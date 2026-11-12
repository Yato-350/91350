"""Convertit un extrait OpenStreetMap (XML) en données de zone pour le jeu.

Repère de sortie, en mètres : x vers l'est, z vers le sud (le nord est en -z), origine au
centre de la zone. Les noms de commerces, de résidences et de bâtiments sont retirés
(aucune marque dans le jeu) ; les noms de lieux publics (rues, parcs, gares) sont gardés.
"""
from __future__ import annotations

import math
import xml.etree.ElementTree as ET

EARTH_RADIUS = 6_371_008.8
LEVEL_HEIGHT = 2.8
DEFAULT_LEVELS = 3
SIMPLIFY_TOLERANCE = 0.3
ATTRIBUTION = "© les contributeurs d'OpenStreetMap — données sous licence ODbL"
LICENSE = "ODbL 1.0"

ROAD_WIDTHS = {
    "motorway": 14.0, "motorway_link": 7.0, "trunk": 12.0, "trunk_link": 7.0,
    "primary": 10.0, "primary_link": 6.0, "secondary": 9.0, "secondary_link": 6.0,
    "tertiary": 8.0, "tertiary_link": 6.0, "residential": 6.5, "unclassified": 6.5,
    "living_street": 6.0, "service": 4.0, "pedestrian": 5.0, "track": 3.0,
    "footway": 2.0, "cycleway": 2.0, "path": 1.5, "steps": 2.0,
}
BUILDING_KINDS = {
    "apartments": "residential", "residential": "residential", "house": "residential",
    "detached": "residential", "terrace": "residential", "dormitory": "residential",
    "retail": "commercial", "commercial": "commercial", "supermarket": "commercial",
    "kiosk": "commercial", "office": "commercial",
    "industrial": "industrial", "warehouse": "industrial", "garage": "industrial",
    "garages": "industrial", "hangar": "industrial",
    "train_station": "station", "transportation": "station",
}
# Lieux de culte, écoles et lieux de soins : zones neutres du jeu (ni combat ni cible).
NEUTRAL_BUILDINGS = {
    "school", "kindergarten", "university", "college", "hospital", "clinic",
    "church", "mosque", "synagogue", "temple", "chapel", "cathedral", "religious",
}
NEUTRAL_AMENITIES = {
    "school", "kindergarten", "college", "university", "hospital", "clinic", "doctors",
    "dentist", "place_of_worship", "nursing_home", "childcare",
}
GREEN_LEISURE = {"park", "garden", "pitch", "playground", "nature_reserve"}
GREEN_LANDUSE = {"grass", "forest", "meadow", "recreation_ground", "village_green", "cemetery"}
GREEN_NATURAL = {"wood", "scrub", "grassland"}
NAMED_POI_KINDS = {"station", "bus_stop"}


def project(lon: float, lat: float, origin: tuple[float, float]) -> tuple[float, float]:
    """Projection plane locale : mètres vers l'est (x) et vers le sud (z)."""
    lon0, lat0 = origin
    x = math.radians(lon - lon0) * math.cos(math.radians(lat0)) * EARTH_RADIUS
    z = -math.radians(lat - lat0) * EARTH_RADIUS
    return x, z


