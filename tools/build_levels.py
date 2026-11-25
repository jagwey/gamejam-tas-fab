"""Generates scenes/levels/floor_01_lobby.tscn and floor_02_office.tscn.

Run from the project root:  python tools/build_levels.py
All static geometry lives under one Node3D (`Geometry`) as StaticBody3D boxes on
collision layer 1. Resources are referenced by res:// path only (no uid attributes).
"""
from __future__ import annotations

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WALL_T = 0.5
TRIM_H = 0.14  # baseboard height
TRIM_D = 0.05  # baseboard depth off the wall face
RIB_STEP = 4.0  # ceiling rib spacing
RIB_H = 0.22
RIB_W = 0.2
PLINTH_PAD = 0.12


def f(v: float) -> str:
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def v3(x: float, y: float, z: float) -> str:
    return "Vector3(%s, %s, %s)" % (f(x), f(y), f(z))


def col(rgba) -> str:
    return "Color(%s)" % ", ".join(f(c) for c in rgba)


class SceneBuilder:
    def __init__(self) -> None:
        self.ext: list[tuple[str, str, str]] = []  # (type, path, id)
        self.ext_ids: dict[str, str] = {}
        self.subs: list[str] = []
        self.sub_ids: dict[str, str] = {}
        self.nodes: list[str] = []
        self.counter = 0
        self.names: set[str] = set()

    # ---------------------------------------------------------- resources
    def ext_res(self, rtype: str, path: str) -> str:
        if path in self.ext_ids:
            return self.ext_ids[path]
        rid = "%d_%s" % (len(self.ext) + 1, os.path.splitext(os.path.basename(path))[0])
        self.ext.append((rtype, path, rid))
        self.ext_ids[path] = rid
        return rid

    def sub_res(self, key: str, rtype: str, props: list[str]) -> str:
        if key in self.sub_ids:
            return self.sub_ids[key]
        self.counter += 1
        rid = "%s_%d" % (rtype, self.counter)
        body = "\n".join(props)
        self.subs.append('[sub_resource type="%s" id="%s"]\n%s\n' % (rtype, rid, body))
        self.sub_ids[key] = rid
        return rid

    def tex_material(self, name: str, tex: str, tint=(1, 1, 1, 1), scale: float = 0.25,
                     roughness: float = 0.8, metallic: float = 0.0) -> str:
        tid = self.ext_res("Texture2D", "res://assets/textures/%s.png" % tex)
        return self.sub_res("mat:" + name, "StandardMaterial3D", [
            "albedo_color = %s" % col(tint),
            'albedo_texture = ExtResource("%s")' % tid,
            "metallic = %s" % f(metallic),
            "roughness = %s" % f(roughness),
            "uv1_scale = %s" % v3(scale, scale, scale),
            "uv1_triplanar = true",
            "uv1_world_triplanar = true",
            "texture_filter = 0",
        ])

    def glow_material(self, name: str, rgba, energy: float = 2.0) -> str:
        return self.sub_res("mat:" + name, "StandardMaterial3D", [
            "albedo_color = %s" % col(rgba),
            "emission_enabled = true",
            "emission = %s" % col(rgba),
            "emission_energy_multiplier = %s" % f(energy),
        ])

    def box_shape(self, sx: float, sy: float, sz: float) -> str:
        return self.sub_res("shape:%s,%s,%s" % (f(sx), f(sy), f(sz)), "BoxShape3D",
                            ["size = %s" % v3(sx, sy, sz)])

    def box_mesh(self, sx: float, sy: float, sz: float, mat: str) -> str:
        return self.sub_res("mesh:%s,%s,%s:%s" % (f(sx), f(sy), f(sz), mat), "BoxMesh", [
            'material = SubResource("%s")' % mat,
            "size = %s" % v3(sx, sy, sz),
        ])

    # ---------------------------------------------------------- nodes
    def unique(self, name: str) -> str:
        base, n = name, 1
        while name in self.names:
            n += 1
            name = "%s%d" % (base, n)
        self.names.add(name)
        return name

    def node(self, name: str, ntype: str | None, parent: str | None, props: list[str] | None = None,
             instance: str | None = None, groups: list[str] | None = None) -> None:
        head = '[node name="%s"' % name
        if ntype:
            head += ' type="%s"' % ntype
        if parent is not None:
            head += ' parent="%s"' % parent
        if instance:
            head += ' instance=ExtResource("%s")' % instance
        if groups:
            head += " groups=[%s]" % ", ".join('"%s"' % g for g in groups)
        head += "]"
        self.nodes.append(head + ("\n" + "\n".join(props) if props else "") + "\n")

    def solid(self, name: str, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float,
              mat: str, collide: bool = True, parent: str = "Geometry") -> str:
        name = self.unique(name)
        sx, sy, sz = abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)
        c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        if collide:
            self.node(name, "StaticBody3D", parent, ["position = %s" % v3(*c)])
            self.node("Mesh", "MeshInstance3D", "%s/%s" % (parent, name),
                      ['mesh = SubResource("%s")' % self.box_mesh(sx, sy, sz, mat)])
            self.node("Shape", "CollisionShape3D", "%s/%s" % (parent, name),
                      ['shape = SubResource("%s")' % self.box_shape(sx, sy, sz)])
        else:
            self.node(name, "MeshInstance3D", parent, [
                "position = %s" % v3(*c),
                'mesh = SubResource("%s")' % self.box_mesh(sx, sy, sz, mat)])
        return name

    def wall_x(self, name: str, z: float, x0: float, x1: float, h: float, mat: str,
               gaps: list[tuple[float, float, float]] | None = None) -> None:
        """Wall along X at depth z. gaps = [(a, b, lintel_height)]."""
        t = WALL_T / 2
        cuts = sorted(gaps or [])
        cur = x0 - t
        for i, (a, b, lintel) in enumerate(cuts):
            if a > cur:
                self.solid(name, cur, a, 0, h, z - t, z + t, mat)
                self.trim_x(name, z, cur, a)
            if lintel < h:
                self.solid(name + "Lintel", a, b, lintel, h, z - t, z + t, mat)
            cur = b
        if x1 + t > cur:
            self.solid(name, cur, x1 + t, 0, h, z - t, z + t, mat)
            self.trim_x(name, z, cur, x1 + t)

    def wall_z(self, name: str, x: float, z0: float, z1: float, h: float, mat: str,
               gaps: list[tuple[float, float, float]] | None = None) -> None:
        """Wall along Z at x. z0 < z1. gaps = [(a, b, lintel)] with a < b."""
        t = WALL_T / 2
        cuts = sorted(gaps or [])
        cur = z0 - t
        for a, b, lintel in cuts:
            if a > cur:
                self.solid(name, x - t, x + t, 0, h, cur, a, mat)
                self.trim_z(name, x, cur, a)
            if lintel < h:
                self.solid(name + "Lintel", x - t, x + t, lintel, h, a, b, mat)
            cur = b
        if z1 + t > cur:
            self.solid(name, x - t, x + t, 0, h, cur, z1 + t, mat)
            self.trim_z(name, x, cur, z1 + t)

    def room_slabs(self, name: str, x0: float, x1: float, z0: float, z1: float, h: float,
                   floor_mat: str, ceil_mat: str) -> None:
        self.solid(name + "Floor", x0, x1, -0.5, 0, z0, z1, floor_mat)
        t = WALL_T / 2
        self.solid(name + "Ceiling", x0 - t, x1 + t, h, h + 0.3, z0 - t, z1 + t, ceil_mat)
        self.ceiling_ribs(name, x0, x1, z0, z1, h)

    # ------------------------------------------------- visual-only detail (no collision)
    def trim_material(self) -> str:
        return self.sub_res("mat:_trim", "StandardMaterial3D", [
            "albedo_color = %s" % col((0.16, 0.18, 0.21, 1)),
            "metallic = 0.55",
            "roughness = 0.5",
        ])

    def trim_x(self, name: str, z: float, a: float, b: float) -> None:
        """Baseboard trim on both faces of an X-running wall segment (use_collision = false)."""
        if b - a < 0.5:
            return
        t = WALL_T / 2
        m = self.trim_material()
        self.solid(name + "Trim", a, b, 0, TRIM_H, z - t - TRIM_D, z - t, m, collide=False)
        self.solid(name + "Trim", a, b, 0, TRIM_H, z + t, z + t + TRIM_D, m, collide=False)

    def trim_z(self, name: str, x: float, a: float, b: float) -> None:
        """Baseboard trim on both faces of a Z-running wall segment (use_collision = false)."""
        if b - a < 0.5:
            return
        t = WALL_T / 2
        m = self.trim_material()
        self.solid(name + "Trim", x - t - TRIM_D, x - t, 0, TRIM_H, a, b, m, collide=False)
        self.solid(name + "Trim", x + t, x + t + TRIM_D, 0, TRIM_H, a, b, m, collide=False)

    def ceiling_ribs(self, name: str, x0: float, x1: float, z0: float, z1: float, h: float) -> None:
        """Structural ribs under the ceiling, spanning the short axis every RIB_STEP m (no collision)."""
        m = self.trim_material()
        w, d = x1 - x0, z1 - z0
        if min(w, d) < 3.0:
            return
        if d >= w:
            n = int(d // RIB_STEP)
            for i in range(1, n + 1):
                z = z0 + d * i / (n + 1)
                self.solid(name + "Rib", x0, x1, h - RIB_H, h, z - RIB_W / 2, z + RIB_W / 2, m, collide=False)
        else:
            n = int(w // RIB_STEP)
            for i in range(1, n + 1):
                x = x0 + w * i / (n + 1)
                self.solid(name + "Rib", x - RIB_W / 2, x + RIB_W / 2, h - RIB_H, h, z0, z1, m, collide=False)

    def column(self, name: str, x0: float, x1: float, z0: float, z1: float, h: float, mat: str) -> None:
        """Solid column with a visual-only plinth and capital."""
        self.solid(name, x0, x1, 0, h, z0, z1, mat)
        m = self.trim_material()
        p = PLINTH_PAD
        self.solid(name + "Plinth", x0 - p, x1 + p, 0, 0.35, z0 - p, z1 + p, m, collide=False)
        self.solid(name + "Capital", x0 - p, x1 + p, h - 0.3, h, z0 - p, z1 + p, m, collide=False)

    def light(self, name: str, pos, rgba, energy: float = 1.6, rng: float = 11.0) -> None:
        self.node(self.unique(name), "OmniLight3D", "Lights", [
            "position = %s" % v3(*pos),
            "light_color = %s" % col(rgba),
            "light_energy = %s" % f(energy),
            "omni_range = %s" % f(rng),
            "omni_attenuation = 1.2",
            "shadow_enabled = false",
            "distance_fade_enabled = true",
            "distance_fade_begin = 16.0",
            "distance_fade_length = 8.0",
        ])

    def instance(self, name: str, scene: str, parent: str, props: list[str]) -> None:
        rid = self.ext_res("PackedScene", scene)
        self.node(self.unique(name), None, parent, props, instance=rid)

    def environment(self, bg, ambient, ambient_energy: float, fog_rgba) -> None:
        env = self.sub_res("env", "Environment", [
            "background_mode = 1",
            "background_color = %s" % col(bg),
            "ambient_light_source = 2",
            "ambient_light_color = %s" % col(ambient),
            "ambient_light_energy = %s" % f(ambient_energy),
            "tonemap_mode = 2",
            "glow_enabled = true",
            "glow_intensity = 0.55",
            "glow_bloom = 0.05",
            "fog_enabled = true",
            "fog_light_color = %s" % col(fog_rgba),
            "fog_density = 0.012",
        ])
        self.node("WorldEnvironment", "WorldEnvironment", ".", ['environment = SubResource("%s")' % env])

    def write(self, rel_path: str) -> None:
        out = ["[gd_scene format=3]\n"]
        for rtype, path, rid in self.ext:
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (rtype, path, rid))
        out.append("")
        out.extend(self.subs)
        out.extend(self.nodes)
        path = os.path.join(ROOT, rel_path)
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(out))
        print("wrote", rel_path, "nodes:", len(self.nodes), "subs:", len(self.subs))


