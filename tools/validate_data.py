#!/usr/bin/env python3
"""Valide les fichiers de données du jeu contre leurs schémas JSON.

- assets_src/palette.json            → data/schemas/palette.schema.json
- data/<type>/**/*.json              → data/schemas/<type>.schema.json

En plus des schémas : dans un tableau d'objets portant un « id », les id sont
uniques ; dans la palette, les couleurs le sont aussi.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

PALETTE = Path("assets_src/palette.json")
SCHEMAS = Path("data/schemas")


def validate(root: Path) -> list[str]:
    """Rend la liste des erreurs trouvées sous `root` (vide si tout est valide)."""
    targets = [(root / PALETTE, root / SCHEMAS / "palette.schema.json")]
    data_dir = root / "data"
    for kind_dir in sorted(data_dir.iterdir()) if data_dir.is_dir() else []:
        if kind_dir.is_dir() and kind_dir.name != SCHEMAS.name:
            schema = root / SCHEMAS / f"{kind_dir.name}.schema.json"
            targets += [(path, schema) for path in sorted(kind_dir.rglob("*.json"))]

    errors: list[str] = []
    for path, schema_path in targets:
        errors += [f"{path.relative_to(root).as_posix()} : {message}"
                   for message in _check_file(path, schema_path)]
    return errors


def _check_file(path: Path, schema_path: Path) -> list[str]:
    if not path.is_file():
        return ["fichier introuvable"]
    if not schema_path.is_file():
        return [f"pas de schéma ({schema_path.name} manquant)"]
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"JSON illisible ({error})"]

    messages = [
        f"{'/'.join(str(part) for part in error.absolute_path) or '(racine)'} : {error.message}"
        for error in sorted(Draft202012Validator(schema).iter_errors(document), key=str)
    ]
    messages += _duplicate_ids(document)
    if path.name == PALETTE.name and isinstance(document, dict):
        messages += _duplicates(document.get("colors", []), "hex")
    return messages


def _duplicate_ids(node) -> list[str]:
    """Cherche récursivement les tableaux d'objets dont un « id » revient deux fois."""
    messages: list[str] = []
    if isinstance(node, list):
        messages += _duplicates(node, "id")
        for item in node:
            messages += _duplicate_ids(item)
    elif isinstance(node, dict):
        for value in node.values():
            messages += _duplicate_ids(value)
    return messages


def _duplicates(items, key: str) -> list[str]:
    seen: set = set()
    messages: list[str] = []
    for item in items:
        if not isinstance(item, dict) or key not in item:
            continue
        value = item[key]
        if value in seen:
            messages.append(f"« {key} » en double : {value}")
        seen.add(value)
    return messages


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors = validate(root)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        print(f"{len(errors)} erreur(s) dans les données.", file=sys.stderr)
        return 1
    print("Données valides.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
