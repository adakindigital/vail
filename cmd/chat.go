package cmd

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/adakindigital/vail/internal/client"
	"github.com/adakindigital/vail/internal/config"
	"github.com/adakindigital/vail/internal/tools"
	"github.com/adakindigital/vail/internal/ui"
)

var chatCmd = &cobra.Command{
	Use:   "chat",
	Short: "Start an interactive session with Vail (tools included)",
	RunE:  runChat,
}

// buildSystemPrompt constructs the full system prompt for a session.
// It injects the current working directory and any loaded project memory.
func buildSystemPrompt(cwd, memory string) string {
	prompt := fmt.Sprintf(`You are Vail (V.A.I.L.) — Versatile Artificial Intelligence Layer, built by Adakin Digital. You are knowledgeable, direct, and helpful. Strong knowledge of South African context — law, business, culture, and language.

## Environment
- Current directory: %s
- OS: macOS (Apple Silicon)

## Tools
You have two tools. Use them freely and proactively — do not ask permission before using them.

- read_file: Read any file by path. Use this constantly. When asked about code or a project, read the relevant files first rather than guessing.
- shell: Run shell commands. Read-only commands (ls, find, cat, grep, git status, git log, etc.) run automatically without prompting. Commands that modify files or system state require explicit user approval.

## How to work
- When asked about a project or codebase, EXPLORE it. Use ls to discover structure, read key files (go.mod, package.json, README, main entry points, config files).
- Chain your tools: explore → read → answer. Don't answer from memory when you can verify.
- When a user says "scan this project", "what is this", or "understand this codebase" — use your tools to actually do it.
- Be direct. Don't over-explain. Don't ask clarifying questions when you can just look.`, cwd)

	if memory != "" {
		prompt += "\n\n## Project Memory\n\n" + memory
	}

	return prompt
}

// Context window sizes per model tier (approximate).
var modelContextWindow = map[string]int{
	"aegis-lite": 8192,
	"aegis":      32768,
	"aegis-pro":  131072,
	"aegis-max":  131072,
}

// validModels is the ordered list of known model tiers.
var validModels = []string{"aegis-lite", "aegis", "aegis-pro", "aegis-max"}

// spinnerFrames for the thinking animation.
var spinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

func runChat(cmd *cobra.Command, args []string) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	th := ui.Get(cfg.Theme)
	c := client.New(cfg.Endpoint, cfg.APIKey, cfg.Model)

	cwd, _ := os.Getwd()
	memory, memoryPath := loadProjectMemory()
	systemPrompt := buildSystemPrompt(cwd, memory)

	messages := []client.Message{
		{Role: "system", Content: systemPrompt},
	}

	// Banner
	memNote := ""
	if memoryPath != "" {
		memNote = th.MemoryLoaded(memoryPath)
	}
	fmt.Print(th.Banner(cfg.Model, cfg.Theme, memNote))

	scanner := bufio.NewScanner(os.Stdin)

	for {
		fmt.Print(th.UserPrompt())

		if !scanner.Scan() {
			break
		}

		input := strings.TrimSpace(scanner.Text())
		if input == "" {
			continue
		}

		// Slash command dispatch
		if handled := handleSlashCommand(input, cfg, &c, &th, &messages, systemPrompt, memoryPath); handled {
			continue
		}

		// User message
		messages = append(messages, client.Message{
			Role:    "user",
			Content: input,
		})

		// Run the agentic turn (handles tool calls + content response)
		if err := agenticTurn(c, th, *cfg, &messages); err != nil {
			fmt.Print(th.Error(err.Error()))
			// Remove the failed user message so history stays clean
			messages = messages[:len(messages)-1]
		}
	}

	return scanner.Err()
}

