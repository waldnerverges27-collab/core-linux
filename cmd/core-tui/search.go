package main

import (
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// SearchModel is a fuzzy search input component
type SearchModel struct {
	Input    textinput.Model
	Active   bool
	Results  []string
	Cursor   int
	OnSearch func(string) []string
}

// NewSearch creates a new search input
func NewSearch() SearchModel {
	ti := textinput.New()
	ti.Placeholder = "Search..."
	ti.CharLimit = 100
	ti.Width = 40

	return SearchModel{
		Input:  ti,
		Active: false,
	}
}

// Focus activates the search input
func (s *SearchModel) Focus() tea.Cmd {
	s.Active = true
	return s.Input.Focus()
}

// Blur deactivates the search input
func (s *SearchModel) Blur() {
	s.Active = false
	s.Input.Blur()
}

// View renders the search input and results
func (s *SearchModel) View() string {
	var b strings.Builder

	if !s.Active {
		return b.String()
	}

	b.WriteString(lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(tc("primary")).
		Padding(0, 1).
		Render(s.Input.View()))
	b.WriteString("\n")

	if len(s.Results) > 0 {
		b.WriteString("\n")
		for i, r := range s.Results {
			style := lipgloss.NewStyle().Foreground(tc("text"))
			if i == s.Cursor {
				style = selectedItemStyle
			}
			b.WriteString(style.Render(" " + r))
			b.WriteString("\n")
		}
	}

	return b.String()
}

// Clear resets the search
func (s *SearchModel) Clear() {
	s.Input.SetValue("")
	s.Results = nil
	s.Cursor = 0
}
