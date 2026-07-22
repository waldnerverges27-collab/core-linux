#!/usr/bin/env bash
# core-linux — One-liner install:
#   curl -fsSL https://raw.githubusercontent.com/waldnerverges27-collab/core-linux/main/install.sh | bash
#
# Automatic dependency resolution: any missing prerequisite is installed silently.
# Works both piped (curl | bash) and locally (bash install.sh).

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths (XDG-compliant)
# ---------------------------------------------------------------------------
CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"
CORE_BIN="${CORE_BIN:-$HOME/.local/bin}"
CORE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/core-linux"
CORE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/core-linux"

UNINSTALL=0
NO_TUI=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--uninstall) UNINSTALL=1; shift ;;
		--no-tui)    NO_TUI=1;    shift ;;
		*) echo "Unknown option: $1"; exit 1 ;;
	esac
done

if [[ $UNINSTALL -eq 1 ]]; then
	echo "Uninstalling core-linux..."
	rm -f "$CORE_BIN/core" "$CORE_BIN/core-tui"
	rm -rf "$CORE_HOME"
	echo "Done. Config at $CORE_CONFIG_DIR preserved; use --purge with uninstall.sh to remove it."
	exit 0
fi

# ---------------------------------------------------------------------------
# 0. Resolve source directory — works both piped and local
# ---------------------------------------------------------------------------
if [[ "$0" == "bash" || "$0" == "-bash" || "$0" == "/dev/stdin" || ! -f "$(dirname "$0")/core" ]]; then
	# Running from pipe (curl | bash) — clone or copy via git
	PIPED_INSTALL=1
	WORK_DIR=$(mktemp -d)
	echo "  ⏳ Downloading core-linux to $WORK_DIR ..."
	if command -v git &>/dev/null; then
		git clone --depth=1 https://github.com/waldnerverges27-collab/core-linux.git "$WORK_DIR" 2>/dev/null || {
			# Fallback: tarball via curl
			rm -rf "$WORK_DIR"
			WORK_DIR=$(mktemp -d)
			curl -fsSL https://github.com/waldnerverges27-collab/core-linux/archive/refs/heads/main.tar.gz \
				| tar -xz -C "$WORK_DIR" --strip=1 2>/dev/null || {
				echo "ERROR: Cannot download core-linux. Check your internet connection." >&2
				rm -rf "$WORK_DIR"
				exit 1
			}
		}
	else
		curl -fsSL https://github.com/waldnerverges27-collab/core-linux/archive/refs/heads/main.tar.gz \
			| tar -xz -C "$WORK_DIR" --strip=1 2>/dev/null || {
			echo "ERROR: Cannot download core-linux. Install git or curl first." >&2
			rm -rf "$WORK_DIR"
			exit 1
		}
	fi
	SRC_DIR="$WORK_DIR"
else
	PIPED_INSTALL=0
	SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# ---------------------------------------------------------------------------
# 1. Distro & package-manager detection (single source of truth)
# ---------------------------------------------------------------------------
DISTRO=""
PM=""
DISTRO_VERSION=""

detect_distro() {
	if [[ -n "${CORE_FORCE_DISTRO:-}" ]]; then
		DISTRO="$CORE_FORCE_DISTRO"
		return
	fi
	local id id_like version=""
	[[ -f /etc/os-release ]] || { DISTRO="unknown"; return; }
	. /etc/os-release
	id="${ID,,}"
	id_like="${ID_LIKE:-}"
	id_like="${id_like,,}"
	version="${VERSION_ID:-}"

	case "$id" in
		ubuntu|debian|linuxmint|pop|elementary|neon|zorin|kali)
			DISTRO="debian"; DISTRO_VERSION="$version" ;;
		fedora|rhel|centos|rocky|alma|ol|amzn|pidora)
			DISTRO="fedora"; DISTRO_VERSION="$version" ;;
		arch|manjaro|endeavouros|artix|archlabs|garuda|arcolinux|cachyos)
			DISTRO="arch";   DISTRO_VERSION="$version" ;;
		opensuse*|suse|sles)
			DISTRO="opensuse"; DISTRO_VERSION="$version" ;;
		void)  DISTRO="void";   DISTRO_VERSION="$version" ;;
		alpine) DISTRO="alpine"; DISTRO_VERSION="$version" ;;
		nixos) DISTRO="nixos";  DISTRO_VERSION="$version" ;;
		solus) DISTRO="solus";  DISTRO_VERSION="$version" ;;
		gentoo) DISTRO="gentoo"; DISTRO_VERSION="$version" ;;
		slackware) DISTRO="slackware"; DISTRO_VERSION="$version" ;;
		*)
			# Fallback: check ID_LIKE
			case "$id_like" in
				*debian*|*ubuntu*)   DISTRO="debian"   ;;
				*fedora*|*rhel*|*centos*) DISTRO="fedora" ;;
				*arch*)              DISTRO="arch"     ;;
				*suse*)              DISTRO="opensuse" ;;
				*void*)              DISTRO="void"     ;;
				*)                   DISTRO="unknown"  ;;
			esac
			;;
	esac
}

