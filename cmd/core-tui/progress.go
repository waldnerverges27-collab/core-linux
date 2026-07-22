package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// ProgressModel is an animated progress bar component
type ProgressModel struct {
	Percent float64
	Width   int
	Label   string
}

// NewProgress creates a new progress bar
func NewProgress() ProgressModel {
	return ProgressModel{
		Percent: 0,
		Width:   40,
	}
}

// View renders the progress bar
func (p *ProgressModel) View() string {
	var b strings.Builder

	if p.Label != "" {
		b.WriteString(lipgloss.NewStyle().Foreground(tc("text")).Render(p.Label))
		b.WriteString("\n")
	}

	filled := int(p.Percent * float64(p.Width))
	if filled > p.Width {
		filled = p.Width
	}
	bar := strings.Repeat("█", filled) + strings.Repeat("░", p.Width-filled)
	b.WriteString(lipgloss.NewStyle().Foreground(tc("primary")).Render(bar))
	b.WriteString(fmt.Sprintf(" %3.0f%%", p.Percent*100))

	return b.String()
}

// SetPercent updates the progress value (clamped 0.0–1.0)
func (p *ProgressModel) SetPercent(v float64) {
	if v < 0 {
		v = 0
	}
	if v > 1.0 {
		v = 1.0
	}
	p.Percent = v
}

var _ = fmt.Sprintf
