#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	docker)
		curl -fsSL https://get.docker.com | sh
		sudo usermod -aG docker "$USER" 2>/dev/null || true
		;;
	kubectl)
		curl -LO https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl
		sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
		rm -f kubectl
		;;
	helm)
		curl -fsSL https://get.helm.sh/helm-v3.15.0-linux-amd64.tar.gz | sudo tar -xz -C /usr/local/bin --strip=1 linux-amd64/helm
		;;
	terraform)
		curl -fsSL https://releases.hashicorp.com/terraform/1.9.0/terraform_1.9.0_linux_amd64.zip | zcat > /usr/local/bin/terraform
		chmod +x /usr/local/bin/terraform
		;;
	ansible)
		sudo apt-get install -y ansible
		;;
	act)
		curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Done: $tool"
