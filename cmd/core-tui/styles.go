package main

import (
	"os"
	"path/filepath"

	"github.com/charmbracelet/lipgloss"
)

// Theme holds all color values for the TUI
type Theme struct {
	Primary   string
	Secondary string
	Accent    string
	Success   string
	Warning   string
	Error     string
	Bg        string
	Surface   string
	Text      string
	Muted     string
	Border    string
}

// loadTheme reads a theme by name from the themes directory
func loadTheme(name string) Theme {
	t := Theme{
		Primary:   "#cba6f7",
		Secondary: "#89b4fa",
		Accent:    "#f38ba8",
		Success:   "#a6e3a1",
		Warning:   "#f9e2af",
		Error:     "#f38ba8",
		Bg:        "#1e1e2e",
		Surface:   "#313244",
		Text:      "#cdd6f4",
		Muted:     "#6c7086",
		Border:    "#45475a",
	}

	cfgPath := filepath.Join(os.Getenv("HOME"), ".config", "core-linux", "config.toml")
	if data, err := os.ReadFile(cfgPath); err == nil {
		parseThemeTOML(string(data), &t)
	}

	themeDir := filepath.Join(os.Getenv("HOME"), ".local", "share", "core-linux", "lib", "tui", "themes")
	themeFile := filepath.Join(themeDir, name+".toml")
	if data, err := os.ReadFile(themeFile); err == nil {
		parseThemeTOML(string(data), &t)
	}

	return t
}

func parseThemeTOML(data string, t *Theme) {
	pos := 0
	for pos < len(data) {
		end := pos
		for end < len(data) && data[end] != '\n' {
			end++
		}
		line := data[pos:end]
		pos = end + 1

		line = trimSpace(line)
		if line == "" || line[0] == '#' || line[0] == '[' {
			continue
		}

		eqIdx := indexOf(line, '=')
		if eqIdx < 0 {
			continue
		}
		key := trimSpace(line[:eqIdx])
		value := trimSpace(line[eqIdx+1:])
		value = trimQuotes(value)

		switch key {
		case "primary":
			t.Primary = value
		case "secondary":
			t.Secondary = value
		case "accent":
			t.Accent = value
		case "success":
			t.Success = value
		case "warning":
			t.Warning = value
		case "error":
			t.Error = value
		case "bg":
			t.Bg = value
		case "surface":
			t.Surface = value
		case "text":
			t.Text = value
		case "muted":
			t.Muted = value
		case "border":
			t.Border = value
		}
	}
}

func trimSpace(s string) string {
	start, end := 0, len(s)
	for start < end && (s[start] == ' ' || s[start] == '\t' || s[start] == '\r') {
		start++
	}
	for end > start && (s[end-1] == ' ' || s[end-1] == '\t' || s[end-1] == '\r') {
		end--
	}
	return s[start:end]
}

func trimQuotes(s string) string {
	if len(s) >= 2 && ((s[0] == '"' && s[len(s)-1] == '"') || (s[0] == '\'' && s[len(s)-1] == '\'')) {
		return s[1 : len(s)-1]
	}
	return s
}

func indexOf(s string, c byte) int {
	for i := range s {
		if s[i] == c {
			return i
		}
	}
	return -1
}

// Theme and style globals
var currentTheme Theme
var (
	titleStyle        lipgloss.Style
	subtitleStyle     lipgloss.Style
	installedStyle    lipgloss.Style
	notInstalledStyle lipgloss.Style
	mutedStyle        lipgloss.Style
	helpKeyStyle      lipgloss.Style
	helpDescStyle     lipgloss.Style
	selectedItemStyle lipgloss.Style
)

func init() {
	reloadTheme("catppuccin-mocha")
}

func reloadTheme(name string) {
	currentTheme = loadTheme(name)

	titleStyle = lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color(currentTheme.Primary)).
		PaddingBottom(1)

	subtitleStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		PaddingBottom(1)

	installedStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Success))

	notInstalledStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted))

	mutedStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted))

	helpKeyStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Secondary)).
		Width(20)

	helpDescStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Text))

	selectedItemStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Primary)).
		Background(lipgloss.Color(currentTheme.Surface)).
		Padding(0, 1)
}

func tc(name string) lipgloss.Color {
	return lipgloss.Color(colorByName(name))
}

func colorByName(name string) string {
	switch name {
	case "primary":
		return currentTheme.Primary
	case "secondary":
		return currentTheme.Secondary
	case "accent":
		return currentTheme.Accent
	case "success":
		return currentTheme.Success
	case "warning":
		return currentTheme.Warning
	case "error":
		return currentTheme.Error
	case "bg":
		return currentTheme.Bg
	case "surface":
		return currentTheme.Surface
	case "text":
		return currentTheme.Text
	case "muted":
		return currentTheme.Muted
	case "border":
		return currentTheme.Border
	}
	return currentTheme.Text
}
