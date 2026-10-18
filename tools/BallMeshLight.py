"""Make light ball meshes from the geometry dumped out of Studio (geo_*.json, model space, shell = 1 stud).

Spheres (shells, glow shells) are rebuilt as clean UV spheres with the old texture mapping.
Everything else is merged per look (Mat + material + colour + transparency) and decimated.
Writes light/<Ball>.json (for an EditableMesh preview) and SL_BallsLight.glb (for the 3D importer).

Usage: TOL=0.003 python tools/BallMeshLight.py <dump folder>   (needs trimesh, pymeshlab, scipy, networkx)
The dump folder holds studio_models.json plus geo_<Ball>__<n>.json, posted out of Studio with execute_luau.
The 3D importer turns the glb half a turn about Y, so rebuilt parts use CFrame.Angles(0, math.pi, 0).
2026-10-18 result: 580,040 -> 50,930 triangles for all 20 balls.
"""
import glob, json, math, os, sys, collections
import numpy as np, trimesh, pymeshlab

SRV = sys.argv[1]
OUT = os.path.join(SRV, "light")
os.makedirs(OUT, exist_ok=True)
TARGET = int(sys.argv[2]) if len(sys.argv) > 2 else 2500

studio = json.load(open(os.path.join(SRV, "studio_models.json")))


def load_part(f):
    d = json.load(open(f))
    if d.get("split"):
        base = f[:-5]
        d["V"] = json.load(open(base + "_V.json"))
        d["F"] = json.load(open(base + "_F.json"))
        if os.path.exists(base + "_UVa.json"):
            d["UV"] = json.load(open(base + "_UVa.json")) + json.load(open(base + "_UVb.json"))
    return d


def sphere_info(V, F):
    c = (V.min(0) + V.max(0)) / 2
    r = np.linalg.norm(V - c, axis=1)
    if r.mean() > 0.3 and r.max() - r.min() < 0.002 * r.mean():
        area = trimesh.Trimesh(V, F, process=False).area
        if area > 0.97 * 4 * math.pi * r.mean() ** 2:
            return c, float(r.mean())
    return None


def fit_uv(V, F, UV, c):
    """Find v = a*lat + b and u = s*lon + o (mod 1) from the old sphere's face-corner UVs."""
    P = V[F.reshape(-1)] - c
    uv = UV.reshape(-1, 2)
    up = P[uv[:, 1] < uv[:, 1].min() + 0.005].mean(0)
    up /= np.linalg.norm(up)
    x = np.cross(up, [0, 0, 1.0]) if abs(up[2]) < 0.9 else np.cross(up, [1.0, 0, 0])
    x /= np.linalg.norm(x)
    z = np.cross(x, up)
    R = np.column_stack([x, up, z])
    P = P @ R
    r = np.linalg.norm(P, axis=1)
    lat = np.arcsin(np.clip(P[:, 1] / r, -1, 1))
    lon = np.arctan2(P[:, 0], P[:, 2])
    a, b = np.polyfit(lat, uv[:, 1], 1)
    keep = (np.abs(lat) < 1.2) & (uv[:, 0] > 0.05) & (uv[:, 0] < 0.95)
    best = None
    for s in (1 / (2 * math.pi), -1 / (2 * math.pi)):
        o = np.angle(np.mean(np.exp(2j * math.pi * (uv[keep, 0] - s * lon[keep])))) / (2 * math.pi)
        err = np.abs(((uv[keep, 0] - (s * lon[keep] + o)) + 0.5) % 1 - 0.5).mean()
        if best is None or err < best[0]:
            best = (err, s, o)
    return a, b, best[1], best[2] % 1, best[0], R


