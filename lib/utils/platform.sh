#!/usr/bin/env bash
set -euo pipefail

# Platform detection for core-linux
# Supports: ubuntu/debian, fedora/rhel/centos, arch/manjaro, opensuse, void

detect_distro() {
	if [[ -n "${CORE_FORCE_DISTRO:-}" ]]; then
		echo "$CORE_FORCE_DISTRO"
		return
	fi
	if [[ ! -f /etc/os-release ]]; then
		echo "unknown"
		return
	fi
	. /etc/os-release
	case "${ID,,}" in
		ubuntu|debian|linuxmint|pop|elementary) echo "ubuntu" ;;
		fedora|rhel|centos|rocky|alma) echo "fedora" ;;
		arch|manjaro|endeavouros|artix|archlabs) echo "arch" ;;
		opensuse*|suse|sles) echo "opensuse" ;;
		void) echo "void" ;;
		alpine) echo "alpine" ;;
		nixos) echo "nixos" ;;
		*) echo "unknown" ;;
	esac
}

detect_pkg_manager() {
	case "$(detect_distro)" in
		ubuntu) echo "apt" ;;
		fedora) echo "dnf" ;;
		arch) echo "pacman" ;;
		opensuse) echo "zypper" ;;
		void) echo "xbps-install" ;;
		alpine) echo "apk" ;;
		nixos) echo "nix-env" ;;
		*) echo "unknown" ;;
	esac
}

detect_arch() {
	local arch
	arch=$(uname -m)
	case "$arch" in
		x86_64|amd64) echo "amd64" ;;
		aarch64|arm64) echo "arm64" ;;
		i386|i686|i86pc) echo "386" ;;
		*) echo "$arch" ;;
	esac
}

detect_init_system() {
	if pidof systemd &>/dev/null || command -v systemctl &>/dev/null; then
		echo "systemd"
		return
	fi
	if command -v rc-service &>/dev/null || [[ -f /sbin/openrc ]]; then
		echo "openrc"
		return
	fi
	if [[ -f /sbin/runit ]]; then
		echo "runit"
		return
	fi
	if command -v supervisorctl &>/dev/null; then
		echo "supervisord"
		return
	fi
	echo "unknown"
}

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

is_wsl() {
	[[ -f /proc/version && "$(head -1 /proc/version)" == *"Microsoft"* ]] || [[ -f /proc/sys/kernel/osrelease && "$(cat /proc/sys/kernel/osrelease)" == *"WSL"* ]]
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
