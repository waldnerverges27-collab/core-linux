package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ---------------------------------------------------------------------------
// Batch module data — loaded with ONE bash call
// ---------------------------------------------------------------------------

// ModEntry is a single module's light metadata
type ModEntry struct {
	Name        string   `json:"name"`
	Icon        string   `json:"icon"`
	Description string   `json:"description"`
}

// ToolEntry is a single tool's light metadata
type ToolEntry struct {
	Name        string   `json:"name"`
	Flag        string   `json:"flag"`
	Description string   `json:"description"`
	Tags        []string `json:"tags"`
}

// InstalledState holds which module/tool combos are installed
type InstalledState map[string]map[string]string // module → tool → version

var (
	modCache     []ModEntry
	modCacheOnce sync.Once
)

// bashOutput runs a command and returns stdout
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

func coreHomeDir() string {
	if h := os.Getenv("CORE_HOME"); h != "" {
		return h
	}
	return os.Getenv("HOME") + "/.local/share/core-linux"
}

// batchLoadModules loads ALL module metadata in ONE bash invocation
func batchLoadModules() []ModEntry {
	modCacheOnce.Do(func() {
		pattern := coreHomeDir() + "/modules/*/manifest.json"
		cmd := fmt.Sprintf(`jq -s '[.[] | {name, icon, description}]' %s 2>/dev/null || echo '[]'`, pattern)
		out := bashOutput(cmd)
		if out == "" {
			modCache = []ModEntry{}
			return
		}
		if err := json.Unmarshal([]byte(out), &modCache); err != nil {
			modCache = []ModEntry{}
		}
	})
	return modCache
}

// batchLoadTools loads ALL tools for a module in ONE bash invocation
func batchLoadTools(module string) []ToolEntry {
	manifest := fmt.Sprintf("%s/modules/%s/manifest.json", coreHomeDir(), module)
	cmd := fmt.Sprintf(`jq -c '[.tools[] | {name, flag, description, tags}]' '%s' 2>/dev/null || echo '[]'`, manifest)
	out := bashOutput(cmd)
	if out == "" {
		return nil
	}
	var tools []ToolEntry
	if err := json.Unmarshal([]byte(out), &tools); err != nil {
		return nil
	}
	return tools
}

// batchInstalledState loads the full installed state in ONE bash invocation
func batchInstalledState() InstalledState {
	cmd := fmt.Sprintf(`cat '%s/installed.json' 2>/dev/null || echo '{"modules":{}}'`, stateDir())
	out := bashOutput(cmd)
	if out == "" {
		return InstalledState{}
	}
	var raw struct {
		Modules map[string]struct {
			Tools map[string]struct {
				Version string `json:"version"`
			} `json:"tools"`
		} `json:"modules"`
	}
	if err := json.Unmarshal([]byte(out), &raw); err != nil {
		return InstalledState{}
	}
	result := make(InstalledState)
	for mod, mdata := range raw.Modules {
		result[mod] = make(map[string]string)
		for tool, tdata := range mdata.Tools {
			result[mod][tool] = tdata.Version
		}
	}
	return result
}

func stateDir() string {
	if s := os.Getenv("CORE_STATE_DIR"); s != "" {
		return s
	}
	if s := os.Getenv("XDG_STATE_HOME"); s != "" {
		return s + "/core-linux"
	}
	return os.Getenv("HOME") + "/.local/state/core-linux"
}

// updateHome handles key events
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

	// Get module data from cache
	mods := batchLoadModules()
	inst := batchInstalledState()

	instCount := 0
	for mod := range inst {
		if len(inst[mod]) > 0 {
			instCount++
		}
	}

	distro := bashOutput(fmt.Sprintf("source %s/lib/utils/platform.sh && echo \"${DISTRO_FAMILY:-unknown}\"", coreHomeDir()))

	statsRow := lipgloss.JoinHorizontal(lipgloss.Top,
		statCard("Modules", fmt.Sprintf("%d", len(mods)), currentTheme.Secondary),
		statCard("Installed", fmt.Sprintf("%d", instCount), currentTheme.Success),
		statCard("Platform", distro, currentTheme.Muted),
	)
	b.WriteString(statsRow)
	b.WriteString("\n\n")

	actions := []struct {
		key, icon, label, desc string
	}{
		{"1", "📦", "Modules", "Browse and install development modules"},
		{"2", "🔑", "Environment", "Manage environment variables"},
		{"3", "🧠", "Brain", "Second brain memory system"},
		{"4", "⚙️", "Settings", "Configure themes and preferences"},
	}

	for _, act := range actions {
		line := lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Secondary)).Bold(true).Render(act.key+". ") +
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Text)).Render(act.icon+" "+act.label) +
			lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render(" — "+act.desc)
		b.WriteString(line)
		b.WriteString("\n\n")
	}

	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Render("? for help • q to quit"))

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