def uv_sphere(c, r, seg, rings, uvfit=None):
    """Seam column duplicated so the texture wraps cleanly."""
    if uvfit:
        a, b, s, o = uvfit
        # longitude where u = 0
        lon0 = -o / s
        sgn = 1 if s > 0 else -1
    else:
        lon0, sgn = 0.0, 1
    V, UV, N = [], [], []
    for i in range(rings + 1):
        lat = math.pi / 2 - math.pi * i / rings
        for j in range(seg + 1):
            t = j / seg
            lon = lon0 + sgn * 2 * math.pi * t
            n = np.array([math.cos(lat) * math.sin(lon), math.sin(lat), math.cos(lat) * math.cos(lon)])
            V.append(c + r * n)
            N.append(n)
            if uvfit:
                UV.append([t, a * lat + b])
            else:
                UV.append([t, i / rings])
    F = []
    W = seg + 1
    for i in range(rings):
        for j in range(seg):
            p0, p1, p2, p3 = i * W + j, i * W + j + 1, (i + 1) * W + j, (i + 1) * W + j + 1
            if i != 0:
                F.append([p0, p2, p1])
            if i != rings - 1:
                F.append([p1, p2, p3])
    F = np.array(F)
    V = np.array(V)
    # keep outward winding
    cen = V[F].mean(1) - c
    nrm = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    if (np.einsum("ij,ij->i", cen, nrm) < 0).mean() > 0.5:
        F = F[:, [0, 2, 1]]
    return V, F, np.array(UV), np.array(N)


def winding_out(V, F, Forig, Vorig):
    return F


def _collapse(m, target):
    c = m.vertices.mean(0)
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh((m.vertices - c) * 100, m.faces))
    ms.meshing_decimation_quadric_edge_collapse(targetfacenum=target, preservenormal=True, preservetopology=False,
                                                optimalplacement=True, planarquadric=True, preserveboundary=True)
    ms.add_mesh(pymeshlab.Mesh((m.vertices - c) * 100, m.faces))  # id 1 = original
    h = ms.get_hausdorff_distance(sampledmesh=1, targetmesh=0, samplenum=4000)
    h2 = ms.get_hausdorff_distance(sampledmesh=0, targetmesh=1, samplenum=4000)
    out = ms.mesh(0)
    return out.vertex_matrix() / 100 + c, out.face_matrix(), max(h["max"], h2["max"]) / 100


TOL = float(os.environ.get("TOL", "0.0015"))


