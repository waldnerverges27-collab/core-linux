package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/table"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type viewID int

const (
	viewHome viewID = iota
	viewModules
	viewModuleDetail
	viewInstall
	viewSettings
	viewBrain
	viewEnv
	viewHelp
)

// App is the main Bubble Tea model
type App struct {
	currentView viewID
	prevView    viewID // track view changes for side effects
	width       int
	height      int
	help        help.Model
	spinner     spinner.Model
	keys        KeyMap

	// Scroll viewport
	vp      viewport.Model
	vpReady bool

	// Module data
	modules        []string
	moduleIndex    int
	selectedModule string
	toolIndex      int

	// Tool detection cache (populated async)
	toolVersions      map[string]string
	toolVersionsReady bool

	// Install progress
	installing      bool
	installLog      []string
	installProgress float64

	// Settings
	settingsCursor int
	themeOptions   []string

	// Brain
	brainSearch textinput.Model
	brainMode   string

	// Env
	envTable table.Model

	notification string
	notifyTimer  int
	loading      bool
}

func NewApp() *App {
	s := spinner.New()
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Primary))
	s.Spinner = spinner.Dot

	ti := textinput.New()
	ti.Placeholder = "Search..."
	ti.CharLimit = 100

	return &App{
		currentView:  viewHome,
		help:         help.New(),
		spinner:      s,
		keys:         defaultKeys,
		moduleIndex:  0,
		toolIndex:    0,
		installLog:   []string{},
		themeOptions: []string{"catppuccin-mocha", "nord", "dracula", "gruvbox-dark", "tokyo-night", "rose-pine"},
		brainSearch:  ti,
		envTable:     table.New(),
	}
}

func (a *App) Init() tea.Cmd {
	return a.spinner.Tick
}

func (a *App) vpContentHeight() int {
	h := a.height - 6
	if h < 3 {
		h = 3
	}
	return h
}

func (a *App) rebuildViewport(content string) {
	vpWidth := a.width - 4
	if vpWidth < 10 {
		vpWidth = 10
	}
	vpHeight := a.vpContentHeight()

	if !a.vpReady {
		a.vp = viewport.New(vpWidth, vpHeight)
		a.vp.Style = lipgloss.NewStyle()
		a.vp.MouseWheelEnabled = true
		a.vpReady = true
	} else {
		a.vp.Width = vpWidth
		a.vp.Height = vpHeight
	}
	a.vp.SetContent(content)
}

func (a *App) viewHeader(title, subtitle string) string {
	var b strings.Builder
	b.WriteString(titleStyle.Render(title))
	b.WriteString("\n")
	if subtitle != "" {
		b.WriteString(subtitleStyle.Render(subtitle))
		b.WriteString("\n")
	}
	return b.String()
}

func (a *App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		a.width = msg.Width
		a.height = msg.Height
		a.help.Width = msg.Width

	case tea.KeyMsg:
		switch {
		case key.Matches(msg, a.keys.ForceQuit):
			return a, tea.Quit
		case key.Matches(msg, a.keys.Help):
			if a.currentView != viewHelp {
				a.currentView = viewHelp
				return a, nil
			}
		}

		// View-specific handling
		var newView viewID
		switch a.currentView {
		case viewHome:
			newView = a.updateHome(msg)
		case viewModules:
			newView = a.updateModules(msg)
		case viewModuleDetail:
			newView = a.updateModuleDetail(msg)
		case viewSettings:
			newView = a.updateSettings(msg)
		case viewBrain:
			newView = a.updateBrain(msg)
		case viewEnv:
			newView = a.updateEnv(msg)
		case viewHelp:
			if key.Matches(msg, a.keys.Quit, a.keys.Back, a.keys.Help) {
				newView = viewHome
			} else {
				newView = viewHelp
			}
		case viewInstall:
			newView = viewInstall
		}

		// If view changed, handle side effects
		if newView != a.currentView {
			a.prevView = a.currentView
			a.currentView = newView

			// Entering module detail: async load tool versions
			if newView == viewModuleDetail {
				a.toolVersionsReady = false
				cmds = append(cmds, a.loadToolVersions)
			}
			if newView != viewModuleDetail {
				a.vp.GotoTop()
			} else {
				a.vp.GotoTop()
			}
		}

	case spinner.TickMsg:
		var cmd tea.Cmd
		a.spinner, cmd = a.spinner.Update(msg)
		cmds = append(cmds, cmd)

	case toolVersionsMsg:
		if msg.mod == a.selectedModule {
			a.toolVersions = msg.versions
			a.toolVersionsReady = true
		}
	}

	return a, tea.Batch(cmds...)
}

