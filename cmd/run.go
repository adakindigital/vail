package cmd

import (
	"github.com/spf13/cobra"
)

// runCmd is kept as a hidden alias for backward compatibility.
// Tool calling is now always active in `vail chat`.
var runCmd = &cobra.Command{
	Use:    "run",
	Short:  "Deprecated — use 'vail chat' (tools are always active now)",
	Hidden: true,
	RunE:   runChat,
}