def convert(xml_text: str, zone_id: str, bbox: tuple[float, float, float, float]) -> dict:
    """bbox = (ouest, sud, est, nord) en degrés."""
    west, south, east, north = bbox
    origin = ((west + east) / 2, (south + north) / 2)
    east_x, _ = project(east, origin[1], origin)
    _, south_z = project(origin[0], south, origin)
    half = (east_x, south_z)

    root = ET.fromstring(xml_text)
    nodes: dict[int, tuple[float, float]] = {}
    node_tags: dict[int, dict[str, str]] = {}
    for node in root.iter("node"):
        node_id = int(node.get("id"))
        nodes[node_id] = project(float(node.get("lon")), float(node.get("lat")), origin)
        tags = _tags(node)
        if tags:
            node_tags[node_id] = tags
    ways: dict[int, tuple[list[int], dict[str, str]]] = {}
    for way in root.iter("way"):
        refs = [int(nd.get("ref")) for nd in way.iter("nd") if int(nd.get("ref")) in nodes]
        ways[int(way.get("id"))] = (refs, _tags(way))

    zone: dict = {
        "zone": zone_id, "attribution": ATTRIBUTION, "license": LICENSE,
        "origin": {"lon": round(origin[0], 7), "lat": round(origin[1], 7)},
        "size": [round(half[0] * 2, 2), round(half[1] * 2, 2)],
        "buildings": [], "roads": [], "rails": [], "water": [], "green": [], "pois": [],
    }

    # Surfaces : chemins fermés, puis relations multipolygones (anneaux extérieurs seulement).
    areas: list[tuple[int, list[tuple[float, float]], dict[str, str]]] = []
    for way_id, (refs, tags) in ways.items():
        if len(refs) >= 4 and refs[0] == refs[-1] and tags:
            areas.append((way_id, [nodes[ref] for ref in refs[:-1]], tags))
    for relation in root.iter("relation"):
        tags = _tags(relation)
        if tags.get("type") != "multipolygon":
            continue
        outers = [
            ways[int(member.get("ref"))][0]
            for member in relation.iter("member")
            if member.get("type") == "way" and member.get("role") in ("outer", "")
            and int(member.get("ref")) in ways
        ]
        for index, ring in enumerate(_assemble_rings(outers)):
            areas.append((int(relation.get("id")) * 100 + index, [nodes[r] for r in ring], tags))

    for area_id, points, tags in sorted(areas, key=lambda area: area[0]):
        if "building" in tags or "building:part" in tags:
            _add_building(zone, area_id, points, tags, half)
        elif tags.get("natural") == "water" or tags.get("waterway") == "riverbank":
            _add_area(zone["water"], area_id, points, tags, half, "water")
        elif _green_kind(tags):
            _add_area(zone["green"], area_id, points, tags, half, _green_kind(tags))
        _add_poi(zone, tags, _centroid(points), half)

    for way_id, (refs, tags) in sorted(ways.items()):
        line = [nodes[ref] for ref in refs]
        if tags.get("highway") in ROAD_WIDTHS:
            kind = tags["highway"]
            for piece in _clip_line(line, half):
                zone["roads"].append({
                    "id": way_id, "kind": kind, "width": ROAD_WIDTHS[kind],
                    "name": tags.get("name", ""), "points": _rounded(_simplify(piece)),
                })
        elif tags.get("railway") == "rail":
            for piece in _clip_line(line, half):
                zone["rails"].append({"id": way_id, "points": _rounded(_simplify(piece))})
        elif tags.get("waterway") in ("river", "stream", "canal"):
            for piece in _clip_line(line, half):
                zone["water"].append({
                    "id": way_id, "kind": "stream", "name": tags.get("name", ""),
                    "points": _rounded(_simplify(piece)),
                })

    for node_id in sorted(node_tags):
        _add_poi(zone, node_tags[node_id], nodes[node_id], half)
    return zone


def _tags(element: ET.Element) -> dict[str, str]:
    return {tag.get("k"): tag.get("v") for tag in element.findall("tag")}


def _add_building(zone: dict, area_id: int, points: list, tags: dict, half: tuple) -> None:
    if len(points) < 3 or not _inside(_centroid(points), half):
        return
    kind_tag = tags.get("building", tags.get("building:part", "yes"))
    levels = _number(tags.get("building:levels"))
    height = _number(tags.get("height"))
    if height is None:
        height = (levels if levels is not None else DEFAULT_LEVELS) * LEVEL_HEIGHT
    if levels is None:
        levels = max(1, round(height / LEVEL_HEIGHT))
    neutral = kind_tag in NEUTRAL_BUILDINGS or tags.get("amenity") in NEUTRAL_AMENITIES
    zone["buildings"].append({
        "id": area_id, "kind": BUILDING_KINDS.get(kind_tag, "neutral" if neutral else "generic"),
        "neutral": neutral, "levels": int(levels), "height": round(height, 2),
        "points": _rounded(_ccw(_simplify(points, closed=True))),
    })


def _add_area(target: list, area_id: int, points: list, tags: dict, half: tuple, kind: str) -> None:
    clipped = _clip_polygon(points, half)
    if len(clipped) >= 3:
        target.append({
            "id": area_id, "kind": kind, "name": tags.get("name", ""),
            "points": _rounded(_ccw(_simplify(clipped, closed=True))),
        })


def _add_poi(zone: dict, tags: dict, at: tuple[float, float], half: tuple) -> None:
    if not _inside(at, half):
        return
    if tags.get("railway") in ("station", "halt"):
        kind, subkind = "station", tags["railway"]
    elif tags.get("highway") == "bus_stop":
        kind, subkind = "bus_stop", "bus_stop"
    elif "shop" in tags:
        kind, subkind = "shop", tags["shop"]
    elif "amenity" in tags:
        kind, subkind = "amenity", tags["amenity"]
    elif tags.get("leisure") in ("pitch", "playground"):
        kind, subkind = "leisure", tags["leisure"]
    else:
        return
    zone["pois"].append({
        "kind": kind, "subkind": subkind,
        "name": tags.get("name", "") if kind in NAMED_POI_KINDS else "",
        "neutral": tags.get("amenity") in NEUTRAL_AMENITIES,
        "x": round(at[0], 2), "z": round(at[1], 2),
    })


def _green_kind(tags: dict) -> str:
    if tags.get("leisure") in GREEN_LEISURE:
        return tags["leisure"]
    if tags.get("landuse") in GREEN_LANDUSE:
        return tags["landuse"]
    if tags.get("natural") in GREEN_NATURAL:
        return tags["natural"]
    return ""


def _number(value: str | None) -> float | None:
    if value is None:
        return None
    try:
        return float(value.replace("m", "").replace(",", ".").strip())
    except ValueError:
        return None


