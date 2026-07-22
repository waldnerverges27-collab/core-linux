#!/usr/bin/env bash
# Fallback bash TUI when Go binary is unavailable

set -euo pipefail

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"

source "$CORE_HOME/lib/utils/colors.sh"
source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/core/state.sh"
source "$CORE_HOME/lib/core/module_manager.sh"

fallback_tui() {
	local running=true
	local current_view="home"

	while $running; do
		case "$current_view" in
			home) _fb_view_home ;;
			modules) _fb_view_modules ;;
			module_detail) _fb_view_module_detail ;;
			env) _fb_view_env ;;
			brain) _fb_view_brain ;;
			help) _fb_view_help ;;
		esac
	done
}

_fb_clear() {
	printf "\033[2J\033[H"
}

_fb_header() {
	local title="${1:-core-linux}"
	local subtitle="${2:-}"
	echo "$(color_bold && color_fg "${COLORS[primary]}")╭──────────────────────────────────────╮$(color_reset)"
	printf "$(color_bold && color_fg "${COLORS[primary]}")│$(color_reset) %-38s " "$title"
	echo "$(color_bold && color_fg "${COLORS[primary]}")│$(color_reset)"
	if [[ -n "$subtitle" ]]; then
		printf "$(color_bold && color_fg "${COLORS[primary]}")│$(color_reset) %-38s " "$subtitle"
		echo "$(color_bold && color_fg "${COLORS[primary]}")│$(color_reset)"
	fi
	echo "$(color_bold && color_fg "${COLORS[primary]}")╰──────────────────────────────────────╯$(color_reset)"
	echo ""
}

_fb_footer() {
	echo ""
	echo "$(color_dim)$(color_fg "${COLORS[muted]}")────────────────────────────────────────$(color_reset)"
	echo "$(color_fg "${COLORS[muted]}") [1-9] Navigate  (q) Quit  (h) Help$(color_reset)"
}

_fb_view_home() {
	_fb_clear
	_fb_header "core-linux" "Development Environment"

	local count=0
	local mod
	for mod in "$CORE_HOME/modules"/*/; do
		[[ -d "$mod" ]] && count=$((count+1))
	done

	local installed
	installed=$(get_installed_modules 2>/dev/null | wc -l)

	echo "$(color_fg "${COLORS[text]}") Modules available: $count$(color_reset)"
	echo "$(color_fg "${COLORS[text]}") Modules installed: $installed$(color_reset)"
	echo "$(color_fg "${COLORS[text]}") Config: $CORE_CONFIG$(color_reset)"
	echo ""
	echo "$(color_fg "${COLORS[secondary]}")1$(color_reset)) Browse Modules"
	echo "$(color_fg "${COLORS[secondary]}")2$(color_reset)) Environment Variables"
	echo "$(color_fg "${COLORS[secondary]}")3$(color_reset)) Second Brain"
	echo "$(color_fg "${COLORS[secondary]}")4$(color_reset)) Help"

	_fb_footer
	echo "$(color_dim)Select an option:$(color_reset) "
	read -r choice
	case "$choice" in
		1) current_view="modules" ;;
		2) current_view="env" ;;
		3) current_view="brain" ;;
		4) current_view="help" ;;
		q|Q) running=false ;;
	esac
}

_fb_view_modules() {
	_fb_clear
	_fb_header "Module Browser"

	local i=1
	local -a mods=()
	local mod
	for mod in "$CORE_HOME/modules"/*/; do
		[[ -d "$mod" ]] || continue
		mod=$(basename "$mod")
		mods+=("$mod")
		local manifest="$CORE_HOME/modules/$mod/manifest.json"
		if [[ -f "$manifest" ]]; then
			local icon desc status
			icon=$(jq -r '.icon // ""' "$manifest" 2>/dev/null)
			desc=$(jq -r '.description // ""' "$manifest" 2>/dev/null)
			status="$(color_fg "${COLORS[muted]}")✗$(color_reset)"
			module_is_installed "$mod" && status="$(color_fg "${COLORS[success]}")✔$(color_reset)"
			echo "$status $(color_fg "${COLORS[secondary]}")$i$(color_reset)) $icon $mod — $desc"
		else
			echo "  $i) $mod"
		fi
		i=$((i+1))
	done

	_fb_footer
	echo "$(color_dim)Select module or (b)ack:$(color_reset) "
	read -r choice
	case "$choice" in
		b|B) current_view="home" ;;
		q|Q) running=false ;;
		*)
			if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#mods[@]} )); then
				_selected_module="${mods[$((choice-1))]}"
				current_view="module_detail"
			fi
			;;
	esac
}

