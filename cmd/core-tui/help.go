package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// viewHelp renders the help overlay with all keybindings
func (a *App) viewHelp() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("⌨️ Help & Keybindings"))
	b.WriteString("\n")

	// Navigation
	sections := []struct {
		title string
		items [][2]string // key, description
	}{
		{"Global", [][2]string{
			{"q", "Quit application"},
			{"?", "Toggle help overlay"},
			{"esc", "Go back to previous view"},
		}},
		{"Navigation", [][2]string{
			{"↑/↓ or j/k", "Move selection up/down"},
			{"enter", "Confirm selection"},
			{"tab", "Switch between views"},
		}},
		{"Home Screen", [][2]string{
			{"1", "Open module browser"},
			{"2", "Open environment manager"},
			{"3", "Open second brain"},
			{"4", "Open settings"},
		}},
		{"Module Detail", [][2]string{
			{"i", "Install selected module/tool"},
			{"x", "Uninstall selected module/tool"},
			{"u", "Update module"},
		}},
		{"Quick Access", [][2]string{
			{"s", "Open settings from anywhere"},
			{"b", "Open brain from anywhere"},
			{"e", "Open env manager from anywhere"},
		}},
	}

	for _, section := range sections {
		b.WriteString(lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color(currentTheme.Primary)).
			Render(fmt.Sprintf("  %s", section.title)))
		b.WriteString("\n")
		for _, item := range section.items {
			b.WriteString(fmt.Sprintf("    %s  %s\n",
				lipgloss.NewStyle().
					Foreground(lipgloss.Color(currentTheme.Secondary)).
					Width(18).
					Render(item[0]),
				lipgloss.NewStyle().
					Foreground(lipgloss.Color(currentTheme.Text)).
					Render(item[1]),
			))
		}
		b.WriteString("\n")
	}

	// CLI Reference
	b.WriteString(lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color(currentTheme.Primary)).
		Render("  CLI Reference"))
	b.WriteString("\n\n")
	cliRef := [][2]string{
		{"core", "Launch TUI"},
		{"core install <mod> [--tool]", "Install module/tools"},
		{"core uninstall <mod> [--tool]", "Remove module/tools"},
		{"core list [module]", "List modules or tools"},
		{"core show <name>", "Show module/tool details"},
		{"core env set|unset|ls", "Manage environment variables"},
		{"core brain save|search|ls", "Second brain system"},
		{"core init", "Interactive project setup"},
		{"core --version", "Show version"},
	}
	for _, item := range cliRef {
		b.WriteString(fmt.Sprintf("    %s  %s\n",
			lipgloss.NewStyle().
				Foreground(lipgloss.Color(currentTheme.Secondary)).
				Width(35).
				Render(item[0]),
			lipgloss.NewStyle().
				Foreground(lipgloss.Color(currentTheme.Text)).
				Render(item[1]),
		))
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("  Press ? or esc to close help • q to quit"))

	return b.String()
}

// Ensure strings is used
var _ = strings.ToUpper
