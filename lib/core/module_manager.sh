#!/usr/bin/env bash
set -euo pipefail

# Module manager for core-linux
# Install, uninstall, update, reinstall, list, show, verify modules

CORE_HOME="${CORE_HOME:-$HOME/.local/share/core-linux}"

source "$CORE_HOME/lib/utils/logger.sh"
source "$CORE_HOME/lib/utils/platform.sh"
source "$CORE_HOME/lib/utils/prompt.sh"
source "$CORE_HOME/lib/core/state.sh"
source "$CORE_HOME/lib/core/resolver.sh"

module_exists() {
	[[ -d "$CORE_HOME/modules/$1" && -f "$CORE_HOME/modules/$1/manifest.json" ]]
}

module_manifest() {
	local module="${1:?Usage: module_manifest <module>}"
	echo "$CORE_HOME/modules/$module/manifest.json"
}

tool_exists_in_manifest() {
	local module="$1" tool="$2"
	local manifest
	manifest=$(module_manifest "$module")
	jq -e ".tools[] | select(.name == \"$tool\")" "$manifest" &>/dev/null
}

# ------------------------------------------------------------------
# Batch-read ALL module manifests in one jq call
# Returns JSON array: [{name, icon, description, deps, tools: [{name, flag, description}]}]
# ------------------------------------------------------------------
_batch_modules_json() {
	local pattern="$CORE_HOME/modules/*/manifest.json"
	# shellcheck disable=SC2086
	jq -s '[.[] | {name, icon, description, dependencies, tools: [.tools[] | {name, flag, description, tags}]}]' $pattern 2>/dev/null || echo "[]"
}

# ------------------------------------------------------------------
# Batch-read installed state (one jq call, cached)
# ------------------------------------------------------------------
_installed_map() {
	local cache_file="${CORE_TMP:-/tmp}/core-installed-cache-$$.json"
	if [[ ! -f "$cache_file" ]]; then
		state_init
		jq -r '.modules | to_entries[] | .key as $m | .value.tools | to_entries[] | "\($m)/\(.key)"' "$CORE_STATE_FILE" 2>/dev/null > "$cache_file" || true
	fi
	cat "$cache_file"
}

_clear_installed_cache() {
	rm -f "${CORE_TMP:-/tmp}/core-installed-cache-$$.json"
}

