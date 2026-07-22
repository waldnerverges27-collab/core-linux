#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# Platform detection for core-linux
# Single source of truth — all distro/arch/pkg logic lives here.
#
# Distro families recognised:
#   debian  — Debian, Ubuntu, Mint, Pop, Elementary, Zorin, Kali, Neon
#   fedora  — Fedora, RHEL, CentOS, Rocky, Alma, Oracle, Amazon Linux
#   arch    — Arch, Manjaro, EndeavourOS, Artix, Garuda, ArcoLinux, CachyOS
#   opensuse— openSUSE (Leap, Tumbleweed), SLES
#   void    — Void Linux
#   alpine  — Alpine Linux
#   nixos   — NixOS
#   solus   — Solus
#   gentoo  — Gentoo
#   slackware — Slackware
#   unknown — anything else

DISTRO=""
DISTRO_FAMILY=""
DISTRO_ID=""
DISTRO_VERSION=""
DISTRO_VERSION_ID=""
PM=""
PM_UPDATE_CMD=""
PM_INSTALL_CMD=""
ARCH=""
ARCH_GO=""       # Go architecture naming
ARCH_DEB=""      # Debian package architecture

# ------------------------------------------------------------------
# detect_distro — populate all DISTRO_* and PM_* variables
# ------------------------------------------------------------------
detect_distro() {
	# Allow override (useful for testing)
	if [[ -n "${CORE_FORCE_DISTRO:-}" ]]; then
		DISTRO_FAMILY="$CORE_FORCE_DISTRO"
		_set_pm
		return
	fi

	# --- os-release (modern, preferred) ---
	if [[ -f /etc/os-release ]]; then
		. /etc/os-release
		DISTRO_ID="${ID,,}"
		DISTRO_VERSION_ID="${VERSION_ID:-}"
		local id_like="${ID_LIKE,,}"

		case "$DISTRO_ID" in
			ubuntu|debian|linuxmint|pop|elementary|neon|zorin|kali|deepin|uos)
				DISTRO_FAMILY="debian" ;;
			fedora|rhel|centos|rocky|alma|ol|amzn|pidora|nobara)
				DISTRO_FAMILY="fedora" ;;
			arch|manjaro|endeavouros|artix|archlabs|garuda|arcolinux|cachyos|rebornos)
				DISTRO_FAMILY="arch" ;;
			opensuse*|suse|sles)
				DISTRO_FAMILY="opensuse" ;;
			void)  DISTRO_FAMILY="void"   ;;
			alpine) DISTRO_FAMILY="alpine" ;;
			nixos) DISTRO_FAMILY="nixos"  ;;
			solus) DISTRO_FAMILY="solus"  ;;
			gentoo) DISTRO_FAMILY="gentoo"; DISTRO_FAMILY="gentoo" ;;
			slackware) DISTRO_FAMILY="slackware" ;;
			*)
				# Fallback: ID_LIKE
				case "$id_like" in
					*debian*|*ubuntu*)   DISTRO_FAMILY="debian"   ;;
					*fedora*|*rhel*|*centos*) DISTRO_FAMILY="fedora" ;;
					*arch*)              DISTRO_FAMILY="arch"     ;;
					*suse*)              DISTRO_FAMILY="opensuse" ;;
					*void*)              DISTRO_FAMILY="void"     ;;
					*)                   DISTRO_FAMILY="unknown"  ;;
				esac
				;;
		esac

	# --- fallback: lsb-release ---
	elif [[ -f /etc/lsb-release ]]; then
		. /etc/lsb-release
		DISTRO_ID="${DISTRIB_ID,,}"
		DISTRO_VERSION_ID="${DISTRIB_RELEASE:-}"
		case "$DISTRO_ID" in
			ubuntu|debian|linuxmint|pop) DISTRO_FAMILY="debian" ;;
			*) DISTRO_FAMILY="unknown" ;;
		esac

	# --- fallback: legacy redhat-release ---
	elif [[ -f /etc/redhat-release ]]; then
		DISTRO_FAMILY="fedora"
		DISTRO_ID="rhel"
		DISTRO_VERSION_ID=$(grep -oP '[0-9]+\.[0-9]+' /etc/redhat-release 2>/dev/null || echo "")

	# --- fallback: debian_version ---
	elif [[ -f /etc/debian_version ]]; then
		DISTRO_FAMILY="debian"
		DISTRO_ID="debian"
		DISTRO_VERSION_ID=$(cat /etc/debian_version 2>/dev/null || "")

	# --- fallback: arch-release (arch has this file, usually empty) ---
	elif [[ -f /etc/arch-release ]]; then
		DISTRO_FAMILY="arch"
		DISTRO_ID="arch"

	# --- fallback: alpine-release ---
	elif [[ -f /etc/alpine-release ]]; then
		DISTRO_FAMILY="alpine"
		DISTRO_ID="alpine"
		DISTRO_VERSION_ID=$(cat /etc/alpine-release 2>/dev/null || "")

	else
		DISTRO_FAMILY="unknown"
		DISTRO_ID="unknown"
	fi

	_set_pm
}

