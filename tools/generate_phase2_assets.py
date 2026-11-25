"""Draw the three Phase 2 floors, their enemies and the ending in Pillow."""

import math
import random
from dataclasses import dataclass

from PIL import Image

from generate_assets import Art, ENEMY_FRAMES, INK, death_pose, gradient, material, panel, screws, windup_halo


@dataclass(frozen=True)
class Suit:
    size: tuple[int, int]
    armor: tuple[str, str, str, str]
    accent: tuple[str, str, str]
    power: tuple[str, str, str]


SUITS = {
    "heavy_lv3": Suit((64, 96), ("#1b2a35", "#586b73", "#a9b9b5", "#e8ebd7"),
                      ("#135246", "#2c8863", "#77c580"), ("#167e57", "#53ee8b", "#dcffd1")),
    "commando_lv4": Suit((64, 96), ("#181422", "#35303f", "#5a5064", "#8b7987"),
                         ("#481429", "#922541", "#e46063"), ("#a35e35", "#f9b750", "#fff3ad")),
    "volkov_boss": Suit((96, 128), ("#1c2434", "#39465a", "#66778a", "#a5bbbe"),
                        ("#4c1732", "#9a294b", "#ed586b"), ("#1966b0", "#43cfff", "#e1fbff")),
}


def armor_leg(a, suit, x, hip_y, foot_x, sole, width):
    dark, mid, light, edge = suit.armor
    knee = (x + foot_x) // 2
    joint = (hip_y + sole) // 2
    a.p(dark, (x - width, hip_y), (x + width, hip_y + 1), (knee + width - 1, joint),
        (foot_x + width - 3, sole - 7), (foot_x + width + 3, sole - 4),
        (foot_x + width + 2, sole), (foot_x - width, sole),
        (foot_x - width - 1, sole - 4), (knee - width, joint + 2), outline=INK)
    a.p(mid, (x - width + 2, hip_y + 3), (x + width - 1, hip_y + 4),
        (knee + width - 2, joint - 2), (knee - width + 1, joint))
    a.p(light, (x - width + 2, hip_y + 4), (x - 1, hip_y + 4),
        (knee - 1, joint - 3), (knee - width + 2, joint - 2))
    a.p(mid, (knee - width + 2, joint + 3), (knee + width - 2, joint + 2),
        (foot_x + width - 4, sole - 6), (foot_x - width + 2, sole - 7))
    a.p(light, (knee - width + 1, joint - 2), (knee + width - 2, joint - 2),
        (knee + width - 3, joint + 2), (knee, joint + 5), (knee - width + 1, joint + 2),
        outline=INK)
    a.l(edge, (knee - width + 2, joint - 1), (knee + 1, joint - 1))
    a.l(suit.accent[1], (knee - 1, joint + 7), (foot_x - 1, sole - 7))
    a.l(mid, (foot_x - width + 1, sole - 2), (foot_x + width, sole - 2),
        (foot_x + width + 1, sole - 1))


def heavy(a, suit, recoil, charged, *, armed=True):
    dark, mid, light, edge = suit.armor
    green, enamel, stripe = suit.accent
    low, glow, hot = suit.power
    a.p(dark, (13, 30), (24, 24), (40, 24), (51, 30), (49, 51),
        (44, 62), (35, 67), (22, 64), (18, 56), (13, 48), outline=INK)
    a.p(light, (19, 30), (28, 26), (36, 27), (45, 27), (47, 40),
        (41, 49), (32, 54), (23, 47), (19, 40), outline=INK)
    a.p(edge, (21, 31), (27, 28), (36, 29), (44, 28), (45, 32),
        (37, 35), (29, 34), (24, 36))
    a.p(green, (24, 39), (31, 41), (43, 35), (45, 39), (41, 46),
        (33, 50), (26, 47), outline=INK)
    a.l(enamel, (26, 43), (33, 46), (41, 41), width=2)
    a.dither(mid, 6, (23, 36), (29, 35), (31, 39), (25, 41))
    a.p(mid, (25, 53), (32, 56), (42, 50), (43, 57), (36, 62),
        (28, 61), (24, 59), outline=INK)
    a.l(light, (27, 58), (34, 59), (39, 56))
    for i in range(3):
        a.l(stripe, (29 + i * 4, 56 - i), (29 + i * 4, 58 - i))
    a.p(mid, (9, 28), (18, 23), (25, 27), (25, 34), (20, 40),
        (17, 51), (22, 57), (19, 63), (11, 62), (6, 53), (6, 40), outline=INK)
    a.p(light, (7, 34), (10, 28), (18, 24), (24, 27), (21, 35), (13, 41), (8, 40), outline=INK)
    a.l(edge, (9, 34), (13, 28), (18, 26), (22, 28), width=2)
    a.l(green, (11, 42), (15, 41), (17, 39), width=2)
    a.p(enamel, (8, 50), (12, 48), (16, 51), (20, 57), (18, 60), (12, 59), outline=INK)
    a.l(stripe, (10, 50), (13, 50), (16, 54))
    a.p(light, (43, 28), (49, 24), (55, 26), (58, 34), (54, 39),
        (46, 38), (42, 33), outline=INK)
    a.l(edge, (45, 28), (50, 26), (55, 29))
    a.p(mid, (23, 11), (28, 7), (37, 7), (44, 12), (45, 19),
        (40, 27), (33, 29), (25, 25), (21, 19), outline=INK)
    a.p(light, (24, 12), (28, 8), (36, 8), (42, 12), (42, 16),
        (34, 14), (25, 17), outline=INK)
    a.l(edge, (26, 12), (30, 10), (36, 10), (40, 12))
    a.p(dark, (25, 17), (32, 15), (42, 16), (42, 20), (37, 24),
        (30, 23), (26, 21), outline=INK)
    a.l(low, (27, 18), (33, 17), (40, 18), width=2)
    a.l(glow, (28, 18), (34, 17), (40, 18))
    a.r(hot, 33, 17, 35, 17)
    a.l(mid, (29, 25), (34, 26), (39, 24))
    a.l(edge, (38, 19), (40, 17))
    if armed:
        return cannon(a, suit, 47, 54 + recoil, charged, False)
    a.p(mid, (45, 39), (51, 38), (55, 48), (54, 54), (48, 56), (43, 51), outline=INK)
    a.l(light, (49, 40), (52, 46), (51, 52))