# ------------------------------------------------------------------
# Spinner for slow operations
# ------------------------------------------------------------------
_spinner() {
	local msg="$1"
	local pid=$!
	local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
	local i=0
	while kill -0 "$pid" 2>/dev/null; do
		printf "\r%s %s " "${spin:$i:1}" "$msg"
		i=$(( (i+1) % ${#spin} ))
		sleep 0.1
	done
	printf "\r✔ %s\n" "$msg"
}

# ------------------------------------------------------------------
# module_list — muestra módulos usando batch jq (UNA llamada)
# ------------------------------------------------------------------
module_list() {
	local module="${1:-}"

	if [[ -n "$module" ]]; then
		# --- Mostrar UN módulo específico con todos sus tools ---
		local manifest
		manifest=$(module_manifest "$module")
		if [[ ! -f "$manifest" ]]; then
			log_error "Module $module not found"
			return 1
		fi

		# Una sola llamada jq para extraer TODO el contenido del módulo
		read -r name version description deps icon tool_count <<< \
			$(jq -r '[.name, .version, .description, (.dependencies | join(",")), .icon, (.tools | length)] | @tsv' "$manifest" 2>/dev/null)
		version="${version:-1.0.0}"
		deps="${deps:-none}"

		echo "$icon $name v$version"
		echo "  $description"
		echo "  Dependencies: ${deps:-none}"
		echo ""
		echo "Tools:"

		if [[ "${tool_count:-0}" -eq 0 ]]; then
			echo "  (none)"
		else
			# Batch: extraer todos los tools + sus estados de instalación en UNA llamada
			local state_file="$CORE_STATE_FILE"
			jq -r --arg mod "$module" '
				.tools[] | [
					.name,
					.flag,
					.description,
					(.tags // []) | join(",")
				] | @tsv
			' "$manifest" 2>/dev/null | while IFS=$'\t' read -r tname tflag tdesc ttags; do
				local status="✗"
				local ver_info=""
				if tool_is_installed "$module" "$tname"; then
					status="✔"
					local ver
					ver=$(get_tool_version "$module" "$tname")
					ver_info=" ($ver)"
				fi
				echo "  $status $tflag $tname — $tdesc$ver_info"
			done
		fi

	elif [[ -d "$CORE_HOME/modules" ]]; then
		# --- Listar TODOS los módulos con UNA sola llamada jq ---
		local modules_json
		modules_json=$(_batch_modules_json)
		local installed_map
		installed_map=$(_installed_map)

		echo "$modules_json" | jq -r '.[] | [.name, .icon, .description] | @tsv' 2>/dev/null | while IFS=$'\t' read -r name icon desc; do
			local status="✗"
			if echo "$installed_map" | grep -q "^$name/"; then
				status="✔"
			fi
			echo "$status $icon $name — $desc"
		done
	fi
}

# ------------------------------------------------------------------
# module_show — details of a module or tool
# ------------------------------------------------------------------
module_show() {
	local target="${1:?Usage: module_show <module|tool>}"
	if module_exists "$target"; then
		module_list "$target"
		return
	fi

	# Buscar el tool en todos los manifests (una sola vez)
	local result
	result=$(jq -s --arg tool "$target" '
		[.[].tools[] | select(.name == $tool)][0] // empty
	' "$CORE_HOME"/modules/*/manifest.json 2>/dev/null || echo "")

	if [[ -z "$result" || "$result" == "null" ]]; then
		log_error "Module or tool not found: $target"
		return 1
	fi

	local name mod_desc mod_flag mod_size mod_tags found_mod
	name=$(jq -r '.name' <<<"$result")
	mod_desc=$(jq -r '.description // "N/A"' <<<"$result")
	mod_flag=$(jq -r '.flag // "N/A"' <<<"$result")
	mod_size=$(jq -r '.size_mb // "?"' <<<"$result")
	mod_tags=$(jq -r '.tags | join(", ")' <<<"$result" 2>/dev/null || echo "N/A")
	found_mod=$(jq -s --arg tool "$target" '[paths as $p | select(getpath($p)? == $tool) | $p[0]] | first // ""' "$CORE_HOME"/modules/*/manifest.json 2>/dev/null || echo "")

	echo "Name: $name"
	echo "Module: ${found_mod:-?}"
	echo "Description: $mod_desc"
	echo "Flag: $mod_flag"
	echo "Size: $mod_size MB"
	echo "Tags: $mod_tags"

	if tool_is_installed "${found_mod:-?}" "$name" 2>/dev/null; then
		local ver
		ver=$(get_tool_version "${found_mod:-?}" "$name")
		echo "Status: ✔ Installed ($ver)"
	else
		echo "Status: ✗ Not installed"
	fi
}

# ------------------------------------------------------------------
# System-level dependency resolution for tool installs
# ------------------------------------------------------------------
_elevate_cmd() {
	if [[ $EUID -eq 0 ]]; then
		"$@"
	elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
		sudo "$@"
	elif command -v sudo &>/dev/null; then
		sudo "$@" 2>&1 || { log_debug "sudo failed (maybe no passwordless sudo)"; return 1; }
	else
		log_debug "No privilege escalation available for: $*"
		return 1
	fi
}

_auto_install_sys_pkg() {
	local pkg="$1"
	local pm_cmd="$PM_INSTALL_CMD"
	[[ -z "$pm_cmd" ]] && { log_warn "No package manager available; cannot install $pkg"; return 1; }

	log_info "Installing system package: $pkg"
	case "$PM" in
		apt)
			_elevate_cmd apt-get update -qq 2>/dev/null || true
			_elevate_cmd env DEBIAN_FRONTEND=noninteractive $pm_cmd "$pkg" 2>/dev/null
			;;
		*)
			_elevate_cmd $pm_cmd "$pkg" 2>/dev/null
			;;
	esac
}

_ensure_cmds() {
	local cmds=("$@")
	local missing=()
	local c
	for c in "${cmds[@]}"; do
		command -v "$c" &>/dev/null || missing+=("$c")
	done
	[[ ${#missing[@]} -eq 0 ]] && return 0

	log_info "Auto-installando: ${missing[*]}"
	for c in "${missing[@]}"; do
		case "$c" in
			curl)  _auto_install_sys_pkg "curl"  && log_success "Instalado curl"  || log_warn "No se pudo instalar curl"  ;;
			wget)  _auto_install_sys_pkg "wget"  && log_success "Instalado wget"  || log_warn "No se pudo instalar wget"  ;;
			git)   _auto_install_sys_pkg "git"   && log_success "Instalado git"   || log_warn "No se pudo instalar git"   ;;
			jq)    _auto_install_sys_pkg "jq"    && log_success "Instalado jq"    || log_warn "No se pudo instalar jq"    ;;
			pip3|pip)
				_auto_install_sys_pkg "python3-pip" && log_success "Instalado pip" ||
				_auto_install_sys_pkg "python-pip"  && log_success "Instalado pip" ||
				log_warn "No se pudo instalar pip" ;;
			node|npm)
				_auto_install_sys_pkg "nodejs" || _auto_install_sys_pkg "node" || log_warn "No se pudo instalar nodejs" ;;
			go)
				_auto_install_sys_pkg "golang" && log_success "Instalado golang" ||
				_auto_install_sys_pkg "go"     && log_success "Instalado go"     ||
				log_warn "No se pudo instalar go" ;;
			make)  _auto_install_sys_pkg "make"  && log_success "Instalado make"  || log_warn "No se pudo instalar make"  ;;
			*)     log_warn "No sé instalar '$c'; hazlo manualmente" ;;
		esac
	done
}

# ------------------------------------------------------------------
# Version comparison helpers
# ------------------------------------------------------------------
# Consulta al gestor de paquetes la versión candidata (más nueva disponible)
_pm_candidate_version() {
	local pkg="$1"
	case "$PM" in
		apt)
			apt-cache policy "$pkg" 2>/dev/null | grep 'Candidato' | awk '{print $2}'
			;;
		dnf)
			dnf info "$pkg" 2>/dev/null | grep -i '^Version' | awk '{print $3}'
			;;
		pacman)
			pacman -Si "$pkg" 2>/dev/null | grep -i '^Version' | awk '{print $3}'
			;;
		zypper)
			zypper info "$pkg" 2>/dev/null | grep '^Version' | awk '{print $3}'
			;;
		xbps-install)
			xbps-query -S "$pkg" 2>/dev/null | head -1 | awk '{print $2}'
			;;
		apk)
			apk search -e "$pkg" 2>/dev/null | head -1 | cut -d'-' -f2-
			;;
		*) echo "" ;;
	esac
}

# Comparación semver simple: 0 = igual, 1 = a > b, 2 = a < b
_ver_compare() {
	local a="$1" b="$2"
	[[ "$a" == "$b" ]] && { echo 0; return; }
	local IFS=.
	local -a pa pb
	read -ra pa <<< "${a//[^0-9.]/}"
	read -ra pb <<< "${b//[^0-9.]/}"
	for ((i=0; i<${#pa[@]} || i<${#pb[@]}; i++)); do
		local va="${pa[$i]:-0}"
		local vb="${pb[$i]:-0}"
		(( va > vb )) && { echo 1; return; }
		(( va < vb )) && { echo 2; return; }
	done
	echo 0
}

# ------------------------------------------------------------------
# module_install
# ------------------------------------------------------------------
module_install() {
	local module="${1:?Usage: module_install <module> [--tool1...]}"
	local upgrade_mode=0

	# Extraer --upgrade antes de shift (si viene como primer flag)
	if [[ "$module" == "--upgrade" ]]; then
		upgrade_mode=1
		module="${2:?Usage: module_install --upgrade <module> [--tool1...]}"
		shift 2
	else
		shift
	fi

	module_exists "$module" || { log_error "Module $module not found"; return 1; }
	check_conflicts "$module" || return 1

	local manifest
	manifest=$(module_manifest "$module")

	# Resolver dependencias
	local -a order
	mapfile -t order < <(resolve_install_order "$module" 2>/dev/null || true)
	local dep
	for dep in "${order[@]}"; do
		[[ "$dep" == "$module" ]] && continue
		if ! module_is_installed "$dep"; then
			log_step "Installing dependency: $dep"
			module_install "$dep" || { log_error "Failed dependency: $dep"; return 1; }
		fi
	done

	# Determinar tools a instalar
	local specific_tools=("$@")
	local -a tools=()

	if [[ ${#specific_tools[@]} -gt 0 ]]; then
		local flag tool_name
		for flag in "${specific_tools[@]}"; do
			flag="${flag#--}"
			tool_name=$(jq -r ".tools[] | select(.flag == \"--$flag\") | .name" "$manifest" 2>/dev/null || true)
			[[ -n "$tool_name" && "$tool_name" != "null" ]] && tools+=("$tool_name")
		done
		[[ ${#tools[@]} -eq 0 ]] && { log_warn "No matching tools found for flags: $*"; return 1; }
	else
		mapfile -t tools < <(jq -r '.tools[].name // empty' "$manifest" 2>/dev/null || true)
	fi

	[[ ${#tools[@]} -eq 0 ]] && { log_warn "No tools defined for $module"; return 0; }

	# Batch: extraer todos los datos de los tools de una sola vez
	local tools_json
	tools_json=$(jq -c '[.tools[] | {name, flag, install, version_cmd}]' "$manifest" 2>/dev/null)

	local tool
	for tool in "${tools[@]}"; do
		# Extraer info del tool
		local tool_info install_cmd ver_cmd
		tool_info=$(echo "$tools_json" | jq -c ".[] | select(.name == \"$tool\")" 2>/dev/null || echo "{}")
		install_cmd=$(echo "$tool_info" | jq -r ".install[\"$DISTRO_ID\"] // .install[\"$DISTRO_FAMILY\"] // .install[\"default\"] // \"\"" 2>/dev/null || echo "")
		ver_cmd=$(echo "$tool_info" | jq -r '.version_cmd // ""' 2>/dev/null || echo "")

		# ──────────────────────────────────────────────────
		# CASO A: Tool ya instalado en el sistema
		# ──────────────────────────────────────────────────
		if command -v "$tool" &>/dev/null; then
			local installed_ver
			installed_ver=$(eval "$ver_cmd" 2>/dev/null || echo "unknown")

			# Registrar en estado si no está ya registrado
			if ! tool_is_installed "$module" "$tool" 2>/dev/null; then
				mark_module_tool_installed "$module" "$tool" "$installed_ver"
			fi

			# En modo normal (sin --upgrade): informar y continuar
			if [[ $upgrade_mode -eq 0 ]]; then
				log_info "$tool ya instalado ($installed_ver). Usa '--upgrade' para buscar actualizaciones."
				continue
			fi

			# Modo --upgrade: buscar versión más nueva
			log_step "Buscando actualizaciones para $tool ($installed_ver)..."
			local candidate_ver=""
			local pkg_name="${tool}"

			# Intentar obtener la versión candidata del gestor de paquetes
			# Primero buscar el nombre del paquete (puede diferir del nombre del tool)
			case "$tool" in
				node)   pkg_name="nodejs" ;;
				python) pkg_name="python3" ;;
				go)     pkg_name="golang"  ;;
				neovim) pkg_name="neovim"  ;;
				# Para tools instalados por curl/script, no hay package manager
				ollama|qwen-code|deepseek-coder|aider|tabby|rust|zig|deno|bun|starship|zoxide|oh-my-zsh|powerlevel10k|helm|terraform|act|github-actions|gitlab-ci|drone|argo|dagger|tailwind|shadcn-ui|radix|framer-motion|nextui|daisyui|chatgpt|copilot)
					pkg_name="" ;;
			esac

			[[ -n "$pkg_name" ]] && candidate_ver=$(_pm_candidate_version "$pkg_name")

			# Si tenemos ambas versiones, comparar
			if [[ -n "$candidate_ver" && "$candidate_ver" != "$installed_ver" ]]; then
				local cmp
				cmp=$(_ver_compare "$candidate_ver" "$installed_ver")
				if [[ "$cmp" -eq 1 ]]; then
					log_info "Actualización disponible: $installed_ver → $candidate_ver"
					if confirm "¿Actualizar $tool?"; then
						log_step "Actualizando $tool..."
						local install_script="$CORE_HOME/modules/$module/install.sh"
						if [[ -f "$install_script" ]]; then
							bash "$install_script" "$tool" && {
								# Verificar nueva versión tras actualizar
								local new_ver
								new_ver=$(eval "$ver_cmd" 2>/dev/null || echo "unknown")
								mark_module_tool_installed "$module" "$tool" "$new_ver"
								log_success "$tool actualizado a $new_ver"
							} || log_warn "Falló la actualización de $tool"
						elif [[ -n "$install_cmd" && "$install_cmd" != "null" ]]; then
							eval "$install_cmd" && {
								local new_ver
								new_ver=$(eval "$ver_cmd" 2>/dev/null || echo "unknown")
								mark_module_tool_installed "$module" "$tool" "$new_ver"
								log_success "$tool actualizado a $new_ver"
							} || log_warn "Falló la actualización de $tool"
						else
							log_warn "No hay método de actualización para $tool"
						fi
					else
						log_info "Actualización de $tool cancelada."
					fi
				else
					log_success "$tool ya está en la última versión ($installed_ver)."
				fi
			elif [[ -n "$candidate_ver" && "$candidate_ver" == "$installed_ver" ]]; then
				log_success "$tool ya está en la última versión ($installed_ver)."
			else
				# No tenemos candidate del package manager
				log_info "$tool instalado ($installed_ver). No se pudo verificar actualización automáticamente."
			fi
			continue
		fi

		# ──────────────────────────────────────────────────
		# CASO B: Tool NO instalado → instalar
		# ──────────────────────────────────────────────────
		log_step "Instalando $module/$tool..."

		# Auto-instalar prerequisitos del sistema
		_ensure_cmds curl wget git jq

		# Detectar dependencias por el comando de instalación
		if [[ "$install_cmd" == *"pip3"* || "$install_cmd" == *"pip install"* ]]; then
			_ensure_cmds pip3
		fi
		if [[ "$install_cmd" == *"npm install"* || "$install_cmd" == *"npx"* ]]; then
			_ensure_cmds npm
		fi
		if [[ "$install_cmd" == *"go install"* ]]; then
			_ensure_cmds go
		fi
		if [[ "$install_cmd" == *"make"* ]]; then
			_ensure_cmds make
		fi
		if [[ "$install_cmd" == *"go install"* ]]; then
			_ensure_cmds go
		fi
		if [[ "$install_cmd" == *"make"* ]]; then
			_ensure_cmds make
		fi

		# Ejecutar script de instalación o comando inline
		local ok=0
		local install_script="$CORE_HOME/modules/$module/install.sh"
		if [[ -f "$install_script" ]]; then
			if bash "$install_script" "$tool"; then
				ok=1
			else
				log_error "Failed to install $tool"
				return 1
			fi
		elif [[ -n "$install_cmd" && "$install_cmd" != "null" ]]; then
			log_info "Running: $install_cmd"
			if eval "$install_cmd"; then
				ok=1
			else
				log_error "Failed to install $tool"
				return 1
			fi
		else
			log_warn "No install method for $module/$tool"
		fi

		if [[ $ok -eq 1 ]]; then
			local version=""
			[[ -n "$ver_cmd" ]] && version=$(eval "$ver_cmd" 2>/dev/null || echo "unknown")
			mark_module_tool_installed "$module" "$tool" "$version"
			log_success "Installed $tool ($version)"
		fi
	done

	module_verify "$module"
}

# ------------------------------------------------------------------
# module_uninstall
# ------------------------------------------------------------------
module_uninstall() {
	local module="${1:?Usage: module_uninstall <module> [--tool1...]}"
	shift

	module_exists "$module" || { log_error "Module $module not found"; return 1; }

	local manifest
	manifest=$(module_manifest "$module")

	local specific_tools=("$@")
	local -a tools=()

	if [[ ${#specific_tools[@]} -gt 0 ]]; then
		local flag tool_name
		for flag in "${specific_tools[@]}"; do
			flag="${flag#--}"
			tool_name=$(jq -r ".tools[] | select(.flag == \"--$flag\") | .name" "$manifest" 2>/dev/null || true)
			[[ -n "$tool_name" && "$tool_name" != "null" ]] && tools+=("$tool_name")
		done
	else
		mapfile -t tools < <(jq -r '.tools[].name // empty' "$manifest" 2>/dev/null || true)
	fi

	local tool
	for tool in "${tools[@]}"; do
		if ! tool_is_installed "$module" "$tool"; then
			log_info "$tool no instalado, saltando"
			continue
		fi

		if ! confirm "¿Eliminar $tool?"; then
			log_info "Saltando $tool"
			continue
		fi

		log_step "Desinstalando $tool..."
		local uninstall_script="$CORE_HOME/modules/$module/uninstall.sh"
		if [[ -f "$uninstall_script" ]]; then
			bash "$uninstall_script" "$tool" 2>/dev/null || log_warn "Desinstalación tuvo advertencias"
		fi
		mark_module_tool_removed "$module" "$tool"
		log_success "Desinstalado $tool"
	done
}

module_update() {
	local module="${1:?Usage: module_update <module>}"
	log_step "Actualizando $module..."
	module_install --upgrade "$module"
}

module_reinstall() {
	local module="${1:?Usage: module_reinstall <module> [--tool1...]}"
	shift
	local tools=("$@")
	module_uninstall "$module" "${tools[@]}"
	shift
	module_install "$module" "${tools[@]}"
}

module_verify() {
	local module="${1:?Usage: module_verify <module>}"
	local verify_script="$CORE_HOME/modules/$module/verify.sh"
	if [[ -f "$verify_script" ]]; then
		log_step "Verificando $module..."
		bash "$verify_script" 2>/dev/null || log_warn "Verificación reportó problemas"
	else
		log_info "No hay script de verificación para $module"
	fi
}
