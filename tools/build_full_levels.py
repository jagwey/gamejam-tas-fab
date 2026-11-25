"""Generates the full v0.2.0 floor scenes: Kat 2 (office), Kat 3 (lab), Kat 4 (VIP), Kat 5 (rooftop).

Run from the project root:  python tools/build_full_levels.py

Reuses SceneBuilder from tools/build_levels.py. Floors 3-5 never reference Phase 2 textures or
the parallel-built puzzle/boss scenes as ext_resources: their meshes carry solid-colour
StandardMaterial3D fallbacks plus a `tex_*` group, and each floor controller applies the
textures at runtime via ResourceLoader.exists(). Puzzle scenes, the Volkov boss and the
reactor console are likewise attached by the controllers, so the .tscn files always parse.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from build_levels import (  # noqa: E402
    CONSOLE, DOOR, EXIT, GUARD, MERC, PICKUP, PLAYER, TECH, TERMINAL,
    SceneBuilder, col, f, patrol, rot_y, tres_string, v3,
)

HEAVY = "res://scenes/enemies/enemy_heavy_lv3.tscn"
COMMANDO = "res://scenes/enemies/enemy_commando_lv4.tscn"
_ = CONSOLE  # kept importable for older callers


class FullBuilder(SceneBuilder):
    """SceneBuilder with texture-group tagging, cylinders, collision-only blockers and grouped lights."""

    def __init__(self) -> None:
        super().__init__()
        self.mat_groups: dict[str, str] = {}

    # ------------------------------------------------------------ materials
    def color_material(self, name: str, rgba, roughness: float = 0.8, metallic: float = 0.0,
                       group: str | None = None, emission=None, energy: float = 1.0,
                       transparent: bool = False) -> str:
        props = [
            "albedo_color = %s" % col(rgba),
            "metallic = %s" % f(metallic),
            "roughness = %s" % f(roughness),
        ]
        if transparent:
            props.insert(0, "transparency = 1")
        if emission is not None:
            props += [
                "emission_enabled = true",
                "emission = %s" % col(emission),
                "emission_energy_multiplier = %s" % f(energy),
            ]
        mid = self.sub_res("mat:" + name, "StandardMaterial3D", props)
        if group:
            self.mat_groups[mid] = group
        return mid

    def glass_material(self, name: str, rgba) -> str:
        return self.color_material(name, rgba, 0.05, 0.3, transparent=True)

    def _groups_for(self, mat: str, groups: list[str] | None) -> list[str] | None:
        out = list(groups or [])
        if mat in self.mat_groups:
            out.append(self.mat_groups[mat])
        return out or None

    # ------------------------------------------------------------ geometry
    def solid(self, name: str, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float,
              mat: str, collide: bool = True, parent: str = "Geometry",
              groups: list[str] | None = None) -> str:
        name = self.unique(name)
        sx, sy, sz = abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)
        c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        mg = self._groups_for(mat, groups)
        mesh = 'mesh = SubResource("%s")' % self.box_mesh(sx, sy, sz, mat)
        if collide:
            self.node(name, "StaticBody3D", parent, ["position = %s" % v3(*c)])
            self.node("Mesh", "MeshInstance3D", "%s/%s" % (parent, name), [mesh], groups=mg)
            self.node("Shape", "CollisionShape3D", "%s/%s" % (parent, name),
                      ['shape = SubResource("%s")' % self.box_shape(sx, sy, sz)])
        else:
            self.node(name, "MeshInstance3D", parent, ["position = %s" % v3(*c), mesh], groups=mg)
        return name

    def blocker(self, name: str, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> None:
        """Invisible collision-only wall (keeps the player inside open areas)."""
        name = self.unique(name)
        sx, sy, sz = abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)
        c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        self.node(name, "StaticBody3D", "Geometry", ["position = %s" % v3(*c)])
        self.node("Shape", "CollisionShape3D", "Geometry/%s" % name,
                  ['shape = SubResource("%s")' % self.box_shape(sx, sy, sz)])

    def cylinder(self, name: str, x: float, z: float, y0: float, y1: float, r: float, mat: str,
                 collide: bool = True, top_r: float | None = None, segments: int = 16,
                 groups: list[str] | None = None) -> str:
        name = self.unique(name)
        h = y1 - y0
        tr = r if top_r is None else top_r
        mesh_id = self.sub_res("cyl:%s,%s,%s:%s" % (f(r), f(tr), f(h), mat), "CylinderMesh", [
            'material = SubResource("%s")' % mat,
            "top_radius = %s" % f(tr),
            "bottom_radius = %s" % f(r),
            "height = %s" % f(h),
            "radial_segments = %d" % segments,
        ])
        pos = "position = %s" % v3(x, (y0 + y1) / 2, z)
        mg = self._groups_for(mat, groups)
        if collide:
            shape = self.sub_res("cshape:%s,%s" % (f(max(r, tr)), f(h)), "CylinderShape3D", [
                "height = %s" % f(h), "radius = %s" % f(max(r, tr))])
            self.node(name, "StaticBody3D", "Geometry", [pos])
            self.node("Mesh", "MeshInstance3D", "Geometry/%s" % name,
                      ['mesh = SubResource("%s")' % mesh_id], groups=mg)
            self.node("Shape", "CollisionShape3D", "Geometry/%s" % name,
                      ['shape = SubResource("%s")' % shape])
        else:
            self.node(name, "MeshInstance3D", "Geometry", [pos, 'mesh = SubResource("%s")' % mesh_id],
                      groups=mg)
        return name

    def glight(self, name: str, pos, rgba, energy: float = 1.6, rng: float = 11.0,
               groups: list[str] | None = None) -> None:
        self.node(self.unique(name), "OmniLight3D", "Lights", [
            "position = %s" % v3(*pos),
            "light_color = %s" % col(rgba),
            "light_energy = %s" % f(energy),
            "omni_range = %s" % f(rng),
            "omni_attenuation = 1.2",
            "shadow_enabled = false",
        ], groups=groups)

    def marker(self, name: str, pos) -> None:
        self.node(self.unique(name), "Marker3D", "Markers", ["position = %s" % v3(*pos)])

    def base_nodes(self, markers: bool = False) -> None:
        for n in ("Geometry", "Lights", "Enemies", "Pickups", "Interactables"):
            self.node(n, "Node3D", ".")
        if markers:
            self.node("Markers", "Node3D", ".")

    def enemy(self, name: str, scene: str, pos, deg: float = 0.0, points=None) -> None:
        props = ["position = %s" % v3(*pos)]
        if deg:
            props.append(rot_y(deg))
        if points:
            props.append(patrol(points))
        self.instance(name, scene, "Enemies", props)

    def ammo(self, name: str, weapon: str, amount: int, pos) -> None:
        self.instance(name, PICKUP, "Pickups", ["position = %s" % v3(*pos), "pickup_type = 0",
                      'weapon_id = "%s"' % weapon, "amount = %d" % amount])

    def terminal(self, name: str, pos, deg: float, title: str, body: str) -> None:
        self.instance(name, TERMINAL, "Interactables", [
            "position = %s" % v3(*pos), rot_y(deg),
            'terminal_title = "%s"' % title,
            "terminal_body = %s" % tres_string(body)])

    def door_and_exit(self, door_name: str, door_pos, exit_pos, target: int, prompt: str) -> None:
        self.instance(door_name, DOOR, "Interactables", ["position = %s" % v3(*door_pos)])
        self.instance("LevelExit", EXIT, "Interactables", [
            "position = %s" % v3(*exit_pos), "target_floor = %d" % target,
            'prompt_text = "%s"' % prompt])


def exit_alcove(b: FullBuilder, z_door: float, floor_m: str, ceil_m: str, wall_m: str,
                glow_m: str, depth: float = 8.0) -> None:
    """Small elevator alcove north of a door gap at z_door (x -3..3)."""
    z1 = z_door - depth
    b.room_slabs("ExitAlcove", -3, 3, z1, z_door, 3.6, floor_m, ceil_m)
    b.wall_z("AlcoveWestWall", -3, z1, z_door, 3.6, wall_m)
    b.wall_z("AlcoveEastWall", 3, z1, z_door, 3.6, wall_m)
    b.wall_x("AlcoveNorthWall", z1, -3, 3, 3.6, wall_m)
    b.solid("ElevatorDoors", -1.5, 1.5, 0, 3, z1 + 0.25, z1 + 0.32, wall_m, collide=False)
    b.solid("ElevatorFrameGlow", -1.7, 1.7, 3.05, 3.15, z1 + 0.25, z1 + 0.32, glow_m, collide=False)


# ====================================================================== FLOOR 2
def build_floor_02() -> None:
    b = FullBuilder()
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
    screen = b.glow_material("monitor", (0.35, 0.6, 1.0, 1), 1.6)
    glass = b.glass_material("glass", (0.55, 0.7, 1.0, 0.22))

    b.base_nodes()

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
    b.solid("CorridorGlassL", -2.75, -2.65, 0, 2.4, -14.5, -10, glass)
    b.solid("CorridorGlassR", 2.65, 2.75, 0, 2.4, -28.5, -25, glass)
    # office west x -17..-3, z -26..-12, h 3.8
    b.room_slabs("Office", -17, -3, -26, -12, 3.8, carpet, ceil)
    b.wall_z("OfficeWestWall", -17, -26, -12, 3.8, wall)
    b.wall_x("OfficeNorthWall", -26, -17, -3, 3.8, wall)
    b.wall_x("OfficeSouthWall", -12, -17, -3, 3.8, wall)
    for dx, dz in ((-14, -15), (-9, -15), (-14, -22), (-9, -22)):
        b.solid("ComputerDesk", dx - 1.2, dx + 1.2, 0, 0.8, dz - 0.6, dz + 0.6, desk)
        b.solid("DeskPartition", dx - 1.2, dx + 1.2, 0.8, 1.5, dz - 0.65, dz - 0.55, metal)
        b.solid("DeskMonitor", dx - 0.45, dx + 0.45, 0.85, 1.35, dz - 0.45, dz - 0.4, screen, collide=False)
        b.solid("DeskMonitor", dx + 0.15, dx + 0.95, 0.85, 1.3, dz - 0.3, dz - 0.25, screen, collide=False)
    # glass dividers between desk clusters (gap at z -18.5 for the patrol lane)
    b.solid("GlassDivider", -11.6, -11.4, 0, 2.2, -25.5, -20.5, glass)
    b.solid("GlassDivider", -11.6, -11.4, 0, 2.2, -16.5, -12.5, glass)
    b.solid("GlassDividerFrame", -11.65, -11.35, 2.2, 2.3, -25.5, -20.5, metal, collide=False)
    b.solid("GlassDividerFrame", -11.65, -11.35, 2.2, 2.3, -16.5, -12.5, metal, collide=False)
    b.solid("OfficeStrip", -15, -5, 3.72, 3.8, -19.2, -18.8, warm, collide=False)
    # archive east x 3..15, z -28..-14, h 4.2
    b.room_slabs("Archive", 3, 15, -28, -14, 4.2, carpet, ceil)
    b.wall_z("ArchiveEastWall", 15, -28, -14, 4.2, wall)
    b.wall_x("ArchiveNorthWall", -28, 3, 15, 4.2, wall)
    b.wall_x("ArchiveSouthWall", -14, 3, 15, 4.2, wall)
    for rx in (7.5, 11.5):
        b.solid("ServerRack", rx - 0.5, rx + 0.5, 0, 2.3, -27.5, -23.5, rack)
        b.solid("ServerRack", rx - 0.5, rx + 0.5, 0, 2.3, -18.5, -14.5, rack)
        b.solid("RackLed", rx - 0.52, rx + 0.52, 2.0, 2.06, -27.5, -23.5, blue, collide=False)
        b.solid("RackLed", rx - 0.52, rx + 0.52, 2.0, 2.06, -18.5, -14.5, blue, collide=False)
    b.solid("ArchiveGlass", 4.5, 4.6, 0, 2.4, -27.5, -23.5, glass)
    b.solid("ArchiveStrip", 6, 13, 4.12, 4.2, -21.2, -20.8, blue, collide=False)
    # executive x -5..5, z -40..-30, h 4.5
    b.room_slabs("Executive", -5, 5, -40, -30, 4.5, carpet, ceil)
    b.wall_x("ExecutiveSouthWall", -30, -5, 5, 4.5, wall, [(-3, 3, 3.8)])
    b.wall_z("ExecutiveWestWall", -5, -40, -30, 4.5, wall)
    b.wall_z("ExecutiveEastWall", 5, -40, -30, 4.5, wall)
    b.wall_x("ExecutiveNorthWall", -40, -5, 5, 4.5, wall, [(-2, 2, 3.2)])
    b.solid("ExecutiveDesk", -2, 2, 0, 0.85, -34.6, -33.6, desk)
    b.solid("ExecutiveMonitor", -0.8, 0.8, 0.9, 1.5, -34.5, -34.45, screen, collide=False)
    b.solid("ExecutiveRack", -4.75, -3.75, 0, 2.3, -39.5, -36.5, rack)
    b.solid("ExecutiveRack", 3.75, 4.75, 0, 2.3, -39.5, -36.5, rack)
    b.solid("ExecutiveStrip", -3, 3, 4.42, 4.5, -31.6, -31.4, warm, collide=False)
    b.solid("DoorWarn", -2, 2, 3.4, 3.5, -39.74, -39.7, warm, collide=False)
    exit_alcove(b, -40, carpet, ceil, wall, blue)

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
    b.light("AlcoveLight", (0, 3.1, -44), blue_c, 1.4, 7)

    b.instance("Player", PLAYER, ".", ["position = %s" % v3(0, 0.05, -2)])

    b.enemy("OfficeTech", TECH, (-11.5, 0, -18.5), -90, [(0, 0, 0), (-4, 0, 0)])
    b.enemy("OfficeTechB", TECH, (-6, 0, -14), 180, [(0, 0, 0), (0, 0, -8)])
    b.enemy("ArchiveMerc", MERC, (9.5, 0, -25), 90, [(0, 0, 0), (0, 0, 8)])
    b.enemy("CorridorMerc", MERC, (0, 0, -27), 180, [(0, 0, 0), (0, 0, 10)])
    b.enemy("ExecutiveMerc", MERC, (0, 0, -38.2), 180)

    b.ammo("OfficeAmmoPickup", "pistol", 24, (-14, 1.0, -22))
    b.ammo("ArchiveShellsPickup", "shotgun", 6, (13.5, 0.5, -26.5))
    b.ammo("ExecutiveShellsPickup", "shotgun", 6, (-4.2, 0.5, -31))

    lore = ("ARŞİV KAYDI — BETA ARAŞTIRMA DOSYASI #0417\n\n"
            "General'in laboratuvarından çalınan BETA araştırmasının tüm kopyaları bu sunuculardan "
            "Volkov'un özel ağına aktarıldı. BETA Cihazı'nın biyolojik enerji dönüşüm verisi şifresiz.\n\n"
            "Kat 5'teki Beta Reaktörü savunma ağı Kat 3 ve 4'teki röle istasyonlarından besleniyor. "
            "Röleler düşerse reaktör kalkanı devre dışı kalır.\n\n"
            "Volkov'a not: Ajan Aydın binada. Lobi hattı rapor vermiyor.")
    b.terminal("ArchiveLoreTerminal", (14.5, 0, -21), -90, "Çalınan BETA Araştırması", lore)
    b.door_and_exit("ExecutiveSecurityDoor", (0, 0, -40), (0, 0, -45), 3, "[E] Asansörle 3. Kata Çık")
    b.write("scenes/levels/floor_02_office.tscn")


# ====================================================================== FLOOR 3
def build_floor_03() -> None:
    b = FullBuilder()
    script = b.ext_res("Script", "res://scripts/systems/floor_03_controller.gd")
    b.node("Floor03Lab", "Node3D", None, ['script = ExtResource("%s")' % script])
    b.environment((0.005, 0.02, 0.012, 1), (0.55, 0.8, 0.62, 1), 0.36, (0.06, 0.16, 0.09, 1))

    floor_m = b.color_material("labfloor", (0.82, 0.86, 0.84, 1), 0.35, 0.0, "tex_f3_lab_floor")
    wall_m = b.color_material("labwall", (0.9, 0.93, 0.91, 1), 0.6, 0.0, "tex_f3_lab_wall")
    dark_m = b.color_material("labdark", (0.06, 0.08, 0.07, 1), 0.5, 0.6)
    ceil_m = b.tex_material("labceil", "f1_ceiling_grid", (0.55, 0.65, 0.58, 1), 0.25, 0.9)
    tube_m = b.color_material("biotube", (0.25, 1.0, 0.45, 0.72), 0.1, 0.0, "tex_f3_bio_tube",
                              emission=(0.2, 1.0, 0.4, 1), energy=1.6, transparent=True)
    bench_m = b.color_material("bench", (0.92, 0.94, 0.93, 1), 0.3, 0.2)
    green = b.glow_material("greenstrip", (0.25, 1.0, 0.45, 1), 2.4)
    white = b.glow_material("whitestrip", (0.92, 1.0, 0.95, 1), 2.0)
    red = b.glow_material("emergency", (1.0, 0.18, 0.12, 1), 2.2)
    screen = b.glow_material("labscreen", (0.3, 1.0, 0.55, 1), 1.4)
    glass = b.glass_material("labglass", (0.7, 1.0, 0.8, 0.2))

    b.base_nodes()

    # --- specimen corridor  x -4..4, z -40..0, h 5
    b.room_slabs("Corridor", -4, 4, -40, 0, 5, floor_m, ceil_m)
    b.wall_x("CorridorSouthWall", 0, -4, 4, 5, wall_m)
    b.wall_z("CorridorWestWall", -4, -40, 0, 5, wall_m, [(-28, -22, 3.2)])
    b.wall_z("CorridorEastWall", 4, -40, 0, 5, wall_m, [(-28, -22, 3.2)])
    b.solid("ElevatorDoorsBack", -1.6, 1.6, 0, 3, -0.3, -0.24, dark_m, collide=False)
    b.solid("CorridorStrip", -0.2, 0.2, 4.92, 5, -39, -1, white, collide=False)
    b.solid("FloorGuideL", -2.2, -2.1, 0, 0.02, -39, -1, green, collide=False)
    b.solid("FloorGuideR", 2.1, 2.2, 0, 0.02, -39, -1, green, collide=False)
    for z in (-7, -12, -17, -33, -37):
        for x in (-3.15, 3.15):
            b.cylinder("SpecimenTubeBase", x, z, 0, 0.4, 0.7, dark_m)
            b.cylinder("SpecimenTube", x, z, 0.4, 3.2, 0.55, tube_m, collide=False)
            b.cylinder("SpecimenTubeCap", x, z, 3.2, 3.5, 0.7, dark_m, collide=False)
            b.blocker("SpecimenTubeHitbox", x - 0.6, x + 0.6, 0.4, 3.2, z - 0.6, z + 0.6)
        b.glight("TubeGlow", (0, 2.2, z), (0.3, 1.0, 0.5, 1), 1.1, 6)

    # --- west bio lab  x -20..-4, z -34..-16, h 4.5
    b.room_slabs("BioLab", -20, -4, -34, -16, 4.5, floor_m, ceil_m)
    b.wall_z("BioLabWestWall", -20, -34, -16, 4.5, wall_m)
    b.wall_x("BioLabNorthWall", -34, -20, -4, 4.5, wall_m)
    b.wall_x("BioLabSouthWall", -16, -20, -4, 4.5, wall_m)
    for bz in (-20.5, -26.5, -30.5):
        b.solid("LabBench", -17, -12.5, 0, 0.95, bz - 0.5, bz + 0.5, bench_m)
        b.solid("BenchScreen", -16, -14.5, 0.95, 1.5, bz - 0.42, bz - 0.38, screen, collide=False)
        b.solid("SampleRack", -13.8, -12.8, 0.95, 1.25, bz - 0.3, bz + 0.3, green, collide=False)
    b.cylinder("Centrifuge", -8, -31, 0, 1.3, 0.9, dark_m)
    b.cylinder("CentrifugeLid", -8, -31, 1.3, 1.4, 0.75, green, collide=False)
    b.solid("LabGlassWall", -9.6, -9.4, 0, 2.6, -24, -17, glass)
    b.solid("BioLabStrip", -18, -6, 4.42, 4.5, -25.2, -24.8, white, collide=False)

    # --- east exo-armor test lab  x 4..20, z -34..-16, h 5
    b.room_slabs("ExoLab", 4, 20, -34, -16, 5, floor_m, ceil_m)
    b.wall_z("ExoLabEastWall", 20, -34, -16, 5, wall_m)
    b.wall_x("ExoLabNorthWall", -34, 4, 20, 5, wall_m)
    b.wall_x("ExoLabSouthWall", -16, 4, 20, 5, wall_m)
    for rz in (-19.5, -30.5):
        b.solid("ArmorRigPost", 10.6, 11.0, 0, 3.2, rz - 0.3, rz + 0.3, dark_m)
        b.solid("ArmorRigPost", 14.0, 14.4, 0, 3.2, rz - 0.3, rz + 0.3, dark_m)
        b.solid("ArmorRigBeam", 10.6, 14.4, 3.2, 3.5, rz - 0.3, rz + 0.3, dark_m)
        b.solid("ExoArmorTorso", 11.7, 13.3, 1.2, 2.6, rz - 0.35, rz + 0.35, bench_m)
        b.solid("ExoArmorLegs", 11.9, 13.1, 0, 1.2, rz - 0.25, rz + 0.25, dark_m)
        b.solid("ExoVisor", 12.1, 12.9, 2.3, 2.45, rz + 0.35, rz + 0.38, green, collide=False)
    b.solid("TestBarrier", 6, 7.2, 0, 1.2, -26, -24, dark_m)
    b.solid("TestBarrier", 16, 17.2, 0, 1.2, -26, -24, dark_m)
    b.solid("ExoLabStrip", 6, 18, 4.92, 5, -25.2, -24.8, white, collide=False)

    # --- containment hall  x -10..10, z -56..-40, h 5.5
    b.room_slabs("ContainmentHall", -10, 10, -56, -40, 5.5, floor_m, ceil_m)
    b.wall_x("HallSouthWall", -40, -10, 10, 5.5, wall_m, [(-3, 3, 4)])
    b.wall_z("HallWestWall", -10, -56, -40, 5.5, wall_m)
    b.wall_z("HallEastWall", 10, -56, -40, 5.5, wall_m)
    b.wall_x("HallNorthWall", -56, -10, 10, 5.5, wall_m, [(-2, 2, 3.2)])
    for tx in (-6.5, 6.5):
        b.cylinder("ContainmentTankBase", tx, -50, 0, 0.5, 1.3, dark_m)
        b.cylinder("ContainmentTank", tx, -50, 0.5, 4.2, 1.05, tube_m, collide=False)
        b.cylinder("ContainmentTankCap", tx, -50, 4.2, 4.6, 1.3, dark_m, collide=False)
        b.blocker("ContainmentTankHitbox", tx - 1.1, tx + 1.1, 0.5, 4.2, -51.1, -48.9)
    b.solid("HazmatCrate", -7.5, -5.5, 0, 1.1, -45, -43.8, dark_m)
    b.solid("HazmatCrate", 5.5, 7.5, 0, 1.1, -45, -43.8, dark_m)
    b.solid("HazmatStripe", -7.5, -5.5, 1.1, 1.14, -45, -43.8, red, collide=False)
    b.solid("HazmatStripe", 5.5, 7.5, 1.1, 1.14, -45, -43.8, red, collide=False)
    b.solid("DoorWarn", -2, 2, 3.4, 3.5, -55.74, -55.7, red, collide=False)
    exit_alcove(b, -56, floor_m, ceil_m, wall_m, green)

    # --- lights: green tube glow (above), flickering emergency/lab lights
    lab_w = (0.85, 1.0, 0.9, 1)
    emerg = (1.0, 0.25, 0.18, 1)
    b.glight("CorridorLabLight", (0, 4.5, -3), lab_w, 1.4, 9, ["flicker_light"])
    b.glight("CorridorLabLight", (0, 4.5, -25), lab_w, 1.3, 10, ["flicker_light"])
    b.glight("BioLabLight", (-12, 4.0, -20), lab_w, 1.5, 11)
    b.glight("BioLabLight", (-12, 4.0, -30), (0.4, 1.0, 0.55, 1), 1.2, 10, ["flicker_light"])
    b.glight("ExoLabLight", (12, 4.4, -25), lab_w, 1.7, 12)
    b.glight("ExoLabEmergency", (18, 4.2, -32), emerg, 1.2, 8, ["flicker_light"])
    b.glight("HallEmergency", (-6, 5.0, -44), emerg, 1.5, 11, ["flicker_light"])
    b.glight("HallEmergency", (6, 5.0, -52), emerg, 1.5, 11, ["flicker_light"])
    b.glight("TankGlow", (0, 3.0, -50), (0.3, 1.0, 0.5, 1), 1.6, 12)
    b.glight("AlcoveLight", (0, 3.1, -60), (0.4, 1.0, 0.6, 1), 1.4, 7)

    b.instance("Player", PLAYER, ".", ["position = %s" % v3(0, 0.05, -2)])

    # enemies: 3x Lv3 heavy + 3x Lv1 technician
    b.enemy("BioLabTech", TECH, (-16, 0, -23.5), -90, [(0, 0, 0), (5, 0, 0)])
    b.enemy("BioLabHeavy", HEAVY, (-11, 0, -28.5), 90, [(0, 0, 0), (0, 0, 8)])
    b.enemy("ExoLabTech", TECH, (8, 0, -31.5), 90, [(0, 0, 0), (0, 0, 13)])
    b.enemy("ExoLabHeavy", HEAVY, (12.5, 0, -25), -90, [(0, 0, 0), (4, 0, 0)])
    b.enemy("HallTech", TECH, (-4, 0, -46), 180, [(0, 0, 0), (8, 0, 0)])
    b.enemy("HallHeavy", HEAVY, (0, 0, -52.5), 180)

    b.ammo("BioLabShellsPickup", "shotgun", 6, (-18.5, 0.5, -32.5))
    b.ammo("ExoLabAmmoPickup", "pistol", 24, (18.5, 0.5, -32.5))
    b.ammo("HallShellsPickup", "shotgun", 6, (-8.8, 0.5, -54.8))

    lore_a = ("DENEY KAYDI — BİYO-REJENERASYON PROGRAMI B-7\n\n"
              "General'in laboratuvarından çalınan BETA doku-rejenerasyon örnekleri bu katta "
              "zorla silah projesine dönüştürüldü. Volkov, güvenlik protokollerini askıya alarak "
              "örneklerin canlı deneklere doğrudan enjekte edilmesini emretti.\n\n"
              "Sonuç: Deneklerin %62'si ilk 48 saatte kaybedildi. Hayatta kalanlarda doku onarımı "
              "4 kat hızlandı; ancak hücre çöküşü kaçınılmaz.\n\n"
              "Volkov'un notu: 'Kayıplar kabul edilebilir. Rejenerasyon serumu Exo birliğine "
              "öncelikli dağıtılacak. Örnek tüpleri hiçbir koşulda bu kattan çıkmayacak.'")
    lore_b = ("TEST RAPORU — EXO-ZIRH DENEMELERİ / SERİ IV\n\n"
              "Deneysel dış iskelet zırhı, BETA rejenerasyon serumu ile senkronize edildi. "
              "Zırh, taşıyıcının yaralarını savaş sırasında kapatabiliyor; enerji kaynağı ise "
              "doğrudan Beta Reaktörü'ne bağlı.\n\n"
              "Deneme 14: Taşıyıcı 3 kurşun yarasından 40 saniyede kurtuldu. Deneme 15: Sinir "
              "sistemi aşırı yük nedeniyle iflas etti.\n\n"
              "Prototip 'Volkov Modeli' çatıya taşındı. Viktor Volkov zırhı bizzat giyecek. "
              "Zırhın üç güç evresi var — her evrede kalkan yeniden şarj oluyor.")
    b.terminal("BioLabLoreTerminal", (-19.6, 0, -24), 90, "Biyo-Rejenerasyon Deney Kaydı", lore_a)
    b.terminal("ExoLabLoreTerminal", (19.6, 0, -25), -90, "Exo-Zırh Deneme Raporu", lore_b)
    b.door_and_exit("LabSecurityDoor", (0, 0, -56), (0, 0, -61), 4, "[E] Asansörle 4. Kata Çık")
    b.write("scenes/levels/floor_03_lab.tscn")


# ====================================================================== FLOOR 4
def build_floor_04() -> None:
    b = FullBuilder()
    script = b.ext_res("Script", "res://scripts/systems/floor_04_controller.gd")
    b.node("Floor04Vip", "Node3D", None, ['script = ExtResource("%s")' % script])
    b.environment((0.02, 0.005, 0.008, 1), (0.75, 0.45, 0.38, 1), 0.34, (0.18, 0.06, 0.05, 1))

    carpet = b.color_material("redcarpet", (0.5, 0.06, 0.08, 1), 0.9, 0.0, "tex_f4_red_carpet")
    wall_m = b.color_material("vipwall", (0.16, 0.05, 0.06, 1), 0.6, 0.1, "tex_f4_vip_wall")
    felt = b.color_material("casinofelt", (0.08, 0.32, 0.16, 1), 0.95, 0.0, "tex_f4_casino_felt")
    ceil_m = b.color_material("vipceil", (0.06, 0.03, 0.03, 1), 0.7, 0.2)
    black = b.color_material("lacquer", (0.03, 0.025, 0.025, 1), 0.25, 0.4)
    gold = b.color_material("gold", (0.85, 0.65, 0.22, 1), 0.3, 0.9)
    gold_glow = b.glow_material("goldglow", (1.0, 0.75, 0.3, 1), 2.2)
    red_glow = b.glow_material("redglow", (1.0, 0.12, 0.15, 1), 2.4)
    screen = b.glow_material("slotscreen", (1.0, 0.45, 0.2, 1), 1.8)
    mon = b.glow_material("secmonitor", (0.45, 0.7, 1.0, 1), 1.4)

    b.base_nodes()

    # --- foyer  x -4..4, z -10..0, h 4
    b.room_slabs("Foyer", -4, 4, -10, 0, 4, carpet, ceil_m)
    b.wall_x("FoyerSouthWall", 0, -4, 4, 4, wall_m)
    b.wall_z("FoyerWestWall", -4, -10, 0, 4, wall_m)
    b.wall_z("FoyerEastWall", 4, -10, 0, 4, wall_m)
    b.solid("ElevatorDoorsBack", -1.6, 1.6, 0, 3, -0.3, -0.24, gold, collide=False)
    b.solid("FoyerStrip", -0.2, 0.2, 3.92, 4, -9, -1, gold_glow, collide=False)

    # --- casino hall  x -16..16, z -40..-10, h 6
    b.room_slabs("Casino", -16, 16, -40, -10, 6, carpet, ceil_m)
    b.wall_x("CasinoSouthWall", -10, -16, 16, 6, wall_m, [(-3, 3, 3.6)])
    b.wall_z("CasinoWestWall", -16, -40, -10, 6, wall_m, [(-28, -22, 3.2)])
    b.wall_z("CasinoEastWall", 16, -40, -10, 6, wall_m, [(-28, -24, 3)])
    b.wall_x("CasinoNorthWall", -40, -16, 16, 6, wall_m, [(-3, 3, 3.8)])
    for tx, tz in ((-9, -17), (9, -17), (-9, -33), (9, -33)):
        b.solid("CasinoTable", tx - 1.6, tx + 1.6, 0, 0.85, tz - 0.9, tz + 0.9, black)
        b.solid("TableFelt", tx - 1.45, tx + 1.45, 0.85, 0.9, tz - 0.75, tz + 0.75, felt, collide=False)
        b.solid("TableRim", tx - 1.6, tx + 1.6, 0.85, 0.92, tz - 0.95, tz - 0.85, gold, collide=False)
        b.solid("TableRim", tx - 1.6, tx + 1.6, 0.85, 0.92, tz + 0.85, tz + 0.95, gold, collide=False)
    b.cylinder("RouletteBase", 0, -25, 0, 0.9, 1.6, black, segments=24)
    b.cylinder("RouletteFelt", 0, -25, 0.9, 0.95, 1.45, felt, collide=False, segments=24)
    b.cylinder("RouletteWheel", 0, -25, 0.95, 1.05, 0.7, gold, collide=False, segments=24)
    for px, pz in ((-4.5, -17), (4.5, -17), (-4.5, -33), (4.5, -33)):
        b.solid("GoldPillar", px - 0.6, px + 0.6, 0, 6, pz - 0.6, pz + 0.6, black)
        b.solid("PillarTrim", px - 0.65, px + 0.65, 2.6, 2.75, pz - 0.65, pz + 0.65, gold_glow, collide=False)
        b.solid("PillarTrim", px - 0.65, px + 0.65, 0, 0.2, pz - 0.65, pz + 0.65, gold, collide=False)
        b.solid("PillarTrim", px - 0.65, px + 0.65, 5.7, 6, pz - 0.65, pz + 0.65, gold, collide=False)
    for sz in (-12.2, -14.2, -16.2):
        b.solid("SlotMachine", 14.6, 15.75, 0, 1.9, sz - 0.7, sz + 0.7, black)
        b.solid("SlotScreen", 14.55, 14.6, 1.0, 1.6, sz - 0.5, sz + 0.5, screen, collide=False)
        b.solid("SlotTop", 14.55, 15.75, 1.9, 2.0, sz - 0.7, sz + 0.7, red_glow, collide=False)
    b.solid("Chandelier", -6, 6, 5.85, 5.95, -25.3, -24.7, gold_glow, collide=False)
    b.solid("Chandelier", -0.3, 0.3, 5.85, 5.95, -31, -19, gold_glow, collide=False)
    b.solid("VelvetRope", -3, 3, 0.85, 0.95, -37.6, -37.5, red_glow, collide=False)

    # --- VIP lounge bar  x -30..-16, z -34..-18, h 4.5
    b.room_slabs("VipLounge", -30, -16, -34, -18, 4.5, carpet, ceil_m)
    b.wall_z("LoungeWestWall", -30, -34, -18, 4.5, wall_m)
    b.wall_x("LoungeNorthWall", -34, -30, -16, 4.5, wall_m)
    b.wall_x("LoungeSouthWall", -18, -30, -16, 4.5, wall_m)
    b.solid("BarCounter", -27, -26, 0, 1.1, -32, -20, black)
    b.solid("BarTop", -27.1, -25.9, 1.1, 1.16, -32.1, -19.9, gold, collide=False)
    b.solid("BarShelf", -29.75, -29.3, 1.2, 3.2, -31, -21, gold_glow, collide=False)
    b.solid("LoungeSofa", -22, -18.5, 0, 0.7, -32.8, -31.6, felt)
    b.solid("LoungeSofa", -22, -18.5, 0, 0.7, -20.4, -19.2, felt)
    b.solid("LoungeTable", -21, -19.5, 0, 0.5, -27, -25, gold)
    b.solid("LoungeStrip", -28, -18, 4.42, 4.5, -26.2, -25.8, red_glow, collide=False)

    # --- private security room  x 16..28, z -32..-20, h 4
    b.room_slabs("SecurityRoom", 16, 28, -32, -20, 4, carpet, ceil_m)
    b.wall_z("SecurityEastWall", 28, -32, -20, 4, wall_m)
    b.wall_x("SecurityNorthWall", -32, 16, 28, 4, wall_m)
    b.wall_x("SecuritySouthWall", -20, 16, 28, 4, wall_m)
    b.solid("MonitorDesk", 25.5, 27.5, 0, 0.9, -29, -23, black)
    b.solid("MonitorWall", 27.7, 27.75, 1.4, 3.2, -29, -23, mon, collide=False)
    b.solid("Lockers", 17, 21, 0, 2.2, -31.75, -31.2, black)
    b.solid("WeaponCrate", 20, 21.5, 0, 1.0, -24, -22.8, gold)

    # --- vault corridor  x -4..4, z -54..-40, h 4.5
    b.room_slabs("VaultCorridor", -4, 4, -54, -40, 4.5, carpet, ceil_m)
    b.wall_z("VaultWestWall", -4, -54, -40, 4.5, wall_m)
    b.wall_z("VaultEastWall", 4, -54, -40, 4.5, wall_m)
    b.wall_x("VaultNorthWall", -54, -4, 4, 4.5, wall_m, [(-2, 2, 3.2)])
    b.solid("VaultCover", -3.75, -2.4, 0, 1.2, -46, -45, gold)
    b.solid("VaultCover", 2.4, 3.75, 0, 1.2, -49, -48, gold)
    b.solid("VaultStripL", -3.75, -3.7, 3.5, 3.6, -53.5, -40.5, gold_glow, collide=False)
    b.solid("VaultStripR", 3.7, 3.75, 3.5, 3.6, -53.5, -40.5, gold_glow, collide=False)
    b.solid("DoorWarn", -2, 2, 3.4, 3.5, -53.74, -53.7, red_glow, collide=False)
    exit_alcove(b, -54, carpet, ceil_m, wall_m, gold_glow)

    gold_c = (1.0, 0.72, 0.38, 1)
    red_c = (1.0, 0.25, 0.22, 1)
    b.glight("FoyerLight", (0, 3.4, -5), gold_c, 1.4, 8)
    b.glight("CasinoLight", (-9, 5.3, -17), gold_c, 1.6, 12)
    b.glight("CasinoLight", (9, 5.3, -17), red_c, 1.4, 12)
    b.glight("CasinoLight", (-9, 5.3, -33), red_c, 1.4, 12)
    b.glight("CasinoLight", (9, 5.3, -33), gold_c, 1.6, 12)
    b.glight("RouletteLight", (0, 4.5, -25), gold_c, 1.8, 10)
    b.glight("LoungeLight", (-23, 4.0, -26), red_c, 1.5, 11)
    b.glight("BarLight", (-28, 3.0, -26), gold_c, 1.2, 7)
    b.glight("SecurityLight", (22, 3.5, -26), (0.6, 0.75, 1.0, 1), 1.4, 10)
    b.glight("VaultLight", (0, 4.0, -44), gold_c, 1.4, 9)
    b.glight("VaultLight", (0, 4.0, -51), red_c, 1.3, 8)
    b.glight("AlcoveLight", (0, 3.1, -58), gold_c, 1.3, 7)

    b.instance("Player", PLAYER, ".", ["position = %s" % v3(0, 0.05, -2)])

    # enemies: 3x Lv4 commando + 2x Lv2 merc + 2x Lv1 guard
    b.enemy("CasinoGuardA", GUARD, (-9, 0, -25), 0, [(0, 0, 0), (0, 0, 4)])
    b.enemy("CasinoGuardB", GUARD, (12, 0, -12), 180, [(0, 0, 0), (-6, 0, 0)])
    b.enemy("CasinoMerc", MERC, (9, 0, -25), 180, [(0, 0, 0), (0, 0, -5)])
    b.enemy("LoungeMerc", MERC, (-22, 0, -26), 90, [(0, 0, 0), (0, 0, 4)])
    b.enemy("CasinoCommando", COMMANDO, (0, 0, -36.5), 180, [(0, 0, 0), (6, 0, 0), (-6, 0, 0)])
    b.enemy("SecurityCommando", COMMANDO, (22, 0, -26), 90)
    b.enemy("VaultCommando", COMMANDO, (0, 0, -51), 180)

    b.ammo("SecurityShellsPickup", "shotgun", 8, (24, 1.4, -23.4))
    b.ammo("SecurityAmmoPickup", "pistol", 24, (19.2, 0.5, -21))
    b.ammo("LoungeAmmoPickup", "pistol", 24, (-28.5, 0.5, -19))
    b.ammo("VaultShellsPickup", "shotgun", 6, (-3.2, 0.5, -52.8))

    lore = ("GİZLİ EMİR — V. VOLKOV / ÇATI TAHLİYE PROTOKOLÜ\n\n"
            "Tüm birimlere: Beta Reaktörü çekirdeği çatıda tam güce ulaştı. Tahliye helikopteri "
            "çevrim tamamlandığında çatıya inecek. Çekirdek modül ve rejenerasyon serumu benimle "
            "birlikte binayı terk edecek.\n\n"
            "Deneysel Savunma Kulesi aktive edilecek. Kule, reaktörden beslenen kalkan ağıyla "
            "çatıyı kuşatır; yetkisiz her hedefi otomatik olarak vurur. Kapatma yalnızca reaktör "
            "tabanındaki konsoldan mümkün.\n\n"
            "Ajan Aydın bu kata ulaşırsa komandolar kasayı mühürleyecek. Sıra kilidi kodu "
            "değiştirildi. Kimse çatıya çıkmayacak.\n\n— V.")
    b.terminal("VipLoreTerminal", (-23, 0, -18.6), 180, "Volkov'un Tahliye Emri", lore)
    b.door_and_exit("VaultSecurityDoor", (0, 0, -54), (0, 0, -59), 5, "[E] Asansörle Çatıya Çık")
    b.write("scenes/levels/floor_04_vip.tscn")


# ====================================================================== FLOOR 5
def build_floor_05() -> None:
    b = FullBuilder()
    script = b.ext_res("Script", "res://scripts/systems/floor_05_controller.gd")
    b.node("Floor05Rooftop", "Node3D", None, ['script = ExtResource("%s")' % script])
    b.environment((0.008, 0.012, 0.03, 1), (0.32, 0.42, 0.7, 1), 0.48, (0.08, 0.11, 0.2, 1))

    grate = b.color_material("roofgrate", (0.2, 0.22, 0.25, 1), 0.7, 0.5, "tex_f5_roof_grate")
    ind_wall = b.color_material("indwall", (0.26, 0.28, 0.32, 1), 0.75, 0.3, "tex_f5_industrial_wall")
    core_m = b.color_material("reactorcore", (0.25, 0.65, 1.0, 1), 0.2, 0.3, "tex_f5_reactor_core",
                              emission=(0.2, 0.6, 1.0, 1), energy=2.6)
    steel = b.color_material("roofsteel", (0.12, 0.13, 0.15, 1), 0.45, 0.8)
    hvac = b.color_material("hvac", (0.32, 0.34, 0.36, 1), 0.6, 0.6)
    tower = b.color_material("skyline", (0.02, 0.025, 0.04, 1), 0.9, 0.1)
    ceil_m = b.color_material("housingceil", (0.1, 0.11, 0.13, 1), 0.8, 0.3)
    blue = b.glow_material("electricblue", (0.25, 0.7, 1.0, 1), 3.0)
    red = b.glow_material("beaconred", (1.0, 0.08, 0.06, 1), 3.2)
    windows = b.glow_material("windows", (0.55, 0.62, 0.9, 1), 0.9)
    warn = b.glow_material("hazard", (1.0, 0.3, 0.1, 1), 1.6)

    b.base_nodes(markers=True)

    # --- stair / elevator housing  x -4..4, z -8..0, h 4 (enclosed, opens north)
    b.room_slabs("Housing", -4, 4, -8, 0, 4, grate, ceil_m)
    b.wall_x("HousingSouthWall", 0, -4, 4, 4, ind_wall)
    b.wall_z("HousingWestWall", -4, -8, 0, 4, ind_wall)
    b.wall_z("HousingEastWall", 4, -8, 0, 4, ind_wall)
    b.solid("HousingLintel", -3, 3, 3.6, 4.3, -8.25, -7.75, ind_wall)
    b.solid("ElevatorDoorsBack", -1.6, 1.6, 0, 3, -0.3, -0.24, steel, collide=False)
    b.solid("HousingSign", -1.5, 1.5, 3.65, 3.75, -8.3, -8.26, warn, collide=False)

    # --- rooftop arena  x -24..24, z -56..-8 (open sky)
    b.solid("RoofSlab", -24, 24, -0.5, 0, -56, -8, grate)
    t = 0.25
    # low parapets (visual + collision) and tall invisible blockers so nobody falls off
    b.solid("ParapetNorth", -24 - t, 24 + t, 0, 1.4, -56 - t, -56 + t, ind_wall)
    b.solid("ParapetWest", -24 - t, -24 + t, 0, 1.4, -56, -8, ind_wall)
    b.solid("ParapetEast", 24 - t, 24 + t, 0, 1.4, -56, -8, ind_wall)
    b.solid("ParapetSouth", -24 - t, -4, 0, 1.4, -8 - t, -8 + t, ind_wall)
    b.solid("ParapetSouth", 4, 24 + t, 0, 1.4, -8 - t, -8 + t, ind_wall)
    for name, x0, x1, z0, z1 in (("ParapetCap", -24.35, 24.35, -56.35, -55.65),
                                 ("ParapetCap", -24.35, -23.65, -56, -8),
                                 ("ParapetCap", 23.65, 24.35, -56, -8)):
        b.solid(name, x0, x1, 1.4, 1.48, z0, z1, warn, collide=False)
    b.blocker("SafetyBlockerNorth", -25, 25, 0, 16, -56.75, -56 + t)
    b.blocker("SafetyBlockerWest", -24.75, -24 + t, 0, 16, -56.75, -7.25)
    b.blocker("SafetyBlockerEast", 24 - t, 24.75, 0, 16, -56.75, -7.25)
    b.blocker("SafetyBlockerSouth", -24.75, -3, 0, 16, -8.75, -8 + t)
    b.blocker("SafetyBlockerSouth", 3, 24.75, 0, 16, -8.75, -8 + t)
    b.blocker("SafetyBlockerHousing", -3, 3, 4.3, 16, -8.75, 0.25)

    # --- Beta Reactor Core  centre (0, -32)
    b.cylinder("ReactorBase", 0, -32, 0, 1.2, 3.2, steel, segments=24)
    b.cylinder("ReactorRing", 0, -32, 1.2, 1.5, 2.4, blue, collide=False, segments=24)
    b.cylinder("ReactorCore", 0, -32, 1.5, 7.2, 1.3, core_m, segments=20)
    b.cylinder("ReactorCap", 0, -32, 7.2, 7.7, 2.0, steel, collide=False, top_r=1.2, segments=20)
    b.cylinder("ReactorHalo", 0, -32, 4.2, 4.4, 1.9, blue, collide=False, segments=24)
    for px, pz in ((-4.3, -27.7), (4.3, -27.7), (-4.3, -36.3), (4.3, -36.3)):
        b.solid("ConduitPylon", px - 0.4, px + 0.4, 0, 4.5, pz - 0.4, pz + 0.4, steel)
        b.solid("ConduitGlow", px - 0.45, px + 0.45, 3.6, 3.8, pz - 0.45, pz + 0.45, blue, collide=False)

    # --- Experimental Defense Spire  north (0, -52.5)
    b.solid("SpireBase", -2.2, 2.2, 0, 3, -54.5, -51, steel)
    b.solid("SpireBaseGlow", -2.25, 2.25, 2.7, 2.85, -54.55, -50.95, red, collide=False)
    b.solid("SpireMast", -0.6, 0.6, 3, 19, -53.35, -52.15, steel, collide=False)
    b.solid("SpireRing", -1.6, 1.6, 12, 12.3, -54.35, -51.15, blue, collide=False)
    b.solid("SpireRing", -1.2, 1.2, 16, 16.3, -53.95, -51.55, blue, collide=False)
    b.solid("SpireTip", -0.8, 0.8, 19, 20.2, -53.55, -51.95, red, collide=False)

    # --- cover: HVAC units, machinery pylons, crates
    for hx, hz in ((-14, -16), (14, -16), (-14, -46), (14, -46), (-9, -38), (9, -24)):
        b.solid("HvacUnit", hx - 1.5, hx + 1.5, 0, 1.8, hz - 1.0, hz + 1.0, hvac)
        b.cylinder("HvacFan", hx, hz, 1.8, 1.9, 0.75, steel, collide=False)
    for mx, mz in ((-18, -30), (18, -34), (-6, -18), (6, -44), (-19, -52), (19, -12)):
        b.solid("MachineryPylon", mx - 0.45, mx + 0.45, 0, 4.2, mz - 0.45, mz + 0.45, steel)
        b.solid("PylonLamp", mx - 0.5, mx + 0.5, 4.2, 4.35, mz - 0.5, mz + 0.5, blue, collide=False)
    for cx, cz in ((-20, -22), (20, -42), (-3, -46.5), (3, -18)):
        b.solid("RoofCrate", cx - 0.8, cx + 0.8, 0, 1.1, cz - 0.6, cz + 0.6, hvac)
    b.solid("HazardLine", -3, 3, 0, 0.02, -9.5, -9.3, warn, collide=False)

    # --- roof beacons (corners) + distant skyline silhouettes
    for bx, bz in ((-23.5, -55.5), (23.5, -55.5), (-23.5, -8.5), (23.5, -8.5)):
        b.solid("BeaconMast", bx - 0.15, bx + 0.15, 1.4, 3.4, bz - 0.15, bz + 0.15, steel, collide=False)
        b.solid("RoofBeacon", bx - 0.3, bx + 0.3, 3.4, 3.8, bz - 0.3, bz + 0.3, red, collide=False)
    for sx0, sx1, sz0, sz1, top in ((-95, -70, -80, -50, 38), (-88, -64, -30, -5, 22), (70, 96, -70, -40, 46),
                                    (66, 90, -20, 6, 28), (-40, -10, -150, -125, 55), (5, 30, -140, -118, 34),
                                    (40, 62, -120, -100, 60), (-30, 0, 40, 60, 30), (20, 45, 35, 55, 42)):
        b.solid("Skyscraper", sx0, sx1, -90, top, sz0, sz1, tower, collide=False)
        cx = (sx0 + sx1) / 2
        cz = (sz0 + sz1) / 2
        b.solid("SkyscraperBeacon", cx - 0.6, cx + 0.6, top, top + 1.2, cz - 0.6, cz + 0.6, red, collide=False)
        for wy in (top - 10, top - 22, top - 34):
            b.solid("SkyscraperWindows", sx0 - 0.1, sx1 + 0.1, wy, wy + 0.8, sz0 - 0.1, sz1 + 0.1, windows,
                    collide=False)

    # --- lights
    cold = (0.62, 0.78, 1.0, 1)
    b.glight("HousingLight", (0, 3.4, -4), cold, 1.3, 8)
    b.glight("FloodLight", (-12, 7, -20), cold, 1.6, 18)
    b.glight("FloodLight", (12, 7, -20), cold, 1.6, 18)
    b.glight("FloodLight", (-12, 7, -46), cold, 1.5, 18)
    b.glight("FloodLight", (12, 7, -46), cold, 1.5, 18)
    b.glight("ReactorLight", (0, 4.5, -32), (0.3, 0.7, 1.0, 1), 3.0, 18, ["reactor_light"])
    b.glight("SpireLight", (0, 14, -52.75), (1.0, 0.15, 0.1, 1), 2.0, 16, ["beacon_light"])
    for bx, bz in ((-23, -55), (23, -55), (-23, -9), (23, -9)):
        b.glight("BeaconLight", (bx, 3.9, bz), (1.0, 0.1, 0.08, 1), 1.6, 9, ["beacon_light"])

    b.instance("Player", PLAYER, ".", ["position = %s" % v3(0, 0.05, -2)])

    b.ammo("NWShellsPickup", "shotgun", 8, (-21.5, 0.5, -53.5))
    b.ammo("SEAmmoPickup", "pistol", 30, (21.5, 0.5, -10.5))
    b.ammo("NEAmmoPickup", "pistol", 24, (21.5, 0.5, -53.5))
    b.ammo("SWShellsPickup", "shotgun", 6, (-21.5, 0.5, -10.5))

    b.marker("BossSpawn", (0, 0, -44))
    b.marker("ConsoleSpawn", (0, 0, -28.1))
    b.marker("ReinforceA", (-20, 0, -48))
    b.marker("ReinforceB", (20, 0, -48))
    b.marker("ReinforceC", (-20, 0, -16))
    b.marker("ReinforceD", (20, 0, -16))
    b.marker("RainOrigin", (0, 18, -32))
    b.write("scenes/levels/floor_05_rooftop.tscn")


if __name__ == "__main__":
    build_floor_02()
    build_floor_03()
    build_floor_04()
    build_floor_05()
