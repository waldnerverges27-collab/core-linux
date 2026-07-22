package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (a *App) updateModules(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	mods := batchLoadModules()
	total := len(mods)

	// Move cursor
	if keyMatches(msg, "up", "k") {
		if a.moduleIndex > 0 {
			a.moduleIndex--
		}
	}
	if keyMatches(msg, "down", "j") {
		if total > 0 && a.moduleIndex < total-1 {
			a.moduleIndex++
		}
	}

	// Keep cursor in scroll view
	maxVis := a.height - 6
	if maxVis < 3 {
		maxVis = 3
	}
	if a.moduleIndex < a.moduleScroll {
		a.moduleScroll = a.moduleIndex
	}
	if a.moduleIndex >= a.moduleScroll+maxVis {
		a.moduleScroll = a.moduleIndex - maxVis + 1
	}
	if a.moduleScroll < 0 {
		a.moduleScroll = 0
	}
	if a.moduleScroll > total-maxVis {
		a.moduleScroll = total - maxVis
	}
	if a.moduleScroll < 0 {
		a.moduleScroll = 0
	}

	switch {
	case keyMatches(msg, "q"):
		return a, tea.Quit
	case keyMatches(msg, "esc"):
		a.moduleScroll = 0
		a.currentView = viewHome
	case keyMatches(msg, "enter"):
		if total > 0 && a.moduleIndex >= 0 && a.moduleIndex < total {
			a.selectedModule = mods[a.moduleIndex].Name
			a.toolIndex = 0
			a.toolScroll = 0
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

	// Calculate visible range
	maxVis := a.height - 6
	if maxVis < 3 {
		maxVis = 3
	}
	start := a.moduleScroll
	end := start + maxVis
	if end > len(mods) {
		end = len(mods)
	}

	if start > 0 {
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render("   ... arriba ..."))
		b.WriteString("\n\n")
	}

	for i, mod := range mods[start:end] {
		absIdx := start + i
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

		if absIdx == a.moduleIndex {
			line = lipgloss.NewStyle().
				Foreground(lipgloss.Color(currentTheme.Primary)).
				Background(lipgloss.Color(currentTheme.Surface)).
				Padding(0, 1).
				Render("▸ " + line)
		}

		b.WriteString(line)
		b.WriteString("\n\n")
	}

	if end < len(mods) {
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render("   ... abajo ..."))
		b.WriteString("\n\n")
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("↑/↓ or j/k navigate • enter select • esc back • q quit"))

	return b.String()
}
