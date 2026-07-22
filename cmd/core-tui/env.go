package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// updateEnv handles key events on the env manager view
func (a *App) updateEnv(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case keyMatches(msg, "q"):
		return a, tea.Quit
	case keyMatches(msg, "esc"):
		a.currentView = viewHome
	case keyMatches(msg, "1"):
		// Set variable — launch via core CLI
		go func() {
			bashRun(fmt.Sprintf("source %s/lib/core/env_manager.sh && env_set", coreHomeDir()))
		}()
	case keyMatches(msg, "2"):
		// Unset variable
		go func() {
			bashRun(fmt.Sprintf("source %s/lib/core/env_manager.sh && env_unset", coreHomeDir()))
		}()
	}
	return a, nil
}

// viewEnv renders the environment variable manager
func (a *App) viewEnv() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("🔑 Environment Variables"))
	b.WriteString(subtitleStyle.Render("Manage your shell environment variables"))
	b.WriteString("\n")

	// Get current vars from rc file
	rcFile := bashOutput("source " + coreHomeDir() + "/lib/utils/platform.sh && detect_shell_rc")
	vars := bashOutput(fmt.Sprintf("grep -E '^export [a-zA-Z_]+=' '%s' 2>/dev/null || true", rcFile))

	b.WriteString(fmt.Sprintf(" Shell rc: %s\n\n", rcFile))

	if vars != "" {
		b.WriteString(lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color(currentTheme.Secondary)).
			Render("Current Variables"))
		b.WriteString("\n\n")

		for _, v := range strings.Split(vars, "\n") {
			if v == "" {
				continue
			}
			v = strings.TrimPrefix(v, "export ")
			parts := strings.SplitN(v, "=", 2)
			if len(parts) == 2 {
				name := parts[0]
				val := parts[1]
				val = strings.Trim(val, "\"")
				// Mask value for display
				masked := "****"
				if len(val) > 10 {
					masked = val[:3] + "..." + val[len(val)-3:]
				} else if len(val) > 0 {
					masked = "****"
				}
				b.WriteString(fmt.Sprintf("  %s = %s\n",
					lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(currentTheme.Text)).Render(name),
					lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(masked),
				))
			}
		}
	} else {
		b.WriteString("  No environment variables set\n")
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("1 set variable • 2 unset variable • esc back • q quit"))

	return b.String()
}
