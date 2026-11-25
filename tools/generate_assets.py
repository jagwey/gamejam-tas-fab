"""Draw deterministic, hard-edged sprite art for BETA PROTOCOL with Pillow."""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw


ASSETS = Path(__file__).resolve().parents[1] / "assets"
INK = "#0b0a13"
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


class Art:
    def __init__(self, size, bg=(0, 0, 0, 0), *, density=1):
        self.logical_size = size
        self.density = density
        self.image = Image.new("RGBA", tuple(round(v * density) for v in size), bg)
        self.draw = ImageDraw.Draw(self.image)

    def native(self):
        view = Art.__new__(Art)
        view.logical_size = self.image.size
        view.density = 1
        view.image = self.image
        view.draw = self.draw
        return view

    def point_at(self, point):
        if self.density == 1:
            return (round(point[0]), round(point[1]))
        sx = (self.image.width - 1) / (self.logical_size[0] - 1)
        sy = (self.image.height - 1) / (self.logical_size[1] - 1)
        return (round(point[0] * sx), round(point[1] * sy))

    def point(self, point, *, fill):
        x, y = self.point_at(point)
        if self.density == 1:
            self.draw.point((x, y), fill=fill)
        else:
            span = max(1, round(self.density * 0.7))
            x1 = min(self.image.width - 1, x + span - 1)
            y1 = min(self.image.height - 1, y + span - 1)
            self.draw.rectangle((x, y, x1, y1), fill=fill)

    def p(self, color, *points, outline=None):
        self.draw.polygon(tuple(map(self.point_at, points)), fill=color, outline=outline)

    def l(self, color, *points, width=1):
        self.draw.line(tuple(map(self.point_at, points)), fill=color, width=max(1, round(width * self.density)))

    def r(self, color, x0, y0, x1, y1, outline=None):
        px0, py0 = self.point_at((x0, y0))
        px1, py1 = self.point_at((x1, y1))
        if self.density != 1:
            span = max(1, round(self.density)) - 1
            if px1 - px0 < span:
                px1 = min(self.image.width - 1, px0 + span)
            if py1 - py0 < span:
                py1 = min(self.image.height - 1, py0 + span)
        self.draw.rectangle((px0, py0, px1, py1), fill=color, outline=outline)

    def e(self, color, x0, y0, x1, y1):
        self.draw.ellipse((*self.point_at((x0, y0)), *self.point_at((x1, y1))), fill=color)

    def dither(self, color, strength, *points):
        mask = Image.new("1", self.image.size)
        ImageDraw.Draw(mask).polygon(tuple(map(self.point_at, points)), fill=1)
        x0, y0, x1, y1 = mask.getbbox() or (0, 0, 0, 0)
        for y in range(y0, y1):
            for x in range(x0, x1):
                if BAYER[y % 4][x % 4] < strength and mask.getpixel((x, y)):
                    self.draw.point((x, y), fill=color)

    def save(self, folder, name, opaque=False):
        destination = ASSETS / folder / f"{name}.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        image = self.image
        if opaque:
            image = image.convert("RGB")
        image.save(destination, optimize=True)


def gradient(a, top, bottom):
    width, height = a.image.size
    pixels = a.image.load()
    bands = 24 if width >= 240 else 18
    for y in range(height):
        level = y * bands / (height - 1)
        row_bayer = BAYER[y % 4]
        for x in range(width):
            t = min(bands, math.floor(level + row_bayer[x % 4] / 16)) / bands
            pixels[x, y] = (
                round(top[0] + (bottom[0] - top[0]) * t),
                round(top[1] + (bottom[1] - top[1]) * t),
                round(top[2] + (bottom[2] - top[2]) * t),
                255,
            )


def crest(a, x, y, color, size=1):
    points = [(-10, -6), (-5, -3), (-2, -3), (-2, -5), (0, -7), (3, -6), (1, -3),
              (4, -3), (10, -6), (8, -1), (5, 2), (2, 2), (3, 5), (0, 4), (-3, 5), (-2, 2), (-5, 2), (-8, -1)]
    a.p(color, *((x + u * size, y + v * size) for u, v in points))


def aydin(tactical):
    a = Art((64, 64), density=2.5)
    gradient(a, (33, 8, 18) if tactical else (35, 40, 54), (91, 17, 35) if tactical else (113, 73, 66))
    stripe = "#961d38" if tactical else "#926358"
    a.dither(stripe, 4, (0, 39), (59, 3), (64, 3), (64, 21), (0, 57))
    a.l(stripe, (2, 47), (62, 11))
    a.l(stripe, (20, 63), (62, 39))
    rim = "#ed2b52" if tactical else "#cb8b71"
    a.p(rim, (0, 62), (6, 54), (17, 48), (20, 39), (18, 32), (13, 24), (16, 19), (13, 17), (23, 12),
        (21, 8), (31, 10), (36, 3), (39, 10), (47, 6), (48, 13), (54, 13), (52, 18), (58, 21), (54, 25),
        (54, 35), (50, 42), (47, 49), (58, 50), (60, 54), (63, 55), (63, 63), (0, 63))
    a.p(INK, (0, 63), (8, 55), (19, 49), (22, 38), (19, 31), (15, 24), (19, 18), (16, 17), (25, 13),
        (24, 10), (31, 12), (36, 5), (38, 12), (46, 8), (47, 15), (52, 14), (50, 19), (56, 22), (52, 26),
        (52, 35), (48, 42), (45, 50), (57, 51), (58, 55), (63, 57), (63, 63))
    a.p("#282531" if tactical else "#373d4b", (0, 63), (9, 56), (22, 50), (28, 51), (35, 58), (44, 50), (53, 51), (63, 59), (63, 63))
    a.p("#41313d" if tactical else "#526175", (0, 63), (11, 57), (21, 53), (25, 54), (20, 57), (13, 58), (8, 63))
    a.p("#824449", (27, 41), (41, 43), (43, 51), (35, 59), (29, 55), (26, 50))
    a.p("#c38176", (36, 48), (42, 46), (41, 51), (35, 57), (33, 54))
    if tactical:
        a.p(INK, (8, 58), (19, 47), (27, 46), (32, 58), (35, 63), (14, 63))
        a.p("#332a36", (12, 58), (20, 49), (26, 48), (29, 54), (23, 53), (21, 60))
        a.p(INK, (37, 63), (44, 48), (55, 48), (53, 55), (50, 57), (52, 63))
        a.l("#844453", (44, 49), (53, 49), (50, 54))
    else:
        a.p("#aea49a", (24, 49), (31, 55), (35, 58), (31, 63), (25, 61), (21, 53), outline=INK)
        a.p("#d1b6a0", (43, 49), (47, 52), (45, 61), (39, 63), (36, 58), outline=INK)
        a.l("#656071", (34, 60), (36, 63))

    a.p("#825565" if tactical else "#a06562", (25, 23), (35, 17), (45, 19), (51, 23), (51, 33), (47, 42),
        (44, 47), (39, 49), (32, 45), (27, 42), (23, 42), (20, 38), (20, 33), (23, 32), (25, 35))
    a.p("#ddada5" if tactical else "#e2a582", (33, 20), (44, 19), (50, 23), (49, 29), (47, 36), (48, 39), (44, 46),
        (40, 48), (36, 45), (35, 41), (37, 38), (32, 36), (29, 31))
    a.p("#f5c9ad", (34, 22), (45, 21), (47, 24), (43, 25), (38, 24), (32, 26))
    a.p("#563745", (29, 29), (33, 34), (34, 40), (37, 44), (32, 44), (28, 41), (26, 34))
    a.dither("#ba827b", 6, (29, 35), (35, 38), (36, 43), (31, 42))
    a.l("#5a3742", (23, 34), (22, 36), (24, 39), (25, 38))
    a.p("#653c48", (43, 30), (42, 34), (40, 37), (43, 39), (46, 37), (44, 36))
    a.p("#fbe0bf", (44, 32), (46, 37), (43, 37))
    a.l("#4d2936", (37, 42), (40, 41), (44, 41), (46, 42))
    a.l("#ad6c6c", (40, 44), (43, 44))
    if tactical:
        a.p(INK, (23, 28), (27, 23), (52, 26), (53, 30), (50, 36), (45, 35), (43, 33), (40, 33), (38, 35), (28, 34), (26, 30))
        a.p("#a90b31", (28, 25), (51, 28), (50, 34), (46, 33), (43, 31), (40, 31), (38, 33), (29, 32))
        a.p("#fb234c", (28, 25), (51, 28), (50, 30), (30, 29))
        a.l("#ff9d9c", (29, 25), (35, 26), (40, 26))
        a.dither("#fd4364", 7, (29, 28), (49, 29), (50, 33), (37, 31), (29, 32))
        a.r("#ff8b91", 49, 29, 50, 30)
    else:
        a.p(INK, (28, 26), (32, 25), (40, 28), (39, 30), (34, 29), (31, 28))
        a.p(INK, (44, 28), (48, 25), (51, 25), (51, 28), (47, 28), (44, 30))
        a.p("#f7d8bf", (31, 29), (39, 30), (36, 32), (32, 31))
        a.p("#f7d8bf", (45, 30), (50, 28), (49, 31), (46, 32))
        a.r("#4c5158", 35, 29, 36, 31)
        a.r("#4c5158", 47, 29, 48, 31)
        a.point((36, 29), fill="#fff4d5")

    a.p(INK, (18, 24), (23, 16), (26, 16), (25, 12), (32, 14), (36, 6), (38, 14), (46, 9), (45, 16),
        (51, 15), (49, 19), (54, 22), (49, 24), (46, 21), (42, 21), (39, 24), (38, 20), (33, 21),
        (29, 24), (27, 28), (22, 31), (22, 25), (19, 27))
    a.p("#272531", (20, 23), (25, 17), (29, 16), (32, 17), (36, 9), (36, 16), (33, 19), (27, 19), (23, 23))
    a.p("#544653", (38, 16), (44, 11), (43, 15), (40, 18), (36, 20))
    a.l("#7c6065", (28, 17), (33, 16), (35, 13))
    a.save("portraits", "aydin_visor" if tactical else "aydin_village", opaque=True)