def _inside(point: tuple[float, float], half: tuple[float, float]) -> bool:
    return abs(point[0]) <= half[0] and abs(point[1]) <= half[1]


def _centroid(points: list) -> tuple[float, float]:
    return (sum(p[0] for p in points) / len(points), sum(p[1] for p in points) / len(points))


def _rounded(points: list) -> list[list[float]]:
    return [[round(x, 2), round(z, 2)] for x, z in points]


def _signed_area(points: list) -> float:
    return sum(
        points[i][0] * points[(i + 1) % len(points)][1]
        - points[(i + 1) % len(points)][0] * points[i][1]
        for i in range(len(points))
    ) / 2


def _ccw(points: list) -> list:
    """Sens de parcours unique pour tous les polygones (aire signée positive)."""
    return points if _signed_area(points) > 0 else points[::-1]


def _assemble_rings(ways: list[list[int]]) -> list[list[int]]:
    """Recolle bout à bout les chemins d'un multipolygone en anneaux fermés."""
    rings: list[list[int]] = []
    pending = [list(way) for way in ways if len(way) >= 2]
    while pending:
        ring = pending.pop(0)
        while ring[0] != ring[-1]:
            for index, way in enumerate(pending):
                if way[0] == ring[-1]:
                    ring += way[1:]
                elif way[-1] == ring[-1]:
                    ring += way[-2::-1]
                else:
                    continue
                pending.pop(index)
                break
            else:
                break
        if ring[0] == ring[-1] and len(ring) >= 4:
            rings.append(ring[:-1])
    return rings


def _clip_line(points: list, half: tuple[float, float]) -> list[list]:
    """Découpe une ligne brisée sur le rectangle de la zone (algorithme de Liang-Barsky)."""
    pieces: list[list] = []
    current: list = []
    for start, end in zip(points, points[1:]):
        clipped = _clip_segment(start, end, half)
        if clipped is None:
            if len(current) >= 2:
                pieces.append(current)
            current = []
            continue
        a, b = clipped
        if not current or current[-1] != a:
            if len(current) >= 2:
                pieces.append(current)
            current = [a]
        current.append(b)
        if b != end:
            pieces.append(current)
            current = []
    if len(current) >= 2:
        pieces.append(current)
    return pieces


def _clip_segment(start: tuple, end: tuple, half: tuple) -> tuple | None:
    dx, dz = end[0] - start[0], end[1] - start[1]
    t0, t1 = 0.0, 1.0
    for p, q in (
        (-dx, start[0] + half[0]), (dx, half[0] - start[0]),
        (-dz, start[1] + half[1]), (dz, half[1] - start[1]),
    ):
        if p == 0:
            if q < 0:
                return None
            continue
        t = q / p
        if p < 0:
            t0 = max(t0, t)
        else:
            t1 = min(t1, t)
    if t0 > t1:
        return None
    a = start if t0 == 0.0 else (start[0] + t0 * dx, start[1] + t0 * dz)
    b = end if t1 == 1.0 else (start[0] + t1 * dx, start[1] + t1 * dz)
    return a, b


def _clip_polygon(points: list, half: tuple[float, float]) -> list:
    """Découpe un polygone sur le rectangle de la zone (Sutherland-Hodgman)."""
    for axis, sign in ((0, 1), (0, -1), (1, 1), (1, -1)):
        limit = half[axis]
        clipped: list = []
        for index, current in enumerate(points):
            previous = points[index - 1]
            current_in = sign * current[axis] <= limit
            previous_in = sign * previous[axis] <= limit
            if current_in != previous_in:
                t = (sign * limit - previous[axis]) / (current[axis] - previous[axis])
                clipped.append((
                    previous[0] + t * (current[0] - previous[0]),
                    previous[1] + t * (current[1] - previous[1]),
                ))
            if current_in:
                clipped.append(current)
        points = clipped
        if not points:
            break
    return points


def _simplify(points: list, closed: bool = False) -> list:
    """Douglas-Peucker : retire les points qui s'écartent de moins de SIMPLIFY_TOLERANCE."""
    if closed:
        if len(points) <= 4:
            return points
        far = max(range(len(points)), key=lambda i: math.dist(points[0], points[i]))
        first = _simplify(points[: far + 1])
        second = _simplify(points[far:] + points[:1])
        return first[:-1] + second[:-1]
    if len(points) <= 2:
        return points
    start, end = points[0], points[-1]
    length = math.dist(start, end)
    best, best_distance = 0, -1.0
    for index in range(1, len(points) - 1):
        point = points[index]
        if length == 0:
            distance = math.dist(point, start)
        else:
            distance = abs(
                (end[0] - start[0]) * (start[1] - point[1])
                - (start[0] - point[0]) * (end[1] - start[1])
            ) / length
        if distance > best_distance:
            best, best_distance = index, distance
    if best_distance <= SIMPLIFY_TOLERANCE:
        return [start, end]
    return _simplify(points[: best + 1])[:-1] + _simplify(points[best:])
