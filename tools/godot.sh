#!/usr/bin/env bash
# Lance la version de Godot épinglée dans .godot-version.
# Ordre de recherche : $GODOT, .tools/godot/<version>/godot, puis « godot » du PATH.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/.godot-version")"

godot=""
for candidate in "${GODOT:-}" "$root/.tools/godot/$version/godot" "$(command -v godot || true)"; do
	if [[ -n "$candidate" && -x "$candidate" ]]; then
		godot="$candidate"
		break
	fi
done

if [[ -z "$godot" ]]; then
	echo "Godot $version introuvable." >&2
	echo "Linux : tools/install_godot.sh — ailleurs : définis GODOT vers l'exécutable." >&2
	exit 1
fi

expected="${version/-/.}"
actual="$("$godot" --version 2>/dev/null | head -n 1 || true)"
if [[ "$actual" != "$expected"* ]]; then
	echo "Godot $expected attendu, $actual trouvé ($godot)." >&2
	exit 1
fi

exec "$godot" "$@"
