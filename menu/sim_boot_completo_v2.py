# sim_boot_completo_v2.py - $C700 -> carregador do banco 0 -> CFFAMENU.BIN v2 do cartao -> menu -> boot da imagem
import struct
from sim_cffamenu_v2 import Sys2, build_cfg, show
import sim_cffamenu_v2 as M
rom4=bytearray(open('s14b.bin','rb').read()[0x600:0xE00])
b0=bytearray(open('banco0_util_C700-CEFF_v1.bin','rb').read())
card=bytearray(open('c32L.img','rb').read())
exp=build_cfg(card,[(0,'TESTE   PO ')]); base=struct.unpack_from('<I',exp,1)[0]
card[base*512:base*512+6]=bytes([0x01,0xA9,0x55,0x4C,0x00,0x09])
S=Sys2(rom4,b0,card); S.bank=0; S.m[0]=0; S.m[1]=0
S.keys=[0x15,0x15]+[0x0A]*6+[ord('1'),13]
c=S.run(0xC700,stop=0x0900)
show(S.shots[-1],'tela no momento do RETURN')
M.check(c.a==0x55,'boot pelo bloco 0 de TESTE.PO (A=%02X)'%c.a)
M.check(bytes(S.banks[4][0x780:0x780+24])==bytes(exp[:24]),'tabela do drive 1 = calculada')
S.shots=[]; S.eewrites=0; S.m[0x47F]=0; S.m[0x800]=0; S.bank=0
c=S.run(0xC700,stop=0x0900)
M.check(c.a==0x55 and S.eewrites==0,'segundo boot sem tecla: direto, nada gravado')
print('RESULTADO:', 'TUDO OK' if M.ok else 'HA FALHAS')
