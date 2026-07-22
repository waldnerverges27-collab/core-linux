package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// updateModules handles key events on the modules browser view
func (a *App) updateModules(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
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
		if len(a.modules) > 0 && a.moduleIndex < len(a.modules)-1 {
			a.moduleIndex++
		}
	case keyMatches(msg, "enter"):
		if len(a.modules) > 0 && a.moduleIndex >= 0 && a.moduleIndex < len(a.modules) {
			a.selectedModule = a.modules[a.moduleIndex]
			a.toolIndex = 0
			a.currentView = viewModuleDetail
		}
	}
	return a, nil
}

// viewModules renders the module browser
func (a *App) viewModules() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("📦 Module Browser"))
	b.WriteString(subtitleStyle.Render("Select a module to view and install its tools"))
	b.WriteString("\n")

	if len(a.modules) == 0 {
		return a.spinner.View() + " Loading modules..."
	}

	for i, mod := range a.modules {
		// Get module info from manifest
		manifestFile := coreHomeDir() + "/modules/" + mod + "/manifest.json"
		icon := bashOutput(fmt.Sprintf("jq -r '.icon // \"\"' '%s' 2>/dev/null || echo ''", manifestFile))
		desc := bashOutput(fmt.Sprintf("jq -r '.description // \"\"' '%s' 2>/dev/null || echo ''", manifestFile))
		status := bashOutput(fmt.Sprintf("source %s/lib/core/state.sh && module_is_installed %s && echo '✔' || echo '✗'", coreHomeDir(), mod))

		statusColor := currentTheme.Muted
		if status == "✔" {
			statusColor = currentTheme.Success
		}

		line := fmt.Sprintf(" %s  %s %s — %s",
			lipgloss.NewStyle().Foreground(lipgloss.Color(statusColor)).Render(status),
			icon,
			lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(currentTheme.Text)).Render(mod),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(desc),
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

	// Navigation hints
	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("↑/↓ or j/k navigate • enter select • esc back • q quit"))

	return b.String()
}
