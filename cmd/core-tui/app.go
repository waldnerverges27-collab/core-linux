package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/table"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// View identifiers
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
	width       int
	height      int
	help        help.Model
	spinner     spinner.Model
	keys        KeyMap

	// Module data
	modules         []string
	moduleIndex     int
	selectedModule  string
	toolIndex       int

	// Install progress
	installing      bool
	installLog      []string
	installProgress float64

	// Settings
	settingsCursor int
	themeOptions   []string

	// Brain
	brainSearch textinput.Model
	brainMode   string // "list", "search", "save"

	// Env
	envTable table.Model

	// Notifications
	notification string
	notifyTimer  int

	// Loading
	loading bool
}

// NewApp creates and returns a new App model
func NewApp() *App {
	s := spinner.New()
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Primary))
	s.Spinner = spinner.Dot

	ti := textinput.New()
	ti.Placeholder = "Search..."
	ti.CharLimit = 100

	return &App{
		currentView:   viewHome,
		help:          help.New(),
		spinner:       s,
		keys:          defaultKeys,
		moduleIndex:   0,
		toolIndex:     0,
		installLog:    []string{},
		themeOptions:  []string{"catppuccin-mocha", "nord", "dracula", "gruvbox-dark", "tokyo-night", "rose-pine"},
		brainSearch:   ti,
		envTable:      table.New(),
	}
}

// Init initializes the model
func (a *App) Init() tea.Cmd {
	return tea.Batch(
		a.spinner.Tick,
		func() tea.Msg { return loadModulesMsg{} },
	)
}

// loadModulesMsg is a message that carries loaded module data
type loadModulesMsg struct {
	modules []string
}

// Update handles all messages and key events
func (a *App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		a.width = msg.Width
		a.height = msg.Height
		a.help.Width = msg.Width

	case tea.KeyMsg:
		// Global keys
		switch {
		case key.Matches(msg, a.keys.ForceQuit):
			return a, tea.Quit
		case key.Matches(msg, a.keys.Help):
			if a.currentView != viewHelp {
				a.currentView = viewHelp
				return a, nil
			}
		}

		// View-specific keys
		switch a.currentView {
		case viewHome:
			return a.updateHome(msg)
		case viewModules:
			return a.updateModules(msg)
		case viewModuleDetail:
			return a.updateModuleDetail(msg)
		case viewSettings:
			return a.updateSettings(msg)
		case viewBrain:
			return a.updateBrain(msg)
		case viewEnv:
			return a.updateEnv(msg)
		case viewHelp:
			if key.Matches(msg, a.keys.Quit, a.keys.Back, a.keys.Help) {
				a.currentView = viewHome
			}
		}

	case loadModulesMsg:
		a.modules = msg.modules
		a.loading = false

	case spinner.TickMsg:
		var cmd tea.Cmd
		a.spinner, cmd = a.spinner.Update(msg)
		cmds = append(cmds, cmd)
	}

	return a, tea.Batch(cmds...)
}

// View renders the current view
func (a *App) View() string {
	var content string

	switch a.currentView {
	case viewHome:
		content = a.viewHome()
	case viewModules:
		content = a.viewModules()
	case viewModuleDetail:
		content = a.viewModuleDetail()
	case viewInstall:
		content = a.viewInstall()
	case viewSettings:
		content = a.viewSettings()
	case viewBrain:
		content = a.viewBrain()
	case viewEnv:
		content = a.viewEnv()
	case viewHelp:
		content = a.viewHelp()
	}

	// Wrap with status bar
	statusBar := a.viewStatusBar()
	mainContent := lipgloss.JoinVertical(lipgloss.Left, content, statusBar)

	return lipgloss.NewStyle().PaddingLeft(2).PaddingRight(2).PaddingTop(1).Render(mainContent)
}

// viewStatusBar renders the bottom status bar
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
	moduleCount := len(a.modules)
	version := "1.0.0"

	left := lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Muted)).Background(lipgloss.Color(currentTheme.Surface)).Padding(0, 1).Render(fmt.Sprintf(" %s | %d modules", viewName, moduleCount))
	right := lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Primary)).Background(lipgloss.Color(currentTheme.Surface)).Render(fmt.Sprintf(" v%s ", version))
	center := lipgloss.NewStyle().Foreground(lipgloss.Color(currentTheme.Secondary)).Background(lipgloss.Color(currentTheme.Surface)).Render(" [?] Help  [q] Quit ")
	padding := a.width - lipgloss.Width(left) - lipgloss.Width(center) - lipgloss.Width(right)
	if padding < 1 {
		padding = 1
	}
	spaces := strings.Repeat(" ", padding)

	return lipgloss.JoinHorizontal(lipgloss.Top, left, center, spaces, right)
}

