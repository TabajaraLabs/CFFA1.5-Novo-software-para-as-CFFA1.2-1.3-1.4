# Simulacao do gravador_v1 com uma CFFA (EEPROM com bancos, trava, data polling) e uma Super Serial falsas
import sys
from py65.devices.mpu65c02 import MPU
from py65.memory import ObservableMemory
img=bytearray(open(sys.argv[1],'rb').read())          # imagem de 32 KB da EEPROM
novo=open(sys.argv[2],'rb').read(); assert len(novo)==2048   # dados a gravar ($C700-$CEFF)
banco_alvo=int(sys.argv[3])
mem=ObservableMemory(); mpu=MPU(memory=mem)
code=open('gravador_v1.bin','rb').read()
for i,b in enumerate(code): mem[0x6000+i]=b
mem[0x6003]=banco_alvo
st={'a14':0,'we':0,'c8':0,'busy':0,'last':0,'rx':[], 'acks':0,'blk':0,'writes':0,'bad_writes':0}
out=[]
def eaddr(a): return st['a14']*0x4000 + (a-0xC000)     # A13=A12=0 (jumpers)
def io_r(a):
    r=a&15
    if a>=0xC0F0:
        if r==3: st['we']=0
        if r==4: st['a14']=0; st['we']=0
        if r==5: st['a14']=1; st['we']=0
        return 0
    if a==0xC099: return 0x10|(0x08 if st['rx'] else 0)
    if a==0xC098: return st['rx'].pop(0) if st['rx'] else 0
    return 0
def io_w(a,v):
    if a>=0xC0F0:
        r=a&15
        if r==3: st['we']=1
        if r==4: st['a14']=0; st['we']=0
        if r==5: st['a14']=1; st['we']=0
    if a==0xC098 and v==6:
        st['acks']+=1
        b=st['blk']; st['rx'].extend(novo[b*256:(b+1)*256]); st['blk']+=1
def rom_r(a):
    if a>=0xCF00: st['c8']=0; return 0xFF
    if a>=0xC800 and not st['c8']: return 0xEE
    if a<0xC800: st['c8']=1
    if st['busy']>0:
        st['busy']-=1; return (st['last']^0x80)&0xFF   # data polling: D7 invertido
    return img[eaddr(a)]
def rom_w(a,v):
    if a>=0xCF00: st['c8']=0; return
    if a<0xC800: st['c8']=1
    if not st['we'] or (a>=0xC800 and not st['c8']): st['bad_writes']+=1; return
    img[eaddr(a)]=v; st['busy']=30; st['last']=v; st['writes']+=1
mem.subscribe_to_read(range(0xC080,0xC100),io_r); mem.subscribe_to_write(range(0xC080,0xC100),io_w)
mem.subscribe_to_read(range(0xC700,0xD000),rom_r); mem.subscribe_to_write(range(0xC700,0xD000),rom_w)
mem[0xC000]=0
for a in (0xFDED,0xFD8E,0xFDDA): mem[a]=0x60
mpu.pc=0x6000; mpu.sp=0xFD; mem[0x1FE]=0xFF; mem[0x1FF]=0xFF
n=0
while mpu.pc!=0 and n<20_000_000:
    if mpu.pc==0xFDED: out.append(chr(mpu.a&0x7f))
    if mpu.pc==0xFD8E: out.append('\n')
    if mpu.pc==0xFDDA: out.append('%02X'%mpu.a)
    mpu.step(); n+=1
print(''.join(out)); print('acks',st['acks'],'gravacoes',st['writes'],'escritas_recusadas',st['bad_writes'],'banco_final_A14',st['a14'],'trava',st['we'])
open('img_depois.bin','wb').write(img)
