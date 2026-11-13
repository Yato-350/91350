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


DETAILS = """<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
  <node id="41" lat="48.0060" lon="2.0060"/>
  <node id="42" lat="48.0060" lon="2.0070"/>
  <node id="43" lat="48.0070" lon="2.0070"/>
  <node id="44" lat="48.0070" lon="2.0060"/>
  <node id="45" lat="48.0060" lon="2.0065"><tag k="entrance" v="staircase"/></node>
  <node id="46" lat="48.0030" lon="2.0030"><tag k="natural" v="tree"/></node>
  <node id="47" lat="48.0010" lon="2.0010"/>
  <node id="48" lat="48.0010" lon="2.0020"/>
  <node id="49" lat="48.0015" lon="2.0020"/>
  <node id="50" lat="48.0015" lon="2.0010"/>
  <node id="51" lat="48.0030" lon="2.0010"/>
  <node id="52" lat="48.0030" lon="2.0030"><tag k="highway" v="crossing"/></node>
  <node id="53" lat="48.0030" lon="2.0050"/>
  <node id="54" lat="48.0031" lon="2.0020"><tag k="amenity" v="bench"/></node>
  <node id="55" lat="48.0032" lon="2.0040"><tag k="amenity" v="waste_basket"/></node>
  <node id="56" lat="48.0029" lon="2.0045"><tag k="highway" v="bus_stop"/></node>
  <node id="57" lat="48.0033" lon="2.0035"><tag k="advertising" v="billboard"/></node>
  <node id="58" lat="48.0034" lon="2.0012"><tag k="man_made" v="surveillance"/></node>
  <node id="59" lat="48.0090" lon="2.0010"><tag k="power" v="tower"/></node>
  <node id="60" lat="48.0090" lon="2.0090"><tag k="power" v="tower"/></node>
  <node id="61" lat="48.0020" lon="2.0080"><tag k="amenity" v="recycling"/></node>
  <node id="62" lat="48.0022" lon="2.0082"><tag k="barrier" v="block"/></node>
  <node id="63" lat="48.0010" lon="2.0015"><tag k="barrier" v="gate"/></node>
  <way id="200">
    <nd ref="41"/><nd ref="45"/><nd ref="42"/><nd ref="43"/><nd ref="44"/><nd ref="41"/>
    <tag k="building" v="apartments"/><tag k="building:levels" v="10"/>
    <tag k="colour" v="White"/><tag k="roof:colour" v="beige"/>
  </way>
  <way id="210">
    <nd ref="47"/><nd ref="48"/><nd ref="49"/><nd ref="50"/><nd ref="47"/>
    <tag k="amenity" v="parking"/><tag k="parking" v="surface"/>
  </way>
  <way id="211">
    <nd ref="47"/><nd ref="48"/><nd ref="49"/><nd ref="50"/><nd ref="47"/>
    <tag k="amenity" v="parking"/><tag k="parking" v="underground"/>
  </way>
  <way id="212"><nd ref="47"/><nd ref="63"/><nd ref="48"/><tag k="barrier" v="fence"/></way>
  <way id="213"><nd ref="49"/><nd ref="50"/><tag k="barrier" v="hedge"/></way>
  <way id="214">
    <nd ref="51"/><nd ref="52"/><nd ref="53"/>
    <tag k="highway" v="residential"/>
  </way>
  <way id="215"><nd ref="59"/><nd ref="60"/><tag k="power" v="line"/></way>
</osm>
"""


def _details():
    return convert(DETAILS, "essai", BBOX)


def test_trees_are_kept_as_points():
    zone = _details()
    origin = (2.005, 48.005)
    expected = project(2.003, 48.003, origin)
    assert len(zone["trees"]) == 1
    assert math.dist(zone["trees"][0], expected) < 0.01


def test_entrances_are_attached_to_their_building_with_an_outward_normal():
    zone = _details()
    assert len(zone["entrances"]) == 1
    entrance = zone["entrances"][0]
    assert entrance["building"] == 200
    assert entrance["kind"] == "staircase"
    assert math.isclose(entrance["normal"][0], 0.0, abs_tol=0.01)
    assert math.isclose(entrance["normal"][1], 1.0, abs_tol=0.01), "porte au sud : normale vers +z"
    south = project(2.0065, 48.0060, (2.005, 48.005))
    assert math.dist((entrance["x"], entrance["z"]), south) < 0.05


def test_only_surface_parkings_are_kept():
    zone = _details()
    assert [parking["id"] for parking in zone["parkings"]] == [210]


def test_barriers_keep_their_kind():
    zone = _details()
    kinds = {barrier["id"]: barrier["kind"] for barrier in zone["barriers"]}
    assert kinds == {212: "fence", 213: "hedge"}


def test_crossings_follow_the_direction_of_their_road():
    zone = _details()
    assert len(zone["crossings"]) == 1
    crossing = zone["crossings"][0]
    assert math.isclose(math.cos(crossing["angle"]), 1.0, abs_tol=0.01), "rue d'ouest en est"


def test_street_furniture_becomes_game_props_aligned_with_the_street():
    zone = _details()
    kinds = sorted(item["kind"] for item in zone["furniture"])
    assert kinds == ["abribus", "banc", "camera", "conteneurs", "ecran", "plot", "poubelle",
                     "pylone", "pylone"]
    bench = next(item for item in zone["furniture"] if item["kind"] == "banc")
    assert math.isclose(abs(math.cos(bench["angle"])), 1.0, abs_tol=0.01)


def test_power_lines_are_kept():
    zone = _details()
    assert [line["id"] for line in zone["power_lines"]] == [215]
    assert len(zone["power_lines"][0]["points"]) == 2


def test_building_colours_are_kept_in_lower_case():
    zone = _details()
    building = zone["buildings"][0]
    assert building["colour"] == "white"
    assert building["roof_colour"] == "beige"


def test_gates_open_the_barriers():
    zone = _details()
    gate = project(2.0015, 48.0010, (2.005, 48.005))
    assert len(zone["gates"]) == 1
    assert math.dist(zone["gates"][0], gate) < 0.01
