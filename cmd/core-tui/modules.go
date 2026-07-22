package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (a *App) updateModules(msg tea.KeyMsg) viewID {
	mods := batchLoadModules()
	total := len(mods)

	// Delegate scroll to viewport
	var cmd tea.Cmd
	a.vp, cmd = a.vp.Update(msg)
	if cmd != nil {
		tea.Batch(cmd)
	}

	// Arrow keys: move cursor and ensure viewport shows it
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

	switch {
	case keyMatches(msg, "q"):
		return a.currentView // handled by global quit
	case keyMatches(msg, "esc"):
		a.vp.GotoTop()
		return viewHome
	case keyMatches(msg, "enter"):
		if total > 0 && a.moduleIndex >= 0 && a.moduleIndex < total {
			a.selectedModule = mods[a.moduleIndex].Name
			a.toolIndex = 0
			a.vp.GotoTop()
			return viewModuleDetail
		}
	}
	return viewModules
}

// renderModulesContent returns the FULL module list (viewport will clip it)
func (a *App) renderModulesContent() string {
	var b strings.Builder
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
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(mutedStyle.Render("↑/↓ scroll • enter select • esc back • q quit"))
	return b.String()
}