def commando(a, suit, recoil, charged, *, armed=True):
    dark, mid, light, edge = suit.armor
    wine, red, scarlet = suit.accent
    gold, glow, hot = suit.power
    a.p(dark, (19, 29), (26, 24), (41, 24), (47, 32), (44, 49),
        (41, 62), (33, 68), (24, 63), (20, 54), (15, 44), outline=INK)
    a.p(mid, (23, 28), (31, 25), (40, 28), (44, 37), (40, 50),
        (30, 53), (22, 45), outline=INK)
    a.dither(light, 6, (25, 31), (34, 29), (41, 34), (39, 41), (26, 43))
    a.p(wine, (15, 27), (23, 26), (27, 34), (22, 50), (20, 66),
        (14, 74), (15, 65), (9, 69), (10, 55), (13, 42), outline=INK)
    a.p(red, (16, 28), (22, 28), (24, 32), (19, 45), (17, 57),
        (14, 66), (15, 52), (14, 45), outline=INK)
    a.l(scarlet, (16, 47), (18, 38), (20, 34))
    a.l(gold, (11, 65), (13, 59), (13, 52))
    a.p(wine, (39, 26), (47, 26), (53, 33), (51, 43), (53, 57),
        (58, 66), (52, 65), (53, 70), (44, 64), (41, 48), outline=INK)
    a.l(red, (44, 29), (49, 32), (49, 42), (50, 57), (55, 64), width=2)
    a.l(gold, (23, 31), (30, 36), (35, 37), (43, 32))
    a.p(gold, (32, 35), (35, 34), (38, 36), (35, 40), outline=INK)
    a.point((35, 36), fill=hot)
    a.p(light, (24, 51), (31, 53), (39, 51), (39, 55), (31, 58), (25, 56), outline=INK)
    a.r(glow, 32, 54, 35, 55, outline=gold)
    a.p(wine, (20, 19), (21, 11), (27, 6), (38, 6), (45, 12), (46, 19), (41, 28),
        (35, 32), (29, 28), (24, 25), outline=INK)
    a.p(dark, (23, 16), (26, 11), (32, 9), (39, 10), (44, 15), (42, 24),
        (36, 29), (30, 26), (24, 23), outline=INK)
    a.l(scarlet, (22, 15), (25, 10), (29, 8), (37, 8), (43, 12))
    a.p(light, (25, 17), (31, 16), (34, 18), (34, 21), (30, 23), (26, 22), outline=INK)
    a.p(mid, (36, 18), (41, 16), (44, 17), (43, 21), (38, 23), (36, 21), outline=INK)
    a.l(glow, (27, 19), (30, 18), (32, 19), width=2)
    a.l(glow, (38, 20), (41, 18))
    a.point((29, 19), fill=hot)
    a.point((41, 19), fill=hot)
    a.l(edge, (30, 24), (34, 26), (38, 25))
    y = 48 + recoil
    a.p(dark, (14, 39), (20, 38), (23, 44), (26, y - 2), (37, y - 4),
        (40, y + 1), (33, y + 5), (22, y + 7), (15, 49), outline=INK)
    a.l(light, (17, 43), (22, y + 3), (31, y + 1))
    if not armed:
        a.p(mid, (45, 41), (48, 40), (51, 48), (54, 52), (51, 57), (47, 55), (43, 48), outline=INK)
        return None
    a.p(mid, (27, y - 4), (43, y - 6), (47, y - 4), (53, y - 4), (55, y - 2),
        (54, y + 2), (43, y + 2), (38, y + 8), (34, y + 7), (35, y + 3), (27, y + 3), outline=INK)
    a.l(light, (29, y - 3), (42, y - 5), (48, y - 3), (53, y - 3))
    a.l(glow if charged else gold, (34, y - 1), (41, y - 2), (48, y - 2))
    a.r(wine, 48, y - 1, 51, y + 1)
    a.r(hot if charged else red, 53, y - 2, 54, y)
    return 55, y - 1


def volkov(a, suit, recoil, charged, *, armed=True):
    dark, mid, light, edge = suit.armor
    wine, red, scarlet = suit.accent
    low, glow, hot = suit.power
    a.p(dark, (15, 40), (29, 25), (44, 24), (58, 26), (78, 38), (82, 53),
        (71, 66), (69, 81), (55, 91), (37, 91), (25, 78), (22, 62), (12, 53), outline=INK)
    a.p(mid, (23, 40), (32, 31), (42, 30), (55, 31), (70, 40), (68, 58),
        (61, 68), (49, 76), (34, 69), (24, 57), outline=INK)
    a.p(light, (26, 42), (34, 34), (42, 33), (49, 40), (58, 34), (67, 40),
        (61, 44), (51, 47), (42, 42), (33, 47))
    a.dither(edge, 5, (29, 41), (34, 35), (42, 34), (46, 39), (36, 43))
    a.p(mid, (29, 69), (42, 75), (50, 78), (62, 72), (66, 77), (59, 83),
        (49, 85), (35, 81), outline=INK)
    a.l(light, (33, 75), (42, 79), (49, 81), (59, 78), width=2)
    for side in (-1, 1):
        x = 48 + side * 14
        a.l(INK, (x, 43), (x + side * 6, 49), (x + side * 6, 60), (x, 69), width=4)
        a.l(low, (x, 43), (x + side * 6, 49), (x + side * 6, 60), (x, 69), width=2)
        a.l(glow, (x + side * 6, 51), (x + side * 6, 56))
    a.p(dark, (40, 44), (53, 43), (61, 49), (62, 59), (55, 68),
        (45, 70), (36, 61), (36, 52), outline=INK)
    a.p(low, (42, 47), (53, 46), (58, 51), (58, 59), (53, 65),
        (45, 66), (40, 60), (39, 53))
    a.p(glow, (45, 49), (52, 48), (56, 52), (55, 59), (51, 64), (45, 62), (42, 57), (43, 52))
    a.p(hot, (47, 50), (51, 50), (53, 54), (51, 59), (47, 61), (46, 56), (44, 55))
    a.p(mid, (8, 43), (13, 36), (25, 37), (27, 49), (23, 57),
        (19, 65), (23, 69), (21, 79), (12, 83), (6, 78),
        (6, 69), (3, 62), outline=INK)
    a.p(light, (8, 53), (14, 49), (21, 51), (17, 63), (19, 67),
        (13, 71), (7, 65), outline=INK)
    a.p(mid, (8, 69), (18, 68), (21, 73), (17, 78), (12, 80), (8, 77), outline=INK)
    a.l(edge, (9, 73), (13, 71), (17, 71))
    a.l(red, (10, 77), (15, 77), width=2)
    for side in (-1, 1):
        x = 48 + side * 24
        a.p(wine, (x - 14, 35), (x - 8, 27), (x + 5, 26), (x + 14, 32), (x + 15, 40),
            (x + 12, 49), (x + 3, 51), (x - 8, 47), (x - 14, 42), outline=INK)
        a.p(red, (x - 12, 35), (x - 7, 28), (x + 4, 27), (x + 12, 32),
            (x + 12, 38), (x + 4, 42), (x - 5, 40), (x - 11, 42))
        a.l(scarlet, (x - 11, 35), (x - 6, 30), (x + 3, 29), (x + 10, 33), width=2)
        a.dither(scarlet, 6, (x - 8, 36), (x + 1, 31), (x + 9, 33), (x + 3, 37), (x - 4, 38))
        a.r(mid, x - 4, 44, x + 4, 46, outline=INK)
    a.p(dark, (34, 12), (39, 6), (53, 5), (62, 10), (64, 21), (61, 30),
        (54, 37), (44, 36), (35, 31), (32, 22), outline=INK)
    a.p(mid, (35, 14), (40, 8), (52, 7), (59, 11), (61, 17), (54, 16),
        (45, 16), (37, 20))
    a.l(light, (36, 14), (41, 9), (51, 8), (57, 11), width=2)
    a.p(wine, (35, 20), (44, 19), (50, 22), (61, 18), (61, 23),
        (56, 27), (49, 28), (39, 26), outline=INK)
    a.l("#ff3e57", (37, 22), (44, 22), (50, 24), (59, 21), width=2)
    a.l("#ffb1a2", (42, 22), (47, 23))
    a.l("#ffb1a2", (52, 23), (58, 21))
    a.p(mid, (39, 28), (47, 31), (54, 31), (60, 26), (57, 32),
        (53, 35), (44, 34), outline=INK)
    a.l(light, (45, 32), (51, 33), (55, 31))
    if armed:
        return cannon(a, suit, 72, 65 + recoil, charged, True)
    a.p(mid, (68, 51), (76, 48), (82, 53), (87, 66), (84, 75), (77, 77),
        (70, 70), (72, 62), outline=INK)
    a.l(light, (77, 52), (81, 57), (83, 64), width=2)


