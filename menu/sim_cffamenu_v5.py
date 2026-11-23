# sim_cffamenu_v5.py - menu v5 + firmware 1.5 com dois cartoes (mestre FAT32, escravo FAT16)
import struct
from sim_cffamenu_v2 import Sys2, show, build_cfg
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)
class Sys5(Sys2):
    def __init__(s,b4,b0,master,slave):
        super().__init__(b4,b0,master); s.cards=[master,slave]
    def io_rd(s,a):
        if (a&15) in (15,6) and s.st['r'][14]&0x10 and s.cards[1] is None: return 0   # sem escravo: status 0
        return super().io_rd(a)
    def lba(s):
        s.card=s.cards[1 if s.st['r'][14]&0x10 else 0]
        return super().lba()
rom4=bytearray(open('s15.bin','rb').read()[0x600:0xE00]); b0=bytearray(open('banco0_util_C700-CEFF_v1.bin','rb').read())
m=bytearray(open('c32L.img','rb').read()); sl=bytearray(open('c16.img','rb').read())
menu=open('cffamenu_v5.bin','rb').read()
S=Sys5(rom4,b0,m,sl); S.bank=4
for i,b in enumerate(menu): S.m[0x4000+i]=b
UP,DN,LF,RT=0x0B,0x0A,0x08,0x15
S.keys=[DN,ord('1'), RT,RT,RT,UP,UP,UP, ord('2'), ord('P'),ord('2'), 13]
S.run(0x4007)
show(S.shots[-1],'dois cartoes: drive 2 com TESTE1.PO do escravo, protegido')
cfg=bytes(S.banks[4][0x780:0x780+0x61]); nm=bytes(S.banks[0][0x7C0:0x7C0+49])
check(cfg[24]==0xC0 and cfg[24+4]&0x10 and cfg[24+10]&0x10,'drive 2: montado+protegido ($%02X), LBA e diretorio no escravo'%cfg[24])
check(nm[11:22]==b'TESTE1  PO ' and nm[45:49]==bytes([0,0x10,0,0]),'nome e cartao do drive 2 guardados (%s)'%nm[45:49].hex())
exp=build_cfg(sl,[(1,'TESTE1  PO ')]); base=struct.unpack_from('<I',exp,24+1)[0]
S.m[0x47F]=0
a,cy,x,y=S.p8(1,0xF0,4); check(cy==0 and bytes(S.m[0x4000:0x4200])==sl[(base+4)*512:(base+5)*512],'driver 1.5: drive 2 le TESTE1.PO do escravo')
antes=bytes(sl); a,cy,_,_=S.p8(2,0xF0,4,buf=0x5000); check(cy==1 and a==0x2B and bytes(sl)==antes,'escrita no drive 2 protegido recusada ($%02X)'%a)
S.eewrites=0; S.shots=[]; S.run(0x4004)
check(S.eewrites==0,'boot sem tecla: nada regravado (protecao e cartao mantidos)')
print('== sem o cartao escravo')
S2=Sys5(bytearray(S.banks[4]),bytearray(S.banks[0]),m,None); S2.bank=4
for i,b in enumerate(menu): S2.m[0x4000+i]=b
S2.keys=[0x1B]; S2.run(0x4007)
show(S2.shots[-1],'sem escravo')
S2.eewrites=0; S2.run(0x4004)
check(S2.banks[4][0x780+24]&0x80==0 and bytes(S2.banks[0][0x7C0+11:0x7C0+22])==b'TESTE1  PO ','drive 2 desmontado, nome guardado para quando o escravo voltar')
print('\nRESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
