"""Cuts each egg's shell into a jagged top + bottom for the hatch (Modules/HatchV2, Config.Ui.HatchHero).

Reads the owner's egg models, writes assets/egg_halves/<EggId>.glb with four meshes (Top, Bottom = the outer shell,
keeping its UVs; TopInner, BottomInner = the inside of the shell + the broken rim, painted in the game) and
assets/egg_halves/layout.json (each piece's box, as a share of the whole shell's size, measured from the shell's centre).

Run: python tools/cut_eggs.py
"""
import json
import math
import os

import numpy as np
import trimesh

ASSETS = os.path.expanduser("~/Documents/Strike Legends Assets")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "egg_halves")

# egg Id -> (file, shell node, cut height as a share of the shell height, tooth height as a share of it)
EGGS = {
    "Speckled": ("SL_Z1_RooftopEgg_full.glb", "egg_shell", 0.60, 0.075),
    "Alley": ("SL_Z2_SunsetEgg_full.glb", "egg_shell", 0.60, 0.075),
    "Arcade": ("SL_Z3_Egg_JungleEgg_OnStand.glb", "egg_shell", 0.60, 0.075),
    "Skyline": ("SL_Z4_SunEgg_Eggonstand.glb", "sun_egg", 0.60, 0.075),
    "OP": ("skyline_egg.glb", "shell", 0.50, 0.055),  # under the window, above the gold band
}
TEETH = 9
WALL = 0.93  # the inside of the shell, as a share of the outer size
EDGE = 0.045  # triangles near the cut are split down to this size (share of the shell height)


def load_shell(file, node):
    scene = trimesh.load(os.path.join(ASSETS, file))
    transform, geometry = scene.graph[node]
    mesh = scene.geometry[geometry]
    position = trimesh.transform_points(mesh.vertices, transform)
    normal = np.asarray(mesh.vertex_normals) @ np.asarray(transform)[:3, :3].T
    normal /= np.maximum(np.linalg.norm(normal, axis=1, keepdims=True), 1e-9)
    uv = getattr(mesh.visual, "uv", None)
    if uv is None:
        uv = np.zeros((len(position), 2))
    return position, normal, np.asarray(uv, dtype=float), np.asarray(mesh.faces)


def tooth_heights(amp):
    # Uneven teeth look broken; even ones look machine-made. Fixed seed: the same cut every run.
    random = np.random.default_rng(7)
    return amp * random.uniform(0.65, 1.15, TEETH * 2) * np.where(np.arange(TEETH * 2) % 2 == 0, 1, -1)


def cut_function(cut, heights):
    count = len(heights)

    def height_at(x, z):
        u = (np.arctan2(z, x) + math.pi) / (2 * math.pi) * count
        i = np.floor(u).astype(int) % count
        t = u - np.floor(u)
        return cut + heights[i] * (1 - t) + heights[(i + 1) % count] * t

    return height_at


def subdivide_near_cut(vertices, faces, height_at):
    # vertices = N x 8 (x y z, nx ny nz, u v); splits the long edges of triangles near the cut
    for _ in range(6):
        out = []
        added = []
        base = len(vertices)
        edge_ids = {}

        def middle(a, b):
            key = (min(a, b), max(a, b))
            if key not in edge_ids:
                edge_ids[key] = base + len(added)
                added.append((vertices[a] + vertices[b]) / 2)
            return edge_ids[key]

        changed = False
        margin = np.abs(vertices[:, 1] - height_at(vertices[:, 0], vertices[:, 2]))
        for a, b, c in faces:
            p = vertices[[a, b, c], :3]
            longest = max(np.linalg.norm(p[0] - p[1]), np.linalg.norm(p[1] - p[2]), np.linalg.norm(p[2] - p[0]))
            if longest > EDGE and min(margin[a], margin[b], margin[c]) < longest + 0.02:
                ab, bc, ca = middle(a, b), middle(b, c), middle(c, a)
                out += [(a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)]
                changed = True
            else:
                out.append((a, b, c))
        faces = out
        if added:
            vertices = np.vstack([vertices, np.array(added)])
        if not changed:
            break
    return vertices, np.array(faces)