// loadToolVersions is a tea.Cmd that runs batchDetectTools in background
func (a *App) loadToolVersions() tea.Msg {
	mod := a.selectedModule
	versions := batchDetectTools(mod)
	return toolVersionsMsg{mod: mod, versions: versions}
}

type toolVersionsMsg struct {
	mod      string
	versions map[string]string
}

// View renders the current view
func (a *App) View() string {
	var header, body string

	switch a.currentView {
	case viewHome:
		body = a.viewHome()
	case viewModules:
		header = a.viewHeader("📦 Module Browser", "Select a module to view its tools")
		body = a.renderModulesContent()
	case viewModuleDetail:
		tools := batchLoadTools(a.selectedModule)
		body = a.renderToolDetailContent(tools)
	case viewInstall:
		body = a.viewInstall()
	case viewSettings:
		body = a.viewSettings()
	case viewBrain:
		header = a.viewHeader("🧠 Second Brain", "Your personal knowledge base")
		body = a.renderBrainContent()
	case viewEnv:
		body = a.viewEnv()
	case viewHelp:
		header = a.viewHeader("⌨️ Help & Keybindings", "")
		body = a.renderHelpContent()
	}

	// Scrollable views use viewport
	switch a.currentView {
	case viewModules, viewModuleDetail, viewBrain, viewHelp:
		fullContent := header + body
		a.rebuildViewport(fullContent)
		content := a.vp.View()
		statusBar := a.viewStatusBar()
		return lipgloss.NewStyle().PaddingLeft(2).PaddingRight(2).PaddingTop(1).Render(
			lipgloss.JoinVertical(lipgloss.Left, content, statusBar),
		)
	default:
		statusBar := a.viewStatusBar()
		return lipgloss.NewStyle().PaddingLeft(2).PaddingRight(2).PaddingTop(1).Render(
			lipgloss.JoinVertical(lipgloss.Left, body, statusBar),
		)
	}
}

func (a *App) viewStatusBar() string {
	viewNames := map[viewID]string{
		viewHome:         "Home",
		viewModules:      "Modules",
		viewModuleDetail: "Detail",
		viewInstall:      "Install",
		viewSettings:     "Settings",
		viewBrain:        "Brain",
		viewEnv:          "Env",
		viewHelp:         "Help",
	}
	viewName := viewNames[a.currentView]
	modCount := len(batchLoadModules())
	version := "1.0.0"

	left := lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Background(lipgloss.Color(currentTheme.Surface)).Padding(0, 1).Render(fmt.Sprintf(" %s | %d modules", viewName, modCount))
	right := lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Primary)).Background(lipgloss.Color(currentTheme.Surface)).Render(fmt.Sprintf(" v%s ", version))
	center := lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Secondary)).Background(lipgloss.Color(currentTheme.Surface)).Render(" [?] Help  [q] Quit ")
	padding := a.width - lipgloss.Width(left) - lipgloss.Width(center) - lipgloss.Width(right)
	if padding < 1 {
		padding = 1
	}
	spaces := strings.Repeat(" ", padding)
	return lipgloss.JoinHorizontal(lipgloss.Top, left, center, spaces, right)
}
