# CFFA v1.2 (Rich Dreher) — análise da ROM e do hardware — v29

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
- Testes atuais (2026-11-20, corrigido): BOOTI no SLOT 7 (dá o boot) e CFFA v1.2 do Rich (montada, sem o 3 jumper fix)
  no SLOT 5 → registradores em $C0D0–$C0DF, ROM em $C500 e $C800–$CEFF; SSC no slot 1.
  No slot 5 o SmartPort da CFFA ganha até 4 drives no ProDOS (2 aparecem como slot 2); com o CF de 64 MB são 2 volumes.
  Na BOOTI: programas Applesoft SR (liga a serial) e SM (serial + monitor) → testes/programas_basic_serial_v1.txt.
- A CFFA Lite fica para depois. O 3 jumper fix não é necessário para nada do que está planejado agora.
  Na v1.2: /WE no pino 8 e banco (A14) no pino 27; o pino 24 só pode ser usado se for confirmado que está livre.
- Esquema da v1.2: só temos o arquivo binário do Protel; um PDF ou uma imagem respondem à maioria das medições.

## Ambiente do usuário (2026-11-20)
- Apple IIe + Super Serial Card; cabo JTAG disponível; programador BeeProg+; CF de 64 MB em uso (tem vários tamanhos).
- CF de 64 MB = 2 volumes ProDOS (o 1º com 32 MB, o 2º com o resto). Só a partir de ~128 MB se usam as 4 partições.
- Placa SEM o 3 jumper fix. Versão da lógica do CPLD ainda a confirmar (ler via JTAG: Security Bit = OFF, dá para ler de volta).



## CFFA Lite (placa do usuário, esquema "0dot3", 04/04/2021 — Placa tabajara labs/esquema.png)
Mesmo circuito da CFFA v1.2, numa placa menor. Confirmado no esquema e na placa:
- O 3 jumper fix já vem na placa: IDE_A0, A1 e A2 saem dos pinos 9, 11 e 28 do CPLD e vão ao CF pelo IC4 (74HCT245) com resistores de 33 Ω.
- Pinos livres do CPLD: 8, 24 e 27 ("vago").
- Pino 13 = TMS: vai só ao JP3 pino 5 (verificado pelo usuário). O texto "EPROM_EN" ao lado dele no desenho é um rótulo solto.
  JTAG (JP3, padrão Altera de 10 pinos): 1 TCK (CPLD 32), 3 TDO (38), 5 TMS (13), 9 TDI (7), 2 e 10 GND, 4 VCC.
- EPROM 27256 (IC2): /CE (20) e /OE (22) juntos no EPROM_EN = CPLD pino 29; VPP (1) no VCC;
  A12/A13/A14 (2/26/27) no JP2, que fecha para GND, com pull-ups de 10k (R9–R11).
- Buffer de dados IC3 (74HCT245): CPLD 25 → G (pino 19) e CPLD 26 → DIR (pino 1); no desenho os nomes "245BUS_SEL"/"245BUS_ENA" estão trocados em relação à função.
- Latches IC5/IC6 (74HCT373) = registradores do byte alto, como na CFFA. Conector IDE JP1, JP4 = /RESET para o IDE, LED1 de atividade.
- Plano da EEPROM na Lite: /WE → CPLD 8 (+33k para VCC); /OE → NOT_RW (CPLD 26 = DIR do IC3); banco por software → CPLD 24 e 27.


## Primeiros resultados no Apple (2026-11-20)
- Serial OK nos dois sentidos com o cabo IDC-10 → DE9 completo (o primeiro cabo estava com defeito).
  O Apple manda os caracteres com o bit 7 ligado; para ler o serial.log, zerar o bit 7.
- CFFA v1.2 do Rich de volta no SLOT 7 → usar idetest_v1. (As versões v2/slot 6 e v3/slot 5 ficam guardadas.)
- Cartão: "STI Flash 8.0.0", serial STI1M92108065194147, firmware 06/20/07, 125.440 setores ($1EA00) = 64,2 MB.
- Leitura de 256 setores (128 KB): laço original 3,14 s (~41 KB/s); laço rápido 2,46 s (~52 KB/s)
  → −22 % de tempo / +28 % de vazão, somas iguais (dados idênticos). O cartão acrescenta ~2,5 ms por setor.
  Detalhes: testes/resultado_idetest_v1_20261120.txt.
- Observação: os arquivos de envio começam com CALL -151. Se o Apple já está no monitor (-SM), o monitor
  interpreta "CALL" como comandos (o "L" lista código) — não faz mal, mas os próximos envios não vão mais incluir essa linha.


## Fase 0 concluída (2026-11-20)
- X28C256 com a gambiarra (pino 1 → furo 27 do soquete; pino 27 /WE → VCC) dá boot no ProDOS pelo CF.
- Leitura pela serial: $C700 e os 1792 bytes de $C800–$CEFF iguais ao BANCO 4 da CFFAv1.30.bin (0 diferenças).
  → os jumpers J6 da placa selecionam o banco 4 = driver 6502 v1.0 (ProDOS, 2 drives, sem SmartPort fora do slot 5).
  O IIe Enhanced pode usar o banco 0 (65C02 v1.2, SmartPort, 4 partições): J6 A14 IN, A13 IN, A12 IN.
- Para ler a ROM de expansão pela serial é preciso copiar para a RAM antes ($CFFF, $C700, depois copiar $C800–$CEFF),
  porque a própria SSC toma o espaço $C800 a cada caractere impresso.
