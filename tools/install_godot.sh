#!/usr/bin/env bash
# Installe la version de Godot épinglée dans .godot-version (éditeur Linux x86_64)
# dans .tools/godot/<version>/godot. Avec « --templates web », installe aussi les
# modèles d'export web mono-thread ; « desktop » ceux de Windows, Linux et macOS ;
# « all » les deux. Sans effet si tout est déjà en place.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/.godot-version")"
base_url="https://github.com/godotengine/godot/releases/download/$version"
install_dir="$root/.tools/godot/$version"
templates_dir="$HOME/.local/share/godot/export_templates/${version/-/.}"
web_templates=(web_nothreads_debug.zip web_nothreads_release.zip)
desktop_templates=(
	linux_debug.x86_64 linux_release.x86_64
	windows_debug_x86_64.exe windows_release_x86_64.exe
	windows_debug_x86_64_console.exe windows_release_x86_64_console.exe
	macos.zip
)

templates=()
if [[ "${1:-}" == "--templates" ]]; then
	case "${2:-}" in
		web) templates=("${web_templates[@]}") ;;
		desktop) templates=("${desktop_templates[@]}") ;;
		all) templates=("${web_templates[@]}" "${desktop_templates[@]}") ;;
		*) echo "usage : tools/install_godot.sh [--templates web|desktop|all]" >&2; exit 2 ;;
	esac
elif [[ $# -gt 0 ]]; then
	echo "usage : tools/install_godot.sh [--templates web|desktop|all]" >&2
	exit 2
fi

if [[ "$(uname -s)-$(uname -m)" != "Linux-x86_64" ]]; then
	echo "Ce script n'installe que la version Linux x86_64." >&2
	echo "Ailleurs : installe Godot $version à la main et définis la variable GODOT." >&2
	exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Télécharge un fichier de la release et vérifie son empreinte SHA-512.
fetch() {
	local name="$1"
	curl --fail --silent --show-error --location --retry 3 -o "$work/$name" "$base_url/$name"
	if [[ ! -f "$work/SHA512-SUMS.txt" ]]; then
		curl --fail --silent --show-error --location --retry 3 \
			-o "$work/SHA512-SUMS.txt" "$base_url/SHA512-SUMS.txt"
	fi
	(cd "$work" && grep " $name\$" SHA512-SUMS.txt | sha512sum --check --quiet -)
}

if [[ ! -x "$install_dir/godot" ]]; then
	archive="Godot_v${version}_linux.x86_64.zip"
	echo "Téléchargement de Godot $version…"
	fetch "$archive"
	mkdir -p "$install_dir"
	unzip -q -o "$work/$archive" -d "$work/editor"
	mv "$work/editor/Godot_v${version}_linux.x86_64" "$install_dir/godot"
	chmod +x "$install_dir/godot"
fi

if [[ ${#templates[@]} -gt 0 ]]; then
	missing=false
	for template in "${templates[@]}"; do
		[[ -f "$templates_dir/$template" ]] || missing=true
	done
	if $missing; then
		archive="Godot_v${version}_export_templates.tpz"
		echo "Téléchargement des modèles d'export (1,3 Go, seuls ceux demandés sont gardés)…"
		fetch "$archive"
		mkdir -p "$templates_dir"
		unzip -q -o -j "$work/$archive" "templates/version.txt" \
			"${templates[@]/#/templates/}" -d "$templates_dir"
	fi
fi

"$install_dir/godot" --version
