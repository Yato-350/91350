"""Tests des sons synthétisés : formats, boucles, crêtes, reproductibilité."""
import struct
import sys
import wave
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

import build_sounds  # noqa: E402


def test_every_recipe_gives_a_short_clean_sound():
    for name, (recipe, loop) in build_sounds.SOUNDS.items():
        buffer = recipe()
        assert len(buffer) > 0, name
        assert max(abs(value) for value in buffer) <= 1.0, name
        seconds = len(buffer) / build_sounds.RATE
        assert seconds <= (25.0 if loop else 3.5), f"{name} dure {seconds:.1f} s"


def test_the_same_recipe_gives_the_same_sound():
    assert build_sounds.footstep(1) == build_sounds.footstep(1)
    assert build_sounds.footstep(1) != build_sounds.footstep(2), "trois prises différentes"


def test_a_loop_carries_its_loop_points(tmp_path):
    path = tmp_path / "boucle.wav"
    buffer = [0.0] * 1000
    build_sounds.write_wav(path, buffer, loop=True)
    with wave.open(str(path), "rb") as file:
        assert file.getnframes() == 1000
        assert file.getframerate() == build_sounds.RATE
    data = path.read_bytes()
    assert struct.unpack("<I", data[4:8])[0] == len(data) - 8, "taille RIFF à jour"
    index = data.index(b"smpl")
    loop_start, loop_end = struct.unpack("<2I", data[index + 8 + 36 + 8 : index + 8 + 36 + 16])
    assert (loop_start, loop_end) == (0, 999)


def test_a_one_shot_has_no_loop_chunk(tmp_path):
    path = tmp_path / "coup.wav"
    build_sounds.write_wav(path, [0.1, -0.1], loop=False)
    assert b"smpl" not in path.read_bytes()


def test_notes_are_tuned_to_a440():
    assert abs(build_sounds.note("A4") - 440.0) < 1e-9
    assert abs(build_sounds.note("A3") - 220.0) < 1e-9
    assert abs(build_sounds.note("C4") - 261.6256) < 1e-3
