// Package ui provides theme-aware terminal styling for the Aegis CLI.
// All styled output goes through here — keeps colour logic out of command files.
package ui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// Theme holds a named colour palette.
type Theme struct {
	Name         string
	Accent       lipgloss.Color // brand colour — "aegis" label, rules
	User         lipgloss.Color // "you" label
	Tool         lipgloss.Color // tool call highlights
	WarnColor    lipgloss.Color // warnings, partial responses
	ErrColor     lipgloss.Color
	OkColor      lipgloss.Color
	Muted        lipgloss.Color // secondary text, status info
	GlamourStyle string         // glamour markdown theme name
}

// All registered themes. Add more here.
var Themes = map[string]Theme{
	"dark": {
		Name:         "dark",
		Accent:       lipgloss.Color("87"),  // bright cyan
		User:         lipgloss.Color("82"),  // bright green
		Tool:         lipgloss.Color("220"), // yellow
		WarnColor:    lipgloss.Color("220"),
		ErrColor:     lipgloss.Color("196"),
		OkColor:      lipgloss.Color("82"),
		Muted:        lipgloss.Color("240"),
		GlamourStyle: "dark",
	},
	"light": {
		Name:         "light",
		Accent:       lipgloss.Color("27"),  // blue
		User:         lipgloss.Color("28"),  // green
		Tool:         lipgloss.Color("208"), // orange
		WarnColor:    lipgloss.Color("208"),
		ErrColor:     lipgloss.Color("160"),
		OkColor:      lipgloss.Color("28"),
		Muted:        lipgloss.Color("246"),
		GlamourStyle: "light",
	},
	"hacker": {
		Name:         "hacker",
		Accent:       lipgloss.Color("46"),  // matrix green
		User:         lipgloss.Color("40"),  // darker green
		Tool:         lipgloss.Color("226"), // bright yellow
		WarnColor:    lipgloss.Color("226"),
		ErrColor:     lipgloss.Color("196"),
		OkColor:      lipgloss.Color("46"),
		Muted:        lipgloss.Color("34"), // dim green
		GlamourStyle: "dracula",
	},
}

// Get returns the named theme, falling back to dark.
func Get(name string) Theme {
	if t, ok := Themes[name]; ok {
		return t
	}
	return Themes["dark"]
}

// ThemeNames returns all registered theme names.
func ThemeNames() []string {
	names := make([]string, 0, len(Themes))
	for name := range Themes {
		names = append(names, name)
	}
	return names
}

// --------------------------------------------------------------------------
// Style primitives — used by render functions below
// --------------------------------------------------------------------------

func (t Theme) accent(s string) string {
	return lipgloss.NewStyle().Foreground(t.Accent).Bold(true).Render(s)
}

func (t Theme) userColor(s string) string {
	return lipgloss.NewStyle().Foreground(t.User).Bold(true).Render(s)
}

func (t Theme) muted(s string) string {
	return lipgloss.NewStyle().Foreground(t.Muted).Render(s)
}

func (t Theme) toolColor(s string) string {
	return lipgloss.NewStyle().Foreground(t.Tool).Render(s)
}

func (t Theme) warnColor(s string) string {
	return lipgloss.NewStyle().Foreground(t.WarnColor).Render(s)
}

func (t Theme) errColor(s string) string {
	return lipgloss.NewStyle().Foreground(t.ErrColor).Render(s)
}

func (t Theme) okColor(s string) string {
	return lipgloss.NewStyle().Foreground(t.OkColor).Render(s)
}

// AccentText returns a string styled in the accent colour (exported for inline use).
func (t Theme) AccentText(s string) string { return t.accent(s) }

// --------------------------------------------------------------------------
// Render functions — used by cmd/chat.go and cmd/ask.go
// --------------------------------------------------------------------------

