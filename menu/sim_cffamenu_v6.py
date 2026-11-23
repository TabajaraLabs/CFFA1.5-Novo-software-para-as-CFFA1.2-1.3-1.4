# sim_cffamenu_v6.py - menu v6: ordem alfabetica, letra, subpastas, nome do volume, SHIFT+1 protege
import struct
from sim_cffamenu_v2 import Sys2, show, build_cfg
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)
class Sys1(Sys2):
    def io_rd(s,a):
        if (a&15) in (15,6) and s.st['r'][14]&0x10: return 0      # sem escravo
        return super().io_rd(a)
rom4=bytearray(open('s15.bin','rb').read()[0x600:0xE00]); b0=bytearray(open('banco0_util_C700-CEFF_v2.bin','rb').read())
card=bytearray(open('c32F.img','rb').read()); menu=open('cffamenu_v6.bin','rb').read()
S=Sys1(rom4,b0,card); S.bank=4
for i,b in enumerate(menu): S.m[0x4000+i]=b
UP,DN,LF,RT=0x0B,0x0A,0x08,0x15
S.keys=[DN,DN,DN,ord('z'), UP,UP,UP,UP,UP, 13, DN,DN,DN, ord('1'), ord('!'), 13]
S.run(0x4007)
show(S.shots[0],'raiz: pastas primeiro, depois ordem alfabetica')
show(S.shots[4],'tecla Z: barra em zork one.po (e o volume dele na ultima linha)')
show(S.shots[9],'dentro da pasta Jogos')
show(S.shots[-1],'Karateka montado no drive 1 e protegido (SHIFT+1)')
cfg=bytes(S.banks[4][0x780:0x780+24])
check(cfg[0]==0xC0,'drive 1 montado e protegido ($%02X)'%cfg[0])
check(bytes(S.banks[0][0x7C0:0x7C0+11])==b'KARATEKAPO ','nome KARATEKA.PO guardado')
print('== boot sem tecla (imagem dentro de subpasta)')
S.eewrites=0; S.shots=[]; S.m[0x47F]=0
S.run(0x4004)
check(S.eewrites==0 and S.banks[4][0x780]==0xC0,'continua montado e protegido; nada regravado')
show(S.shots[0] if S.shots else (None,None),'') if S.shots else None
a,cy,x,y=S.p8(0,0x70,0); check(cy==0 and x+256*y==280,'driver: drive 1 = %d blocos'%(x+256*y))
a,cy,_,_=S.p8(1,0x70,2); check(cy==0 and bytes(S.m[0x4005:0x400D])==b'JOGOS.UM','bloco 2 do drive 1 = volume /JOGOS.UM')
print('\nRESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
