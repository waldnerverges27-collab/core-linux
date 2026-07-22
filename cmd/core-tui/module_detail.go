package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (a *App) updateModuleDetail(msg tea.KeyMsg) viewID {
	tools := batchLoadTools(a.selectedModule)
	toolCount := len(tools)

	// Delegate scroll to viewport
	var cmd tea.Cmd
	a.vp, cmd = a.vp.Update(msg)
	if cmd != nil {
		tea.Batch(cmd)
	}

	// Move cursor
	if keyMatches(msg, "up", "k") {
		if a.toolIndex > 0 {
			a.toolIndex--
		}
	}
	if keyMatches(msg, "down", "j") {
		if toolCount > 0 && a.toolIndex < toolCount-1 {
			a.toolIndex++
		}
	}

	switch {
	case keyMatches(msg, "q"):
		return a.currentView
	case keyMatches(msg, "esc"):
		a.vp.GotoTop()
		return viewModules
	case keyMatches(msg, "i"):
		a.installing = true
		a.installLog = []string{fmt.Sprintf("Installing %s...", a.selectedModule)}
		a.installProgress = 0.0
		a.currentView = viewInstall
		go func(m string) {
			coreCLI("install", m)
		}(a.selectedModule)
		return viewInstall
	case keyMatches(msg, "x"):
		a.installing = true
		a.installLog = []string{fmt.Sprintf("Uninstalling %s...", a.selectedModule)}
		a.installProgress = 0.0
		a.currentView = viewInstall
		go func(m string) {
			coreCLI("uninstall", m)
		}(a.selectedModule)
		return viewInstall
	}
	return viewModuleDetail
}

// renderToolDetailContent returns the FULL tool list (viewport clips it)
func (a *App) renderToolDetailContent(tools []ToolEntry) string {
	var b strings.Builder

	if len(tools) == 0 {
		return a.spinner.View() + " Loading tools...\n"
	}

	// Si las versiones no están listas, mostrar spinner
	if !a.toolVersionsReady {
		return a.spinner.View() + " Detecting installed tools...\n"
	}

	for i, tool := range tools {
		status := "✗"
		statusColor := currentTheme.Muted
		verInfo := ""
		// Usar detección real (command -v + --version)
		if v, ok := a.toolVersions[tool.Name]; ok && v != "" {
			status = "✔"
			statusColor = currentTheme.Success
			verInfo = fmt.Sprintf(" (%s)", v)
		}

		line := fmt.Sprintf(" %s  %s %s — %s%s",
			lipgloss.NewStyle().Foreground(lipgloss.Color(statusColor)).Render(status),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Secondary)).Bold(true).Render(tool.Flag),
			lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(currentTheme.Text)).Render(tool.Name),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(tool.Description),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(verInfo),
		)

		if i == a.toolIndex {
			line = lipgloss.NewStyle().
				Foreground(lipgloss.Color(currentTheme.Primary)).
				Background(lipgloss.Color(currentTheme.Surface)).
				Padding(0, 1).
				Render("▸ " + line)
		}

		b.WriteString(line)
		b.WriteString("\n")
		if len(tool.Tags) > 0 {
			b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Italic(true).
				Render(fmt.Sprintf("     [%s]", strings.Join(tool.Tags, ", "))))
			b.WriteString("\n")
		}
	}

	b.WriteString("\n")
	b.WriteString(mutedStyle.Render("↑/↓ scroll • i install • x uninstall • esc back • q quit"))
	return b.String()
}
