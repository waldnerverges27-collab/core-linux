package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// installDoneMsg signals that an install/uninstall operation finished
type installDoneMsg struct {
	module  string
	action  string
	success bool
	output  string
}

// runInstallCmd returns a tea.Cmd that runs 'core install/uninstall' in background
// and sends installDoneMsg when finished (non-blocking for the TUI)
func (a *App) runInstallCmd(action, module string) tea.Cmd {
	return func() tea.Msg {
		var err error
		if action == "install" {
			err = coreCLI("install", module)
		} else {
			err = coreCLI("uninstall", module)
		}
		output := ""
		success := err == nil
		if err != nil {
			output = err.Error()
		}
		return installDoneMsg{
			module:  module,
			action:  action,
			success: success,
			output:  output,
		}
	}
}

// viewInstall renders the install/uninstall progress view
func (a *App) viewInstall() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("⚙️ Operations"))
	b.WriteString("\n")

	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Text)).Render("Running..."))
	b.WriteString("\n\n")

	// Animated progress bar (indeterminate — shows activity)
	barWidth := 40
	filled := int(a.installProgress * float64(barWidth))
	bar := strings.Repeat("█", filled) + strings.Repeat("░", barWidth-filled)
	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Primary)).
		Render(bar))
	b.WriteString(fmt.Sprintf(" %d%%\n\n", int(a.installProgress*100)))

	// Log output
	for _, line := range a.installLog {
		b.WriteString(line)
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("Processing... please wait"))

	return b.String()
}
