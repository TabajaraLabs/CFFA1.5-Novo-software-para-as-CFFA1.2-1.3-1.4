# sim_serimg_v1.py - simula o serimg (Super Serial emulada) com o driver 1.5 e uma imagem montada num cartao FAT32
import struct, os
from sim_fw14_v2 import Sys, build_cfg
ok=True
def check(c,m):
    global ok; print(('  OK   ' if c else '  FALHA ')+m); ok&=bool(c)
class SysS(Sys):
    def __init__(s,*a):
        super().__init__(*a); s.rx=[]; s.tx=bytearray(); s.file=b''; s.blk=0; s.ctl=[]; s.go=False
        s.m.subscribe_to_read([0xC098,0xC099,0xC09B,0xC000],s.ssc_rd); s.m.subscribe_to_write([0xC098,0xC09B,0xC010],s.ssc_wr)
    def ssc_rd(s,a):
        if a==0xC099: return 0x10|(0x08 if s.rx else 0)
        if a==0xC098: return s.rx.pop(0) if s.rx else 0
        if a==0xC09B: return 0x1E
        return 0
    def ssc_wr(s,a,v):
        if a==0xC09B: s.ctl.append(v); return
        if a==0xC098:
            s.tx.append(v)
            if s.mode=='send' and not s.go and bytes(s.tx).endswith(b'\x1b\x01BK'):
                s.go=True; s.rx.append(0x06)        # a ponte (#recvbin) manda o "pode mandar" ja a 115200
            if v==6 and s.mode=='recv' and s.blk*512<len(s.file):   # ACK -> ponte manda o proximo bloco
                s.rx+=list(s.file[s.blk*512:(s.blk+1)*512]); s.blk+=1
rom=bytearray(open('s15.bin','rb').read()[0x600:0xE00])
card=bytearray(open('c32.img','rb').read())
cfg=build_cfg(card,[(1,'TESTE1  PO ')]); base=struct.unpack_from('<I',cfg,24+1)[0]
b4=bytearray(rom); b4[0x780:0x780+0x61]=cfg[:0x61]
img=bytes(os.urandom(280*512))
prog=open('serimg_v1.bin','rb').read()
# ---- PC -> Apple: grava 280 blocos no drive 2 (TESTE1.PO)
S=SysS(b4,bytearray(b4),card); S.bank=4; S.mode='recv'; S.file=img
for i,b in enumerate(prog): S.m[0x6000+i]=b
S.m[0x6003]=0; S.m[0x6004]=0xF0; S.m[0x6005]=280&255; S.m[0x6006]=280>>8; S.m[0x6007]=0; S.m[0x6008]=0; S.m[0x6009]=1; S.m[0x600A]=1
S.run(0x6000,maxsteps=900_000_000)
out=''.join(S.out); print('   Apple:',out.strip())
check(card[base*512:(base+280)*512]==img,'os 280 blocos foram gravados dentro de TESTE1.PO, no lugar certo')
sm=S.m[0x600B]|S.m[0x600C]<<8; vs=S.m[0x600D]|S.m[0x600E]<<8
check(sm==sum(img)&0xFFFF and vs==sm and out.strip().endswith('OK'),'soma %04X e releitura %04X conferem com o arquivo (%04X)'%(sm,vs,sum(img)&0xFFFF))
t=bytes(S.tx)
check(t.startswith(b'\x1b\x01B4') and b'\x1b\x01BK' in t and b'\x1b\x01B1' in t,'pediu 115200, confirmou e voltou para 19200 (ESC 01 B 4 / K / 1)')
check(S.ctl==[0x10,0x1E],'6551: $10 (115200) durante e $%02X (original) no fim'%S.ctl[-1])
print('   ciclos: %.1f s simulados a 1,02 MHz (sem contar a serial)'%(S.c.processorCycles/1.023e6))
# ---- Apple -> PC: le os mesmos 280 blocos (backup)
S2=SysS(b4,bytearray(b4),card); S2.bank=4; S2.mode='send'
for i,b in enumerate(prog): S2.m[0x6000+i]=b
S2.m[0x6003]=1; S2.m[0x6004]=0xF0; S2.m[0x6005]=0; S2.m[0x6006]=0; S2.m[0x6009]=1   # 0 = tamanho pelo STATUS
S2.run(0x6000,maxsteps=900_000_000)
t=bytes(S2.tx); i=t.index(b'\x1b\x01BK')+4; nb=t[i]|t[i+1]<<8; dados=t[i+2:i+2+nb*512]
check(nb==1600,'backup: cabecalho com o tamanho do drive pelo STATUS (%d blocos)'%nb)
check(dados[:280*512]==img and dados==bytes(card[base*512:(base+1600)*512]),'backup: os 1600 blocos de TESTE1.PO chegaram iguais ao PC')
print('   Apple:',''.join(S2.out).strip())
print('\nRESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
