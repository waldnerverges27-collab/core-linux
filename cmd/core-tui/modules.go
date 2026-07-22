package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (a *App) updateModules(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	mods := batchLoadModules()
	switch {
	case keyMatches(msg, "q"):
		return a, tea.Quit
	case keyMatches(msg, "esc"):
		a.currentView = viewHome
	case keyMatches(msg, "up", "k"):
		if a.moduleIndex > 0 {
			a.moduleIndex--
		}
	case keyMatches(msg, "down", "j"):
		if len(mods) > 0 && a.moduleIndex < len(mods)-1 {
			a.moduleIndex++
		}
	case keyMatches(msg, "enter"):
		if len(mods) > 0 && a.moduleIndex >= 0 && a.moduleIndex < len(mods) {
			a.selectedModule = mods[a.moduleIndex].Name
			a.toolIndex = 0
			a.currentView = viewModuleDetail
		}
	}
	return a, nil
}

func (a *App) viewModules() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("📦 Module Browser"))
	b.WriteString(subtitleStyle.Render("Select a module to view and install its tools"))
	b.WriteString("\n")

	mods := batchLoadModules()
	inst := batchInstalledState()

	if len(mods) == 0 {
		return a.spinner.View() + " Loading modules..."
	}

	for i, mod := range mods {
		status := "✗"
		statusColor := currentTheme.Muted
		if _, ok := inst[mod.Name]; ok && len(inst[mod.Name]) > 0 {
			status = "✔"
			statusColor = currentTheme.Success
		}

		line := fmt.Sprintf(" %s  %s %s — %s",
			lipgloss.NewStyle().Foreground(lipgloss.Color(statusColor)).Render(status),
			mod.Icon,
			lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(currentTheme.Text)).Render(mod.Name),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(mod.Description),
		)

		if i == a.moduleIndex {
			line = lipgloss.NewStyle().
				Foreground(lipgloss.Color(currentTheme.Primary)).
				Background(lipgloss.Color(currentTheme.Surface)).
				Padding(0, 1).
				Render("▸ " + line)
		}

		b.WriteString(line)
		b.WriteString("\n\n")
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("↑/↓ or j/k navigate • enter select • esc back • q quit"))

	return b.String()
}
