# Writes z3nodes.json: per file, every mesh node {n=name, c=[x,y,z] world bbox centre, m=material index} + materials
import json, sys, os
import numpy as np
sys.path.insert(0, os.path.expandvars(r"%TEMP%\claude\sl"))
from glbmap import load

def mat4(n):
    if 'matrix' in n: return np.array(n['matrix']).reshape(4,4).T
    t=n.get('translation',[0,0,0]); r=n.get('rotation',[0,0,0,1]); s=n.get('scale',[1,1,1])
    x,y,z,w=r
    R=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    M=np.eye(4); M[:3,:3]=R*np.array(s); M[:3,3]=t; return M

D = os.path.expanduser(r"~/Documents/Strike Legends Assets")
FILES = ["SL_Z3_SellStall","SL_Z3_ShopStall_BallsAndBags","SL_Z3_Gate_CanyonOasis_Closed","SL_Z3_Egg_JungleEgg_OnStand","SL_Z3_DisplayCase_Common","PET_TreeFrog_Rare","PET_ToucanTom_Epic","PET_JaguarCub_Legendary","PET_TempleMonkey_Legendary","SL_Z3_Hero_GiantJungleTree","SL_Z3_Hero_RopeBridge","SL_Z3_Hero_TempleRuin","SL_Z3_Hero_WaterfallCliff"]
out = {}
for f in FILES:
    g = load(os.path.join(D, f + ".glb"))
    mats = []
    for m in g['materials']:
        p = m.get('pbrMetallicRoughness', {}); ex = m.get('extras', {})
        bc = p.get('baseColorFactor', [1,1,1,1])
        ei = m.get('extensions', {}).get('KHR_materials_emissive_strength', {}).get('emissiveStrength', 0 if not m.get('emissiveFactor') else 1)
        mats.append({"name": m['name'], "hex": ex.get('hex', '#FFFFFF')[1:], "a": round(bc[3], 3), "metal": p.get('metallicFactor', 0),
                     "rough": p.get('roughnessFactor', 1), "glow": bool(ex.get('glow')), "ei": ei, "tex": bool(ex.get('tex'))})
    nodes = []
    def walk(i, P, grp=None):
        n = g['nodes'][i]; W = P @ mat4(n)
        if 'mesh' in n:
            pr = g['meshes'][n['mesh']]['primitives'][0]
            a = g['accessors'][pr['attributes']['POSITION']]; lo, hi = np.array(a['min']), np.array(a['max'])
            cs = np.array([[x,y,z,1] for x in (lo[0],hi[0]) for y in (lo[1],hi[1]) for z in (lo[2],hi[2])]) @ W.T
            c = (cs[:,:3].min(0) + cs[:,:3].max(0)) / 2
            nodes.append({"n": n.get('name',''), "c": [round(float(v),3) for v in c], "m": pr.get('material', 0), "g": grp or ""})
        # grp = the named group right under the file's root (e.g. the gate's Door_L, a lineup pet), kept for the build
        sub = grp if grp is not None else ("" if depth.get(i, 0) < 2 else n.get('name', ''))
        for ch in n.get('children', []):
            depth[ch] = depth.get(i, 0) + 1
            walk(ch, W, sub if depth[ch] > 2 else None)
    depth = {}
    for r in g['scenes'][g.get('scene',0)]['nodes']: walk(r, np.eye(4))
    out[f] = {"mats": mats, "nodes": nodes}
json.dump(out, open(os.path.join(os.path.dirname(__file__), "z3nodes.json"), "w"), separators=(',',':'))
print({k: len(v['nodes']) for k, v in out.items()})
