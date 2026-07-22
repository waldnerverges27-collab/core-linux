package main

import (
	"fmt"

	"github.com/charmbracelet/lipgloss"
)

func (a *App) renderHelpContent() string {
	var b string

	sections := []struct {
		title string
		items [][2]string
	}{
		{"Global", [][2]string{
			{"q", "Quit application"},
			{"?", "Toggle help overlay"},
			{"esc", "Go back to previous view"},
		}},
		{"Navigation", [][2]string{
			{"↑/↓ or j/k", "Scroll content"},
			{"PgUp/PgDn", "Page up / page down"},
			{"enter", "Confirm selection"},
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
		}},
	}

	for _, section := range sections {
		b += lipgloss.NewStyle().Bold(true).Foreground(tc("primary")).Render(fmt.Sprintf("  %s", section.title)) + "\n"
		for _, item := range section.items {
			b += fmt.Sprintf("    %s  %s\n",
				lipgloss.NewStyle().Foreground(tc("secondary")).Width(18).Render(item[0]),
				lipgloss.NewStyle().Foreground(tc("text")).Render(item[1]),
			)
		}
		b += "\n"
	}

	b += lipgloss.NewStyle().Bold(true).Foreground(tc("primary")).Render("  CLI Reference") + "\n\n"
	cliRef := [][2]string{
		{"core", "Launch TUI"},
		{"core install <mod>", "Install module/tools"},
		{"core uninstall <mod>", "Remove module/tools"},
		{"core list", "List modules"},
		{"core show <name>", "Show details"},
		{"core env ls", "Show env variables"},
		{"core brain ls", "Second brain"},
		{"core init", "Project setup"},
	}
	for _, item := range cliRef {
		b += fmt.Sprintf("    %s  %s\n",
			lipgloss.NewStyle().Foreground(tc("secondary")).Width(35).Render(item[0]),
			lipgloss.NewStyle().Foreground(tc("text")).Render(item[1]),
		)
	}

	b += "\n" + mutedStyle.Render("  ? or esc to close help • q to quit")
	return b
}
