import numpy as np
from PIL import Image
import sys, os
out = sys.argv[1]; N=256
y, x = np.mgrid[0:N, 0:N]; dx=(x-127.5)/128; dy=(y-127.5)/128
r=np.hypot(dx,dy)
rng=np.random.default_rng(5)
def noise():
    n=np.zeros((N,N))
    for f in (3,6,12):
        g=rng.uniform(0,1,(f+1,f+1))
        n+=np.array(Image.fromarray((g*255).astype(np.uint8)).resize((N,N),Image.BICUBIC))/255/f
    return n/n.max()
def save(name,a):
    img=np.ones((N,N,4)); img[...,3]=np.clip(a,0,1)
    Image.fromarray((img*255).astype(np.uint8),'RGBA').save(os.path.join(out,name))
# flame: round base at dy=0.45 radius 0.38, tapering to tip at dy=-0.9, wavy
n=noise()
t=np.clip((0.45-dy)/1.35,0,1)              # 0 at base centre, 1 at tip
half=0.4*(1-t)**0.9
wave=0.08*np.sin(dy*7+1.3)*t
inner=np.where(dy>0.45, np.sqrt(np.clip(0.4**2-(dy-0.45)**2,0,1)), half)
f=np.clip((inner-np.abs(dx-wave))/0.12,0,1)
save("SL_Fx_FlameTongue.png", f*(0.6+0.5*n)*np.clip(1-t*0.4,0,1))
# smoke: big lumpy blob filling the frame
n=noise(); lump=np.zeros((N,N))
for _ in range(10):
    ox,oy,rad=rng.uniform(-0.3,0.3),rng.uniform(-0.3,0.3),rng.uniform(0.35,0.55)
    lump+=np.exp(-((dx-ox)**2+(dy-oy)**2)/rad**2*1.6)
lump/=lump.max()
save("SL_Fx_Smoke.png", np.clip(lump*1.2-0.1,0,1)*(0.5+0.5*n)*np.clip((1-r)*2,0,1))
