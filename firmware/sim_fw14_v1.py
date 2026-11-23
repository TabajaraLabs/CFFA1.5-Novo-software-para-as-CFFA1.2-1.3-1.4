# sim_fw14_v1.py - simula o firmware 1.4 da CFFA (bancos 0 e 4 trocados pelo CPLD v1.6) num 65C02
import sys, struct
from py65.devices.mpu65c02 import MPU
from py65.memory import ObservableMemory

class Sys:
    def __init__(s, bank4, bank0, card):
        s.m=ObservableMemory(); s.c=MPU(memory=s.m)
        b0=bytearray(bank0); b0[0:0x100]=bank4[0:0x100]   # pagina $C7 igual nos dois bancos (como sera gravado)
        s.banks={0:b0,4:bytearray(bank4)}; s.bank=0; s.card=card
        s.st={'buf':None,'i':0,'hi':0,'r':[0]*16,'wbuf':None,'reads':[], 'writes':[]}
        s.m.subscribe_to_read(range(0xC0F0,0xC100),s.io_rd); s.m.subscribe_to_write(range(0xC0F0,0xC100),s.io_wr)
        s.m.subscribe_to_read(range(0xC700,0xCF00),lambda a: s.banks[s.bank][a-0xC700])
        for a in (0xFDED,0xFD8E,0xFDDA,0xFCA8,0xFE89,0xFE93,0xFB2F,0xFC58): s.m[a]=0x60
        s.out=[]
    def io_rd(s,a):
        r=a&15; st=s.st
        if r==4: s.bank=0; return 0
        if r==5: s.bank=4; return 0
        if r==15 or r==6:
            busy=0
            return 0x58 if (st['buf'] is not None or st['wbuf'] is not None) else 0x50
        if r==8 and st['buf'] is not None:
            b=st['buf']; v=b[st['i']]; st['hi']=b[st['i']+1]; st['i']+=2
            if st['i']>=512: st['buf']=None
            return v
        if r==0: return st['hi']
        return 0
    def lba(s):
        R=s.st['r']; assert R[14]&0xE0==0xE0; assert R[10]==1, 'contagem %d'%R[10]
        return R[11]|R[12]<<8|R[13]<<16|(R[14]&15)<<24
    def io_wr(s,a,v):
        r=a&15; st=s.st
        if r==4: s.bank=0; return
        if r==5: s.bank=4; return
        if r==0: st['hi']=v; return
        if r==8 and st['wbuf'] is not None:
            st['wbuf']+=bytes([v,st['hi']])
            if len(st['wbuf'])>=512:
                l=st['wlba']; s.card[l*512:l*512+512]=st['wbuf']; st['writes'].append(l); st['wbuf']=None
            return
        st['r'][r]=v
        if r==15:
            if v==0x20:
                l=s.lba(); st['buf']=bytes(s.card[l*512:l*512+512]).ljust(512,b'\0'); st['i']=0; st['reads'].append(l)
            elif v==0x30:
                st['wlba']=s.lba(); st['wbuf']=b''
            elif v==0xEC:
                idb=bytearray(512); idb[114:118]=idb[120:124]=(len(s.card)//512).to_bytes(4,'little'); st['buf']=bytes(idb); st['i']=0
    def run(s,pc,maxsteps=20_000_000,stop=0):
        c=s.c; c.pc=pc; c.sp=0xF0; s.m[0x1F1]=(stop-1)&255; s.m[0x1F2]=(stop-1)>>8
        n=0
        while c.pc!=stop and n<maxsteps:
            if c.pc==0xFDED: s.out.append(chr(c.a&0x7f))
            if c.pc==0xFD8E: s.out.append('\n')
            c.step(); n+=1
        assert c.pc==stop, 'nao voltou: PC=%04X'%c.pc
        return c
    def p8(s,cmd,unit,block,buf=0x4000):
        m=s.m; m[0x42]=cmd; m[0x43]=unit; m[0x44]=buf&255; m[0x45]=buf>>8; m[0x46]=block&255; m[0x47]=block>>8
        c=s.run(0xC70A, stop=0x0000)
        return c.a, c.p&1, c.x, c.y
    def sp(s,cmd,plist):
        # programa em $1000: JSR $C70D / .byte cmd / .word plist / (volta em $1006)
        m=s.m; code=[0x20,0x0D,0xC7,cmd,0x30,0x10,0x00]  # plist em $1030
        for i,b in enumerate(code): m[0x1000+i]=b
        for i,b in enumerate(plist): m[0x1030+i]=b
        c=s.run(0x1000, stop=0x1006)
        return c.a, c.p&1, c.x, c.y

def build_cfg(card, entries):
    """entries: lista (drive, nome83) -> bytes da tabela ($CE80..$CEE3) + magic, calculados em Python"""
    d=card; u=lambda o,n:int.from_bytes(d[o:o+n],'little')
    pst=0 if d[0] in (0xEB,0xE9) else u(0x1C6,4); b=pst*512
    spc=d[b+13]; rs=u(b+14,2); nf=d[b+16]; re=u(b+17,2); f16=u(b+22,2); fz=f16 or u(b+36,4)
    fat=pst+rs; root=fat+nf*fz; data=root+re//16
    def nxt(c): return (u(fat*512+c*4,4)&0x0FFFFFFF) if not f16 else u(fat*512+c*2,2)
    secs=[]
    if not f16:
        c=u(b+44,4)
        while True:
            secs+=[data+(c-2)*spc+i for i in range(spc)]; c=nxt(c)
            if c>=0x0FFFFFF8: break
    else: secs=[root+i for i in range(re//16)]
    cfg=bytearray([0xFF]*0x80)
    for drv,name in entries:
        found=None
        for sct in secs:
            for k in range(16):
                e=d[sct*512+k*32:sct*512+k*32+32]
                if e[:11]==name.encode(): found=(sct,k,e); break
            if found: break
        sct,k,e=found
        cl=u(sct*512+k*32+26,2)|(u(sct*512+k*32+20,2)<<16 if not f16 else 0); sz=u(sct*512+k*32+28,4)
        base=data+(cl-2)*spc; blocks=min(sz//512,0xFFFF)
        h=bytes([0x80])+base.to_bytes(4,'little')+blocks.to_bytes(2,'little')+sct.to_bytes(4,'little')+bytes([k])+e[20:22]+e[26:32]+bytes(4)
        cfg[drv*24:drv*24+24]=h
        print('  tabela: drive %d = %s  LBA %08X  blocos %d  dir %08X/%d'%(drv,name,base,blocks,sct,k))
    cfg[0x60]=ord('C')
    return cfg

if __name__=='__main__':
    rom=open('s14.bin','rb').read()[0x600:0xE00]
    bank4=bytearray(rom)
    ok=True
    def check(cond,msg):
        global ok
        print(('  OK   ' if cond else '  FALHA ')+msg); ok&=bool(cond)
    # ---------- 1) cartao cru (ProDOS): bloco 0 comeca com $01
    print('== cartao cru')
    raw=bytearray(4*1024*1024)
    for blk in range(8192): raw[blk*512:blk*512+2]=struct.pack('<H',blk)
    raw[0]=0x01
    S=Sys(bank4,bytearray([0xFF]*2048),raw)
    a,cy,x,y=S.p8(0,0x70,0); check(cy==0,'STATUS drive 1 (cru) A=%02X tam=%02X%02X'%(a,y,x))
    a,cy,_,_=S.p8(1,0x70,0x123); check(cy==0 and S.m[0x4000+1]==0x01 and S.m[0x4000]==0x23,'READ bloco $123 -> LBA $123')
    check(S.m[0x57F]==0,'FatFlags = %02X (cru)'%S.m[0x57F])
    # ---------- 2) cartao FAT32 com TESTE1.PO no drive 1 e HD32.PO no drive 2
    print('== cartao FAT32 (c32.img)')
    card=bytearray(open('c32.img','rb').read())
    cfg=build_cfg(card,[(0,'TESTE1  PO '),(1,'HD32    PO ')])
    b4=bytearray(bank4); b4[0xE80-0x700:0xE80-0x700+0x80]=cfg
    S=Sys(b4,bytearray([0xFF]*2048),card)
    a,cy,x,y=S.p8(0,0x70,0); check(cy==0 and x+256*y==1600,'STATUS drive 1 = %d blocos'%(x+256*y))
    a,cy,x,y=S.p8(0,0xF0,0); check(cy==0 and x+256*y==65535,'STATUS drive 2 = %d blocos'%(x+256*y))
    check(S.m[0x57F]==0x83,'FatFlags = %02X'%S.m[0x57F])
    base1=struct.unpack_from('<I',cfg,1)[0]
    a,cy,_,_=S.p8(1,0x70,5); exp=card[(base1+5)*512:(base1+6)*512]
    check(cy==0 and bytes(S.m[0x4000:0x4200])==exp,'READ drive 1 bloco 5 = LBA %X'%(base1+5))
    for i in range(512): S.m[0x5000+i]=(i*7)&255
    a,cy,_,_=S.p8(2,0x70,7,buf=0x5000)
    check(cy==0 and card[(base1+7)*512:(base1+8)*512]==bytes(S.m[0x5000:0x5200]) and S.st['writes'][-1]==base1+7,'WRITE drive 1 bloco 7 -> LBA %X'%(base1+7))
    a,cy,_,_=S.p8(1,0x70,1600); check(cy==1 and a==0x2D,'READ bloco 1600 (fora da imagem) -> erro %02X'%a)
    nw=len(S.st['writes']); a,cy,_,_=S.p8(2,0x70,1600,buf=0x5000); check(cy==1 and a==0x2D and len(S.st['writes'])==nw,'WRITE bloco 1600 recusado, nada escrito')
    # SmartPort: STATUS unit 0 (numero de drives), unit 3 offline, READ unit 2
    a,cy,_,_=S.sp(0,[3,0,0x00,0x60,0]); check(cy==0 and S.m[0x6000]==4,'SP STATUS unit 0: %d drives'%S.m[0x6000])
    a,cy,_,_=S.sp(0,[3,3,0x00,0x60,0]); check(cy==1 and a==0x2F,'SP STATUS unit 3 (vazio) -> erro %02X'%a)
    base2=struct.unpack_from('<I',cfg,24+1)[0]
    a,cy,_,_=S.sp(1,[3,2,0x00,0x60,0x34,0x12,0]); check(cy==0 and bytes(S.m[0x6000:0x6200])==card[(base2+0x1234)*512:(base2+0x1235)*512],'SP READ unit 2 bloco $1234')
    a,cy,_,_=S.sp(1,[3,1,0x00,0x60,0x00,0x00,0]); check(cy==0 and bytes(S.m[0x6000:0x6200])==card[base1*512:(base1+1)*512],'SP READ unit 1 bloco 0')
    # ---------- 3) arquivo mexido no PC (tamanho mudou) -> drive offline
    print('== entrada de diretorio alterada')
    card2=bytearray(card); sct=struct.unpack_from('<I',cfg,7)[0]; k=cfg[11]
    card2[sct*512+k*32+29]^=0x01
    S=Sys(b4,bytearray([0xFF]*2048),card2)
    a,cy,_,_=S.p8(1,0x70,5); check(cy==1 and a==0x2F,'READ drive 1 -> offline (%02X)'%a)
    a,cy,x,y=S.p8(0,0xF0,0); check(cy==0 and x+256*y==65535,'drive 2 continua montado')
    # ---------- 4) boot: banco 0 com utilitario falso ("CFU"), imagem com bloco de boot
    print('== boot pelo $C700 com utilitario no banco 0')
    card3=bytearray(card); card3[base1*512:base1*512+4]=bytes([0x01,0x4C,0x00,0x09])  # JMP $0900
    b0=bytearray([0xFF]*2048); b0[0:0x100]=b4[0:0x100]
    util=bytes([ord('C'),ord('F'),ord('U'), 0xA9,0x42, 0x8D,0x00,0x04, 0x60])   # lda #$42 / sta $0400 / rts
    b0[0x100:0x100+len(util)]=util
    S=Sys(b4,b0,card3); S.m[0x900]=0xEA
    S.m[0]=0; S.m[1]=0
    c=S.run(0xC700, stop=0x0900)
    check(S.m[0x400]==0x42,'utilitario rodou na RAM ($2003) e voltou')
    check(S.bank==4,'banco 4 selecionado no fim')
    check(bytes(S.m[0x800:0x804])==bytes([0x01,0x4C,0x00,0x09]),'bloco 0 da imagem do drive 1 carregado em $800 e executado')
    # ---------- 5) boot com banco 0 original (sem "CFU"): nao chama nada
    print('== boot com banco 0 sem utilitario')
    S=Sys(b4,bytearray(b4),card3); S.m[0]=0; S.m[1]=0
    c=S.run(0xC700, stop=0x0900); check(S.m[0x400]==0,'utilitario nao chamado; boot direto da imagem')
    # ---------- 6) cartao cru com tabela "velha" gravada: continua modo classico
    print('== cartao cru com tabela antiga na EEPROM')
    S=Sys(b4,bytearray([0xFF]*2048),raw)
    a,cy,_,_=S.p8(1,0x70,0x123); check(cy==0 and S.m[0x4000]==0x23 and S.m[0x57F]==0,'modo classico (FatFlags=%02X)'%S.m[0x57F])
    print('\nRESULTADO:', 'TUDO OK' if ok else 'HA FALHAS')
