"""Synthesize the Phase 2 score and effects using the original PCM writer."""

import math

from generate_audio import OUT, TAU, Track, hz, write


def voice(track, start, duration, note, gain, attack, release, harmonics, drift=0):
    """Add a shaped oscillator whose tails can cross the loop boundary."""
    pitch = hz(note)

    def sample(t):
        envelope = min(1, t / attack, (duration - t) / release)
        phase = TAU * pitch * t + drift * math.sin(TAU * 3.7 * t)
        return gain * max(0, envelope) ** 1.5 * sum(
            level * math.sin(index * phase) for index, level in harmonics
        )

    track.add(start, duration, sample)


SINE = ((1, 1),)
PAD = ((1, 0.68), (2, 0.19), (3, 0.09), (5, 0.04))
BRASS = ((1, 0.51), (2, 0.23), (3, 0.12), (4, 0.08), (6, 0.06))
DRIVE = ((1, 0.62), (2, 0.15), (3, 0.13), (5, 0.07), (7, 0.03))


def bed(track, time, beat, notes, gain):
    for index, note in enumerate(notes):
        level = gain / (1 + 0.17 * index)
        voice(track, time - 0.52 * beat, 5.4 * beat, note, level, beat, 1.9 * beat, PAD, 0.12)
        voice(track, time - 0.23 * beat, 5.1 * beat, note + 0.09,
              level * 0.38, 1.3 * beat, 1.5 * beat, SINE, 0.08)


def kick(track, time, level, pitch=122):
    track.tone(time, 0.22, pitch, 41, level, attack=0.004)
    track.noise(time, 0.027, level * 0.24, 0.21, attack=0.002, bright=0.65)


def snare(track, time, level):
    track.noise(time, 0.18, level, 0.32, 3.4, 0.003, 0.79)
    track.tone(time, 0.115, 214, 131, level * 0.38, "bell", 0.002)


def lab(track, i, time, beat):
    root, third, fifth, tension = (
        (38, 53, 57, 63), (38, 53, 57, 60), (34, 53, 57, 64), (36, 51, 55, 62),
        (38, 53, 57, 63), (41, 56, 60, 67), (34, 53, 57, 63), (37, 52, 55, 61),
    )[i]
    bed(track, time, beat, (root + 12, third, fifth, tension), 0.058)
    for offset in (0, 1.5, 2.5):
        start = time + offset * beat
        voice(track, start, 1.25 * beat, root - 12, 0.29, 0.047, 0.39, SINE)
        voice(track, start + 0.025, 0.8 * beat, root, 0.08, 0.035, 0.31, PAD)
    sequence = (third, fifth, tension, third + 12, fifth, tension, fifth, third)
    for step, note in enumerate(sequence if i % 2 == 0 else sequence[2:] + sequence[:2]):
        start = time + step * beat / 2
        pitch = hz(note + 12)
        level = 0.22 if step % 3 == 0 else 0.13
        track.tone(start, 0.26, pitch, pitch * 0.997, level, "bell", 0.008)
        track.tone(start + 0.75 * beat, 0.42, pitch, pitch, level * 0.31, "bell", 0.019)
    kick(track, time, 0.36, 85)
    track.noise(time + 2.75 * beat, 0.36, 0.21, 0.14, 1.8, 0.08, 0.64)
    if i in (3, 7):
        track.tone(time + 3.0 * beat, 1.8 * beat, hz(tension + 12), hz(tension + 24),
                   0.09, "bell", 0.17)


def vip(track, i, time, beat):
    root, third, fifth, seven, ninth = (
        (36, 51, 55, 58, 62), (36, 51, 55, 58, 65), (34, 50, 53, 57, 60), (31, 50, 53, 59, 63),
        (36, 51, 55, 58, 62), (39, 55, 58, 62, 65), (32, 48, 51, 55, 58), (31, 50, 53, 59, 63),
    )[i]
    bed(track, time, beat, (third, seven, ninth), 0.038)
    bass = ((0, root), (0.75, root), (1.5, root + 7), (2, root + 12),
            (2.75, root + 7), (3.25, root), (3.75, root + (1 if i % 2 else 3)))
    for step, note in bass:
        length = 0.61 if step in (0, 2) else 0.41
        start = time + step * beat
        voice(track, start, length * beat, note, 0.39, 0.012, 0.16, DRIVE, 0.22)
    stabs = (0.5, 2.5, 3.25) if i % 2 == 0 else (1.25, 2.75)
    for step in stabs:
        start = time + step * beat
        for note in (third + 12, fifth + 12, seven + 12, ninth + 12):
            voice(track, start, beat * 0.48, note, 0.083, 0.026, 0.14, BRASS, 0.14)
        track.noise(start, 0.077, 0.075, 0.18, attack=0.009, bright=0.44)
    for step in (0, 1.75, 2.5):
        kick(track, time + step * beat, 0.48, 101)
    for step in (1, 3):
        snare(track, time + step * beat, 0.36)
    for step in (0.5, 1.56, 2.5, 3.56):
        track.noise(time + step * beat, 0.071, 0.11, 0.08, bright=0.9)


