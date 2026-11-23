# sim_fatcat_v1.py - roda fatcat_v1.bin num 65C02 simulado com a CFFA (slot 7) lendo uma imagem de cartao
import sys
from py65.devices.mpu65c02 import MPU
from py65.memory import ObservableMemory
mem=ObservableMemory(); mpu=MPU(memory=mem)
code=open(sys.argv[1],'rb').read(); card=open(sys.argv[2],'rb').read()
for i,b in enumerate(code): mem[0x6000+i]=b
out=[]; st={'buf':None,'i':0,'hi':0,'r':[0]*16,'reads':0}
def rd(a):
    r=a&15
    if r==15: return 0x58 if st['buf'] is not None else 0x50
    if r==8:
        b=st['buf']; v=b[st['i']]; st['hi']=b[st['i']+1]; st['i']+=2
        if st['i']>=512: st['buf']=None
        return v
    if r==0: return st['hi']
    return 0
def wr(a,v):
    r=a&15; st['r'][r]=v
    if r==15 and v==0x20:
        R=st['r']; assert R[14]&0xE0==0xE0, 'modo LBA'; assert R[10]==1
        lba=R[11]|R[12]<<8|R[13]<<16|(R[14]&15)<<24
        st['buf']=card[lba*512:lba*512+512].ljust(512,b'\0'); st['i']=0; st['reads']+=1
mem.subscribe_to_read(range(0xC0F0,0xC100),rd); mem.subscribe_to_write(range(0xC0F0,0xC100),wr)
for a in (0xFDED,0xFD8E,0xFDDA): mem[a]=0x60
mem[0xC000]=0
mpu.pc=0x6000; mpu.sp=0xFD; mem[0x1FE]=0xFF; mem[0x1FF]=0xFF
n=0
while mpu.pc!=0 and n<200_000_000:
    pc=mpu.pc
    if pc==0xFDED: out.append(chr(mpu.a&0x7f))
    elif pc==0xFD8E: out.append('\n')
    elif pc==0xFDDA: out.append('%02X'%mpu.a)
    mpu.step(); n+=1
print(''.join(out)); print('[sim] setores lidos %d, ciclos %d (~%.1f s a 1,02 MHz), pilha final %02X'%(st['reads'],mpu.processorCycles,mpu.processorCycles/1.023e6,mpu.sp))
