#!/usr/bin/env python3
# prepara_serial_v2.py - Tabajara Labs, 2026-11-20
# v2: usa o serimg_v2 (CLD na entrada) e zera $48 antes de cada G (o G do monitor restaura P de $48;
#     depois de um boot ProDOS fica $FF ali = modo decimal ligado, que embaralhava os blocos no v1).
# Gera os arquivos de envio da ponte serial (v6) para o serimg (transferencia de imagens a 115200).
#   python prepara_serial_v1.py grava  imagens\JOGO.po  2      -> grava JOGO.po no drive 2 da CFFA
#   python prepara_serial_v1.py backup 1  backup\drive1.po     -> copia o drive 1 inteiro para o PC
# Os caminhos sao relativos a pasta do projeto (Documents\Claude\Apple II\CFFA). O arquivo gerado vai para
# serial\ ; para executar, copie-o para envio\ (a ponte precisa ser a v6: pontes\ponte_serial_cffa_v2.bat).
# O Apple precisa estar no monitor com a serial ligada (IN#1, PR#1, CALL -151).
import sys, os
AQUI = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(AQUI)
UNID = {'1': 0x70, '2': 0xF0, '3': 0x40, '4': 0xC0}     # drives 3/4: slot espelhado (o driver soma 2)
CARGA = bytes.fromhex('8002600 8AD020385FB64FA9C5B039C5C03AE0303AD99C02910F0F9A9068D98C0A000AD99C02908F0F9AD98C091FA186D5B038D5B03900 3EE5C03C8D0E5E6FBCAD0D2A9D320EDFDA9BD20EDFDAD5C0320DAFDAD5B0320DAFD4C8EFD0000'.replace(' ',''))
def cabeca():
    L = ['#raw', '#idle 1.5', '#chardelay 0.03', '48:00']
    for i in range(0, len(CARGA), 16):
        L.append('%04X:' % (0x300 + i) + ' '.join('%02X' % b for b in CARGA[i:i + 16]))
    L += ['302:60 04', '48:00', '300G', '#sendbin serial\\serimg_v2_pad.bin 256', '#pause 2', '#idle 2']
    return L
def main():
    if len(sys.argv) < 4 or sys.argv[1] not in ('grava', 'backup'):
        print(open(__file__, encoding='utf-8').read().split('import sys')[0]); sys.exit(1)
    if sys.argv[1] == 'grava':
        arq, drv = sys.argv[2], sys.argv[3]
        tam = os.path.getsize(os.path.join(PROJ, arq))
        if tam % 512: print('ATENCAO: tamanho nao e multiplo de 512; o ultimo bloco vai incompleto')
        nb = (tam + 511) // 512
        L = cabeca() + ['6003:00 %02X %02X %02X 00 00 01 01' % (UNID[drv], nb & 255, nb >> 8), '48:00', '6000G',
                        '#sendbin %s 512' % arq, '#pause %d' % (5 + nb * 0.012), '#idle 3']
        nome = 'grava_%s_drive%s_envio.txt' % (os.path.splitext(os.path.basename(arq))[0], drv)
        print('%s: %d blocos (%.1f KB) -> drive %s; tempo estimado %.0f s' % (arq, nb, tam / 1024, drv, nb * 0.07 + 30))
    else:
        drv, arq = sys.argv[2], sys.argv[3]
        L = cabeca() + ['6003:01 %02X 00 00 00 00 01' % UNID[drv], '48:00', '6000G', '#recvbin %s' % arq, '#pause 3', '#idle 3']
        nome = 'backup_drive%s_envio.txt' % drv
        print('backup do drive %s inteiro -> %s' % (drv, arq))
    open(os.path.join(AQUI, nome), 'w').write('\n'.join(L) + '\n')
    print('gerado: serial\\%s  (copie para envio\\ para executar)' % nome)
main()