- O backup do CPLD não é necessário: o usuário já tem o binário guardado.

## Lógica v1.5 para a CFFA 1.2 (cpld/cffa12_v15, projeto Quartus II 13.0sp1)
- cffa_core_v15.v (núcleo comum com a Lite) + cffa12_v15.v (topo) + .qpf/.qsf com a pinagem da 1.4 e os pinos novos 8 (/WE) e 27 (A14).
- Simulação (Icarus Verilog): 200.000 vetores aleatórios contra as equações do relatório da 1.4 → 0 diferenças;
  teste dirigido das funções novas → tudo como esperado (/WE de ~279 ns, nada em $CFxx, trava e banco OK).
- Gravada e testada na placa (2026-11-20): Quartus sem erros, 27/64 macrocélulas, pinos conferidos no .pin, Fmax 92,6 MHz.
  Com a v1.5: ROM lida igual ao banco 4 (0 diferenças) e idetest igual ao da 1.4 (3,15 s / 2,44 s, somas 9AB7).
  Detalhes: testes/resultado_cpld_v15_20261120.txt. Próximo passo: fiação da fase 2.
- Atenção nos testes: o idetest ocupa $6000–$627F e usa $6800 como buffer; rotinas auxiliares vão em $6300.
- Fase 2 (fiação, depois de gravar o CPLD): /WE da EEPROM (pino 27 dela) → CPLD pino 8 (mantém o pull-up);
  pino 22 da EEPROM dobrado para fora → NOT_RW (CPLD pino 26); A14: tirar o jumper A14 do J6 e ligar o CPLD pino 27 à linha A14
  (o pull-up de 10k da placa dá o "1"; se o jumper A14 ficar IN, o banco fica forçado em 0 sem conflito).


## Fase 2 — fiação e problemas encontrados (2026-11-20)
- Fiação: pino 1 da EEPROM (laranja) → CPLD 27; pino 22 (preto) → CPLD 26; pino 27 (marrom) → CPLD 8.
  Na primeira tentativa os fios caíram em pinos de endereço (contagem espelhada pelo lado da solda); corrigido.
- A CFFA 1.2 NÃO tem pull-up na linha A14 → resistor de 10k do pino 1 ao pino 28 da EEPROM (acrescentado).
- Com a v1.5/v1.5.1 e o jumper A14 aberto, o boot travava quase sempre (BRK em $CC7A, laço de espera do cartão):
  o A14 mudava sozinho durante o boot, e uma leitura de $C0F5 não voltava o banco. Com o jumper A14 fechado: sem falhas.
- Também: a v1.5 tinha "Power-Up Don't Care" = On (o Quartus escolhia o estado inicial dos registradores);
  corrigido na v1.5.1 (ALLOW_POWER_UP_DONT_CARE OFF).
- Hipótese: pulsos curtos no /DEVSEL do IIe alcançando uma borda do 7M mudavam o registrador (a v1.5 usava o /DEVSEL cru).
- v1.6 (cpld/cffa12_v16): amostragem só no meio do ciclo (/DEVSEL baixo também na borda de descida anterior, como o W_HOST do Rich);
  banco por endereço, sem depender do R/W: $C0F4 = A14 0, $C0F5 = A14 1 (os dois também travam a gravação);
  $C0F3 escrita destrava, leitura trava. Simulação: 0 diferenças contra a 1.4; 20 pulsos espúrios de 25 ns ignorados.

- 2026-11-20 (continuação): o jumper A14 não fazia efeito na fiação da fase 2 (o fio pino 1 → furo 27 da fase 0 foi substituído
  pelo laranja até o CPLD); as conclusões tiradas de "boot sem falhas com o jumper fechado" estavam erradas.
- Teste decisivo: EPROM original + jumper A14 fechado: CPLD compilado no Quartus (v1.5.1) → 80% dos boots; .pof original da 1.4 (MAX+plus II) → 100%.
  → causa principal: TEMPORIZAÇÃO da compilação no Quartus (o Rich avisou no LEIA-ME da 1.4 que o Quartus não funcionava).
  Diferença encontrada: a 1.4 original usa Turbo Bit = OFF (0/64 células turbo); o Quartus ligou o turbo nas 27 células (sinais mais rápidos).
- v1.6.1 (cpld/cffa12_v161): v1.6 + AUTO_TURBO_BIT OFF → 0/64 células turbo (Fmax 23,8 MHz, como a 1.4).
  (A linha TURBO_BIT com "*" é ignorada pelo Quartus — basta a global; tirar na próxima versão.)
  RESULTADO: EPROM original + jumper A14 fechado + v1.6.1 → 8 de 8 boots OK. Causa confirmada: Turbo Bit ligado.
- X28C256 de volta com a fiação da fase 2 + v1.6.1: boots 100%. O resistor de 470 Ω em série no A14 foi retirado
  (com ele o A14 ficava em 1,6 V; a corrente medida indica um pull-up menor que 10k ou a perna 1 encostando no soquete — conferir).
  Troca de banco OK: 80 10 80 80 80 10 80 (testes/…banco). Na partida: banco 0.
- PRIMEIRA GRAVAÇÃO PELA SERIAL OK (09:22): $A5 gravado em $CEF0 do banco 4, ~3,4 ms, banco 0 intacto.
  Detalhes: testes/resultado_gravacao_v1_20261120.txt. Pendente: voltar $CEF0 do banco 4 para FF.
