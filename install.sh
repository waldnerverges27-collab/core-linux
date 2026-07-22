#!/usr/bin/env bash
set -euo pipefail

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"
CORE_BIN="${CORE_BIN:-$HOME/.local/bin}"
CORE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/core-linux"
CORE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/core-linux"

UNINSTALL=0
NO_TUI=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--uninstall) UNINSTALL=1; shift ;;
		--no-tui) NO_TUI=1; shift ;;
		*) echo "Unknown option: $1"; exit 1 ;;
	esac
done

if [[ $UNINSTALL -eq 1 ]]; then
	echo "Uninstalling core-linux..."
	rm -f "$CORE_BIN/core" "$CORE_BIN/core-tui"
	rm -rf "$CORE_HOME"
	echo "Done. Config at $CORE_CONFIG_DIR kept; use --purge with uninstall.sh to remove."
	exit 0
fi

echo "=== core-linux Installer ==="
echo ""

detect_distro() {
	if [[ -n "${CORE_FORCE_DISTRO:-}" ]]; then echo "$CORE_FORCE_DISTRO"; return; fi
	[[ -f /etc/os-release ]] || { echo "unknown"; return; }
	. /etc/os-release
	case "${ID,,}" in
		ubuntu|debian) echo "ubuntu" ;;
		fedora|rhel|centos) echo "fedora" ;;
		arch|manjaro|endeavouros) echo "arch" ;;
		opensuse*|suse) echo "opensuse" ;;
		void) echo "void" ;;
		*) echo "unknown" ;;
	esac
}

distro=$(detect_distro)
echo "Detected distro: $distro"

install_prereqs() {
	local pkgs=("curl" "git" "jq" "fzf")
	local missing=()
	for pkg in "${pkgs[@]}"; do
		command -v "$pkg" &>/dev/null || missing+=("$pkg")
	done
	[[ ${#missing[@]} -eq 0 ]] && return 0

	echo "Installing missing prerequisites: ${missing[*]}"
	case "$distro" in
		ubuntu)
			sudo apt-get update -qq
			sudo apt-get install -y -qq "${missing[@]}"
			;;
		fedora)
			sudo dnf install -y "${missing[@]}"
			;;
		arch)
			sudo pacman -S --noconfirm "${missing[@]}"
			;;
		opensuse)
			sudo zypper install -y "${missing[@]}"
			;;
		void)
			sudo xbps-install -y "${missing[@]}"
			;;
		*)
			echo "WARNING: Unsupported distro. Please install manually: ${missing[*]}"
			;;
	esac
}

install_prereqs

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$CORE_HOME" "$CORE_BIN" "$CORE_CONFIG_DIR" "$CORE_STATE_DIR"

echo "Installing files to $CORE_HOME..."
cp -r "$SRC_DIR/modules" "$CORE_HOME/"
cp -r "$SRC_DIR/lib" "$CORE_HOME/"
cp -r "$SRC_DIR/plugins" "$CORE_HOME/" 2>/dev/null || true
cp "$SRC_DIR/core" "$CORE_HOME/core"
chmod +x "$CORE_HOME/core"

if [[ $NO_TUI -eq 0 ]] && command -v go &>/dev/null; then
	echo "Building TUI binary..."
	cd "$SRC_DIR/cmd/core-tui"
	go mod tidy 2>/dev/null || true
	if go build -ldflags="-s -w" -o core-tui . 2>/dev/null; then
		cp core-tui "$CORE_HOME/core-tui"
		ln -sf "$CORE_HOME/core-tui" "$CORE_BIN/core-tui"
		echo "TUI built successfully."
	else
		echo "TUI build failed; falling back to bash-only mode."
	fi
else
	echo "Skipping TUI build (--no-tui or Go not found)."
fi

ln -sf "$CORE_HOME/core" "$CORE_BIN/core"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
	echo "Added ~/.local/bin to PATH in ~/.bashrc"
fi

if [[ ! -f "$CORE_CONFIG_DIR/config.toml" ]]; then
	sed "s|CORE_HOME_PLACEHOLDER|$CORE_HOME|g" "$SRC_DIR/core.conf.example" > "$CORE_CONFIG_DIR/config.toml"
	echo "Created default config at $CORE_CONFIG_DIR/config.toml"
fi

echo '{"modules":{}}' > "$CORE_STATE_DIR/installed.json"

echo ""
echo "============================================"
echo "  core-linux installed successfully!"
echo "============================================"
echo "  Binary:  $CORE_BIN/core"
echo "  Config:  $CORE_CONFIG_DIR/config.toml"
echo "  State:   $CORE_STATE_DIR/installed.json"
echo "  Modules: $CORE_HOME/modules/"
echo ""
echo "  Run 'core' to launch the TUI"
echo "  Run 'core --help' for CLI usage"
echo "============================================"