detect_pm() {
	case "$DISTRO" in
		debian)   PM="apt"    ;;
		fedora)   PM="dnf"    ;;
		arch)     PM="pacman" ;;
		opensuse) PM="zypper" ;;
		void)     PM="xbps-install" ;;
		alpine)   PM="apk"    ;;
		nixos)    PM="nix-env";;
		solus)    PM="eopkg"  ;;
		gentoo)   PM="emerge" ;;
		slackware) PM="slackpkg" ;;
		*)        PM=""       ;;
	esac
}

detect_distro
detect_pm
echo "=== core-linux Installer ==="
echo "  Distro: $DISTRO ${DISTRO_VERSION:+($DISTRO_VERSION)}"
echo "  PM:     ${PM:-none detected}"
echo ""

# ---------------------------------------------------------------------------
# 2. Privilege escalation
# ---------------------------------------------------------------------------
_elevate() {
	if [[ $EUID -eq 0 ]]; then
		"$@"
	elif command -v sudo &>/dev/null; then
		sudo "$@"
	elif command -v doas &>/dev/null; then
		doas "$@"
	elif command -v su &>/dev/null; then
		su -c "$*" --
	else
		echo "ERROR: need root but no sudo/doas/su available." >&2
		echo "  Please run manually: $*" >&2
		return 1
	fi
}

# ---------------------------------------------------------------------------
# 3. Package install helper
# ---------------------------------------------------------------------------
_pm_install() {
	local pkgs=("$@")
	[[ ${#pkgs[@]} -eq 0 ]] && return 0
	local retries=3
	local rc=0
	while [[ $retries -gt 0 ]]; do
		case "$PM" in
			apt)
				# Refresh package list only if empty (avoid unnecessary updates)
				_elevate apt-get update -qq 2>/dev/null || true
				_elevate env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}" 2>/dev/null && return 0
				;;
			dnf)
				_elevate dnf install -y "${pkgs[@]}" 2>/dev/null && return 0
				;;
			pacman)
				_elevate pacman -S --noconfirm --needed "${pkgs[@]}" 2>/dev/null && return 0
				;;
			zypper)
				_elevate zypper install -y "${pkgs[@]}" 2>/dev/null && return 0
				;;
			xbps-install)
				_elevate xbps-install -y "${pkgs[@]}" 2>/dev/null && return 0
				;;
			apk)
				_elevate apk add "${pkgs[@]}" 2>/dev/null && return 0
				;;
			*)
				echo "  ⚠ No supported package manager found." >&2
				echo "  Please install manually: ${pkgs[*]}" >&2
				return 1
				;;
		esac
		rc=$?
		# On apt, a lock may block us — wait and retry
		if [[ "$PM" == "apt" && $rc -ne 0 ]]; then
			sleep 2
			retries=$((retries - 1))
		else
			break
		fi
	done
	return $rc
}