- Bancos alcançáveis por software na CFFA 1.2: só 0 e 4 (A13/A12 ficam nos jumpers). Plano: banco 0 = firmware original (boot seguro);
  banco 4 = firmware novo em teste (troca com $C0F5 e C700G no monitor; se travar, desligar e ligar volta ao banco 0).
- Gravador pela serial (gravador/gravador_v1, 2026-11-20): recebe 2048 bytes ($C700–$CEFF de um banco) pelo #sendbin da ponte,
  grava só os bytes diferentes (escrita simples + data polling), trava, confere e mostra o resumo. Simulado (py65) e testado na placa:
  banco 4 de volta ao original (1 byte gravado, 0 falhas).
- FIRMWARE 1.3 ("1.2R") no banco 4: laço de leitura com status 1× por setor. ProDOS lendo 256 blocos: 3,23 s (banco 0) → 2,60 s (banco 4),
  +24% de vazão. Os pontos de entrada não mudaram: dá para trocar de banco com o ProDOS rodando ($C0F5 = 1.3, $C0F4 = original).
  Detalhes: testes/resultado_firmware13_v1_20261120.txt. O banco 4 não tem mais o driver 6502 (guardado em rom/).
- Medições na placa são difíceis sem extensor de slot: manter o mínimo possível (o usuário vai providenciar um extensor).

## Ferramentas e testes
- Ponte: Documents/Claude/pontes/ponte_serial_cffa_v1.bat (COM9, 19200, pasta CFFA). Para mandar um teste,
  copiar o .txt para CFFA/envio/ (a ponte envia sozinha e grava a resposta em CFFA/serial.log, com hora em ms).
- testes/idetest_v3 = programa para o slot 5 (USAR ESTE). idetest_v2 = slot 6, idetest_v1 = slot 7.
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
  - Bloco de jumper: posição MODEM, com o cabo IDC-10 → DE9 fêmea (null-modem embutido) da seção "Cabo da Super Serial".
  - No Apple: IN#1 e depois PR#1 (o console vai para a serial).


