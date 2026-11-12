#!/usr/bin/env python3
"""Pipeline voxel : modèles en couches de texte → maillages .glb + icônes 32×32.

    python tools/build_voxels.py            # tout reconstruire
    python tools/build_voxels.py batte      # un seul modèle

Source : assets_src/voxel/<nom>.txt. Un voxel mesure 1/16 m. Format :

    # commentaire
    palette:
      r: rouge_propagande        (une lettre → une couleur de assets_src/palette.json)
    part: head                   (facultatif : une partie articulée ; « main » par défaut)
    pivot: 0 22 0                (facultatif, en voxels : point de rotation de la partie)
    offset: 0 22 0               (facultatif, en voxels : position de sa grille)
    layer x3:                    (une couche horizontale, répétée 3 fois vers le haut)
      .rr.
      rrrr                       (première ligne = avant du modèle, côté -Z)

Les couches s'empilent du bas vers le haut. « . » ou espace = vide.
"""
from __future__ import annotations

import json
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets_src" / "voxel"
MESH_DIR = ROOT / "assets" / "voxel"
ICON_DIR = ROOT / "assets" / "icons"
VOXEL = 1 / 16
ICON_SIZE = 32
OUTLINE_COLOR_ID = "noir"

# Pour chaque direction : la normale et les 4 coins de la face (sens anti-horaire vu de dehors).
FACES = [
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
    ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    ((0, -1, 0), [(0, 0, 1), (0, 0, 0), (1, 0, 0), (1, 0, 1)]),
    ((0, 0, 1), [(1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)]),
    ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
]


@dataclass
class Part:
    name: str
    voxels: dict[tuple[int, int, int], tuple[int, int, int]] = field(default_factory=dict)
    pivot: tuple[float, float, float] = (0.0, 0.0, 0.0)
    offset: tuple[float, float, float] = (0, 0, 0)
    width: int = 0
    depth: int = 0
    height: int = 0


@dataclass
class Model:
    parts: dict[str, Part] = field(default_factory=dict)
    outline: tuple[int, int, int] = (0, 0, 0)


def load_palette(path: Path = ROOT / "assets_src" / "palette.json") -> dict[str, tuple[int, int, int]]:
    colors = json.loads(path.read_text(encoding="utf-8"))["colors"]
    return {c["id"]: tuple(int(c["hex"][i : i + 2], 16) for i in (1, 3, 5)) for c in colors}


def parse_model(text: str, palette: dict[str, tuple[int, int, int]]) -> Model:
    model = Model(outline=palette.get(OUTLINE_COLOR_ID, (0, 0, 0)))
    letters: dict[str, tuple[int, int, int]] = {}
    part: Part | None = None
    section = ""
    repeat = 1
    rows: list[str] = []

    def current_part() -> Part:
        nonlocal part
        if part is None:
            part = model.parts.setdefault("main", Part("main"))
        return part

    def flush_layer() -> None:
        nonlocal rows
        if not rows:
            return
        target = current_part()
        for _ in range(repeat):
            for z, row in enumerate(rows):
                for x, letter in enumerate(row):
                    if letter in ". ":
                        continue
                    if letter not in letters:
                        raise ValueError(f"lettre « {letter} » absente de la palette du modèle")
                    target.voxels[(x, target.height, z)] = letters[letter]
            target.height += 1
        target.width = max(target.width, max(len(row) for row in rows))
        target.depth = max(target.depth, len(rows))
        rows = []

    for raw in text.splitlines():
        line = raw.split("#")[0].rstrip()
        if not line.strip():
            continue
        stripped = line.strip()
        if not raw.startswith((" ", "\t")):
            flush_layer()
            section = ""
            keyword, _, value = stripped.partition(":")
            value = value.strip()
            if keyword == "palette":
                section = "palette"
            elif keyword == "part":
                part = model.parts.setdefault(value, Part(value))
            elif keyword == "pivot":
                current_part().pivot = tuple(float(v) * VOXEL for v in value.split())
            elif keyword == "offset":
                current_part().offset = tuple(float(v) for v in value.split())
            elif keyword.startswith("layer"):
                section = "layer"
                repeat = int(keyword.split("x")[1]) if "x" in keyword else 1
            else:
                raise ValueError(f"ligne non comprise : {stripped}")
        elif section == "palette":
            letter, _, color_id = stripped.partition(":")
            color_id = color_id.strip()
            if color_id not in palette:
                raise ValueError(f"couleur inconnue dans la palette du jeu : {color_id}")
            letters[letter.strip()] = palette[color_id]
        elif section == "layer":
            rows.append(stripped)
    flush_layer()
    return model


def _corner(part: Part, x: int, y: int, z: int) -> tuple[float, float, float]:
    """Position d'un coin de voxel, en mètres, par rapport au pivot de la partie."""
    ox, oy, oz = part.offset
    return (
        (x + ox - part.width / 2) * VOXEL - part.pivot[0],
        (y + oy) * VOXEL - part.pivot[1],
        (z + oz - part.depth / 2) * VOXEL - part.pivot[2],
    )


def mesh_part(part: Part) -> tuple[list, list, list, list]:
    """Rend (positions, normales, couleurs, indices) en ne gardant que les faces visibles."""
    positions: list = []
    normals: list = []
    colors: list = []
    indices: list = []
    for (x, y, z), color in sorted(part.voxels.items()):
        for normal, corners in FACES:
            if (x + normal[0], y + normal[1], z + normal[2]) in part.voxels:
                continue
            base = len(positions)
            for cx, cy, cz in corners:
                positions.append(_corner(part, x + cx, y + cy, z + cz))
                normals.append(tuple(float(n) for n in normal))
                colors.append((*color, 255))
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
    return positions, normals, colors, indices


