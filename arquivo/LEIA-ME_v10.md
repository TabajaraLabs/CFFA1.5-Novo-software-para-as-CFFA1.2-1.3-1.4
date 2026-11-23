# CFFA v1.2 (Rich Dreher) — análise da ROM e do hardware — v10

Pasta do projeto: Documents/Claude/Apple II/CFFA (movida de Documents/Claude/CFFA em 2026-11-20; os projetos de Apple II ficam todos em Documents/Claude/Apple II)
Originais copiados em: original/ (firmware 1.3, lógica CPLD 1.4, esquema 2.0B em PDF, esquema 1.2B em Protel, fotos do "3 jumper fix")

## Versões (o que é "1.3" e "1.4")
- **EPROM 1.3** (jun/2004) = pacote de firmware: contém o driver 65C02 v1.2 (2002) e o driver 6502 v1.0 (2004).
- **Lógica 1.4** (abr/2005) = versão do CPLD (EPM7064S), não do firmware. Suporta o "3 jumper fix" (U4 pinos 2,3,4 levantados; A0–A2 do CF passam a vir latcheados do CPLD).
- Firmware 2.0 (2008) existe, mas para a placa CFFA 2.0 (EEPROM AT28C64, menu de configuração com 'M' no boot). Rich prometeu uma versão reduzida para placas 1.2; não localizada.

## Mapa da EPROM 27C256 (32 KB = 8 bancos de 4 KB, jumpers J6 A14/A13/A12, IN = 0)
Cada banco é uma imagem de $C000–$CFFF: $C000–$C0FF não decodificado; $C100–$C7FF = ROM de slot (uma página
diferente por slot, só a do slot onde a placa está é visível); $C800–$CEFF = ROM de expansão (1792 bytes).

| Banco | J6 (A14 A13 A12) | Conteúdo (verificado recompilando o fonte) | Livre em $C800 |
|---|---|---|---|
| 0 | IN IN IN | 65C02 v1.2, SmartPort, 4 partições, release | 590 bytes |
| 1 | IN IN OUT | idem, DEBUG (saída serial na SSC do slot 2, 19200 8N1) | 92 |
| 2 | IN OUT IN | 65C02 v1.2, SmartPort, 8 partições (GS/OS driver do Lyons não carrega) | 590 |
| 3 | IN OUT OUT | idem 8 partições, DEBUG | 92 |
| 4 | OUT IN IN | 6502 v1.0, release (SmartPort só no slot 5, sem autoboot; demais slots: 2 drives, autoboot) | 559 |
| 5 | OUT IN OUT | 6502 v1.0, DEBUG | 41 |
| 6 | OUT OUT IN | **VAZIO** | 4 KB |
| 7 | OUT OUT OUT | **VAZIO** | 4 KB |

Reprodução: o fonte da pasta (spdrv.s / spdrv6502.s) com ca65 2.19 gera os bancos 0–5 idênticos à ROM,
exceto bytes de preenchimento ($CnE5–$CnF4 e $CnF2–$CnF4). Ou seja, temos fonte confiável para modificar.

## Recursos escondidos (já existentes, só no driver 65C02 — bancos 0–3)
- SmartPort STATUS, unidade 0, código $49 ('I'): devolve os 512 bytes do ATA IDENTIFY (modelo/serial com bytes já desinvertidos).
- Unidade "mágica" 127 em READ/WRITE BLOCK SmartPort: acesso a LBA bruto de 24 bits (até 8 GB), ignorando partições e BLOCKOFFSET.
- ID da placa em $CnF6–$CnFA: "CFFA" + versão ($12 ou $10). $CnF5 = versão do driver GS/OS (02/03/10).
- Driver 6502 v1.0 não tem IDENTIFY nem unidade 127 (cortados por espaço).

## Hardware (esquema 1.2B e relatório do CPLD 1.4)
- CPLD EPM7064SLC44: 19 de 64 macrocélulas usadas (45 livres), 30/32 I/O usados; pino 8 livre. JTAG na placa (J7).
- Registradores $C0n0–$C0nF: 0 = latch byte alto; 1/2 = liga/desliga máscara de CS0 (truque SanDisk); 6 = alt status/dev ctrl;
  8–F = registradores ATA. **$C0n3, $C0n4, $C0n5 estão livres** (decodificáveis no CPLD para registradores novos).
