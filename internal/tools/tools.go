package tools

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/adakindigital/vail/internal/client"
)

const maxFileBytes = 100 * 1024 // 100KB read limit per file
const maxFetchBytes = 8 * 1024  // 8KB fetch limit — keeps responses within context budget

// safeCommandPrefixes — commands that are read-only and can run without user approval.
var safeCommandPrefixes = []string{
	"ls", "find", "cat", "head", "tail", "grep", "rg", "wc",
	"pwd", "echo", "which", "type", "file",
	"git status", "git log", "git diff", "git branch", "git show", "git remote",
	"go build", "go list", "go mod", "go env", "go version",
	"python3 -c", "python -c", "node -e",
	"du ", "df ", "ps ", "env", "printenv",
	"curl -s", "curl --silent",
}

// IsSafeCommand returns true if the command is read-only and safe to auto-approve.
func IsSafeCommand(cmd string) bool {
	cmd = strings.TrimSpace(cmd)
	for _, prefix := range safeCommandPrefixes {
		if cmd == prefix || strings.HasPrefix(cmd, prefix+" ") || strings.HasPrefix(cmd, prefix+"\t") {
			return true
		}
	}
	return false
}

// Definitions returns the tool list to send to the model.
// Research tools (web_search, fetch_url) are included only when tavilyKey is set.
func Definitions(tavilyKey string) []client.ToolDef {
	defs := []client.ToolDef{
		{
			Type: "function",
			Function: client.ToolFunction{
				Name:        "read_file",
				Description: "Read the contents of a file. Use relative paths from the current working directory or absolute paths.",
				Parameters: map[string]any{
					"type": "object",
					"properties": map[string]any{
						"path": map[string]any{
							"type":        "string",
							"description": "Path to the file to read",
						},
					},
					"required": []string{"path"},
				},
			},
		},
		{
			Type: "function",
			Function: client.ToolFunction{
				Name:        "shell",
				Description: "Run a shell command. The user will see the command and must approve it before it runs. Use for building, testing, listing files, git operations, etc.",
				Parameters: map[string]any{
					"type": "object",
					"properties": map[string]any{
						"command": map[string]any{
							"type":        "string",
							"description": "The shell command to execute",
						},
					},
					"required": []string{"command"},
				},
			},
		},
	}

	if tavilyKey != "" {
		defs = append(defs,
			client.ToolDef{
				Type: "function",
				Function: client.ToolFunction{
					Name:        "web_search",
					Description: "Search the web for current information. Use this for recent events, documentation, research, or anything requiring up-to-date knowledge. Returns top results with titles, URLs, and content snippets.",
					Parameters: map[string]any{
						"type": "object",
						"properties": map[string]any{
							"query": map[string]any{
								"type":        "string",
								"description": "The search query",
							},
						},
						"required": []string{"query"},
					},
				},
			},
			client.ToolDef{
				Type: "function",
				Function: client.ToolFunction{
					Name:        "fetch_url",
					Description: "Fetch and read a web page by URL. Use after web_search to read the full content of a result. Returns plain text extracted from the page.",
					Parameters: map[string]any{
						"type": "object",
						"properties": map[string]any{
							"url": map[string]any{
								"type":        "string",
								"description": "The full URL to fetch",
							},
						},
						"required": []string{"url"},
					},
				},
			},
		)
	}

	return defs
}

// Execute runs a tool call and returns the output to feed back to the model.
// approve is called for shell commands — it receives the command string and returns
// true if the user allows execution, false to decline.
func Execute(tc client.ToolCall, tavilyKey string, approve func(command string) bool) string {
	switch tc.Name {
	case "read_file":
		return readFile(tc.Arguments)
	case "shell":
		return runShell(tc.Arguments, approve)
	case "web_search":
		return webSearch(tc.Arguments, tavilyKey)
	case "fetch_url":
		return fetchURL(tc.Arguments)
	default:
		return fmt.Sprintf("unknown tool: %s", tc.Name)
	}
}

// ToAPIToolCall converts a ToolCall back to the API format for conversation history.
func ToAPIToolCall(tc client.ToolCall) client.APIToolCall {
	return client.APIToolCall{
		ID:   tc.ID,
		Type: "function",
		Function: struct {
			Name      string `json:"name"`
			Arguments string `json:"arguments"`
		}{
			Name:      tc.Name,
			Arguments: tc.Arguments,
		},
	}
}

func readFile(rawArgs string) string {
	var args struct {
		Path string `json:"path"`
	}
	if err := json.Unmarshal([]byte(rawArgs), &args); err != nil {
		return fmt.Sprintf("error: invalid arguments: %v", err)
	}

	path := args.Path
	if !filepath.IsAbs(path) {
		cwd, err := os.Getwd()
		if err != nil {
			return fmt.Sprintf("error: cannot determine working directory: %v", err)
		}
		path = filepath.Join(cwd, path)
	}

	info, err := os.Stat(path)
	if err != nil {
		return fmt.Sprintf("error: cannot access %s: %v", args.Path, err)
	}
	if info.IsDir() {
		return fmt.Sprintf("error: %s is a directory, not a file", args.Path)
	}

	f, err := os.Open(path)
	if err != nil {
		return fmt.Sprintf("error: cannot open %s: %v", args.Path, err)
	}
	defer f.Close()

	buf := make([]byte, maxFileBytes)
	n, err := f.Read(buf)
	if err != nil && n == 0 {
		return fmt.Sprintf("error: cannot read %s: %v", args.Path, err)
	}

	content := string(buf[:n])
	if int64(n) >= int64(maxFileBytes) {
		content += fmt.Sprintf("\n\n[truncated — file exceeds %dKB read limit]", maxFileBytes/1024)
	}

	return content
}

