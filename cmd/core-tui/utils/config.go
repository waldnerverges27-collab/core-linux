package utils

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Config holds the full application configuration
type Config struct {
	Core  CoreConfig  `json:"core"`
	TUI   TUIConfig   `json:"tui"`
	Brain BrainConfig `json:"brain"`
}

// CoreConfig holds [core] section
type CoreConfig struct {
	Version string `json:"version"`
	Home    string `json:"home"`
	Theme   string `json:"theme"`
	Editor  string `json:"editor"`
}

// TUIConfig holds [tui] section
type TUIConfig struct {
	AnimationSpeed string `json:"animation_speed"`
	BorderStyle    string `json:"border_style"`
}

// BrainConfig holds [brain] section
type BrainConfig struct {
	SyncRemote string `json:"sync_remote"`
}

// DefaultConfig returns a Config with sensible defaults
func DefaultConfig() *Config {
	return &Config{
		Core: CoreConfig{
			Version: "1.0.0",
			Home:    CoreHome(),
			Theme:   "catppuccin-mocha",
			Editor:  "vim",
		},
		TUI: TUIConfig{
			AnimationSpeed: "normal",
			BorderStyle:    "rounded",
		},
		Brain: BrainConfig{
			SyncRemote: "",
		},
	}
}

// LoadConfig reads the TOML config file and returns a Config
// Uses simple line-by-line parsing (no TOML library dependency)
func LoadConfig() *Config {
	cfg := DefaultConfig()

	configPath := filepath.Join(os.Getenv("HOME"), ".config", "core-linux", "config.toml")
	data, err := os.ReadFile(configPath)
	if err != nil {
		return cfg
	}

	content := string(data)
	section := ""
	lines := strings.Split(content, "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = line[1 : len(line)-1]
			continue
		}

		eqIdx := strings.Index(line, "=")
		if eqIdx < 0 {
			continue
		}
		key := strings.TrimSpace(line[:eqIdx])
		value := strings.TrimSpace(line[eqIdx+1:])
		value = strings.Trim(value, "\"'")

		switch section {
		case "core":
			switch key {
			case "theme":
				cfg.Core.Theme = value
			case "editor":
				cfg.Core.Editor = value
			}
		case "tui":
			switch key {
			case "animation_speed":
				cfg.TUI.AnimationSpeed = value
			case "border_style":
				cfg.TUI.BorderStyle = value
			}
		case "brain":
			switch key {
			case "sync_remote":
				cfg.Brain.SyncRemote = value
			}
		}
	}

	return cfg
}

// SaveConfig writes the config to the TOML file
func SaveConfig(cfg *Config) error {
	configPath := filepath.Join(os.Getenv("HOME"), ".config", "core-linux", "config.toml")
	dir := filepath.Dir(configPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("creating config dir: %w", err)
	}

	var b strings.Builder
	b.WriteString("[core]\n")
	b.WriteString(fmt.Sprintf("version = \"%s\"\n", cfg.Core.Version))
	b.WriteString(fmt.Sprintf("home = \"%s\"\n", cfg.Core.Home))
	b.WriteString(fmt.Sprintf("theme = \"%s\"\n", cfg.Core.Theme))
	b.WriteString(fmt.Sprintf("editor = \"%s\"\n", cfg.Core.Editor))
	b.WriteString("\n[tui]\n")
	b.WriteString(fmt.Sprintf("animation_speed = \"%s\"\n", cfg.TUI.AnimationSpeed))
	b.WriteString(fmt.Sprintf("border_style = \"%s\"\n", cfg.TUI.BorderStyle))
	b.WriteString("\n[brain]\n")
	b.WriteString(fmt.Sprintf("sync_remote = \"%s\"\n", cfg.Brain.SyncRemote))

	return os.WriteFile(configPath, []byte(b.String()), 0644)
}

// ToJSON returns a JSON representation of the config (for internal use)
func (c *Config) ToJSON() string {
	data, _ := json.MarshalIndent(c, "", "  ")
	return string(data)
}
