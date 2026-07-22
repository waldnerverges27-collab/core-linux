package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (a *App) updateBrain(msg tea.KeyMsg) viewID {
	// Forward scroll events to viewport
	var cmd tea.Cmd
	a.vp, cmd = a.vp.Update(msg)
	if cmd != nil {
		tea.Batch(cmd)
	}

	switch {
	case keyMatches(msg, "q"):
		return viewHome
	case keyMatches(msg, "esc"):
		return viewHome
	case keyMatches(msg, "1"):
		a.brainMode = "save"
		a.brainSearch.Focus()
		a.brainSearch.Placeholder = "Memory title..."
		return viewBrain
	case keyMatches(msg, "2"):
		a.brainMode = "search"
		a.brainSearch.Focus()
		a.brainSearch.Placeholder = "Search term..."
		return viewBrain
	case keyMatches(msg, "3"):
		a.brainMode = "list"
	}
	return viewBrain
}

func (a *App) renderBrainContent() string {
	var b strings.Builder

	brainDir := coreHomeDir() + "/brain"
	count := bashOutput(fmt.Sprintf("find '%s' -name '*.md' 2>/dev/null | wc -l", brainDir))
	if count == "" {
		count = "0"
	}

	b.WriteString(fmt.Sprintf(" Memories: %s\n\n", count))

	actions := []string{
		"1. Save memory",
		"2. Search memories",
		"3. List all memories",
	}
	for _, act := range actions {
		b.WriteString(lipgloss.NewStyle().Foreground(tc("text")).Render(act))
		b.WriteString("\n\n")
	}

	if a.brainMode == "search" || a.brainMode == "save" {
		b.WriteString(a.brainSearch.View())
		b.WriteString("\n")
	}

	if a.brainMode == "list" || count != "0" {
		memories := bashOutput(fmt.Sprintf("ls '%s'/*/*.md 2>/dev/null | head -10 || true", brainDir))
		if memories != "" {
			b.WriteString(lipgloss.NewStyle().Bold(true).Foreground(tc("secondary")).Render("Recent Memories"))
			b.WriteString("\n\n")
			for _, mem := range strings.Split(memories, "\n") {
				if mem == "" {
					continue
				}
				title := bashOutput(fmt.Sprintf("head -5 '%s' | grep '^title:' | cut -d'\"' -f2", mem))
				if title == "" {
					title = strings.TrimSuffix(mem, ".md")
				}
				b.WriteString(fmt.Sprintf("  📝 %s\n", title))
			}
		}
	}

	b.WriteString("\n")
	b.WriteString(mutedStyle.Render("1 save • 2 search • 3 list • esc back • q quit"))
	return b.String()
}