// handleSlashCommand processes /commands. Returns true if input was a slash command.
func handleSlashCommand(
	input string,
	cfg *config.Config,
	c **client.Client,
	th *ui.Theme,
	messages *[]client.Message,
	systemPrompt string,
	memoryPath string,
) bool {
	cmd := strings.Fields(input)
	if len(cmd) == 0 || !strings.HasPrefix(cmd[0], "/") {
		// Also handle bare exit/quit without slash
		if input == "exit" || input == "quit" {
			fmt.Printf("\n  %s  Goodbye.\n\n", th.AccentText("aegis"))
			os.Exit(0)
		}
		return false
	}

	switch cmd[0] {
	case "/exit", "/quit":
		fmt.Printf("\n  %s  Goodbye.\n\n", th.AccentText("aegis"))
		os.Exit(0)

	case "/clear":
		*messages = []client.Message{{Role: "system", Content: systemPrompt}}
		fmt.Print(th.Info("conversation cleared"))

	case "/help":
		fmt.Print(th.HelpText())

	case "/context":
		tokens := countTokens(*messages)
		maxTokens := modelContextWindow[cfg.Model]
		fmt.Print(th.ContextLine(cfg.Model, tokens, maxTokens))

	case "/tools":
		fmt.Print(th.Info("read_file  ·  read any file by path"))
		fmt.Print(th.Info("shell      ·  run shell commands (requires your approval)"))

	case "/settings":
		fmt.Print(th.SettingsText(cfg.Model, cfg.Theme, cfg.Endpoint, cfg.APIKey))

	case "/theme":
		if len(cmd) == 1 {
			fmt.Print(th.ThemeList(cfg.Theme))
		} else {
			newTheme := cmd[1]
			if _, ok := ui.Themes[newTheme]; !ok {
				fmt.Print(th.Error(fmt.Sprintf("unknown theme: %s", newTheme)))
				fmt.Print(th.Info(fmt.Sprintf("available: %s", strings.Join(ui.ThemeNames(), ", "))))
			} else {
				cfg.Theme = newTheme
				if err := config.Save(cfg); err != nil {
					fmt.Print(th.Error(fmt.Sprintf("could not save config: %v", err)))
				} else {
					*th = ui.Get(newTheme)
					fmt.Print(th.Ok(fmt.Sprintf("theme: %s", newTheme)))
				}
			}
		}

	case "/model":
		if len(cmd) == 1 {
			fmt.Print(th.ModelList(cfg.Model))
		} else {
			newModel := cmd[1]
			if !isValidModel(newModel) {
				fmt.Print(th.Error(fmt.Sprintf("unknown model: %s", newModel)))
				fmt.Print(th.Info(fmt.Sprintf("available: %s", strings.Join(validModels, ", "))))
			} else {
				cfg.Model = newModel
				if err := config.Save(cfg); err != nil {
					fmt.Print(th.Error(fmt.Sprintf("could not save config: %v", err)))
				} else {
					*c = client.New(cfg.Endpoint, cfg.APIKey, cfg.Model)
					fmt.Print(th.Ok(fmt.Sprintf("model: %s", newModel)))
					fmt.Print(th.Info("restart or use /clear to apply to this session"))
				}
			}
		}

	case "/init":
		handleSmartInit(**c, *th, cfg, messages, systemPrompt)

	default:
		fmt.Print(th.Error(fmt.Sprintf("unknown command: %s  (try /help)", cmd[0])))
	}

	return true
}

// agenticTurn runs one full model turn, executing tool calls until the model stops.
func agenticTurn(c *client.Client, th ui.Theme, cfg config.Config, messages *[]client.Message) error {
	toolDefs := tools.Definitions()

	for {
		done := make(chan struct{})
		go spin(done, th)

		result, err := c.StreamWithTools(*messages, toolDefs, nil)

		close(done)
		time.Sleep(20 * time.Millisecond)
		fmt.Print("\r\033[K") // clear spinner line

		if err != nil {
			if result.Content != "" {
				// Partial response — show what we got with a warning
				tokens := countTokens(*messages) + len(result.Content)/4
				fmt.Print(th.VailHeader(cfg.Model, tokens, modelContextWindow[cfg.Model]))
				fmt.Print(renderMarkdown(result.Content, th.GlamourStyle))
				fmt.Print(th.Warn(fmt.Sprintf("response cut short: %v", err)))
				*messages = append(*messages, client.Message{Role: "assistant", Content: result.Content})
				return nil
			}
			return err
		}

		// Print response content if any
		if result.Content != "" {
			tokens := countTokens(*messages) + len(result.Content)/4
			fmt.Print(th.VailHeader(cfg.Model, tokens, modelContextWindow[cfg.Model]))
			fmt.Print(renderMarkdown(result.Content, th.GlamourStyle))
		}

		// No tool calls — turn complete
		if len(result.ToolCalls) == 0 {
			*messages = append(*messages, client.Message{Role: "assistant", Content: result.Content})
			return nil
		}

		// Add assistant message with tool calls to history
		apiCalls := make([]client.APIToolCall, len(result.ToolCalls))
		for i, tc := range result.ToolCalls {
			apiCalls[i] = tools.ToAPIToolCall(tc)
		}
		*messages = append(*messages, client.Message{
			Role:      "assistant",
			Content:   nil,
			ToolCalls: apiCalls,
		})

		// Execute each tool and feed results back
		for _, tc := range result.ToolCalls {
			detail := toolDetail(tc)

			output := tools.Execute(tc, func(command string) bool {
				if tools.IsSafeCommand(command) {
					// Auto-approve read-only commands — show it's running but don't prompt
					fmt.Print(th.ToolCall("shell", command))
					return true
				}
				return shellApproval(th, command)
			})

			if tc.Name != "shell" || !tools.IsSafeCommand(detail) {
				fmt.Print(th.ToolCall(tc.Name, detail))
			}
			fmt.Print(th.ToolDone(truncate(output, 80)))

			*messages = append(*messages, client.Message{
				Role:       "tool",
				Content:    output,
				ToolCallID: tc.ID,
			})
		}
		// Loop — send tool results back to model
	}
}

// shellApproval shows the proposed command and waits for explicit approval.
func shellApproval(th ui.Theme, command string) bool {
	fmt.Print(th.ShellApproval(command))
	var input string
	fmt.Scanln(&input)
	approved := strings.ToLower(strings.TrimSpace(input)) == "y"
	if !approved {
		fmt.Print(th.Info("skipped"))
	}
	return approved
}

