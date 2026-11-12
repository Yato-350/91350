"""Générateur de personnages en voxels à partir d'une fiche d'apparence.

Un personnage est fait de six parties rigides (tête, torse, bras, jambes) que le jeu
anime de façon procédurale. La fiche choisit les couleurs dans la palette du jeu et
quelques styles (coiffure, haut, accessoire, carrure) :

    {"skin": "peau_1", "hair": "noir", "hair_style": "court", "top": "jaune_linge",
     "top_style": "hoodie", "bottom": "bleu_acier", "shoes": "blanc",
     "accessory": "sac", "accessory_color": "beton_2", "detail": "blanc", "build": "adulte"}
"""
from __future__ import annotations

from build_voxels import VOXEL, Model, Part

PART_NAMES = ["LegLeft", "LegRight", "Torso", "ArmLeft", "ArmRight", "Head"]
HAIR_STYLES = [
    "chauve", "rase", "court", "afro", "long", "chignon", "tresses",
    "casquette", "capuche", "bonnet", "casque",
]
TOP_STYLES = ["tshirt", "hoodie", "veste", "uniforme", "blouse", "tablier"]
ACCESSORIES = ["", "sac", "gilet", "lunettes", "brassard", "ecouteurs", "matraque"]
EYE_COLOR = "noir"
HEAD = 6  # la tête est un cube de 6 voxels, quelle que soit la carrure

# Carrure → (largeur, hauteur, profondeur) des jambes, du torse et des bras, en voxels.
BUILDS = {
    "adulte": {"leg": (4, 12, 3), "torso": (8, 10, 4), "arm": (2, 10, 3)},
    "enfant": {"leg": (3, 8, 3), "torso": (6, 7, 3), "arm": (2, 7, 2)},
    "fort": {"leg": (5, 12, 4), "torso": (10, 11, 5), "arm": (3, 11, 3)},
}


