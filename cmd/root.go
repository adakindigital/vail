package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "vail",
	Short: "Vail — AI by Adakin Digital",
	Long:  `Vail (V.A.I.L.) — Versatile Artificial Intelligence Layer. Run 'vail chat' to start a session.`,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

// SetVersion injects build-time version info from main.go ldflags.
func SetVersion(version, commit, date string) {
	rootCmd.Version = fmt.Sprintf("%s (commit %s, built %s)", version, commit, date)
}

func init() {
	rootCmd.AddCommand(askCmd)
	rootCmd.AddCommand(chatCmd)
	rootCmd.AddCommand(runCmd)
	rootCmd.AddCommand(configCmd)
}
