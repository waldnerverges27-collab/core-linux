#!/usr/bin/env bash
set -euo pipefail

tool="${1:?Usage: $0 <tool_name>}"

case "$tool" in
	jenkins)
		sudo apt-get install -y openjdk-17-jre 2>/dev/null || true
		wget -q https://get.jenkins.io/war-stable/latest/jenkins.war -O /usr/local/bin/jenkins.war
		;;
	github-actions)
		curl -fsSL https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz | sudo tar -xz -C /opt/actions-runner 2>/dev/null || sudo mkdir -p /opt/actions-runner && curl -fsSL https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz | sudo tar -xz -C /opt/actions-runner
		;;
	gitlab-ci)
		curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
		sudo apt-get install -y gitlab-runner
		;;
	drone)
		curl -fsSL https://github.com/harness/drone-cli/releases/latest/download/drone_linux_amd64.tar.gz | sudo tar -xz -C /usr/local/bin drone
		;;
	argo)
		curl -fsSL https://github.com/argoproj/argo-workflows/releases/latest/download/argo-linux-amd64.gz | zcat > /usr/local/bin/argo && chmod +x /usr/local/bin/argo
		;;
	dagger)
		curl -fsSL https://dl.dagger.io/dagger/install.sh | sh
		;;
	*)
		echo "Unknown tool: $tool"
		exit 1
		;;
esac

echo "Done: $tool"