def general():
    a = Art((64, 64), density=2.5)
    gradient(a, (26, 28, 39), (100, 48, 49))
    a.dither("#653844", 5, (0, 23), (62, 6), (62, 27), (0, 47))
    a.l("#8e5656", (0, 41), (63, 20))
    a.p("#9d5b63", (0, 62), (8, 53), (19, 47), (18, 37), (14, 30), (11, 21), (13, 15), (21, 9), (30, 6),
        (44, 7), (52, 13), (54, 21), (51, 32), (52, 42), (48, 48), (54, 51), (63, 60), (63, 63), (0, 63))
    a.p(INK, (0, 63), (10, 54), (23, 49), (22, 43), (17, 36), (13, 27), (12, 21), (15, 15), (24, 9),
        (32, 7), (43, 8), (51, 14), (53, 22), (49, 32), (51, 42), (46, 50), (53, 53), (63, 62), (63, 63))
    a.p("#47424a", (0, 63), (13, 55), (26, 51), (35, 54), (46, 51), (54, 55), (62, 63))
    a.p("#796271", (5, 63), (16, 56), (26, 53), (30, 56), (23, 58), (17, 63))
    a.p("#201c26", (25, 47), (34, 53), (42, 51), (49, 47), (51, 52), (44, 61), (34, 63), (23, 57), outline=INK)
    a.l("#9e724f", (10, 61), (19, 57), (22, 57), width=2)
    a.l("#b5845d", (50, 55), (56, 59), (58, 62), width=2)
    a.p("#9f625d", (20, 23), (32, 17), (46, 18), (49, 25), (48, 33), (50, 37), (47, 46), (43, 51), (36, 53),
        (28, 49), (24, 44), (21, 43), (18, 39), (18, 34), (21, 32), outline=INK)
    a.p("#d89978", (29, 22), (45, 19), (48, 24), (46, 30), (47, 34), (48, 40), (43, 42), (37, 38), (29, 41), (26, 34))
    a.dither("#b07569", 6, (24, 29), (35, 28), (32, 38), (29, 41), (24, 36))
    a.l("#633e47", (32, 24), (38, 23), (45, 23))
    a.l("#a66058", (33, 26), (37, 25), (40, 25))
    a.p(INK, (26, 30), (30, 27), (36, 27), (40, 30), (37, 32), (31, 31))
    a.p(INK, (42, 29), (47, 26), (49, 27), (49, 30), (46, 30), (42, 32))
    a.l("#e4b598", (31, 30), (36, 30))
    a.l("#e4b598", (44, 30), (47, 29))
    a.point((35, 30), fill=INK)
    a.point((46, 30), fill=INK)
    a.p("#70434b", (41, 30), (39, 35), (38, 37), (43, 39), (46, 37), (44, 35))
    a.l("#f8c39b", (42, 31), (44, 37))
    a.l("#69424b", (21, 34), (20, 36), (22, 40), (23, 38))
    a.p("#645460", (23, 32), (26, 35), (27, 40), (34, 42), (37, 39), (44, 39), (48, 41), (49, 36), (50, 43),
        (46, 50), (42, 52), (37, 54), (30, 50), (26, 47), (24, 40), outline=INK)
    a.p("#a38781", (26, 41), (34, 44), (36, 42), (43, 41), (47, 43), (46, 47), (40, 51), (34, 50), (29, 46))
    a.l("#c4a598", (33, 45), (35, 49), (38, 51))
    a.l("#c4a598", (45, 45), (43, 49), (41, 50))
    a.p("#271923", (33, 44), (37, 42), (43, 42), (46, 44), (42, 44), (38, 44), (36, 45))
    a.dither("#3d3746", 7, (25, 42), (34, 46), (40, 52), (35, 52), (29, 49))
    a.p("#5d203b", (13, 23), (14, 17), (23, 11), (31, 8), (42, 9), (48, 12), (52, 18), (52, 23), (44, 21),
        (35, 21), (27, 25), (19, 30), (15, 28), outline=INK)
    a.p("#923750", (15, 20), (22, 14), (31, 10), (42, 10), (47, 13), (39, 12), (29, 14), (21, 17), (17, 22))
    a.l("#27101f", (16, 27), (27, 22), (36, 19), (50, 20), width=2)
    crest(a, 44, 16, "#d4a16c", 0.32)
    a.save("portraits", "general_portrait", opaque=True)


def volkov():
    a = Art((64, 64), density=2.5)
    gradient(a, (12, 17, 29), (76, 19, 39))
    a.p("#54223b", (0, 51), (64, 12), (64, 26), (0, 60))
    a.dither("#a53552", 4, (0, 51), (64, 12), (64, 23), (0, 62))
    a.l("#63233e", (0, 30), (51, 0))
    a.p("#b63456", (0, 62), (7, 53), (18, 48), (15, 36), (22, 37), (21, 25), (21, 17), (27, 10), (34, 8),
        (43, 9), (49, 13), (53, 21), (51, 32), (47, 42), (53, 36), (60, 35), (54, 48), (63, 54), (63, 63), (0, 63))
    a.p(INK, (0, 63), (9, 54), (21, 49), (17, 38), (24, 39), (22, 25), (22, 18), (29, 11), (35, 9), (42, 10),
        (48, 14), (51, 21), (50, 32), (45, 44), (54, 38), (58, 37), (52, 49), (63, 56), (63, 63))
    a.p("#292834", (22, 20), (28, 13), (35, 10), (43, 12), (48, 16), (49, 20), (41, 18), (36, 15), (28, 19), (24, 25))
    a.l("#524353", (25, 18), (32, 13), (40, 13))
    a.p("#251d2d", (26, 24), (33, 21), (41, 22), (47, 24), (47, 32), (43, 40), (38, 45), (31, 42), (27, 35))
    a.p("#3d293a", (37, 24), (44, 25), (42, 33), (40, 35), (44, 36), (40, 41), (36, 39), (38, 34), (35, 31))
    a.l("#665060", (39, 29), (38, 34), (41, 35))
    a.p("#7b1838", (26, 26), (34, 27), (36, 31), (30, 31), (27, 30))
    a.p("#7b1838", (40, 28), (48, 25), (47, 30), (42, 32), (40, 31))
    a.l("#ff3752", (28, 28), (33, 29), (34, 30), width=2)
    a.l("#ff3752", (41, 30), (46, 28), width=2)
    a.l("#ffc0a8", (30, 29), (32, 29))
    a.l("#ffc0a8", (43, 29), (45, 28))
    a.p("#222636", (2, 63), (12, 55), (21, 52), (29, 56), (35, 62), (43, 54), (52, 51), (63, 58), (63, 63))
    a.p("#393246", (18, 39), (25, 41), (31, 49), (34, 58), (30, 61), (23, 52))
    a.p("#383245", (38, 59), (43, 47), (54, 39), (56, 39), (52, 49), (46, 57))
    a.l("#945165", (41, 54), (47, 46), (54, 41))
    a.l("#82465d", (19, 40), (24, 43), (29, 49))
    crest(a, 50, 57, "#a72b4e", 0.53)
    crest(a, 50, 56, "#ff4963", 0.42)
    a.save("portraits", "volkov_silhouette", opaque=True)


def helix(a, x, y, width, height, phase=0):
    strands = [[], []]
    for row in range(height + 1):
        t = row / height
        wave = round(width * math.sin(t * math.tau * 1.27 + phase))
        for strand, offset in zip(strands, (wave, -wave)):
            strand.append((x + offset, y + row))
        if row % 4 == 2:
            a.l("#ff596f", (x - abs(wave), y + row), (x + abs(wave), y + row))
    a.l("#ef254d", *strands[1], width=2)
    a.l("#ffbaa9", *strands[0])


def device():
    a = Art((160, 90), density=3)
    gradient(a, (20, 24, 39), (64, 25, 43))
    for index in range(0, 160, 9):
        a.l("#372a3a", (index, 0), (index - 35, 90))
    a.p("#55293d", (0, 65), (39, 53), (134, 53), (159, 75), (159, 89), (0, 89))
    a.dither("#8d374c", 4, (0, 68), (29, 55), (142, 56), (159, 78), (159, 89), (0, 89))
    a.p("#8e3751", (23, 83), (32, 64), (44, 56), (46, 34), (56, 25), (61, 13), (72, 6), (94, 6), (106, 12),
        (115, 24), (121, 37), (126, 64), (140, 72), (149, 89), (19, 89))
    a.p(INK, (23, 89), (34, 65), (47, 58), (48, 36), (59, 26), (62, 16), (73, 8), (93, 8), (104, 14),
        (114, 26), (119, 39), (123, 66), (137, 74), (146, 89))
    a.p("#364157", (26, 89), (37, 67), (50, 61), (59, 63), (64, 74), (106, 74), (119, 65), (134, 76), (143, 89))
    a.p("#191f30", (35, 89), (42, 73), (53, 68), (60, 80), (111, 80), (120, 73), (133, 85), (135, 89))
    a.l("#788293", (37, 69), (50, 63), (57, 65))
    a.l("#b94a5c", (119, 67), (133, 77), (138, 87), width=2)
    a.p("#3c4155", (50, 60), (51, 37), (61, 29), (66, 17), (75, 11), (93, 11), (102, 16), (111, 29), (116, 40),
        (121, 64), (110, 76), (62, 76), outline=INK)
    a.p("#565d72", (58, 30), (67, 18), (74, 12), (93, 12), (100, 16), (102, 19), (90, 16), (76, 16), (67, 22), (65, 29))
    a.p("#191727", (63, 64), (61, 38), (65, 28), (74, 22), (93, 22), (104, 29), (108, 39), (108, 66), (100, 72), (69, 72), outline=INK)
    a.p("#a20c38", (66, 62), (65, 38), (70, 29), (77, 26), (91, 26), (100, 31), (104, 39), (104, 63), (98, 68), (72, 68))
    a.p("#d11946", (69, 59), (68, 39), (73, 32), (78, 29), (91, 29), (98, 33), (101, 41), (101, 60), (96, 65), (74, 65))
    a.p("#751132", (75, 60), (73, 41), (78, 34), (91, 34), (96, 41), (96, 58), (91, 62), (80, 63))
    a.dither("#ff5470", 7, (68, 47), (75, 40), (93, 42), (101, 49), (101, 60), (94, 65), (74, 65), (69, 60))
    a.l("#ff7687", (70, 58), (69, 39), (74, 32), (78, 31), width=2)
    a.l("#ffd3af", (72, 39), (75, 34), (80, 32))
    a.l("#ff6c83", (99, 38), (101, 43), (101, 55))
    helix(a, 85, 33, 9, 27, 0.45)
    for x, y in ((76, 41), (93, 40), (80, 46), (89, 52), (75, 56), (96, 56)):
        a.r("#ff9d8f", x, y, x + 1, y)
    for x, y in ((53, 39), (54, 47), (56, 57), (111, 40), (113, 49), (115, 58)):
        a.r("#171523", x, y, x + 5, y + 3)
        a.l("#fc4e69", (x + 1, y + 1), (x + 3, y + 1))
    for x in (65, 71, 95, 101):
        a.l("#747082", (x, 72), (x + 2, 74))

    # Crisp 480x270 OVA mechanical & biotech closeup details.
    hi = a.native()
    # Etched titanium seam lines and hex bolts on outer housing.
    hi.l("#161a29", (164, 108), (198, 76), (222, 46), (282, 46), (312, 74), (342, 114))
    hi.l("#8d97ac", (166, 107), (199, 77), (223, 48), (281, 48))
    hi.l("#22283a", (110, 210), (156, 196), (186, 224), (318, 224), (358, 198), (402, 226))
    for bx, by in ((170, 96), (206, 54), (298, 54), (336, 98), (186, 214), (322, 214), (132, 232), (382, 236)):
        hi.r("#111320", bx - 3, by - 3, bx + 3, by + 3)
        hi.r("#68728a", bx - 2, by - 2, bx + 1, by + 1)
        hi.point((bx - 1, by - 1), fill="#cdd4df")
    # Crisp glass reflection curves and fluid micro-spores inside the bio-core.
    hi.l("#ff9eaa", (214, 174), (212, 118), (225, 96), (242, 88), width=2)
    hi.l("#ffe9cf", (216, 152), (216, 120), (228, 99), (240, 92))
    hi.l("#ff8498", (298, 112), (305, 132), (304, 172))
    for sx, sy, sr in ((228, 118, 2), (274, 112, 2), (242, 146, 3), (268, 158, 2),
                       (230, 172, 2), (284, 170, 2), (256, 102, 1), (248, 184, 2)):
        hi.e("#ff7084", sx - sr, sy - sr, sx + sr, sy + sr)
        hi.point((sx - 1, sy - 1), fill="#fff1d8")
    # Precision telemetry ticks & crimson status indicators on side pods.
    for row_y in (122, 146, 174):
        hi.l("#ff909e", (162, row_y), (171, row_y))
        hi.l("#ff909e", (338, row_y + 2), (347, row_y + 2))
    for tx in range(202, 306, 8):
        hi.l("#8d8b9e" if tx % 16 else "#ff5c78", (tx, 218), (tx, 224))
    a.save("portraits", "beta_device_closeup", opaque=True)


