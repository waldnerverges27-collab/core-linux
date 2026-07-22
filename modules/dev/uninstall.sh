#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	docker) sudo apt-get remove -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true ;;
	kubectl) sudo rm -f /usr/local/bin/kubectl 2>/dev/null || true ;;
	helm) sudo rm -f /usr/local/bin/helm 2>/dev/null || true ;;
	terraform) sudo rm -f /usr/local/bin/terraform 2>/dev/null || true ;;
	ansible) sudo apt-get remove -y ansible 2>/dev/null || true ;;
	act) sudo rm -f /usr/local/bin/act 2>/dev/null || true ;;
	*) echo "Unknown tool: $tool"; exit 1 ;;
esac

echo "Removed: $tool"
