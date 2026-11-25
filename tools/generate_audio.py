"""Synthesize the BETA PROTOCOL score and sound effects with the Python stdlib."""

import math
import random
import struct
import wave
from pathlib import Path


RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
TAU = math.tau


def write(name, samples, loop=False):
    peak = max(1.0, max(abs(sample) for sample in samples))
    pcm = [round(sample * (32000 / peak)) for sample in samples]
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
    if loop:
        # RIFF sampler header and one forward loop ending at the final sample.
        sampler = struct.pack("<15I", 0, 0, round(1e9 / RATE), 60, 0, 0, 0, 1, 0,
                              0, 0, 0, len(pcm) - 1, 0, 0)
        with path.open("r+b") as stream:
            stream.seek(0, 2)
            stream.write(struct.pack("<4sI", b"smpl", len(sampler)) + sampler)
            size = stream.tell()
            stream.seek(4)
            stream.write(struct.pack("<I", size - 8))


class Track:
    def __init__(self, duration, seed, loop=False):
        self.samples = [0.0] * round(duration * RATE)
        self.random = random.Random(seed)
        self.loop = loop

    def add(self, start, duration, sample_at):
        offset = round(start * RATE)
        for index in range(round(duration * RATE)):
            position = offset + index
            if self.loop:
                position %= len(self.samples)
            elif position >= len(self.samples):
                break
            self.samples[position] += sample_at(index / RATE)

    def tone(self, start, duration, low, high, level, voice="sine", attack=0.005):
        def sample(t):
            phase = TAU * (low * t + (high - low) * t * t / (2 * duration))
            if voice == "pulse":
                signal = (math.sin(phase) + 0.26 * math.sin(3 * phase)
                          + 0.11 * math.sin(5 * phase)) / 1.37
            elif voice == "bell":
                signal = 0.7 * math.sin(phase) + 0.3 * math.sin(phase * 2.76) * math.exp(-9 * t)
            else:
                signal = math.sin(phase)
            release = (1 - t / duration) ** 2
            return signal * level * min(1.0, t / attack) * release

        self.add(start, duration, sample)

    def noise(self, start, duration, level, smooth, decay=3, attack=0.002, bright=0.0):
        state = 0.0

        def sample(t):
            nonlocal state
            white = self.random.uniform(-1, 1)
            state += (white - state) * smooth
            return (state + bright * (white - state)) * level * min(1, t / attack) * (1 - t / duration) ** decay

        self.add(start, duration, sample)


