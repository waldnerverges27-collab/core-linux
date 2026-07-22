package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Helper to run bash and get output
func bashOutput(cmd string) string {
	c := exec.Command("bash", "-c", cmd)
	out, err := c.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func bashRun(cmd string) error {
	c := exec.Command("bash", "-c", cmd)
	return c.Run()
}

func corePath() string {
	if h := os.Getenv("CORE_HOME"); h != "" {
		return h + "/core"
	}
	return os.Getenv("HOME") + "/.local/share/core-linux/core"
}

func coreHomeDir() string {
	if h := os.Getenv("CORE_HOME"); h != "" {
		return h
	}
	return os.Getenv("HOME") + "/.local/share/core-linux"
}

func keyMatches(msg tea.KeyMsg, keys ...string) bool {
	for _, k := range keys {
		if msg.String() == k {
			return true
		}
	}
	return false
}

// updateHome handles key events on the home view
func (a *App) updateHome(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case keyMatches(msg, "q"):
		return a, tea.Quit
	case keyMatches(msg, "1"):
		a.currentView = viewModules
	case keyMatches(msg, "2"):
		a.currentView = viewEnv
	case keyMatches(msg, "3"):
		a.currentView = viewBrain
	case keyMatches(msg, "4"):
		a.currentView = viewSettings
	case keyMatches(msg, "s"):
		a.currentView = viewSettings
	case keyMatches(msg, "b"):
		a.currentView = viewBrain
	case keyMatches(msg, "e"):
		a.currentView = viewEnv
	case keyMatches(msg, "enter"):
		a.currentView = viewModules
	}
	return a, nil
}

// viewHome renders the main dashboard
func (a *App) viewHome() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("core-linux"))
	b.WriteString(subtitleStyle.Render("Modular Development Environment"))
	b.WriteString("\n")

	// Get counts
	modCount := len(a.modules)
	instCountStr := bashOutput(fmt.Sprintf("source %s/lib/core/state.sh && get_installed_modules | wc -l", coreHomeDir()))
	instCount := "0"
	if instCountStr != "" {
		instCount = instCountStr
	}

	// Platform
	distro := bashOutput("source " + coreHomeDir() + "/lib/utils/platform.sh && detect_distro")

	// Stats row
	statsRow := lipgloss.JoinHorizontal(lipgloss.Top,
		statCard("Modules", fmt.Sprintf("%d", modCount), currentTheme.Secondary),
		statCard("Installed", instCount, currentTheme.Success),
		statCard("Platform", distro, currentTheme.Muted),
	)
	b.WriteString(statsRow)
	b.WriteString("\n\n")

	// Quick actions menu
	actions := []struct {
		key, icon, label, desc string
	}{
		{"1", "📦", "Modules", "Browse and install development modules"},
		{"2", "🔑", "Environment", "Manage environment variables"},
		{"3", "🧠", "Brain", "Second brain memory system"},
		{"4", "⚙️", "Settings", "Configure themes and preferences"},
	}

	for _, act := range actions {
		line := lipgloss.NewStyle().
			Foreground(lipgloss.Color(currentTheme.Secondary)).
			Bold(true).
			Render(act.key+". ") +
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Text)).Render(act.icon+" "+act.label) +
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(" — "+act.desc)
		b.WriteString(line)
		b.WriteString("\n\n")
	}

	b.WriteString(lipgloss.NewStyle().
		Foreground(lipgloss.Color(currentTheme.Muted)).
		Render("Press ? for help • q to quit"))

	return b.String()
}

func statCard(title, value, color string) string {
	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color(color)).
		Padding(1, 2).
		MarginRight(2).
		Render(lipgloss.JoinVertical(lipgloss.Center,
			lipgloss.NewStyle().Foreground(lipgloss.Color(color)).Render(title),
			lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(currentTheme.Text)).Render(value),
		))
}