# ---------------------------------------------------------------------------
# 4. Install OS prerequisites (curl, git, jq, fzf)
# ---------------------------------------------------------------------------
install_prereqs() {
	local core_pkgs=()
	command -v curl  &>/dev/null || core_pkgs+=("curl")
	command -v git   &>/dev/null || core_pkgs+=("git")
	command -v jq    &>/dev/null || core_pkgs+=("jq")
	command -v fzf   &>/dev/null || core_pkgs+=("fzf")

	if [[ ${#core_pkgs[@]} -eq 0 ]]; then
		echo "  ✔ Core prerequisites already satisfied."
	else
		echo "  ⏳ Installing: ${core_pkgs[*]}"
		_pm_install "${core_pkgs[@]}" && echo "  ✔ Done." || echo "  ⚠ Some packages may not have been installed."
	fi
}

install_prereqs

# ---------------------------------------------------------------------------
# 5. Install Go (needed for TUI)
# ---------------------------------------------------------------------------
_maybe_install_go() {
	[[ $NO_TUI -eq 1 ]] && return 1
	command -v go &>/dev/null && { echo "  ✔ Go: $(go version | head -1)"; return 0; }

	echo "  ⏳ Installing Go (required for TUI)..."
	local go_ok=0
	case "$PM" in
		apt)    _pm_install golang-go    && go_ok=1 ;;
		dnf)    _pm_install golang       && go_ok=1 ;;
		pacman) _pm_install go           && go_ok=1 ;;
		zypper) _pm_install go           && go_ok=1 ;;
		xbps-install) _pm_install go     && go_ok=1 ;;
		apk)    _pm_install go           && go_ok=1 ;;
	esac

	if [[ $go_ok -eq 0 ]]; then
		# Binary download fallback
		local ver="1.23.0" arch goarch
		arch=$(uname -m)
		case "$arch" in
			x86_64|amd64)  goarch="amd64" ;;
			aarch64|arm64) goarch="arm64" ;;
			i386|i686)     goarch="386"   ;;
			armv7l|armhf)  goarch="armv6l" ;;
			*)             goarch="amd64" ;;
		esac

		local tarball="go${ver}.linux-${goarch}.tar.gz"
		echo "  Downloading Go $ver ($goarch) from golang.org..."
		if curl -fsSL "https://go.dev/dl/${tarball}" -o "/tmp/${tarball}"; then
			_elevate mkdir -p /usr/local /etc/profile.d
			_elevate tar -C /usr/local -xzf "/tmp/${tarball}" && go_ok=1
			rm -f "/tmp/${tarball}"
			if [[ $go_ok -eq 1 ]]; then
				export PATH="/usr/local/go/bin:$PATH"
				echo 'export PATH=$PATH:/usr/local/go/bin' | _elevate tee /etc/profile.d/go.sh >/dev/null
			fi
		fi
	fi

	if command -v go &>/dev/null; then
		echo "  ✔ Go: $(go version)"
	else
		echo "  ⚠ Go install failed; falling back to bash-only mode."
		NO_TUI=1
	fi
}

_maybe_install_go

# ---------------------------------------------------------------------------
# 6. Write files to CORE_HOME
# ---------------------------------------------------------------------------
echo ""
mkdir -p "$CORE_HOME" "$CORE_BIN" "$CORE_CONFIG_DIR" "$CORE_STATE_DIR"
echo "Installing files to $CORE_HOME ..."

cp -r "$SRC_DIR/modules" "$CORE_HOME/"
cp -r "$SRC_DIR/lib"     "$CORE_HOME/"
cp -r "$SRC_DIR/plugins" "$CORE_HOME/" 2>/dev/null || true
cp "$SRC_DIR/core"       "$CORE_HOME/core"
chmod +x "$CORE_HOME/core"

# ---------------------------------------------------------------------------
# 7. Build Go TUI binary
# ---------------------------------------------------------------------------
if [[ $NO_TUI -eq 0 ]] && command -v go &>/dev/null; then
	echo "Building TUI binary..."
	cd "$SRC_DIR/cmd/core-tui"
	go mod tidy 2>/dev/null || true
	if go build -ldflags="-s -w" -o core-tui . 2>/dev/null; then
		cp core-tui "$CORE_HOME/core-tui"
		ln -sf "$CORE_HOME/core-tui" "$CORE_BIN/core-tui"
		echo "  ✔ TUI built."
	else
		echo "  ⚠ TUI build failed; bash-only mode."
	fi
fi

# ---------------------------------------------------------------------------
# 8. Final setup
# ---------------------------------------------------------------------------
ln -sf "$CORE_HOME/core" "$CORE_BIN/core"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
	echo "  ✔ Added ~/.local/bin to PATH in ~/.bashrc"
fi

if [[ ! -f "$CORE_CONFIG_DIR/config.toml" ]]; then
	sed "s|CORE_HOME_PLACEHOLDER|$CORE_HOME|g" "$SRC_DIR/core.conf.example" > "$CORE_CONFIG_DIR/config.toml"
fi

echo '{"modules":{}}' > "$CORE_STATE_DIR/installed.json"

# Clean up temp dir on piped install
if [[ $PIPED_INSTALL -eq 1 ]]; then
	rm -rf "$WORK_DIR"
fi

# ---------------------------------------------------------------------------
# 9. Done
# ---------------------------------------------------------------------------
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