def cannon(a, suit, x, y, charged, boss):
    dark, mid, light, edge = suit.armor
    low, glow, hot = suit.power
    width, height = (16, 13) if boss else (11, 9)
    left, right = x - width, x + width
    top, base = y - height, y + height
    a.p(dark, (left, y - 3), (left + 3, top + 3), (x - 6, top), (right - 6, top),
        (right, top + 3), (right, base - 3), (right - 5, base),
        (x - 8, base + 2), (left, base - 3), outline=INK)
    a.p(mid, (left + 2, y - 4), (x - 6, top + 2), (right - 6, top + 2),
        (right - 4, y - 6), (x + 2, y + 6), (left + 2, y + 5))
    a.l(light, (left + 3, y - 4), (x - 5, top + 2), (right - 7, top + 2), width=2)
    a.l(edge, (x - 5, top + 2), (x + 4, top + 2))
    a.dither(light, 5, (left + 3, y), (x - 3, top + 4), (x + 7, top + 5), (x + 5, y))
    for index in range(3):
        a.l(INK, (left + 3 + index * 3, y + 2), (left + 4 + index * 3, y + 7), width=2)
        a.l(glow if charged else low, (left + 4 + index * 3, y + 2), (left + 5 + index * 3, y + 7))
    a.p(light, (right - 9, top + 4), (right - 3, top + 4), (right + 1, y - 4),
        (right + 1, y + 5), (right - 3, base - 2), (right - 8, base - 3),
        (right - 11, y + 4), (right - 11, y - 4), outline=INK)
    a.e(dark, right - 9, y - 6, right - 1, y + 6)
    a.e(glow if charged else low, right - 8, y - 4, right - 2, y + 4)
    a.e(hot if charged else dark, right - 7, y - 3, right - 3, y + 3)
    if charged:
        a.r("#fff4d9", right - 6, y - 1, right - 4, y + 1)
    return right - 4, y


def discharge(a, suit, x, y, pose, index, commando_suit):
    low, glow, hot = suit.power
    width = suit.size[0]
    is_boss = width == 96
    if pose == "hurt":
        for dx, dy in ((-29, -17), (-25, -13), (-18, -23), (-8, -17), (-3, -22)):
            a.l("#f35069", (x + dx, y + dy), (x + dx + 3, y + dy - 4))
            a.point((x + dx + 3, y + dy - 4), fill="#fed8ad")
    elif pose == "windup":
        windup_halo(a, (x, y), index)
        if is_boss:
            a.l(low, (8, 105), (22, 99), (51, 96), (70, 98), (88, 104))
            a.l(glow, (3, 111), (16, 107), (30, 106), (41, 104))
            if index == 2:
                a.l(low, (22, 77), (29, 72), (35, 71), (44, 62), (50, 60), width=2)
                a.l(glow, (52, 53), (58, 48), (65, 47), (71, 41), (85, 43))
                a.l(hot, (31, 72), (35, 71), (43, 64))
                a.l(glow, (29, 98), (35, 96), (48, 96), (55, 95), (66, 97))
                a.l(hot, (71, 104), (82, 106), (93, 110))
    elif pose == "attack":
        max_reach = (13 if is_boss else 9) if index == 1 else 7
        reach = min(max_reach, width - 2 - x)
        height = 13 if is_boss else 8
        if commando_suit:
            low, glow, hot = "#a02639", "#ffb845", "#fff2ae"
        a.p(low, (x - 2, y), (x - 1, y - height), (x + 3, y - 4),
            (x + reach, y - height + 2), (x + 7, y), (x + reach, y + height - 3),
            (x + 3, y + 5), (x - 1, y + height))
        a.p(glow, (x - 2, y + 1), (x + 1, y - 5), (x + 4, y - 2),
            (x + reach, y - 4), (x + 5, y + 1), (x + reach - 2, y + 5),
            (x + 2, y + 4), (x, y + 6))
        a.p(hot, (x - 2, y + 1), (x + 2, y - 2), (x + 7, y), (x + 2, y + 3))
        a.point((x + reach - 1, y - height - 1), fill=hot)