def rot_y(deg: float) -> str:
    return "rotation_degrees = %s" % v3(0, deg, 0)


def patrol(points) -> str:
    return "patrol_points = Array[Vector3]([%s])" % ", ".join(v3(*p) for p in points)


GUARD = "res://scenes/enemies/enemy_guard_lv1.tscn"
MERC = "res://scenes/enemies/enemy_merc_lv2.tscn"
TECH = "res://scenes/enemies/enemy_tech_lv1.tscn"
PLAYER = "res://scenes/player/player.tscn"
PICKUP = "res://scenes/weapons/pickup_item.tscn"
TERMINAL = "res://scenes/puzzles/lore_terminal.tscn"
DOOR = "res://scenes/puzzles/locked_door.tscn"
EXIT = "res://scenes/puzzles/level_exit.tscn"
CONSOLE = "res://scenes/puzzles/vertical_slice_console.tscn"


def tres_string(s: str) -> str:
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


# ====================================================================== FLOOR 1
def build_floor_01() -> None:
    b = SceneBuilder()
    script = b.ext_res("Script", "res://scripts/systems/floor_01_controller.gd")
    b.node("Floor01Lobby", "Node3D", None, ['script = ExtResource("%s")' % script])
    b.environment((0.02, 0.03, 0.045, 1), (0.55, 0.66, 0.8, 1), 0.42, (0.18, 0.24, 0.32, 1))

    floor_m = b.tex_material("marble", "f1_marble_floor", (0.92, 0.95, 1.0, 1), 0.25, 0.35)
    wall_m = b.tex_material("panel", "f1_wall_panel", (0.86, 0.9, 0.96, 1), 0.25, 0.75)
    ceil_m = b.tex_material("ceiling", "f1_ceiling_grid", (0.8, 0.85, 0.92, 1), 0.25, 0.9)
    desk_m = b.tex_material("desk", "f1_desk_wood_metal", (1, 1, 1, 1), 0.5, 0.6)
    door_m = b.tex_material("metal", "f1_metal_door", (0.8, 0.86, 0.95, 1), 0.5, 0.45, 0.4)
    screen_m = b.tex_material("screen", "f1_security_screen", (1, 1, 1, 1), 0.5, 0.4)
    glow_m = b.glow_material("coldstrip", (0.62, 0.84, 1.0, 1), 2.4)
    warn_m = b.glow_material("warn", (1.0, 0.36, 0.22, 1), 1.8)

    b.node("Geometry", "Node3D", ".")
    b.node("Lights", "Node3D", ".")
    b.node("Enemies", "Node3D", ".")
    b.node("Pickups", "Node3D", ".")
    b.node("Interactables", "Node3D", ".")

    # --- Zone 1: entrance  x -6..6, z -12..0, h 4.5
    b.room_slabs("Entrance", -6, 6, -12, 0, 4.5, floor_m, ceil_m)
    b.wall_x("EntranceSouthWall", 0, -6, 6, 4.5, wall_m)
    b.wall_z("EntranceWestWall", -6, -12, 0, 4.5, wall_m)
    b.wall_z("EntranceEastWall", 6, -12, 0, 4.5, wall_m)
    for ax in (-2.0, 2.0):  # security detector arches
        b.solid("DetectorPost", ax - 0.75, ax - 0.5, 0, 2.4, -8.25, -7.75, door_m)
        b.solid("DetectorPost", ax + 0.5, ax + 0.75, 0, 2.4, -8.25, -7.75, door_m)
        b.solid("DetectorBeam", ax - 0.75, ax + 0.75, 2.4, 2.65, -8.25, -7.75, door_m)
        b.solid("DetectorLamp", ax - 0.2, ax + 0.2, 2.66, 2.74, -8.1, -7.9, warn_m, collide=False)
    b.solid("TurnstileBarrier", -5.75, -2.75, 0, 1.0, -8.15, -7.85, door_m)
    b.solid("TurnstileBarrier", -1.25, 1.25, 0, 1.0, -8.15, -7.85, door_m)
    b.solid("TurnstileBarrier", 2.75, 5.75, 0, 1.0, -8.15, -7.85, door_m)
    b.solid("Bench", -5.6, -4.8, 0, 0.5, -6.0, -2.5, desk_m)
    b.solid("Bench", 4.8, 5.6, 0, 0.5, -6.0, -2.5, desk_m)
    b.solid("EntranceStrip", -0.2, 0.2, 4.42, 4.5, -11, -1, glow_m, collide=False)

    # --- Zone 2: lobby  x -14..14, z -36..-12, h 7
    b.room_slabs("Lobby", -14, 14, -36, -12, 7, floor_m, ceil_m)
    b.wall_x("LobbySouthWall", -12, -14, 14, 7, wall_m, [(-3, 3, 3.5)])
    b.wall_z("WestBoundaryWall", -14, -36, -12, 7, wall_m)
    b.wall_x("NorthBoundaryWall", -36, -14, 14, 7, wall_m)
    b.wall_z("LobbyEastWall", 14, -36, -12, 7, wall_m, [(-28, -22, 4)])
    for cx in (-8, 8):
        for cz in (-18, -30):
            b.column("Column", cx - 0.6, cx + 0.6, cz - 0.6, cz + 0.6, 7, wall_m)
    b.solid("ReceptionDesk", -4, 4, 0, 1.1, -27, -26, desk_m)
    b.solid("ReceptionWing", -4.6, -4, 0, 1.1, -29, -26, desk_m)
    b.solid("ReceptionWing", 4, 4.6, 0, 1.1, -29, -26, desk_m)
    b.solid("CoverCrate", -11.5, -10, 0, 1.2, -23, -21.5, door_m)
    b.solid("CoverCrate", 9.5, 11, 0, 1.2, -33, -31.5, door_m)
    b.solid("CoverCrate", 10, 11.2, 0, 0.9, -17.5, -16.3, door_m)
    b.solid("SecurityWall", -6, 6, 2.6, 5.6, -35.75, -35.7, screen_m, collide=False)
    b.solid("LobbyStrip", -10, 10, 6.92, 7, -24.2, -23.8, glow_m, collide=False)
    b.solid("EastArrow", 13.68, 13.74, 2.2, 2.5, -26.5, -23.5, warn_m, collide=False)

    # --- Zone 3: corridor A  x 14..30, z -28..-22, h 4
    b.room_slabs("CorridorA", 14, 30, -28, -22, 4, floor_m, ceil_m)
    b.wall_x("CorridorANorthWall", -28, 14, 24, 4, wall_m)
    b.wall_x("CorridorASouthWall", -22, 14, 30, 4, wall_m, [(20, 23, 3)])
    b.solid("CorridorAStrip", 15, 29, 3.92, 4, -25.2, -24.8, glow_m, collide=False)
    # booth  x 18..26, z -22..-14, h 4
    b.room_slabs("Booth", 18, 26, -22, -14, 4, floor_m, ceil_m)
    b.wall_z("BoothWestWall", 18, -22, -14, 4, wall_m)
    b.wall_z("BoothEastWall", 26, -22, -14, 4, wall_m)
    b.wall_x("BoothSouthWall", -14, 18, 26, 4, wall_m)
    b.solid("BoothCounter", 18.25, 19.4, 0, 1.0, -21, -15, desk_m)
    b.solid("BoothMonitors", 18.3, 18.4, 1.2, 2.4, -20.5, -15.5, screen_m, collide=False)
    # corridor B  x 24..30, z -50..-28, h 4
    b.room_slabs("CorridorB", 24, 30, -50, -28, 4, floor_m, ceil_m)
    b.wall_z("CorridorBWestWall", 24, -50, -28, 4, wall_m)
    b.wall_z("SharedEastWall", 30, -50, -22, 4, wall_m)
    b.solid("CorridorBStrip", 26.8, 27.2, 3.92, 4, -49, -29, glow_m, collide=False)
    b.solid("CorridorCrate", 24.25, 25.4, 0, 1.1, -40, -38.6, door_m)

    # --- Zone 4: elevator hall  x 16..36, z -66..-50, h 6
    b.room_slabs("ElevatorHall", 16, 36, -66, -50, 6, floor_m, ceil_m)
    b.wall_x("HallSouthWall", -50, 16, 36, 6, wall_m, [(24, 30, 4)])
    b.wall_z("HallWestWall", 16, -66, -50, 6, wall_m)
    b.wall_z("HallEastWall", 36, -66, -50, 6, wall_m)
    b.wall_x("HallNorthWall", -66, 16, 36, 6, wall_m, [(24, 28, 3.2)])
    for cx in (20, 32):
        b.column("HallPillar", cx - 0.7, cx + 0.7, -59, -57.6, 6, wall_m)
    b.solid("HallBarricade", 22, 24.5, 0, 1.15, -55, -54.3, door_m)
    b.solid("HallBarricade", 28, 30.5, 0, 1.15, -61.2, -60.5, door_m)
    b.solid("HallStrip", 18, 34, 5.92, 6, -58.2, -57.8, glow_m, collide=False)
    b.solid("DoorWarn", 24, 28, 3.3, 3.42, -65.74, -65.7, warn_m, collide=False)
    # alcove  x 23..29, z -74..-66, h 3.6
    b.room_slabs("ElevatorAlcove", 23, 29, -74, -66, 3.6, floor_m, ceil_m)
    b.wall_z("AlcoveWestWall", 23, -74, -66, 3.6, wall_m)
    b.wall_z("AlcoveEastWall", 29, -74, -66, 3.6, wall_m)
    b.wall_x("AlcoveNorthWall", -74, 23, 29, 3.6, wall_m)
    b.solid("ElevatorDoors", 24.5, 27.5, 0, 3, -73.75, -73.65, door_m, collide=False)

    # --- lights (13)
    cold = (0.72, 0.84, 1.0, 1)
    white = (0.94, 0.96, 1.0, 1)
    b.light("EntranceLight", (0, 3.8, -3), white, 1.5, 9)
    b.light("EntranceLight", (0, 3.8, -9.5), cold, 1.3, 8)
    b.light("LobbyLight", (-7, 6, -17), cold, 2.0, 14)
    b.light("LobbyLight", (7, 6, -17), cold, 2.0, 14)
    b.light("LobbyLight", (-7, 6, -30), white, 1.8, 14)
    b.light("LobbyLight", (7, 6, -30), cold, 1.8, 14)
    b.light("CorridorALight", (19, 3.5, -25), cold, 1.4, 9)
    b.light("BoothLight", (22, 3.4, -18), (0.85, 0.95, 1.0, 1), 1.4, 8)
    b.light("CorridorBLight", (27, 3.5, -33), cold, 1.3, 9)
    b.light("CorridorBLight", (27, 3.5, -45), cold, 1.3, 9)
    b.light("HallLight", (21, 5.2, -58), cold, 1.8, 13)
    b.light("HallLight", (31, 5.2, -58), white, 1.8, 13)
    b.light("AlcoveLight", (26, 3.1, -70), (0.4, 0.9, 1.0, 1), 1.5, 7)

    # --- player
    b.instance("Player", PLAYER, ".", ["position = %s" % v3(0, 0.05, -2)])

    # --- enemies
    b.instance("LobbyGuardA", GUARD, "Enemies", ["position = %s" % v3(-6, 0, -22), rot_y(180),
               patrol([(0, 0, 0), (10, 0, 0), (10, 0, -6), (0, 0, -6)])])
    b.instance("LobbyGuardB", GUARD, "Enemies", ["position = %s" % v3(6, 0, -32.5),
               patrol([(0, 0, 0), (-10, 0, 0)])])
    b.instance("CorridorGuardA", GUARD, "Enemies", ["position = %s" % v3(17, 0, -25), rot_y(-90),
               patrol([(0, 0, 0), (9, 0, 0)])])
    b.instance("BoothGuard", GUARD, "Enemies", ["position = %s" % v3(23.5, 0, -16), rot_y(180)])
    b.instance("CorridorGuardB", GUARD, "Enemies", ["position = %s" % v3(27, 0, -34), rot_y(180),
               patrol([(0, 0, 0), (0, 0, -8)])])
    b.instance("CorridorMerc", MERC, "Enemies", ["position = %s" % v3(27, 0, -46.5), rot_y(180)])
    b.instance("HallGuardA", GUARD, "Enemies", ["position = %s" % v3(19, 0, -62), rot_y(180),
               patrol([(0, 0, 0), (0, 0, 8)])])
    b.instance("HallGuardB", GUARD, "Enemies", ["position = %s" % v3(33, 0, -54), rot_y(180),
               patrol([(0, 0, 0), (0, 0, -8)])])
    b.instance("HallMerc", MERC, "Enemies", ["position = %s" % v3(26, 0, -63.5), rot_y(180)])

    # --- pickups
    b.instance("ShotgunPickup", PICKUP, "Pickups", ["position = %s" % v3(20.5, 0.9, -18.5),
               "pickup_type = 1", 'weapon_id = "shotgun"', "amount = 12",
               'prompt_override = "[E] POMPALI TÜFEĞİ AL"'])
    b.instance("PistolAmmoPickup", PICKUP, "Pickups", ["position = %s" % v3(23, 0.5, -20.5),
               "pickup_type = 0", 'weapon_id = "pistol"', "amount = 24"])

    lore = ("OPERASYON KAYDI — GÜVENLİK ŞEFLİĞİ\n\n"
            "Viktor Volkov'un ekibi binayı 03:40'ta devraldı. General'in BETA araştırma dosyaları "
            "ve Beta Reaktörü'nün çekirdek modülü 5. kata taşındı.\n\n"
            "Talimat: Lobi hattı kilitli kalacak. Asansör güvenlik kilidi yalnızca hizalama "
            "terminalinden açılabilir. İzinsiz giriş yapan herkes etkisiz hale getirilecek.\n\n"
            "Not: Reaktör çevriminin tamamlanmasına 6 saat var. Volkov, sızıntıyı engellemek için "
            "tüm iletişimi kesti. Dışarıdan yardım gelmeyecek.")
    b.instance("SecurityLoreTerminal", TERMINAL, "Interactables", [
        "position = %s" % v3(24.5, 0, -14.75), rot_y(180),
        'terminal_title = "Volkov Raporu — Beta Reaktörü"',
        "terminal_body = %s" % tres_string(lore)])
    b.instance("ElevatorSecurityDoor", DOOR, "Interactables", ["position = %s" % v3(26, 0, -66)])
    b.instance("LevelExit", EXIT, "Interactables", ["position = %s" % v3(26, 0, -71.5),
               "target_floor = 2"])
    b.node("TestWallMarker", "Marker3D", ".", ["position = %s" % v3(-14, 1, -24)])
    b.write("scenes/levels/floor_01_lobby.tscn")


