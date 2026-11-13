#!/usr/bin/env python3
"""Importe une zone depuis OpenStreetMap : téléchargement (une fois), puis conversion.

    python tools/osm_import/run.py grigny2
    python tools/osm_import/run.py all

L'extrait brut est gardé dans tools/osm_import/cache/ (ignoré par Git) : relancer la
commande ne retélécharge rien. Les données converties vont dans tools/osm_import/data/
et restent sous licence ODbL.
"""
from __future__ import annotations

import json
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from osm_import.convert import convert  # noqa: E402

HERE = Path(__file__).resolve().parent
API = "https://api.openstreetmap.org/api/0.6/map?bbox={west},{south},{east},{north}"
USER_AGENT = "osm-import-tool/0.1 (extraits ponctuels, mis en cache)"


def load_zones() -> dict:
    return json.loads((HERE / "zones.json").read_text(encoding="utf-8"))


def fetch(zone_id: str, bbox: list[float]) -> str:
    cache = HERE / "cache" / f"{zone_id}.osm"
    if not cache.is_file():
        url = API.format(west=bbox[0], south=bbox[1], east=bbox[2], north=bbox[3])
        print(f"Téléchargement de {zone_id}…")
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=180) as response:
            cache.parent.mkdir(exist_ok=True)
            cache.write_bytes(response.read())
    return cache.read_text(encoding="utf-8")


def import_zone(zone_id: str, definition: dict) -> Path:
    zone = convert(fetch(zone_id, definition["bbox"]), zone_id, tuple(definition["bbox"]))
    zone["name"] = definition["name"]
    output = HERE / "data" / f"{zone_id}.json"
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(zone, ensure_ascii=False, separators=(",", ":")) + "\n",
                      encoding="utf-8")
    counts = {key: len(value) for key, value in zone.items() if isinstance(value, list)}
    print(f"{zone_id} : {zone['size'][0]:.0f} × {zone['size'][1]:.0f} m, {counts}")
    return output


def main() -> int:
    zones = load_zones()
    wanted = sys.argv[1:] or ["all"]
    names = list(zones) if wanted == ["all"] else wanted
    for name in names:
        if name not in zones:
            print(f"Zone inconnue : {name} (connues : {', '.join(zones)})", file=sys.stderr)
            return 2
        import_zone(name, zones[name])
    return 0


if __name__ == "__main__":
    sys.exit(main())
