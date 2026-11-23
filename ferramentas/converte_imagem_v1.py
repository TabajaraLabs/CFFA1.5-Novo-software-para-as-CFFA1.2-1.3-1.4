#!/usr/bin/env python3
# converte_imagem_v1.py - Tabajara Labs, 2026-11-20
# Converte imagens de disco do Apple II para .PO (ordem ProDOS, sem cabecalho), o formato que a CFFA monta.
#   .DSK / .DO (140 KB, ordem DOS 3.3)  -> reordena os setores
#   .2MG                                 -> tira o cabecalho de 64 bytes (e reordena se for ordem DOS)
#   .PO / .HDV                           -> so confere
# A ordem de um .DSK e detectada procurando o diretorio de volume ProDOS no bloco 2.
# Uso:  python converte_imagem_v1.py ARQUIVO [ARQUIVO...]        (gera ARQUIVO.po ao lado do original)
#       python converte_imagem_v1.py *.dsk *.2mg
import sys, os, struct

# setor fisico DOS de cada setor "logico" ProDOS dentro de uma trilha (tabela classica do CiderPress)
DO_DE_PO = [0x0,0xE,0xD,0xC,0xB,0xA,0x9,0x8,0x7,0x6,0x5,0x4,0x3,0x2,0x1,0xF]

def do_para_po(d):
    assert len(d) % 4096 == 0
    out = bytearray(len(d))
    for t in range(len(d)//4096):
        for s in range(16):
            o = t*4096
            out[o+s*256:o+s*256+256] = d[o+DO_DE_PO[s]*256:o+DO_DE_PO[s]*256+256]
    return bytes(out)

def po_para_do(d):           # inversa (usada nos testes)
    out = bytearray(len(d))
    for t in range(len(d)//4096):
        for s in range(16):
            o = t*4096
            out[o+DO_DE_PO[s]*256:o+DO_DE_PO[s]*256+256] = d[o+s*256:o+s*256+256]
    return bytes(out)

def e_prodos(po):
    """diretorio de volume ProDOS no bloco 2 (ordem ProDOS)?"""
    if len(po) < 1536: return False
    b = po[1024:1536]
    prev, nxt = struct.unpack_from('<HH', b, 0)
    return prev == 0 and nxt in (3, 0) and (b[4] >> 4) == 0xF and 1 <= (b[4] & 15) <= 15 and b[0x23] == 0x27

def nome_volume(po):
    b = po[1024:1536]; return '/' + b[5:5+(b[4]&15)].decode('ascii', 'replace')

def converte(caminho):
    d = open(caminho, 'rb').read()
    ext = os.path.splitext(caminho)[1].lower()
    aviso = ''
    if d[:4] == b'2IMG':
        hl, ver, fmt = struct.unpack_from('<HHI', d, 8)
        off, tam = struct.unpack_from('<II', d, 24)
        dados = d[off:off+tam]
        if fmt == 0:   po = do_para_po(dados); como = '.2MG ordem DOS -> reordenado'
        elif fmt == 1: po = dados; como = '.2MG ordem ProDOS -> cabecalho retirado'
        else: return 'NAO CONVERTIDO: .2MG em formato nibble (%d)' % fmt
    elif ext in ('.po', '.hdv'):
        po = d; como = 'ja esta em ordem ProDOS'
    elif ext in ('.dsk', '.do'):
        if len(d) != 143360: return 'NAO CONVERTIDO: .DSK com %d bytes (esperado 143360)' % len(d)
        if e_prodos(d):   po = d; como = '.DSK ja estava em ordem ProDOS'
        else:
            po = do_para_po(d); como = '.DSK ordem DOS -> reordenado'
    elif ext == '.nib':
        return 'NAO CONVERTIDO: .NIB (formato de nibbles) nao e suportado'
    else:
        return 'NAO CONVERTIDO: extensao desconhecida'
    if len(po) % 512:
        po = po + bytes(512 - len(po) % 512); aviso += ' (completado ate multiplo de 512)'
    if len(po) > 65535*512:
        aviso += ' ATENCAO: maior que 32 MB, a CFFA usa so os primeiros 65535 blocos'
    if e_prodos(po): vol = 'volume ProDOS ' + nome_volume(po)
    else: vol = 'SEM volume ProDOS no bloco 2 (disco DOS 3.3 ou protegido?): o ProDOS nao vai ler'
    saida = os.path.splitext(caminho)[0] + '.po'
    if ext in ('.po', '.hdv') and not d[:4] == b'2IMG':
        return '%s; %s; %d blocos%s (nada gravado)' % (como, vol, len(po)//512, aviso)
    if os.path.exists(saida):
        saida = os.path.splitext(caminho)[0] + '_convertido.po'
    open(saida, 'wb').write(po)
    return '%s; %s; %d blocos%s -> %s' % (como, vol, len(po)//512, aviso, os.path.basename(saida))

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__ or 'uso: converte_imagem_v1.py ARQUIVO...'); sys.exit(1)
    import glob
    arqs = [a for p in sys.argv[1:] for a in (glob.glob(p) or [p])]
    for a in arqs:
        try: print('%s: %s' % (os.path.basename(a), converte(a)))
        except Exception as e: print('%s: ERRO %s' % (os.path.basename(a), e))
