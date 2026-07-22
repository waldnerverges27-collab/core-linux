#!/usr/bin/env bash
# core-linux — One-liner install:
#   curl -fsSL https://raw.githubusercontent.com/waldnerverges27-collab/core-linux/main/install.sh | bash

# Automatic dependency resolution: any missing prerequisite is installed silently.
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

# ------------------------------------------------------------------
# Distro detection
# ------------------------------------------------------------------
detect_distro() {
	if [[ -n "${CORE_FORCE_DISTRO:-}" ]]; then echo "$CORE_FORCE_DISTRO"; return; fi
	[[ -f /etc/os-release ]] || { echo "unknown"; return; }
	. /etc/os-release
	case "${ID,,}" in
		ubuntu|debian|linuxmint|pop|elementary) echo "ubuntu" ;;
		fedora|rhel|centos|rocky|alma)          echo "fedora" ;;
		arch|manjaro|endeavouros|artix)         echo "arch" ;;
		opensuse*|suse|sles)                    echo "opensuse" ;;
		void)                                   echo "void" ;;
		alpine)                                 echo "alpine" ;;
		nixos)                                  echo "nixos" ;;
		*)                                      echo "unknown" ;;
	esac
}

detect_pkg_manager() {
	case "$(detect_distro)" in
		ubuntu)   echo "apt"    ;;
		fedora)   echo "dnf"    ;;
		arch)     echo "pacman" ;;
		opensuse) echo "zypper" ;;
		void)     echo "xbps-install" ;;
		alpine)   echo "apk"    ;;
		*)        echo ""       ;;
	esac
}

distro=$(detect_distro)
pm=$(detect_pkg_manager)
echo "Detected: $distro ($pm)"

# ------------------------------------------------------------------
# Privilege escalation helper — uses sudo when available,
# falls back to doas / su if sudo is missing.
# ------------------------------------------------------------------
_elevate() {
	if command -v sudo &>/dev/null; then
		sudo "$@"
	elif command -v doas &>/dev/null; then
		doas "$@"
	elif [[ $EUID -eq 0 ]]; then
		"$@"
	else
		echo "ERROR: need root privileges but no sudo/doas found."
		echo "  Please run: $*"
		return 1
	fi
}

# ------------------------------------------------------------------
# 1. Install OS-level prerequisites (curl, git, jq, fzf, …)
# ------------------------------------------------------------------
_install_pkg() {
	local pkg="$1"
	case "$pm" in
		apt)    _elevate apt-get install -y -qq "$pkg" ;;
		dnf)    _elevate dnf install -y "$pkg" ;;
		pacman) _elevate pacman -S --noconfirm --needed "$pkg" ;;
		zypper) _elevate zypper install -y "$pkg" ;;
		xbps-install) _elevate xbps-install -y "$pkg" ;;
		apk)    _elevate apk add "$pkg" ;;
		*)      return 1 ;;
	esac
}

install_prereqs() {
	local core_pkgs=()
	command -v curl &>/dev/null || core_pkgs+=("curl")
	command -v git  &>/dev/null || core_pkgs+=("git")
	command -v jq   &>/dev/null || core_pkgs+=("jq")
	command -v fzf  &>/dev/null || core_pkgs+=("fzf")
	command -v which &>/dev/null || core_pkgs+=("which")

	if [[ ${#core_pkgs[@]} -eq 0 ]]; then
		echo "  ✔ All core prerequisites already installed."
	else
		echo "  ⏳ Installing missing core prerequisites: ${core_pkgs[*]}"
		for pkg in "${core_pkgs[@]}"; do
			_install_pkg "$pkg" || echo "  ⚠ Failed to install $pkg (will continue anyway)"
		done
	fi

	# Update package DB for apt-based systems (needed for fresh images)
	if [[ "$pm" == "apt" ]]; then
		_elevate apt-get update -qq 2>/dev/null || true
	fi
}

install_prereqs

# ------------------------------------------------------------------
# 2. Install Go (needed for TUI build)
# ------------------------------------------------------------------
_maybe_install_go() {
	[[ $NO_TUI -eq 1 ]] && return 1
	command -v go &>/dev/null && { echo "  ✔ Go already installed: $(go version | head -1)"; return 0; }

	echo "  ⏳ Installing Go (required for TUI)..."

	case "$pm" in
		apt)
			_elevate apt-get install -y -qq golang-go 2>/dev/null ||
			_install_go_binary
			;;
		dnf)
			_elevate dnf install -y golang 2>/dev/null ||
			_install_go_binary
			;;
		pacman)
			_elevate pacman -S --noconfirm --needed go 2>/dev/null ||
			_install_go_binary
			;;
		zypper)
			_elevate zypper install -y go 2>/dev/null ||
			_install_go_binary
			;;
		*)
			_install_go_binary
			;;
	esac

	if command -v go &>/dev/null; then
		echo "  ✔ Go installed: $(go version)"
	else
		echo "  ⚠ Go install failed; TUI disabled (use --no-tui to skip)"
		NO_TUI=1
	fi
}

