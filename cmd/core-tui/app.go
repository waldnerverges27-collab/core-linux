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
	width       int
	height      int
	help        help.Model
	spinner     spinner.Model
	keys        KeyMap

	// Scroll viewport (used by modules, module_detail, help, brain)
	vp      viewport.Model
	vpReady bool // true once width/height are set

	// Module data
	modules        []string
	moduleIndex    int
	selectedModule string
	toolIndex      int

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

	// Notifications
	notification string
	notifyTimer  int

	// Loading
	loading bool
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

// vpContentHeight returns the height available for viewport content
// (terminal height minus header/footer/padding overhead)
func (a *App) vpContentHeight() int {
	// overhead: title(1) + subtitle(1) + statusbar(1) + padding(1) + help(1) + margin(1) = 6
	h := a.height - 6
	if h < 3 {
		h = 3
	}
	if h > a.height-1 {
		h = a.height - 1
	}
	return h
}

// rebuildViewport sets the viewport dimensions and content for the current view
func (a *App) rebuildViewport(content string) {
	vpWidth := a.width - 4 // account for padding
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

// viewHeader renders the title area above the viewport
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
				a.enterView(viewHelp)
				return a, nil
			}
		}

		// View-specific key handling
		var handled bool
		a.currentView, handled = a.handleViewKey(msg)
		if handled {
			return a, nil
		}

	case spinner.TickMsg:
		var cmd tea.Cmd
		a.spinner, cmd = a.spinner.Update(msg)
		cmds = append(cmds, cmd)
	}

	return a, tea.Batch(cmds...)
}

// handleViewKey routes key events to the appropriate view handler
// Returns (newView, wasHandled)
func (a *App) handleViewKey(msg tea.KeyMsg) (viewID, bool) {
	switch a.currentView {
	case viewHome:
		return a.updateHome(msg), true
	case viewModules:
		return a.updateModules(msg), true
	case viewModuleDetail:
		return a.updateModuleDetail(msg), true
	case viewSettings:
		return a.updateSettings(msg), true
	case viewBrain:
		return a.updateBrain(msg), true
	case viewEnv:
		return a.updateEnv(msg), true
	case viewHelp:
		if key.Matches(msg, a.keys.Quit, a.keys.Back, a.keys.Help) {
			return viewHome, true
		}
		return viewHelp, true
	case viewInstall:
		// Install view: only allow q to quit
		return viewInstall, true
	}
	return a.currentView, false
}

// enterView transitions to a new view, rebuilding the viewport if needed
func (a *App) enterView(v viewID) {
	a.currentView = v
	a.vp.GotoTop()
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

	// For scrollable views, use viewport
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
