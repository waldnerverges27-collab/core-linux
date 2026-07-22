package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (a *App) updateEnv(msg tea.KeyMsg) viewID {
	switch {
	case keyMatches(msg, "q"):
		return viewHome
	case keyMatches(msg, "esc"):
		return viewHome
	case keyMatches(msg, "1"):
		go func() {
			bashRun(fmt.Sprintf("source %s/lib/core/env_manager.sh && env_set", coreHomeDir()))
		}()
	case keyMatches(msg, "2"):
		go func() {
			bashRun(fmt.Sprintf("source %s/lib/core/env_manager.sh && env_unset", coreHomeDir()))
		}()
	}
	return viewEnv
}

func (a *App) viewEnv() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("🔑 Environment Variables"))
	b.WriteString(subtitleStyle.Render("Manage your shell environment variables"))
	b.WriteString("\n")

	rcFile := bashOutput("source " + coreHomeDir() + "/lib/utils/platform.sh && detect_shell_rc")
	vars := bashOutput(fmt.Sprintf("grep -E '^export [a-zA-Z_]+=' '%s' 2>/dev/null || true", rcFile))

	b.WriteString(fmt.Sprintf(" Shell rc: %s\n\n", rcFile))

	if vars != "" {
		b.WriteString(lipgloss.NewStyle().Bold(true).Foreground(tc("secondary")).Render("Current Variables"))
		b.WriteString("\n\n")
		for _, v := range strings.Split(vars, "\n") {
			if v == "" {
				continue
			}
			v = strings.TrimPrefix(v, "export ")
			parts := strings.SplitN(v, "=", 2)
			if len(parts) == 2 {
				name := parts[0]
				val := strings.Trim(parts[1], "\"")
				masked := "****"
				if len(val) > 10 {
					masked = val[:3] + "..." + val[len(val)-3:]
				} else if len(val) > 0 {
					masked = "****"
				}
				b.WriteString(fmt.Sprintf("  %s = %s\n",
					lipgloss.NewStyle().Bold(true).Foreground(tc("text")).Render(name),
					lipgloss.NewStyle().Foreground(tc("muted")).Render(masked),
				))
			}
		}
	} else {
		b.WriteString("  No environment variables set\n")
	}

	b.WriteString("\n")
	b.WriteString(mutedStyle.Render("1 set • 2 unset • esc back • q quit"))
	return b.String()
}
