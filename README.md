# core-linux

> A production-grade, modular development environment for Linux terminals.

core-linux provides a unified CLI and premium TUI for installing, managing, and configuring
development tools across your Linux system. Everything from programming languages to AI coding
assistants is just one command away.

## Features

- **🧩 Modular** — 8 modules covering languages, databases, AI, editors, DevOps, shell, CI/CD, and UI
- **🎨 Premium TUI** — Go Bubble Tea interface with 6 themes (Catppuccin, Nord, Dracula, Gruvbox, Tokyo Night, Rose Pine)
- **🔧 Flag-based installs** — `core install ai --ollama --aider` installs exactly what you need
- **🧠 Second Brain** — Built-in markdown memory system with search and git sync
- **🔑 Env Manager** — Manage shell environment variables with hidden input
- **⚡ Dependency resolution** — Automatic dependency ordering between modules
- **🐚 Graceful fallback** — Bash TUI when Go binary is unavailable

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/waldnerverges27-collab/core-linux/main/install.sh | bash
```

Then run:

```bash
core          # Launch the TUI
core --help   # See all commands
```

## Usage

```
core                          Launch TUI (or fallback bash TUI)
core install <module> [--tool...]  Install module/tools
core uninstall <module> [--tool...] Uninstall module/tools
core update [module|--all]    Update framework or module
core list [module]            List modules or tools
core show <module|tool>       Show details
core env set|unset|ls         Manage environment variables
core brain <subcommand>       Second brain memory system
core init                     Interactive project setup
```

### Examples

```bash
# Install all language runtimes
core install lang

# Install specific tools
core install ai --ollama --aider
core install dev --docker --kubectl

# Uninstall specific tools
core uninstall ai --ollama

# List all modules
core list

# Show module details
core show ai

# Second brain
core brain init
core brain save
core brain search "kubernetes"

# Environment variables
core env set
core env ls
```

## Modules

| Module | Icon | Description |
|--------|------|-------------|
| lang | 🔤 | Programming languages and runtimes |
| db | 🗄️ | Databases and data stores |
| ai | 🤖 | AI agents and coding assistants |
| editor | ✏️ | Code editors and IDEs |
| dev | 🔧 | DevOps and infrastructure tools |
| shell | 🐚 | Shell enhancements and terminal utilities |
| auto | ⚡ | CI/CD and automation tools |
| ui | 🎨 | Frontend UI libraries and frameworks |

## Theming

6 built-in themes: Catppuccin Mocha, Nord, Dracula, Gruvbox Dark, Tokyo Night, Rose Pine.
Change via TUI settings or edit `~/.config/core-linux/config.toml`:

```toml
[core]
theme = "dracula"
```

## Requirements

- **OS**: Linux (Ubuntu/Debian, Fedora/RHEL, Arch, openSUSE, Void Linux)
- **Bash 5+**
- **curl, git, jq, fzf**
- **Go 1.22+** (for TUI, optional)

## Development

```bash
make build       # Build TUI binary
make install     # Run install.sh locally
make test        # Run tests (requires bats)
make lint        # shellcheck all bash files
make clean       # Remove build artifacts
```

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full architecture overview.
See [docs/MODULE_AUTHORING.md](docs/MODULE_AUTHORING.md) for creating new modules.
See [docs/THEMING.md](docs/THEMING.md) for creating custom themes.

## License

MIT
