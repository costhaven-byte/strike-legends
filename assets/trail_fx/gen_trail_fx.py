import numpy as np
from PIL import Image
import sys, os
out = sys.argv[1]
N = 256
y, x = np.mgrid[0:N, 0:N]
cx = cy = (N-1)/2
dx, dy = (x-cx)/(N/2), (y-cy)/(N/2)
r = np.hypot(dx, dy); a = np.arctan2(dy, dx)
def save(name, alpha, rgb=(1,1,1)):
    alpha = np.clip(alpha, 0, 1)
    img = np.zeros((N,N,4))
    for i in range(3): img[...,i] = rgb[i]
    img[...,3] = alpha
    Image.fromarray((img*255).astype(np.uint8), 'RGBA').save(os.path.join(out, name))
def seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx-ax, by-ay
    t = np.clip(((px-ax)*vx+(py-ay)*vy)/(vx*vx+vy*vy), 0, 1)
    return np.hypot(px-(ax+t*vx), py-(ay+t*vy))
# Snowflake: 6 arms with side branches, soft glow
d = np.full((N,N), 9.0)
for k in range(6):
    ang = k*np.pi/3; c, s = np.cos(ang), np.sin(ang)
    d = np.minimum(d, seg_dist(dx, dy, 0, 0, 0.85*c, 0.85*s))
    for t, L in ((0.4, 0.28), (0.62, 0.2)):
        bx, by = t*c, t*s
        for side in (1, -1):
            ang2 = ang + side*np.pi/3
            d = np.minimum(d, seg_dist(dx, dy, bx, by, bx+L*np.cos(ang2), by+L*np.sin(ang2)))
snow = np.clip(1 - d/0.045, 0, 1) + 0.35*np.exp(-(d/0.12)**2) + 0.6*np.exp(-(r/0.12)**2)
save("SL_Fx_Snowflake.png", snow)
# Bubble: thin rim, soft inside, highlight
rim = np.exp(-((r-0.82)/0.06)**2)
inside = np.where(r < 0.82, 0.12 + 0.18*(r/0.82)**3, 0)
hl = np.exp(-(((dx+0.35)/0.18)**2 + ((dy+0.38)/0.12)**2))
save("SL_Fx_Bubble.png", rim + inside + 0.9*hl)
# Smoke puff: lumpy soft blob
rng = np.random.default_rng(3)
lump = np.zeros((N,N))
for _ in range(9):
    ox, oy, rad = rng.uniform(-0.35,0.35), rng.uniform(-0.35,0.35), rng.uniform(0.3,0.5)
    lump += np.exp(-(((dx-ox)**2+(dy-oy)**2)/rad**2)*2.2)
lump = lump/lump.max()
noise = np.zeros((N,N))
for f in (4, 8, 16):
    g = rng.uniform(0,1,(f+1,f+1))
    gi = np.array(Image.fromarray((g*255).astype(np.uint8)).resize((N,N), Image.BICUBIC))/255
    noise += gi/f
noise = noise/noise.max()
save("SL_Fx_Smoke.png", np.clip(lump*1.3-0.25,0,1)**1.4*(0.55+0.45*noise)*np.clip(1-r,0,1)*1.6)
# Ember: hot core + glow
save("SL_Fx_Ember.png", np.exp(-(r/0.18)**2) + 0.45*np.exp(-(r/0.5)**2))
# Flame tongue: teardrop pointing up
ty = dy + 0.1
width = 0.42*np.clip((ty+0.9)/1.5, 0, 1)**0.6*np.clip((0.75-ty)/0.75, 0, 1.2)
w = np.where(ty < 0.75, 0.38*np.sqrt(np.clip((0.75-ty)/1.6,0,1))*np.clip((ty+0.95)/0.35,0,1), 0)
flame = np.clip(1 - np.abs(dx)/np.maximum(w,1e-3), 0, 1)**0.8
save("SL_Fx_FlameTongue.png", flame*(0.7+0.3*noise))
# Goo drop: round bottom, pointed top
gy = dy - 0.15
gw = np.where(gy < 0, 0.45*np.clip((gy+0.85)/0.85,0,1)**1.3, np.sqrt(np.clip(0.45**2-gy**2,0,1)))
goo = np.clip((gw - np.abs(dx))/0.05, 0, 1)
gooHl = np.exp(-(((dx+0.15)/0.08)**2+((dy-0.2)/0.12)**2))
save("SL_Fx_Goo.png", goo*0.9 + 0.5*gooHl)
# Coin: gold disc with rim, already coloured
coin_a = np.clip((0.8 - r)/0.03, 0, 1)
img = np.zeros((N,N,4))
shade = 0.75 + 0.25*np.clip(-(dx+dy),-1,1)
ring = np.exp(-((r-0.65)/0.05)**2)
img[...,0] = np.clip(shade*1.0 + ring*0.2, 0, 1)
img[...,1] = np.clip(shade*0.78 + ring*0.15, 0, 1)
img[...,2] = np.clip(shade*0.22, 0, 1)
img[...,3] = coin_a
Image.fromarray((img*255).astype(np.uint8), 'RGBA').save(os.path.join(out, "SL_Fx_Coin.png"))
print(os.listdir(out))
