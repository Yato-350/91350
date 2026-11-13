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


def _front(part):
    front = min(z for (_, _, z) in part.voxels)
    return {(x, y): color for (x, y, z), color in part.voxels.items() if z == front}


def test_face_has_eyebrows_and_a_mouth():
    head = _front(build_character(AKAN, PALETTE).parts["Head"])
    assert head[(1, 4)] == PALETTE["noir"] and head[(4, 4)] == PALETTE["noir"], "sourcils"
    assert head[(2, 1)] == PALETTE["brun_2"] and head[(3, 1)] == PALETTE["brun_2"], "bouche"
    assert head[(2, 2)] == PALETTE["peau_1"], "les joues restent de la couleur de la peau"


def test_facial_hair_covers_the_lower_face():
    beard = build_character({**AKAN, "facial_hair": "barbe"}, PALETTE).parts["Head"]
    front = _front(beard)
    assert front[(0, 0)] == PALETTE["noir"] and front[(5, 1)] == PALETTE["noir"]
    assert front[(2, 1)] == PALETTE["brun_2"], "la bouche reste visible dans la barbe"
    moustache = _front(build_character({**AKAN, "facial_hair": "moustache"}, PALETTE).parts["Head"])
    assert [moustache[(x, 2)] for x in range(1, 5)] == [PALETTE["noir"]] * 4
    assert moustache[(0, 0)] == PALETTE["peau_1"]
    goatee = _front(build_character({**AKAN, "facial_hair": "bouc"}, PALETTE).parts["Head"])
    assert goatee[(2, 0)] == PALETTE["noir"] and goatee[(0, 0)] == PALETTE["peau_1"]


def test_jogging_has_side_stripes_and_jeans_a_belt():
    spec = {**AKAN, "bottom_style": "jogging", "detail": "blanc"}
    model = build_character(spec, PALETTE)
    left = model.parts["LegLeft"]
    outer = {left.voxels[(0, y, 1)] for y in range(3, 11)}
    assert outer == {PALETTE["blanc"]}, "bande sur le côté extérieur"
    jean = build_character({**AKAN, "bottom_style": "jean"}, PALETTE)
    belt = {color for (x, y, z), color in jean.parts["Torso"].voxels.items() if y == 0}
    assert PALETTE["brun_1"] in belt


def test_a_skirt_hangs_from_the_torso_over_bare_legs():
    model = build_character({**AKAN, "bottom_style": "jupe", "bottom": "violet_tag"}, PALETTE)
    skirt = [key for key, color in model.parts["Torso"].voxels.items()
             if key[1] < 0 and color == PALETTE["violet_tag"]]
    assert skirt, "la jupe fait partie du buste : elle ne suit pas les jambes"
    leg = model.parts["LegLeft"]
    assert leg.voxels[(1, 5, 1)] == PALETTE["peau_1"], "jambes nues sous la jupe"


def test_shorts_show_the_knees_and_sneakers_have_a_sole():
    model = build_character({**AKAN, "bottom_style": "short", "shoes": "rouge_sombre"}, PALETTE)
    leg = model.parts["LegLeft"]
    assert leg.voxels[(1, 11, 1)] == PALETTE["bleu_acier"]
    assert leg.voxels[(1, 4, 1)] == PALETTE["peau_1"]
    assert leg.voxels[(1, 0, 1)] == PALETTE["blanc"], "semelle"
    assert leg.voxels[(1, 1, 1)] == PALETTE["rouge_sombre"]


def test_a_hoodie_has_its_hood_on_the_back():
    torso = build_character(AKAN, PALETTE).parts["Torso"]
    back = max(z for (_, _, z) in torso.voxels)
    assert back == torso.depth, "la capuche dépasse dans le dos"


def test_every_bottom_and_facial_hair_style_builds():
    from voxel_characters import BOTTOM_STYLES, FACIAL_HAIR

    for bottom_style in BOTTOM_STYLES:
        for facial_hair in FACIAL_HAIR:
            for build in ("adulte", "enfant", "fort"):
                spec = {**AKAN, "bottom_style": bottom_style, "facial_hair": facial_hair, "build": build}
                model = build_character(spec, PALETTE)
                assert all(part.voxels for part in model.parts.values())
