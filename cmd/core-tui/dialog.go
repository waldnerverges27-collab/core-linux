package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// DialogModel is a simple confirm/input dialog component
type DialogModel struct {
	Title   string
	Message string
	Visible bool
	Buttons []string
	Cursor  int
}

// NewDialog creates a new dialog
func NewDialog() DialogModel {
	return DialogModel{
		Visible: false,
		Buttons: []string{"OK", "Cancel"},
		Cursor:  0,
	}
}

// View renders the dialog
func (d *DialogModel) View() string {
	if !d.Visible {
		return ""
	}

	var b strings.Builder
	box := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(tc("primary")).
		Padding(1, 2).
		Width(50)

	content := strings.Builder{}
	if d.Title != "" {
		content.WriteString(titleStyle.Render(d.Title))
		content.WriteString("\n")
	}
	content.WriteString(lipgloss.NewStyle().Foreground(tc("text")).Render(d.Message))
	content.WriteString("\n\n")

	// Buttons
	for i, btn := range d.Buttons {
		if i == d.Cursor {
			content.WriteString(lipgloss.NewStyle().
				Foreground(tc("bg")).
				Background(lipgloss.Color(currentTheme.Primary)).
				Padding(0, 2).
				Render(btn))
		} else {
			content.WriteString(lipgloss.NewStyle().
				Foreground(tc("text")).
				Background(lipgloss.Color(currentTheme.Surface)).
				Padding(0, 2).
				Render(btn))
		}
		if i < len(d.Buttons)-1 {
			content.WriteString(" ")
		}
	}

	b.WriteString(box.Render(content.String()))
	return b.String()
}

// Confirm shows a confirmation dialog and returns true if accepted
func (d *DialogModel) Confirm(title, message string) bool {
	d.Title = title
	d.Message = message
	d.Visible = true
	d.Buttons = []string{"Yes", "No"}
	d.Cursor = 0
	return d.Cursor == 0
}
