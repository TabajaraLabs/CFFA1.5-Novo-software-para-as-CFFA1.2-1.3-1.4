# sim_boot_completo_v10.py - $C700 (1.5) -> carregador do banco 0 v2 -> CFFAMENU v10 do cartao -> boot
import struct
import sys; sys.argv=["x"]
from sim_cffamenu_v2 import Sys2, show, screen, build_cfg, inv
import re
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)
KEYW=int(re.search(r'^00(....)  1  AD 00 C0     @w:     lda KBD                 ; v10: teclado direto',open('cffamenu_v10.lst').read(),re.M).group(1),16)
KEYR=int(re.search(r'^00(....)  1  29 7F        @r:',open('cffamenu_v10.lst').read(),re.M).group(1),16)
class Sys1(Sys2):
    # v10: o menu le $C000 direto. Ao chegar no laco do key (KEYW) tira a foto e poe a proxima tecla em
    # $C000 (ou na serial do slot 1, se S.viaser); a escrita em $C010 apaga; rearma ao passar por KEYR.
    def __init__(s,*a):
        super().__init__(*a); s.viaser=False; s.rx=None
        s.m.subscribe_to_write([0xC010],s.strobe)
        s.m.subscribe_to_read([0xC098,0xC099],s.ssc)
    def strobe(s,a,v): s.m[0xC000]=0
    def ssc(s,a):
        if a==0xC099: return 0x10|(0x08 if s.rx is not None else 0)
        k=s.rx; s.rx=None; return k or 0
    def io_rd(s,a):
        if (a&15) in (15,6) and s.st['r'][14]&0x10: return 0      # sem escravo
        return super().io_rd(a)
    def run(s,pc,maxsteps=600_000_000,stop=0,x=0x70,p=0x30):
        c=s.c; c.p=p; c.pc=pc; c.x=x; c.sp=0xF0; s.m[0x1F1]=(stop-1)&255; s.m[0x1F2]=(stop-1)>>8
        n=0; armed=True
        while c.pc!=stop and n<maxsteps:
            if c.pc==KEYW and armed:
                s.shots.append((screen(s.m),inv(s.m)))
                k=(s.keys.pop(0) if s.keys else 0x1B)|0x80
                if s.viaser: s.rx=k
                else: s.m[0xC000]=k
                armed=False
            elif c.pc==KEYR: armed=True
            c.step(); n+=1
        assert c.pc==stop,'nao voltou PC=%04X'%c.pc
        return c
rom4=bytearray(open('s15.bin','rb').read()[0x600:0xE00]); b0=bytearray(open('banco0_util_C700-CEFF_v2.bin','rb').read())
card=bytearray(open('c32F10.img','rb').read())
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