_install_go_binary() {
	local ver="1.23.0"
	local arch
	case "$(uname -m)" in x86_64|amd64) arch="amd64" ;; aarch64|arm64) arch="arm64" ;; *) arch="amd64" ;; esac
	local tarball="go${ver}.linux-${arch}.tar.gz"

	echo "  Downloading Go ${ver} from golang.org..."
	curl -fsSL "https://go.dev/dl/${tarball}" -o "/tmp/${tarball}"
	_elevate tar -C /usr/local -xzf "/tmp/${tarball}"
	rm -f "/tmp/${tarball}"
	export PATH="/usr/local/go/bin:$PATH"
	# Persist for the current session and future logins
	mkdir -p /etc/profile.d
	echo 'export PATH=$PATH:/usr/local/go/bin' | _elevate tee /etc/profile.d/go.sh >/dev/null
}

_maybe_install_go

# ------------------------------------------------------------------
# 3. Write files
# ------------------------------------------------------------------
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$CORE_HOME" "$CORE_BIN" "$CORE_CONFIG_DIR" "$CORE_STATE_DIR"

echo ""
echo "Installing files to $CORE_HOME..."
cp -r "$SRC_DIR/modules" "$CORE_HOME/"
cp -r "$SRC_DIR/lib" "$CORE_HOME/"
cp -r "$SRC_DIR/plugins" "$CORE_HOME/" 2>/dev/null || true
cp "$SRC_DIR/core" "$CORE_HOME/core"
chmod +x "$CORE_HOME/core"

# ------------------------------------------------------------------
# 4. Build Go TUI
# ------------------------------------------------------------------
if [[ $NO_TUI -eq 0 ]] && command -v go &>/dev/null; then
	echo "Building TUI binary..."
	cd "$SRC_DIR/cmd/core-tui"
	go mod tidy 2>/dev/null || true
	if go build -ldflags="-s -w" -o core-tui . 2>/dev/null; then
		cp core-tui "$CORE_HOME/core-tui"
		ln -sf "$CORE_HOME/core-tui" "$CORE_BIN/core-tui"
		echo "  ✔ TUI built successfully."
	else
		echo "  ⚠ TUI build failed; falling back to bash-only mode."
	fi
else
	[[ $NO_TUI -eq 0 ]] && echo "  ⏩ Go not available, skipping TUI build."
fi

# ------------------------------------------------------------------
# 5. Finish setup
# ------------------------------------------------------------------
ln -sf "$CORE_HOME/core" "$CORE_BIN/core"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
	echo "Added ~/.local/bin to PATH in ~/.bashrc"
fi

if [[ ! -f "$CORE_CONFIG_DIR/config.toml" ]]; then
	sed "s|CORE_HOME_PLACEHOLDER|$CORE_HOME|g" "$SRC_DIR/core.conf.example" > "$CORE_CONFIG_DIR/config.toml"
	echo "  ✔ Created default config at $CORE_CONFIG_DIR/config.toml"
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
