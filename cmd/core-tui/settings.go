package main

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (a *App) updateSettings(msg tea.KeyMsg) viewID {
	switch {
	case keyMatches(msg, "q"):
		return viewHome
	case keyMatches(msg, "esc"):
		return viewHome
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
	return viewSettings
}

func (a *App) viewSettings() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("⚙️ Settings"))
	b.WriteString(subtitleStyle.Render("Select a theme • Reopen TUI to apply fully"))
	b.WriteString("\n")

	b.WriteString(lipgloss.NewStyle().Bold(true).Foreground(tc("secondary")).Render("Theme Picker"))
	b.WriteString("\n\n")

	for i, theme := range a.themeOptions {
		line := "  " + lipgloss.NewStyle().Foreground(tc("text")).Render(theme)
		if i == a.settingsCursor {
			line = "▸ " + selectedItemStyle.Render(theme)
		}
		b.WriteString(line)
		b.WriteString("\n\n")
	}

	preview := lipgloss.JoinHorizontal(lipgloss.Center,
		colorSwatch(currentTheme.Primary, "Primary"),
		colorSwatch(currentTheme.Secondary, "Secondary"),
		colorSwatch(currentTheme.Accent, "Accent"),
		colorSwatch(currentTheme.Success, "Success"),
		colorSwatch(currentTheme.Warning, "Warning"),
	)
	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Bold(true).Foreground(tc("secondary")).Render("Color Preview"))
	b.WriteString("\n\n")
	b.WriteString(preview)
	b.WriteString("\n\n")

	b.WriteString(mutedStyle.Render("↑/↓ theme • enter apply • esc back • q quit"))
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
