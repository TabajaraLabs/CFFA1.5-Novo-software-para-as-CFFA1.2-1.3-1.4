# mkdisco_prodos_v1.py - gera um volume ProDOS (140 KB, ordem ProDOS) com arquivos BIN
# uso: python3 mkdisco_prodos_v1.py SAIDA.po VOLNOME arquivo:NOME:aux_hex ...
import sys,struct
out,vol=sys.argv[1],sys.argv[2].upper(); files=[]
for a in sys.argv[3:]:
    p,n,aux=a.split(':'); files.append((open(p,'rb').read(),n.upper(),int(aux,16)))
NB=280; img=bytearray(NB*512); used=set(range(0,7))   # 0-1 boot, 2-5 diretorio, 6 bitmap
def date(): return struct.pack('<HBB',(26<<9)|(11<<5)|20,0,9)   # 20/11/26 09:00
nxt=[7]
def alloc():
    b=nxt[0]; nxt[0]+=1; used.add(b); return b
for i,b in enumerate(range(2,6)):
    struct.pack_into('<HH',img,b*512,2+i-1 if i else 0,b+1 if b<5 else 0)
h=bytearray(39); h[0]=0xF0|len(vol); h[1:1+len(vol)]=vol.encode(); h[24:28]=date()
h[30]=0xC3; h[31]=0x27; h[32]=0x0D; struct.pack_into('<HHH',h,33,len(files),6,NB)
img[2*512+4:2*512+43]=h
for k,(d,n,aux) in enumerate(files):
    nblk=(len(d)+511)//512
    if nblk<=1: st=1; key=alloc(); img[key*512:key*512+len(d)]=d; usedb=1
    else:
        assert nblk<=256; st=2; key=alloc()
        for j in range(nblk):
            b=alloc(); img[b*512:b*512+512]=d[j*512:(j+1)*512].ljust(512,b'\0')
            img[key*512+j]=b&255; img[key*512+256+j]=b>>8
        usedb=nblk+1
    e=bytearray(39); e[0]=(st<<4)|len(n); e[1:1+len(n)]=n.encode(); e[16]=0x06
    struct.pack_into('<HH',e,17,key,usedb); e[21:24]=len(d).to_bytes(3,'little'); e[24:28]=date()
    e[30]=0xE3; struct.pack_into('<H',e,31,aux); e[33:37]=date(); struct.pack_into('<H',e,37,2)
    slot=k+1; blk=2+slot//13; off=4+(slot%13)*39
    img[blk*512+off:blk*512+off+39]=e
for b in range(NB):
    if b not in used: img[6*512+b//8]|=0x80>>(b%8)
open(out,'wb').write(img)
# conferencia: le de volta
d=img; hb=2*512+4
print('volume',d[hb+1:hb+1+(d[hb]&15)].decode(),'arquivos',struct.unpack_from('<H',d,hb+33)[0])
for k in range(len(files)):
    slot=k+1; o=(2+slot//13)*512+4+(slot%13)*39; e=d[o:o+39]
    st=e[0]>>4; key,ub=struct.unpack_from('<HH',e,17); eof=int.from_bytes(e[21:24],'little'); aux=struct.unpack_from('<H',e,31)[0]
    if st==1: data=d[key*512:key*512+eof]
    else: data=b''.join(d[(d[key*512+j]|d[key*512+256+j]<<8)*512:][:512] for j in range((eof+511)//512))[:eof]
    print(' %-15s tipo $%02X aux $%04X %5d bytes blocos %d confere=%s'%(e[1:1+(e[0]&15)].decode(),e[16],aux,eof,ub,data==files[k][0]))
print('blocos livres',sum(bin(x).count('1') for x in d[6*512:6*512+35]))
