package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// viewInstall renders the install/uninstall progress view
func (a *App) viewInstall() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("⚙️ Operations"))
	b.WriteString("\n")

	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Text)).Render("Running..."))
	b.WriteString("\n\n")

	// Progress bar
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
		Render("Press q to return to modules when complete"))

	return b.String()
}
