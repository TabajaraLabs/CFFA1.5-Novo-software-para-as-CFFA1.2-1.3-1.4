# sim_boot_completo_v8.py - $C700 (1.5) -> carregador do banco 0 v2 -> CFFAMENU v8 do cartao -> boot
import struct
from sim_cffamenu_v2 import Sys2, show, screen, build_cfg
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)
class Sys1(Sys2):
    def io_rd(s,a):
        if (a&15) in (15,6) and s.st['r'][14]&0x10: return 0
        return super().io_rd(a)
rom4=bytearray(open('s15.bin','rb').read()[0x600:0xE00]); b0=bytearray(open('banco0_util_C700-CEFF_v2.bin','rb').read())
card=bytearray(open('c32F8.img','rb').read())
e1=build_cfg(card,[(0,'TOTALR~1HDV')]); l1=struct.unpack_from('<I',e1,1)[0]
e2=build_cfg(card,[(1,'ZORKON~1PO ')]); l2=struct.unpack_from('<I',e2,25)[0]
card[l1*512:l1*512+6]=bytes([0x01,0xA9,0x44,0x4C,0x00,0x09])     # bloco 0: LDA #$44 / JMP $0900
card[l2*512:l2*512+6]=bytes([0x01,0xA9,0x55,0x4C,0x00,0x09])     # bloco 0: LDA #$55 / JMP $0900
S=Sys1(rom4,b0,card); S.bank=0; S.m[0]=0; S.m[1]=0
S.keys=[ord('t'),ord('1'),ord('z'),ord('2'),ord('-'),ord('-'),2,13]   # Total Replay no 1, Zork no 2, 3->1 s, boot pelo 2
c=S.run(0xC700,stop=0x0900)
show(S.shots[-1],'boot completo: drive 1 = Total Replay, drive 2 = Zork, espera 1 s, boot pelo drive 2')
check(c.a==0x55 and c.x==0xF0,'entrou no bloco 0 do Zork (drive 2) com X=$%02X'%c.x)
S.shots=[]; S.eewrites=0; S.m[0x47F]=0; S.bank=0; S.m[0x800]=0
c=S.run(0xC700,stop=0x0900)
check(c.a==0x55 and S.eewrites==0 and not S.shots,'segundo boot sem tecla: 1 s de contagem e drive 2, nada gravado')
print('RESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
