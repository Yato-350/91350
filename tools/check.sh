#!/usr/bin/env bash
# Vérifications du projet : les mêmes commandes en local et en CI.
# usage : tools/check.sh <lint|data|import|test|render|screenshot <scène>|web|all>
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# Environnement Python du projet, s'il existe (.venv/Scripts sous Windows).
for venv_bin in .venv/bin .venv/Scripts; do
	if [[ -d "$venv_bin" ]]; then
		PATH="$root/$venv_bin:$PATH"
	fi
done
python="python3"
if ! command -v python3 > /dev/null; then
	python="python"
fi

# Dossiers de GDScript qui existent déjà (les addons ne sont pas vérifiés).
gdscript_dirs() {
	local dir
	for dir in scripts tests tools; do
		if [[ -d "$dir" ]]; then
			echo "$dir"
		fi
	done
}

lint() {
	local dirs
	# shellcheck disable=SC2046 # les noms de dossiers n'ont pas d'espace
	dirs="$(gdscript_dirs)"
	gdlint $dirs
	gdformat --check $dirs
}

# build/ contient des captures et le build web : Godot ne doit pas les importer.
prepare_build_dir() {
	mkdir -p build
	touch build/.gdignore
}

# Schémas JSON des données, puis tests du validateur lui-même.
check_data() {
	"$python" tools/validate_data.py
	"$python" -m pytest -q tools/tests
}

# Godot rend souvent le code 0 même quand un script ne compile pas : on lit sa sortie.
fail_on_script_errors() {
	if grep -qE "SCRIPT ERROR|Parse Error|Failed loading resource|Échec du chargement" "$1"; then
		echo "Échec : erreur de script (voir ci-dessus)." >&2
		exit 1
	fi
}

# L'import ne compile pas le GDScript : on charge ensuite chaque script, scène et
# ressource. Le journal de l'import lui-même n'est pas contrôlé : sur un clone neuf,
# Godot y signale des fichiers « introuvables » qu'il est justement en train de créer.
import_project() {
	local log
	log="$(mktemp)"
	tools/godot.sh --headless --path . --import
	tools/godot.sh --headless --path . -s tools/check_scripts.gd 2>&1 | tee "$log"
	fail_on_script_errors "$log"
}

# GUT ignore un fichier de test qui ne compile pas et rend 0 s'il s'arrête avant
# de commencer : on exige son bilan, aucun test en échec et aucune erreur de script.
check_gut_log() {
	fail_on_script_errors "$1"
	if ! grep -q "Passing Tests" "$1" || grep -q "Failing Tests" "$1"; then
		echo "Échec : des tests GUT ont échoué ou n'ont pas tourné." >&2
		exit 1
	fi
}

run_tests() {
	local log
	log="$(mktemp)"
	tools/godot.sh --headless --path . -s addons/gut/gut_cmdln.gd -gexit 2>&1 | tee "$log"
	check_gut_log "$log"
}

# Lance une commande dans un écran virtuel quand il n'y a pas d'affichage (CI, cloud).
with_display() {
	if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run > /dev/null; then
		xvfb-run -a -s "-screen 0 1280x720x24" "$@"
	else
		"$@"
	fi
}

# Tests qui exigent un vrai rendu : « --headless » n'affiche rien.
render() {
	local log
	log="$(mktemp)"
	with_display tools/godot.sh --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 -s addons/gut/gut_cmdln.gd -gexit -gdir=res://tests/render \
		2>&1 | tee "$log"
	check_gut_log "$log"
	screenshot res://scenes/zones/test_zone.tscn
}

# Export web mono-thread (aucun en-tête HTTP spécial requis : compatible GitHub Pages).
export_web() {
	local log file
	log="$(mktemp)"
	prepare_build_dir
	rm -rf build/web
	mkdir -p build/web
	tools/godot.sh --headless --path . --export-release "Web" build/web/index.html 2>&1 | tee "$log"
	fail_on_script_errors "$log"
	for file in index.html index.js index.wasm index.pck; do
		if [[ ! -s "build/web/$file" ]]; then
			echo "Échec : build/web/$file manquant." >&2
			exit 1
		fi
	done
}

# Capture une scène dans build/screenshots/ (voir scripts/main/main.gd).
screenshot() {
	local scene="$1"
	local output
	output="build/screenshots/$(basename "$scene" .tscn).png"
	prepare_build_dir
	rm -f "$output"
	with_display tools/godot.sh --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 -- --screenshot "$scene"
	if [[ ! -f "$output" || "$(wc -c < "$output")" -lt 2048 ]]; then
		echo "Échec : capture absente ou vide ($output)." >&2
		exit 1
	fi
}

case "${1:-all}" in
	lint) lint ;;
	data) check_data ;;
	import) import_project ;;
	test) run_tests ;;
	render) render ;;
	web) export_web ;;
	screenshot) screenshot "${2:?usage : tools/check.sh screenshot <scène>}" ;;
	all)
		lint
		check_data
		import_project
		run_tests
		render
		export_web
		;;
	*)
		echo "usage : tools/check.sh <lint|data|import|test|render|screenshot <scène>|web|all>" >&2
		exit 2
		;;
esac