def village():
    a = Art((160, 90), density=3)
    rng = random.Random(922)
    gradient(a, (24, 33, 63), (112, 109, 144))
    a.e("#dfd3c5", 84, 15, 96, 27)
    a.e("#2c375d", 89, 12, 98, 24)
    a.p("#525779", (0, 52), (18, 42), (30, 38), (43, 30), (49, 32), (57, 29), (72, 36), (83, 41),
        (105, 32), (119, 28), (133, 39), (159, 47), (159, 73), (0, 73))
    a.p("#777e9f", (33, 37), (43, 30), (49, 32), (57, 29), (68, 35), (57, 34), (53, 36), (48, 34), (40, 38))
    a.p("#626587", (89, 39), (105, 32), (119, 28), (133, 39), (120, 34), (111, 32), (101, 37))
    a.p("#3b4969", (0, 52), (18, 42), (33, 44), (53, 53), (69, 55), (96, 46), (111, 42), (132, 45), (159, 53), (159, 76), (0, 76))
    a.p("#282f4e", (0, 61), (27, 52), (47, 59), (67, 61), (100, 51), (121, 54), (159, 49), (159, 84), (0, 80))
    a.dither("#536080", 4, (20, 54), (45, 58), (72, 61), (107, 53), (133, 56), (107, 68), (52, 67))
    for x, y, w in ((48, 61, 6), (60, 62, 8), (76, 59, 9), (89, 59, 8), (96, 64, 6), (68, 66, 7)):
        a.p("#1d263c", (x, y + 2), (x + w // 2, y - 3), (x + w, y + 2), (x + w - 1, y + 6), (x + 1, y + 6))
        a.l("#66617d", (x, y + 2), (x + w // 2, y - 3), (x + w, y + 2))
        a.point((x + 3, y + 3), fill="#f5ad6f")
    a.p("#171928", (0, 0), (159, 0), (159, 10), (95, 8), (40, 14), (22, 20), (0, 19))
    a.p("#463039", (0, 8), (47, 7), (97, 5), (158, 5), (159, 9), (95, 9), (40, 15), (19, 20), (0, 18))
    a.l("#8a5650", (9, 15), (42, 12), (96, 7), (152, 7))
    a.p("#151827", (0, 14), (26, 17), (24, 73), (14, 89), (0, 89))
    a.p("#44313c", (0, 17), (19, 21), (17, 69), (1, 80))
    for band in range(23, 80, 7):
        a.l("#282231", (0, band), (17, band - 3))
        a.l("#6f4243", (1, band + 1), (9, band - 1))
        a.l("#262231", (5 + band % 9, band - 2), (5 + band % 9, band + 3))
    a.p("#632d36", (18, 20), (23, 17), (26, 19), (24, 77), (19, 82), (17, 80))
    a.l("#b77158", (24, 21), (22, 73))
    a.p("#191a28", (118, 10), (126, 8), (130, 11), (131, 78), (127, 83), (119, 78))
    a.p("#53404c", (124, 11), (128, 12), (129, 77), (125, 80), (124, 52))
    a.l("#956859", (124, 15), (126, 68))
    a.p("#1d1c2c", (0, 82), (29, 69), (114, 68), (159, 73), (159, 89), (0, 89))
    a.p("#63464a", (1, 87), (31, 72), (110, 72), (157, 80), (159, 89), (0, 89))
    for x in range(26, 155, 15):
        a.l("#322630", (x, 74), (x + (x - 70) // 2, 90))
    a.l("#a46a54", (14, 83), (44, 79), (63, 79))
    a.p("#292332", (123, 56), (159, 52), (159, 59), (124, 61))
    a.l("#774f53", (130, 56), (158, 53))
    a.r("#272334", 143, 58, 147, 75)
    a.dither("#bd7353", 4, (0, 26), (8, 21), (29, 22), (48, 37), (41, 49), (15, 58), (0, 52))
    a.l("#291c25", (23, 18), (37, 18), (39, 25), width=2)
    a.p("#3a2530", (34, 27), (38, 24), (44, 26), (45, 31), (46, 42), (44, 44), (35, 44), (32, 41), (33, 32))
    a.p("#cf7856", (35, 32), (44, 31), (44, 41), (35, 41), outline="#8e483e")
    a.r("#ffd491", 37, 33, 42, 40)
    a.r("#fff3bd", 39, 35, 40, 40)
    a.l("#623b3b", (35, 42), (44, 42), width=2)

    # Crisp 480x270 OVA nocturnal village details.
    hi = a.native()
    # Starfield kept cleanly within the open night sky window.
    for _ in range(72):
        sx, sy = rng.randrange(146, 350), rng.randrange(36, 98)
        if 246 <= sx <= 300 and 34 <= sy <= 86:
            continue
        color = rng.choice(("#7d83ab", "#a8aac7", "#e0d6c5", "#fff3db"))
        hi.point((sx, sy), fill=color)
        if color == "#fff3db":
            hi.l("#9fa3c4", (sx - 2, sy), (sx + 2, sy))
            hi.l("#9fa3c4", (sx, sy - 2), (sx, sy + 2))
    hi.draw.arc((253, 45, 289, 81), 115, 265, fill="#f7eedd", width=2)
    # Distant Anatolian pine silhouettes along the mid ridge.
    for px in range(86, 350, 9):
        py = 166 + round(10 * math.sin(px * 0.04))
        ph = 7 + (px * 7) % 10
        hi.p("#1c243d", (px, py - ph), (px - 3, py), (px + 3, py))
    # Crisp cottage chimney smoke wisps & warm window glows.
    for cx, cy in ((153, 186), (192, 189), (242, 180), (279, 180), (298, 195), (214, 201)):
        hi.r("#ffe09c", cx, cy, cx + 4, cy + 4)
        hi.point((cx + 1, cy + 1), fill="#fff7d6")
        hi.l("#596283", (cx + 2, cy - 11), (cx + 5, cy - 19), (cx + 3, cy - 26))
    # Fine porch post highlights, deck plank joints, lantern cage bars & warm moths.
    hi.l("#c88664", (72, 62), (66, 214))
    hi.l("#b38470", (374, 44), (379, 206))
    for py in range(226, 268, 8):
        hi.l("#43313b", (18, py), (464, py + 4))
    hi.l("#4d2c33", (118, 95), (118, 126))
    hi.l("#4d2c33", (125, 95), (125, 126))
    hi.l("#ffe3a8", (112, 99), (112, 120))
    for mx, my in ((96, 108), (144, 102), (138, 134), (104, 140), (154, 118)):
        hi.r("#ffcf87", mx, my, mx + 1, my + 1)
    a.save("sprites/cutscenes", "bg_village_house", opaque=True)


def tower():
    a = Art((160, 90), density=3)
    rng = random.Random(923)
    gradient(a, (13, 18, 38), (57, 61, 88))
    a.p("#302c4a", (15, 28), (57, 18), (128, 13), (159, 18), (159, 22), (77, 24), (45, 29))
    a.dither("#564154", 5, (0, 34), (89, 18), (135, 19), (159, 18), (159, 30), (37, 42), (0, 46))
    for x in range(1, 160, 8):
        roof = rng.randrange(48, 71)
        a.r("#25273d", x, roof, x + rng.randrange(4, 8), 85)
        for y in range(roof + 4, 77, 5):
            if rng.random() < 0.53:
                a.r("#51516e", x + 2, y, x + 3, y + 1)
    a.p("#251c31", (42, 82), (52, 37), (58, 31), (66, 28), (67, 22), (73, 17), (94, 17), (101, 21), (104, 28),
        (112, 32), (122, 36), (129, 80))
    a.p("#111525", (46, 80), (55, 38), (62, 32), (73, 28), (97, 28), (109, 31), (119, 38), (125, 80), (113, 85), (57, 86))
    a.p("#31374e", (47, 80), (56, 39), (63, 35), (63, 79), (56, 86))
    a.p("#24283d", (106, 33), (117, 38), (124, 80), (114, 85), (113, 56))
    a.p("#3b3b54", (64, 34), (74, 30), (98, 30), (108, 34), (114, 81), (106, 84), (61, 83))
    for index in range(5):
        y = 39 + index * 8
        left, right = 55 - index, 119 + index
        a.l("#181827", (left, y + 3), (66, y), (105, y), (right, y + 3), width=2)
        a.l("#555469", (left + 1, y + 1), (67, y - 1), (105, y - 1), (right - 1, y + 1))
        a.l("#5bafc9", (58 - index, y + 4), (62 - index, y + 3))
        a.l("#ae334e", (111 + index, y + 3), (116 + index, y + 4))
    a.l("#575b77", (64, 35), (62, 80), width=2)
    a.l("#87bec9", (66, 40), (65, 70))
    a.l("#625475", (108, 35), (112, 77), width=2)
    a.p("#100f1c", (73, 31), (100, 31), (102, 72), (87, 66), (72, 73))
    a.p("#6a1738", (75, 32), (98, 32), (100, 69), (87, 63), (74, 69))
    a.p("#420f2e", (91, 33), (98, 32), (100, 69), (91, 65))
    a.l("#b13353", (75, 33), (75, 65))
    crest(a, 86, 46, "#e94162", 0.88)
    a.dither("#b33251", 4, (77, 53), (90, 54), (98, 48), (98, 67), (87, 62), (76, 66))
    a.p("#21243b", (65, 28), (68, 22), (74, 18), (94, 18), (101, 22), (103, 29), outline="#522943")
    a.l("#7dbac5", (68, 24), (75, 21), (94, 21), (100, 24))
    for x in range(73, 99, 6):
        a.l("#cf325b", (x, 24), (x, 27))
    a.p("#794058", (81, 17), (84, 10), (85, 2), (87, 10), (90, 18))
    a.l("#68dbdb", (85, 3), (85, 15))
    a.l("#ffe1c9", (85, 9), (85, 15))
    a.l("#e95e71", (76, 17), (94, 17))
    a.p("#121726", (0, 80), (28, 76), (52, 83), (76, 79), (101, 78), (133, 81), (159, 76), (159, 89), (0, 89))
    a.l("#744962", (17, 86), (47, 87), (57, 85))
    a.l("#5696aa", (77, 83), (99, 83), (104, 84))
    a.l("#a53853", (109, 87), (135, 87))

    # Crisp 480x270 OVA neo-noir skyline, tower searchlights, neon windows & fine rain.
    hi = a.native()
    # Upward spotlight beams sweeping past Volkov Tower into the sky.
    hi.dither("#4e7c96", 3, (124, 238), (144, 238), (88, 0), (42, 0))
    hi.dither("#9e3352", 3, (354, 238), (376, 238), (442, 0), (394, 0))
    # Fine skyscraper office window grids & red aircraft warning beacons.
    for bx in range(6, 474, 14):
        if 132 <= bx <= 380:
            continue
        top_y = 148 + (bx * 19) % 52
        if bx % 28 == 6:
            hi.l("#333856", (bx + 4, top_y - 14), (bx + 4, top_y))
            hi.r("#ff4364", bx + 3, top_y - 16, bx + 5, top_y - 14)
        for wy in range(top_y + 6, 230, 7):
            for wx in range(bx + 2, min(476, bx + 11), 4):
                if rng.random() < 0.36:
                    hi.r(rng.choice(("#68c4d4", "#d95770", "#9599b8", "#f0c996")), wx, wy, wx + 1, wy + 2)
    # Tower glass mullions, glowing floor bands & subtle dithered spire beacon halo.
    for floor_y in (122, 146, 170, 194, 218):
        hi.l("#7ee0ec", (170, floor_y), (190, floor_y - 3))
        hi.l("#ff4e6e", (328, floor_y - 3), (348, floor_y))
    hi.dither("#68dbdb", 4, (242, 10), (256, 0), (270, 10), (256, 24))
    hi.r("#e8ffff", 254, 6, 258, 12)
    # Wet street neon puddle reflections.
    for rx, ry, rw, rc in ((42, 256, 36, "#c94362"), (116, 262, 48, "#60b8cc"),
                           (232, 252, 62, "#7bd8e0"), (324, 260, 56, "#e34966"), (402, 254, 40, "#9c4767")):
        hi.l(rc, (rx, ry), (rx + rw, ry))
        hi.l("#2a324a", (rx + 6, ry + 2), (rx + rw - 4, ry + 2))
    # Layered 1px diagonal atmospheric rain streaks.
    for _ in range(290):
        rx, ry = rng.randrange(480), rng.randrange(270)
        length = rng.choice((6, 9, 13))
        hi.l(rng.choice(("#4a5070", "#68708e", "#5b7991", "#8ba3b8")), (rx, ry), (rx - length // 2, ry + length))
    a.save("sprites/cutscenes", "bg_tower_exterior", opaque=True)


HUD_SIZE = (320, 200)
STEEL = "#35475d"
BEVEL = "#7d9aaf"
GLINT = "#c4dce0"
CARBON = "#202a39"
RED = "#ef2446"


class WeaponView:
    """Project gun-local points from the receiver toward the muzzle."""

    def __init__(self, art, anchor, pitch):
        self.art = art
        self.anchor = anchor
        self.pitch = pitch

    def xy(self, point):
        along, down = point
        return (round(self.anchor[0] - along + 0.52 * down),
                round(self.anchor[1] - self.pitch * along + down))

    def p(self, color, *points, outline=INK):
        self.art.p(color, *map(self.xy, points), outline=outline)

    def l(self, color, *points, width=1):
        self.art.l(color, *map(self.xy, points), width=width)


def sleeve(a, wrist, bottom):
    x, y = wrist
    left, right = bottom
    a.p(INK, (left, 199), (x - 21, y + 10), (x - 15, y - 8), (x + 10, y - 12),
        (x + 23, y + 3), (right, 199))
    a.p("#292e3b", (left + 3, 199), (x - 18, y + 10), (x - 13, y - 6),
        (x + 10, y - 9), (x + 20, y + 5), (right - 3, 199))
    a.p("#40495b", (left + 6, 199), (x - 15, y + 12), (x - 7, y + 14),
        (x + 3, y + 31), (left + 31, 199))
    a.p("#1a1d29", (right - 26, 199), (x + 8, y + 24), (x + 19, y + 13), (right - 4, 199))
    a.l("#515b6a", (x - 15, y + 15), (x - 11, y + 27), (left + 12, 199))
    a.l("#222533", (x - 5, y + 28), (x + 5, y + 42), (x + 10, y + 45), width=2)
    a.dither("#53586a", 4, (x - 11, y + 21), (x + 1, y + 31), (left + 29, 199), (left + 17, 199))
    a.p("#242938", (x - 20, y + 9), (x - 15, y - 8), (x + 12, y - 11),
        (x + 22, y + 4), (x + 15, y + 16), (x - 11, y + 22), outline=INK)
    a.l("#6a7889", (x - 17, y + 11), (x - 12, y + 16), (x + 10, y + 11), width=2)
    a.l("#3d4556", (x - 13, y + 18), (x + 1, y + 15), (x + 15, y + 10))


def gripping_hand(a, wrist):
    x, y = wrist
    a.p("#212635", (x - 19, y + 4), (x - 22, y - 9), (x - 14, y - 24), (x - 2, y - 29),
        (x + 10, y - 26), (x + 18, y - 18), (x + 20, y - 7), (x + 12, y + 5),
        (x - 6, y + 12), outline=INK)
    a.p("#384456", (x - 17, y + 3), (x - 18, y - 8), (x - 11, y - 19), (x, y - 23),
        (x + 12, y - 17), (x + 8, y - 9), (x + 3, y - 3), (x - 7, y + 8), outline=INK)
    a.l("#6b7b8b", (x - 16, y - 5), (x - 12, y - 12), (x - 5, y - 17), width=2)
    a.l("#5a6678", (x - 13, y + 4), (x - 8, y + 7), (x - 1, y + 3))
    for row in range(3):
        yy = y - 20 + row * 6
        a.p("#966363", (x + 2, yy - 1), (x + 10, yy - 2), (x + 15, yy), (x + 14, yy + 3),
            (x + 7, yy + 4), (x + 2, yy + 2), outline=INK)
        a.l("#cb8d76", (x + 5, yy), (x + 10, yy - 1), (x + 12, yy))


def muzzle(a, center, variant, wide=False):
    x, y = center
    radius = 40 if wide else 31 if variant == 1 else 22
    points = ((2, 6), (-8, 4), (-18, 13), (-16, 3), (-32, 0), (-20, -5), (-37, -24),
              (-17, -14), (-19, -30), (-10, -14), (-4, -22), (-3, -8), (8, -12), (4, -3))

    def star(scale):
        return [(x + round(px * scale), y + round(py * scale)) for px, py in points]

    a.p("#aa2445", *star(radius / 28))
    a.p("#ff633d", *star(radius / 36))
    a.p("#ffba62", *star(radius / 47))
    a.p("#87edec", (x + 2, y + 4), (x - 10, y - 2), (x - radius, y - radius // 2 - 8),
        (x - 12, y - 9), (x, y - 3))
    a.p("#fff6cf", *star(radius / 68))
    for dx, dy, color in ((-35, -2, "#ffd580"), (-21, -30, "#ff934f"),
                          (-12, -20, "#81e9ec"), (-26, 8, "#fc7650")):
        sx = x + dx * radius // 30
        sy = y + dy * radius // 30
        a.l(color, (sx, sy), (sx - 3, sy - 2))


def ammunition(a, anchor, pitch, shell=False):
    view = WeaponView(a, anchor, pitch)
    length = 20 if shell else 13
    body = "#b42e48" if shell else "#b77c4e"
    highlight = "#ed6870" if shell else "#ffe4a1"
    view.p(body, (0, 0), (length - 1, 0), (length + 1, 3), (length - 1, 7), (0, 7), (-2, 4))
    view.l(highlight, (1, 1), (length - 1, 1), width=2)
    view.p("#c49552", (-1, 0), (3, 0), (3, 7), (-2, 7), (-3, 4))
    view.l("#ffda91", (-1, 2), (1, 2), width=2)
    view.l("#783b3a", (4, 5), (length - 1, 5))


def pistol_ads():
    a = Art(HUD_SIZE)
    sleeve(a, (130, 164), (49, 155))
    sleeve(a, (192, 161), (167, 276))
    a.p(CARBON, (136, 147), (145, 126), (150, 102), (155, 99), (165, 99),
        (170, 104), (177, 130), (186, 148), (178, 168), (143, 169), outline=INK)
    a.p(STEEL, (138, 139), (151, 105), (156, 101), (164, 101), (169, 105), (181, 138),
        (171, 146), (151, 146), outline=INK)
    a.p("#526c84", (141, 137), (152, 106), (157, 103), (164, 103), (170, 119), (173, 139))
    a.p(BEVEL, (150, 128), (155, 105), (157, 104), (155, 129), outline=None)
    a.p("#2c3a50", (162, 105), (166, 106), (173, 135), (167, 136))
    a.l("#afc3ce", (155, 110), (153, 119), (152, 126))
    for x, direction in ((133, 1), (187, -1)):
        a.p("#242935", (x - 15, 165), (x - 12, 149), (x + direction * 8, 136),
            (x + direction * 15, 127), (x + direction * 20, 130), (x + direction * 19, 138),
            (x + direction * 14, 146), (x + direction * 14, 161), (x + 7, 173), outline=INK)
        a.p("#3f4b5a", (x - 10, 164), (x + direction * 4, 145), (x + direction * 11, 139),
            (x + direction * 14, 148), (x + direction * 8, 164), (x, 170), outline=INK)
        a.p("#a77770", (x + direction * 10, 136), (x + direction * 15, 129),
            (x + direction * 18, 131), (x + direction * 15, 139), (x + direction * 13, 141), outline=INK)
        a.l("#e8a388", (x + direction * 13, 133), (x + direction * 15, 131))
        a.l("#697b8a", (x - 7, 164), (x + direction * 6, 151), (x + direction * 9, 148), width=2)
    a.p(INK, (148, 140), (148, 126), (153, 124), (156, 128), (156, 132),
        (164, 132), (164, 128), (167, 124), (173, 127), (173, 140), (169, 150), (152, 150))
    a.p(STEEL, (151, 139), (151, 128), (154, 128), (155, 135),
        (165, 135), (167, 128), (170, 129), (170, 139), (167, 147), (154, 147))
    a.l(BEVEL, (151, 128), (153, 127), (154, 130))
    a.l(BEVEL, (167, 128), (169, 127), (171, 129))
    a.r("#293242", 156, 138, 166, 144, outline=INK)
    a.l("#617890", (157, 139), (164, 139))
    a.p(INK, (149, 105), (149, 96), (153, 96), (154, 98), (154, 103),
        (166, 103), (166, 98), (167, 96), (171, 96), (171, 105), (167, 108), (153, 108))
    a.r(RED, 158, 99, 162, 101)
    a.point((160, 100), fill="#ff8880")
    return a


def pistol(frame):
    if frame == "ads":
        pistol_ads().save("sprites/weapons", "pistol_ads")
        return
    a = Art(HUD_SIZE)
    anchor, pitch = {
        "idle": ((230, 129), 0.42),
        "fire_1": ((237, 124), 0.67),
        "fire_2": ((233, 127), 0.54),
        "reload_1": ((236, 123), 0.87),
        "reload_2": ((232, 122), 0.73),
    }[frame]
    view = WeaponView(a, anchor, pitch)
    fired = frame.startswith("fire")
    reloading = frame.startswith("reload")
    wrist = view.xy((-4, 41))
    sleeve(a, wrist, (204, 311))
    view.p(CARBON, (-10, 6), (13, 2), (20, 19), (13, 43), (9, 47), (-11, 44), (-16, 37))
    view.p("#4c5767", (-8, 11), (7, 10), (10, 20), (6, 38), (-10, 40), (-12, 35))
    for down in range(21, 39, 3):
        view.l("#242a36", (-10, down), (6, down - 2))
    view.p(STEEL, (6, 11), (26, 8), (45, 7), (64, 5), (77, 1), (79, 9), (73, 13),
        (52, 17), (41, 22), (26, 23), (20, 19), (10, 21))
    view.p(INK, (25, 19), (42, 18), (47, 19), (41, 28), (34, 32), (21, 30), (16, 26), (20, 20))
    view.p("#194050", (26, 21), (42, 20), (40, 24), (34, 28), (23, 27), (20, 24))
    view.l(BEVEL, (22, 29), (34, 30), (41, 27), (45, 21))
    view.l("#9c5f6c", (50, 14), (72, 10), width=3)
    view.l(RED, (58, 15), (72, 12))
    view.p("#43172a", (61, 13), (77, 9), (80, 13), (75, 17), (62, 20), (59, 18))
    view.l("#ff3e55", (64, 15), (76, 12), width=2)
    view.p("#7f8fa4", (58, 0), (80, -8), (82, -4), (81, 2), (60, 8))
    view.l(GLINT, (59, 2), (77, -5), width=2)
    slide = 12 if frame == "fire_1" or reloading else 7 if fired else 0
    slide_view = WeaponView(a, view.xy((-slide, 0)), pitch)
    slide_view.p(INK, (-17, -9), (-7, -19), (8, -23), (65, -17), (78, -13),
                 (79, -5), (73, 3), (62, 8), (2, 13), (-15, 9))
    slide_view.p(STEEL, (-14, -8), (1, -19), (65, -15), (76, -12), (77, -6),
                 (70, 2), (61, 6), (0, 11), (-13, 7))
    slide_view.p("#617f9c", (-12, -8), (1, -18), (66, -14), (76, -11),
                 (61, -8), (28, -6), (3, -2), outline=None)
    slide_view.l(GLINT, (1, -17), (30, -16), (58, -14), (71, -12))
    slide_view.l("#1a2536", (-10, -3), (3, 0), (26, -3), (56, -6), (75, -10), width=2)
    slide_view.l("#7897aa", (20, 6), (56, 1), (70, -2))
    slide_view.p("#1d2838", (33, -5), (54, -8), (59, -7), (54, -3), (34, 0))
    slide_view.l("#9bbbc6", (35, -3), (51, -5))
    for along in (-10, -5, 0, 5, 10):
        slide_view.l(INK, (along, -5), (along + 2, 6), width=2)
        slide_view.l(BEVEL, (along + 2, -5), (along + 4, 6))
    slide_view.p(INK, (67, -16), (69, -22), (74, -22), (76, -15))
    slide_view.l(RED, (70, -20), (73, -20), width=2)
    slide_view.l("#ffaea0", (71, -20), (72, -20))
    slide_view.p("#101522", (73, -9), (77, -12), (79, -9), (79, -5), (76, -1), (73, -3))
    if reloading:
        mag = WeaponView(a, view.xy((10 if frame == "reload_1" else 3, 55)), pitch)
        if frame == "reload_2":
            sleeve(a, (187, 177), (126, 206))
            gripping_hand(a, (187, 177))
        mag.p("#3b4b61", (-12, -10), (1, -10), (3, 18), (-13, 22), (-19, 18))
        mag.l(BEVEL, (-10, -7), (-13, 17), width=2)
        mag.l("#c49052", (-11, -10), (-3, -11), width=2)
        mag.l("#171a24", (-16, 18), (1, 15), width=2)
        view.l("#65e5ee", (65, -4), (77, -8), width=2)
        view.l("#d2ffff", (74, -8), (79, -9))
        if frame == "reload_1":
            a.l("#647991", (wrist[0] - 12, wrist[1] + 12), (wrist[0] - 22, wrist[1] + 30))
    gripping_hand(a, wrist)
    if fired:
        muzzle(a, view.xy((83, -7)), int(frame[-1]))
        if frame == "fire_2":
            ammunition(a, (268, 86), -1.15)
            a.l("#83626b", (268, 94), (262, 101), (257, 104))
    a.save("sprites/weapons", f"pistol_{frame}")


def shotgun(frame):
    a = Art(HUD_SIZE)
    anchor, pitch = {
        "idle": ((242, 147), 0.47),
        "fire_1": ((253, 145), 0.71),
        "pump_1": ((247, 148), 0.58),
        "pump_2": ((244, 147), 0.48),
        "reload": ((239, 139), 0.24),
    }[frame]
    view = WeaponView(a, anchor, pitch)
    pump = {"pump_1": -22, "pump_2": -8}.get(frame, 0)
    wrist = view.xy((0, 24))
    hand = view.xy((76 + pump, 36)) if frame != "reload" else (191, 167)
    sleeve(a, wrist, (224, 319))
    sleeve(a, hand, (100, 200 if frame != "reload" else 229))
    view.p(INK, (-24, 5), (-16, -19), (4, -29), (44, -26), (53, -20), (133, -16), (148, -11),
           (149, 5), (142, 11), (130, 14), (123, 24), (78, 27), (52, 30), (32, 35),
           (9, 38), (-14, 37))
    view.p(CARBON, (-21, 5), (-13, -17), (5, -25), (44, -23), (53, -17),
           (133, -14), (146, -10), (146, 4), (137, 11), (124, 12), (123, 20),
           (72, 25), (48, 27), (31, 32), (10, 35), (-13, 34))
    view.p(STEEL, (-16, -9), (6, -23), (41, -21), (55, -16), (129, -13),
           (144, -9), (132, -4), (87, -2), (63, 0), (54, 7), (30, 12), (3, 11))
    view.p("#55748d", (-10, -11), (7, -22), (40, -20), (55, -15), (126, -12),
           (135, -10), (110, -8), (52, -7), (42, -9), (5, -8), outline=None)
    view.l(GLINT, (7, -21), (36, -19), (48, -17))
    view.l(BEVEL, (54, -15), (101, -13), (127, -11), width=2)
    view.l("#69879b", (56, 6), (93, 2), (126, 1), (141, -2), width=2)
    view.p("#526479", (149, -10), (153, -7), (154, 1), (149, 8), (144, 7), (142, 2), (143, -5))
    view.p(INK, (149, -7), (151, -6), (152, 1), (149, 5), (146, 4), (145, -1), (146, -5))
    view.l(GLINT, (150, -7), (152, -4))
    view.p(INK, (132, -15), (137, -23), (143, -22), (145, -14))
    view.l(RED, (138, -21), (142, -21), width=2)
    for along in range(69, 129, 10):
        view.p(INK, (along, -10), (along + 6, -10), (along + 7, -7), (along + 4, -4), (along, -5))
        view.l(BEVEL, (along + 1, -5), (along + 5, -5))
    view.p("#111b2a", (7, -6), (29, -13), (45, -12), (52, -7), (48, 5), (32, 10), (6, 9))
    view.p("#2b3b50", (12, -3), (30, -9), (45, -9), (48, -6), (44, 3), (32, 6), (12, 5))
    view.l("#78a0b3", (12, -2), (30, -8), (43, -8))
    view.l("#9ae0e6" if pump else "#72889a", (32, 1), (42, -1), width=2)
    view.p("#292330", (12, 12), (48, 8), (48, 22), (12, 28), (4, 23))
    for along in range(12, 45, 8):
        shell = WeaponView(a, view.xy((along, 24)), 2.4)
        shell.p("#a72942", (0, 0), (6, -2), (7, 2), (5, 7), (0, 8), (-1, 4))
        shell.l("#f56a6f", (1, 1), (5, -1))
        shell.l("#dfab6f", (0, 4), (0, 7), width=2)
    forestock = WeaponView(a, view.xy((pump, 0)), pitch)
    forestock.p("#323847", (54, 11), (107, 6), (120, 9), (119, 20), (109, 26),
                (67, 31), (53, 25))
    forestock.l(BEVEL, (57, 13), (105, 9), (116, 11))
    for along in range(59, 114, 8):
        forestock.l(INK, (along, 13), (along + 3, 26), width=3)
        forestock.l("#647584", (along + 2, 13), (along + 5, 26))
    gripping_hand(a, wrist)
    gripping_hand(a, hand)
    if frame == "fire_1":
        muzzle(a, view.xy((153, 1)), 1, wide=True)
    elif frame == "reload":
        view.p(INK, (44, 23), (62, 17), (66, 19), (62, 27), (47, 31), (42, 29))
        view.l("#7da6b5", (45, 29), (61, 24), width=2)
        ammunition(a, (hand[0] + 6, hand[1] - 21), 0.76, shell=True)
    elif frame == "pump_1":
        ammunition(a, (206, 88), -0.85, shell=True)
    a.save("sprites/weapons", f"shotgun_{frame}")


def blade(frame):
    a = Art(HUD_SIZE)
    anchor, pitch = {"idle": ((224, 149), 0.84), "slash_1": ((206, 151), 0.42),
                     "slash_2": ((182, 153), 0.14)}[frame]
    if frame.startswith("slash"):
        y = 0 if frame.endswith("1") else 20
        a.p((130, 18, 52, 195), (20, 161 + y), (57, 119 + y), (104, 83 + y), (158, 57 + y),
            (211, 44 + y), (279, 39 + y), (309, 48 + y), (262, 52 + y), (209, 69 + y),
            (136, 104 + y), (166, 97 + y), (211, 94 + y), (152, 118 + y), (91, 154 + y), (46, 169 + y))
        a.p("#df3057", (28, 158 + y), (77, 112 + y), (122, 80 + y), (169, 59 + y),
            (214, 49 + y), (284, 42 + y), (257, 53 + y), (211, 64 + y), (163, 83 + y),
            (116, 110 + y), (66, 147 + y), (101, 132 + y), (76, 151 + y))
        a.l("#fff0d9", (34, 157 + y), (69, 126 + y), (122, 89 + y), (165, 68 + y),
            (210, 54 + y), (266, 45 + y), width=2)
        a.l("#ff8494", (78, 155 + y), (122, 128 + y), (166, 108 + y), (190, 100 + y))
    view = WeaponView(a, anchor, pitch)
    wrist = view.xy((-2, 22))
    sleeve(a, wrist, (196 if frame == "idle" else 166, 314))
    view.p(CARBON, (-19, 21), (-18, 9), (-8, 0), (20, -8), (27, -2), (29, 8),
           (22, 16), (-7, 26), (-15, 26))
    view.l(BEVEL, (-15, 11), (-7, 4), (18, -4))
    for along in range(-10, 24, 5):
        view.l("#111824", (along, 6), (along + 5, 16), width=2)
    view.p("#384658", (21, -9), (27, -12), (35, -5), (36, 7), (31, 16), (24, 14), (23, 5))
    view.l(BEVEL, (26, -9), (32, -4), (34, 3))
    view.p("#435368", (30, -6), (47, -11), (83, -16), (106, -15), (94, -2),
           (79, 6), (55, 12), (36, 10))
    view.p("#252e3f", (35, -5), (55, -10), (89, -14), (104, -14), (91, -7),
           (73, -2), (49, 4), (36, 5), outline=None)
    view.p("#6f8b9c", (37, 7), (64, 4), (89, -3), (105, -14), (95, -3), (80, 5),
           (54, 11), (38, 10), outline=None)
    view.l(GLINT, (39, 10), (55, 10), (80, 4), (94, -3), (104, -13))
    view.l(INK, (41, 1), (63, -4), (86, -10), width=3)
    view.l("#4b566c", (42, 2), (66, -3), (86, -9))
    view.l("#ad5267", (45, -6), (63, -9), (80, -11))
    gripping_hand(a, wrist)
    a.save("sprites/weapons", f"melee_{frame}")


def beta_hand(frame):
    a = Art(HUD_SIZE)
    lift = (0, -4, -8)[frame - 1]
    center = (71 + frame * 4, 132 + lift)
    cx, cy = center
    paths = (
        ((5, -7), (13, -24), (29, -28), (23, -38), (41, -43), (55, -60), (75, -66)),
        ((16, 4), (33, -3), (43, -17), (62, -13), (71, -29), (96, -32), (109, -43)),
        ((13, 12), (31, 13), (40, 5), (61, 12), (82, 5), (106, 9), (142, -5)),
        ((4, -10), (0, -22), (9, -34), (5, -51), (23, -65), (30, -89)),
        ((20, -4), (50, -4), (56, -21), (84, -26), (99, -46), (126, -57), (155, -59)),
    )
    for index, path in enumerate(paths[:(1, 3, 5)[frame - 1]]):
        points = tuple((cx + x, cy + y) for x, y in path)
        a.l((163, 19, 61, 142), *points, width=frame + 2)
        a.l("#ff2c63", *points, width=1 if frame == 1 else 2)
        if frame > 1:
            a.l("#ffb1ac" if index % 2 else "#ff5a8b", *points[2:-1])
        for x, y in points[2::2]:
            a.l("#ff9ba6", (x + 2, y - 3), (x + 5, y - 5))
    sleeve(a, (53, 166 + lift), (0, 117))
    hand = WeaponView(a, (55, 159 + lift), 0.1)
    hand.p("#303646", (23, 16), (28, 1), (18, -11), (20, -24), (27, -30),
           (25, -43), (17, -48), (8, -46), (4, -34), (-3, -38), (-7, -58), (-16, -61),
           (-21, -55), (-17, -33), (-25, -41), (-32, -59), (-39, -59), (-43, -52),
           (-37, -29), (-47, -43), (-55, -42), (-58, -34), (-45, -15), (-40, -2),
           (-32, 9), (-22, 21), (2, 28))
    hand.p("#414c61", (20, 13), (24, 2), (14, -11), (15, -22), (22, -29),
           (19, -39), (13, -40), (5, -27), (-13, -25), (-29, -22), (-39, -13),
           (-38, -3), (-21, 17), (-7, 25), (8, 21))
    for x, y in ((-13, -55), (-34, -53), (-49, -37), (16, -42)):
        hand.l("#7b8ca0", (x, y), (x + 3, y + 11), width=3)
        hand.l("#d55a72", (x - 1, y + 2), (x, y + 6))
    hand.p("#202334", (9, 19), (13, 1), (5, -17), (-11, -22), (-27, -14),
           (-34, -3), (-28, 8), (-17, 22), (-1, 26))
    hand.p("#566379", (7, 18), (9, 5), (4, 3), (-1, 9), (-10, 19), (-18, 20), (-9, 24))
    hand.l("#8194a7", (6, 17), (6, 8), (4, 5))
    hand.p("#541734", (3, 0), (4, -14), (-4, -21), (-17, -21), (-26, -15),
           (-30, -5), (-25, 5), (-13, 9), (-2, 6))
    hand.p("#ad183f", (0, 0), (1, -13), (-5, -18), (-17, -18), (-24, -13),
           (-27, -5), (-22, 3), (-13, 6), (-3, 3))
    hand.l("#ff6a79", (-2, -2), (-1, -11), (-6, -16), (-13, -17), width=2)
    hand.l("#ffd2b8", (-2, -9), (-5, -14), (-10, -15))
    hand.l("#6a1838", (-20, 1), (-23, -4), (-23, -10))
    helix(a, cx - 2, cy + 10, 5, 16, frame * 0.92)
    hand.l("#f54362", (2, 8), (7, 13), (1, 21), (-6, 24), width=2)
    a.l("#ff8390", (50, 170 + lift), (40, 178 + lift), (33, 189 + lift), width=2)
    for x, y in ((43, 148 + lift), (91, 143 + lift), (77, 170 + lift)):
        a.r(INK, x - 2, y - 2, x + 2, y + 2)
        a.point((x, y), fill="#a4c2d0")
    a.save("sprites/weapons", f"beta_hand_{frame}")


ENEMIES = {
    # shadow, uniform, light, trim, visor
    "guard_lv1": ("#192737", "#49637f", "#9fbbcd", "#e0e0d5", "#77e1e6"),
    "tech_lv1": ("#1d2032", "#3f4862", "#8698b1", "#e48542", "#6be4ce"),
    "merc_lv2": ("#201e2d", "#3e435d", "#8390a7", "#b56a41", "#ff6954"),
}
ENEMY_FRAMES = ("idle_1", "idle_2", "walk_1", "walk_2", "walk_3", "walk_4", "windup_1", "windup_2",
                "attack_1", "attack_2", "hurt_1", "death_1", "death_2", "death_3",
                "corpse_fresh", "corpse_drained")


def windup_halo(a, muzzle, index):
    width = a.image.width
    x, y = muzzle
    radius = (9 + 3 * index) if width == 64 else (13 + 4 * index)
    # Keep both arc segments in the frame even when the muzzle is near its edge.
    ring_x = min(width - radius - 3, x)
    outer = (ring_x - radius, y - radius, ring_x + radius, y + radius)
    inner = (outer[0] + 3, outer[1] + 3, outer[2] - 3, outer[3] - 3)
    glow = "#ff9e4d" if index == 1 else "#ff6748"
    for begin, end in ((191, 273), (288, 352), (18, 107)):
        a.draw.arc(outer, begin, end, fill=(202, 44, 54, 168), width=3)
        a.draw.arc(inner, begin + 8, end - 7, fill=glow)
    a.l("#ffb762", (ring_x - radius + 3, y - 4), (ring_x - radius, y - 7), width=2)
    a.l("#ffa86a", (ring_x + 2, y - radius + 2), (ring_x + 3, y - radius - 3))
    a.l("#f25151", (ring_x + 5, y + radius - 3), (ring_x + 9, y + radius - 1))
    a.p(glow, (x - 7, y), (x - 2, y - 2), (x, y - 7), (x + 2, y - 2),
        (x + 6, y), (x + 1, y + 2), (x, y + 6), (x - 2, y + 2))
    a.p("#fff2b2", (x - 3, y), (x, y - 3), (x + 3, y), (x, y + 2))
    if index == 2:
        a.l("#ffdc7c", (ring_x - 5, y - radius + 3), (ring_x - 9, y - radius))
        a.l("#ff8758", (ring_x - radius + 1, y + 5), (ring_x - radius - 3, y + 8), width=2)


def death_pose(torso, fallen, palette, index):
    w, h = torso.image.size
    shadow, uniform, light, trim = palette
    size = w / 64
    a = Art((w, h))
    a.e((25, 18, 28, 104), 2, h - 8, w - 3, h - 1)

    if index == 3:
        # Keep the boots planted and lift the head a few pixels before impact.
        a.image.alpha_composite(fallen.image.transform(
            (w, h), Image.Transform.AFFINE, (1, 0, 0, 0.09, 1, 0),
            resample=Image.Resampling.NEAREST))
        a.l("#765164", (4, h - 9), (10, h - 12), (16, h - 12))
        a.l("#956e75", (w - 13, h - 14), (w - 8, h - 13), (w - 4, h - 10))
        a.l("#b67c78", (w - 12, h - 20), (w - 8, h - 21))
        a.l("#4f3b4c", (w - 25, h - 6), (w - 16, h - 6))
        return a

    fall = index == 2
    pivot_x, pivot_y = (w // 2, 80 if w == 96 else 60)
    hip_x = round(w * (0.36 if fall else 0.43))
    hip_y = h - round((16 if fall else 28) * size)
    angle = math.radians(38 if fall else 16)
    proportion = 0.82 if fall else 0.93
    cosine, sine = math.cos(angle) / proportion, math.sin(angle) / proportion
    leaned = torso.image.transform(
        (w, h), Image.Transform.AFFINE,
        (cosine, sine, pivot_x - cosine * hip_x - sine * hip_y,
         -sine, cosine, pivot_y + sine * hip_x - cosine * hip_y),
        resample=Image.Resampling.NEAREST,
    )
    if fall:
        alpha = leaned.getchannel("A")
        leaned = Image.blend(leaned, Image.new("RGBA", leaned.size, "#181521"), 0.35)
        leaned.putalpha(alpha)

    def point(x, y):
        return round(x * size), h - 1 + round(y * size)

    legs = (
        ((24, -30), (15, -14), (12, -3), 4), ((31, -30), (43, -13), (51, -3), 4),
    ) if not fall else (
        ((20, -16), (14, -7), (5, -3), 0), ((26, -15), (36, -2), (20, -2), 0),
    )
    for top, knee, toe, heel in legs:
        tx, ty = top
        kx, ky = knee
        fx, fy = toe
        a.p(shadow, *[point(x, y) for x, y in (
            (tx - 6, ty), (tx + 6, ty), (kx + 5, ky - 3), (kx + 4, ky + 1),
            (fx + 5, fy - heel), (fx + 7, fy + 1), (fx - 5, fy + 2),
            (fx - 7, fy - 1), (kx - 5, ky + 3), (kx - 5, ky - 3))], outline=INK)
        a.l(uniform, point(tx - 3, ty + 2), point(kx - 2, ky), point(fx - 3, fy),
            width=round(4 * size))
        a.p(trim if not fall else uniform, point(kx - 4, ky - 2), point(kx + 3, ky - 2),
            point(kx + 4, ky), point(kx + 1, ky + 2), point(kx - 3, ky + 2), outline=INK)
        a.l(light if not fall else uniform, point(kx - 3, ky - 1), point(kx, ky - 1))
    a.image.alpha_composite(leaned)

    x, y = point(50 if fall else 49, -11 if fall else -28)
    dropped = WeaponView(a, (x, y), -0.35 if fall else 0.38)
    length = round((16 if w == 96 else 11) * size)
    dropped.p("#3b4555", (-4, -3), (length - 3, -3), (length, -1),
              (length, 2), (2, 4), (-1, 9), (-5, 8), (-3, 4), (-6, 0))
    dropped.l("#889aaa", (-3, -1), (length - 2, -1))
    dropped.l("#7a313f", (length - 4, 1), (length - 1, 1))

    if not fall:
        x, y = point(29, -55)
        a.p("#a32947", (x - 11, y - 7), (x - 2, y - 3), (x + 2, y - 11), (x + 4, y - 2),
            (x + 12, y - 4), (x + 7, y + 2), (x + 11, y + 9), (x + 2, y + 5),
            (x - 4, y + 10), (x - 5, y + 3), (x - 13, y + 4))
        a.p("#fc536b", (x - 6, y - 3), (x + 1, y), (x + 3, y - 6), (x + 4, y),
            (x + 8, y - 2), (x + 5, y + 3), (x + 1, y + 5), (x - 3, y + 3))
        a.l("#ffd0aa", (x - 2, y + 1), (x + 2, y + 2), (x + 4, y))
        for dx, dy in ((-15, -8), (-9, -13), (7, -15), (14, 2), (-15, 10)):
            a.l("#f56670", (x + dx, y + dy), (x + dx - 2, y + dy - 3))
    else:
        for dx, dy in ((17, -49), (20, -44), (28, -45)):
            x, y = point(dx, dy)
            a.l("#923146", (x, y), (x - 2, y - 2))
    return a


def corpse(enemy, drained, *, charged=True):
    a = Art((64, 96))
    shadow, uniform, light, trim, visor = ENEMIES[enemy]
    if drained:
        shadow, uniform, light, trim, visor = "#272630", "#41404a", "#6b6973", "#77727a", "#837d83"
    a.e((43, 27, 39, 95), 2, 87, 61, 95)
    a.p(shadow, (2, 87), (6, 82), (16, 82), (21, 76), (30, 77), (36, 80), (43, 76), (49, 76), (53, 80),
        (58, 81), (61, 85), (59, 89), (49, 90), (40, 89), (35, 92), (24, 92), (16, 89), (7, 91), outline=INK)
    a.p(uniform, (5, 86), (10, 84), (17, 84), (24, 78), (32, 80), (34, 83), (26, 86), (17, 87), (13, 89), (6, 89), outline=INK)
    a.p(light, (15, 84), (24, 79), (31, 80), (28, 83), (22, 84), (20, 86))
    a.p(uniform, (23, 86), (32, 81), (39, 80), (45, 83), (49, 87), (44, 90), (34, 91), (24, 90), outline=INK)
    a.p(trim, (33, 82), (39, 81), (45, 83), (43, 86), (37, 86), (32, 88), (28, 87))
    a.l(light, (37, 82), (41, 82), (44, 83))
    a.p(uniform, (47, 80), (50, 77), (55, 78), (59, 81), (61, 85), (57, 88), (51, 87), (47, 85), outline=INK)
    a.l(light, (49, 80), (52, 79), (56, 81))
    a.l(visor, (56, 83), (59, 85))
    a.p(shadow, (37, 87), (46, 87), (51, 90), (56, 90), (58, 92), (53, 94), (45, 92), (39, 92), outline=INK)
    a.l(light, (42, 88), (47, 89), (51, 91))
    if enemy == "merc_lv2":
        a.p(trim, (34, 80), (38, 76), (45, 77), (49, 81), (47, 85), (40, 85), outline=INK)
        a.l(light, (37, 79), (40, 77), (44, 78))
        a.l(trim, (52, 79), (55, 80), (57, 82), width=2)
    elif enemy == "tech_lv1":
        a.p("#7c6668" if drained else "#c18471", (51, 79), (54, 79), (58, 82), (58, 85), (54, 85), (51, 83))
        a.l(shadow, (54, 81), (57, 83))
        a.r(visor, 50, 81, 51, 83)
        a.l(shadow, (51, 83), (53, 85), (55, 85))
    else:
        a.l(trim, (50, 79), (53, 77), (56, 79), width=2)
    if drained:
        a.dither("#26252d", 8, (22, 86), (38, 81), (52, 86), (43, 89), (24, 91))
        for x, y in ((12, 92), (18, 90), (25, 94), (48, 94), (58, 92)):
            a.point((x, y), fill="#77717a")
    elif charged:
        for x, y, radius in ((29, 72, 3), (37, 63, 4), (46, 70, 2), (32, 57, 2), (24, 65, 1), (41, 54, 1)):
            a.e((122, 14, 57, 140), x - radius - 2, y - radius - 2, x + radius + 2, y + radius + 2)
            a.e("#de3155", x - radius, y - radius, x + radius, y + radius)
            a.e("#ff978c", x - radius // 2, y - radius // 2, x + radius // 2, y + radius // 2)
            a.point((x, y), fill="#ffe5b7")
        a.l("#b92a52", (29, 87), (34, 81), (37, 79), (37, 75))
        a.l("#ff506a", (30, 86), (34, 82), (36, 81))
    return a


def enemy_frame(enemy, frame, *, torso_only=False):
    if frame.startswith("death"):
        body = enemy_frame(enemy, "idle_1", torso_only=True)
        return death_pose(body, corpse(enemy, False, charged=False), ENEMIES[enemy][:4], int(frame[-1]))
    if frame.startswith("corpse"):
        return corpse(enemy, frame.endswith("drained"))
    a = Art((64, 96))
    shadow, uniform, light, trim, visor = ENEMIES[enemy]
    heavy = enemy == "merc_lv2"
    technician = enemy == "tech_lv1"
    pose = frame.split("_")[0]
    index = int(frame[-1])
    step = (-7, -3, 6, 2)[index - 1] if pose == "walk" else 0
    bob = (index % 2) if pose in ("idle", "walk") else (-2 if pose == "windup" else 1)
    sway = -3 if pose == "hurt" else 0
    a.e((13, 12, 23, 75), 9, 90, 53, 95)
    for side in (1, -1):
        hip = 31 + side * 7
        knee = 30 + side * 8 + side * step // 2
        foot = 31 + side * 10 + side * step
        floor = 93 - max(0, side * step // 2)
        a.p(shadow, (hip - 7, 53), (hip + 7, 53), (knee + 5, 73), (foot + 5, floor - 6),
            (foot + 9, floor - 3), (foot + 8, floor), (foot - 6, floor), (foot - 8, floor - 4),
            (knee - 6, 74), (hip - 6, 66), outline=INK)
        a.p(uniform, (hip - 5, 56), (hip + 4, 57), (knee + 4, 71), (foot + 2, floor - 7),
            (foot - 3, floor - 7), (knee - 4, 73), (hip - 5, 64))
        a.p(light, (hip - 5, 59), (hip - 2, 60), (knee - 1, 73), (knee - 5, 72))
        a.p(trim if heavy else light, (knee - 5, 71), (knee + 3, 71), (knee + 4, 75), (knee, 79), (knee - 4, 78), outline=INK)
        a.l(uniform, (foot - 5, floor - 2), (foot + 5, floor - 2), (foot + 6, floor - 1))
        a.l(light, (foot - 2, floor - 12), (foot - 1, floor - 8))

    body = a
    a = Art((64, 96))
    shoulder = 12 if heavy else 15 if technician else 13
    a.p(shadow, (shoulder, 27), (24, 22), (40, 22), (64 - shoulder, 28), (63 - shoulder, 43),
        (44, 55), (43, 62), (36, 64), (27, 64), (20, 61), (18, 51), (shoulder - 2, 42), outline=INK)
    a.p(uniform, (shoulder + 1, 29), (23, 25), (31, 27), (41, 25), (62 - shoulder, 29), (44, 45),
        (44, 53), (37, 57), (26, 56), (21, 50), (21, 42), (shoulder + 1, 38))
    a.p(trim, (22, 29), (28, 26), (34, 28), (42, 26), (47, 31), (44, 39), (34, 44), (25, 41), (23, 36), outline=INK)
    a.p(light if not technician else "#f2a35c", (24, 30), (28, 28), (34, 31), (41, 28), (44, 30), (38, 33), (29, 34))
    a.p(shadow, (27, 37), (33, 37), (38, 34), (44, 33), (44, 38), (34, 43), (26, 40))
    a.dither(light, 5, (25, 46), (33, 47), (40, 43), (42, 50), (36, 53), (26, 51))
    a.l(INK, (21, 53), (25, 56), (38, 58), (44, 55), width=2)
    a.p("#647485", (27, 54), (37, 55), (37, 59), (28, 60), outline=INK)
    a.l(light, (29, 55), (34, 56))
    if heavy:
        a.p(trim, (7, 30), (13, 25), (22, 27), (25, 33), (22, 41), (12, 41), (8, 37), outline=INK)
        a.p(trim, (42, 28), (50, 25), (57, 30), (57, 37), (53, 41), (45, 39), outline=INK)
        a.l("#e9aa62", (9, 31), (14, 27), (21, 29), width=2)
        a.l("#e9aa62", (45, 29), (50, 27), (55, 30), width=2)
        a.l("#784536", (11, 35), (17, 37), (22, 34))
        a.r("#f4b276", 52, 30, 54, 31)
    elif technician:
        a.p("#535c71", (13, 29), (19, 26), (23, 30), (23, 38), (20, 41), (14, 37), outline=INK)
        a.l("#f8a356", (16, 30), (19, 31), (21, 36), width=2)
        a.l("#e98946", (45, 32), (47, 38), width=2)
        a.l(INK, (33, 29), (34, 37), (33, 41), (33, 52))
    else:
        a.p("#a5c0d1", (11, 31), (15, 27), (21, 29), (23, 33), (20, 37), (12, 36), outline=INK)
        a.l("#e7ebe1", (13, 32), (16, 29), (20, 30))
        a.p("#718ba2", (45, 30), (50, 27), (54, 30), (54, 34), (48, 37), (44, 35), outline=INK)
        a.l("#bed4db", (47, 30), (50, 29), (53, 31))
        a.r("#638eaa", 28, 33, 32, 34)

    if technician:
        a.p("#a06965", (22, 15), (24, 8), (31, 5), (39, 6), (44, 11), (44, 18), (40, 26),
            (34, 30), (28, 27), (26, 24), (23, 23), (21, 20), outline=INK)
        a.p("#e2aa82", (31, 12), (39, 11), (43, 13), (42, 19), (39, 24), (34, 27), (30, 25), (31, 21), (28, 18))
        a.p("#202436", (22, 17), (21, 12), (26, 6), (32, 4), (40, 6), (45, 11), (44, 14), (39, 11),
            (36, 13), (32, 11), (28, 15), (26, 21), (23, 20), outline=INK)
        a.l("#68758a", (24, 12), (29, 8), (34, 7), (39, 8))
        a.p(INK, (28, 16), (32, 15), (36, 17), (36, 19), (32, 19), (29, 18))
        a.p(INK, (38, 17), (43, 15), (43, 18), (40, 19))
        a.l("#e9d2a8", (33, 17), (34, 17))
        a.l("#e9d2a8", (41, 17), (42, 16))
        a.l("#794350", (34, 23), (38, 22), (40, 23))
        a.r("#253c4c", 22, 16, 26, 23, outline=INK)
        a.l(visor, (24, 17), (24, 20))
        a.point((24, 17), fill="#e2fff1")
        a.l("#566b79", (25, 22), (29, 24), (32, 24))
    else:
        top = 3 if heavy else 6
        a.p(uniform, (21, top + 7), (26, top + 3), (31, top), (39, top + 1), (46, top + 6), (47, top + 14),
            (43, top + 22), (38, top + 26), (28, top + 25), (23, top + 20), (19, top + 15), outline=INK)
        a.p(light, (22, top + 9), (27, top + 4), (32, top + 2), (39, top + 3), (44, top + 7), (42, top + 10),
            (36, top + 7), (28, top + 8), (25, top + 12))
        a.l(trim, (26, top + 6), (33, top + 3), (39, top + 4))
        a.p(INK, (22, top + 12), (30, top + 9), (40, top + 9), (46, top + 12), (44, top + 17), (38, top + 20),
            (30, top + 19), (25, top + 18))
        a.p(visor, (25, top + 13), (31, top + 11), (39, top + 11), (44, top + 13), (41, top + 16),
            (36, top + 16), (34, top + 15), (29, top + 16))
        a.l("#fdf3cc", (30, top + 13), (34, top + 12), (38, top + 12))
        a.l("#edf4df" if not heavy else "#ffad91", (39, top + 15), (42, top + 13))
        a.p(shadow, (26, top + 18), (30, top + 19), (34, top + 17), (38, top + 19), (42, top + 17),
            (42, top + 21), (38, top + 24), (30, top + 24), outline=INK)
        a.l(uniform, (31, top + 21), (36, top + 22), (39, top + 21))
        if heavy:
            a.l(trim, (21, top + 11), (22, top + 18), (26, top + 22), width=2)
            a.l(trim, (44, top + 16), (42, top + 22), width=2)

    gun_y = {"windup": 29 - 4 * index, "attack": 35 + index * 2, "hurt": 47}.get(pose, 42 + bob)
    gun_x = {"windup": 44, "attack": 46, "hurt": 42}.get(pose, 45)
    a.p(shadow, (13, 33), (18, 35), (20, 42), (25, gun_y + 5), (30, gun_y + 7), (31, gun_y + 12),
        (24, gun_y + 14), (17, 53), (12, 46), (10, 38), outline=INK)
    a.p(uniform, (13, 36), (16, 37), (17, 43), (23, gun_y + 7), (28, gun_y + 8), (28, gun_y + 10), (22, 50), (18, 48), (14, 44))
    a.l(light, (13, 38), (14, 43), (18, 48))
    a.p(uniform, (47, 33), (52, 36), (53, 42), (49, 47), (43, gun_y + 9), (35, gun_y + 8),
        (34, gun_y + 4), (42, gun_y + 2), (46, 40), (45, 36), outline=INK)
    a.l(light, (49, 36), (51, 40), (48, 44), (43, gun_y + 7))
    if torso_only:
        return a
    reach = 9 if heavy else 7 if technician else 4
    back = 15 if heavy else 12 if technician else 8
    a.p("#384255", (gun_x - back - 7, gun_y + 6), (gun_x - back - 1, gun_y + 1), (gun_x + reach, gun_y - 4),
        (gun_x + reach + 1, gun_y + 1), (gun_x + 4, gun_y + 3), (gun_x - 5, gun_y + 6), (gun_x - back, gun_y + 8),
        (gun_x - back - 4, gun_y + 11), outline=INK)
    a.l("#a2a8ae", (gun_x - back - 1, gun_y + 2), (gun_x + reach - 1, gun_y - 3))
    a.l("#667d92", (gun_x - 6, gun_y + 4), (gun_x + reach, gun_y))
    a.p("#212532", (gun_x - 10, gun_y + 6), (gun_x - 5, gun_y + 6), (gun_x - 7, gun_y + 13), (gun_x - 11, gun_y + 13), outline=INK)
    a.p(uniform, (gun_x - 17, gun_y + 7), (gun_x - 16, gun_y + 4), (gun_x - 11, gun_y + 3), (gun_x - 10, gun_y + 6),
        (gun_x - 13, gun_y + 9), (gun_x - 16, gun_y + 10), outline=INK)
    a.l(light, (gun_x - 15, gun_y + 6), (gun_x - 12, gun_y + 4))
    if pose == "windup":
        windup_halo(a, (gun_x + reach + 1, gun_y - 2), index)
    if pose == "attack":
        x, y = gun_x + reach, gun_y - 2
        length = 11 if index == 1 else 7
        a.p("#ff854e", (x - 2, y), (x + 2, y - 3), (x + 3, y - length), (x + 5, y - 4), (x + length, y - 2),
            (x + 6, y + 1), (x + length, y + 6), (x + 3, y + 3), (x + 1, y + 6))
        a.p("#fff1bb", (x - 1, y), (x + 3, y - 3), (x + 6, y - 1), (x + 5, y + 2), (x + 2, y + 2))
        a.point((x - 1, y - length), fill="#f1a769")
    if pose == "hurt":
        a.l("#f37470", (18, 28), (22, 30), (24, 35), width=2)
        a.l("#f47d70", (43, 45), (47, 48), (50, 48))
        for x, y in ((12, 23), (18, 31), (9, 29), (47, 43), (52, 52)):
            a.r("#ea5665", x, y, x + 1, y + 1)
    body.image.alpha_composite(a.image, (sway, bob))
    return body


def material(base, contrast, seed, pattern):
    a = Art((128, 128))
    rng = random.Random(seed)
    for y in range(128):
        for x in range(128):
            u, v = x * math.tau / 128, y * math.tau / 128
            tone = pattern(u, v, x, y) + rng.uniform(-0.22, 0.22)
            tone += (BAYER[y % 4][x % 4] - 7.5) / 63
            a.draw.point((x, y), fill=tuple(max(0, min(255, round(channel + tone * span))) for channel, span in zip(base, contrast)))
    return a


def panel(a, x, y, w, h, edges, fill=None):
    dark, bright, line = edges
    if fill:
        a.r(fill, x + 2, y + 2, x + w - 3, y + h - 3)
    a.l(dark, (x, y + h - 1), (x, y), (x + w - 1, y))
    a.l(line, (x + w - 1, y + 1), (x + w - 1, y + h - 1), (x + 1, y + h - 1))
    a.l(bright, (x + 1, y + h - 2), (x + 1, y + 1), (x + w - 2, y + 1))


def screws(a, points, bright, dark):
    for x, y in points:
        a.r(dark, x - 1, y - 1, x + 1, y + 1)
        a.l(bright, (x - 1, y - 1), (x, y - 1), (x + 1, y))


def textures():
    folder = "textures"

    def marble(u, v, x, y):
        bend = math.sin(v + 0.67 * math.sin(2 * u)) + 0.55 * math.sin(2 * u - v)
        vein = abs(math.sin(2 * u - 2 * v + 1.25 * bend))
        filigree = abs(math.sin(3 * u - 4 * v + 1.1 * bend))
        return 0.24 * bend - 0.87 * max(0, 1 - vein * 7) - 0.43 * max(0, 1 - filigree * 14)

    a = material((168, 187, 195), (48, 52, 47), 4, marble)
    edges = ("#718a9c", "#becdd2", "#8c9eab")
    for y in (0, 64):
        for x in (0, 64):
            panel(a, x, y, 64, 64, edges)
    a.save(folder, "f1_marble_floor", opaque=True)

    a = material((138, 157, 171), (14, 15, 15), 5, lambda u, v, x, y: 0.4 * math.cos(2 * v) + 0.22 * (y % 3))
    for y in (0, 64):
        panel(a, 0, y, 128, 64, ("#586879", "#afc2ce", "#768e9d"))
        a.l("#738d9f", (2, y + 51), (125, y + 51))
        a.l("#bdd0d9", (2, y + 52), (125, y + 52))
        screws(a, ((7, y + 6), (120, y + 6), (7, y + 57), (120, y + 57)), "#bbd0da", "#607788")
    a.save(folder, "f1_wall_panel", opaque=True)

    a = material((75, 94, 109), (8, 10, 12), 6, lambda u, v, x, y: (x + y) % 3 / 3)
    for y in (0, 32, 64, 96):
        for x in (0, 32, 64, 96):
            panel(a, x, y, 32, 32, ("#303e50", "#718d9d", "#485f73"))
            for line in range(y + 5, y + 28, 3):
                a.l("#455b6d", (x + 3, line), (x + 28, line))
    for x, y in ((32, 0), (96, 64)):
        panel(a, x + 3, y + 7, 26, 18, ("#2d3d4d", "#657e92", "#3e5364"), "#c8dfdc")
        a.r("#e5ede5", x + 6, y + 10, x + 25, y + 19)
        a.l("#a4c4cb", (x + 5, y + 21), (x + 26, y + 21))
        for stripe in range(x + 8, x + 25, 4):
            a.l("#c0d9d8", (stripe, y + 10), (stripe, y + 20))
    a.save(folder, "f1_ceiling_grid", opaque=True)

    a = material((53, 66, 83), (12, 15, 17), 7, lambda u, v, x, y: math.cos(2 * u) * 0.3 + (y % 4) * 0.25)
    a.r("#293343", 0, 0, 127, 5)
    a.r("#293343", 0, 122, 127, 127)
    for x in (0, 64):
        panel(a, x + 5, 5, 54, 118, ("#202b3b", "#61798b", "#35485a"))
        panel(a, x + 13, 19, 38, 76, ("#27384a", "#5c7183", "#33475a"))
        a.p("#576d82", (x + 15, 21), (x + 47, 21), (x + 47, 28), (x + 15, 63))
        a.l("#687f93", (x + 16, 57), (x + 47, 23))
        a.r("#253645", x + 16, 99, x + 47, 108)
        for pos in range(x + 18, x + 48, 6):
            a.p("#8297a3", (pos, 100), (pos + 2, 100), (pos + 5, 107), (pos + 3, 107))
    a.r("#1c2635", 61, 0, 66, 127)
    a.r("#264859", 59, 54, 68, 72, outline="#162536")
    a.r("#70c5c9", 61, 57, 66, 60)
    a.r("#d8eee2", 62, 57, 65, 57)
    a.save(folder, "f1_metal_door", opaque=True)

    def wood(u, v, x, y):
        grain = 37 * v + 1.1 * math.sin(2 * u + v) + 0.55 * math.sin(5 * u)
        return 0.4 * math.cos(4 * v + 0.35 * math.sin(u)) + 0.28 * math.cos(grain) - 0.63 * max(0, math.sin(grain * 1.0) - 0.65)

    a = material((96, 65, 52), (18, 13, 10), 8, wood)
    for y in (0, 64):
        panel(a, 0, y, 128, 64, ("#292938", "#916958", "#423842"))
        a.r("#414857", 2, y + 54, 125, y + 61)
        a.l("#75828b", (2, y + 54), (125, y + 54))
        a.l("#30343e", (2, y + 60), (125, y + 60))
        screws(a, ((6, y + 57), (64, y + 57), (121, y + 57)), "#8694a0", "#282a38")
    a.save(folder, "f1_desk_wood_metal", opaque=True)

    a = Art((128, 128), "#202d3c")
    panel(a, 0, 0, 128, 128, ("#131c2b", "#647a8c", "#334b5b"))
    panel(a, 5, 5, 118, 106, ("#0b1c28", "#456476", "#56768a"), "#162d3c")
    for y in range(8, 109, 2):
        a.l("#1b3946", (8, y), (119, y))
    for x in range(14, 118, 10):
        a.l("#234754", (x, 12), (x, 105))
    a.r("#244858", 13, 12, 114, 20)
    a.draw.text((16, 11), "VOLKOV / SEC 01", fill="#a2dfd6")
    a.r("#101f30", 14, 29, 78, 78, outline="#4e7787")
    a.p("#2b5768", (19, 33), (70, 33), (70, 42), (57, 42), (57, 55), (68, 55), (68, 71), (49, 71),
        (49, 62), (33, 62), (33, 74), (19, 74), outline="#70aabb")
    a.l("#63e3d4", (25, 51), (36, 51), (36, 44), (52, 44))
    a.r("#ef6371", 53, 43, 56, 46)
    for y in range(31, 76, 7):
        a.r("#345568", 85, y, 113, y + 3)
        a.r("#6ea8a8", 86, y + 1, 94 + (y * y) % 16, y + 1)
    a.l("#81c0c6", (13, 95), (35, 95), (41, 89), (56, 91), (66, 83), (74, 97), (82, 88), (91, 92), (114, 92))
    a.draw.text((14, 112), "LINK ACTIVE", fill="#82b6bc")
    a.r("#67c5bd", 109, 116, 114, 119)
    a.save(folder, "f1_security_screen", opaque=True)

    def carpet(u, v, x, y):
        return 0.42 * math.cos(16 * u + 8 * v) + 0.24 * math.cos(16 * u - 8 * v) + 0.29 * math.cos(2 * v) + (x % 2) * 0.3

    a = material((36, 45, 66), (17, 17, 22), 10, carpet)
    for y in (16, 80):
        a.l("#354361", (0, y), (127, y))
        a.l("#60505a", (0, y + 2), (127, y + 2))
        a.l("#332e45", (0, y + 3), (127, y + 3))
        for x in range(0, 128, 4):
            a.point((x, y + 2), fill="#8d655a")
    a.save(folder, "f2_carpet_floor", opaque=True)

    a = material((46, 56, 76), (10, 11, 15), 11, lambda u, v, x, y: 0.48 * math.cos(2 * u) - (y % 3) * 0.08)
    for x in (0, 64):
        panel(a, x, 0, 64, 128, ("#202837", "#596780", "#323c51"))
        panel(a, x + 6, 12, 52, 92, ("#212939", "#53637d", "#2d3a51"))
        a.r("#714942", x + 2, 86, x + 61, 92)
        a.l("#b5704f", (x + 2, 86), (x + 61, 86))
        a.l("#462f38", (x + 2, 92), (x + 61, 92))
        screws(a, ((x + 6, 6), (x + 57, 6), (x + 6, 119), (x + 57, 119)), "#728394", "#2a3043")
    a.save(folder, "f2_wall_office", opaque=True)

    a = Art((128, 128), "#202838")
    rng = random.Random(12)
    for x in (0, 64):
        panel(a, x, 0, 64, 128, ("#111724", "#4a5368", "#30394c"))
        for index, y in enumerate(range(4, 125, 15)):
            panel(a, x + 5, y, 54, 13, ("#151724", "#4f5d74", "#30394e"), "#2c364a")
            for n in range(y + 4, y + 10, 2):
                a.l("#172031", (x + 11, n), (x + 36, n))
            for pos in range(x + 12, x + 37, 4):
                a.point((pos, y + 5), fill="#4d596e")
            a.r("#191f2d", x + 38, y + 4, x + 52, y + 9)
            for led in (40, 44, 48):
                color = rng.choice(("#985746", "#ed905c", "#4da29f", "#557285"))
                a.r(color, x + led, y + 6, x + led + 1, y + 7)
            if index % 3 == 2:
                a.l("#b97450", (x + 9, y + 9), (x + 20, y + 9))
    a.save(folder, "f2_server_rack", opaque=True)


def main():
    aydin(False)
    aydin(True)
    general()
    volkov()
    device()
    village()
    tower()
    for frame in ("idle", "fire_1", "fire_2", "reload_1", "reload_2", "ads"):
        pistol(frame)
    for frame in ("idle", "fire_1", "pump_1", "pump_2", "reload"):
        shotgun(frame)
    for frame in ("idle", "slash_1", "slash_2"):
        blade(frame)
    for frame in (1, 2, 3):
        beta_hand(frame)
    for enemy in ENEMIES:
        for frame in ENEMY_FRAMES:
            enemy_frame(enemy, frame).save("sprites/enemies", f"{enemy}_{frame}")
    textures()


if __name__ == "__main__":
    main()
