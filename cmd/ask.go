package cmd

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/adakindigital/vail/internal/client"
	"github.com/adakindigital/vail/internal/config"
	"github.com/adakindigital/vail/internal/ui"
)

var askCmd = &cobra.Command{
	Use:   "ask [prompt]",
	Short: "Ask Vail a single question (non-interactive)",
	Example: `  vail ask "What is section 11 of the South African LRA?"
  vail ask "Summarise this: $(cat report.txt)"`,
	Args: cobra.MinimumNArgs(1),
	RunE: runAsk,
}

func runAsk(cmd *cobra.Command, args []string) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	th := ui.Get(cfg.Theme)
	prompt := strings.Join(args, " ")
	c := client.New(cfg.Endpoint, cfg.APIKey, cfg.Model)

	messages := []client.Message{
		{
			Role:    "system",
			Content: "You are Vail, an intelligent AI assistant built by Adakin Digital. Be direct and concise. South African context is well understood.",
		},
		{
			Role:    "user",
			Content: prompt,
		},
	}

	done := make(chan struct{})
	go spin(done, th)

	response, err := c.Stream(messages, nil)

	close(done)
	time.Sleep(20 * time.Millisecond)
	fmt.Fprintf(os.Stderr, "\r\033[K")

	if err != nil && response == "" {
		return err
	}

	fmt.Print(renderMarkdown(response, th.GlamourStyle))

	if err != nil {
		fmt.Fprint(os.Stderr, th.Warn(fmt.Sprintf("response cut short: %v", err)))
	}

	return nil
}
