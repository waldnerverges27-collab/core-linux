package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (a *App) updateModuleDetail(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	tools := batchLoadTools(a.selectedModule)
	toolCount := len(tools)

	// Move cursor
	if msg.String() == "up" || msg.String() == "k" {
		if a.toolIndex > 0 {
			a.toolIndex--
		}
	} else if msg.String() == "down" || msg.String() == "j" {
		if toolCount > 0 && a.toolIndex < toolCount-1 {
			a.toolIndex++
		}
	}

	// Recalculate scroll — keep cursor visible
	// Terminal real estate: height - title(3) - statusbar(1) - padding(1) - help(1)
	maxVis := a.height - 6
	if maxVis < 2 {
		maxVis = 2
	}
	if a.toolIndex < a.toolScroll {
		a.toolScroll = a.toolIndex
	}
	if toolCount > 0 && a.toolIndex >= a.toolScroll+maxVis {
		a.toolScroll = a.toolIndex - maxVis + 1
	}
	if a.toolScroll > toolCount-maxVis {
		a.toolScroll = toolCount - maxVis
	}
	if a.toolScroll < 0 {
		a.toolScroll = 0
	}

	switch {
	case keyMatches(msg, "q"):
		return a, tea.Quit
	case keyMatches(msg, "esc"):
		a.toolScroll = 0
		a.currentView = viewModules
	case keyMatches(msg, "i"):
		a.installing = true
		a.installLog = []string{fmt.Sprintf("Installing %s...", a.selectedModule)}
		a.installProgress = 0.0
		a.currentView = viewInstall
		go func(m string) {
			bashRun(fmt.Sprintf("source %s/lib/core/module_manager.sh && module_install '%s'", coreHomeDir(), m))
		}(a.selectedModule)
	case keyMatches(msg, "x"):
		a.installing = true
		a.installLog = []string{fmt.Sprintf("Uninstalling %s...", a.selectedModule)}
		a.installProgress = 0.0
		a.currentView = viewInstall
		go func(m string) {
			bashRun(fmt.Sprintf("source %s/lib/core/module_manager.sh && module_uninstall '%s'", coreHomeDir(), m))
		}(a.selectedModule)
	}
	return a, nil
}

func (a *App) viewModuleDetail() string {
	mod := a.selectedModule
	tools := batchLoadTools(mod)
	inst := batchInstalledState()
	mods := batchLoadModules()

	// Find this module's icon
	icon := ""
	for _, m := range mods {
		if m.Name == mod {
			icon = m.Icon
			break
		}
	}

	var b strings.Builder
	b.WriteString(titleStyle.Render(fmt.Sprintf("%s %s", icon, mod)))
	b.WriteString("\n")

	if len(tools) == 0 {
		b.WriteString("Loading...\n")
		return b.String()
	}

	// Calculate visible range
	// Available lines: height - title(3) - statusbar(1) - padding(1) - help(1) = height-6
	maxVis := a.height - 6
	if maxVis < 2 {
		maxVis = 2
	}
	start := a.toolScroll
	end := start + maxVis
	if end > len(tools) {
		end = len(tools)
	}

	// Show scroll indicator at top
	if start > 0 {
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render("   ... arriba ..."))
		b.WriteString("\n")
	}

	for i, tool := range tools[start:end] {
		absIdx := start + i
		status := "✗"
		statusColor := currentTheme.Muted
		verInfo := ""
		if _, ok := inst[mod]; ok {
			if v, ok2 := inst[mod][tool.Name]; ok2 {
				status = "✔"
				statusColor = currentTheme.Success
				if v != "" {
					verInfo = fmt.Sprintf(" (%s)", v)
				}
			}
		}

		line := fmt.Sprintf(" %s  %s %s — %s%s",
			lipgloss.NewStyle().Foreground(lipgloss.Color(statusColor)).Render(status),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Secondary)).Bold(true).Render(tool.Flag),
			lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(currentTheme.Text)).Render(tool.Name),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(tool.Description),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(verInfo),
		)

		if absIdx == a.toolIndex {
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

	// Show scroll indicator at bottom
	if end < len(tools) {
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render("   ... abajo ..."))
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("↑/↓ navigate • i install • x uninstall • esc back • q quit"))

	return b.String()
}
