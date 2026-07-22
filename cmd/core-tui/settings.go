package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// updateSettings handles key events on the settings view
func (a *App) updateSettings(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case keyMatches(msg, "q"):
		return a, tea.Quit
	case keyMatches(msg, "esc"):
		a.currentView = viewHome
	case keyMatches(msg, "up", "k"):
		if a.settingsCursor > 0 {
			a.settingsCursor--
		}
	case keyMatches(msg, "down", "j"):
		if a.settingsCursor < len(a.themeOptions)-1 {
			a.settingsCursor++
		}
	case keyMatches(msg, "enter"):
		if a.settingsCursor >= 0 && a.settingsCursor < len(a.themeOptions) {
			theme := a.themeOptions[a.settingsCursor]
			reloadTheme(theme)
		}
	}
	return a, nil
}

// viewSettings renders the settings/theme picker
func (a *App) viewSettings() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("⚙️ Settings"))
	b.WriteString(subtitleStyle.Render("Select a theme • Reopen TUI to apply fully"))
	b.WriteString("\n")

	// Theme section
	b.WriteString(lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color(currentTheme.Secondary)).
		Render("Theme Picker"))
	b.WriteString("\n\n")

	for i, theme := range a.themeOptions {
		line := fmt.Sprintf("  %s",
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Text)).Render(theme),
		)

		if i == a.settingsCursor {
			line = "▸ " + lipgloss.NewStyle().
				Foreground(lipgloss.Color(currentTheme.Primary)).
				Background(lipgloss.Color(currentTheme.Surface)).
				Padding(0, 1).
				Render(theme)
		}

		b.WriteString(line)
		b.WriteString("\n\n")
	}

	// Color preview
	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color(currentTheme.Secondary)).
		Render("Color Preview"))
	b.WriteString("\n\n")

	preview := lipgloss.JoinHorizontal(lipgloss.Center,
		colorSwatch(currentTheme.Primary, "Primary"),
		colorSwatch(currentTheme.Secondary, "Secondary"),
		colorSwatch(currentTheme.Accent, "Accent"),
		colorSwatch(currentTheme.Success, "Success"),
		colorSwatch(currentTheme.Warning, "Warning"),
	)
	b.WriteString(preview)
	b.WriteString("\n\n")

	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("↑/↓ change theme • enter apply • esc back • q quit"))

	return b.String()
}

func colorSwatch(color, label string) string {
	return lipgloss.NewStyle().
		Background(lipgloss.Color(color)).
		Foreground(lipgloss.Color("#000000")).
		Padding(0, 2).
		MarginRight(1).
		Render(label)
}
