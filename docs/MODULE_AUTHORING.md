# Module Authoring Guide

This guide explains how to create new modules for core-linux.

## Module Structure

Each module lives in `modules/<name>/` and contains:

```
modules/<name>/
├── manifest.json      # Module definition (REQUIRED)
├── install.sh         # Tool installer (RECOMMENDED)
├── uninstall.sh       # Tool uninstaller (RECOMMENDED)
└── verify.sh          # Verification script (RECOMMENDED)
```

## Manifest Schema

```json
{
  "$schema": "core-linux-module-v1",
  "name": "my-module",
  "version": "1.0.0",
  "description": "Description of my module",
  "author": "Your Name",
  "icon": "🔌",
  "dependencies": ["lang"],
  "conflicts": [],
  "platform": {
    "min_ram_mb": 512,
    "requires_gpu": false,
    "supported_distros": ["ubuntu", "fedora", "arch", "opensuse", "void"]
  },
  "tools": [
    {
      "name": "mytool",
      "flag": "--mytool",
      "description": "Description of this tool",
      "version_cmd": "mytool --version",
      "install": {
        "ubuntu": "sudo apt-get install -y mytool",
        "fedora": "sudo dnf install -y mytool",
        "arch": "sudo pacman -S --noconfirm mytool",
        "default": "curl -fsSL https://example.com/install.sh | sh"
      },
      "uninstall": {
        "default": "sudo apt-get remove -y mytool"
      },
      "post_install": "systemctl enable mytool 2>/dev/null || true",
      "size_mb": 50,
      "tags": ["category1", "category2"]
    }
  ]
}
```

## Install Script

The install script receives a tool name as its first argument:

```bash
#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
  mytool)
    echo "Installing mytool..."
    # Installation commands here
    ;;
  *)
    echo "Unknown tool: $tool"
    exit 1
    ;;
esac
```

## Best Practices

1. **Idempotency**: Running install twice should never break anything
2. **Error handling**: Check command success and provide meaningful error messages
3. **Distro support**: Provide at least ubuntu and default install commands
4. **Version detection**: Provide a `version_cmd` that returns just the version string
5. **Tags**: Use descriptive tags for searchability
6. **Size estimation**: Provide accurate `size_mb` estimates
7. **Clean uninstall**: Remove all files created during install