def clip(vertices, faces, height_at, keep_top):
    # Splits every triangle crossing the cut; returns the kept triangles as flat vertex rows + the open rim edges
    sign = 1 if keep_top else -1
    g = sign * (vertices[:, 1] - height_at(vertices[:, 0], vertices[:, 2]))
    rows = []
    rim = []
    for face in faces:
        corners = [vertices[i] for i in face]
        values = [g[i] for i in face]
        polygon = []
        new_points = []
        for i in range(3):
            a, b = corners[i], corners[(i + 1) % 3]
            ga, gb = values[i], values[(i + 1) % 3]
            if ga >= 0:
                polygon.append(a)
            if (ga >= 0) != (gb >= 0):
                point = a + (b - a) * (ga / (ga - gb))
                polygon.append(point)
                new_points.append(point)
        for i in range(1, len(polygon) - 1):
            rows += [polygon[0], polygon[i], polygon[i + 1]]
        if len(new_points) == 2:
            rim.append(new_points)
    return np.array(rows), rim


def to_mesh(rows, name, flat_normals=False):
    faces = np.arange(len(rows)).reshape(-1, 3)
    mesh = trimesh.Trimesh(vertices=rows[:, :3], faces=faces, process=False)
    if not flat_normals:
        mesh.vertex_normals = rows[:, 3:6]
    mesh.visual = trimesh.visual.TextureVisuals(
        uv=rows[:, 6:8],
        material=trimesh.visual.material.PBRMaterial(name=name, baseColorFactor=[255, 255, 255, 255]),
    )
    mesh.metadata["name"] = name
    return mesh


def inner_rows(outer_rows, rim_edges, centre):
    # The inside: the kept outer shell shrunk towards the centre with its faces turned round, plus the broken rim
    # joining the two walls. Their UVs are unused (the game paints these flat).
    inner = outer_rows.copy()
    inner[:, :3] = centre + (outer_rows[:, :3] - centre) * WALL
    inner[:, 3:6] = -inner[:, 3:6]
    inner[1::3], inner[2::3] = inner[2::3].copy(), inner[1::3].copy()
    rim_rows = []
    for a, b in rim_edges:
        p0, p1 = a[:3], b[:3]
        q0, q1 = centre + (p0 - centre) * WALL, centre + (p1 - centre) * WALL
        normal = np.cross(p1 - p0, q0 - p0)
        length = np.linalg.norm(normal)
        if length < 1e-9:
            continue
        normal /= length
        outward = (p0 + p1) / 2 - centre
        # the rim of a top piece faces down, of a bottom piece up; both sides are drawn so the winding can't hide it
        for tri in ((p0, p1, q1), (p0, q1, q0), (p1, p0, q1), (q1, p0, q0)):
            face_normal = np.cross(tri[1] - tri[0], tri[2] - tri[0])
            n = face_normal / max(np.linalg.norm(face_normal), 1e-9)
            for corner in tri:
                rim_rows.append(np.concatenate([corner, n, [0.5, 0.5]]))
    return np.vstack([inner, np.array(rim_rows)])


def piece_box(rows):
    low, high = rows[:, :3].min(0), rows[:, :3].max(0)
    return {"Centre": ((low + high) / 2).tolist(), "Size": (high - low).tolist()}


def main():
    os.makedirs(OUT, exist_ok=True)
    layout = {}
    for egg, (file, node, cut_share, tooth_share) in EGGS.items():
        position, normal, uv, faces = load_shell(file, node)
        low, high = position.min(0), position.max(0)
        centre = (low + high) / 2
        size = high - low
        # shell space: centre at 0, height 1 (the same scale on all axes, so the shape keeps its proportions)
        scale = 1 / size[1]
        vertices = np.hstack([(position - centre) * scale, normal, uv])
        cut = cut_share - 0.5
        height_at = cut_function(cut, tooth_heights(tooth_share))
        vertices, faces = subdivide_near_cut(vertices, faces, height_at)
        origin = np.zeros(3)
        entry = {"Cut": cut, "ShellSize": (size * scale).tolist()}
        scene = trimesh.Scene()
        counts = {}
        for name, keep_top in (("Top", True), ("Bottom", False)):
            rows, rim = clip(vertices, faces, height_at, keep_top)
            inner = inner_rows(rows, rim, origin)
            scene.add_geometry(to_mesh(rows, name), node_name=name, geom_name=name)
            scene.add_geometry(to_mesh(inner, name + "Inner"), node_name=name + "Inner", geom_name=name + "Inner")
            entry[name] = piece_box(rows)
            entry[name + "Inner"] = piece_box(inner)
            counts[name] = len(rows) // 3
            counts[name + "Inner"] = len(inner) // 3
            if not rim:
                raise RuntimeError(f"{egg}: {name} has no rim, the cut missed the shell")
        path = os.path.join(OUT, egg + ".glb")
        scene.export(path)
        layout[egg] = entry
        print(egg, counts, os.path.getsize(path) // 1024, "KB")
    with open(os.path.join(OUT, "layout.json"), "w") as handle:
        json.dump(layout, handle, indent=1)


if __name__ == "__main__":
    main()