func runShell(rawArgs string, approve func(string) bool) string {
	var args struct {
		Command string `json:"command"`
	}
	if err := json.Unmarshal([]byte(rawArgs), &args); err != nil {
		return fmt.Sprintf("error: invalid arguments: %v", err)
	}

	command := strings.TrimSpace(args.Command)
	if command == "" {
		return "error: empty command"
	}

	if !approve(command) {
		return "user declined to run this command"
	}

	cmd := exec.Command("bash", "-c", command)
	cmd.Dir, _ = os.Getwd()

	out, err := cmd.CombinedOutput()
	output := strings.TrimRight(string(out), "\n")

	if err != nil {
		if output != "" {
			return fmt.Sprintf("exit error: %v\n%s", err, output)
		}
		return fmt.Sprintf("exit error: %v", err)
	}

	if output == "" {
		return "(no output)"
	}

	return output
}

// tavilyResponse is the subset of the Tavily search API response we care about.
type tavilyResponse struct {
	Query   string `json:"query"`
	Results []struct {
		Title   string  `json:"title"`
		URL     string  `json:"url"`
		Content string  `json:"content"`
		Score   float64 `json:"score"`
	} `json:"results"`
	Error string `json:"error"`
}

func webSearch(rawArgs, tavilyKey string) string {
	var args struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal([]byte(rawArgs), &args); err != nil {
		return fmt.Sprintf("error: invalid arguments: %v", err)
	}
	if tavilyKey == "" {
		return "error: Tavily API key not configured — run: vail config tavily-key <key>"
	}
	if strings.TrimSpace(args.Query) == "" {
		return "error: query is empty"
	}

	payload, _ := json.Marshal(map[string]any{
		"api_key":      tavilyKey,
		"query":        args.Query,
		"search_depth": "basic",
		"max_results":  5,
	})

	httpClient := &http.Client{Timeout: 15 * time.Second}
	resp, err := httpClient.Post(
		"https://api.tavily.com/search",
		"application/json",
		bytes.NewReader(payload),
	)
	if err != nil {
		return fmt.Sprintf("error: search request failed: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Sprintf("error: failed to read response: %v", err)
	}

	var result tavilyResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return fmt.Sprintf("error: failed to parse response: %v", err)
	}
	if result.Error != "" {
		return fmt.Sprintf("error: Tavily API error: %s", result.Error)
	}
	if len(result.Results) == 0 {
		return fmt.Sprintf("no results found for: %s", args.Query)
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Search results for \"%s\":\n\n", result.Query))
	for i, r := range result.Results {
		sb.WriteString(fmt.Sprintf("%d. %s\n", i+1, r.Title))
		sb.WriteString(fmt.Sprintf("   URL: %s\n", r.URL))
		if r.Content != "" {
			snippet := r.Content
			if len(snippet) > 300 {
				snippet = snippet[:300] + "..."
			}
			sb.WriteString(fmt.Sprintf("   %s\n", snippet))
		}
		sb.WriteString("\n")
	}

	return strings.TrimRight(sb.String(), "\n")
}

var htmlTagRe = regexp.MustCompile(`<[^>]+>`)
var whitespaceRe = regexp.MustCompile(`[ \t]{2,}`)

func fetchURL(rawArgs string) string {
	var args struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal([]byte(rawArgs), &args); err != nil {
		return fmt.Sprintf("error: invalid arguments: %v", err)
	}
	if strings.TrimSpace(args.URL) == "" {
		return "error: URL is empty"
	}

	httpClient := &http.Client{Timeout: 15 * time.Second}
	resp, err := httpClient.Get(args.URL)
	if err != nil {
		return fmt.Sprintf("error: fetch failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Sprintf("error: server returned %d for %s", resp.StatusCode, args.URL)
	}

	limited := io.LimitReader(resp.Body, maxFetchBytes)
	raw, err := io.ReadAll(limited)
	if err != nil {
		return fmt.Sprintf("error: failed to read response: %v", err)
	}

	content := string(raw)

	// Strip HTML tags and collapse whitespace for readability
	contentType := resp.Header.Get("Content-Type")
	if strings.Contains(contentType, "html") {
		content = htmlTagRe.ReplaceAllString(content, " ")
		content = whitespaceRe.ReplaceAllString(content, " ")
		content = strings.ReplaceAll(content, "\n ", "\n")
	}

	content = strings.TrimSpace(content)
	if len(raw) >= maxFetchBytes {
		content += fmt.Sprintf("\n\n[truncated — page exceeds %dKB fetch limit]", maxFetchBytes/1024)
	}

	return content
}
