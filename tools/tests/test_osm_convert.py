"""Tests de la conversion OpenStreetMap → données de zone."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from osm_import.convert import convert, project  # noqa: E402

BBOX = (2.0, 48.0, 2.01, 48.01)  # ouest, sud, est, nord

OSM = """<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
  <node id="1" lat="48.0040" lon="2.0040"/>
  <node id="2" lat="48.0040" lon="2.0050"/>
  <node id="3" lat="48.0050" lon="2.0050"/>
  <node id="4" lat="48.0050" lon="2.0040"/>
  <node id="5" lat="48.0020" lon="2.0010"/>
  <node id="6" lat="48.0020" lon="2.0090"/>
  <node id="7" lat="48.0080" lon="2.0020"><tag k="shop" v="supermarket"/><tag k="name" v="MarqueConnue"/></node>
  <node id="8" lat="48.0085" lon="2.0025"><tag k="railway" v="station"/><tag k="name" v="Gare du Test"/></node>
  <node id="9" lat="48.0200" lon="2.0200"/>
  <way id="100">
    <nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="4"/><nd ref="1"/>
    <tag k="building" v="apartments"/><tag k="building:levels" v="12"/><tag k="name" v="Bailleur Machin 44"/>
  </way>
  <way id="101">
    <nd ref="4"/><nd ref="3"/><nd ref="2"/><nd ref="1"/><nd ref="4"/>
    <tag k="building" v="yes"/>
  </way>
  <way id="102">
    <nd ref="5"/><nd ref="6"/>
    <tag k="highway" v="residential"/><tag k="name" v="Rue du Test"/>
  </way>
  <way id="103">
    <nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="1"/>
    <tag k="natural" v="water"/>
  </way>
  <way id="104">
    <nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="1"/>
    <tag k="leisure" v="park"/><tag k="name" v="Parc du Test"/>
  </way>
  <way id="105">
    <nd ref="5"/><nd ref="9"/>
    <tag k="highway" v="motorway"/>
  </way>
  <way id="106">
    <nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="4"/><nd ref="1"/>
    <tag k="building" v="school"/><tag k="height" v="7.5"/>
  </way>
</osm>
"""


def test_projection_is_metric_and_north_is_minus_z():
    x, z = project(2.005, 48.006, origin=(2.005, 48.005))
    assert abs(x) < 1e-6
    assert math.isclose(z, -111.19, abs_tol=0.2)  # 0,001° de latitude ≈ 111 m vers le nord
    x, z = project(2.006, 48.005, origin=(2.005, 48.005))
    assert math.isclose(x, 74.4, abs_tol=0.3)  # 0,001° de longitude à 48° N
    assert abs(z) < 1e-6


def test_building_height_comes_from_levels_then_height_then_default():
    zone = convert(OSM, "essai", BBOX)
    by_id = {b["id"]: b for b in zone["buildings"]}
    assert by_id[100]["levels"] == 12
    assert by_id[100]["height"] == 33.6
    assert by_id[106]["height"] == 7.5
    assert by_id[101]["height"] == 8.4


def test_polygons_are_counter_clockwise_and_open():
    zone = convert(OSM, "essai", BBOX)
    for building in zone["buildings"]:
        points = building["points"]
        assert points[0] != points[-1]
        area = sum(
            points[i][0] * points[(i + 1) % len(points)][1]
            - points[(i + 1) % len(points)][0] * points[i][1]
            for i in range(len(points))
        )
        assert area > 0


def test_business_and_landlord_names_are_dropped_but_place_names_kept():
    zone = convert(OSM, "essai", BBOX)
    text = str(zone)
    assert "MarqueConnue" not in text
    assert "Bailleur Machin" not in text
    assert zone["roads"][0]["name"] == "Rue du Test"
    assert zone["green"][0]["name"] == "Parc du Test"
    stations = [p for p in zone["pois"] if p["kind"] == "station"]
    assert stations[0]["name"] == "Gare du Test"
    shops = [p for p in zone["pois"] if p["kind"] == "shop"]
    assert shops and shops[0]["name"] == ""


def test_neutral_buildings_are_flagged():
    zone = convert(OSM, "essai", BBOX)
    by_id = {b["id"]: b for b in zone["buildings"]}
    assert by_id[106]["neutral"] is True
    assert by_id[100]["neutral"] is False


def test_roads_are_clipped_to_the_zone():
    zone = convert(OSM, "essai", BBOX)
    half_w, half_h = zone["size"][0] / 2, zone["size"][1] / 2
    for road in zone["roads"]:
        for x, z in road["points"]:
            assert -half_w - 0.01 <= x <= half_w + 0.01
            assert -half_h - 0.01 <= z <= half_h + 0.01
    assert any(r["kind"] == "motorway" for r in zone["roads"])


def test_output_carries_license_and_is_deterministic():
    first = convert(OSM, "essai", BBOX)
    second = convert(OSM, "essai", BBOX)
    assert first == second
    assert first["license"] == "ODbL 1.0"
    assert "OpenStreetMap" in first["attribution"]
    assert first["water"] and first["green"]
