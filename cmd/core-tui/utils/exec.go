package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// ExecResult holds the output of a shell command
type ExecResult struct {
	Stdout string
	Stderr string
	Code   int
}

// RunCommand executes a shell command and returns the result
func RunCommand(name string, args ...string) ExecResult {
	cmd := exec.Command(name, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()

	result := ExecResult{
		Stdout: strings.TrimSpace(stdout.String()),
		Stderr: strings.TrimSpace(stderr.String()),
		Code:   0,
	}

	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			result.Code = exitErr.ExitCode()
		} else {
			result.Code = -1
			result.Stderr = err.Error()
		}
	}

	return result
}

// RunBash executes a bash command string
func RunBash(command string) ExecResult {
	return RunCommand("bash", "-c", command)
}

// CoreHome returns the CORE_HOME directory
func CoreHome() string {
	if h := os.Getenv("CORE_HOME"); h != "" {
		return h
	}
	return fmt.Sprintf("%s/.local/share/core-linux", os.Getenv("HOME"))
}

// RunCore executes a core-linux CLI command
func RunCore(args ...string) ExecResult {
	corePath := fmt.Sprintf("%s/core", CoreHome())
	return RunCommand("bash", append([]string{corePath}, args...)...)
}

// ModuleInfo holds parsed module manifest data
type ModuleInfo struct {
	Name         string   `json:"name"`
	Version      string   `json:"version"`
	Description  string   `json:"description"`
	Icon         string   `json:"icon"`
	Dependencies []string `json:"dependencies"`
	Tools        []ToolInfo `json:"tools"`
}

// ToolInfo holds parsed tool manifest data
type ToolInfo struct {
	Name        string `json:"name"`
	Flag        string `json:"flag"`
	Description string `json:"description"`
	VersionCmd  string `json:"version_cmd"`
	SizeMB      int    `json:"size_mb"`
}

// LoadModuleManifest reads and parses a module's manifest.json
func LoadModuleManifest(module string) (*ModuleInfo, error) {
	path := fmt.Sprintf("%s/modules/%s/manifest.json", CoreHome(), module)
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading manifest for %s: %w", module, err)
	}

	var info ModuleInfo
	if err := json.Unmarshal(data, &info); err != nil {
		return nil, fmt.Errorf("parsing manifest for %s: %w", module, err)
	}

	return &info, nil
}

// ListModules returns all available module names
func ListModules() ([]string, error) {
	path := fmt.Sprintf("%s/modules", CoreHome())
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil, err
	}

	var modules []string
	for _, e := range entries {
		if e.IsDir() {
			modules = append(modules, e.Name())
		}
	}

	return modules, nil
}

// GetInstalledModules returns installed modules from state
func GetInstalledModules() ([]string, error) {
	result := RunBash(fmt.Sprintf(`
		source %s/lib/core/state.sh
		get_installed_modules
	`, CoreHome()))

	if result.Code != 0 {
		return nil, fmt.Errorf("getting installed modules: %s", result.Stderr)
	}

	var modules []string
	for _, line := range strings.Split(result.Stdout, "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			modules = append(modules, line)
		}
	}

	return modules, nil
}

// InstallModule installs a module via the core CLI
func InstallModule(module string, tools ...string) ExecResult {
	args := []string{"install", module}
	args = append(args, tools...)
	return RunCore(args...)
}

// UninstallModule uninstalls a module via the core CLI
func UninstallModule(module string, tools ...string) ExecResult {
	args := []string{"uninstall", module}
	args = append(args, tools...)
	return RunCore(args...)
}
