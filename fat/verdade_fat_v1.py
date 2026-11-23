# verdade.py - calcula em Python o que o fatcat deve mostrar (referencia)
import struct,sys
d=open(sys.argv[1],'rb').read()
def u(o,n): return int.from_bytes(d[o:o+n],'little')
pst=0 if d[0] in (0xEB,0xE9) else u(0x1C6,4)
b=pst*512; spc=d[b+13]; rs=u(b+14,2); nf=d[b+16]; re=u(b+17,2); fz=u(b+22,2) or u(b+36,4)
f32=u(b+22,2)==0; fat=pst+rs; root=fat+nf*fz; data=root+re//16
print('FAT32' if f32 else 'FAT16','PART %08X SPC %d FAT %08X DADOS %08X'%(pst,spc,fat,data))
def nxt(c):
    if f32: return u(fat*512+c*4,4)&0x0FFFFFFF
    return u(fat*512+c*2,2)
def chain(c):
    out=[c]
    while True:
        n=nxt(c)
        if n>=(0x0FFFFFF8 if f32 else 0xFFF8) or n<2: return out
        out.append(n); c=n
rc=u(b+44,4)
secs=[]
if f32:
    for c in chain(rc): secs+= [data+(c-2)*spc+i for i in range(spc)]
else: secs=[root+i for i in range(re//16)]
for s in secs:
    for k in range(16):
        e=d[s*512+k*32:s*512+k*32+32]
        if e[0]==0: sys.exit()
        if e[0]==0xE5 or e[11]==0x0F or e[11]&0x18: continue
        if e[8:11] in (b'PO ',b'HDV',b'IMG'):
            c=u(s*512+k*32+26,2)|(u(s*512+k*32+20,2)<<16 if f32 else 0); sz=u(s*512+k*32+28,4)
            if c==0: print(e[:8].decode(),e[8:11].decode(),'VAZIO'); continue
            ch=chain(c); cont=all(ch[i+1]==ch[i]+1 for i in range(len(ch)-1))
            print(e[:8].decode(),e[8:11].decode(),'%06X %08X %08X'%(sz>>9,c,data+(c-2)*spc),'OK' if cont else 'FRAGMENTADO','(%d clusters)'%len(ch))
