# sim_boot_completo_v6.py - $C700 (1.5) -> carregador do banco 0 v2 -> CFFAMENU v6 do cartao -> menu -> boot
import struct
from sim_cffamenu_v6 import Sys1, show, build_cfg
import sim_cffamenu_v6 as M
rom4=bytearray(open('s15.bin','rb').read()[0x600:0xE00]); b0=bytearray(open('banco0_util_C700-CEFF_v2.bin','rb').read())
card=bytearray(open('c32F.img','rb').read())
exp=build_cfg(card,[(0,'TOTALR~1HDV')]); base=struct.unpack_from('<I',exp,1)[0]
card[base*512:base*512+6]=bytes([0x01,0xA9,0x44,0x4C,0x00,0x09])
S=Sys1(rom4,b0,card); S.bank=0; S.m[0]=0; S.m[1]=0
S.keys=[ord('t'),ord('1'),13]
c=S.run(0xC700,stop=0x0900)
show(S.shots[-1],'boot completo: T pula para Total Replay, 1 monta, RETURN')
M.check(c.a==0x44,'boot pelo bloco 0 de Total Replay.hdv (A=%02X)'%c.a)
S.shots=[]; S.eewrites=0; S.m[0x47F]=0; S.bank=0; S.m[0x800]=0
c=S.run(0xC700,stop=0x0900)
M.check(c.a==0x44 and S.eewrites==0,'segundo boot sem tecla: direto, nada gravado')
print('RESULTADO:', 'TUDO OK' if M.ok else 'HA FALHAS')
