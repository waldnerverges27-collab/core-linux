# Theming Guide

core-linux supports custom themes defined as TOML files.

## Built-in Themes

- **Catppuccin Mocha** (default)
- **Nord**
- **Dracula**
- **Gruvbox Dark**
- **Tokyo Night**
- **Rose Pine**

## Theme File Format

Theme files are stored in `lib/tui/themes/<name>.toml`:

```toml
[colors]
primary = "#cba6f7"    # Headlines, active items, branding
secondary = "#89b4fa"  # Links, secondary text, key hints
accent = "#f38ba8"     # Error text, warnings, danger buttons
success = "#a6e3a1"    # Success indicators, installed status
warning = "#f9e2af"    # Warning text, pending status
error = "#f38ba8"      # Error text, critical status
bg = "#1e1e2e"         # Background color
surface = "#313244"    # Card surfaces, modal backgrounds
text = "#cdd6f4"       # Primary text color
muted = "#6c7086"      # Secondary text, hints, labels
border = "#45475a"     # Borders, separators

[styles]
border = "rounded"          # Border style: rounded, normal, double, hidden
padding_x = 2               # Horizontal padding
padding_y = 1               # Vertical padding
animation_speed = "normal"  # Animation speed: slow, normal, fast, off
```

## Creating a Theme

1. Create a new TOML file in `lib/tui/themes/<your-theme>.toml`
2. Define all 11 color values
3. Add optional style settings

## Selecting a Theme

Via TUI: Settings view → Theme Picker → select theme

Via config: Edit `~/.config/core-linux/config.toml`:
```toml
[core]
theme = "your-theme"
```

## Color Guidelines

- Choose high-contrast combinations for readability
- Ensure text is readable on both bg and surface backgrounds
- Test in both light and dark terminal emulators
- Use hex colors (#RRGGBB) — named colors are not supported
- Colors are automatically mapped to 256-color ANSI codes in bash
- Go TUI uses true color (24-bit) when supported by the terminal
