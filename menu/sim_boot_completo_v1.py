# sim_boot_completo_v1.py - caminho real: $C700 (1.4) -> trampolim -> carregador do banco 0 -> CFFAMENU.BIN -> menu -> boot
import struct
from sim_cffamenu_v1 import Sys2, build_cfg, check
import sim_cffamenu_v1 as M
rom4=bytearray(open('s14b.bin','rb').read()[0x600:0xE00])
b0=bytearray(open('banco0_util_C700-CEFF_v1.bin','rb').read())
card=bytearray(open('c32m.img','rb').read())
exp=build_cfg(card,[(0,'TESTE1  PO ')])
base1=struct.unpack_from('<I',exp,1)[0]
card[base1*512:base1*512+6]=bytes([0x01,0xA9,0x77,0x4C,0x00,0x09])
print('== boot 1: nada montado -> menu; teclas 1 A RETURN')
S=Sys2(rom4,b0,card); S.bank=0; S.m[0]=0; S.m[1]=0
S.keys=[ord('1'),ord('A'),13]
c=S.run(0xC700,stop=0x0900)
out=''.join(S.out); print('     |'+out[-400:].replace('\n','\n     |'))
check(c.a==0x77,'boot pelo bloco 0 de TESTE1.PO (A=%02X)'%c.a)
check(bytes(S.banks[4][0x780:0x780+24])==bytes(exp[:24]),'tabela do drive 1 gravada no banco 4')
check(bytes(S.banks[0][0x7C0:0x7C0+11])==b'TESTE1  PO ','nome gravado no banco 0')
print('== boot 2 (desligou e ligou): sem tecla -> nada gravado, boot direto')
S.m[0x47F]=0x00; S.m[0x57F]=0x55; S.m[0x7FF]=0x12; S.eewrites=0; S.out=[]; S.bank=0; S.m[0x800]=0
c=S.run(0xC700,stop=0x0900)
check(c.a==0x77 and S.eewrites==0,'boot direto, %d bytes gravados'%S.eewrites)
print('     |'+''.join(S.out)[-200:].replace('\n','\n     |'))
print('== cartao FAT sem CFFAMENU.BIN: aviso e boot com a montagem antiga')
card2=bytearray(open('c32.img','rb').read()); card2[base1*512:base1*512+6]=bytes([0x01,0xA9,0x66,0x4C,0x00,0x09])
S2=Sys2(bytearray(S.banks[4]),bytearray(S.banks[0]),card2); S2.bank=0; S2.m[0]=0; S2.m[1]=0
c=S2.run(0xC700,stop=0x0900)
check('NAO ENCONTRADO' in ''.join(S2.out) and c.a==0x66,'aviso mostrado e boot da imagem (A=%02X)'%c.a)
print('\nRESULTADO:', 'TUDO OK' if M.ok else 'HA FALHAS')
