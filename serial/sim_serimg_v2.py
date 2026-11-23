# sim_serimg_v2.py - serimg v2 (CLD na entrada) contra o v1, os dois comecando com P=$FF
# (o que o G do monitor faz depois de um boot ProDOS, que deixa $FF em $48)
import struct, os
from sim_fw14_v2 import Sys, build_cfg
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)
class SysS(Sys):
    def __init__(s,*a):
        super().__init__(*a); s.rx=[]; s.tx=bytearray(); s.file=b''; s.blk=0; s.go=False
        s.m.subscribe_to_read([0xC098,0xC099,0xC09B,0xC000],s.ssc_rd); s.m.subscribe_to_write([0xC098,0xC09B,0xC010],s.ssc_wr)
    def ssc_rd(s,a):
        if a==0xC099: return 0x10|(0x08 if s.rx else 0)
        if a==0xC098: return s.rx.pop(0) if s.rx else 0
        if a==0xC09B: return 0x1E
        return 0
    def ssc_wr(s,a,v):
        if a==0xC098:
            s.tx.append(v)
            if s.mode=='send' and not s.go and bytes(s.tx).endswith(b'\x1b\x01BK'):
                s.go=True; s.rx.append(0x06)
            if v==6 and s.mode=='recv' and s.blk*512<len(s.file):
                s.rx+=list(s.file[s.blk*512:(s.blk+1)*512]); s.blk+=1
    def run(s,pc,maxsteps=20_000_000,stop=0,p=None):
        if p is not None: s.c.p=p
        return super().run(pc,maxsteps,stop)
rom=bytearray(open('s15.bin','rb').read()[0x600:0xE00])
card0=bytearray(open('c32.img','rb').read())
cfg=build_cfg(card0,[(1,'TESTE1  PO ')]); base=struct.unpack_from('<I',cfg,24+1)[0]
b4=bytearray(rom); b4[0x780:0x780+0x61]=cfg[:0x61]
N=300
img=b''.join(bytes([b&255,b>>8])+os.urandom(510) for b in range(N))   # cada bloco comeca com o proprio numero
def backup(prog):
    card=bytearray(card0); card[base*512:(base+N)*512]=img
    S=SysS(b4,bytearray(b4),card); S.bank=4; S.mode='send'
    for i,b in enumerate(open(prog,'rb').read()): S.m[0x6000+i]=b
    S.m[0x6003]=1; S.m[0x6004]=0xF0; S.m[0x6005]=N&255; S.m[0x6006]=N>>8; S.m[0x6007]=0; S.m[0x6008]=0; S.m[0x6009]=1
    S.run(0x6000,maxsteps=900_000_000,p=0xFF)
    t=bytes(S.tx); i=t.index(b'\x1b\x01BK')+4; return t[i+2:i+2+N*512], ''.join(S.out).strip()
def grava(prog):
    card=bytearray(card0)
    S=SysS(b4,bytearray(b4),card); S.bank=4; S.mode='recv'; S.file=img
    for i,b in enumerate(open(prog,'rb').read()): S.m[0x6000+i]=b
    S.m[0x6003]=0; S.m[0x6004]=0xF0; S.m[0x6005]=N&255; S.m[0x6006]=N>>8; S.m[0x6007]=0; S.m[0x6008]=0; S.m[0x6009]=1; S.m[0x600A]=1
    S.run(0x6000,maxsteps=900_000_000,p=0xFF)
    return bytes(card[base*512:(base+N)*512]), ''.join(S.out).strip()
def lidos(d): return [d[k*512]|d[k*512+1]<<8 for k in range(len(d)//512)]
print('== v1 com P=$FF (reproduz o bug da bancada)')
d,out=backup('serimg_v1.bin'); L=lidos(d)
errados=[k for k in range(len(L)) if L[k]!=k]
print('   v1: %d de %d blocos chegaram; %d com o numero errado; Apple: %s'%(len(L),N,len(errados),out))
check(len(L)<N or errados,'v1 com D=1: o backup sai errado (bloco errado ou erro do driver)')
g,out=grava('serimg_v1.bin')
check(g!=img,'v1: a gravacao com D=1 espalha os blocos no lugar errado (Apple: %s)'%out)
print('== v2 com P=$FF')
d,out=backup('serimg_v2.bin')
check(d==img,'v2: backup dos %d blocos chegou igual'%N)
g,out=grava('serimg_v2.bin')
check(g==img and out.endswith('OK'),'v2: gravacao + releitura certas (Apple: %s)'%out)
print('\nRESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
