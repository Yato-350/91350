#!/usr/bin/env python3
"""Sons du jeu, synthétisés à partir de rien (façon sfxr) : bruitages, musiques, ambiance.

    python tools/build_sounds.py            # tout reconstruire dans assets/audio/
    python tools/build_sounds.py coup pas   # seulement ceux-là

Chaque son est une recette Python ci-dessous : des oscillateurs (carré, dent de scie,
triangle, sinus, bruit), des enveloppes et des glissandos. Le hasard est graine fixe :
le même script redonne exactement les mêmes fichiers. WAV 16 bits mono à 22 050 Hz ;
une boucle porte un bloc « smpl » que Godot lit pour la faire tourner sans couture.
Licence : CC0 (créés pour 91350).
"""
from __future__ import annotations

import math
import random
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "audio"
RATE = 22050
SEED = 91350
# Crêtes visées : les bruitages gardent de la marge, la musique encore plus (on mixe dessus).
PEAK_SFX = 10 ** (-3 / 20)
PEAK_MUSIC = 10 ** (-6 / 20)

Buffer = list[float]


# --- Briques ------------------------------------------------------------------------


def silence(seconds: float) -> Buffer:
    return [0.0] * int(seconds * RATE)


def tone(kind: str, freq, seconds: float, rng: random.Random | None = None) -> Buffer:
    """Un oscillateur ; `freq` est un nombre ou une fonction du temps (glissando)."""
    count = int(seconds * RATE)
    out: Buffer = []
    phase = 0.0
    noise_value = 0.0
    rng = rng or random.Random(SEED)
    for index in range(count):
        t = index / RATE
        f = freq(t) if callable(freq) else freq
        phase += f / RATE
        if phase >= 1.0:
            phase -= math.floor(phase)
            noise_value = rng.uniform(-1.0, 1.0)
        if kind == "sine":
            out.append(math.sin(2 * math.pi * phase))
        elif kind == "square":
            out.append(1.0 if phase < 0.5 else -1.0)
        elif kind == "saw":
            out.append(2.0 * phase - 1.0)
        elif kind == "triangle":
            out.append(4.0 * abs(phase - 0.5) - 1.0)
        elif kind == "noise":
            out.append(noise_value)
        else:
            raise ValueError(f"oscillateur inconnu : {kind}")
    return out


def white(seconds: float, rng: random.Random) -> Buffer:
    return [rng.uniform(-1.0, 1.0) for _ in range(int(seconds * RATE))]


def envelope(buffer: Buffer, attack: float, decay: float, sustain: float, release: float) -> Buffer:
    """ADSR : montée, descente vers le palier, palier, chute finale (en secondes)."""
    count = len(buffer)
    a, d, r = int(attack * RATE), int(decay * RATE), int(release * RATE)
    out: Buffer = []
    for index, value in enumerate(buffer):
        if index < a:
            gain = index / max(a, 1)
        elif index < a + d:
            gain = 1.0 - (1.0 - sustain) * (index - a) / max(d, 1)
        else:
            gain = sustain
        if index > count - r:
            gain *= max(count - index, 0) / max(r, 1)
        out.append(value * gain)
    return out


def lowpass(buffer: Buffer, cutoff: float) -> Buffer:
    alpha = 1.0 - math.exp(-2 * math.pi * cutoff / RATE)
    out: Buffer = []
    state = 0.0
    for value in buffer:
        state += alpha * (value - state)
        out.append(state)
    return out


def highpass(buffer: Buffer, cutoff: float) -> Buffer:
    low = lowpass(buffer, cutoff)
    return [value - smooth for value, smooth in zip(buffer, low)]


def gain(buffer: Buffer, amount: float) -> Buffer:
    return [value * amount for value in buffer]


def mix(*buffers: Buffer) -> Buffer:
    out = [0.0] * max(len(buffer) for buffer in buffers)
    for buffer in buffers:
        for index, value in enumerate(buffer):
            out[index] += value
    return out


