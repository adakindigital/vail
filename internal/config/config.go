package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Endpoint  string            `yaml:"endpoint"`
	APIKey    string            `yaml:"api_key"`
	Model     string            `yaml:"model"`
	Stream    bool              `yaml:"stream"`
	Theme     string            `yaml:"theme"`
	Models    map[string]string `yaml:"models"`
	TavilyKey string            `yaml:"tavily_key"`
}

var defaults = Config{
	Endpoint: "http://localhost:9090",
	Model:    "vail-lite",
	Stream:   true,
	Theme:    "dark",
	Models: map[string]string{
		"vail-lite": "/Users/papa/models/friday/gemma-4-e2b-it-4bit",
		"vail":      "/Users/papa/models/friday/gemma-4-26b-a4b-it-4bit",
		"vail-pro":  "/Users/papa/models/friday/gemma-4-31b-it-4bit",
		"vail-max":  "/Users/papa/models/friday/gemma-4-31b-it-4bit",
	},
}

func configPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".vail", "config.yaml")
}

func Load() (*Config, error) {
	cfg := defaults

	path := configPath()
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return &cfg, nil
	}
	if err != nil {
		return nil, err
	}

	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("invalid config at %s: %w", path, err)
	}

	return &cfg, nil
}

func Save(cfg *Config) error {
	path := configPath()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}

	data, err := yaml.Marshal(cfg)
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0600)
}

// ResolvedModel returns the underlying model ID for a given Vail model name.
// If the name isn't in the models map it's passed through as-is (supports raw model IDs).
func (c *Config) ResolvedModel() string {
	if id, ok := c.Models[c.Model]; ok {
		return id
	}
	return c.Model
}
