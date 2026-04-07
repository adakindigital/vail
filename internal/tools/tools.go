package tools

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/adakindigital/vail/internal/client"
)

const maxFileBytes = 100 * 1024 // 100KB read limit per file

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
func Definitions() []client.ToolDef {
	return []client.ToolDef{
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
}

// Execute runs a tool call and returns the output to feed back to the model.
// approve is called for shell commands — it receives the command string and returns
// true if the user allows execution, false to decline.
func Execute(tc client.ToolCall, approve func(command string) bool) string {
	switch tc.Name {
	case "read_file":
		return readFile(tc.Arguments)
	case "shell":
		return runShell(tc.Arguments, approve)
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
