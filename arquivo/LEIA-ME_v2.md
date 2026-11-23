# CFFA v1.2 (Rich Dreher) — análise da ROM e do hardware — v2

Pasta do projeto: Documents/Claude/CFFA
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

## Ambiente do usuário (2026-11-20)
- Apple IIe + Super Serial Card; cabo JTAG disponível; programador BeeProg+; CF de 64 MB em uso (tem vários tamanhos).
- CF de 64 MB = 2 volumes ProDOS (o 1º com 32 MB, o 2º com o resto). Só a partir de ~128 MB se usam as 4 partições.
- Placa SEM o 3 jumper fix. Versão da lógica do CPLD ainda a confirmar (ler via JTAG: Security Bit = OFF, dá para ler de volta).

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

## Ideias (detalhadas na conversa de 2026-11-20)
1. Sem mexer na ROM: utilitários em RAM (info do cartão, editor de setores, troca de volumes além dos 128 MB, benchmark), usando os recursos escondidos ou acessando $C0n8.. direto.
2. Nova EPROM aproveitando bancos 6 e 7 (sem perder os originais): laço de leitura/escrita mais rápido (~25–30%), boot por qualquer partição, seletor de "banco de volumes", stub carregador de utilitário a partir de blocos reservados no CF (BLOCKOFFSET), 6502 com IDENTIFY/raw, suporte a slave no conector IDE.
3. CPLD via JTAG: registrador novo em $C0n3; /WE para EEPROM 28C256 num adaptador (gravação na própria placa); troca de banco por software (precisa de mais um pino).
4. Outros usos: driver Apple /// (a3DriverDepot), driver CP/M para Appli-Card (sourceforge cffaapplicard), MAME para testar antes de gravar.
