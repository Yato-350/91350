#!/usr/bin/env python3
"""Dessine un aperçu PNG d'une zone convertie (pour choisir un cadrage ou vérifier un import).

    python tools/osm_import/preview.py grigny2 [pixels_par_mètre]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def draw(zone: dict, scale: float) -> Image.Image:
    width, height = zone["size"]
    image = Image.new("RGB", (int(width * scale), int(height * scale)), (180, 183, 189))
    canvas = ImageDraw.Draw(image)

    def at(point: list[float]) -> tuple[float, float]:
        return ((point[0] + width / 2) * scale, (point[1] + height / 2) * scale)

    for area in zone["green"]:
        canvas.polygon([at(p) for p in area["points"]], fill=(63, 143, 74))
    for area in zone["water"]:
        if area["kind"] == "water":
            canvas.polygon([at(p) for p in area["points"]], fill=(63, 143, 163))
        else:
            canvas.line([at(p) for p in area["points"]], fill=(63, 143, 163), width=max(1, int(2 * scale)))
    for road in sorted(zone["roads"], key=lambda r: r["width"]):
        shade = 61 if road["kind"] not in ("footway", "path", "steps", "cycleway") else 134
        canvas.line([at(p) for p in road["points"]], fill=(shade, shade + 3, shade + 11),
                    width=max(1, int(road["width"] * scale)))
    for rail in zone["rails"]:
        canvas.line([at(p) for p in rail["points"]], fill=(124, 19, 32), width=max(1, int(1.5 * scale)))
    for building in zone["buildings"]:
        level = min(255, 60 + building["levels"] * 12)
        fill = (level, level, 40) if building["neutral"] else (level, level // 2, level // 2)
        canvas.polygon([at(p) for p in building["points"]], fill=fill, outline=(20, 21, 26))
    for poi in zone["pois"]:
        x, y = at([poi["x"], poi["z"]])
        colour = {"station": (255, 0, 255), "shop": (255, 210, 63), "amenity": (25, 195, 240)}
        canvas.ellipse([x - 3, y - 3, x + 3, y + 3], fill=colour.get(poi["kind"], (255, 255, 255)))
    step = 100
    for meters in range(0, int(width) + 1, step):
        x = meters * scale
        canvas.line([(x, 0), (x, 6)], fill=(0, 0, 0))
    return image


def main() -> int:
    zone_id = sys.argv[1]
    scale = float(sys.argv[2]) if len(sys.argv) > 2 else 2.0
    zone = json.loads((HERE / "data" / f"{zone_id}.json").read_text(encoding="utf-8"))
    output = ROOT / "build" / "osm" / f"{zone_id}.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    draw(zone, scale).save(output)
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
