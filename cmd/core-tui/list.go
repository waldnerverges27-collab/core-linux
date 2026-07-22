package main

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ListItem represents an item in a selectable list
type ListItem struct {
	Title       string
	Description string
	Icon        string
	Selected    bool
}

// ListModel is a generic selectable list component
type ListModel struct {
	Items    []ListItem
	Index    int
	Title    string
	ShowHelp bool
}

// NewList creates a new list
func NewList(title string, items []ListItem) ListModel {
	return ListModel{
		Items:    items,
		Index:    0,
		Title:    title,
		ShowHelp: true,
	}
}

// Update handles key events for the list
func (l *ListModel) Update(msg tea.KeyMsg) {
	switch {
	case keyMatches(msg, "up", "k"):
		if l.Index > 0 {
			l.Index--
		}
	case keyMatches(msg, "down", "j"):
		if l.Index < len(l.Items)-1 {
			l.Index++
		}
	}
}

// View renders the list
func (l *ListModel) View() string {
	var b strings.Builder

	if l.Title != "" {
		b.WriteString(titleStyle.Render(l.Title))
		b.WriteString("\n")
	}

	for i, item := range l.Items {
		icon := item.Icon
		if icon == "" {
			icon = " "
		}

		status := " "
		if item.Selected {
			status = "●"
		}

		line := " " + lipgloss.NewStyle().Foreground(tc("secondary")).Render(status) +
			" " + icon + " " +
			lipgloss.NewStyle().Foreground(tc("text")).Render(item.Title)

		if item.Description != "" {
			line += lipgloss.NewStyle().Foreground(tc("muted")).Render(" — " + item.Description)
		}

		if i == l.Index {
			line = selectedItemStyle.Render("▸ " + line)
		}

		b.WriteString(line)
		b.WriteString("\n\n")
	}

	if l.ShowHelp && len(l.Items) > 0 {
		b.WriteString(mutedStyle.Render("↑/↓ navigate • enter select"))
	}

	return b.String()
}

// SelectedItem returns the currently selected item
func (l *ListModel) SelectedItem() *ListItem {
	if l.Index >= 0 && l.Index < len(l.Items) {
		return &l.Items[l.Index]
	}
	return nil
}
