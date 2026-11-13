"""Tests du générateur de la table des commandes."""
import json
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

from build_input_map import PROJECT, SOURCE, build_section, key_code, replace_section  # noqa: E402


def test_key_codes_match_godot():
    assert key_code("A") == 65
    assert key_code("1") == 49
    assert key_code("Space") == 32
    assert key_code("Left") == 4194319
    assert key_code("Shift") == 4194325
    assert key_code("F5") == 4194336
    assert key_code("F11") == 4194342
    assert key_code("Escape") == 4194305


def test_unknown_key_is_refused():
    with pytest.raises(ValueError):
        key_code("Licorne")


def test_section_lists_every_kind_of_event():
    source = {"deadzone": 0.2, "actions": {
        "attack": {"keys": ["Space"], "mouse": [1], "buttons": [2], "axes": [[4, 1]]}}}
    section = build_section(source)
    assert section.startswith("[input]\n\nattack={\n\"deadzone\": 0.2,\n")
    assert '"physical_keycode":32' in section
    assert 'InputEventMouseButton' in section and '"button_index":1' in section
    assert '"axis":4,"axis_value":1.0' in section
    assert section.count('"device":-1') == 4


def test_replace_section_keeps_the_other_sections():
    project = "[application]\n\nname=\"x\"\n\n[input]\n\nold={\n}\n\n[rendering]\n\nr=1\n"
    updated = replace_section(project, "[input]\n\nnew={\n}\n")
    assert updated == "[application]\n\nname=\"x\"\n\n[input]\n\nnew={\n}\n\n[rendering]\n\nr=1\n"


def test_project_is_in_sync_with_the_source():
    source = json.loads((REPO / SOURCE).read_text(encoding="utf-8"))
    project = (REPO / PROJECT).read_text(encoding="utf-8")
    assert replace_section(project, build_section(source)) == project
