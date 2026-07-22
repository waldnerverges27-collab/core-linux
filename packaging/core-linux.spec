Summary: core-linux — Modular Development Environment
Name: core-linux
Version: 1.0.0
Release: 1
License: MIT
URL: https://github.com/waldnerverges27-collab/core-linux
Source0: core-linux-%{version}.tar.gz
BuildArch: noarch
BuildRequires: bash, gzip
Requires: bash >= 5.0, curl, git, jq, fzf

%description
core-linux is a production-grade modular development environment
for Linux terminals. It provides a unified CLI and TUI for managing
development tools, languages, databases, AI assistants, and more.

%install
mkdir -p %{buildroot}%{_bindir}
cp core %{buildroot}%{_bindir}/core
cp cmd/core-tui/core-tui %{buildroot}%{_bindir}/core-tui 2>/dev/null || true

mkdir -p %{buildroot}%{_datadir}/core-linux
cp -r modules lib plugins %{buildroot}%{_datadir}/core-linux/

%files
%{_bindir}/core
%{_bindir}/core-tui
%{_datadir}/core-linux/modules/
%{_datadir}/core-linux/lib/
%{_datadir}/core-linux/plugins/

%post
echo "core-linux installed. Run 'core' to launch."

%changelog
* Tue Jul 22 2026 core-linux <dev@core-linux.dev> - 1.0.0
- Initial release
