import sys
from py65.devices.mpu65c02 import MPU
from py65.memory import ObservableMemory
mem=ObservableMemory()
mpu=MPU(memory=mem)
code=open(sys.argv[1],'rb').read()
for i,b in enumerate(code): mem[0x6000+i]=b
out=[]
# fake CFFA slot 7
ident=bytearray(512)
def putstr(word,s,n):
    s=s.ljust(n*2)
    for k in range(n):
        ident[(word+k)*2+1]=ord(s[2*k]); ident[(word+k)*2]=ord(s[2*k+1])
putstr(27,"SanDisk SDCFB-64",20); putstr(10,"X123",10); putstr(23,"Vdd 1.0",4)
ident[120:124]=(125440).to_bytes(4,'little')
st={'buf':None,'i':0,'hi':0,'lba':[0,0,0],'reads':0}
def rd(addr):
    r=addr&15
    if r==15:
        return 0x58 if st['buf'] is not None and st['i']<512 else 0x50
    if r==8:
        b=st['buf']; v=b[st['i']]; st['hi']=b[st['i']+1]; st['i']+=2
        if st['i']>=512: st['buf']=None
        return v
    if r==0: return st['hi']
    return 0
def wr(addr,v):
    r=addr&15
    if r in (11,12,13): st['lba'][r-11]=v
    if r==15:
        if v==0xEC: st['buf']=ident; st['i']=0
        if v==0x20:
            lba=st['lba'][0]|st['lba'][1]<<8; st['buf']=bytes([lba&255,lba>>8])+bytes(510); st['i']=0; st['reads']+=1
mem.subscribe_to_read(range(0xC0E0,0xC0F0),rd)
mem.subscribe_to_write(range(0xC0E0,0xC0F0),wr)
# ROM traps: RTS stubs
for a in (0xFDED,0xFD8E,0xFDDA): mem[a]=0x60
mpu.pc=0x6000; mem[0x1FF]=0; 
# push fake return address to $0000-1 -> stop when pc==0
mpu.sp=0xFD; mem[0x1FE]=0xFF; mem[0x1FF]=0xFF  # RTS -> $0000
cyc0=None; marks=[]
steps=0
while mpu.pc!=0 and steps<5_000_000:
    if mpu.pc==0xFDED: out.append(chr(mpu.a&0x7f))
    if mpu.pc==0xFD8E: out.append('\n'); marks.append((''.join(out).split('\n')[-2] if out else '',mpu.processorCycles))
    if mpu.pc==0xFDDA: out.append('%02X'%mpu.a)
    mpu.step(); steps+=1
print(''.join(out)); print('reads',st['reads'],'steps',steps)
for m,c in marks: print(c,m)
