"""Tests du pipeline voxel : texte → maillage GLB + icône."""
import json
import struct
import sys
from pathlib import Path

import pytest

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


def test_hidden_faces_are_removed_and_same_colour_faces_merged():
    model = parse_model("palette:\n  r: rouge_propagande\nlayer:\n  rr\n", PALETTE)
    _, _, _, indices = mesh_part(model.parts["main"])
    assert len(indices) == 6 * 6  # 2 cubes de même couleur = un pavé : 6 rectangles


def test_faces_of_different_colours_are_not_merged():
    text = "palette:\n  r: rouge_propagande\n  n: noir\nlayer:\n  rn\n"
    positions, _, colors, indices = mesh_part(parse_model(text, PALETTE).parts["main"])
    assert len(indices) == 10 * 6  # 12 faces − 2 faces internes, rien à fusionner
    assert set(colors) == {(200, 32, 44, 255), (20, 21, 26, 255)}


def test_merged_faces_keep_the_outer_shape():
    text = "palette:\n  r: rouge_propagande\nlayer x3:\n  rrrr\n  rrrr\n"
    positions, _, _, indices = mesh_part(parse_model(text, PALETTE).parts["main"])
    assert len(indices) == 6 * 6
    assert max(p[0] for p in positions) - min(p[0] for p in positions) == 4 / 16
    assert max(p[1] for p in positions) - min(p[1] for p in positions) == 3 / 16
    assert max(p[2] for p in positions) - min(p[2] for p in positions) == 2 / 16


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


BOXES = """
palette:
  r: rouge_propagande
  n: noir
box: r 0 0 0 4 1 2     # un plateau
box: n 1 1 0 2 3 1     # un pied posé dessus
box: n 0 0 0 1 1 1     # un bloc recouvre ce qui était déjà là
"""


def test_boxes_fill_blocks_of_voxels():
    part = parse_model(BOXES, PALETTE).parts["main"]
    assert len(part.voxels) == 4 * 1 * 2 + 2 * 3 * 1
    assert (part.width, part.height, part.depth) == (4, 4, 2)
    assert part.voxels[(3, 0, 1)] == PALETTE["rouge_propagande"]
    assert part.voxels[(2, 3, 0)] == PALETTE["noir"]
    assert part.voxels[(0, 0, 0)] == PALETTE["noir"]


@pytest.mark.parametrize("line", ["box: x 0 0 0 1 1 1", "box: r 0 0 0 1 1", "box: r 0 0 0 1 0 1"])
def test_a_malformed_box_is_an_error(line):
    with pytest.raises(ValueError):
        parse_model("palette:\n  r: noir\n" + line + "\n", PALETTE)


def test_icon_of_an_odd_width_model_has_no_gap():
    model = parse_model("palette:\n  r: rouge_propagande\nbox: r 0 0 0 5 3 1\n", PALETTE)
    icon = build_icon(model)
    red = [(x, y) for x in range(32) for y in range(32)
           if icon.getpixel((x, y))[:3] == PALETTE["rouge_propagande"]]
    xs = sorted({x for x, _ in red})
    ys = sorted({y for _, y in red})
    assert xs == list(range(xs[0], xs[-1] + 1))
    assert len(red) == len(xs) * len(ys), "un rectangle plein"
    assert len(xs) * 3 == len(ys) * 5, "aux proportions du modèle"


SCALED = """
palette:
  r: rouge_propagande
scale: 4
pivot: 0 1 0
box: r 0 0 0 2 2 1
"""


def test_scale_makes_bigger_voxels_and_scales_the_pivot():
    model = parse_model(SCALED, PALETTE)
    part = model.parts["main"]
    assert part.scale == 4
    assert part.pivot == (0.0, 0.25, 0.0), "le pivot est compté en gros voxels"
    positions, _, _, _ = mesh_part(part)
    xs = [p[0] for p in positions]
    ys = [p[1] for p in positions]
    assert min(xs) == -0.25 and max(xs) == 0.25, "deux voxels de 1/4 m"
    assert min(ys) == -0.25 and max(ys) == 0.25


def test_icon_of_a_scaled_model_keeps_its_proportions():
    icon = build_icon(parse_model(SCALED, PALETTE))
    red = [(x, y) for x in range(32) for y in range(32)
           if icon.getpixel((x, y))[:3] == PALETTE["rouge_propagande"]]
    xs = sorted({x for x, _ in red})
    ys = sorted({y for _, y in red})
    assert len(xs) == len(ys), "un carré reste un carré"
    assert len(red) == len(xs) * len(ys)


def test_scale_must_be_a_positive_integer():
    with pytest.raises(ValueError):
        parse_model("palette:\n  r: noir\nscale: 0\nbox: r 0 0 0 1 1 1\n", PALETTE)