# ====================================================================== FLOOR 2
def build_floor_02() -> None:
    b = SceneBuilder()
    script = b.ext_res("Script", "res://scripts/systems/floor_02_controller.gd")
    b.node("Floor02Office", "Node3D", None, ['script = ExtResource("%s")' % script])
    b.environment((0.012, 0.016, 0.04, 1), (0.3, 0.36, 0.6, 1), 0.38, (0.12, 0.1, 0.16, 1))

    carpet = b.tex_material("carpet", "f2_carpet_floor", (1, 1, 1, 1), 0.25, 0.95)
    wall = b.tex_material("office", "f2_wall_office", (1, 1, 1, 1), 0.25, 0.8)
    ceil = b.tex_material("ceil2", "f1_ceiling_grid", (0.32, 0.36, 0.52, 1), 0.25, 0.9)
    rack = b.tex_material("rack", "f2_server_rack", (1, 1, 1, 1), 0.5, 0.5, 0.3)
    desk = b.tex_material("desk2", "f1_desk_wood_metal", (0.85, 0.72, 0.6, 1), 0.5, 0.6)
    metal = b.tex_material("metal2", "f1_metal_door", (0.45, 0.5, 0.7, 1), 0.5, 0.5, 0.4)
    warm = b.glow_material("warmstrip", (1.0, 0.58, 0.24, 1), 2.4)
    blue = b.glow_material("bluestrip", (0.3, 0.5, 1.0, 1), 2.0)

    b.node("Geometry", "Node3D", ".")
    b.node("Lights", "Node3D", ".")
    b.node("Enemies", "Node3D", ".")
    b.node("Pickups", "Node3D", ".")
    b.node("Interactables", "Node3D", ".")

    # vestibule x -4..4, z -8..0, h 4
    b.room_slabs("Vestibule", -4, 4, -8, 0, 4, carpet, ceil)
    b.wall_x("VestibuleSouthWall", 0, -4, 4, 4, wall)
    b.wall_z("VestibuleWestWall", -4, -8, 0, 4, wall)
    b.wall_z("VestibuleEastWall", 4, -8, 0, 4, wall)
    b.wall_x("VestibuleNorthWall", -8, -4, 4, 4, wall, [(-3, 3, 3.8)])
    b.solid("ElevatorDoorsBack", -1.6, 1.6, 0, 3, -0.3, -0.24, metal, collide=False)
    # corridor x -3..3, z -30..-8, h 3.8
    b.room_slabs("Corridor", -3, 3, -30, -8, 3.8, carpet, ceil)
    b.wall_z("CorridorWestWall", -3, -30, -8, 3.8, wall, [(-20, -16, 3)])
    b.wall_z("CorridorEastWall", 3, -30, -8, 4.2, wall, [(-24, -20, 3)])
    b.solid("CorridorStrip", -0.2, 0.2, 3.72, 3.8, -29, -9, warm, collide=False)
    # office west x -17..-3, z -26..-12, h 3.8
    b.room_slabs("Office", -17, -3, -26, -12, 3.8, carpet, ceil)
    b.wall_z("OfficeWestWall", -17, -26, -12, 3.8, wall)
    b.wall_x("OfficeNorthWall", -26, -17, -3, 3.8, wall)
    b.wall_x("OfficeSouthWall", -12, -17, -3, 3.8, wall)
    for dx, dz in ((-14, -15), (-9, -15), (-14, -22), (-9, -22)):
        b.solid("OfficeDesk", dx - 1.2, dx + 1.2, 0, 0.8, dz - 0.6, dz + 0.6, desk)
        b.solid("DeskPartition", dx - 1.2, dx + 1.2, 0.8, 1.5, dz - 0.65, dz - 0.55, metal)
    b.solid("OfficeStrip", -15, -5, 3.72, 3.8, -19.2, -18.8, warm, collide=False)
    # archive east x 3..15, z -28..-14, h 4.2
    b.room_slabs("Archive", 3, 15, -28, -14, 4.2, carpet, ceil)
    b.wall_z("ArchiveEastWall", 15, -28, -14, 4.2, wall)
    b.wall_x("ArchiveNorthWall", -28, 3, 15, 4.2, wall)
    b.wall_x("ArchiveSouthWall", -14, 3, 15, 4.2, wall)
    for rx in (7.5, 11.5):
        b.solid("ServerRack", rx - 0.5, rx + 0.5, 0, 2.3, -27.5, -23.5, rack)
        b.solid("ServerRack", rx - 0.5, rx + 0.5, 0, 2.3, -18.5, -14.5, rack)
    b.solid("ArchiveStrip", 6, 13, 4.12, 4.2, -21.2, -20.8, blue, collide=False)
    # executive x -5..5, z -40..-30, h 4.5
    b.room_slabs("Executive", -5, 5, -40, -30, 4.5, carpet, ceil)
    b.wall_x("ExecutiveSouthWall", -30, -5, 5, 4.5, wall, [(-3, 3, 3.8)])
    b.wall_z("ExecutiveWestWall", -5, -40, -30, 4.5, wall)
    b.wall_z("ExecutiveEastWall", 5, -40, -30, 4.5, wall)
    b.wall_x("ExecutiveNorthWall", -40, -5, 5, 4.5, wall)
    b.solid("ExecutiveDesk", -2.5, 2.5, 0, 0.85, -36.2, -35.2, desk)
    b.solid("ExecutiveRack", -4.75, -3.75, 0, 2.3, -39.5, -36.5, rack)
    b.solid("ExecutiveRack", 3.75, 4.75, 0, 2.3, -39.5, -36.5, rack)
    b.solid("ExecutiveStrip", -3, 3, 4.42, 4.5, -39.6, -39.4, warm, collide=False)

    warm_c = (1.0, 0.66, 0.36, 1)
    blue_c = (0.42, 0.55, 1.0, 1)
    b.light("VestibuleLight", (0, 3.4, -4), warm_c, 1.4, 8)
    b.light("CorridorLight", (0, 3.3, -13), warm_c, 1.3, 9)
    b.light("CorridorLight", (0, 3.3, -25), blue_c, 1.2, 9)
    b.light("OfficeLight", (-13, 3.3, -18), warm_c, 1.6, 10)
    b.light("OfficeLight", (-7, 3.3, -23), blue_c, 1.1, 9)
    b.light("ArchiveLight", (9.5, 3.6, -21), blue_c, 1.7, 11)
    b.light("ArchiveLight", (13, 3.6, -16), warm_c, 1.0, 7)
    b.light("ExecutiveLight", (0, 4, -35), warm_c, 1.7, 10)

    b.instance("Player", PLAYER, ".", ["position = %s" % v3(0, 0.05, -2)])

    b.instance("OfficeTech", TECH, "Enemies", ["position = %s" % v3(-11.5, 0, -18.5), rot_y(-90),
               patrol([(0, 0, 0), (-4, 0, 0)])])
    b.instance("ArchiveMerc", MERC, "Enemies", ["position = %s" % v3(9.5, 0, -25), rot_y(90),
               patrol([(0, 0, 0), (0, 0, 8)])])
    b.instance("ExecutiveMerc", MERC, "Enemies", ["position = %s" % v3(-2.5, 0, -33.5)])

    b.instance("OfficeAmmoPickup", PICKUP, "Pickups", ["position = %s" % v3(-14, 1.0, -22),
               "pickup_type = 0", 'weapon_id = "pistol"', "amount = 24"])
    b.instance("ArchiveShellsPickup", PICKUP, "Pickups", ["position = %s" % v3(13.5, 0.5, -26.5),
               "pickup_type = 0", 'weapon_id = "shotgun"', "amount = 6"])

    lore = ("ARŞİV KAYDI — BETA ARAŞTIRMA DOSYASI #0417\n\n"
            "General'in laboratuvarından çalınan BETA araştırmasının tüm kopyaları bu sunuculardan "
            "Volkov'un özel ağına aktarıldı. BETA Cihazı'nın biyolojik enerji dönüşüm verisi şifresiz.\n\n"
            "Kat 5'teki Beta Reaktörü savunma ağı Kat 3 ve 4'teki röle istasyonlarından besleniyor. "
            "Röleler düşerse reaktör kalkanı devre dışı kalır.\n\n"
            "Volkov'a not: Ajan Aydın binada. Lobi hattı rapor vermiyor.")
    b.instance("ArchiveLoreTerminal", TERMINAL, "Interactables", [
        "position = %s" % v3(14.5, 0, -21), rot_y(-90),
        'terminal_title = "Çalınan BETA Araştırması"',
        "terminal_body = %s" % tres_string(lore)])
    b.instance("VerticalSliceConsole", CONSOLE, "Interactables", ["position = %s" % v3(0, 0, -38.6)])
    b.write("scenes/levels/floor_02_office.tscn")


if __name__ == "__main__":
    # Floor 2+ are generated by tools/build_full_levels.py (circuit puzzle +
    # Floor 3 exit). build_floor_02() is kept for reference only — running it
    # would overwrite the current floor_02_office.tscn.
    build_floor_01()
