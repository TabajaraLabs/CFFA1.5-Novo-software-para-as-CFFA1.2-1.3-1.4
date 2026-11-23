# sim_cffamenu_v9.py - menu v9: espera configuravel (+/-), boot pelo drive 2 (CTRL-B), maca aberta, CLD
import struct
from sim_cffamenu_v2 import Sys2, show, screen, build_cfg
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)
class Sys1(Sys2):
    def io_rd(s,a):
        if (a&15) in (15,6) and s.st['r'][14]&0x10: return 0      # sem escravo
        return super().io_rd(a)
    def run(s,pc,maxsteps=600_000_000,stop=0,x=0x70,p=0x30):
        s.c.p=p; return super().run(pc,maxsteps,stop,x)
rom4=bytearray(open('s15.bin','rb').read()[0x600:0xE00]); b0=bytearray(open('banco0_util_C700-CEFF_v2.bin','rb').read())
card=bytearray(open('c32F.img','rb').read()); menu=open('cffamenu_v9.bin','rb').read()
S=Sys1(rom4,b0,card); S.bank=4
for i,b in enumerate(menu): S.m[0x4000+i]=b
UP,DN,LF,RT,CB=0x0B,0x0A,0x08,0x15,0x02
def tela(): return screen(S.m)
print('== 1. regressao (sequencia do v7), comecando com P=$FF (decimal ligado, como depois de um G)')
S.keys=[DN,DN,DN,ord('z'), UP,UP,UP,UP,UP, 13, DN,DN,DN, ord('1'), ord('!'), 13]
S.run(0x4007,p=0xFF)
show(S.shots[-1],'Karateka montado e protegido; ajustes do boot na linha 7')
cfg=bytes(S.banks[4][0x780:0x780+24])
check(cfg[0]==0xC0,'drive 1 montado e protegido ($%02X)'%cfg[0])
check(bytes(S.banks[0][0x7C0:0x7C0+11])==b'KARATEKAPO ','nome KARATEKA.PO guardado')
check(S.banks[0][0x7F1]==3 and S.banks[0][0x7F2]==0,'EEPROM gravada pelo v7 ($FF): padrao 3 s e drive 1 ($CEF1=%d $CEF2=%d)'%(S.banks[0][0x7F1],S.banks[0][0x7F2]))
check('BOOT DRIVE 1 [^B]  ESPERA 3 S [+-]' in S.shots[-1][0][7],'linha 7: %r'%S.shots[-1][0][7])
l21,l22=S.shots[-1][0][21],S.shots[-1][0][22]
check('1-4: MONTA IMAGEM ! SHIFT 1-4: PROTEGE' in l21 and 'RETURN: BOOT ! ESC: SAI ! ?: AJUDA' in l22,'ajuda em 2 linhas (II Plus: !): %r / %r'%(l21.strip(),l22.strip()))
print('== 2. monta Zork no drive 2, + + (3->5->8 s), CTRL-B (boot pelo drive 2), RETURN')
S.shots=[]; S.keys=[ord('z'),ord('2'),ord('+'),ord('='),CB,13]
S.run(0x4007)
show(S.shots[-1],'drive 2 = Zork, boot pelo drive 2, espera 8 s')
check(S.banks[0][0x7F1]==8 and S.banks[0][0x7F2]==1,'gravado: espera %d s, boot pelo drive %d'%(S.banks[0][0x7F1],S.banks[0][0x7F2]+1))
c2=bytes(S.banks[4][0x780+24:0x780+48]); lba=struct.unpack_from('<I',c2,1)[0]&0x0FFFFFFF
check(c2[0]&0x80,'drive 2 montado (LBA %08X)'%lba)
card[lba*512:lba*512+8]=bytes([0x01,0x38,0xB0,0x03,0x4C,0x32,0xA1,0x86])   # bloco 0 de ProDOS
print('== 3. boot ($4004) sem tecla: contagem de 8 s e entrada no bloco 0 do drive 2 com X=$F0')
S.shots=[]; S.eewrites=0; S.m[0x47F]=0; S.m[0x800:0x808]=bytes(8)
c=S.run(0x4004,stop=0x0801,p=0xFF)
t=tela()
show((t,['']*24),'tela no instante do boot')
check(c.x==0xF0,'entrou em $0801 com X=$%02X (unidade: slot 7, drive 2)'%c.x)
check(bytes(S.m[0x800:0x808])==bytes(card[lba*512:lba*512+8]),'$0800 = bloco 0 do Zork (drive 2)')
check('BOOT DO DRIVE 2 EM 1 S. TECLA = MENU' in t[23],'ultima mensagem da contagem: %r'%t[23].strip())
check(S.eewrites==0 and not S.shots,'nada regravado e o menu nao abriu')
print('== 4. tecla apertada durante o boot: menu; ESC: sai sem gravar e o boot continua pelo drive 2')
S.shots=[]; S.m[0xC000]=0xC1; S.m[0x47F]=0
c=S.run(0x4004,stop=0x0801)
S.m[0xC000]=0
check(len(S.shots)==1 and c.x==0xF0,'menu abriu (%d tela) e o ESC seguiu para o drive 2'%len(S.shots))
print('== 5. maca aberta segurada (IIe): menu; - - - - - - (8 s -> 0), CTRL-B (drive 1), RETURN')
S.shots=[]; S.m[0xFBB3]=6; S.m[0xC061]=0x80; S.m[0x47F]=0
S.keys=[ord('-')]*4+[ord('_')]*3+[CB,13]
S.run(0x4004,stop=0)
S.m[0xC061]=0
check(len(S.shots)>0,'maca aberta: menu abriu')
check(S.banks[0][0x7F1]==0 and S.banks[0][0x7F2]==0,'gravado: espera %d s, boot pelo drive %d'%(S.banks[0][0x7F1],S.banks[0][0x7F2]+1))
print('== 6. espera 0: boot direto, sem desenhar nada, volta para o boot normal (drive 1)')
for a in range(0x400,0x800): S.m[a]=0
S.shots=[]; S.eewrites=0; S.m[0x47F]=0
S.run(0x4004,stop=0)
check(all(S.m[a]==0 for a in range(0x400,0x800)) and S.eewrites==0,'tela intocada, nada gravado')
print('== 7. espera 0 + tecla ja apertada: abre o menu')
S.shots=[]; S.m[0xC000]=0xA0; S.m[0x47F]=0
S.run(0x4004,stop=0); S.m[0xC000]=0
check(len(S.shots)==1,'menu abriu')
print('== 8. drive 2 escolhido mas vazio: boot normal pelo drive 1')
S.shots=[]; S.keys=[ord('+'),ord('+'),CB,DN-DN+0x0B,UP,UP,UP,UP,UP,UP,UP,UP,UP,UP,ord('2'),13]
S.run(0x4007)
check(S.banks[4][0x780+24]&0x80==0 and S.banks[0][0x7F2]==1,'drive 2 esvaziado, boot pelo drive 2 escolhido')
S.shots=[]; S.m[0x47F]=0
S.run(0x4004,stop=0)
t=tela(); check('BOOT DO DRIVE 1 EM 1 S' in t[23],'contagem mostra drive 1: %r'%t[23].strip())
print('== 9. tecla ?: tela de ajuda (IIe: barra vertical), qualquer tecla volta')
S.shots=[]; S.m[0xFBB3]=6; S.keys=[ord('H'),0x15,ord(' '),ord(' '),0x08,0x1B,ord('?'),13,0x1B]
S.run(0x4007)
for k,t in ((1,'ajuda 1 (IIe)'),(2,'ajuda 2'),(3,'ajuda 3'),(5,'ajuda 2 de novo (seta esquerda)'),(6,'ESC: de volta ao menu')): show(S.shots[k],t)
check('1 DE 3' in S.shots[1][0][0] and 'CTRL-B' in ''.join(S.shots[1][0]),'H abre a pagina 1')
check('2 DE 3' in S.shots[2][0][0] and '3 DE 3' in S.shots[3][0][0] and '3 DE 3' in S.shots[4][0][0],'seta direita/espaco: 2 e 3; espaco na ultima fica nela')
check('TABAJARA' in ''.join(S.shots[3][0]),'pagina Sobre com o (C)')
check('2 DE 3' in S.shots[5][0][0],'seta esquerda volta para a 2')
check('V9 - CARTAO FAT' in S.shots[6][0][0] and '?: AJUDA' in S.shots[6][0][22] and '|' in S.shots[6][0][22],'menu redesenhado; linha 22 com | no IIe: %r'%S.shots[6][0][22].strip())
check('AJUDA' in S.shots[7][0][0] and 'V9 - CARTAO' in S.shots[8][0][0],'? tambem abre; RETURN volta')
print('== 10. II Plus: ajuda em maiusculas')
S.m[0xFBB3]=0xEA; S.shots=[]; S.keys=[ord('H'),0x1B,0x1B]
S.run(0x4007)
show(S.shots[1],'ajuda 1 no II Plus')
check('MOVE A BARRA' in S.shots[1][0][4],'minusculas convertidas: %r'%S.shots[1][0][4].strip())
print('\nRESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
