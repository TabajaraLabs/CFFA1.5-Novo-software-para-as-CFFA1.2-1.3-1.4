# sim_fw15_v1.py - testes novos do 1.5: protecao contra escrita e imagem no cartao escravo (bit DEV)
import struct
from sim_fw14_v2 import Sys, build_cfg
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)
class Sys2c(Sys):
    """dois cartoes: bit 4 do registrador Head escolhe o escravo"""
    def __init__(s,b4,b0,master,slave):
        super().__init__(b4,b0,master); s.cards=[master,slave]
    def lba(s):
        s.card=s.cards[1 if s.st['r'][14]&0x10 else 0]
        return super().lba()
rom=bytearray(open('s15.bin','rb').read()[0x600:0xE00])
m=bytearray(open('c32.img','rb').read()); sl=bytearray(open('c16.img','rb').read())
cm=build_cfg(m,[(0,'TESTE1  PO ')]); cs=build_cfg(sl,[(1,'HD32    PO ')])
cfg=bytearray(cm[:24])+bytearray(cs[24:48])+bytes(48)+cm[0x60:0x61]+bytes(0x80-0x61)
cfg[24+4]|=0x10; cfg[24+10]|=0x10        # drive 2: imagem e diretorio no escravo
cfg[0]|=0x40                              # drive 1 protegido
b4=bytearray(rom); b4[0x780:0x800]=cfg
S=Sys2c(b4,bytearray([0xFF]*2048),m,sl)
a,cy,x,y=S.p8(0,0x70,0); check(cy==0 and x+256*y==1600,'drive 1 (mestre) %d blocos'%(x+256*y))
a,cy,x,y=S.p8(0,0xF0,0); check(cy==0 and x+256*y==65535,'drive 2 (escravo) %d blocos, FatFlags=%02X'%(x+256*y,S.m[0x57F]))
b1=struct.unpack_from('<I',cm,1)[0]; b2=struct.unpack_from('<I',cs,24+1)[0]
a,cy,_,_=S.p8(1,0x70,3); check(cy==0 and bytes(S.m[0x4000:0x4200])==m[(b1+3)*512:(b1+4)*512],'leitura no drive protegido funciona')
antes=bytes(m); a,cy,_,_=S.p8(2,0x70,3,buf=0x5000); check(cy==1 and a==0x2B and bytes(m)==antes,'escrita no drive protegido: erro %02X, nada gravado'%a)
a,cy,_,_=S.sp(2,[3,1,0x00,0x50,3,0,0]); check(cy==1 and a==0x2B,'escrita SmartPort no protegido: erro %02X'%a)
a,cy,_,_=S.p8(1,0xF0,0x1234); check(cy==0 and bytes(S.m[0x4000:0x4200])==sl[(b2+0x1234)*512:(b2+0x1235)*512],'leitura do drive 2 vem do cartao escravo')
for i in range(512): S.m[0x5000+i]=(i*3)&255
a,cy,_,_=S.p8(2,0xF0,9,buf=0x5000); check(cy==0 and sl[(b2+9)*512:(b2+10)*512]==bytes(S.m[0x5000:0x5200]) and m==antes,'escrita no drive 2 vai para o escravo (mestre intacto)')
print('\nRESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
