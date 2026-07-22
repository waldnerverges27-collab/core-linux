package main

import (
	"fmt"
	"time"

	"github.com/charmbracelet/lipgloss"
)

// NotificationModel handles toast-style notifications
type NotificationModel struct {
	Message   string
	Type      string // "info", "success", "error"
	Visible   bool
	StartTime time.Time
	Duration  time.Duration
}

// NewNotification creates a new notification manager
func NewNotification() NotificationModel {
	return NotificationModel{
		Duration: 3 * time.Second,
	}
}

// Show displays a notification
func (n *NotificationModel) Show(msg, msgType string) {
	n.Message = msg
	n.Type = msgType
	n.Visible = true
	n.StartTime = time.Now()
}

// View renders the notification if visible
func (n *NotificationModel) View() string {
	if !n.Visible {
		return ""
	}

	if time.Since(n.StartTime) > n.Duration {
		n.Visible = false
		return ""
	}

	color := tc("info")
	switch n.Type {
	case "success":
		color = tc("success")
	case "error":
		color = tc("error")
	case "warning":
		color = tc("warning")
	}

	return lipgloss.NewStyle().
		Foreground(color).
		Background(lipgloss.Color(currentTheme.Surface)).
		Padding(0, 2).
		Render(fmt.Sprintf(" %s ", n.Message))
}

var _ = fmt.Sprintf
