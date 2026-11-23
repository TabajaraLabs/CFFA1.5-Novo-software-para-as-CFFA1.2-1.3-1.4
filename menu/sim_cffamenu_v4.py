# sim_cffamenu_v2.py - testa o menu v2 (nomes longos, molduras, setas, paginas) e mostra a tela simulada
import sys, struct
from sim_fw14_v2 import Sys, build_cfg
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)
BASCALC=bytes.fromhex('484a2903090485296829189002697f85280a0a05288528 60'.replace(' ',''))
def screen(m):
    L=[]
    for r in range(24):
        b=0x400+(r%8)*0x80+(r//8)*0x28; s=''
        for c in range(40):
            v=m[b+c]
            if v>=0xA0: s+=chr(v-0x80)
            elif v<0x40: s+=chr(v+0x40 if v<0x20 else v)   # inverso: mostra igual (marcado abaixo)
            else: s+='#'
        L.append(s)
    return L
def inv(m):
    L=[]
    for r in range(24):
        b=0x400+(r%8)*0x80+(r//8)*0x28
        L.append(''.join('^' if m[b+c]<0x40 else ' ' for c in range(40)))
    return L
class Sys2(Sys):
    def __init__(s,*a):
        super().__init__(*a); s.keys=[]; s.we=False; s.eewrites=0; s.shots=[]
        s.m.subscribe_to_write(range(0xC800,0xCF00),s.rom_wr)
        for a in (0xFC58,0xFD0C): s.m[a]=0x60
        for i,b in enumerate(BASCALC): s.m[0xFBC1+i]=b
    def io_rd(s,a):
        if (a&15)==3: s.we=False; return 0
        if (a&15) in (4,5): s.we=False
        return super().io_rd(a)
    def io_wr(s,a,v):
        if (a&15)==3: s.we=True; return
        if (a&15) in (4,5): s.we=False
        return super().io_wr(a,v)
    def rom_wr(s,a,v):
        if s.we: s.banks[s.bank][a-0xC700]=v; s.eewrites+=1
    def run(s,pc,maxsteps=600_000_000,stop=0,x=0x70):
        c=s.c; c.pc=pc; c.x=x; c.sp=0xF0; s.m[0x1F1]=(stop-1)&255; s.m[0x1F2]=(stop-1)>>8
        n=0
        while c.pc!=stop and n<maxsteps:
            if c.pc==0xFD0C:
                s.shots.append((screen(s.m),inv(s.m)))
                k=s.keys.pop(0) if s.keys else 0x1B
                c.a=k|0x80
            elif c.pc==0xFDED: s.out.append(chr(c.a&0x7f))
            c.step(); n+=1
        assert c.pc==stop,'nao voltou PC=%04X'%c.pc
        return c
def show(shot,title):
    print('   +'+'-'*40+'+  '+title)
    for l,i in zip(*shot): print('   |'+l+'|  '+i.rstrip())
    print('   +'+'-'*40+'+')
if __name__=='__main__':
    rom4=bytearray(open('s14b.bin','rb').read()[0x600:0xE00])
    b0=bytearray(open('banco0_util_C700-CEFF_v1.bin','rb').read())
    card=bytearray(open('c32L.img','rb').read())
    menu=open('cffamenu_v4.bin','rb').read()
    S=Sys2(rom4,b0,card); S.bank=4
    for i,b in enumerate(menu): S.m[0x4000+i]=b
    UP,DN,LF,RT=0x0B,0x0A,0x08,0x15
    S.keys=[DN,DN,DN,ord('1'), RT, ord('2'), RT, RT, ord('3'), LF, LF, LF, ord('3'), ord('4'), 13]
    c=S.run(0x4007)
    show(S.shots[0],'tela inicial')
    show(S.shots[6],'drive 1 montado; seta direita: pagina 2; drive 2 montado')
    show(S.shots[9],'pagina 3 (nomes com acento) e drive 3 montado')
    show(S.shots[-1],'final: drive 3 esvaziado pela linha (NENHUMA)')
    cfg=bytes(S.banks[4][0x780:0x780+0x61]); nm=bytes(S.banks[0][0x7C0:0x7C0+45])
    print('   nomes gravados:',nm)
    check(cfg[0]==0x80 and cfg[24]==0x80 and cfg[48]==0 and cfg[72]==0 and cfg[0x60]==ord('C'),'drives 1 e 2 montados, 3 e 4 vazios (estado %02X %02X %02X %02X)'%(cfg[0],cfg[24],cfg[48],cfg[72]))
    check(nm[:11]==b'APPLEW~1PO ' and nm[11:22]==b'ZORKI~1 PO ' and nm[22:44]==b' '*22,'nomes: %r'%nm[:22])
    exp=build_cfg(card,[(0,'APPLEW~1PO '),(1,'ZORKI~1 PO ')])
    check(cfg[:48]==bytes(exp[:48]),'tabela dos drives 1 e 2 = calculada em Python')
    print('\nRESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
