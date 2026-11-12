"""Tests du pipeline voxel : texte → maillage GLB + icône."""
import json
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

from build_voxels import build_glb, build_icon, mesh_part, parse_model  # noqa: E402

PALETTE = {"rouge_propagande": (200, 32, 44), "noir": (20, 21, 26), "blanc": (238, 239, 240)}

ONE_VOXEL = """
palette:
  r: rouge_propagande
layer:
  r
"""

TWO_PARTS = """
# deux cubes : un corps et une tête articulée
palette:
  r: rouge_propagande
  n: noir
part: body
layer x2:
  rr
  rr
part: head
pivot: 0 2 0
offset: 0 2 0
layer:
  n.
  .n
"""


def test_single_voxel_has_six_faces():
    model = parse_model(ONE_VOXEL, PALETTE)
    assert list(model.parts) == ["main"]
    positions, normals, colors, indices = mesh_part(model.parts["main"])
    assert len(indices) == 36  # 6 faces × 2 triangles × 3 sommets
    assert len(positions) == 24
    assert set(colors) == {(200, 32, 44, 255)}


def test_hidden_faces_between_neighbours_are_removed():
    model = parse_model("palette:\n  r: rouge_propagande\nlayer:\n  rr\n", PALETTE)
    _, _, _, indices = mesh_part(model.parts["main"])
    assert len(indices) == 10 * 6  # 2 cubes collés : 12 faces − 2 faces internes


def test_voxels_are_one_sixteenth_of_a_metre_and_centred():
    model = parse_model(ONE_VOXEL, PALETTE)
    positions, _, _, _ = mesh_part(model.parts["main"])
    xs = [p[0] for p in positions]
    ys = [p[1] for p in positions]
    assert min(xs) == -0.03125 and max(xs) == 0.03125
    assert min(ys) == 0.0 and max(ys) == 0.0625


def test_repeated_layers_and_parts_with_pivots():
    model = parse_model(TWO_PARTS, PALETTE)
    assert list(model.parts) == ["body", "head"]
    assert len(model.parts["body"].voxels) == 8
    assert len(model.parts["head"].voxels) == 2
    assert model.parts["head"].pivot == (0.0, 0.125, 0.0)
    # Les sommets d'une partie sont exprimés par rapport à son pivot.
    positions, _, _, _ = mesh_part(model.parts["head"])
    assert min(p[1] for p in positions) == 0.0


def test_unknown_palette_colour_is_an_error():
    try:
        parse_model("palette:\n  r: fuchsia\nlayer:\n  r\n", PALETTE)
    except ValueError as error:
        assert "fuchsia" in str(error)
    else:
        raise AssertionError("une couleur inconnue doit être refusée")


def test_glb_is_a_valid_container_with_one_node_per_part():
    glb = build_glb(parse_model(TWO_PARTS, PALETTE))
    magic, version, length = struct.unpack_from("<4sII", glb, 0)
    assert magic == b"glTF" and version == 2 and length == len(glb)
    json_length, json_type = struct.unpack_from("<I4s", glb, 12)
    assert json_type == b"JSON"
    document = json.loads(glb[20 : 20 + json_length])
    assert [node["name"] for node in document["nodes"][1:]] == ["body", "head"]
    assert document["nodes"][2]["translation"] == [0.0, 0.125, 0.0]
    assert len(document["meshes"]) == 2
    primitive = document["meshes"][0]["primitives"][0]
    assert set(primitive["attributes"]) == {"POSITION", "NORMAL", "COLOR_0"}


def test_icon_is_32_pixels_with_palette_colours_only():
    icon = build_icon(parse_model(TWO_PARTS, PALETTE))
    assert icon.size == (32, 32) and icon.mode == "RGBA"
    pixels = [icon.getpixel((x, y)) for y in range(32) for x in range(32)]
    opaque = {pixel[:3] for pixel in pixels if pixel[3] == 255}
    assert opaque and opaque <= set(PALETTE.values())
    assert any(pixel[3] == 0 for pixel in pixels)