def place(target: Buffer, sound: Buffer, at: float, wrap: bool = False) -> None:
    """Ajoute `sound` dans `target` à l'instant `at` ; en boucle, ce qui dépasse revient au début."""
    start = int(at * RATE)
    size = len(target)
    for index, value in enumerate(sound):
        position = start + index
        if position >= size:
            if not wrap:
                break
            position %= size
        target[position] += value


def concat(*buffers: Buffer) -> Buffer:
    out: Buffer = []
    for buffer in buffers:
        out.extend(buffer)
    return out


def normalize(buffer: Buffer, peak: float) -> Buffer:
    top = max((abs(value) for value in buffer), default=0.0)
    return gain(buffer, peak / top) if top > 0 else buffer


def note(name: str) -> float:
    """« A4 », « C#3 » → fréquence (Hz)."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semitones = names[name[0]] + (1 if "#" in name else 0) - (1 if name[1] == "b" else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((semitones + (octave - 4) * 12) / 12)


def pluck(freq: float, seconds: float, kind: str = "triangle", brightness: float = 3000.0) -> Buffer:
    return lowpass(envelope(tone(kind, freq, seconds), 0.005, seconds * 0.4, 0.3, seconds * 0.5), brightness)


# --- Bruitages ----------------------------------------------------------------------


def footstep(take: int) -> Buffer:
    rng = random.Random(SEED + take)
    thump = envelope(tone("sine", lambda t: 110 - 300 * t, 0.07), 0.002, 0.03, 0.2, 0.03)
    scuff = envelope(lowpass(white(0.06, rng), 1400 + 300 * take), 0.001, 0.02, 0.3, 0.03)
    return normalize(mix(gain(thump, 0.8), scuff), PEAK_SFX)


def punch() -> Buffer:
    rng = random.Random(SEED + 10)
    body = envelope(tone("sine", lambda t: 160 - 500 * t, 0.14), 0.001, 0.05, 0.3, 0.08)
    slap = envelope(lowpass(white(0.08, rng), 3000), 0.001, 0.02, 0.2, 0.05)
    return normalize(mix(body, gain(slap, 0.7)), PEAK_SFX)


def knock_out() -> Buffer:
    rng = random.Random(SEED + 11)
    fall = envelope(tone("sine", lambda t: 90 - 60 * t, 0.35), 0.002, 0.15, 0.4, 0.15)
    dust = envelope(lowpass(white(0.25, rng), 800), 0.01, 0.1, 0.3, 0.1)
    return normalize(mix(fall, gain(dust, 0.5)), PEAK_SFX)


def guard_alert() -> Buffer:
    first = envelope(tone("square", note("E5"), 0.09), 0.002, 0.03, 0.6, 0.02)
    second = envelope(tone("square", note("B5"), 0.16), 0.002, 0.05, 0.6, 0.06)
    return normalize(lowpass(concat(first, silence(0.02), second), 4000), PEAK_SFX)


def camera_spot() -> Buffer:
    beep = envelope(tone("sine", 1660, 0.07), 0.002, 0.02, 0.8, 0.02)
    return normalize(concat(beep, silence(0.05), beep, silence(0.05), beep), PEAK_SFX)


def alarm() -> Buffer:
    sweep = tone("saw", lambda t: 600 + 300 * abs(math.sin(math.pi * t / 0.4)), 1.2)
    return normalize(envelope(lowpass(sweep, 2500), 0.02, 0.1, 0.8, 0.2), PEAK_SFX)


def door() -> Buffer:
    rng = random.Random(SEED + 12)
    latch = envelope(tone("square", 900, 0.02), 0.001, 0.01, 0.2, 0.01)
    thud = envelope(tone("sine", lambda t: 120 - 80 * t, 0.25), 0.002, 0.1, 0.3, 0.1)
    air = envelope(lowpass(white(0.2, rng), 600), 0.02, 0.08, 0.3, 0.08)
    return normalize(mix(latch, thud, gain(air, 0.4)), PEAK_SFX)


def pickup() -> Buffer:
    notes = [note("C5"), note("E5"), note("G5")]
    return normalize(concat(*(envelope(tone("square", f, 0.06), 0.002, 0.02, 0.6, 0.02) for f in notes)), PEAK_SFX)


def spray() -> Buffer:
    rng = random.Random(SEED + 13)
    clack = envelope(tone("square", 2400, 0.015), 0.001, 0.01, 0.1, 0.004)
    shake = concat(clack, silence(0.09), clack, silence(0.12))
    hiss = envelope(highpass(white(0.7, rng), 3000), 0.03, 0.1, 0.8, 0.15)
    return normalize(concat(shake, gain(hiss, 0.8)), PEAK_SFX)


def cable_cut() -> Buffer:
    rng = random.Random(SEED + 14)
    snap = envelope(white(0.03, rng), 0.001, 0.01, 0.2, 0.01)
    zap = envelope(tone("saw", lambda t: 1800 - 1600 * t / 0.2, 0.2), 0.002, 0.05, 0.4, 0.1)
    return normalize(mix(snap, gain(lowpass(zap, 3000), 0.6)), PEAK_SFX)


def siren() -> Buffer:
    wail = tone("sine", lambda t: 450 + 250 * (0.5 - 0.5 * math.cos(2 * math.pi * t / 1.25)), 2.5)
    harmonic = gain(tone("sine", lambda t: 900 + 500 * (0.5 - 0.5 * math.cos(2 * math.pi * t / 1.25)), 2.5), 0.3)
    return normalize(envelope(mix(wail, harmonic), 0.2, 0.2, 0.9, 0.4), PEAK_SFX)


def announcement() -> Buffer:
    # Le carillon poli du régime : trois notes qui descendent, sans chaleur.
    chime = [note("A5"), note("F5"), note("C5")]
    parts = [envelope(mix(tone("sine", f, 0.4), gain(tone("sine", f * 2, 0.4), 0.2)), 0.005, 0.1, 0.5, 0.25)
             for f in chime]
    return normalize(concat(*parts), PEAK_SFX)


def step_done() -> Buffer:
    return normalize(concat(pluck(note("G5"), 0.09, "square"), pluck(note("C6"), 0.18, "square")), PEAK_SFX)


def quest_done() -> Buffer:
    melody = [note("C5"), note("E5"), note("G5"), note("C6")]
    parts = [pluck(f, 0.14, "square", 3500) for f in melody[:-1]] + [pluck(melody[-1], 0.5, "square", 3500)]
    return normalize(concat(*parts), PEAK_SFX)


def level_up() -> Buffer:
    up = tone("square", lambda t: 400 * 2 ** (t / 0.25), 0.5)
    return normalize(lowpass(envelope(up, 0.01, 0.1, 0.7, 0.2), 3500), PEAK_SFX)


def liberation() -> Buffer:
    # Un accord majeur qui s'ouvre : la couleur revient.
    chord = [note("C4"), note("E4"), note("G4"), note("C5"), note("E5")]
    voices = [envelope(mix(tone("saw", f, 3.0), gain(tone("sine", f / 2, 3.0), 0.5)), 0.8, 0.5, 0.7, 1.2) for f in chord]
    swell = mix(*voices)
    opened = [value for value in lowpass(swell, 1800)]
    return normalize(opened, PEAK_SFX)


def arrest() -> Buffer:
    rng = random.Random(SEED + 15)
    hit = envelope(tone("sine", lambda t: 70 - 30 * t, 1.0), 0.002, 0.3, 0.4, 0.5)
    clash = envelope(mix(tone("saw", note("C3"), 1.0), tone("saw", note("C#3"), 1.0)), 0.01, 0.3, 0.3, 0.5)
    noise_burst = envelope(lowpass(white(0.3, rng), 1200), 0.001, 0.1, 0.2, 0.15)
    return normalize(mix(hit, gain(lowpass(clash, 900), 0.4), gain(noise_burst, 0.6)), PEAK_SFX)


def ui_tick() -> Buffer:
    return normalize(envelope(tone("square", 1200, 0.025), 0.001, 0.01, 0.3, 0.01), PEAK_SFX * 0.5)


def ui_accept() -> Buffer:
    return normalize(concat(envelope(tone("square", 880, 0.035), 0.001, 0.01, 0.6, 0.01),
                            envelope(tone("square", 1320, 0.04), 0.001, 0.01, 0.6, 0.02)), PEAK_SFX * 0.6)


def ui_back() -> Buffer:
    return normalize(concat(envelope(tone("square", 880, 0.035), 0.001, 0.01, 0.6, 0.01),
                            envelope(tone("square", 587, 0.04), 0.001, 0.01, 0.6, 0.02)), PEAK_SFX * 0.6)


def bubble() -> Buffer:
    return normalize(envelope(tone("triangle", lambda t: 700 + 2000 * t, 0.04), 0.002, 0.01, 0.6, 0.02), PEAK_SFX * 0.5)


# --- Musiques et ambiance (boucles) ---------------------------------------------------


def regime_drone() -> Buffer:
    """Le régime : un bourdon froid, un battement lent, un « bip » de surveillance."""
    seconds = 16.0
    # Des fréquences qui font un nombre entier de cycles sur la boucle : pas de couture.
    def whole(freq: float) -> float:
        return round(freq * seconds) / seconds
    low = mix(tone("sine", whole(note("A1")), seconds), gain(tone("sine", whole(note("E2")) + 0.25, seconds), 0.6),
              gain(tone("triangle", whole(note("A2")) - 0.25, seconds), 0.25))
    breath = [value * (0.75 + 0.25 * math.sin(2 * math.pi * index / (RATE * seconds / 2)))
              for index, value in enumerate(low)]
    track = lowpass(breath, 700)
    ping = envelope(mix(tone("sine", note("E6"), 0.6), gain(tone("sine", note("B6"), 0.6), 0.3)), 0.005, 0.2, 0.2, 0.35)
    for at in (2.0, 10.0):
        place(track, gain(ping, 0.18), at, wrap=True)
    pulse = envelope(tone("sine", lambda t: 55 - 20 * t, 0.25), 0.002, 0.1, 0.2, 0.12)
    for beat in range(16):
        place(track, gain(pulse, 0.35), beat * 1.0, wrap=True)
    return normalize(track, PEAK_MUSIC)


def warm_loop(bpm: float, chords: list[list[str]], groove: bool, seed: int) -> Buffer:
    """Une boucle chaude : des accords en nappe, un arpège, une basse, et un rythme léger."""
    rng = random.Random(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    seconds = bar * len(chords)
    track = silence(seconds)
    for index, chord in enumerate(chords):
        start = index * bar
        freqs = [note(name) for name in chord]
        pad = mix(*(gain(tone("triangle", f, bar + 0.4), 0.5) for f in freqs))
        place(track, gain(lowpass(envelope(pad, 0.3, 0.5, 0.7, 0.6), 1500), 0.5), start, wrap=True)
        bass = envelope(tone("sine", freqs[0] / 2, beat * 1.8), 0.01, 0.2, 0.7, 0.3)
        place(track, gain(bass, 0.8), start, wrap=True)
        place(track, gain(bass, 0.6), start + beat * 2, wrap=True)
        arpeggio = freqs + [freqs[1] * 2]
        for step in range(8):
            f = arpeggio[step % len(arpeggio)] * 2
            place(track, gain(pluck(f, beat * 0.9, "square", 2200), 0.16), start + step * beat / 2, wrap=True)
        if groove:
            kick = envelope(tone("sine", lambda t: 120 - 300 * t, 0.18), 0.001, 0.08, 0.2, 0.08)
            snare = envelope(highpass(white(0.15, rng), 1500), 0.001, 0.05, 0.2, 0.08)
            hat = envelope(highpass(white(0.04, rng), 6000), 0.001, 0.01, 0.2, 0.02)
            for b in range(4):
                place(track, gain(kick, 0.7 if b % 2 == 0 else 0.0), start + b * beat, wrap=True)
                place(track, gain(snare, 0.35 if b % 2 == 1 else 0.0), start + b * beat, wrap=True)
                for half in range(2):
                    place(track, gain(hat, 0.12), start + b * beat + half * beat / 2, wrap=True)
    return normalize(track, PEAK_MUSIC)


def home_loop() -> Buffer:
    """Chez soi : la même chaleur, sans tambour, plus lente."""
    return warm_loop(70.0, [["F3", "A3", "C4"], ["D3", "F3", "A3"], ["A#2", "D3", "F3"], ["C3", "E3", "G3"]],
                     groove=False, seed=SEED + 20)


def free_loop() -> Buffer:
    """Le quartier libre : les mêmes accords, avec le rythme de la rue."""
    return warm_loop(90.0, [["F3", "A3", "C4"], ["D3", "F3", "A3"], ["A#2", "D3", "F3"], ["C3", "E3", "G3"],
                            ["F3", "A3", "C4"], ["A3", "C4", "E4"], ["A#2", "D3", "F3"], ["C3", "E3", "G3"]],
                     groove=True, seed=SEED + 21)


def city_ambience() -> Buffer:
    """La rumeur de la ville : un grondement lointain qui respire."""
    rng = random.Random(SEED + 30)
    seconds = 8.0
    rumble = lowpass(lowpass(white(seconds, rng), 180), 180)
    swell = [value * (0.7 + 0.3 * math.sin(2 * math.pi * index / (RATE * seconds))) for index, value in enumerate(rumble)]
    # Fondu enchaîné de la fin sur le début : la boucle ne claque pas.
    fade = int(0.5 * RATE)
    for index in range(fade):
        mix_in = index / fade
        swell[index] = swell[index] * mix_in + swell[len(swell) - fade + index] * (1 - mix_in)
    looped = swell[: len(swell) - fade]
    return normalize(looped, PEAK_MUSIC)


# Nom du fichier → (recette, boucle ?)
SOUNDS = {
    "pas_1": (lambda: footstep(1), False),
    "pas_2": (lambda: footstep(2), False),
    "pas_3": (lambda: footstep(3), False),
    "coup": (punch, False),
    "ko": (knock_out, False),
    "vigile_alerte": (guard_alert, False),
    "camera_repere": (camera_spot, False),
    "alarme": (alarm, False),
    "porte": (door, False),
    "ramassage": (pickup, False),
    "bombe": (spray, False),
    "coupe": (cable_cut, False),
    "sirene": (siren, False),
    "annonce": (announcement, False),
    "objectif": (step_done, False),
    "quete": (quest_done, False),
    "niveau": (level_up, False),
    "liberation": (liberation, False),
    "arrestation": (arrest, False),
    "ui_survol": (ui_tick, False),
    "ui_valide": (ui_accept, False),
    "ui_retour": (ui_back, False),
    "bulle": (bubble, False),
    "musique_regime": (regime_drone, True),
    "musique_maison": (home_loop, True),
    "musique_libre": (free_loop, True),
    "ambiance_ville": (city_ambience, True),
}


def to_pcm(buffer: Buffer) -> bytes:
    return b"".join(struct.pack("<h", max(-32767, min(32767, int(round(value * 32767))))) for value in buffer)


def write_wav(path: Path, buffer: Buffer, loop: bool) -> None:
    """WAV 16 bits mono ; une boucle reçoit un bloc « smpl » (boucle avant sur tout le son)."""
    with wave.open(str(path), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(to_pcm(buffer))
    if not loop:
        return
    data = path.read_bytes()
    smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
    smpl += struct.pack("<6I", 0, 0, 0, len(buffer) - 1, 0, 0)
    chunk = b"smpl" + struct.pack("<I", len(smpl)) + smpl
    riff_size = struct.unpack("<I", data[4:8])[0] + len(chunk)
    path.write_bytes(data[:4] + struct.pack("<I", riff_size) + data[8:] + chunk)


def main() -> int:
    wanted = set(sys.argv[1:])
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    built = 0
    for name, (recipe, loop) in SOUNDS.items():
        if wanted and name not in wanted:
            continue
        write_wav(OUT_DIR / f"{name}.wav", recipe(), loop)
        built += 1
    print(f"{built} son(s) construit(s) dans {OUT_DIR.relative_to(ROOT)}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
