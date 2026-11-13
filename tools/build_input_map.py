#!/usr/bin/env python3
"""Écrit la section [input] de project.godot à partir d'assets_src/input_map.json.

La source liste, pour chaque action : des touches (« keys », par leur position physique
sur un clavier QWERTY), des boutons de souris (« mouse »), des boutons de manette
(« buttons ») et des axes de manette (« axes » : [axe, sens]).

    python3 tools/build_input_map.py          réécrit project.godot
    python3 tools/build_input_map.py --check  échoue si project.godot n'est pas à jour
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

SOURCE = Path("assets_src/input_map.json")
PROJECT = Path("project.godot")
SECTION = "[input]"

# Codes de touches de Godot : les touches spéciales commencent à KEY_SPECIAL.
KEY_SPECIAL = 4194304
SPECIAL_KEYS = {
    "Escape": 1, "Tab": 2, "Enter": 5, "Left": 15, "Up": 16, "Right": 17, "Down": 18,
    "Shift": 21, "Ctrl": 22, "Alt": 24,
}
FIRST_FUNCTION_KEY = 27  # F1 = KEY_SPECIAL + 28

KEY_EVENT = (
    'Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,'
    '"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,'
    '"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":%d,"key_label":0,'
    '"unicode":0,"location":0,"echo":false,"script":null)'
)
MOUSE_EVENT = (
    'Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"",'
    '"device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,'
    '"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),'
    '"global_position":Vector2(0, 0),"factor":1.0,"button_index":%d,"canceled":false,'
    '"pressed":false,"double_click":false,"script":null)'
)
BUTTON_EVENT = (
    'Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"",'
    '"device":-1,"button_index":%d,"pressure":0.0,"pressed":false,"script":null)'
)
AXIS_EVENT = (
    'Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"",'
    '"device":-1,"axis":%d,"axis_value":%.1f,"script":null)'
)


def key_code(name: str) -> int:
    """Code Godot d'une touche nommée : « A », « 1 », « Space », « F5 », « Shift »…"""
    if name in SPECIAL_KEYS:
        return KEY_SPECIAL + SPECIAL_KEYS[name]
    if name == "Space":
        return ord(" ")
    if len(name) > 1 and name[0] == "F" and name[1:].isdigit():
        return KEY_SPECIAL + FIRST_FUNCTION_KEY + int(name[1:])
    if len(name) == 1 and (name.isdigit() or ("A" <= name <= "Z")):
        return ord(name)
    raise ValueError(f"touche inconnue : {name}")


def build_section(source: dict) -> str:
    lines = [SECTION, ""]
    for action, bindings in source["actions"].items():
        events = [KEY_EVENT % key_code(name) for name in bindings.get("keys", [])]
        events += [MOUSE_EVENT % index for index in bindings.get("mouse", [])]
        events += [AXIS_EVENT % (axis, value) for axis, value in bindings.get("axes", [])]
        events += [BUTTON_EVENT % index for index in bindings.get("buttons", [])]
        lines += [f"{action}={{", f'"deadzone": {source["deadzone"]},',
                  '"events": [' + "\n, ".join(events), "]", "}"]
    return "\n".join(lines) + "\n"


def replace_section(project_text: str, section_text: str) -> str:
    """Remplace la section [input] ; les autres sections ne bougent pas."""
    start = project_text.index(SECTION)
    end = project_text.find("\n[", start + len(SECTION))
    rest = project_text[end + 1:] if end != -1 else ""
    return project_text[:start] + section_text + ("\n" + rest if rest else "")


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    source = json.loads((root / SOURCE).read_text(encoding="utf-8"))
    current = (root / PROJECT).read_text(encoding="utf-8")
    updated = replace_section(current, build_section(source))
    if "--check" in sys.argv[1:]:
        if updated != current:
            print(f"{PROJECT} n'est pas à jour : lancer tools/build_input_map.py", file=sys.stderr)
            return 1
        return 0
    (root / PROJECT).write_text(updated, encoding="utf-8")
    print(f"{PROJECT} : {len(source['actions'])} actions.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
