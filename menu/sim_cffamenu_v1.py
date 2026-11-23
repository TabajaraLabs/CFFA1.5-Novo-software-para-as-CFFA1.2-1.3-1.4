# sim_cffamenu_v1.py - ponta a ponta: CFFAMENU.BIN monta imagens (teclas simuladas), grava a EEPROM, boot pelo 1.4
import sys, struct
from sim_fw14_v2 import Sys, build_cfg
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)

class Sys2(Sys):
    def __init__(s,*a):
        super().__init__(*a); s.keys=[]; s.we=False; s.eewrites=0
        s.m.subscribe_to_write(range(0xC800,0xCF00),s.rom_wr)
        for a in (0xFC58,0xFD0C): s.m[a]=0x60
    def io_rd(s,a):
        if (a&15)==3: s.we=False; return 0
        if (a&15) in (4,5): s.we=False
        return super().io_rd(a)
    def io_wr(s,a,v):
        if (a&15)==3: s.we=True; return
        if (a&15) in (4,5): s.we=False
        return super().io_wr(a,v)
    def rom_wr(s,a,v):
        if s.we and a<0xCF00: s.banks[s.bank][a-0xC700]=v; s.eewrites+=1
    def run(s,pc,maxsteps=400_000_000,stop=0,x=0x70):
        c=s.c; c.pc=pc; c.x=x; c.sp=0xF0; s.m[0x1F1]=(stop-1)&255; s.m[0x1F2]=(stop-1)>>8
        n=0
        while c.pc!=stop and n<maxsteps:
            pc=c.pc
            if pc==0xFDED: s.out.append(chr(c.a&0x7f))
            elif pc==0xFD8E: s.out.append('\n')
            elif pc==0xFDDA: s.out.append('%02X'%c.a)
            elif pc==0xFD0C:
                k=s.keys.pop(0) if s.keys else 0x1B
                s.out.append('<%s>'%chr(k)); c.a=k|0x80
            c.step(); n+=1
        assert c.pc==stop,'nao voltou PC=%04X'%c.pc
        return c

card=bytearray(open('c32.img','rb').read())
exp=build_cfg(card,[(0,'TESTE1  PO '),(1,'HD32    PO ')])
base1=struct.unpack_from('<I',exp,1)[0]
card[base1*512:base1*512+6]=bytes([0x01,0xA9,0x99,0x4C,0x00,0x09])   # bloco 0 da imagem: lda #$99 / jmp $0900
rom4=bytearray(open('s14b.bin','rb').read()[0x600:0xE00])
orig0=bytearray(rom4)          # banco 0 "original" (sem CFU): usa o proprio 1.4 como enchimento
orig0[0x100:0x103]=b'XXX'
menu=open('CFFAMENU.BIN','rb').read()

print('== 1) menu pela entrada de teste: 1 A, 2 B, RETURN')
S=Sys2(rom4,orig0,card); S.bank=4
for i,b in enumerate(menu): S.m[0x4000+i]=b
S.keys=[ord('1'),ord('A'),ord('2'),ord('B'),13]
c=S.run(0x4007)
out=''.join(S.out); print('\n'.join('     |'+l for l in out.split('\n')[-30:]))
got=bytes(S.banks[4][0xE80-0x700:0xE80-0x700+0x61])
check(got[:48]==bytes(exp[:48]) and got[48]==0 and got[72]==0 and got[0x60]==ord('C'),'tabela gravada no banco 4 = calculada em Python (drives 3-4 vazios = 0)')
nm=bytes(S.banks[0][0xEC0-0x700:0xEC0-0x700+45])
check(nm==b'TESTE1  PO HD32    PO '+b' '*22+b'N','nomes gravados no banco 0: %r'%nm[:24])
check(S.m[0x47F]==0,'DriveResetDone zerado (o driver refaz o FatInit)')
w1=S.eewrites; print('     bytes gravados na EEPROM:',w1)

print('== 2) boot pelo $C700 com o 1.4 (banco 0 sem CFU)')
S.m[0]=0; S.m[1]=0; S.out=[]
c=S.run(0xC700,stop=0x0900)
check(c.a==0x99 and S.m[0x800]==1,'bloco 0 de TESTE1.PO executado (A=%02X)'%c.a)
a,cy,x,y=S.p8(0,0xF0,0); check(cy==0 and x+256*y==65535,'drive 2 = HD32.PO (%d blocos)'%(x+256*y))

print('== 3) entrada de boot ($4004) sem tecla: nada muda, nada e gravado')
S.eewrites=0; S.out=[]; c=S.run(0x4004)
check(S.eewrites==0,'0 bytes gravados'); print('     |'+''.join(S.out).replace('\n','\n     |'))

print('== 4) TESTE1.PO apagado no PC -> drive 1 desmontado, nome guardado')
sct=struct.unpack_from('<I',exp,7)[0]; k=exp[11]
S.card[sct*512+k*32]=0xE5
S.eewrites=0; S.out=[]; c=S.run(0x4004)
check(S.banks[4][0xE80-0x700]==0 and S.banks[4][0xE80-0x700+24]==0x80,'drive 1 desmontado, drive 2 continua')
check(bytes(S.banks[0][0xEC0-0x700:0xEC0-0x700+11])==b'TESTE1  PO ','nome de TESTE1 continua guardado')
print('     bytes gravados:',S.eewrites)
S.card[sct*512+k*32]=ord('T')
S.eewrites=0; S.out=[]; c=S.run(0x4004)
check(S.banks[4][0xE80-0x700]==0x80,'arquivo de volta -> drive 1 montado de novo (gravados %d)'%S.eewrites)

print('== 5) FAT16 sem MBR: menu monta FRAG.IMG? (deve recusar) e TESTE1.PO')
card16=bytearray(open('c16.img','rb').read())
S=Sys2(rom4,orig0,card16); S.bank=4
for i,b in enumerate(menu): S.m[0x4000+i]=b
S.keys=[ord('1'),ord('C'),13,ord('1'),ord('A'),13]
c=S.run(0x4007)
out=''.join(S.out)
check('FRAGMENTADA' in out,'FRAG.IMG recusada (fragmentada)')
exp16=build_cfg(card16,[(0,'TESTE1  PO ')])
got=bytes(S.banks[4][0xE80-0x700:0xE80-0x700+24])
check(got==bytes(exp16[:24]),'TESTE1.PO no drive 1 (FAT16) = calculado')
print('\nRESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