- EPROM: A0–A11 do barramento, A12–A14 dos jumpers (pull-up 10k). Não é gravável na placa.
- CF socket e conector IDE no mesmo barramento; CF está como master (CSEL ao GND). Firmware sempre usa $E0 (master, LBA).
- Layout fixo: partição N = LBA N×65536 + BLOCKOFFSET (BLOCKOFFSET = 0 na ROM).


## Decisões e dados da bancada (2026-11-20)
- Serial do Apple: COM9 (a mesma porta da ponte; vale uma placa de cada vez). Ponte do projeto a 19200.
- EEPROM: Xicor X28C256P (32 KB, mesmo tamanho da 27C256 → 8 bancos). As 28C64 (8 KB) ficam de reserva.
  Gravar e conferir a velocidade na marcação (-15/-20/-25 servem). Deixar o SDP desligado.
- CPLD: Quartus II 13.0sp1 Web Edition (o último que suporta MAX7000S) + cabo JTAG já configurado. MAX+plus II não é necessário.
- CFFA no slot 7 → registradores em $C0F0–$C0FF, ROM em $C700 e $C800–$CEFF.
- Esquema da v1.2: só temos o arquivo binário do Protel; um PDF ou uma imagem respondem à maioria das medições.

## Ambiente do usuário (2026-11-20)
- Apple IIe + Super Serial Card; cabo JTAG disponível; programador BeeProg+; CF de 64 MB em uso (tem vários tamanhos).
- CF de 64 MB = 2 volumes ProDOS (o 1º com 32 MB, o 2º com o resto). Só a partir de ~128 MB se usam as 4 partições.
- Placa SEM o 3 jumper fix. Versão da lógica do CPLD ainda a confirmar (ler via JTAG: Security Bit = OFF, dá para ler de volta).


## Ferramentas e testes
- Ponte: Documents/Claude/pontes/ponte_serial_cffa_v1.bat (COM9, 19200, pasta CFFA). Para mandar um teste,
  copiar o .txt para CFFA/envio/ (a ponte envia sozinha e grava a resposta em CFFA/serial.log, com hora em ms).
- testes/idetest_v1 (roda em $6000, 640 bytes): IDENTIFY (modelo, serial, firmware, setores) e medição do laço de leitura
  original × rápido, lendo 256 setores a partir do LBA 0 (só leitura). As linhas >INICIO/>FIM dão o tempo pela hora da ponte.
  testes/idetest_v1_envio.txt digita o programa no monitor (CALL -151, linhas hex, 6000G).
  No Apple, antes: IN#1 e PR#1 (no prompt do BASIC).
- Simulação (testes/sim_idetest_v1.py, py65 com uma CFFA falsa): programa correto, as duas somas iguais.
  Ciclos de CPU (sem a latência do cartão): original 2.542.800, rápido 1.824.150 → −28 %
  (~2,49 s × ~1,79 s para 128 KB a 1,02 MHz). A medição real vai dizer quanto o cartão acrescenta.