def build_character(spec: dict, palette: dict[str, tuple[int, int, int]]) -> Model:
    def color(key: str, default: str) -> tuple[int, int, int]:
        color_id = spec.get(key, default)
        if color_id not in palette:
            raise ValueError(f"couleur inconnue pour « {key} » : {color_id}")
        return palette[color_id]

    hair_style = spec.get("hair_style", "court")
    top_style = spec.get("top_style", "tshirt")
    accessory = spec.get("accessory", "")
    build = spec.get("build", "adulte")
    for value, allowed, label in (
        (hair_style, HAIR_STYLES, "coiffure"), (top_style, TOP_STYLES, "haut"),
        (accessory, ACCESSORIES, "accessoire"), (build, list(BUILDS), "carrure"),
    ):
        if value not in allowed:
            raise ValueError(f"{label} inconnu(e) : {value}")

    skin, hair = color("skin", "peau_2"), color("hair", "noir")
    top, bottom, shoes = color("top", "beton_4"), color("bottom", "bleu_acier"), color("shoes", "noir")
    extra, detail = color("accessory_color", "beton_2"), color("detail", "blanc")
    eye = palette[EYE_COLOR]
    (leg_w, leg_h, leg_d), (torso_w, torso_h, torso_d), (arm_w, arm_h, arm_d) = (
        BUILDS[build]["leg"], BUILDS[build]["torso"], BUILDS[build]["arm"],
    )
    shoulder = leg_h + torso_h
    model = Model(outline=palette.get("noir", (0, 0, 0)))

    def part(name: str, size: tuple[int, int, int], offset: tuple[float, float, float],
             pivot: tuple[float, float, float]) -> Part:
        new = Part(name, width=size[0], height=size[1], depth=size[2], offset=offset,
                   pivot=tuple(value * VOXEL for value in pivot))
        model.parts[name] = new
        return new

    def fill(target: Part, xs: range, ys: range, zs: range, rgb: tuple[int, int, int]) -> None:
        for x in xs:
            for y in ys:
                for z in zs:
                    target.voxels[(x, y, z)] = rgb

    # Jambes : pantalon, chaussures sur les deux couches du bas.
    for name, side in (("LegLeft", -1), ("LegRight", 1)):
        center = side * leg_w / 2
        leg = part(name, (leg_w, leg_h, leg_d), (center, 0, 0), (center, leg_h, 0))
        fill(leg, range(leg_w), range(leg_h), range(leg_d), bottom)
        fill(leg, range(leg_w), range(2), range(leg_d), shoes)
        if top_style == "blouse":
            fill(leg, range(leg_w), range(leg_h - 4, leg_h), range(leg_d), top)
        if accessory == "matraque" and side == 1:
            fill(leg, range(leg_w, leg_w + 1), range(leg_h - 7, leg_h - 1), range(1, 2), eye)

    torso = part("Torso", (torso_w, torso_h, torso_d), (0, leg_h, 0), (0, leg_h, 0))
    fill(torso, range(torso_w), range(torso_h), range(torso_d), top)
    middle = range(torso_w // 2 - 1, torso_w // 2 + 1)
    if top_style == "veste":
        fill(torso, middle, range(torso_h), range(1), detail)
    elif top_style == "uniforme":
        fill(torso, range(torso_w), range(1), range(torso_d), eye)
        fill(torso, range(1, 2), range(torso_h - 3, torso_h - 2), range(1), detail)
    elif top_style == "tablier":
        fill(torso, range(1, torso_w - 1), range(torso_h - 2), range(1), detail)
    elif top_style == "hoodie":
        fill(torso, middle, range(2, 4), range(1), detail)
    if accessory == "sac":
        fill(torso, range(1, torso_w - 1), range(2, torso_h - 1), range(torso_d, torso_d + 2), extra)
    elif accessory == "gilet":
        fill(torso, range(torso_w), range(2, torso_h), range(1), extra)
        fill(torso, range(torso_w), range(2, torso_h), range(torso_d - 1, torso_d), extra)

    for name, side in (("ArmLeft", -1), ("ArmRight", 1)):
        center = side * (torso_w / 2 + arm_w / 2)
        arm = part(name, (arm_w, arm_h, arm_d), (center, leg_h, 0), (center, shoulder, 0))
        fill(arm, range(arm_w), range(arm_h), range(arm_d), top)
        fill(arm, range(arm_w), range(2), range(arm_d), skin)
        if top_style == "tshirt":
            fill(arm, range(arm_w), range(arm_h - 4), range(arm_d), skin)
        if accessory == "brassard" or (top_style == "uniforme" and side == -1):
            fill(arm, range(arm_w), range(arm_h - 4, arm_h - 2), range(arm_d), palette["rouge_propagande"])

    head = part("Head", (HEAD, HEAD, HEAD), (0, shoulder, 0), (0, shoulder, 0))
    whole = range(HEAD)
    fill(head, whole, whole, whole, skin)
    fill(head, range(1, 2), range(3, 4), range(1), eye)
    fill(head, range(4, 5), range(3, 4), range(1), eye)
    if accessory == "lunettes":
        fill(head, whole, range(3, 4), range(1), eye)
    elif accessory == "ecouteurs":
        fill(head, range(-1, 0), range(2, 5), range(2, 4), extra)
        fill(head, range(HEAD, HEAD + 1), range(2, 5), range(2, 4), extra)
        fill(head, range(-1, HEAD + 1), range(HEAD, HEAD + 1), range(2, 4), extra)
    _add_hair(head, hair_style, hair, top, extra, eye, fill)
    return model


def _add_hair(head: Part, style: str, hair: tuple, top: tuple, extra: tuple, dark: tuple, fill) -> None:
    whole = range(HEAD)
    crown, back, upper = range(HEAD - 1, HEAD), range(HEAD - 2, HEAD), range(3, HEAD)
    if style == "chauve":
        return
    if style == "rase":
        fill(head, whole, crown, whole, hair)
        return
    if style in ("casquette", "bonnet", "casque"):
        layers = {"casquette": 1, "bonnet": 2, "casque": 3}[style]
        fill(head, whole, range(HEAD - layers, HEAD), whole, extra)
        if style == "casquette":
            fill(head, whole, range(HEAD - 1, HEAD), range(-2, 0), extra)
        if style == "casque":
            fill(head, whole, range(HEAD, HEAD + 1), whole, extra)
            fill(head, whole, range(3, 4), range(1), dark)
        return
    if style == "capuche":
        fill(head, range(-1, HEAD + 1), range(HEAD, HEAD + 1), range(1, HEAD + 1), top)
        fill(head, range(-1, HEAD + 1), range(1, HEAD), range(HEAD, HEAD + 1), top)
        for x in (-1, HEAD):
            fill(head, range(x, x + 1), range(1, HEAD), range(2, HEAD), top)
        return
    # Coiffures : calotte, arrière et côtés hauts communs à toutes.
    fill(head, whole, crown, whole, hair)
    fill(head, whole, upper, back, hair)
    fill(head, range(1), range(4, HEAD), range(2, HEAD), hair)
    fill(head, range(HEAD - 1, HEAD), range(4, HEAD), range(2, HEAD), hair)
    if style == "afro":
        fill(head, range(-1, HEAD + 1), range(HEAD, HEAD + 2), range(-1, HEAD + 1), hair)
        fill(head, range(-1, HEAD + 1), range(3, HEAD), range(HEAD, HEAD + 1), hair)
        for x in (-1, HEAD):
            fill(head, range(x, x + 1), range(3, HEAD), range(1, HEAD), hair)
    elif style == "long":
        fill(head, whole, range(-3, 3), range(HEAD - 1, HEAD + 1), hair)
        fill(head, whole, range(3, HEAD), range(HEAD, HEAD + 1), hair)
    elif style == "chignon":
        fill(head, range(2, 4), range(HEAD, HEAD + 2), range(HEAD - 2, HEAD), hair)
    elif style == "tresses":
        for x in (0, HEAD - 1):
            fill(head, range(x, x + 1), range(-3, 3), range(HEAD - 1, HEAD + 1), hair)