# ------------------------------------------------------------------
# _set_pm — set PM_* variables based on DISTRO_FAMILY
# ------------------------------------------------------------------
_set_pm() {
	case "$DISTRO_FAMILY" in
		debian)
			PM="apt"
			PM_UPDATE_CMD="apt-get update -qq"
			PM_INSTALL_CMD="apt-get install -y -qq"
			;;
		fedora)
			PM="dnf"
			PM_INSTALL_CMD="dnf install -y"
			;;
		arch)
			PM="pacman"
			PM_INSTALL_CMD="pacman -S --noconfirm --needed"
			;;
		opensuse)
			PM="zypper"
			PM_INSTALL_CMD="zypper install -y"
			;;
		void)
			PM="xbps-install"
			PM_INSTALL_CMD="xbps-install -y"
			;;
		alpine)
			PM="apk"
			PM_INSTALL_CMD="apk add"
			;;
		nixos)
			PM="nix-env"
			PM_INSTALL_CMD="nix-env -iA"
			;;
		solus)
			PM="eopkg"
			PM_INSTALL_CMD="eopkg install -y"
			;;
		gentoo)
			PM="emerge"
			PM_INSTALL_CMD="emerge --ask n"
			;;
		slackware)
			PM="slackpkg"
			PM_INSTALL_CMD="slackpkg install"
			;;
		*)
			PM=""
			PM_INSTALL_CMD=""
			;;
	esac
}

# ------------------------------------------------------------------
# detect_arch — populate ARCH, ARCH_GO, ARCH_DEB
# ------------------------------------------------------------------
detect_arch() {
	ARCH="${CORE_ARCH:-$(uname -m)}"

	case "$ARCH" in
		x86_64|amd64)
			ARCH_GO="amd64"
			ARCH_DEB="amd64"
			;;
		aarch64|arm64)
			ARCH_GO="arm64"
			ARCH_DEB="arm64"
			;;
		i386|i686|i86pc)
			ARCH_GO="386"
			ARCH_DEB="i386"
			;;
		armv7l|armhf)
			ARCH_GO="armv6l"
			ARCH_DEB="armhf"
			;;
		armv6l|armv6)
			ARCH_GO="armv6l"
			ARCH_DEB="armel"
			;;
		riscv64)
			ARCH_GO="riscv64"
			ARCH_DEB="riscv64"
			;;
		s390x)
			ARCH_GO="s390x"
			ARCH_DEB="s390x"
			;;
		ppc64le)
			ARCH_GO="ppc64le"
			ARCH_DEB="ppc64el"
			;;
		*)
			ARCH_GO="$ARCH"
			ARCH_DEB="$ARCH"
			;;
	esac
}

# ------------------------------------------------------------------
# detect_init_system
# ------------------------------------------------------------------
detect_init_system() {
	if command -v systemctl &>/dev/null; then
		echo "systemd"
	elif command -v rc-service &>/dev/null || [[ -f /sbin/openrc ]]; then
		echo "openrc"
	elif [[ -f /sbin/runit ]]; then
		echo "runit"
	elif command -v supervisorctl &>/dev/null; then
		echo "supervisord"
	else
		echo "unknown"
	fi
}

# ------------------------------------------------------------------
# detect_shell_rc
# ------------------------------------------------------------------
detect_shell_rc() {
	local shell_name
	shell_name="$(basename "${SHELL:-bash}")"
	case "$shell_name" in
		zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
		bash) echo "${HOME}/.bashrc" ;;
		fish) echo "${HOME}/.config/fish/config.fish" ;;
		*)    echo "${HOME}/.profile" ;;
	esac
}

detect_shell_name() {
	basename "${SHELL:-bash}"
}

# ------------------------------------------------------------------
# Environment checks
# ------------------------------------------------------------------
is_wsl() {
	[[ -f /proc/version && "$(head -1 /proc/version)" == *"Microsoft"* ]] ||
	[[ -f /proc/sys/kernel/osrelease && "$(cat /proc/sys/kernel/osrelease)" == *"WSL"* ]]
}

is_container() {
	[[ -f /.dockerenv ]] || grep -qE '(docker|lxc|containerd)' /proc/1/cgroup 2>/dev/null || return 1
}

available_memory_mb() {
	local mem_kb
	if [[ -f /proc/meminfo ]]; then
		mem_kb=$(grep ^MemTotal /proc/meminfo | awk '{print $2}')
		echo $(( mem_kb / 1024 ))
	else
		echo "0"
	fi
}

# ------------------------------------------------------------------
# Auto-run detection at source time (so variables are available)
# ------------------------------------------------------------------
detect_distro
detect_arch