// spin runs the thinking animation until done is closed.
func spin(done <-chan struct{}, th ui.Theme) {
	i := 0
	for {
		select {
		case <-done:
			return
		default:
			fmt.Print(th.Spinner(spinnerFrames[i%len(spinnerFrames)]))
			time.Sleep(80 * time.Millisecond)
			i++
		}
	}
}

// handleSmartInit triggers an agentic project scan and writes the result to .vail/memory.md.
// The model explores the codebase using its tools and generates the memory content itself.
func handleSmartInit(c client.Client, th ui.Theme, cfg *config.Config, messages *[]client.Message, systemPrompt string) {
	const memDir = ".vail"
	const memFile = ".vail/memory.md"

	if _, err := os.Stat(memFile); err == nil {
		fmt.Print(th.InitExists(memFile))
		return
	}

	if err := os.MkdirAll(memDir, 0755); err != nil {
		fmt.Print(th.Error(fmt.Sprintf("could not create .vail/: %v", err)))
		return
	}

	cwd, _ := os.Getwd()
	fmt.Print(th.Info(fmt.Sprintf("scanning %s ...", cwd)))

	// Inject a scan request into the conversation
	scanPrompt := fmt.Sprintf(`Scan this project at %s and generate the content for .vail/memory.md.

Use your tools:
1. Run ls to see the directory structure
2. Read the key files that reveal what this project is (go.mod, package.json, pubspec.yaml, README.md, main entry points, config files — whatever is relevant)
3. Check git log for recent activity if it's a git repo

Then write a memory file in this exact markdown format:

# Project Memory

## Project
[What this project is, what problem it solves, who it's for]

## Stack
[Tech stack, frameworks, key libraries, architecture decisions]

## Current State
[What's built, what's in progress, what's next]

## Context
[Naming conventions, important decisions, things to always keep in mind]

Output ONLY the markdown content above. No explanation, no preamble.`, cwd)

	// Save conversation length so we can strip the scan exchange after
	prevLen := len(*messages)
	*messages = append(*messages, client.Message{Role: "user", Content: scanPrompt})

	if err := agenticTurn(&c, th, *cfg, messages); err != nil {
		fmt.Print(th.Error(fmt.Sprintf("scan failed: %v", err)))
		*messages = (*messages)[:prevLen]
		return
	}

	// Extract the model's response from the last assistant message
	var content string
	for i := len(*messages) - 1; i >= 0; i-- {
		if (*messages)[i].Role == "assistant" {
			if s, ok := (*messages)[i].Content.(string); ok && s != "" {
				content = s
				break
			}
		}
	}

	// Strip the scan exchange — it was utility work, not part of the user's conversation
	*messages = (*messages)[:prevLen]

	if content == "" {
		fmt.Print(th.Error("model did not generate content — try again or fill .vail/memory.md manually"))
		return
	}

	if err := os.WriteFile(memFile, []byte(content+"\n"), 0644); err != nil {
		fmt.Print(th.Error(fmt.Sprintf("could not write %s: %v", memFile, err)))
		return
	}

	fmt.Print(th.InitSuccess(memFile))
	fmt.Print(th.Info("memory will load automatically next time you run 'vail chat' here"))
}

// loadProjectMemory searches for .aegis/memory.md in the cwd and up to 3 parent dirs.
// Returns the file contents and the path where it was found (empty strings if not found).
func loadProjectMemory() (string, string) {
	dir, err := os.Getwd()
	if err != nil {
		return "", ""
	}

	for i := 0; i < 4; i++ {
		path := filepath.Join(dir, ".vail", "memory.md")
		if data, err := os.ReadFile(path); err == nil {
			return string(data), path
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	return "", ""
}

// countTokens estimates the total token count for a message slice.
// Approximation: 4 chars ≈ 1 token.
func countTokens(messages []client.Message) int {
	total := 0
	for _, m := range messages {
		switch v := m.Content.(type) {
		case string:
			total += len(v) / 4
		}
	}
	return total
}

// toolDetail extracts a short human-readable label from a tool call's arguments.
func toolDetail(tc client.ToolCall) string {
	// Pull the first string value from the JSON args as the detail label
	args := tc.Arguments
	// Quick and dirty: look for "path" or "command" value
	for _, key := range []string{`"path":"`, `"command":"`} {
		if idx := strings.Index(args, key); idx >= 0 {
			rest := args[idx+len(key):]
			if end := strings.IndexByte(rest, '"'); end >= 0 {
				return rest[:end]
			}
		}
	}
	return ""
}

// truncate shortens s to maxLen chars, adding "…" if cut.
func truncate(s string, maxLen int) string {
	s = strings.TrimSpace(s)
	// Only show first line for tool output summary
	if nl := strings.IndexByte(s, '\n'); nl >= 0 {
		s = s[:nl] + "…"
	}
	if len(s) > maxLen {
		return s[:maxLen] + "…"
	}
	return s
}

func isValidModel(name string) bool {
	for _, m := range validModels {
		if m == name {
			return true
		}
	}
	return false
}