def corpse(suit, enemy, drained, *, charged=True):
    w, h = suit.size
    big = w == 96
    dark, mid, light, edge = suit.armor
    deep, trim, stripe = suit.accent
    a = Art(suit.size)
    a.e((20, 13, 24, 125), 2, h - 12, w - 3, h - 1)
    x, y = w // 2, h - 17
    spread = 12 if big else 7
    a.p(dark, (3, h - 10), (8, h - 18), (15, h - 19), (x - 11, y - 5),
        (x - 4, y - 11), (x + 10, y - 7), (x + 16, y - 8),
        (w - 10, y - 7), (w - 4, y - 2), (w - 3, y + 6),
        (w - 8, y + 10), (x + 6, y + 10), (x - 8, y + 9),
        (15, h - 4), (5, h - 5), outline=INK)
    a.p(mid, (5, h - 12), (10, h - 17), (15, h - 16), (x - 9, y - 5),
        (x - 6, y + 1), (x - 15, y + 5), (14, h - 8), (7, h - 7), outline=INK)
    a.l(light, (9, h - 14), (15, h - 14), (x - 11, y - 4))
    a.p(mid, (x - 13, y + 1), (x - 5, y - 6), (x + spread, y - 7),
        (x + spread + 5, y), (x + 9, y + 7), (x - 4, y + 8), outline=INK)
    a.p(light, (x - 10, y + 1), (x - 3, y - 4), (x + spread, y - 5),
        (x + 11, y + 1), (x + 3, y + 4), (x - 6, y + 4))
    a.dither(mid, 7, (x - 10, y + 1), (x + 3, y - 3), (x + 13, y), (x + 5, y + 5), (x - 6, y + 4))
    a.p(trim, (x + 3, y - 8), (x + 9, y - 11), (x + spread + 8, y - 8),
        (x + spread + 10, y - 3), (x + 10, y + 1), (x + 4, y - 2), outline=INK)
    a.l(stripe, (x + 5, y - 7), (x + 9, y - 9), (x + spread + 6, y - 7))
    a.p(mid, (w - 17, y - 3), (w - 13, y - 8), (w - 8, y - 7),
        (w - 4, y - 2), (w - 4, y + 4), (w - 10, y + 6), (w - 16, y + 4), outline=INK)
    a.l(edge, (w - 15, y - 3), (w - 12, y - 6), (w - 8, y - 5))
    a.l(deep if not big else "#922844", (w - 12, y - 1), (w - 8, y + 1), (w - 5, y + 1), width=2)
    if enemy == "commando_lv4":
        a.p(deep, (x - 12, y + 1), (x + 4, y + 2), (x + 9, y + 7),
            (x - 5, y + 10), (x - 22, y + 9), (x - 18, y + 6), outline=INK)
        a.l(trim, (x - 19, y + 8), (x - 9, y + 7), (x + 3, y + 8))
        a.l("#bc844c", (x - 16, y + 7), (x - 10, y + 6))
    else:
        cannon(a, suit, x + (11 if big else 4), y + 4, False, False)
    if drained:
        gray = a.image.convert("L").point(lambda value: (value * 3) // 4 + 8)
        ash = gray.point(lambda value: min(255, value + 4))
        a.image = Image.merge("RGBA", (gray, gray, ash, a.image.getchannel("A")))
    elif charged:
        a.l("#b52e58", (x - 7, y + 1), (x - 2, y - 5), (x + 1, y - 7), width=2)
        for dx, dy, r in ((0, -10, 2), (5, -17, 3), (-4, -20, 1), (-8, -13, 1), (12, -23, 1)):
            a.e((152, 20, 63, 125), x + dx - r - 2, y + dy - r - 2, x + dx + r + 2, y + dy + r + 2)
            a.e("#e13e62", x + dx - r, y + dy - r, x + dx + r, y + dy + r)
            a.point((x + dx, y + dy), fill="#ffc4a4")
    return a


def enemy_sprite(enemy, suit, body, frame):
    pose, number = frame.split("_")
    if pose == "corpse":
        return corpse(suit, enemy, number == "drained")
    index = int(number)
    if pose == "death":
        torso = Art(suit.size)
        body(torso, suit, 7, False, armed=False)
        return death_pose(torso, corpse(suit, enemy, False, charged=False), suit.armor, index)
    w, h = suit.size
    big = w == 96
    a = Art(suit.size)
    step = (-7, -3, 7, 3)[index - 1] if pose == "walk" else 0
    sway = (-2, 1, 3, -1)[index - 1] if pose == "walk" else -2 if pose == "hurt" else 0
    bob = 2 if pose == "hurt" else -2 if pose == "windup" else index % 2
    recoil = -3 + index if pose == "attack" else -3 if pose == "windup" else 1 if pose == "walk" else 0
    a.e((13, 12, 23, 96), 10, h - 7, w - 11, h - 1)
    for side in (1, -1):
        hips = (13 if big else 7) * side
        foot = w // 2 + (16 if big else 9) * side + side * step
        sole = h - 3 - max(0, side * step // 2)
        width = 10 if big else 6 if enemy == "commando_lv4" else 8
        armor_leg(a, suit, w // 2 + hips + sway, (77 if big else 58) + bob, foot, sole, width)
    upper = Art(suit.size)
    x, y = body(upper, suit, recoil, pose == "windup" or pose == "attack")
    a.image.alpha_composite(upper.image, (sway, bob))
    discharge(a, suit, x + sway, y + bob, pose, index, enemy == "commando_lv4")
    return a


def portrait():
    a = Art((64, 64), density=2.5)
    gradient(a, (15, 19, 33), (91, 25, 53))
    a.dither("#b64059", 5, (0, 42), (63, 5), (63, 24), (0, 57))
    a.l("#7b324e", (0, 44), (63, 9))
    a.l("#ae405b", (9, 46), (63, 17))
    a.p("#87304d", (0, 62), (8, 50), (15, 47), (11, 33), (17, 34),
        (20, 20), (20, 14), (28, 8), (37, 5), (46, 8), (52, 14), (53, 24),
        (51, 39), (57, 33), (62, 36), (56, 49), (63, 54), (63, 63), (0, 63))
    a.p(INK, (0, 63), (8, 52), (19, 49), (13, 35), (19, 37), (22, 22), (22, 16),
        (29, 9), (37, 7), (44, 9), (50, 14), (52, 23), (49, 41),
        (56, 36), (60, 35), (56, 48), (63, 56), (63, 63))
    a.p("#252a3e", (0, 63), (10, 54), (23, 50), (31, 55), (39, 57),
        (49, 49), (56, 51), (63, 58), (63, 63))
    a.p("#a26b68", (22, 22), (28, 16), (43, 15), (48, 18), (50, 24), (47, 32),
        (48, 37), (44, 47), (38, 52), (32, 50), (27, 46), (23, 39),
        (21, 36), (19, 29), (21, 27), outline=INK)
    a.p("#d09279", (27, 23), (34, 18), (43, 17), (48, 20), (48, 26), (44, 30),
        (46, 35), (47, 38), (43, 44), (38, 46), (33, 43), (35, 38), (31, 36), (29, 30))
    a.p("#eeb298", (28, 23), (34, 19), (42, 18), (46, 22), (39, 22),
        (34, 23), (29, 26))
    a.p("#604657", (22, 29), (26, 25), (30, 31), (31, 36), (34, 41),
        (33, 48), (29, 46), (25, 40), (24, 36))
    a.dither("#ba7776", 7, (25, 30), (28, 31), (31, 38), (33, 44), (29, 44), (26, 39))
    a.p("#53515c", (22, 20), (23, 15), (29, 10), (37, 7), (45, 10),
        (49, 15), (51, 21), (46, 18), (42, 16), (37, 16), (31, 19),
        (27, 24), (24, 29), (22, 28), outline=INK)
    a.p("#8a8687", (25, 18), (29, 13), (36, 10), (42, 11), (45, 14),
        (38, 13), (32, 16), (29, 20), (25, 23))
    a.l("#cac0b6", (25, 17), (29, 13), (35, 11), (39, 11))
    a.l("#ec7580", (45, 11), (49, 15), (50, 18))
    a.p(INK, (27, 28), (31, 26), (36, 28), (39, 30), (36, 32), (31, 31), (28, 30))
    a.p(INK, (41, 29), (45, 26), (48, 25), (48, 28), (45, 30), (42, 31))
    a.l("#e7c6ae", (29, 29), (34, 29), (37, 30))
    a.l("#ffd6b6", (43, 29), (46, 28))
    a.r("#567482", 33, 29, 34, 30)
    a.point((46, 28), fill="#7e5f64")
    a.p("#754856", (39, 31), (38, 35), (36, 38), (41, 40), (44, 38), (42, 35), (42, 32))
    a.l("#f9c4a5", (41, 31), (41, 35), (43, 38))
    a.l("#864e5b", (45, 20), (44, 24), (43, 26))
    a.l("#f2a18b", (46, 20), (45, 24), (44, 26))
    a.l("#854753", (42, 31), (44, 33), (44, 36), (46, 39), (45, 43))
    a.l("#eea090", (43, 31), (45, 33), (45, 36), (47, 39))
    a.p("#634753", (27, 43), (34, 45), (38, 42), (43, 42), (46, 40),
        (44, 46), (38, 51), (33, 49), (29, 47))
    a.p("#301e2b", (33, 44), (37, 42), (40, 42), (42, 43), (44, 43),
        (42, 44), (38, 44), (35, 45))
    a.l("#be7b75", (36, 47), (40, 46))
    a.l("#fd7183", (49, 26), (47, 32), (48, 36))
    a.p("#3c445a", (11, 36), (22, 40), (28, 49), (31, 57), (28, 63),
        (20, 59), (15, 51), outline=INK)
    a.p("#606f87", (14, 38), (21, 41), (24, 47), (22, 52), (18, 49))
    a.l("#adbec3", (14, 39), (20, 42), (24, 48))
    a.p("#3c374d", (38, 63), (44, 50), (50, 44), (58, 36), (57, 44),
        (54, 52), (51, 58), (47, 63), outline=INK)
    a.p("#633750", (44, 60), (47, 52), (54, 45), (57, 39), (55, 47), (51, 53))
    a.l("#d4536f", (43, 60), (48, 51), (54, 45), (57, 40))
    a.l("#62b3d1", (20, 56), (24, 59), (26, 62))
    a.l("#722940", (51, 57), (57, 57), (62, 61), width=2)
    a.save("portraits", "volkov_portrait", opaque=True)


def helicopter(a, x, y, small=False):
    width = 10 if small else 17
    tail = 18 if small else 29
    shadow = "#141b2d"
    steel = "#33445c" if small else "#455b73"
    edge = "#697d8f" if small else "#9faaba"
    a.p(shadow, (x - width, y + 2), (x - width + 2, y - 3), (x - 3, y - 6),
        (x + 6, y - 5), (x + width, y - 2), (x + tail, y - 6),
        (x + tail + 2, y - 10), (x + tail + 4, y - 9), (x + tail + 2, y - 3),
        (x + 9, y + 4), (x - 4, y + 6), outline="#101527")
    a.p(steel, (x - width + 2, y + 1), (x - width + 4, y - 3), (x - 3, y - 5),
        (x + 6, y - 4), (x + 8, y - 1), (x + 1, y + 3), (x - 7, y + 4))
    a.p("#aab5b6", (x - width + 3, y), (x - width + 5, y - 3),
        (x - 4, y - 3), (x - 6, y), (x - 10, y + 1))
    a.l("#394960", (x - width + 4, y), (x - width + 7, y - 3))
    a.l(edge, (x + 7, y - 1), (x + tail, y - 5), (x + tail + 2, y - 8))
    a.l("#121827", (x - 1, y - 6), (x - 1, y - 8), width=2)
    a.l("#1b2537", (x - width - 8, y - 8), (x - 1, y - 9), (x + width + 8, y - 8), width=2)
    a.l(edge, (x - width - 6, y - 9), (x - 3, y - 9))
    a.l("#181c2b", (x - width + 4, y + 7), (x + 5, y + 7), (x + 9, y + 5))
    a.point((x + 8, y + 3), fill="#f25d74")
    a.point((x - width + 3, y + 4), fill="#fff2bf")


def rooftop():
    a = Art((160, 90), density=3)
    rng = random.Random(113)
    gradient(a, (20, 24, 46), (72, 88, 115))
    a.p("#22273f", (0, 0), (159, 0), (159, 12), (140, 17), (102, 15),
        (76, 20), (54, 19), (32, 26), (9, 25), (0, 22))
    a.p("#303b56", (0, 24), (21, 25), (52, 20), (82, 22), (96, 19),
        (135, 21), (159, 16), (159, 23), (126, 27), (89, 24), (56, 28), (0, 33))
    a.dither("#52617a", 6, (0, 26), (17, 27), (49, 22), (75, 25), (103, 24), (48, 32), (0, 36))
    a.l("#73829b", (102, 12), (105, 14), (101, 20), (105, 20), (103, 27))
    a.l("#a0a6b8", (103, 13), (106, 14), (102, 20), (105, 20))
    for depth, color in ((0, "#404d67"), (1, "#2b344c"), (2, "#1c263a")):
        x = 0
        while x < 160:
            w = rng.randint(4, 10)
            y = rng.randint(37 + depth * 4, 51 + depth * 5)
            a.r(color, x, y, x + w, 65)
            if w >= 7:
                a.l(color, (x + 4, y - rng.randint(1, 6)), (x + 4, y))
            for window_y in range(y + 3, 62, 4):
                for window_x in range(x + 2, min(x + w, 160), 3):
                    if rng.random() < .31:
                        a.point((window_x, window_y), fill=rng.choice(("#977e79", "#687b8c", "#bf9b83")))
            x += w + 1
    for x, y, far in ((131, 25, True), (48, 35, False)):
        source = x - (7 if far else 14)
        a.dither("#a8afbd", 4 if far else 7, (source, y + 3), (source + 3, y + 3),
                 (source + 16, 66), (source - 20, 66))
        a.dither("#e0d8b8", 4, (source - 1, y + 4), (source + 1, y + 4),
                 (source + 4, 66), (source - 10, 66))
        helicopter(a, x, y, far)
    a.p("#202a3c", (0, 65), (39, 58), (126, 58), (159, 64), (159, 89), (0, 89))
    a.p("#333e55", (0, 73), (41, 62), (123, 62), (159, 70), (159, 73),
        (120, 65), (47, 65), (0, 78))
    a.l("#768297", (0, 65), (39, 58), (126, 58), (159, 64))
    a.dither("#59647a", 5, (0, 83), (51, 67), (113, 65), (159, 76), (159, 89), (0, 89))
    for x in (13, 31, 50, 68, 89, 111, 133, 151):
        a.l("#182134", (80 + (x - 80) // 2, 60), (x, 89))
    a.l("#536076", (8, 78), (39, 70), (115, 70), (150, 77))
    a.l("#637085", (11, 82), (39, 75), (103, 75), (125, 78))
    for x, y in ((8, 77), (32, 81), (131, 75), (139, 83), (59, 88), (111, 87), (22, 85)):
        a.l("#616e83", (x, y), (x + rng.randint(5, 12), y))
    a.p(INK, (58, 81), (64, 75), (66, 56), (72, 47), (87, 45),
        (99, 50), (103, 56), (105, 74), (115, 80), (112, 84), (59, 84))
    a.p("#414959", (61, 81), (66, 76), (104, 75), (112, 80), (107, 82), (65, 82))
    a.p("#566277", (68, 56), (74, 48), (86, 46), (98, 51), (102, 57),
        (103, 74), (98, 78), (72, 78), (66, 74), outline="#273348")
    a.p("#1b3049", (73, 57), (78, 52), (88, 51), (96, 55), (98, 60),
        (97, 73), (92, 75), (78, 75), (73, 72), outline="#111927")
    a.p("#304d62", (76, 57), (81, 54), (91, 54), (95, 57), (95, 70),
        (92, 73), (77, 73), (75, 70))
    a.dither("#63879b", 5, (77, 58), (83, 55), (89, 55), (92, 61), (84, 64), (76, 63))
    a.l("#78a2b1", (77, 70), (77, 58), (81, 55))
    a.l("#233a50", (82, 59), (88, 61), (89, 66), (83, 69))
    a.l("#6a354a", (66, 66), (65, 73))
    a.l("#652e43", (100, 63), (101, 72))
    a.r("#7a5665", 100, 68, 101, 69)
    a.l("#8491a0", (71, 51), (75, 48), (85, 47), (92, 49))

    # Crisp 480x270 OVA stormy rooftop evacuation details.
    hi = a.native()
    # Spinning rotor blur lines & crisp helicopter strobes.
    hi.l("#8ca0b5", (64, 78), (222, 78))
    hi.l("#6d7f96", (332, 48), (446, 48))
    hi.r("#ff5c77", 168, 114, 170, 116)
    hi.r("#fff6cf", 98, 117, 100, 119)
    hi.r("#ff5c77", 418, 84, 420, 86)
    # Powered-down reactor dome metallic cooling ribs & dimming blue glow.
    for ry in range(178, 224, 7):
        hi.l("#223a52", (230, ry), (284, ry))
        hi.l("#7cb4c4", (234, ry + 1), (256, ry + 1))
    hi.l("#c2e4eb", (232, 212), (232, 176), (244, 166))
    # Wet rooftop puddle sheen & helipad markings.
    for px, py, pw in ((26, 232, 34), (96, 246, 42), (344, 242, 46), (408, 250, 32)):
        hi.l("#7a8ea6", (px, py), (px + pw, py))
        hi.l("#47556c", (px + 4, py + 2), (px + pw - 6, py + 2))
    # Crisp 1px rain streaks across the 480x270 canvas.
    for _ in range(250):
        rx, ry = rng.randrange(480), rng.randrange(270)
        if 176 < rx < 340 and 136 < ry < 256 and rng.random() < 0.72:
            continue
        length = rng.choice((5, 8, 11))
        hi.l(rng.choice(("#5b6d8a", "#7587a3", "#98a8bc")), (rx, ry), (rx - length // 3, ry + length))
    a.save("sprites/cutscenes", "bg_ending_rooftop", opaque=True)


def village():
    a = Art((160, 90), density=3)
    rng = random.Random(114)
    gradient(a, (62, 56, 94), (255, 174, 115))
    a.p("#d58a85", (0, 30), (22, 27), (35, 22), (53, 23), (74, 18), (96, 20),
        (117, 15), (143, 17), (159, 13), (159, 17), (129, 21), (100, 22), (69, 24),
        (49, 28), (20, 32), (0, 33))
    a.l("#edac8e", (5, 32), (20, 31), (52, 27), (69, 24))
    a.l("#ffcf9b", (82, 30), (99, 27), (119, 29), (135, 26), (154, 27))
    a.e("#f3b784", 95, 23, 126, 54)
    a.e("#ffd798", 99, 27, 122, 50)
    a.e("#fff0b7", 103, 30, 118, 47)
    a.p("#a46978", (0, 51), (18, 41), (25, 37), (34, 38), (48, 31), (55, 33),
        (67, 41), (79, 41), (89, 46), (103, 43), (115, 43), (129, 37), (138, 36),
        (148, 41), (159, 45), (159, 63), (0, 63))
    a.p("#d58e87", (13, 43), (25, 37), (34, 38), (48, 31), (55, 33),
        (62, 38), (55, 36), (50, 35), (43, 38), (39, 42), (29, 41), (25, 40))
    a.p("#ce8f83", (108, 44), (129, 37), (138, 36), (148, 41), (138, 39),
        (133, 39), (128, 42), (119, 43))
    a.dither("#e3a190", 5, (30, 41), (48, 34), (61, 38), (71, 43), (58, 41), (47, 45), (33, 44))
    a.p("#7a6876", (0, 53), (16, 46), (33, 46), (48, 48), (63, 50), (76, 55),
        (92, 53), (111, 48), (128, 45), (142, 46), (159, 52), (159, 73), (0, 73))
    a.p("#b3837f", (75, 53), (93, 51), (113, 46), (128, 44), (141, 46), (157, 51),
        (133, 48), (111, 51), (98, 54), (88, 56))
    a.p("#655e64", (0, 59), (17, 52), (37, 54), (54, 58), (65, 61), (85, 62),
        (105, 58), (131, 54), (144, 55), (159, 59), (159, 79), (0, 79))
    a.p("#92846e", (0, 66), (18, 60), (44, 61), (61, 66), (83, 67), (117, 60),
        (142, 58), (159, 62), (159, 89), (0, 89))
    a.p("#b99873", (16, 64), (36, 62), (53, 64), (71, 68), (94, 66), (112, 62),
        (144, 60), (158, 63), (143, 63), (111, 66), (89, 71), (61, 72), (39, 67))
    a.p("#626451", (0, 70), (25, 67), (46, 73), (69, 75), (92, 73), (120, 70),
        (141, 66), (159, 69), (159, 89), (0, 89))
    a.p("#c29a71", (82, 67), (92, 67), (84, 72), (90, 76),
        (107, 80), (127, 89), (112, 89), (99, 83), (81, 78), (79, 73))
    a.dither("#edb789", 5, (82, 72), (87, 74), (90, 77), (109, 81), (123, 89),
             (112, 89), (98, 83), (81, 77))
    for x, y, w, wall in ((41, 60, 11, "#bb9374"), (51, 63, 10, "#cfaa87"),
                          (65, 59, 13, "#c59c7e"), (77, 65, 10, "#cdab84"),
                          (92, 61, 13, "#d7ae89"), (105, 64, 12, "#bf9576"),
                          (35, 67, 12, "#cca588"), (59, 69, 15, "#d2ab89")):
        a.r("#806671", x, y, x + w - 1, y + 5)
        a.r(wall, x + 1, y + 1, x + w - 3, y + 4)
        a.p("#6d4453", (x - 1, y + 1), (x + 2, y - 3), (x + w - 3, y - 3),
            (x + w, y), (x + w - 2, y + 1))
        a.l("#a85d58", (x + 1, y), (x + 3, y - 2), (x + w - 4, y - 2))
        a.l("#ca7c63", (x + 4, y - 2), (x + w - 4, y - 2))
        a.r("#655660", x + 3, y + 2, x + 4, y + 3)
    # Slender minaret in the center of the settlement.
    a.r("#c9a58a", 88, 54, 89, 64)
    a.r("#836173", 90, 54, 90, 64)
    a.p("#6a5368", (88, 54), (89, 49), (90, 54))
    a.l("#7c5c6b", (87, 58), (91, 58))
    a.p("#494b42", (0, 81), (14, 75), (31, 76), (51, 81), (65, 89), (0, 89))
    a.p("#464b40", (121, 89), (136, 79), (159, 74), (159, 89))
    for x, y, height in ((12, 79, 12), (15, 80, 8), (131, 79, 8), (141, 81, 11),
                         (150, 79, 16), (154, 80, 11), (23, 76, 6)):
        a.p("#364546", (x - 2, y), (x - 2, y - height // 2), (x, y - height),
            (x + 2, y - height // 2), (x + 2, y))
        a.l("#66704e", (x - 1, y - height + 3), (x - 1, y - 2))

    # Crisp 480x270 OVA golden sunrise valley details.
    hi = a.native()
    # Soaring morning bird silhouettes & subtle sunlit cloud rims.
    hi.l("#ffe5b4", (18, 94), (66, 91), (156, 80), (208, 72))
    hi.l("#ffecc2", (360, 58), (414, 52), (476, 42))
    for bx, by in ((116, 46), (130, 52), (142, 43), (222, 62), (236, 56)):
        hi.l("#6a4c67", (bx - 5, by + 1), (bx - 2, by - 2), (bx, by))
        hi.l("#6a4c67", (bx, by), (bx + 2, by - 2), (bx + 5, by + 1))
    # Chimney smoke wisps & crisp sunlit roof highlights.
    for cx, cy in ((136, 173), (206, 170), (290, 176), (192, 198)):
        hi.l("#f5ccb0", (cx, cy), (cx + 3, cy - 8), (cx + 1, cy - 16), (cx + 4, cy - 22))
    hi.l("#ffe3b0", (266, 163), (266, 190))
    # Crisp meadow grass blades, sunlit rim tips & wildflower flecks.
    for _ in range(210):
        gx, gy = rng.randrange(480), rng.randrange(222, 270)
        if 240 < gx < 380 and gx < 244 + (gy - 220) * 3:
            continue
        color = rng.choice(("#9e9072", "#7d775d", "#cfa574", "#545b46", "#f2c280"))
        hi.l(color, (gx, gy), (gx + rng.choice((-1, 0, 1)), gy - rng.randint(2, 5)))
    a.save("sprites/cutscenes", "bg_ending_village", opaque=True)


def save_tile(a, name):
    # Share edge texels so even a mesh using clamped UVs can abut another tile.
    pixels = a.image.load()
    for y in range(128):
        shared = tuple((a + b) // 2 for a, b in zip(pixels[0, y], pixels[127, y]))
        pixels[0, y] = pixels[127, y] = shared
    for x in range(128):
        shared = tuple((a + b) // 2 for a, b in zip(pixels[x, 0], pixels[x, 127]))
        pixels[x, 0] = pixels[x, 127] = shared
    a.save("textures", name, opaque=True)


def lab_textures():
    a = material((159, 181, 174), (25, 27, 23), 31,
                 lambda u, v, x, y: 0.37 * math.cos(2 * u) + 0.25 * math.cos(4 * v))
    for y in (0, 32, 64, 96):
        for x in (0, 32, 64, 96):
            panel(a, x, y, 32, 32, ("#283946", "#d6ded1", "#607771"))
            a.p("#a2b7ac", (x + 4, y + 5), (x + 24, y + 4),
                (x + 27, y + 8), (x + 25, y + 16), (x + 4, y + 19))
            a.dither("#b7c9ba", 7, (x + 4, y + 4), (x + 27, y + 4),
                     (x + 27, y + 12), (x + 4, y + 20))
            a.l("#77968e", (x + 6, y + 26), (x + 26, y + 26))
            if (x + y) % 64:
                a.l("#2a6a58", (x + 13, y + 27), (x + 19, y + 27), width=2)
                a.l("#6fc49a", (x + 14, y + 27), (x + 18, y + 27))
            screws(a, ((x + 5, y + 5), (x + 26, y + 24)), "#e1e9d9", "#607a76")
    save_tile(a, "f3_lab_floor")

    a = material((83, 109, 105), (20, 25, 22), 32,
                 lambda u, v, x, y: 0.6 * math.cos(2 * u) + 0.19 * math.sin(32 * v))
    for x in (0, 64):
        panel(a, x, 0, 64, 128, ("#1b2a37", "#7d9c97", "#233d45"))
        panel(a, x + 4, 11, 56, 78, ("#273b46", "#c3d9c9", "#4b6667"), "#9aafa6")
        a.p("#bac9b8", (x + 7, 15), (x + 55, 15), (x + 55, 23),
            (x + 43, 29), (x + 21, 29), (x + 7, 37))
        a.dither("#ccd8c8", 6, (x + 7, 15), (x + 55, 15), (x + 55, 23), (x + 7, 37))
        panel(a, x + 10, 37, 44, 39, ("#253743", "#bfd0bf", "#526d67"), "#607c78")
        for line in range(44, 70, 4):
            a.l("#30484c", (x + 15, line), (x + 42, line), width=2)
            a.l("#87a599", (x + 15, line + 2), (x + 42, line + 2))
        a.r("#354b4d", x + 8, 93, x + 55, 108, outline="#263440")
        for i in range(9):
            a.l("#4a715f", (x + 12 + i * 5, 98), (x + 12 + i * 5, 104), width=2)
        a.l("#68cb93", (x + 12, 97), (x + 26, 97), width=2)
        screws(a, ((x + 7, 7), (x + 56, 7), (x + 7, 116), (x + 56, 116)), "#bed5c5", "#2b464a")
    save_tile(a, "f3_lab_wall")

    a = material((28, 49, 52), (13, 21, 22), 33,
                 lambda u, v, x, y: 0.59 * math.cos(3 * u) + 0.3 * math.cos(16 * v))
    panel(a, 7, 0, 114, 128, ("#111f29", "#587670", "#233e45"))
    a.p("#1a302f", (20, 21), (33, 13), (96, 13), (108, 22),
        (108, 104), (97, 115), (30, 115), (20, 103), outline=INK)
    a.p("#185f48", (26, 31), (33, 24), (94, 24), (101, 31),
        (101, 97), (94, 104), (33, 104), (26, 97))
    a.p("#3b9562", (28, 45), (39, 42), (59, 46), (72, 43), (87, 44),
        (98, 41), (98, 92), (91, 100), (38, 100), (29, 93))
    a.l("#7bd68c", (28, 45), (39, 42), (59, 46), (72, 43), (87, 44), (98, 41))
    a.p("#246a56", (54, 68), (63, 56), (72, 54), (79, 62), (77, 72),
        (70, 79), (75, 84), (70, 94), (62, 96), (62, 86), (57, 81))
    a.dither("#8fbf7a", 7, (29, 50), (49, 54), (56, 75), (48, 100), (37, 100), (29, 93))
    a.dither("#1c5b49", 7, (78, 47), (98, 43), (98, 92), (91, 99), (82, 98), (88, 74))
    rng = random.Random(341)
    for _ in range(24):
        x, y, r = rng.randrange(32, 96), rng.randrange(46, 96), rng.choice((1, 1, 2, 3))
        a.e("#286b53", x - r, y - r, x + r, y + r)
        a.draw.arc((x - r, y - r, x + r, y + r), 183, 286, fill="#a0e8a1")
    a.l("#a5e4a9", (31, 75), (31, 35), (36, 29))
    a.l("#68ac7d", (34, 54), (34, 36))
    a.l("#5faf8e", (95, 70), (95, 91), (90, 97))
    for y in (5, 105):
        panel(a, 14, y, 100, 18, ("#172833", "#93aea0", "#324b50"), "#607d77")
        a.l("#b8cabc", (21, y + 4), (107, y + 4))
        a.l("#334e50", (21, y + 12), (107, y + 12), width=2)
        screws(a, ((24, y + 8), (103, y + 8)), "#cdd5bf", "#314b4d")
    save_tile(a, "f3_bio_tube")


def vip_textures():
    a = material((101, 24, 44), (19, 10, 14), 41,
                 lambda u, v, x, y: 0.42 * math.cos(16 * u + 16 * v) + 0.32 * math.cos(8 * v))
    for y in range(16, 128, 32):
        for x in range(16, 128, 32):
            a.p("#4d1830", (x, y - 14), (x + 14, y), (x, y + 14), (x - 14, y),
                outline="#a46b4b")
            a.p("#85233d", (x, y - 11), (x + 11, y), (x, y + 11), (x - 11, y),
                outline="#b2824e")
            a.p("#cf9e5e", (x, y - 7), (x + 2, y - 2), (x + 7, y), (x + 2, y + 2),
                (x, y + 7), (x - 2, y + 2), (x - 7, y), (x - 2, y - 2))
            a.p("#f3c984", (x, y - 4), (x + 1, y), (x, y + 3), (x - 1, y))
            for dx, dy in ((-10, -10), (-10, 10), (10, -10), (10, 10)):
                a.l("#b37c55", (x + dx - 2, y + dy), (x + dx, y + dy - 2),
                    (x + dx + 2, y + dy))
    save_tile(a, "f4_red_carpet")

    def marble(u, v, x, y):
        bend = 1.19 * math.sin(2 * u + v) + 0.74 * math.cos(u - 2 * v)
        broad = abs(math.sin(2 * u - 3 * v + bend))
        fine = abs(math.sin(3 * u - 4 * v + 2 * bend))
        return 0.38 * bend + max(0, 1 - broad * 6) * 0.75 + max(0, 1 - fine * 18) * 0.50

    a = material((28, 23, 33), (19, 16, 23), 42, marble)
    for x in (0, 64):
        panel(a, x, 0, 64, 128, ("#1a1422", "#ab764c", "#57394a"))
        for y in (9, 65):
            panel(a, x + 8, y, 48, 49, ("#100e19", "#be8953", "#684232"))
            a.l("#563143", (x + 12, y + 44), (x + 12, y + 4), (x + 51, y + 4))
            for dx in (9, 52):
                a.r("#a87144", x + dx, y + 5, x + dx + 2, y + 8)
                a.point((x + dx + 1, y + 6), fill="#f3c682")
    a.l("#a97546", (0, 61), (127, 61))
    a.l("#4a2c35", (0, 62), (127, 62))
    a.l("#d3a56a", (0, 119), (127, 119))
    a.l("#6a4337", (0, 120), (127, 120), width=2)
    save_tile(a, "f4_vip_wall")

    a = material((99, 24, 48), (18, 10, 11), 43,
                 lambda u, v, x, y: 0.24 * math.cos(2 * u + v) + 0.52 * math.sin(56 * u - 24 * v))
    for y in (9, 117):
        a.l("#4a1934", (0, y - 2), (127, y - 2))
        a.l("#b87c51", (0, y), (127, y))
        a.l("#e0b477", (0, y + 1), (127, y + 1))
        for x in range(2, 128, 8):
            a.point((x, y + 1), fill="#ffe1a3")
    for x, y in ((31, 41), (95, 41), (31, 87), (95, 87)):
        a.p("#7e3142", (x, y - 12), (x + 8, y), (x, y + 12), (x - 8, y),
            outline="#ae754a")
        a.p("#67213b", (x, y - 8), (x + 5, y), (x, y + 8), (x - 5, y),
            outline="#dbab6c")
    save_tile(a, "f4_casino_felt")


def roof_textures():
    a = material((42, 52, 66), (18, 23, 28), 51,
                 lambda u, v, x, y: 0.51 * math.cos(4 * u - v) + 0.22 * math.sin(8 * v))
    rng = random.Random(511)
    for y in range(0, 128, 32):
        for x in range(0, 128, 32):
            panel(a, x, y, 32, 32, ("#171c29", "#647d8d", "#242b3a"))
            for row in range(y + 5, y + 25, 6):
                for ox in (x + 4, x + 16):
                    a.r("#131a29", ox, row, ox + 9, row + 2)
                    a.l("#596b7b", (ox, row + 3), (ox + 9, row + 3))
                    a.l("#9cb2b9", (ox + 2, row + 3), (ox + rng.randrange(3, 9), row + 3))
                if (row + x) % 5 == 0:
                    a.l("#5597bb", (x + 6, row + 4), (x + 10, row + 4))
            screws(a, ((x + 4, y + 27), (x + 27, y + 27)), "#98a9af", "#252d3c")
    save_tile(a, "f5_roof_grate")

    a = material((55, 63, 76), (19, 22, 29), 52,
                 lambda u, v, x, y: 0.65 * math.sin(2 * u) + 0.23 * math.cos(32 * v))
    for x in (0, 64):
        panel(a, x, 0, 64, 128, ("#1f2430", "#667a8a", "#323c4d"))
        panel(a, x + 7, 12, 50, 86, ("#212733", "#7d8a99", "#444c59"))
        a.p("#434b5b", (x + 10, 18), (x + 30, 18), (x + 54, 44), (x + 54, 82),
            (x + 50, 86), (x + 18, 54), (x + 10, 54))
        a.l("#848e9b", (x + 10, 17), (x + 32, 17), (x + 54, 39))
        a.l("#272a36", (x + 10, 54), (x + 18, 54), (x + 49, 86), width=2)
        a.r("#282837", x + 6, 100, x + 58, 113)
        for d in range(7, 52, 9):
            a.p("#683143", (x + d, 103), (x + d + 4, 103),
                (x + d + 8, 109), (x + d + 3, 109))
        a.r("#472a3d", x + 25, 84, x + 39, 90, outline="#1c212d")
        a.l("#d75a68", (x + 29, 87), (x + 35, 87))
        screws(a, ((x + 6, 7), (x + 58, 7), (x + 6, 119), (x + 58, 119)), "#9aa8b1", "#303645")
    save_tile(a, "f5_industrial_wall")

    a = material((26, 35, 56), (18, 24, 35), 53,
                 lambda u, v, x, y: 0.61 * math.cos(3 * u) + 0.35 * math.sin(16 * v))
    panel(a, 5, 0, 118, 128, ("#14182b", "#5b7087", "#20344c"))
    for x in (18, 105):
        a.r("#191526", x - 5, 4, x + 5, 123)
        a.r("#722a42", x - 3, 6, x + 3, 121)
        a.l("#b4455e", (x - 1, 8), (x - 1, 119))
        for y in range(14, 119, 13):
            a.l("#ef6c73", (x - 1, y), (x, y + 4))
    a.p("#1a3658", (37, 16), (90, 16), (96, 27), (96, 102),
        (88, 112), (37, 112), (30, 101), (30, 29), outline="#121c32")
    a.p("#215a8c", (41, 19), (86, 19), (90, 27), (90, 101), (84, 107),
        (41, 107), (36, 98), (36, 29))
    a.p("#278ebd", (48, 21), (78, 21), (85, 29), (85, 97), (78, 106),
        (48, 106), (42, 96), (42, 32))
    a.dither("#69d5f1", 7, (51, 22), (75, 22), (79, 32), (79, 95), (75, 103), (51, 103), (47, 94), (47, 32))
    for y in (31, 50, 70, 90):
        a.p("#182c4d", (29, y), (39, y + 5), (47, y + 7), (80, y + 7),
            (98, y), (98, y + 5), (82, y + 13), (46, y + 13), (29, y + 5), outline="#172238")
        a.l("#3484bb", (31, y + 2), (45, y + 9), (81, y + 9), (96, y + 3), width=2)
        a.l("#78e1f6", (43, y + 8), (80, y + 8), (88, y + 5))
    a.l("#a2f0fb", (63, 24), (60, 39), (66, 52), (59, 70), (67, 84), (63, 103), width=2)
    a.l("#ecf9ef", (63, 27), (60, 39), (66, 52), (59, 68), (67, 84), (63, 100))
    for y in (4, 111):
        panel(a, 26, y, 75, 13, ("#182331", "#748a9f", "#2c415b"), "#4a5f77")
        screws(a, ((33, y + 6), (93, y + 6)), "#b7c4cc", "#17283b")
    save_tile(a, "f5_reactor_core")


def main():
    for enemy, body in (("heavy_lv3", heavy), ("commando_lv4", commando), ("volkov_boss", volkov)):
        for frame in ENEMY_FRAMES:
            enemy_sprite(enemy, SUITS[enemy], body, frame).save("sprites/enemies", f"{enemy}_{frame}")
    portrait()
    rooftop()
    village()
    lab_textures()
    vip_textures()
    roof_textures()


if __name__ == "__main__":
    main()
