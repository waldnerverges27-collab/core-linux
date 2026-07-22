package utils

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

// PlatformInfo holds detected platform details
type PlatformInfo struct {
	Distro      string `json:"distro"`
	PkgManager  string `json:"pkg_manager"`
	Arch        string `json:"arch"`
	InitSystem  string `json:"init_system"`
	MemoryMB    int    `json:"memory_mb"`
	IsWSL       bool   `json:"is_wsl"`
	IsContainer bool   `json:"is_container"`
}

// DetectPlatform detects the current Linux platform
func DetectPlatform() PlatformInfo {
	return PlatformInfo{
		Distro:      detectDistro(),
		PkgManager:  detectPkgManager(),
		Arch:        detectArch(),
		InitSystem:  detectInitSystem(),
		MemoryMB:    detectMemoryMB(),
		IsWSL:       detectWSL(),
		IsContainer: detectContainer(),
	}
}

func detectDistro() string {
	if d := os.Getenv("CORE_FORCE_DISTRO"); d != "" {
		return d
	}

	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return "unknown"
	}

	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") {
			id := strings.Trim(strings.TrimPrefix(line, "ID="), "\"")
			switch strings.ToLower(id) {
			case "ubuntu", "debian", "linuxmint", "pop":
				return "ubuntu"
			case "fedora", "rhel", "centos", "rocky", "alma":
				return "fedora"
			case "arch", "manjaro", "endeavouros":
				return "arch"
			case "opensuse", "suse", "sles":
				return "opensuse"
			case "void":
				return "void"
			}
		}
	}
	return "unknown"
}

func detectPkgManager() string {
	switch detectDistro() {
	case "ubuntu":
		return "apt"
	case "fedora":
		return "dnf"
	case "arch":
		return "pacman"
	case "opensuse":
		return "zypper"
	case "void":
		return "xbps-install"
	default:
		return "unknown"
	}
}

func detectArch() string {
	arch := os.Getenv("CORE_ARCH")
	if arch != "" {
		return arch
	}
	//nolint:govet
	data, err := os.ReadFile("/proc/sys/kernel/arch")
	if err == nil {
		return strings.TrimSpace(string(data))
	}
	return "unknown"
}

func detectInitSystem() string {
	if _, err := os.Stat("/run/systemd/system"); err == nil {
		return "systemd"
	}
	if _, err := os.Stat("/sbin/openrc"); err == nil {
		return "openrc"
	}
	if _, err := os.Stat("/sbin/runit"); err == nil {
		return "runit"
	}
	return "unknown"
}

func detectMemoryMB() int {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0
	}
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "MemTotal:") {
			var kb int
			fmt.Sscanf(line, "MemTotal: %d kB", &kb)
			return kb / 1024
		}
	}
	return 0
}

func detectWSL() bool {
	data, err := os.ReadFile("/proc/version")
	if err == nil && strings.Contains(strings.ToLower(string(data)), "microsoft") {
		return true
	}
	data, err = os.ReadFile("/proc/sys/kernel/osrelease")
	if err == nil && strings.Contains(strings.ToLower(string(data)), "wsl") {
		return true
	}
	return false
}

func detectContainer() bool {
	if _, err := os.Stat("/.dockerenv"); err == nil {
		return true
	}
	data, err := os.ReadFile("/proc/1/cgroup")
	if err == nil {
		content := string(data)
		if strings.Contains(content, "docker") || strings.Contains(content, "lxc") || strings.Contains(content, "containerd") {
			return true
		}
	}
	return false
}