def build_glb(model: Model) -> bytes:
    """Écrit un fichier glTF binaire : un nœud racine, un nœud et un maillage par partie."""
    buffer = bytearray()
    views: list[dict] = []
    accessors: list[dict] = []

    def add(data: bytes, target: int, component: int, kind: str, count: int, **extra) -> int:
        while len(buffer) % 4:
            buffer.append(0)
        views.append({"buffer": 0, "byteOffset": len(buffer), "byteLength": len(data), "target": target})
        buffer.extend(data)
        accessors.append({
            "bufferView": len(views) - 1, "componentType": component, "count": count,
            "type": kind, **extra,
        })
        return len(accessors) - 1

    nodes: list[dict] = [{"name": "model", "children": []}]
    meshes: list[dict] = []
    for name, part in model.parts.items():
        positions, normals, colors, indices = mesh_part(part)
        if not positions:
            continue
        bounds = {
            "min": [min(p[i] for p in positions) for i in range(3)],
            "max": [max(p[i] for p in positions) for i in range(3)],
        }
        flat = [value for vertex in positions for value in vertex]
        position = add(struct.pack(f"<{len(flat)}f", *flat), 34962, 5126, "VEC3", len(positions), **bounds)
        flat = [value for vertex in normals for value in vertex]
        normal = add(struct.pack(f"<{len(flat)}f", *flat), 34962, 5126, "VEC3", len(normals))
        flat = [value for vertex in colors for value in vertex]
        color = add(bytes(flat), 34962, 5121, "VEC4", len(colors), normalized=True)
        index = add(struct.pack(f"<{len(indices)}I", *indices), 34963, 5125, "SCALAR", len(indices))
        meshes.append({"name": name, "primitives": [{
            "attributes": {"POSITION": position, "NORMAL": normal, "COLOR_0": color},
            "indices": index, "material": 0,
        }]})
        nodes[0]["children"].append(len(nodes))
        nodes.append({"name": name, "mesh": len(meshes) - 1, "translation": list(part.pivot)})

    document = {
        "asset": {"version": "2.0", "generator": "tools/build_voxels.py"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": nodes, "meshes": meshes,
        "materials": [{"name": "voxel", "pbrMetallicRoughness": {
            "baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 1,
        }}],
        "buffers": [{"byteLength": len(buffer)}], "bufferViews": views, "accessors": accessors,
    }
    json_chunk = json.dumps(document, separators=(",", ":")).encode("utf-8")
    json_chunk += b" " * (-len(json_chunk) % 4)
    binary = bytes(buffer) + b"\0" * (-len(buffer) % 4)
    total = 12 + 8 + len(json_chunk) + 8 + len(binary)
    return (
        struct.pack("<4sII", b"glTF", 2, total)
        + struct.pack("<I4s", len(json_chunk), b"JSON") + json_chunk
        + struct.pack("<I4s", len(binary), b"BIN\0") + binary
    )


def build_icon(model: Model) -> Image.Image:
    """Icône d'inventaire : le modèle vu de face, agrandi au pixel près, cerné de noir."""
    front: dict[tuple[int, int], tuple[int, tuple[int, int, int]]] = {}
    for part in model.parts.values():
        ox, oy, oz = part.offset
        for (x, y, z), color in part.voxels.items():
            column = (round(x + ox - part.width / 2 + 64), round(y + oy))
            depth = z + oz - part.depth / 2
            if column not in front or depth < front[column][0]:
                front[column] = (depth, color)
    icon = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    if not front:
        return icon
    xs = [column[0] for column in front]
    ys = [column[1] for column in front]
    width, height = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
    room = ICON_SIZE - 2
    scale = max(1, min(room // width, room // height))
    step = max(1, -(-max(width, height) // room))  # sous-échantillonnage des grands modèles
    drawn_w, drawn_h = -(-width // step) * scale, -(-height // step) * scale
    left, top = (ICON_SIZE - drawn_w) // 2, (ICON_SIZE - drawn_h) // 2
    filled: set[tuple[int, int]] = set()
    for (x, y), (_, color) in front.items():
        cell_x, cell_y = (x - min(xs)) // step, (max(ys) - y) // step
        for dx in range(scale):
            for dy in range(scale):
                pixel = (left + cell_x * scale + dx, top + cell_y * scale + dy)
                if 0 <= pixel[0] < ICON_SIZE and 0 <= pixel[1] < ICON_SIZE:
                    icon.putpixel(pixel, (*color, 255))
                    filled.add(pixel)
    for x, y in list(filled):
        for neighbour in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            inside = 0 <= neighbour[0] < ICON_SIZE and 0 <= neighbour[1] < ICON_SIZE
            if inside and neighbour not in filled:
                icon.putpixel(neighbour, (*model.outline, 255))
    return icon


def build_file(source: Path, palette: dict) -> None:
    model = parse_model(source.read_text(encoding="utf-8"), palette)
    relative = source.relative_to(SOURCE_DIR).with_suffix("")
    mesh_path = MESH_DIR / relative.with_suffix(".glb")
    icon_path = ICON_DIR / relative.with_suffix(".png")
    mesh_path.parent.mkdir(parents=True, exist_ok=True)
    icon_path.parent.mkdir(parents=True, exist_ok=True)
    mesh_path.write_bytes(build_glb(model))
    build_icon(model).save(icon_path)


def main() -> int:
    palette = load_palette()
    wanted = set(sys.argv[1:])
    sources = sorted(SOURCE_DIR.rglob("*.txt"))
    built = 0
    for source in sources:
        if wanted and source.stem not in wanted:
            continue
        try:
            build_file(source, palette)
        except ValueError as error:
            print(f"{source.relative_to(ROOT)} : {error}", file=sys.stderr)
            return 1
        built += 1
    print(f"{built} modèle(s) voxel construit(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
