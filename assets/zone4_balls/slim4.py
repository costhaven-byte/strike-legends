import json,struct,sys
import numpy as np
src,out=sys.argv[1],sys.argv[2]
b=open(src,'rb').read()
l=struct.unpack('<I',b[12:16])[0]
j=json.loads(b[20:20+l]); bin0=20+l+8
CT={5126:('f',4),5123:('H',2),5125:('I',4)}
NC={'SCALAR':1,'VEC2':2,'VEC3':3}
def acc(i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    t,sz=CT[a['componentType']]; n=NC[a['type']]
    s=bin0+bv.get('byteOffset',0)+a.get('byteOffset',0)
    stride=bv.get('byteStride',sz*n)
    arr=np.frombuffer(b,dtype=np.dtype('<'+t),count=None,offset=0) if False else None
    out=np.zeros((a['count'],n),dtype=np.float64 if t=='f' else np.int64)
    raw=np.frombuffer(b[s:s+stride*(a['count']-1)+sz*n],dtype=np.uint8)
    for k in range(a['count']):
        out[k]=np.frombuffer(b[s+k*stride:s+k*stride+sz*n],dtype='<'+t)
    return out
nodes={n['name']:n for n in j['nodes']}
def mat(n):
    m=n.get('matrix'); return np.array(m).reshape(4,4).T if m else np.eye(4)
def geom(name):
    n=nodes[name]; pr=j['meshes'][n['mesh']]['primitives'][0]
    P=acc(pr['attributes']['POSITION']); N=acc(pr['attributes']['NORMAL']); U=acc(pr['attributes']['TEXCOORD_0'])
    I=acc(pr['indices']).ravel() if 'indices' in pr else np.arange(len(P))
    M=mat(n); P=(np.c_[P,np.ones(len(P))]@M.T)[:,:3]
    R=M[:3,:3]; N=N@R.T; N/=np.linalg.norm(N,axis=1,keepdims=True)+1e-12
    return P,N,U,I
def merge(names):
    Ps,Ns,Us,Is=[],[],[],[]; off=0
    for nm in names:
        P,N,U,I=geom(nm); Ps.append(P);Ns.append(N);Us.append(U);Is.append(I+off); off+=len(P)
    return np.vstack(Ps),np.vstack(Ns),np.vstack(Us),np.concatenate(Is)
parts=[
 ('Shell',['cloud_swirl_shell']),
 ('Inserts',['cloud_swirl_thumb_insert','cloud_swirl_finger_l_insert','cloud_swirl_finger_r_insert']),
 ('Bores',['cloud_swirl_thumb_bore','cloud_swirl_finger_l_bore','cloud_swirl_finger_r_bore']),
 ('CrystalCore',['crystal_core']),
 ('CrystalGlints',['crystal_glint_%d'%i for i in range(9)]),
 ('Diamond',['solid_gold_diamond']),
]
buf=bytearray(); bvs=[]; accs=[]; meshes=[]; outnodes=[]; mats=[]
def add(arr,dt,typ,target,mm=False):
    global buf
    while len(buf)%4: buf+=b'\0'
    data=arr.astype(dt).tobytes(); bvs.append({'buffer':0,'byteOffset':len(buf),'byteLength':len(data),'target':target}); buf+=data
    a={'bufferView':len(bvs)-1,'componentType':{'<f4':5126,'<u4':5125}[dt],'count':len(arr),'type':typ}
    if mm: a['min']=arr.min(0).tolist(); a['max']=arr.max(0).tolist()
    accs.append(a); return len(accs)-1
for i,(nm,src_names) in enumerate(parts):
    P,N,U,I=merge(src_names)
    p=add(P,'<f4','VEC3',34962,True); n=add(N,'<f4','VEC3',34962); u=add(U,'<f4','VEC2',34962); ix=add(I.reshape(-1,1),'<u4','SCALAR',34963)
    mats.append({'name':nm,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':0.5}})
    meshes.append({'name':nm,'primitives':[{'attributes':{'POSITION':p,'NORMAL':n,'TEXCOORD_0':u},'indices':ix,'material':i}]})
    outnodes.append({'name':nm,'mesh':i}); print(nm,len(P),'verts',len(I)//3,'tris')
outnodes.append({'name':'SL_Z4Ball','children':list(range(len(parts)))})
J={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[len(parts)]}],'nodes':outnodes,'meshes':meshes,'materials':mats,'accessors':accs,'bufferViews':bvs,'buffers':[{'byteLength':len(buf)}]}
js=json.dumps(J).encode(); js+=b' '*((4-len(js)%4)%4)
while len(buf)%4: buf+=b'\0'
total=12+8+len(js)+8+len(buf)
open(out,'wb').write(struct.pack('<III',0x46546C67,2,total)+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(buf),0x004E4942)+bytes(buf))
print('wrote',out,total)
