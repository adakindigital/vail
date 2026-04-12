package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/adakindigital/vail/internal/config"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Show or update Vail configuration",
}

var configShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show current configuration",
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg, err := config.Load()
		if err != nil {
			return err
		}
		fmt.Printf("endpoint:    %s\n", cfg.Endpoint)
		fmt.Printf("model:       %s  (%s)\n", cfg.Model, cfg.ResolvedModel())
		if cfg.APIKey != "" {
			fmt.Printf("api_key:     %s...\n", cfg.APIKey[:8])
		} else {
			fmt.Printf("api_key:     (not set — local mode)\n")
		}
		if cfg.TavilyKey != "" {
			fmt.Printf("tavily_key:  set (web search enabled)\n")
		} else {
			fmt.Printf("tavily_key:  (not set — run: vail config tavily-key <key>)\n")
		}
		return nil
	},
}

var configSetEndpointCmd = &cobra.Command{
	Use:   "endpoint [url]",
	Short: "Set the API endpoint (local or cloud)",
	Example: `  vail config endpoint http://localhost:8080
  vail config endpoint https://api.vail.adakindigital.com/v1`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg, err := config.Load()
		if err != nil {
			return err
		}
		cfg.Endpoint = args[0]
		if err := config.Save(cfg); err != nil {
			return err
		}
		fmt.Printf("endpoint set to %s\n", args[0])
		return nil
	},
}

var configSetModelCmd = &cobra.Command{
	Use:   "model [name]",
	Short: "Set the active model",
	Example: `  vail config model vail-lite
  vail config model vail
  vail config model vail-pro`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg, err := config.Load()
		if err != nil {
			return err
		}
		name := args[0]
		if _, ok := cfg.Models[name]; !ok {
			known := make([]string, 0, len(cfg.Models))
			for k := range cfg.Models {
				known = append(known, k)
			}
			fmt.Printf("unknown model %q — known tiers: %v\n", name, known)
			fmt.Printf("if this is a custom model path, add it to ~/.vail/config.yaml manually\n")
			return nil
		}
		cfg.Model = name
		if err := config.Save(cfg); err != nil {
			return err
		}
		fmt.Printf("model set to %s  (%s)\n", name, cfg.Models[name])
		return nil
	},
}

var configSetKeyCmd = &cobra.Command{
	Use:   "key [api-key]",
	Short: "Set the Vail API key (for cloud mode)",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg, err := config.Load()
		if err != nil {
			return err
		}
		cfg.APIKey = args[0]
		if err := config.Save(cfg); err != nil {
			return err
		}
		fmt.Printf("API key saved\n")
		return nil
	},
}

var configSetTavilyKeyCmd = &cobra.Command{
	Use:   "tavily-key [api-key]",
	Short: "Set the Tavily API key (enables web_search and fetch_url tools)",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg, err := config.Load()
		if err != nil {
			return err
		}
		cfg.TavilyKey = args[0]
		if err := config.Save(cfg); err != nil {
			return err
		}
		fmt.Printf("Tavily key saved — web_search and fetch_url tools are now active\n")
		return nil
	},
}

func init() {
	configCmd.AddCommand(configShowCmd)
	configCmd.AddCommand(configSetEndpointCmd)
	configCmd.AddCommand(configSetModelCmd)
	configCmd.AddCommand(configSetKeyCmd)
	configCmd.AddCommand(configSetTavilyKeyCmd)
}
