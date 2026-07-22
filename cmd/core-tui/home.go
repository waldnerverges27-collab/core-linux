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

// ModEntry is a single module's light metadata
type ModEntry struct {
	Name        string `json:"name"`
	Icon        string `json:"icon"`
	Description string `json:"description"`
}

// ToolEntry is a single tool's light metadata
type ToolEntry struct {
	Name        string   `json:"name"`
	Flag        string   `json:"flag"`
	Description string   `json:"description"`
	Tags        []string `json:"tags"`
}

type InstalledState map[string]map[string]string

var (
	modCache     []ModEntry
	modCacheOnce sync.Once
)

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

// coreCLI ejecuta 'core <args>' a través del CLI principal
// Esto asegura que la TUI use EXACTAMENTE los mismos métodos
// que el CLI: verificación, versiones, --upgrade, etc.
func coreCLI(args ...string) error {
	corePath := coreHomeDir() + "/core"
	cmdArgs := append([]string{corePath}, args...)
	c := exec.Command("bash", cmdArgs...)
	return c.Run()
}

func coreHomeDir() string {
	if h := os.Getenv("CORE_HOME"); h != "" {
		return h
	}
	return os.Getenv("HOME") + "/.local/share/core-linux"
}

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

// batchDetectTools checks ALL tools in a module using bash _tool_detect
// Returns JSON: {"tool_name": "version_or_empty"}
// Uses a SINGLE bash call instead of spawning 27 processes.
func batchDetectTools(module string) map[string]string {
	manifest := fmt.Sprintf("%s/modules/%s/manifest.json", coreHomeDir(), module)
	ch := coreHomeDir()
	// Construye un script bash que itera sobre los tools del manifest
	// y llama _tool_detect para cada uno, devolviendo JSON.
	cmd := fmt.Sprintf(`
		source '%s/lib/core/module_manager.sh' 2>/dev/null
		manifest='%s'
		result="{"
		sep=""
		while IFS= read -r tool; do
			[ -z "$tool" ] && continue
			ver=""
			ver=$(_tool_detect "$tool" 2>/dev/null) || true
			result="$result$sep\"$tool\":\"${ver:-}\""
			sep=","
		done < <(jq -r '.tools[].name' "$manifest" 2>/dev/null)
		echo "$result}"
	`, ch, manifest)
	out := bashOutput(cmd)
	if out == "" {
		out = "{}"
	}
	result := make(map[string]string)
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		// Fallback: try parsing empty or malformed
		return result
	}
	return result
}

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

func (a *App) updateHome(msg tea.KeyMsg) viewID {
	switch {
	case keyMatches(msg, "q"):
		// handled by global
		return viewHome
	case keyMatches(msg, "1"):
		return viewModules
	case keyMatches(msg, "2"):
		return viewEnv
	case keyMatches(msg, "3"):
		return viewBrain
	case keyMatches(msg, "4"):
		return viewSettings
	case keyMatches(msg, "s"):
		return viewSettings
	case keyMatches(msg, "b"):
		return viewBrain
	case keyMatches(msg, "e"):
		return viewEnv
	case keyMatches(msg, "enter"):
		return viewModules
	}
	return viewHome
}

func (a *App) viewHome() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("core-linux"))
	b.WriteString(subtitleStyle.Render("Modular Development Environment"))
	b.WriteString("\n")

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

	b.WriteString(mutedStyle.Render("? for help • q to quit"))
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

var _ = json.Marshal
