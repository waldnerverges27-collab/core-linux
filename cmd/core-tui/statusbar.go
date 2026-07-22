package main

import (
	"fmt"

	"github.com/charmbracelet/lipgloss"
)

// StatusBarModel is a bottom status bar component
type StatusBarModel struct {
	Left   string
	Center string
	Right  string
	Width  int
}

// NewStatusBar creates a new status bar
func NewStatusBar() StatusBarModel {
	return StatusBarModel{
		Width: 80,
	}
}

// View renders the status bar
func (s *StatusBarModel) View() string {
	left := lipgloss.NewStyle().
		Foreground(tc("muted")).
		Background(lipgloss.Color(currentTheme.Surface)).
		Padding(0, 1).
		Render(s.Left)

	right := lipgloss.NewStyle().
		Foreground(tc("primary")).
		Background(lipgloss.Color(currentTheme.Surface)).
		Render(s.Right)

	center := lipgloss.NewStyle().
		Foreground(tc("secondary")).
		Background(lipgloss.Color(currentTheme.Surface)).
		Render(s.Center)

	padding := s.Width - lipgloss.Width(left) - lipgloss.Width(center) - lipgloss.Width(right)
	if padding < 1 {
		padding = 1
	}

	spaces := lipgloss.NewStyle().
		Background(lipgloss.Color(currentTheme.Surface)).
		Render(fmt.Sprintf("%*s", padding, ""))

	return lipgloss.JoinHorizontal(lipgloss.Top, left, center, spaces, right)
}

// SetContent updates all three sections of the status bar
func (s *StatusBarModel) SetContent(left, center, right string) {
	s.Left = left
	s.Center = center
	s.Right = right
}
