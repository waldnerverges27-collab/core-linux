package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// updateModuleDetail handles key events on the module detail view
func (a *App) updateModuleDetail(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	manifestFile := coreHomeDir() + "/modules/" + a.selectedModule + "/manifest.json"
	toolCountStr := bashOutput(fmt.Sprintf("jq '.tools | length' '%s' 2>/dev/null || echo 0", manifestFile))
	toolCount := 1
	if toolCountStr != "" && toolCountStr != "0" {
		fmt.Sscanf(toolCountStr, "%d", &toolCount)
	}

	switch {
	case keyMatches(msg, "q"):
		return a, tea.Quit
	case keyMatches(msg, "esc"):
		a.currentView = viewModules
	case keyMatches(msg, "up", "k"):
		if a.toolIndex > 0 {
			a.toolIndex--
		}
	case keyMatches(msg, "down", "j"):
		if a.toolIndex < toolCount-1 {
			a.toolIndex++
		}
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

// viewModuleDetail renders a single module with its tools
func (a *App) viewModuleDetail() string {
	mod := a.selectedModule
	manifestFile := coreHomeDir() + "/modules/" + mod + "/manifest.json"

	name := bashOutput(fmt.Sprintf("jq -r '.name // \"%s\"' '%s'", mod, manifestFile))
	version := bashOutput(fmt.Sprintf("jq -r '.version // \"1.0.0\"' '%s'", manifestFile))
	desc := bashOutput(fmt.Sprintf("jq -r '.description // \"\"' '%s'", manifestFile))
	icon := bashOutput(fmt.Sprintf("jq -r '.icon // \"\"' '%s'", manifestFile))
	toolCountStr := bashOutput(fmt.Sprintf("jq '.tools | length' '%s' 2>/dev/null || echo 0", manifestFile))

	var b strings.Builder

	b.WriteString(titleStyle.Render(fmt.Sprintf("%s %s v%s", icon, name, version)))
	b.WriteString(subtitleStyle.Render(desc))
	b.WriteString("\n")

	// Dependencies
	deps := bashOutput(fmt.Sprintf("jq -r '.dependencies | join(\", \")' '%s' 2>/dev/null || echo ''", manifestFile))
	if deps != "" {
		b.WriteString(fmt.Sprintf("🔗 Dependencies: %s\n\n", deps))
	}

	// Tools
	toolCount := 0
	fmt.Sscanf(toolCountStr, "%d", &toolCount)

	for i := 0; i < toolCount; i++ {
		toolName := bashOutput(fmt.Sprintf("jq -r '.tools[%d].name // \"\"' '%s'", i, manifestFile))
		toolFlag := bashOutput(fmt.Sprintf("jq -r '.tools[%d].flag // \"\"' '%s'", i, manifestFile))
		toolDesc := bashOutput(fmt.Sprintf("jq -r '.tools[%d].description // \"\"' '%s'", i, manifestFile))
		toolTags := bashOutput(fmt.Sprintf("jq -r '.tools[%d].tags | join(\", \")' '%s' 2>/dev/null || echo ''", i, manifestFile))

		installed := bashOutput(fmt.Sprintf("source %s/lib/core/state.sh && tool_is_installed '%s' '%s' && echo yes || echo no", coreHomeDir(), mod, toolName))

		statusColor := currentTheme.Muted
		status := "✗"
		if installed == "yes" {
			statusColor = currentTheme.Success
			status = "✔"
		}

		line := fmt.Sprintf(" %s  %s %s — %s",
			lipgloss.NewStyle().Foreground(lipgloss.Color(statusColor)).Render(status),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Secondary)).Bold(true).Render(toolFlag),
			lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(currentTheme.Text)).Render(toolName),
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(toolDesc),
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
		if toolTags != "" {
			b.WriteString(lipgloss.NewStyle().
				Foreground(lipgloss.Color(currentTheme.Muted)).
				Italic(true).
				Render(fmt.Sprintf("     [%s]", toolTags)))
			b.WriteString("\n")
		}
		b.WriteString("\n")
	}

	// Actions
	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("↑/↓ navigate • i install • x uninstall • esc back • q quit"))

	return b.String()
}
