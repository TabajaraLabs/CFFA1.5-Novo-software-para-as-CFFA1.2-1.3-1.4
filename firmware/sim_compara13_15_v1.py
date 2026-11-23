# compara o firmware 1.3 e o 1.4 num cartao cru (modo classico): devem responder igual
import random, struct
from sim_fw14_v1 import Sys
r13=open('s13.bin','rb').read()[0x600:0xE00]; r14=open('s15.bin','rb').read()[0x600:0xE00]
N=125440
card=bytearray(N*512)
for l in range(0,N,1): card[l*512:l*512+4]=struct.pack('<I',l)
card[0]=0x01
A=Sys(bytearray(r13),bytearray(r13),bytearray(card)); B=Sys(bytearray(r14),bytearray(r14),bytearray(card))
A.bank=B.bank=4
random.seed(1); dif=0; n=0
for t in range(300):
    op=random.choice(['p8r','p8w','p8s','spr','sps','sp127'])
    unit=random.choice([0x70,0xF0,0x20,0xA0]); blk=random.choice([0,1,5,0x1234,0xFFFE,0xFFFF,random.randrange(65536)])
    for S in (A,B):
        for i in range(512): S.m[0x5000+i]=(i+t)&255
    if op=='p8r': ra=A.p8(1,unit,blk); rb=B.p8(1,unit,blk)
    elif op=='p8w': ra=A.p8(2,unit,blk,0x5000); rb=B.p8(2,unit,blk,0x5000)
    elif op=='p8s': ra=A.p8(0,unit,blk); rb=B.p8(0,unit,blk)
    elif op=='spr':
        u=random.randint(1,5); pl=[3,u,0,0x40,blk&255,blk>>8,0]; ra=A.sp(1,pl); rb=B.sp(1,pl)
    elif op=='sps':
        u=random.randint(0,5); pl=[3,u,0,0x60,0]; ra=A.sp(0,pl); rb=B.sp(0,pl)
    else:
        pl=[3,127,0,0x40,blk&255,blk>>8,random.randint(0,1)]; ra=A.sp(1,pl); rb=B.sp(1,pl)
    same = ra==rb and bytes(A.m[0x4000:0x4200])==bytes(B.m[0x4000:0x4200]) and bytes(A.m[0x6000:0x6010])==bytes(B.m[0x6000:0x6010])
    n+=1
    if not same:
        dif+=1
        if dif<6: print('DIFERENTE',op,hex(unit),hex(blk),ra,rb)
print('chamadas',n,'diferencas',dif,'cartao igual',A.card==B.card,'escritas',len(A.st['writes']),len(B.st['writes']))