def effects():
    track = Track(0.19, 14)
    track.tone(0, 0.12, 109, 49, 0.46)
    track.noise(0, 0.18, 0.88, 0.19, bright=0.18)
    track.noise(0.035, 0.1, 0.36, 0.66)
    write("sfx_footstep_1", track.samples)
    track = Track(0.2, 15)
    track.tone(0, 0.14, 93, 42, 0.43)
    track.noise(0, 0.16, 0.93, 0.16, bright=0.22)
    track.noise(0.047, 0.1, 0.31, 0.58)
    write("sfx_footstep_2", track.samples)

    track = Track(0.29, 16)
    track.noise(0, 0.15, 1.15, 0.51, 4, 0.0005, 0.25)
    track.tone(0, 0.16, 184, 50, 0.77, "pulse", 0.001)
    track.tone(0, 0.034, 1150, 520, 0.44, "bell", 0.0007)
    track.noise(0.087, 0.19, 0.22, 0.24)
    write("sfx_pistol_fire", track.samples)
    track = Track(0.47, 17)
    track.tone(0, 0.33, 115, 32, 0.96, "pulse", 0.001)
    track.noise(0, 0.36, 1.65, 0.44, 3.5, 0.001, 0.18)
    track.noise(0.012, 0.09, 0.7, 0.86, 4)
    track.noise(0.128, 0.32, 0.32, 0.16, 2)
    track.tone(0.265, 0.09, 640, 410, 0.16, "bell")
    write("sfx_shotgun_fire", track.samples)
    track = Track(0.28, 24)
    track.noise(0, 0.265, 0.91, 0.4, 2, 0.073, 0.57)
    track.tone(0.038, 0.2, 481, 1711, 0.21, "bell", 0.049)
    write("sfx_melee_slash", track.samples)

    track = Track(0.21, 25)
    track.tone(0, 0.17, 145, 47, 0.73, "pulse", 0.001)
    track.noise(0, 0.195, 1.0, 0.26, 3, 0.001, 0.26)
    write("sfx_enemy_hit", track.samples)
    track = Track(0.52, 26)
    for time, pitch, strength in [(0, 480, 0.55), (0.12, 680, 0.46), (0.31, 510, 0.75), (0.37, 790, 0.39)]:
        track.noise(time, 0.10, strength, 0.65, 4, 0.002, 0.53)
        track.tone(time, 0.09, pitch, pitch * 0.73, strength * 0.56, "bell", 0.001)
    write("sfx_reload", track.samples)
    track = Track(0.115, 27)
    track.noise(0, 0.069, 0.72, 0.79, 4, 0.001)
    track.tone(0, 0.084, 670, 410, 0.42, "bell", 0.001)
    track.noise(0.022, 0.08, 0.24, 0.7)
    write("sfx_empty_click", track.samples)

    track = Track(0.41, 28)
    track.tone(0, 0.38, 147, 55, 0.74, "pulse", 0.009)
    track.tone(0.018, 0.28, 360, 120, 0.32, "bell", 0.015)
    track.noise(0, 0.25, 0.6, 0.24, 2)
    write("sfx_player_hurt", track.samples)
    track = Track(0.47, 29)
    for time, pitch in [(0, 336), (0.103, 510)]:
        track.tone(time, 0.29, pitch, pitch * 1.45, 0.39, "pulse", 0.015)
        track.noise(time, 0.21, 0.47, 0.36, attack=0.015)
    write("sfx_enemy_alert", track.samples)
    track = Track(0.36, 30)
    track.tone(0, 0.16, 950, 1560, 0.33, "pulse", 0.029)
    track.tone(0.084, 0.235, 254, 53, 0.69, "pulse", 0.001)
    track.noise(0.084, 0.22, 0.86, 0.58, 3, 0.001, 0.25)
    write("sfx_enemy_attack", track.samples)
    track = Track(0.62, 31)
    track.tone(0, 0.48, 183, 42, 0.55, "pulse", 0.006)
    track.noise(0, 0.37, 0.77, 0.29, 2)
    track.tone(0.23, 0.35, 82, 34, 0.61)
    track.noise(0.23, 0.35, 0.69, 0.12, 2)
    write("sfx_enemy_die", track.samples)

    track = Track(0.8, 32)
    track.tone(0, 0.77, 58, 129, 0.57, "pulse", 0.095)
    track.noise(0, 0.77, 0.44, 0.29, 1.3, 0.08, 0.33)
    for index in range(6):
        pitch = 219 * 1.14 ** index
        track.tone(index * 0.083, 0.28, pitch, pitch * 1.9, 0.25, "bell", 0.017)
    write("sfx_beta_start", track.samples)
    track = Track(0.93, 33)
    track.tone(0, 0.64, 176, 45, 0.46, "pulse")
    track.noise(0, 0.52, 0.63, 0.38, 2, bright=0.2)
    for index, pitch in enumerate((330, 494, 660, 880)):
        track.tone(0.07 + index * 0.106, 0.51, pitch, pitch * 1.008, 0.31, "bell")
    write("sfx_beta_complete", track.samples)

    for name, duration, notes, seed in [
        ("puzzle_move", 0.12, [(0, 465, 496)], 34),
        ("puzzle_bar_pass", 0.24, [(0, 610, 633), (0.075, 840, 855)], 35),
        ("puzzle_fail", 0.42, [(0, 337, 269), (0.12, 222, 146)], 36),
        ("puzzle_success", 0.74, [(0, 440, 440), (0.08, 554, 554), (0.16, 659, 659), (0.24, 880, 880)], 37),
    ]:
        track = Track(duration, seed)
        for time, low, high in notes:
            track.tone(time, duration - time - 0.01, low, high, 0.39, "pulse")
        write(f"sfx_{name}", track.samples)

    track = Track(0.91, 38)
    track.noise(0, 0.85, 0.81, 0.32, 1.6, 0.038)
    track.tone(0.024, 0.78, 87, 52, 0.58, "pulse", 0.045)
    track.tone(0.59, 0.31, 441, 115, 0.34, "bell", 0.009)
    write("sfx_door_open", track.samples)
    track = Track(1.67, 39)
    for time in (0, 0.54, 1.08):
        track.tone(time, 0.56, 636, 934, 0.53, "pulse", 0.039)
        track.tone(time + 0.03, 0.52, 698, 1001, 0.29, "pulse", 0.055)
    write("sfx_alarm", track.samples)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def music(name, bpm, chords, mode):
    beat = 60 / bpm
    track = Track(32 * beat, 108 + mode, loop=True)
    for bar in range(8):
        start = bar * 4 * beat
        root, third, fifth, color = chords[bar // 2]
        for index, note in enumerate((root + 24, third + 24, fifth + 24, color + 24)):
            frequency = hz(note)
            gain = (0.085 if mode == 0 else 0.046) / (1 + index * 0.12)
            track.tone(start - 0.42 * beat, 5.1 * beat, frequency, frequency * 0.997, gain, "pulse", 0.67 * beat)
            track.tone(start - 0.23 * beat, 5.2 * beat, frequency * 1.004, frequency, gain * 0.48, "sine", 0.91 * beat)

        bass_steps = ((0, 3, 6), (0, 2, 3, 5, 6, 7), (0, 1, 3, 4, 6, 7))[mode]
        for step in bass_steps:
            time = start + step * beat / 2
            note = fifth - 12 if step == 7 and bar % 2 else root + (12 if step == 6 and mode == 2 else 0)
            frequency = hz(note)
            track.tone(time, beat * (1.64 if mode == 0 else 0.66), frequency * 1.006, frequency, (0.24, 0.29, 0.36)[mode], "pulse")
            if mode == 2:
                track.tone(time + 0.007, 0.24, frequency * 2.01, frequency * 2, 0.085, "bell")

        pattern = (root, fifth, color, third, fifth, root + 12, color, fifth)
        for step in range(8):
            if mode == 0 and (step + bar % 2) % 2:
                continue
            time = start + step * beat / 2
            frequency = hz(pattern[(step + (2 if bar % 2 else 0)) % 8] + (36 if mode != 2 else 24))
            track.tone(time, beat * 0.88, frequency, frequency * 0.999, (0.16, 0.19, 0.12)[mode], "bell")
            track.tone(time + beat * 0.75, beat * 1.18, frequency, frequency, 0.045, "bell", 0.009)

        for step in ((0, 2) if mode == 0 else (0, 1, 2, 3)):
            time = start + step * beat
            track.tone(time, 0.19, (80, 103, 119)[mode], 38, (0.31, 0.58, 0.69)[mode], attack=0.002)
        for step in ((3,) if mode == 0 else (1, 3)):
            time = start + step * beat
            track.noise(time, 0.17, (0.19, 0.40, 0.49)[mode], 0.33, 3, 0.002, 0.78)
            track.tone(time, 0.12, 203, 143, (0.07, 0.13, 0.19)[mode])
        for step in (1, 3, 5, 7):
            track.noise(start + step * beat / 2, 0.074, (0.085, 0.17, 0.22)[mode], 0.07, 4, 0.001, 1)
        if mode == 0 and bar % 2 == 1:
            for offset, note in ((0.0, fifth + 36), (1.5, color + 36), (2.5, third + 36)):
                frequency = hz(note)
                track.tone(start + offset * beat, 1.9 * beat, frequency * 0.992, frequency, 0.09, "bell", 0.1)
    write(name, track.samples, loop=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    effects()
    music("bgm_menu_cutscene", 120, [(38, 41, 45, 48), (34, 38, 41, 45), (33, 36, 40, 43), (36, 40, 43, 47)], 0)
    music("bgm_floor1_lobby", 132, [(38, 41, 45, 49), (41, 44, 48, 51), (36, 39, 43, 46), (37, 40, 44, 46)], 1)
    music("bgm_floor2_office", 144, [(35, 38, 42, 45), (32, 35, 39, 42), (34, 37, 40, 44), (33, 36, 40, 43)], 2)


if __name__ == "__main__":
    main()