## Cabo da Super Serial: IDC-10 → DE9 fêmea (null-modem embutido), versão 1
Liga direto na DE9 macho do PC/adaptador USB (COM9). Bloco de jumper da SSC na posição MODEM; SW1-7 ON, SW2-7 OFF.
Os nomes do conector de 10 pinos da SSC (posição MODEM, a SSC funciona como DTE): 1 FRMGND, 2 TxD, 3 RxD, 4 RTS, 5 CTS,
6 DSR, 7 SCTS, 8 SGND, 9 DTR, 10 DCD (fonte: Apple IIe Technical Note #7).

| IDC-10 (SSC) | Sinal da SSC | DE9 fêmea | Sinal do PC |
|---|---|---|---|
| 2 | TxD (sai) | 2 | RxD |
| 3 | RxD (entra) | 3 | TxD |
| 4 | RTS (sai) | 8 | CTS |
| 5 | CTS (entra) | 7 | RTS |
| 9 | DTR (sai) | 6 e 1 | DSR e DCD |
| 6 | DSR (entra) | 4 | DTR |
| 10 | DCD (entra) | 4 | DTR |
| 8 | GND de sinal | 5 | GND |
| 1 | GND de carcaça | carcaça (opcional) | — |
| 7 | SCTS | não ligar | — |
- A ponte abre a porta com RTS e DTR ligados → CTS, DSR e DCD ativos na SSC.
- O pino 9 da DE9 (RI) fica sem ligação.
- Teste mínimo, se faltar fio: 2→2, 3→3, 8→5, mais um jumper no lado da SSC ligando 4→5 (RTS→CTS) e 9→6 e 10 (DTR→DSR e DCD).

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


### Adaptador da EEPROM — fase 0 na CFFA v1.2 (só leitura, sem nenhuma ligação ao CPLD)
Enquanto a EEPROM não é gravada pela placa, o /OE não interfere: o pino 22 continua ligado como estava.
Só os pinos 1 e 27 mudam:
- Soquete torneado (adaptador) entre a placa e a EEPROM: os pinos 1 e 27 de cima ficam dobrados para fora (não entram no soquete da placa).
- EEPROM pino 1 (A14) → pino 27 do soquete da placa (linha do jumper A14 do J6).
- EEPROM pino 27 (/WE) → resistor de 10k–33k → EEPROM pino 28 (VCC). /WE sempre em nível alto = nunca grava.
- O pino 1 do soquete da placa (VPP, no VCC) fica sem ligação.
- Conferir antes, sem alimentação: soquete da placa pino 27 ↔ jumper A14 do J6; soquete pino 1 ↔ VCC (pino 28).
- Gravação no BeeProg: X28C256 com CFFAv1.30.bin (32 KB inteiros), verificar, SDP desligado. Guardar a EPROM original.
Fase 2 (depois do CPLD v1.5): o fio do /WE sai do pull-up e vai também ao CPLD pino 8 (o pull-up fica);
o pino 22 da EEPROM é dobrado para fora e ligado ao NOT_RW (CPLD pino 26).

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


## Modo FAT — arquitetura decidida (2026-11-20, v24)
Espaço disponível (medido no firmware 1.3 do banco 4): o driver ocupa $C700–$CCB1; sobram só **590 bytes** ($CCB2–$CEFF).
Do slot 7 só se enxergam $C700–$CEFF de cada banco (2 KB), e na CFFA 1.2 só A14 é trocado por software (bancos 0 e 4).
Um leitor de FAT16/FAT32 + menu não cabe em 590 bytes; por isso o trabalho fica dividido:
- **Banco 4 = driver** (firmware 1.4, a escrever): o driver de sempre + "LBA base por drive" + tabela de montagem.
  - A tabela de montagem fica na própria EEPROM (bloco de configuração em $CExx do banco 4), gravada só quando muda.
    Por drive: estado, LBA inicial (28 bits), nº de blocos, nome 8.3, cluster inicial, setor/posição da entrada de diretório.
    Fica memorizada com o Apple desligado (como na CFFA3000).
  - Não há RAM livre para isso: os 8 "screen holes" do slot 7 já são usados pelo driver (só $57F e $7FF estão livres).
  - Na inicialização do drive o driver relê a entrada de diretório gravada e compara nome, cluster e tamanho;
    se não bater (cartão trocado ou mexido no PC), o drive fica offline. Isso protege também o boot por outro slot.
- **Banco 0 = utilitário** (menu + FAT, até 1.792 bytes em $C800–$CEFF): no boot, se o cartão for FAT, o código da página $C7
  copia o banco 0 para a RAM, volta para o banco 4 e executa o utilitário na RAM. Ele resolve de novo as imagens pelo nome,
  confere contiguidade, mostra o menu (tecla dentro de ~1 s, ou sempre se nada estiver montado), grava a tabela na EEPROM
  e devolve o controle ao boot normal do driver (bloco 0 da imagem montada no drive 1).
  - A página $C700 tem de ser igual nos dois bancos nos pontos de troca; o boot e as entradas do driver selecionam o banco 4 primeiro
    (o CPLD sempre liga no banco 0).
  - Isso **substitui o original do banco 0**. Rede de segurança: tirar o jumper A13 do J6 → bancos 2/6, e liga no banco 2
    (driver original 65C02 de 8 partições, intacto). Último recurso: regravar no BeeProg.
  - Alternativa sem mexer no banco 0: só na CFFA Lite (3 pinos livres → A12/A13 também por software, 8 bancos).
- Formatos aceitos para montar: .PO, .HDV, .IMG (ordem ProDOS, sem cabeçalho), tamanho múltiplo de 512, máximo 65535 blocos
  (um arquivo de 32 MB exatos = 65536 blocos é limitado a 65535). FAT12 recusada. .2MG/.DSK ficam para conversão.
- O utilitário só lê a FAT, nunca escreve nela.
- **Decisão do usuário (2026-11-20 10:00): o banco 0 pode ser usado para o utilitário.**

## Protótipo fatcat_v1 (fat/, 2026-11-20)
- Programa na RAM ($6000, 2.031 bytes; buffers $6800/$6A00; variáveis $6C00). Só leitura. Rodar com 6000G (ESC interrompe).
- Lê o setor 0. Aceita MBR (partição 1 tipo $04/$06/$0E/$0B/$0C) ou VBR direto no setor 0 ("superfloppy").
- Interpreta o BPB (FAT16/FAT32) e percorre o diretório raiz (região fixa no FAT16, cadeia de clusters no FAT32).
- Para cada .PO/.HDV/.IMG mostra nome, blocos, cluster inicial, LBA inicial, nº de clusters e OK/FRAGMENTADO
  (TAM? = tamanho não múltiplo de 512).
- Ignora apagados, nomes longos (mostra o nome curto 8.3), pastas e rótulo de volume.
- Contiguidade: caminho lento por fatnext() + laço rápido dentro do mesmo setor de FAT.
- Simulado (sim_fatcat_v1.py, py65 + CFFA emulada) contra cartões gerados por mkcartoes_v1.sh (mkfs.fat + mtools):
  - FAT32 de 64 MB com MBR;
  - FAT16 de 64 MB sem MBR;
  - arquivos de 800 KB, 32 MB, um fragmentado de propósito, um nome longo, uma pasta.
  Resultado idêntico ao calculado por verdade_fat_v1.py.
- Tempo simulado:
  - FAT16 (clusters de 2 KB): 2,2 s;
  - FAT32 de 64 MB (clusters de 512 bytes, o pior caso): 12,5 s, por causa dos 65.536 clusters da imagem de 32 MB;
  - cartões maiores (clusters de 4 KB ou mais): menos de 1 s.
  A conferência de contiguidade só precisa ser completa na hora de montar; no boot basta comparar a entrada de diretório.
- Erros corrigidos na simulação: o nome "SEC" colidia com a instrução SEC do ca65 (virou SBUF);
  um CPY no meio da subtração de 32 bits estragava o carry (c2l desenrolado);
  PTR da FAT era sobrescrito pela leitura do setor (agora FOFS);
  a primeira versão da conferência levava 10,7 s no FAT16.
- Teste real, 2026-11-20 09:49, cartão ProDOS cru (STI 64 MB): "NAO E FAT16/FAT32 (CARTAO PRODOS CRU?)" — correto.
- Próximo teste: cartão FAT32 ou FAT16 formatado no PC com algumas imagens .PO/.HDV.

## Firmware 1.4 (banco 4) — escrito e simulado (2026-11-20, v26)
Arquivos: firmware/spdrv14_v1.s/.lst, firmware/c100.cfg (ld65: $C100–$CEFF, sobra preenchida com $FF),
rom/banco4_spdrv14_C700-CEFF_v1.bin. FIRMWARE_VER $14 ("Ver:1.4" na mensagem de erro do boot).
rom/ agora tem o 1.4 (atual) e o 1.3 (anterior); o original do banco 4 foi para rom/arquivo/.
- **Página $C7** (igual nos dois bancos): o boot, a entrada ProDOS ($C70A) e a SmartPort ($C70D) leem `$C085,X`
  ($C0F5 = banco 4) antes de pular para $C800. Os pontos de entrada e o byte $CnFF não mudaram.
  - O CPLD confirma que ler $C0F5 não aciona o cartão: CS1 só nos endereços 6/7; CS0 só com A3=1.
  - Sobram 3 bytes na página $C7.
- **Boot:** depois do CheckDevice chama `FatBoot`.
  - Força o FatInit. Se o cartão for FAT, copia um trampolim de 60 bytes para $0300 e o executa.
  - O trampolim seleciona o banco 0 e confere a assinatura "CFU" em $C800.
  - Se a assinatura existir, copia $C800–$CEFF do banco 0 para $2000–$26FF, volta ao banco 4 e chama $2003 (X = $n0).
  - Na volta religa a ROM $C800 da placa (`BIT $CFFF` + `LDA $Cn00`), seleciona o banco 4 e refaz o FatInit.
    Daí segue o boot normal: bloco 0 do drive 1 em $800 e `JMP $801`.
  - Sem a assinatura (banco 0 ainda original), o boot segue direto.
- **FatInit** (uma vez por reset, chamado de ResetDriveIfFirstTime):
  - Cartão FAT = setor 0 terminando em $55 $AA e byte 0 diferente de $01 (o bloco de boot ProDOS começa com $01).
  - Para cada drive montado, relê o setor de diretório gravado e compara os bytes 20–21 e 26–31 da entrada
    (cluster inicial e tamanho), lendo o setor em sequência e acumulando as diferenças com EOR/ORA, sem buffer na RAM.
  - Resultado em **FatFlags = $57F** (bit 7 = cartão FAT; bits 0–3 = drive 1–4 conferido). $57F era o SerialInitDone,
    que só o DEBUG usava. Usa $ED como temporário (salvo e restaurado).
- **Leitura e escrita no modo FAT** (Block2LBA): LBA = início da imagem + bloco, com 28 bits.
  - Bloco ≥ tamanho da imagem → erro $2D, **nada é escrito fora da imagem**.
  - Drive não conferido → $2F (offline).
  - A unidade 127 (bloco cru) continua ignorando o modo FAT.
- **STATUS:** no modo FAT, ProDOS e SmartPort recebem o tamanho da imagem, ou $2F para drive vazio.
  O STATUS da interface (unit 0) informa 4 drives.
- **Tabela de montagem** (banco 4, gravada pelo utilitário), em $CE80 + d×24 para d = 0..3:
  - +0 estado (bit 7 = montado);
  - +1..+4 LBA inicial;
  - +5..+6 blocos;
  - +7..+10 LBA do setor de diretório;
  - +11 índice da entrada;
  - +12..+13 bytes 20–21 da entrada;
  - +14..+19 bytes 26–31 da entrada;
  - +20..+23 livres.

  $CEE0 = 'C' (tabela válida). O código termina em $CE6D; sobram 18 bytes até $CE80.
- **Para caber**, foi retirado o subcódigo SmartPort $49 (IDENTIFY por STATUS, 111 bytes). Nada no IIe usa isso;
  os nossos programas fazem o IDENTIFY direto nos registradores.
- **Simulação** (firmware/sim_fw14_v1.py: py65 + os dois bancos com troca por $C0F4/$C0F5 + CFFA com leitura e escrita): **20 de 20 OK**.
  - Cartão cru: STATUS, leitura, FatFlags = 0.
  - FAT32 com TESTE1.PO no drive 1 e HD32.PO no drive 2: STATUS 1600/65535; leitura e escrita no LBA certo;
    bloco 1600 recusado sem escrever; SmartPort STATUS (4 drives), drive vazio offline, leitura nas unidades 1 e 2.
  - Entrada de diretório alterada (tamanho mudou): drive 1 offline e drive 2 continua.
  - Boot pelo $C700 com um utilitário falso no banco 0: roda em $2003, volta, carrega o bloco 0 da imagem e executa.
  - Boot com o banco 0 original: não chama nada.
  - Cartão cru com tabela antiga na EEPROM: modo clássico.
- **Comparação com o 1.3** (firmware/sim_compara13_14_v1.py), cartão cru de 64 MB:
  - 300 chamadas aleatórias (P8 READ/WRITE/STATUS nos 4 drives, SmartPort READ/STATUS, unidade 127);
  - **0 diferenças**, cartão final idêntico.
- **Gravação no banco 4 preparada:** gravador/grava_banco4_v14_v1_envio.txt, com o CARGA em hex, depois o gravador
  e a imagem em binário (gravador/gravador_v1_pad.bin, idêntico ao gravador_v1.bin). Não enviada: o Apple não respondia às 10:13.
  O banco 0 continua original até o utilitário ficar pronto, então ligar a placa continua seguro.

## Firmware 1.4 v2 na placa e o menu em dois estágios (2026-11-20, v27)
### 1.4 v1 → v2 (erro achado na placa)
- **10:22 – 1.4 v1 gravado no banco 4:** GRAVADOS 068A, FALHAS 0000, DIFERENCAS 0000, SOMA 07F7.
- **Benchmark MLI com o 1.4 v1:** erro $27 imediato. O ProDOS já rodava com outro firmware, que tinha deixado
  DriveResetDone = $A5. O 1.4 pulou o FatInit e usou o lixo de $57F ($A5: bits "FAT" e "drive 1") como FatFlags.
  Somou a tabela vazia ($FF) ao bloco e pediu um setor além do fim do cartão. Só leitura; nada gravado.
- **Correção (spdrv14_v2.s):**
  - INITDONESIG passa a $A4, então a entrada vinda de outro firmware sempre refaz o reset e o FatInit.
  - FatChk = $7FF (Available2 do slot 7) guarda FatFlags EOR $5A. O ResetDriveIfFirstTime refaz tudo se não bater.
  - O FatBoot não zera mais o DriveResetDone depois do utilitário; quem zera é o menu, quando grava.
  - O código termina em $CE7A (sobram 5 bytes).
  - O simulador (sim_fw14_v2.py) ganhou o caso "RAM com restos": o v1 falha nele e o v2 passa. 23/23 OK;
    contra o 1.3: 0 diferenças.
- **10:25 – 1.4 v2 gravado:** GRAVADOS 0422, FALHAS 0000, DIFERENCAS 0000, SOMA 0280 (igual à calculada).
- **Benchmark MLI (256 blocos, ProDOS):**

  | Firmware | Tempo |
  |---|---|
  | 1.4 v2 | 2,66 s, 2,62 s e 2,67 s |
  | Banco 0 original | 3,28 s |

  Igual ao 1.3 (2,60 s).
- rom/: banco4_spdrv14_C700-CEFF_v2.bin (atual) e _v1 (anterior); o 1.3 foi para rom/arquivo/.

### Por que dois estágios
- O utilitário completo (menu + FAT + gravação) deu 2.687 bytes; no banco 0 cabem 1.728 (até os nomes).
- Por isso o banco 0 fica com um **carregador** (estágio 1), e o **menu** vira o arquivo **CFFAMENU.BIN**
  na raiz do cartão FAT (estágio 2).
- Vantagens: o menu pode crescer à vontade, e atualizá-lo é só copiar um arquivo para o cartão.

### Carregador do banco 0: menu/carga_menu_v1.s
- Roda em $2000. Código até $25D5; sobram 234 bytes.
- Procura CFFAMENU.BIN na raiz (FAT16/FAT32, inclusive diretório raiz com vários clusters).
- Carrega em $4000 (até 16 KB) seguindo a cadeia de clusters, confere "CFM1" e chama $4004 com X = $70.
- Sem o arquivo: "CFFA: CFFAMENU.BIN NAO ENCONTRADO", ~1,4 s, e o boot segue com a montagem anterior,
  já conferida pelo driver.
- Imagem do banco 0: rom/banco0_util_C700-CEFF_v1.bin = página $C7 do 1.4 v2 + carregador + nomes em branco em $CEC0. Soma 9FD6.
- **Ainda não gravada.** No banco 0 original, $CEC0–$CEEC está livre (código até $CCB1), então o menu já pode
  gravar os nomes ali, mesmo antes.

### Menu: menu/cffamenu_v1.s → CFFAMENU.BIN
- 2.695 bytes em $4000. Buffers em $8800–$8F57 (o carregador em $2000–$2FFF fica intacto).
- Entradas: $4004 = boot (menu só se houver tecla em ~1,7 s ou nada montado); $4007 = teste (menu sempre).
- **Tela:** os 4 drives e até 16 imagens .PO/.HDV/.IMG (letra, nome 8.3, blocos em hex).
  Teclas: 1–4 escolhe o drive, depois a letra da imagem, ou ESPAÇO para esvaziar; RETURN grava e segue o boot; ESC sai sem gravar.
- **Ao montar:** confere a contiguidade ("CONFERINDO…") e recusa a imagem fragmentada.
- **No boot ("resolve"):** procura cada nome guardado. Se a entrada não mudou, não faz nada (rápido).
  Se mudou, confere de novo e refaz a entrada da tabela. Se o arquivo sumiu, desmonta, mas guarda o nome.
- **Gravação na EEPROM:** só os bytes diferentes. A tabela vai para o banco 4 ($CE80–$CEE0, 'C') e os nomes para o banco 0
  ($CEC0–$CEEC, 'N'). Polling de dados e trava pelo $C0F3. No fim zera DriveResetDone ($47F), para o driver refazer o FatInit.
- Usa RDKEY/COUT, então funciona tanto pelo teclado e tela quanto pela serial com IN#1/PR#1.
  Religa a ROM $C800 da placa antes de ler ou gravar a EEPROM.
- Só slot 7, por enquanto.

### Simulação de ponta a ponta (menu/sim_cffamenu_v1.py e menu/sim_boot_completo_v1.py; precisam do sim_fw14_v2.py)
Todos OK:
- O menu monta TESTE1.PO e HD32.PO (teclas simuladas); a tabela gravada é igual à calculada em Python;
  os nomes ficam no banco 0; DriveResetDone é zerado; 140 bytes gravados.
- Boot pelo $C700 depois disso: o bloco 0 de TESTE1.PO é executado; o drive 2 tem HD32.PO (65535 blocos).
- Entrada de boot sem tecla: 0 bytes gravados.
- TESTE1.PO apagado no "PC": drive 1 desmontado, nome mantido; com o arquivo de volta, monta de novo (1 byte gravado).
- FAT16 sem MBR: FRAG.IMG recusada; TESTE1.PO montada certo.
- **Caminho real completo:** $C700 → trampolim → carregador do banco 0 → CFFAMENU.BIN lido do cartão → menu → gravação → boot da imagem.
- Segundo boot sem tecla: direto, nada gravado.
- Cartão sem CFFAMENU.BIN: aviso e boot com a montagem anterior.

### Envios preparados
- menu/teste_menu_ram_v1_envio.txt: CARGA + CFFAMENU em $4000 (11 blocos) + C0F5 + 4007G. Soma esperada S=85C1.
  Precisa do cartão FAT na CFFA. As teclas do menu vão em seguida, pela ponte.
- menu/grava_banco0_util_v1_envio.txt: grava o carregador no banco 0 (6003:00). Fazer só depois do teste na RAM.
- menu/para_o_cartao/CFFAMENU.BIN: copiar para a raiz do cartão FAT.

## Utilitário do banco 0 (plano original, substituído pelos dois estágios acima)
- Imagem do banco 0: página $C7 = cópia exata da do banco 4.
- Em $C800: "CFU", depois as entradas $2003 (boot: menu com tempo, ou se nada estiver montado) e $2006 (menu sempre, para testes).
  O resto até $CEFF fica para o código e a tabela de nomes.
- **Nomes das imagens montadas** (4 × 11 bytes): guardados no próprio banco 0, no fim, porque não cabem na tabela do banco 4.
  - Copiados para a RAM junto com o utilitário.
  - No boot o utilitário procura cada nome no diretório.
  - Se a entrada estiver igual à da tabela, nada a fazer (rápido, sem refazer a contiguidade).
  - Se o arquivo mudou de lugar, refaz a conferência de contiguidade e regrava a tabela.
  - Se o arquivo sumiu, desmonta, mas guarda o nome para montar de novo quando ele voltar.
- Escrita na EEPROM igual à do gravador: só os bytes diferentes, com `$C0F3` (destrava), polling de dados e `$C0F4/$C0F5`.
- Entrada pelo RDKEY/COUT do monitor: no boot é o teclado e a tela; com IN#1/PR#1 ativo dá para eu operar o menu pela serial.
  Antes de ler ou gravar a ROM, religar a $C800 da placa (o firmware da SSC usa a $C800 dele).

## Carga rápida pela serial e disco de utilitários (2026-11-20, v25)
- **carga_v1 (fat/carga_v1.s, 93 bytes em $0300):** carregador binário com o mesmo protocolo do #sendbin
  (ACK $06 antes de cada bloco de 256 bytes).
  - Parâmetros: $0302 = página inicial, $0303 = número de blocos. Padrão: $60 e 8, ou seja 2 KB em $6000.
  - Monitor: `302:PP NN` e `300G`. BASIC.SYSTEM: `BRUN CARGA`.
  - No fim imprime `S=xxxx`, a soma de 16 bits dos bytes, para conferir.
  - Teste real, 09:57: 2.048 bytes em 1,1 s, S=3B99 (igual ao esperado). O envio completo (carga digitada em hex + FATCAT binário)
    leva ~35 s, contra ~6 min do hex puro. Com a CARGA já na RAM (ou carregada do disco), cada novo teste leva ~3 s.
  - Cuidado no arquivo de envio: depois do #sendbin vem `#pause 2` antes do próximo comando.
    Sem a pausa, o "6" do `6000G` se perdeu enquanto o Apple imprimia S=, o monitor executou `000G` e caiu no BASIC.
    Corrigido em fatcat_rapido_v1_envio.txt.
- **Disco para a BOOTI: disco/cffa_util_v1.po** (140 KB, ordem ProDOS, volume /CFFA.UTIL, não inicializável),
  com FATCAT (BIN, aux $6000) e CARGA (BIN, aux $0300). Gerado por fat/mkdisco_prodos_v1.py, que relê e confere os arquivos.
  - Também disco/FATCAT#066000 e disco/CARGA#060300: nomes no padrão do CiderPress II (tipo e aux no nome),
    para copiar para o volume de boot da BOOTI mantendo tipo e endereço.
  - Uso: `PR#1` (a saída vai para a serial, para eu ler) e depois `BRUN FATCAT`.

## Super Serial a 115200 (pesquisa de 2026-11-20)
- O 6551 tem o modo "relógio externo 16x" (bits 0–3 do registrador de controle = 0000). Na SSC esse pino recebe o próprio cristal
  de 1,8432 MHz → 1,8432 MHz / 16 = **115200 bps sem modificação**. É assim que o ADTPro faz (e o cc65 e o AppleWin usam o valor $00 para 115200).
- Slot 1: controle = $C09B; dados = $C098; status = $C099; comando = $C09A.
- Limite prático: a 1 MHz sobram ~89 ciclos por byte. Só laços próprios, em polling e sem COUT, acompanham.
  O monitor e o PR#1/IN#1 continuam a 19200 (chaves).
- Uso planejado: carregador de imagens pela serial e gravador, mudando para 115200 só durante a transferência e voltando a 19200 no fim.
  A ponte troca de velocidade (set_baud). Volume de 32 MB: ~5 h a 19200 contra ~50 min a 115200.

## Pendências anotadas (2026-11-20)
- Programa "exercitador" de leituras e escritas, para testar o circuito (pedido do usuário; depois do menu).
- Teste de gravação de dados no cartão com o firmware 1.3. Conferir o pull-up de A14 quando houver extensor de slot.


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

## Banco 0 gravado (2026-11-20 10:36)
- GRAVADOS 06CC, FALHAS 0000, DIFERENCAS 0000, SOMA 9FD6 (igual à calculada). Ao ligar, a placa já roda a página $C7 do 1.4 e o carregador.
- No monitor, `C800.C802` mostrou `20 9B C9`, e não "CFU": com o PR#1 ativo, a área $C800 era a ROM da Super Serial. Não é erro.
- Recuperação, se precisar: tirar o jumper A13 do J6 (liga no banco 2, o driver original de 8 partições) ou regravar no BeeProg.

## Primeiro teste real do modo FAT (2026-11-20 10:40)
- Cartão FAT com CFFAMENU.BIN e imagens .PO: o menu, a montagem e o boot pela imagem funcionaram de primeira (relato do usuário).

## Menu v2: nomes longos, molduras e páginas (2026-11-20 14:27, v28)
- menu/cffamenu_v2.s → menu/cffamenu_v2.bin (3.781 bytes). A cópia para o cartão é menu/para_o_cartao/CFFAMENU.BIN
  (agora v2; a v1 continua em menu/cffamenu_v1.bin). O banco 0 não muda: basta copiar o arquivo para a raiz do cartão.
- **Nomes longos (VFAT)**:
  - junta os pedaços (atributo $0F, 13 caracteres UTF-16 cada) e confere a soma do nome curto;
  - mostra até 29 caracteres; acentos e caracteres fora do ASCII viram "?";
  - sem nome longo, mostra o 8.3 ("TESTE.PO");
  - a EEPROM continua guardando o nome curto (11 bytes), que serve para reencontrar a imagem.
- **Até 64 imagens.** Memória do menu:
  - $6000 nomes longos (64 × 32);
  - $6800 lista (64 × 24);
  - $6E00 tabela nova;
  - $6E80 nomes;
  - $6F00 nome longo em montagem;
  - $6F40 mensagem;
  - buffers continuam em $8800.
- **Tela no estilo do Locksmith 6.0**, escrita direto na memória de vídeo:
  - título em inverso;
  - moldura de cima: os 4 drives, com nome e tamanho;
  - moldura de baixo: as imagens, 11 por página, com a barra de seleção em inverso;
  - linha de ajuda e linha de mensagens.
- **Teclas:**
  - ↑ ↓ movem a barra; ← → mudam de página;
  - 1–4 montam a imagem marcada no drive (a linha "(NENHUMA)" esvazia o drive);
  - RETURN grava e dá o boot; ESC sai sem gravar.
- **Drives na moldura de cima:**
  - "FRAG." = o nome está guardado, mas a imagem está fragmentada;
  - "AUSENTE" = o arquivo não está no cartão.
- No boot com imagens montadas, a mesma tela aparece por ~1,7 s com "QUALQUER TECLA ABRE O MENU".
- **Limitação:** na barra inversa as minúsculas aparecem em maiúsculas, porque o conjunto de caracteres principal não tem inverso minúsculo.
  O IIe Enhanced poderia usar MouseText e o conjunto alternativo (inverso minúsculo e molduras de linha), mas isso
  deixaria de funcionar no II Plus.
- **Simulação** (menu/sim_cffamenu_v2.py e menu/sim_boot_completo_v2.py), num cartão FAT32 com 30 imagens de nome longo:
  - telas conferidas;
  - montagem nos drives 1 e 2 em páginas diferentes;
  - esvaziar pelo "(NENHUMA)";
  - tabela igual à calculada em Python;
  - caminho completo $C700 → carregador → CFFAMENU v2 → menu → boot da imagem escolhida;
  - segundo boot direto, sem gravar nada.

  Erros corrigidos na simulação: a variável do drive era apagada pelo redesenho (agora MDRV); o título cortava o "32";
  apareciam dois pontos nos nomes 8.3.
- Imagem da tela: menu/tela_cffamenu_v2.png.

## Pedidos anotados (2026-11-20 tarde)
- **Segundo cartão (drive escravo):** o driver hoje só fala com o mestre ($E0 no registrador Head).
  - Suporte ao escravo ($F0): adaptador de 2 cartões CF, ou CF + adaptador SD/CF→IDE no conector de 40 pinos.
  - Permitiria copiar imagens e arquivos de um cartão para o outro.
- **Cartões SD:** por adaptador SD→CF ou SD→IDE (sem mudar a placa; testar a compatibilidade).
  SD nativo (SPI) não é viável na 1.2, porque o CPLD não tem acesso ao barramento de dados.
- **Wi-Fi:**
  - ESP como modem Hayes na Super Serial (simples);
  - ou um RP2040 W imitando um disco ATA no conector IDE (projeto grande).

## Menu v3: sem piscar (2026-11-20 14:35, v29)
- menu/cffamenu_v3.s → cffamenu_v3.bin (3.802 bytes). menu/para_o_cartao/CFFAMENU.BIN agora é a v3.
- A tela só é apagada ao abrir o menu (rotina cls). Depois disso, cada tecla redesenha escrevendo por cima,
  porque toda linha é escrita inteira. As linhas 22 e 23 são completadas com espaços.
- Medido no simulador: cada seta muda 72 caracteres na tela (as duas linhas da barra), contra 1.030 na v2.
- Testes funcionais da v2 repetidos com a v3 (sim_cffamenu_v3.py): tudo OK.