_fb_view_module_detail() {
	_fb_clear
	local mod="${_selected_module:-}"
	[[ -z "$mod" ]] && { current_view="modules"; return; }

	local manifest="$CORE_HOME/modules/$mod/manifest.json"
	if [[ ! -f "$manifest" ]]; then
		log_error "Module $mod not found"
		current_view="modules"
		return
	fi

	local icon desc deps
	icon=$(jq -r '.icon // ""' "$manifest" 2>/dev/null)
	desc=$(jq -r '.description // ""' "$manifest" 2>/dev/null)
	deps=$(jq -r '.dependencies | join(", ")' "$manifest" 2>/dev/null || echo "none")

	_fb_header "$icon $mod" "$desc"
	echo "$(color_fg "${COLORS[muted]}") Dependencies: $deps$(color_reset)"
	echo ""

	local i=0
	while jq -e ".tools[$i]" "$manifest" &>/dev/null; do
		local tname tdesc tflag tver
		tname=$(jq -r ".tools[$i].name" "$manifest")
		tdesc=$(jq -r ".tools[$i].description" "$manifest")
		tflag=$(jq -r ".tools[$i].flag" "$manifest")
		local status="✗"
		if tool_is_installed "$mod" "$tname"; then
			status="✔"
			tver=$(get_tool_version "$mod" "$tname")
		fi
		echo " $status $(color_fg "${COLORS[secondary]}")$((i+1))$(color_reset)) $tflag $tname — $tdesc"
		i=$((i+1))
	done

	echo ""
	echo "$(color_fg "${COLORS[secondary]}")i$(color_reset)) Install all tools in $mod"
	echo "$(color_fg "${COLORS[secondary]}")x$(color_reset)) Uninstall all tools in $mod"

	_fb_footer
	echo "$(color_dim)Select action or (b)ack:$(color_reset) "
	read -r choice
	case "$choice" in
		b|B) current_view="modules" ;;
		i|I)
			log_step "Installing $mod..."
			module_install "$mod" || log_error "Install had errors"
			read -r -n 1 -s -p "Press any key..."
			;;
		x|X)
			log_step "Uninstalling $mod..."
			module_uninstall "$mod" || log_error "Uninstall had errors"
			read -r -n 1 -s -p "Press any key..."
			;;
		q|Q) running=false ;;
	esac
}

_fb_view_env() {
	_fb_clear
	_fb_header "Environment Variables"
	source "$CORE_HOME/lib/core/env_manager.sh"
	env_ls
	echo ""
	echo "$(color_fg "${COLORS[secondary]}")1$(color_reset)) Set variable"
	echo "$(color_fg "${COLORS[secondary]}")2$(color_reset)) Unset variable"
	_fb_footer
	echo "$(color_dim)Select or (b)ack:$(color_reset) "
	read -r choice
	case "$choice" in
		b|B) current_view="home" ;;
		1) env_set; read -r -n 1 -s -p "Press any key..." ;;
		2) env_unset; read -r -n 1 -s -p "Press any key..." ;;
		q|Q) running=false ;;
	esac
}

_fb_view_brain() {
	_fb_clear
	_fb_header "Second Brain"
	source "$CORE_HOME/lib/core/brain.sh"
	if [[ ! -d "$BRAIN_DIR" ]]; then
		brain_init
	fi
	brain_ls
	echo ""
	echo "$(color_fg "${COLORS[secondary]}")1$(color_reset)) Save memory"
	echo "$(color_fg "${COLORS[secondary]}")2$(color_reset)) Search memories"
	_fb_footer
	echo "$(color_dim)Select or (b)ack:$(color_reset) "
	read -r choice
	case "$choice" in
		b|B) current_view="home" ;;
		1) brain_save; read -r -n 1 -s -p "Press any key..." ;;
		2)
			echo "Search query:"
			read -r query
			brain_search "$query"
			read -r -n 1 -s -p "Press any key..."
			;;
		q|Q) running=false ;;
	esac
}

_fb_view_help() {
	_fb_clear
	_fb_header "Help" "Keybindings & Usage"
	cat <<- EOF
$(color_fg "${COLORS[secondary]}")Navigation:$(color_reset)
  1-9   Select menu items
  b     Go back
  q     Quit
  h     Help (this screen)

$(color_fg "${COLORS[secondary]}")CLI Usage:$(color_reset)
  core install <module> [--tool]   Install tools
  core uninstall <module> [--tool] Remove tools
  core list [module]               List modules/tools
  core show <name>                 Show details
  core env set|unset|ls            Manage environment
  core brain save|search|ls        Second brain
  core init                        Project setup

$(color_fg "${COLORS[secondary]}")Modules:$(color_reset)
  🔤 lang     Programming languages
  🗄️ db       Databases
  🤖 ai       AI assistants
  ✏️ editor   Code editors
  🔧 dev      DevOps tools
  🐚 shell    Shell enhancements
  ⚡ auto     CI/CD tools
  🎨 ui       UI frameworks
EOF
	_fb_footer
	echo "$(color_dim)Press any key to return:$(color_reset) "
	read -r -n 1
	case "$REPLY" in
		q|Q) running=false ;;
		*) current_view="home" ;;
	esac
}

# If called directly, run the TUI
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	fallback_tui
fi
