"""Tests du validateur de données : il doit accepter le dépôt et refuser chaque défaut."""
import json
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

from validate_data import validate  # noqa: E402


def make_project(tmp_path: Path) -> Path:
    """Copie la palette et les schémas du dépôt dans un projet jetable."""
    shutil.copytree(REPO / "data" / "schemas", tmp_path / "data" / "schemas")
    (tmp_path / "assets_src").mkdir()
    shutil.copy(REPO / "assets_src" / "palette.json", tmp_path / "assets_src" / "palette.json")
    return tmp_path


def edit_palette(project: Path, change) -> None:
    path = project / "assets_src" / "palette.json"
    palette = json.loads(path.read_text(encoding="utf-8"))
    change(palette["colors"])
    path.write_text(json.dumps(palette), encoding="utf-8")


def test_repo_data_is_valid():
    assert validate(REPO) == []


def test_rejects_bad_hex(tmp_path):
    project = make_project(tmp_path)
    edit_palette(project, lambda colors: colors[0].update(hex="#12345g"))
    errors = validate(project)
    assert len(errors) == 1
    assert "assets_src/palette.json" in errors[0]


def test_rejects_duplicate_ids(tmp_path):
    project = make_project(tmp_path)
    edit_palette(project, lambda colors: colors[1].update(id=colors[0]["id"]))
    errors = validate(project)
    assert len(errors) == 1
    assert "assets_src/palette.json" in errors[0]


def test_rejects_duplicate_hex(tmp_path):
    project = make_project(tmp_path)
    edit_palette(project, lambda colors: colors[1].update(hex=colors[0]["hex"]))
    errors = validate(project)
    assert len(errors) == 1
    assert "assets_src/palette.json" in errors[0]


def test_rejects_more_than_32_colors(tmp_path):
    project = make_project(tmp_path)

    def fill(colors):
        colors.clear()
        colors.extend(
            {"id": f"c{i}", "hex": f"#0000{i:02x}", "group": "neutre"} for i in range(33)
        )

    edit_palette(project, fill)
    errors = validate(project)
    assert len(errors) == 1
    assert "assets_src/palette.json" in errors[0]


def test_data_file_without_schema_is_an_error(tmp_path):
    project = make_project(tmp_path)
    (project / "data" / "items").mkdir()
    (project / "data" / "items" / "x.json").write_text("{}", encoding="utf-8")
    errors = validate(project)
    assert len(errors) == 1
    assert "data/items/x.json" in errors[0]
