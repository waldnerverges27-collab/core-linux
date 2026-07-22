#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	jenkins) sudo rm -f /usr/local/bin/jenkins.war 2>/dev/null || true ;;
	github-actions) sudo rm -rf /opt/actions-runner 2>/dev/null || true ;;
	gitlab-ci) sudo apt-get remove -y gitlab-runner 2>/dev/null || true ;;
	drone) sudo rm -f /usr/local/bin/drone 2>/dev/null || true ;;
	argo) sudo rm -f /usr/local/bin/argo 2>/dev/null || true ;;
	dagger) rm -f /usr/local/bin/dagger 2>/dev/null || true ;;
	*) echo "Unknown tool: $tool"; exit 1 ;;
esac

echo "Removed: $tool"