def boss(track, i, time, beat):
    root = (33, 33, 29, 31, 33, 36, 29, 28)[i]
    bed(track, time, beat, (root + 12, root + 19, root + 24, root + 31), 0.047)
    riff = (0, 0, 12, 0, 0, 7, 0, 10, 0, 0, 12, 7, 0, 0, 3, 6 if i % 2 else 7)
    for step, interval in enumerate(riff):
        start = time + step * beat / 4
        level = 0.34 if step % 4 == 0 else 0.26
        voice(track, start, beat * 0.24, root + interval, level, 0.007, 0.07, DRIVE, 0.19)
        voice(track, start, beat * 0.22, root + interval + 12, level * 0.39, 0.008, 0.067, BRASS)
    motif = ((0, 19), (0.75, 24), (1.5, 22), (2.5, 19), (3.25, 18))
    if i >= 4:
        motif = ((0, 24), (0.75, 27), (1.5, 26), (2, 24), (3.25, 19))
    for step, interval in motif:
        start = time + step * beat
        voice(track, start, beat * 0.66, root + interval + 12, 0.16, 0.019, 0.14, BRASS, 0.34)
        voice(track, start + 0.375 * beat, beat * 0.69, root + interval + 12,
              0.048, 0.023, 0.19, PAD, 0.16)
    for step in range(4):
        kick(track, time + step * beat, 0.62, 146)
        track.noise(time + (step + 0.5) * beat, 0.094, 0.20, 0.09, 4, bright=1)
    for step in (1, 3):
        snare(track, time + step * beat, 0.47)
    if i % 2:
        for step in (3.25, 3.5, 3.75):
            start = time + step * beat
            track.tone(start, 0.105, 550, 152, 0.18, "bell", 0.003)
            track.noise(start, 0.09, 0.19, 0.49, bright=0.61)


def ending(track, i, time, beat):
    chord = (
        (45, 52, 57, 60, 64), (41, 53, 57, 60, 64), (48, 52, 55, 60, 67), (43, 50, 55, 59, 62),
        (45, 52, 57, 60, 64), (41, 53, 57, 60, 67), (48, 52, 55, 60, 64), (43, 52, 55, 60, 62),
    )[i]
    bed(track, time, beat, chord, 0.195)
    voice(track, time - 0.32 * beat, 5.0 * beat, chord[0] - 12, 0.15, 0.53, 0.76, SINE)
    motifs = ((0.5, 72, 1.9), (2.75, 76, 1.45)), ((0.75, 74, 1.45), (2.5, 72, 2))
    for offset, note, length in motifs[i % 2]:
        start = time + offset * beat
        pitch = hz(note + (5 if i in (4, 5) else 0))
        track.tone(start, length * beat, pitch, pitch * 1.001, 0.17, "bell", 0.085)
        track.tone(start + 0.75 * beat, length * beat, pitch, pitch, 0.055, "bell", 0.105)
    if i in (2, 6):
        voice(track, time, 3.9 * beat, 79, 0.074, 0.39, 0.74, PAD, 0.22)


def music():
    for name, bpm, arrangement, seed in (
        ("bgm_floor3_lab", 126, lab, 312),
        ("bgm_floor4_vip", 132, vip, 413),
        ("bgm_floor5_boss", 145, boss, 514),
        ("bgm_ending", 128, ending, 615),
    ):
        beat = 60 / bpm
        track = Track(32 * beat, seed, loop=True)
        for bar in range(8):
            arrangement(track, bar, bar * 4 * beat, beat)
        write(name, track.samples, loop=True)


def effects():
    charge = Track(1.12, 173)
    charge.tone(0, 1.10, 42, 182, 0.66, "pulse", 0.53)
    charge.tone(0.08, 1.02, 133, 1340, 0.52, "bell", 0.38)
    charge.noise(0.16, 0.92, 0.63, 0.33, 1.2, 0.42, 0.45)
    for offset, pitch in ((0.19, 415), (0.43, 554), (0.61, 740), (0.75, 988), (0.86, 1480)):
        charge.tone(offset, 0.24, pitch, pitch * 1.23, 0.31, "pulse", 0.018)
    write("sfx_boss_charge", charge.samples)

    slam = Track(0.88, 174)
    slam.tone(0, 0.67, 167, 29, 1.12, "pulse", 0.003)
    slam.noise(0, 0.77, 0.94, 0.31, 2.2, 0.002, 0.32)
    slam.tone(0.006, 0.14, 1330, 343, 0.42, "bell", 0.002)
    slam.tone(0.099, 0.65, 82, 35, 0.62, attack=0.01)
    for offset, pitch in ((0.13, 680), (0.22, 480), (0.34, 295)):
        slam.tone(offset, 0.36, pitch, pitch * 0.56, 0.14, "bell")
    write("sfx_boss_slam", slam.samples)

    phase = Track(1.35, 175)
    phase.noise(0.07, 1.23, 0.69, 0.41, 1.3, 0.14, 0.56)
    for index, pitch in enumerate((83, 117, 166, 233, 330, 466, 660)):
        phase.tone(index * 0.094, 0.52, pitch, pitch * 1.48, 0.46, "pulse", 0.02)
    phase.tone(0.69, 0.61, 120, 34, 0.81, "pulse", 0.006)
    phase.tone(0.72, 0.53, 1720, 510, 0.33, "bell", 0.012)
    write("sfx_boss_phase", phase.samples)

    shutdown = Track(1.7, 176)
    shutdown.tone(0, 1.48, 143, 30, 0.68, "pulse", 0.026)
    shutdown.tone(0.04, 1.23, 532, 41, 0.35, "bell", 0.029)
    shutdown.noise(0, 1.46, 0.45, 0.15, 1.25, 0.05, 0.18)
    for offset, pitch in ((0.39, 660), (0.57, 550), (0.87, 440)):
        shutdown.tone(offset, 0.74, pitch, pitch * 0.997, 0.33, "bell", 0.016)
    shutdown.noise(1.22, 0.21, 0.47, 0.46, 2.5, 0.003, 0.43)
    shutdown.tone(1.22, 0.44, 87, 36, 0.25, attack=0.004)
    write("sfx_reactor_shutdown", shutdown.samples)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    music()
    effects()


if __name__ == "__main__":
    main()
