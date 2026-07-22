package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// Tab represents a single tab
type Tab struct {
	Name  string
	ID    string
	Count int // optional badge count
}

// TabsModel is a horizontal tab bar component
type TabsModel struct {
	Tabs   []Tab
	Active int
}

// NewTabs creates a new tab bar
func NewTabs(tabs []Tab) TabsModel {
	return TabsModel{
		Tabs:   tabs,
		Active: 0,
	}
}

// View renders the tab bar
func (t *TabsModel) View() string {
	var b strings.Builder

	for i, tab := range t.Tabs {
		var style lipgloss.Style
		if i == t.Active {
			style = lipgloss.NewStyle().
				Border(lipgloss.NormalBorder(), false, false, true, false).
				BorderForeground(tc("primary")).
				Bold(true).
				Foreground(tc("text")).
				Padding(0, 2)
		} else {
			style = lipgloss.NewStyle().
				Foreground(tc("muted")).
				Padding(0, 2)
		}

		name := tab.Name
		if tab.Count > 0 {
			name = fmt.Sprintf("%s (%d)", name, tab.Count)
		}

		b.WriteString(style.Render(name))
	}

	b.WriteString("\n")
	b.WriteString(strings.Repeat("─", 80))

	return b.String()
}

// Next activates the next tab
func (t *TabsModel) Next() {
	if t.Active < len(t.Tabs)-1 {
		t.Active++
	}
}

// Prev activates the previous tab
func (t *TabsModel) Prev() {
	if t.Active > 0 {
		t.Active--
	}
}
