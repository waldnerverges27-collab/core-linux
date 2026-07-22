# core-linux Architecture

## Overview

core-linux follows a two-tier architecture:

1. **Bash CLI** — The primary entry point (`core`) that delegates to modular bash libraries
2. **Go TUI** — A Bubble Tea graphical interface that wraps the same bash operations

```
┌─────────────────────────────────────────────┐
│                  User                        │
├────────────────────┬────────────────────────┤
│   core (bash CLI)  │  core-tui (Go binary)  │
├────────────────────┴────────────────────────┤
│              lib/ (bash libs)                │
│  ┌──────┬──────┬──────┬──────┬──────┬──────┐ │
│  │logger│colors│platform│network│fs  │prompt│ │
│  └──────┴──────┴──────┴──────┴──────┴──────┘ │
│  ┌──────┬──────┬──────┬──────┬──────┬──────┐ │
│  │state │module│ env  │ brain│resolv│update│ │
│  │      │manager│manager│     │er   │  r  │ │
│  └──────┴──────┴──────┴──────┴──────┴──────┘ │
├─────────────────────────────────────────────┤
│           modules/ (8 modules)               │
│  lang  db  ai  editor  dev  shell  auto  ui  │
├─────────────────────────────────────────────┤
│         Config, State, Brain Storage         │
│  ~/.config/core-linux/                       │
│  ~/.local/state/core-linux/                  │
│  ~/.local/share/core-linux/brain/            │
└─────────────────────────────────────────────┘
```

## Directory Structure

```
core-linux/
├── core                    # CLI entry point (bash)
├── cmd/core-tui/           # Go TUI source
│   ├── main.go             # Entry point
│   ├── app.go              # Bubble Tea model
│   ├── styles.go           # Lip Gloss styles + theme
│   ├── keys.go             # Keybindings
│   ├── views/              # View renderers
│   ├── components/         # UI components
│   └── utils/              # Go utilities
├── lib/
│   ├── core/               # Core bash libraries
│   │   ├── state.sh        # JSON state management
│   │   ├── module_manager.sh  # Install/uninstall/update
│   │   ├── env_manager.sh  # Environment variables
│   │   ├── brain.sh        # Second brain
│   │   ├── resolver.sh     # Dependency resolution
│   │   └── updater.sh      # Self-update
│   ├── utils/              # Utility libraries
│   │   ├── logger.sh       # Structured logging
│   │   ├── colors.sh       # Color system
│   │   ├── platform.sh     # Distro detection
│   │   ├── network.sh      # curl/wget wrapper
│   │   ├── fs.sh           # File operations
│   │   └── prompt.sh       # Interactive prompts
│   └── tui/
│       ├── fallback.sh     # Bash TUI fallback
│       └── themes/         # TOML theme files
├── modules/                # Module definitions
│   ├── lang/
│   ├── db/
│   ├── ai/
│   ├── editor/
│   ├── dev/
│   ├── shell/
│   ├── auto/
│   └── ui/
├── tests/                  # Bats test files
└── packaging/              # RPM, DEB, AUR
```

## Key Design Decisions

1. **Bash-first**: All operations work via bash. The Go TUI is a wrapper.
2. **Module manifests**: JSON with jq parsing — no custom parsers.
3. **State tracking**: Single JSON file for installed module state.
4. **Theme system**: TOML files read at bash and Go levels.
5. **XDG compliance**: Config, state, and data follow XDG Base Directory spec.

## Data Flow

### Install
```
User → core install ai --ollama
  → core (bash) → module_manager.sh
    → resolver.sh (check deps)
    → state.sh (read/write state)
    → modules/ai/install.sh (execute install)
    → state.sh (mark tool installed)
```

### TUI
```
User → core (launches core-tui)
  → app.go (Bubble Tea model)
    → views/home.go (render dashboard)
    → utils/exec.go (bash interaction)
    → module_manager.sh (install operations)
```
