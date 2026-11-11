#!/usr/bin/env bash
# Vérifications du projet : les mêmes commandes en local et en CI.
# usage : tools/check.sh <lint|data|import|test|all>
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
if [[ -d .venv/bin ]]; then
	PATH="$root/.venv/bin:$PATH"
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
	mapfile -t dirs < <(gdscript_dirs)
	gdlint "${dirs[@]}"
	gdformat --check "${dirs[@]}"
}

# Schémas JSON des données, puis tests du validateur lui-même.
check_data() {
	python tools/validate_data.py
	python -m pytest -q tools/tests
}

# Godot rend souvent le code 0 même quand un script ne compile pas : on lit sa sortie.
fail_on_script_errors() {
	if grep -qE "SCRIPT ERROR|Parse Error|Échec du chargement" "$1"; then
		echo "Échec : erreur de script (voir ci-dessus)." >&2
		exit 1
	fi
}

# L'import ne compile pas le GDScript : on charge ensuite chaque script et chaque scène.
import_project() {
	local log
	log="$(mktemp)"
	tools/godot.sh --headless --path . --import 2>&1 | tee "$log"
	tools/godot.sh --headless --path . -s tools/check_scripts.gd 2>&1 | tee -a "$log"
	fail_on_script_errors "$log"
}

# GUT ignore un fichier de test qui ne compile pas et rend 0 s'il s'arrête avant
# de commencer : on exige son bilan et l'absence d'erreur de script.
run_tests() {
	local log
	log="$(mktemp)"
	tools/godot.sh --headless --path . -s addons/gut/gut_cmdln.gd -gexit "$@" 2>&1 | tee "$log"
	fail_on_script_errors "$log"
	if ! grep -q "All tests passed" "$log"; then
		echo "Échec : GUT n'a pas annoncé « All tests passed »." >&2
		exit 1
	fi
}

case "${1:-all}" in
	lint) lint ;;
	data) check_data ;;
	import) import_project ;;
	test) run_tests ;;
	all)
		lint
		check_data
		import_project
		run_tests
		;;
	*)
		echo "usage : tools/check.sh <lint|data|import|test|all>" >&2
		exit 2
		;;
esac
