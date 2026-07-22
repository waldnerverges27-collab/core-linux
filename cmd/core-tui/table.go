package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// TableRow represents a row of data
type TableRow []string

// TableModel is a data table component
type TableModel struct {
	Headers []string
	Rows    []TableRow
	Cursor  int
	Widths  []int
}

// NewTable creates a new table
func NewTable(headers []string) TableModel {
	widths := make([]int, len(headers))
	for i, h := range headers {
		widths[i] = len(h) + 2
	}
	return TableModel{
		Headers: headers,
		Widths:  widths,
	}
}

// AddRow adds a row to the table
func (t *TableModel) AddRow(row TableRow) {
	if len(row) > len(t.Widths) {
		// Extend widths
		newWidths := make([]int, len(row))
		copy(newWidths, t.Widths)
		for i := len(t.Widths); i < len(row); i++ {
			newWidths[i] = len(row[i]) + 2
		}
		t.Widths = newWidths
	}
	for i, cell := range row {
		if i < len(t.Widths) && len(cell)+2 > t.Widths[i] {
			t.Widths[i] = len(cell) + 2
		}
	}
	t.Rows = append(t.Rows, row)
}

// View renders the table
func (t *TableModel) View() string {
	var b strings.Builder

	// Header
	for i, h := range t.Headers {
		style := lipgloss.NewStyle().
			Bold(true).
			Foreground(tc("primary")).
			Width(t.Widths[i])
		b.WriteString(style.Render(h))
	}
	b.WriteString("\n")

	// Separator
	for i := range t.Headers {
		b.WriteString(strings.Repeat("─", t.Widths[i]))
	}
	b.WriteString("\n")

	// Rows
	for ri, row := range t.Rows {
		cursor := " "
		if ri == t.Cursor {
			cursor = "▸"
		}
		b.WriteString(lipgloss.NewStyle().Foreground(tc("secondary")).Render(cursor))
		for ci, cell := range row {
			if ci >= len(t.Widths) {
				break
			}
			color := tc("text")
			if ri == t.Cursor {
				color = tc("primary")
			}
			style := lipgloss.NewStyle().Foreground(color).Width(t.Widths[ci])
			b.WriteString(style.Render(cell))
		}
		b.WriteString("\n")
	}

	return b.String()
}

var _ = fmt.Sprintf
