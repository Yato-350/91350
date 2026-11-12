"""Tests du générateur de personnages en voxels."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

from build_voxels import VOXEL, load_palette, mesh_part  # noqa: E402
from voxel_characters import PART_NAMES, build_character  # noqa: E402

PALETTE = load_palette()
AKAN = {
    "skin": "peau_1", "hair": "noir", "hair_style": "court", "top": "jaune_linge",
    "top_style": "hoodie", "bottom": "bleu_acier", "shoes": "blanc",
}


def top_of(model) -> float:
    return max(
        (y + part.offset[1] + 1) * VOXEL for part in model.parts.values() for (_, y, _) in part.voxels
    )


def test_adult_is_one_metre_seventy_five_with_six_parts():
    model = build_character(AKAN, PALETTE)
    assert list(model.parts) == PART_NAMES
    assert top_of(model) == 1.75


def test_parts_pivot_at_hips_shoulders_and_neck():
    model = build_character(AKAN, PALETTE)
    assert model.parts["LegLeft"].pivot == (-2 * VOXEL, 12 * VOXEL, 0.0)
    assert model.parts["ArmRight"].pivot == (5 * VOXEL, 22 * VOXEL, 0.0)
    assert model.parts["Head"].pivot == (0.0, 22 * VOXEL, 0.0)
    # Une jambe pend sous son pivot : aucun sommet au-dessus de la hanche.
    positions, _, _, _ = mesh_part(model.parts["LegLeft"])
    assert max(p[1] for p in positions) == 0.0


def test_colours_come_from_the_appearance():
    model = build_character(AKAN, PALETTE)
    assert PALETTE["jaune_linge"] in set(model.parts["Torso"].voxels.values())
    assert PALETTE["bleu_acier"] in set(model.parts["LegLeft"].voxels.values())
    assert PALETTE["blanc"] in set(model.parts["LegLeft"].voxels.values())
    head = set(model.parts["Head"].voxels.values())
    assert {PALETTE["peau_1"], PALETTE["noir"]} <= head


def test_face_has_two_eyes_on_the_front():
    model = build_character(AKAN, PALETTE)
    head = model.parts["Head"]
    front = min(z for (_, _, z) in head.voxels)
    eyes = [key for key, color in head.voxels.items() if key[2] == front and color == PALETTE["noir"]
            and key[1] in (2, 3)]
    assert len(eyes) == 2


def test_child_is_smaller_and_strong_build_is_wider():
    child = build_character({**AKAN, "build": "enfant"}, PALETTE)
    strong = build_character({**AKAN, "build": "fort"}, PALETTE)
    adult = build_character(AKAN, PALETTE)
    assert top_of(child) < 1.4
    assert strong.parts["Torso"].width > adult.parts["Torso"].width


def test_parts_sit_on_the_voxel_grid_for_every_build():
    for build in ("adulte", "enfant", "fort"):
        model = build_character({**AKAN, "build": build}, PALETTE)
        legs = model.parts["LegLeft"], model.parts["LegRight"]
        left = [p[0] + legs[0].pivot[0] for p in mesh_part(legs[0])[0]]
        right = [p[0] + legs[1].pivot[0] for p in mesh_part(legs[1])[0]]
        assert max(left) == 0.0 and min(right) == 0.0, build
        for part in model.parts.values():
            for position in mesh_part(part)[0]:
                x = (position[0] + part.pivot[0]) / VOXEL
                assert x == round(x), (build, part.name)


def test_every_style_builds_and_is_deterministic():
    from voxel_characters import ACCESSORIES, HAIR_STYLES, TOP_STYLES

    for hair_style in HAIR_STYLES:
        for top_style in TOP_STYLES:
            spec = {**AKAN, "hair_style": hair_style, "top_style": top_style}
            first = build_character(spec, PALETTE)
            second = build_character(spec, PALETTE)
            assert first.parts["Head"].voxels == second.parts["Head"].voxels
            assert all(part.voxels for part in first.parts.values())
    for accessory in ACCESSORIES:
        model = build_character({**AKAN, "accessory": accessory, "accessory_color": "beton_2"}, PALETTE)
        assert all(part.voxels for part in model.parts.values())


def test_unknown_colour_or_style_is_an_error():
    for bad in ({"skin": "fuchsia"}, {"hair_style": "licorne"}, {"top_style": "armure"}):
        try:
            build_character({**AKAN, **bad}, PALETTE)
        except ValueError:
            continue
        raise AssertionError(f"{bad} aurait dû être refusé")