// Banner renders the startup screen.
func (t Theme) Banner(model, themeName, memoryNote string) string {
	rule := t.accent(strings.Repeat("─", 44))
	title := lipgloss.NewStyle().Foreground(lipgloss.Color("255")).Bold(true).Render("A E G I S")
	sub := t.muted("·  AI by Adakin Digital")

	b := strings.Builder{}
	b.WriteString("\n")
	b.WriteString(fmt.Sprintf("  %s\n", rule))
	b.WriteString(fmt.Sprintf("  %s  %s\n", title, sub))
	b.WriteString(fmt.Sprintf("  %s\n", rule))
	b.WriteString("\n")
	b.WriteString(fmt.Sprintf("  %s  %-14s  %s  %s\n", t.muted("model"), model, t.muted("theme"), themeName))
	if memoryNote != "" {
		b.WriteString(fmt.Sprintf("  %s  %s\n", t.muted("memory"), t.okColor(memoryNote)))
	}
	b.WriteString(fmt.Sprintf("  %s  %s\n", t.muted("keys"), t.muted("/help · /clear · /theme · /exit")))
	b.WriteString("\n")
	return b.String()
}

// UserPrompt renders the input prompt. Caller prints this then reads a line.
// Two-line format keeps the user's typed text on its own line below the label.
func (t Theme) UserPrompt() string {
	return fmt.Sprintf("\n  %s\n  %s ", t.userColor("you"), t.muted("›"))
}

// AegisHeader renders the start of a model response, with context stats.
func (t Theme) VailHeader(model string, tokens, maxTokens int) string {
	label := t.accent("aegis")
	var stats string
	if maxTokens > 0 && tokens > 0 {
		pct := tokens * 100 / maxTokens
		stats = t.muted(fmt.Sprintf("%s  ·  ~%s / %s  (%d%%)", model, FormatTokens(tokens), FormatTokens(maxTokens), pct))
	} else if tokens > 0 {
		stats = t.muted(fmt.Sprintf("%s  ·  ~%s tokens", model, FormatTokens(tokens)))
	} else {
		stats = t.muted(model)
	}
	return fmt.Sprintf("\n  %s  %s\n", label, stats)
}

// ContextLine renders a standalone context usage line (for /context command).
func (t Theme) ContextLine(model string, tokens, maxTokens int) string {
	if maxTokens > 0 {
		pct := tokens * 100 / maxTokens
		bar := contextBar(pct, 20)
		return fmt.Sprintf("  %s  %s %s / %s  (%d%%)\n",
			t.muted("context"),
			t.accent(bar),
			t.muted(FormatTokens(tokens)),
			t.muted(FormatTokens(maxTokens)),
			pct,
		)
	}
	return fmt.Sprintf("  %s  ~%s tokens\n", t.muted("context"), t.muted(FormatTokens(tokens)))
}

// ToolCall renders a tool invocation line (before the tool runs).
func (t Theme) ToolCall(toolName, detail string) string {
	label := t.toolColor(fmt.Sprintf("⟳ %s", toolName))
	return fmt.Sprintf("  %s  %s\n", label, t.muted(detail))
}

// ToolDone renders a tool completion line.
func (t Theme) ToolDone(detail string) string {
	return fmt.Sprintf("  %s  %s\n", t.okColor("✓"), t.muted(detail))
}

// ShellApproval renders the approval prompt for a shell command.
// Caller must then read the user's y/N response.
func (t Theme) ShellApproval(command string) string {
	b := strings.Builder{}
	b.WriteString(fmt.Sprintf("\n  %s\n", t.warnColor("◆ shell command")))
	b.WriteString(fmt.Sprintf("\n    %s\n\n", t.toolColor(command)))
	b.WriteString(fmt.Sprintf("  %s y/N  › ", t.muted("run this?")))
	return b.String()
}

// Spinner renders a single spinner frame (use with \r to overwrite).
func (t Theme) Spinner(frame string) string {
	return fmt.Sprintf("\r  %s  %s", t.warnColor(frame), t.muted("thinking..."))
}

// Error renders an error message.
func (t Theme) Error(msg string) string {
	return fmt.Sprintf("\n  %s  %s\n", t.errColor("✗"), msg)
}

// Warn renders a warning line.
func (t Theme) Warn(msg string) string {
	return fmt.Sprintf("  %s  %s\n", t.warnColor("↑"), t.muted(msg))
}

// Info renders a dim info line.
func (t Theme) Info(msg string) string {
	return fmt.Sprintf("  %s\n", t.muted(msg))
}

// Ok renders a success line.
func (t Theme) Ok(msg string) string {
	return fmt.Sprintf("  %s  %s\n", t.okColor("✓"), msg)
}