def decimate(V, F, target):
    """Fewest triangles (not below `target`) that stay within TOL studs (shell = 1) of the original."""
    m = trimesh.Trimesh(V, F, process=True)  # merges duplicate verts
    n = len(m.faces)
    if n <= target:
        return m.vertices, m.faces
    lo, hi = target, n
    best = None
    v, f, err = _collapse(m, lo)
    if err <= TOL:
        return v, f
    while hi - lo > max(8, lo // 8):
        mid = (lo + hi) // 2
        v, f, err = _collapse(m, mid)
        if err <= TOL:
            hi, best = mid, (v, f)
        else:
            lo = mid
    if best is None:
        return m.vertices, m.faces
    return best


def smooth_normals(V, F, angle=45):
    m = trimesh.Trimesh(V, F, process=False)
    sm = trimesh.graph.smooth_shade(m, angle=math.radians(angle))
    return sm.vertices, sm.faces, sm.vertex_normals


def fmt(x):
    return [round(float(v), 5) for v in np.asarray(x).reshape(-1)]


report = []
scene = trimesh.Scene()
for ball, info in sorted(studio.items()):
    props = {}
    for p in info["parts"]:
        props.setdefault(p["n"], []).append(p)
    files = sorted(glob.glob(os.path.join(SRV, f"geo_{ball}__*.json")))
    files = [f for f in files if os.path.basename(f).count("__") == 1 and not f.endswith(("_V.json", "_F.json", "_UVa.json", "_UVb.json"))]
    groups = collections.OrderedDict()
    before = 0
    for f in files:
        d = load_part(f)
        V = np.array(d["V"]).reshape(-1, 3)
        F = np.array(d["F"]).reshape(-1, 3)
        before += len(F)
        cand = [p for p in props.get(d["n"], []) if p.get("mesh") == d["mesh"]]
        p = cand[0]
        sph = sphere_info(V, F)
        key = (p["mat"], p["material"], p["color"], round(p["tr"], 3), p.get("tex") or "", "S" if sph else "M")
        if sph:
            key = key + (d["n"],)  # each sphere stays its own part
        g = groups.setdefault(key, {"names": [], "V": [], "F": [], "sphere": sph, "uv": None, "p": p})
        g["names"].append(d["n"])
        if sph:
            if d.get("UV"):
                a, b, s, o, err, R = fit_uv(V, F, np.array(d["UV"]), sph[0])
                g["uv"] = (a, b, s, o)
                g["R"] = R
                g["uverr"] = err
        else:
            g["V"].append(V)
            g["F"].append(F)

    # budget: spheres fixed, rest split by sqrt of their size
    sphere_tris = 0
    for g in groups.values():
        if g["sphere"]:
            textured = bool(g["p"].get("tex"))
            g["seg"], g["rings"] = (36, 18) if textured else ((32, 16) if g["p"]["n"] == "Shell" else (24, 12))
            sphere_tris += g["seg"] * (2 * g["rings"] - 2)
    rest = [g for g in groups.values() if not g["sphere"]]
    for g in rest:
        g["Fc"] = np.vstack(g["F"])
    left = max(TARGET - sphere_tris, 300 * max(len(rest), 1))
    w = {id(g): math.sqrt(len(g["Fc"])) for g in rest}
    tw = sum(w.values()) or 1
    out_parts = []
    after = 0
    for key, g in groups.items():
        name = g["names"][0] if len(g["names"]) == 1 else f'{key[0]}_x{len(g["names"])}'
        if g["sphere"]:
            c, r = g["sphere"]
            # the shell sits a hair (0.7%) lower so stripes and decals laid 0.3% above it never flicker
            rr = r * 0.993 if g["p"]["n"] == "Shell" else r
            V, F, UV, N = uv_sphere(np.zeros(3), rr, g["seg"], g["rings"], g["uv"])
            if g.get("R") is not None:
                V, N = V @ g["R"].T, N @ g["R"].T
            V = V + c
            if not g["p"].get("tex"):
                UV = None
        else:
            tgt = max(60, int(left * w[id(g)] / tw))
            pw = [math.sqrt(len(f)) for f in g["F"]]
            Vs, Fs, Ns, off = [], [], [], 0
            for pv, pf, ww in zip(g["V"], g["F"], pw):
                v, f = decimate(pv, pf, 24)
                v, f, n = smooth_normals(v, f)
                Vs.append(v); Fs.append(f + off); Ns.append(n); off += len(v)
            V, F, N = np.vstack(Vs), np.vstack(Fs), np.vstack(Ns)
            UV = None
        after += len(F)
        mn, mx = V.min(0), V.max(0)
        out_parts.append({"name": "Shell" if g["p"]["n"] == "Shell" else name, "from": g["names"], "mat": key[0], "src": g["p"]["n"],
                          "V": fmt(V), "F": [int(x) for x in np.asarray(F).reshape(-1)], "N": fmt(N),
                          "UV": fmt(UV) if UV is not None else None, "bbmin": fmt(mn), "bbmax": fmt(mx)})
        # glb node in model space (studs); importer re-centres, rebuild uses bbmin/bbmax
        tm = trimesh.Trimesh(V, F, vertex_normals=N, process=False)
        if UV is not None:
            tm.visual = trimesh.visual.TextureVisuals(uv=np.column_stack([UV[:, 0], 1 - UV[:, 1]]))
        scene.add_geometry(tm, node_name=f"{ball}__{out_parts[-1]['name']}", geom_name=f"{ball}__{out_parts[-1]['name']}")
    json.dump({"ball": ball, "parts": out_parts}, open(os.path.join(OUT, f"{ball}.json"), "w"))
    uverr = [round(g.get("uverr", 0), 4) for g in groups.values() if g.get("uverr") is not None]
    report.append((before, f"{ball:10s} {before:7d} -> {after:5d} tris, {sum(len(g['names']) for g in groups.values()):2d} -> {len(groups):2d} parts  uvfit_err={uverr}"))

for _, line in sorted(report, reverse=True):
    print(line)
print("ALL", sum(b for b, _ in report))
scene.export(os.path.join(OUT, "SL_BallsLight.glb"))