## Fluxo de desenvolvimento proposto
1. Console serial: SSC no slot 2 ligada ao PC; no Apple, IN#2 / PR#2 levam o monitor/BASIC para a serial. A ponte serial
   (Documents/Claude/pontes, modo #raw) digita comandos do monitor (ex.: 9000: A9 00 ...; 9000G; C800.C8FF) e lê as respostas.
   Depois, um carregador binário pequeno no Apple (com ACK $06 a cada bloco) permite usar o #sendbin da ponte.
2. Testar todo código novo primeiro na RAM (acesso direto a $C0n8..$C0nF), sem gravar EPROM.
3. Gravar a ROM só quando estiver estável: trocar a 27C256 UV por uma equivalente regravável eletricamente
   (ex.: SST 27SF256 ou Winbond W27C257/W27E257 — conferir suporte no BeeProg+), mantendo a EPROM original guardada.
4. Opcional: EEPROM 28C256 num adaptador (pinos 1 e 27 trocados) com /WE vindo do CPLD → gravação na própria placa pela serial.

## 3 jumper fix — para que serve e como fazer
- Problema: sem o fix, A0–A2 do CF vêm direto do barramento do Apple (via U4). O endereço do 6502 muda logo depois do fim do ciclo,
  e alguns cartões CF exigem o endereço estável um pouco antes e depois de /IORD e /IOWR (tempos de setup e hold do ATA).
  Com o fix, A0–A2 vêm do CPLD (LA0–LA2), travados durante todo o ciclo do /DEVSEL. Resultado: mais cartões CF funcionam.
- Pré-requisito: CPLD com lógica 1.4. A lógica 1.4 sem o fix funciona (LA0–LA2 ficam sem uso);
  o fix com lógica 1.2 ou 1.3 NÃO funciona (entradas do U4 ficariam soltas).
- Procedimento: (a) gravar a lógica 1.4 por JTAG; (b) conferir que os pinos 9, 11 e 28 do CPLD não estão ligados a nada na placa;
  (c) descobrir com o multímetro qual dos pinos 2, 3 e 4 do U4 (74HCT245) recebe A0, A1 e A2 do slot
  (pinos 2, 3 e 4 do conector do slot, passando pelo resistor de 33 Ω); (d) levantar os pinos 2, 3 e 4 do U4;
  (e) ligar com fio fino: o pino que recebia A0 → CPLD pino 9 (LA0), A1 → pino 11 (LA1), A2 → pino 28 (LA2).

## Pinos do CPLD (EPM7064SLC44, lógica 1.4)
- 32 I/O de usuário, 30 em uso. Livres: pinos 8 e 27 (marcados RESERVED). Conferir na placa se estão mesmo sem ligação.
- O pino 24 (CS_MASK) é saída só por conveniência e pode virar nó interno se não estiver ligado na placa (+1 pino).
- Os pinos 1, 2 e 44 são entradas dedicadas ligadas ao GND. Os pinos JTAG (7, 13, 32, 38) ficam reservados ao JTAG.

## Troca de banco da ROM pelo CPLD
- Registrador novo em $C0n3 (escrita): bit 0 → EPROM A13, bit 1 → EPROM A14 (pinos 8 e 27 do CPLD).
  A12 continua no jumper → 4 bancos por software × 2 pelo jumper. Os jumpers A13 e A14 ficam OUT e o CPLD
  aciona a linha do lado da EPROM (o pull-up de 10k não atrapalha).
- O CPLD não recebe /RESET. No power-up o registrador zera (MAX7000), mas um Ctrl-Reset não zera.
  Por isso o código de boot de cada banco deve gravar o banco padrão em $C0n3 logo no início, com código idêntico
  e no mesmo endereço em todos os bancos (o mesmo vale para todo ponto de troca), ou a troca roda da RAM.
- Alternativa futura: 27C512 (64 KB) com o pino 1 (A15) também vindo do CPLD → 16 bancos.


## Configuração do Apple (2026-11-20)
- Apple IIe Enhanced (65C02) com 4 MB de RAM estendida → usar firmware 65C02 (banco 0 hoje). SSC no slot 1.
- Super Serial Card (19200 por chave; 115200 só por software, num laço dedicado):
  - SW1: 1-1 a 1-4 OFF (19200), 1-5 ON e 1-6 ON (modo comunicações/modem), 1-7 ON (CTS).
  - SW2: 2-1 ON, 2-2 ON, 2-3 OFF, 2-4 ON (8N1), 2-5 OFF (sem LF automático), 2-6 OFF (sem interrupções), 2-7 OFF.
  - Bloco de jumper: na posição MODEM com cabo null-modem até o PC; na posição TERMINAL com cabo direto.
  - No Apple: IN#1 e depois PR#1 (o console vai para a serial).

## EEPROM 28C256 no lugar da 27C256 (adaptador)
Diferenças de pinagem: na 27C256 o pino 1 é VPP e o 27 é A14; na 28C256 o pino 1 é A14 e o 27 é /WE.
O /OE de uma 28C256 em nível baixo inibe a escrita, e numa escrita a memória não pode ligar as saídas.
Adaptador com dois soquetes torneados empilhados; no soquete de cima, os pinos 1, 22 e 27 ficam dobrados para fora:
- Cima 1 (A14) → baixo 27 (linha do jumper A14). O baixo 1 (VPP) fica sem ligação.
- Cima 27 (/WE) → resistor de 33k para VCC (cima 28). Mais tarde → CPLD pino 8 (/WE gerado pela lógica nova).
- Cima 22 (/OE) → sinal NOT_RW (CPLD pino 26 / U2 pino 1): baixo na leitura, alto na escrita. O baixo 22 fica sem ligação.
- Todos os outros pinos passam direto.
Fase 0: gravar a 28C256 com CFFAv1.30.bin e usar com /WE só no pull-up → a placa tem que funcionar como antes.
NÃO ligar o pino 8 do CPLD enquanto a lógica for a 1.4 (pino RESERVED; estado não garantido).

## Lógica nova do CPLD (v1.5, a escrever)
O CPLD não enxerga o barramento de dados → os controles novos são chaves por endereço, como as do Apple:
- $C0n3: leitura = trava a escrita; escrita = destrava (num STA, a leitura falsa antes da escrita não atrapalha: vale o último acesso).
- $C0n4: leitura = banco A14 = 0; escrita = A14 = 1 (pino 27 do CPLD, se for usado para troca de banco).
- $C0n5: livre para o futuro.
- /WE = destravado & escrita & ROM da placa selecionada & não $CFxx; pulso dentro do PH0 (dado válido na subida do /WE).
- Toda escrita na 28C256 leva até 10 ms: esperar pelo "data polling" do D7. Não ligar o SDP (o endereço $5555 depende dos jumpers).

## Medições pedidas (placa sem alimentação, EPROM fora)
1. Soquete da EPROM pino 1 ↔ VCC?   2. Soquete pino 27 ↔ qual lado do jumper A14?
3. Soquete pino 22 (/OE) ↔ pino 20, GND ou CPLD 29?   4. Soquete pino 20 (/CE) ↔ CPLD 29?
5. CPLD pinos 8, 24 e 27 ↔ alguma coisa?   6. CPLD pinos 9, 11 e 28 ↔ alguma coisa? (para o 3 jumper fix)
7. U2 pino 1 ↔ CPLD 26 (NOT_RW)?


## CFFA3000 — o que ela faz e o que dá para trazer para a v1.2 (pesquisa de 2026-11-20)
Fontes: manual de referência v1.2 da CFFA3000 (pasta original/cffa3000), Readme do firmware 3.1, dreher.net.
- Hardware: microcontrolador AVR + CPLD Altera (~9× maior que o da v1.2) + SRAM 128 KB + RAM de duas portas de 8 KB.
  CF e pendrive USB com FAT16/FAT32; sem IDE. Firmware fechado. Hoje fabricada sob licença pela ReActiveMicro (desde 2021).
- Funções: menu ('M' no boot), imagens .PO/.2MG/.HDV como SmartPort; Disk II virtual em OUTRO slot vazio
  (nível de nibble, .DSK/.DO/.PO/.NIB, 1 trilha por vez em RAM); importação de disquetes/discos físicos para imagem;
  controle remoto com botões para trocar disquetes; troca de mídia com o Apple ligado; atualização de firmware e CPLD por arquivo no CF;
  driver SOS para o Apple ///; LEDs de diagnóstico; log de depuração.
- Disk II no nível de hardware NÃO é possível na v1.2: exige responder às chaves $C0nX de outro slot com um fluxo de
  nibbles em tempo real (microcontrolador + RAM). O projeto Floppy Emu do usuário já cobre isso.
- Dá para trazer para a v1.2 (firmware + EEPROM + menu carregado do CF):
  1. Imagens em cartão FAT16/FAT32 preparado no PC: o menu (na RAM) lê a FAT, lista os .PO/.2MG/.HDV,
     e o usuário associa uma imagem a cada drive. A ROM só soma o LBA inicial da imagem
     (os arquivos precisam ser contíguos; num cartão recém-formatado eles são).
     A tabela de associações fica gravada na própria EEPROM. Imagens de 140 KB e 800 KB funcionam como volumes ProDOS.
  2. Menu no boot, com boot por slot/drive, Ctrl-B, configurações salvas na EEPROM.
  3. Atualização de firmware lendo um arquivo do cartão (equivalente ao CFFA.BIN).
  4. Importação/exportação de imagens pela serial (o "USB" da v1.2) — ver o item 5 abaixo.
  5. DOS 3.3: via DOS.MASTER (volumes DOS 3.3 dentro de ProDOS) — só para software sem proteção.


## Projeto: imagens em cartão FAT montadas como volumes ProDOS (detalhado em 2026-11-20)
- Princípio: arquivo contíguo → bloco ProDOS N = setor (LBA_inicial_do_arquivo + N). Transparente para leitura e escrita;
  a FAT nunca é alterada (o tamanho do arquivo não muda). O PC enxerga as alterações quando o cartão volta para ele.
- LBA_inicial = início_da_partição + setores_reservados + FATs×setores_por_FAT + (cluster_inicial − 2)×setores_por_cluster (FAT32).
- Formatos nativos (ordem ProDOS, sem cabeçalho): .PO, .HDV, .IMG.
  .2MG: cabeçalho de 64 bytes desalinha os blocos dos setores → o menu converte (remove o cabeçalho) ou converte no PC.
  .DO/.DSK em ordem DOS: precisa traduzir a ordem dos setores → converter.
- Limites: volume ProDOS ≤ 32 MB (65535 blocos); os drives visíveis dependem do ProDOS (2.0.3 vs 2.4.x).
  O LBA passa a usar 28 bits (bits 24–27 no registrador Head) → cartões até 128 GB.
- Segurança: se o PC desfragmentar ou trocar um arquivo, um LBA guardado ficaria errado e a escrita iria para o lugar errado.
  Por isso a resolução é feita A CADA BOOT, pelo nome (código de FAT num banco extra da EEPROM),
  conferindo que o arquivo é contíguo e que o bloco 2 tem cabeçalho de volume ProDOS; senão o drive fica offline.
- O desempenho é igual ao do modo de partição fixa (só uma soma por acesso).
- Dois modos no mesmo firmware, detectados no boot (um cartão de cada vez):
  * Modo clássico (cartão CFFA "cru"): drive N começa no LBA N×65536 (+BLOCKOFFSET) — igual ao firmware atual.
  * Modo FAT: o setor 0 tem MBR com assinatura $55AA e partição FAT (tipo $04/$06/$0E FAT16, $0B/$0C FAT32),
    ou um setor de boot FAT direto no LBA 0 ("superfloppy", sem MBR) → drive N começa no LBA do arquivo associado.
  * Se a detecção falhar, a regra é cair no modo clássico; dá para forçar o modo no menu.
    Ao montar, conferir sempre o cabeçalho de volume ProDOS no bloco 2.
  * O driver é um só: ele sempre soma "LBA base do drive". O boot só preenche a tabela de bases de um jeito ou de outro.
    A tabela fica na EEPROM, gravada somente quando muda (para poupar os ciclos de escrita).


## Ideias (detalhadas na conversa de 2026-11-20)
1. Sem mexer na ROM: utilitários em RAM (info do cartão, editor de setores, troca de volumes além dos 128 MB, benchmark), usando os recursos escondidos ou acessando $C0n8.. direto.
2. Nova EPROM aproveitando bancos 6 e 7 (sem perder os originais): laço de leitura/escrita mais rápido (~25–30%), boot por qualquer partição, seletor de "banco de volumes", stub carregador de utilitário a partir de blocos reservados no CF (BLOCKOFFSET), 6502 com IDENTIFY/raw, suporte a slave no conector IDE.
3. CPLD via JTAG: registrador novo em $C0n3; /WE para EEPROM 28C256 num adaptador (gravação na própria placa); troca de banco por software (precisa de mais um pino).
4. Outros usos: driver Apple /// (a3DriverDepot), driver CP/M para Appli-Card (sourceforge cffaapplicard), MAME para testar antes de gravar.
5. Pedido do usuário (2026-11-20), para a próxima sessão: carregador de imagens (.IMG/.PO/.2MG) pela serial que grava direto no cartão CF.
   Ideia: um programa no Apple a 115200 recebe blocos de 512 bytes com ACK ($06), usando o #sendbin da ponte,
   e grava pelos registradores da CFFA na partição escolhida (ou num LBA bruto).
   Velocidade estimada: ~11 KB/s → disquete de 140 KB em ~15 s; volume de 32 MB em ~50 min.
   Validar com checksum por bloco e reler no fim.