// HelpText returns the formatted /help output.
func (t Theme) HelpText() string {
	row := func(cmd, desc string) string {
		return fmt.Sprintf("  %s  %s\n", t.accent(fmt.Sprintf("%-18s", cmd)), t.muted(desc))
	}
	b := strings.Builder{}
	b.WriteString("\n")
	b.WriteString(row("/clear", "reset conversation history"))
	b.WriteString(row("/context", "show token usage"))
	b.WriteString(row("/model [name]", "show or set active model"))
	b.WriteString(row("/theme [name]", "show or set theme  (dark, light, hacker)"))
	b.WriteString(row("/settings", "show current settings"))
	b.WriteString(row("/init", "create .vail/memory.md project memory file"))
	b.WriteString(row("/tools", "list available tools"))
	b.WriteString(row("/help", "show this"))
	b.WriteString(row("/exit  /quit", "end session"))
	b.WriteString("\n")
	return b.String()
}

// SettingsText returns the formatted /settings output.
func (t Theme) SettingsText(model, themeName, endpoint, apiKey string) string {
	keyDisplay := "(not set — local mode)"
	if apiKey != "" {
		keyDisplay = "set"
	}
	row := func(k, v string) string {
		return fmt.Sprintf("  %s  %s\n", t.muted(fmt.Sprintf("%-12s", k)), v)
	}
	b := strings.Builder{}
	b.WriteString("\n")
	b.WriteString(row("model", model))
	b.WriteString(row("theme", themeName))
	b.WriteString(row("endpoint", endpoint))
	b.WriteString(row("api key", keyDisplay))
	b.WriteString(row("tools", "read_file, shell"))
	b.WriteString("\n")
	return b.String()
}

// ThemeList returns the formatted theme picker output.
func (t Theme) ThemeList(current string) string {
	b := strings.Builder{}
	b.WriteString("\n")
	for name := range Themes {
		if name == current {
			b.WriteString(fmt.Sprintf("  %s  %s\n", t.okColor("✓"), name))
		} else {
			b.WriteString(fmt.Sprintf("     %s\n", t.muted(name)))
		}
	}
	b.WriteString("\n")
	return b.String()
}

// ModelList returns the formatted model list.
func (t Theme) ModelList(current string) string {
	models := []struct{ name, desc string }{
		{"aegis-lite", "E2B 4-bit  ·  fast, daily use"},
		{"aegis", "26B MoE 4-bit  ·  production workhorse"},
		{"aegis-pro", "31B dense 4-bit  ·  complex reasoning"},
		{"aegis-max", "31B dense 4-bit  ·  alias for aegis-pro"},
	}
	b := strings.Builder{}
	b.WriteString("\n")
	for _, m := range models {
		if m.name == current {
			b.WriteString(fmt.Sprintf("  %s  %s  %s\n", t.okColor("✓"), t.accent(fmt.Sprintf("%-12s", m.name)), t.muted(m.desc)))
		} else {
			b.WriteString(fmt.Sprintf("     %s  %s\n", fmt.Sprintf("%-12s", m.name), t.muted(m.desc)))
		}
	}
	b.WriteString("\n")
	return b.String()
}

// InitSuccess renders the /init success message.
func (t Theme) InitSuccess(path string) string {
	b := strings.Builder{}
	b.WriteString(fmt.Sprintf("\n  %s  %s\n", t.okColor("✓"), path))
	b.WriteString(fmt.Sprintf("  %s\n\n", t.muted("edit this file — Aegis will load it as context on startup")))
	return b.String()
}

// InitExists renders the /init already-exists message.
func (t Theme) InitExists(path string) string {
	return fmt.Sprintf("\n  %s  already exists\n  %s\n\n", t.muted(path), t.muted("edit it to update project context"))
}

// MemoryLoaded renders the notification that a memory file was found.
func (t Theme) MemoryLoaded(path string) string {
	return fmt.Sprintf(".vail/memory.md loaded")
}

// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------

// FormatTokens formats a token count as "1.2k" or "420".
func FormatTokens(n int) string {
	if n >= 1000 {
		return fmt.Sprintf("%.1fk", float64(n)/1000)
	}
	return fmt.Sprintf("%d", n)
}

// contextBar returns a compact ASCII progress bar for context usage.
func contextBar(pct, width int) string {
	filled := pct * width / 100
	if filled > width {
		filled = width
	}
	return "[" + strings.Repeat("█", filled) + strings.Repeat("░", width-filled) + "]"
}
