package cmd

import (
	"os"
	"strings"

	"github.com/charmbracelet/glamour"
	"golang.org/x/term"
)

// renderMarkdown converts markdown text to ANSI-styled terminal output.
// glamourStyle corresponds to a named glamour style (dark, light, dracula, etc.).
// Falls back to plain text if rendering fails.
func renderMarkdown(text, glamourStyle string) string {
	if strings.TrimSpace(text) == "" {
		return "\n"
	}

	if glamourStyle == "" {
		glamourStyle = "dark"
	}

	width := termWidth()

	r, err := glamour.NewTermRenderer(
		glamour.WithStylePath(glamourStyle),
		glamour.WithWordWrap(width),
	)
	if err != nil {
		return text + "\n"
	}

	out, err := r.Render(text)
	if err != nil {
		return text + "\n"
	}

	return strings.TrimRight(out, "\n") + "\n"
}

// termWidth returns the terminal width, capped at 120 for readability.
func termWidth() int {
	w, _, err := term.GetSize(int(os.Stdout.Fd()))
	if err != nil || w <= 0 {
		return 100
	}
	if w > 120 {
		return 120
	}
	return w
}
