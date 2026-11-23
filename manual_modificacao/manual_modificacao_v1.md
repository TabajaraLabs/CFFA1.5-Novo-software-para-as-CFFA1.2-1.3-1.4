# Manual de modificação: CFFA 1.2 → CFFA 1.5

**Tabajara Labs — v1, 23/11/2026**

Este manual ensina a transformar uma **CFFA v1.2** (CompactFlash for Apple II, de Rich Dreher) em **CFFA 1.5**. Com a modificação, a placa ganha:

- imagens ProDOS (`.PO`, `.HDV`, `.IMG`) num cartão **FAT16/FAT32**, montadas como drives 1 a 4;
- **menu de boot** com nomes longos, subpastas, proteção contra escrita, tempo de espera, boot pelo drive 2 e ajuda na tecla H;
- **firmware 1.5**, com escrita mais rápida;
- **EEPROM gravável no próprio Apple**, para atualizar o firmware sem tirar o chip da placa.

As placas 1.3 e 1.4 do Rich usam o mesmo circuito e a mesma lógica de CPLD. O procedimento deve valer para elas, mas foi testado só na 1.2.

## 1. Arquivos desta pasta

| Arquivo | O que é | Onde vai |
|---|---|---|
| `CFFA_EEPROM_32K_fw15_v1.bin` | imagem completa da EEPROM (32 KB, 8 bancos) | EEPROM X28C256 (gravador de chips) |
| `cffa12_v161.pof` | lógica 1.6.1 do CPLD | CPLD EPM7064SLC44, pelo JTAG (Quartus II) |
| `CFFAMENU.BIN` | menu de boot (v11) | raiz do cartão CF formatado em FAT |
| `manual_modificacao_v1.pdf` | este manual | — |

Os fontes de tudo (firmware, lógica do CPLD, menu e ferramentas) estão no repositório do projeto. O `LEIA-ME` dele conta todo o desenvolvimento.

## 2. Requisitos e material

- **Apple com processador 65C02**: IIe Enhanced, ou um II Plus / IIe antigo com o 65C02 trocado. O firmware 1.5 e o menu usam instruções do 65C02. O driver 6502 original da placa foi substituído pelo firmware novo.
- **EEPROM X28C256** (ou outra 28C256 de 32 KB) no lugar da EPROM 27C256 original. Guarde a EPROM original.
- **Dois soquetes torneados de 28 pinos**, para fazer o adaptador.
- **Dois resistores:** 10 kΩ (pull-up do A14) e 33 kΩ (pull-up do /WE; qualquer valor de 10 k a 33 k serve).
- **Fio fino** (wire-wrap ou 30 AWG), de três cores para não confundir.
- **Gravador de chips** (BeeProg, TL866 etc.) para a primeira gravação da EEPROM.
- **Cabo JTAG** (USB-Blaster ou ByteBlaster) e o **Quartus II 13.0sp1**, que é a última versão com a família MAX 7000S.
- Cartão CompactFlash formatado em **FAT16 ou FAT32**.

## 3. Por que a EEPROM precisa de um adaptador

A 28C256 é quase igual à 27C256, mas três pinos mudam de função:

| Pino | 27C256 (EPROM original) | 28C256 (EEPROM) | Na CFFA 1.5 vai para |
|---|---|---|---|
| 1 | VPP (tensão de gravação; na placa, ligado ao VCC) | **A14** (endereço) | CPLD pino **27** (BK14), com pull-up de 10 kΩ |
| 22 | /OE (habilita a saída) | /OE | CPLD pino **26** (NOT_RW) |
| 27 | **A14** (endereço; na placa vem do jumper A14) | **/WE** (habilita a escrita) | CPLD pino **8** (nWE), com pull-up de 33 kΩ |

- **Pino 1:** o A14 passa a ser comandado pelo CPLD. É isso que troca o banco da EEPROM por software (bancos 0 e 4).
- **Pino 27:** a EEPROM só grava quando o CPLD manda, e só depois de destravada por software.
- **Pino 22:** na placa original o /OE fica sempre ativo. Ligado ao NOT_RW, ele desliga as saídas da EEPROM durante uma escrita; sem isso, a EEPROM e o Apple brigariam pelo barramento de dados.

## 4. Passo a passo

### Passo 1 — Gravar a lógica nova no CPLD

1. Com o Apple **desligado**, tire a placa do slot. Ligue o cabo JTAG no conector **J7** da CFFA.
2. Alimente a placa para a gravação. O jeito mais simples é recolocá-la no Apple e ligar o Apple, com o cabo JTAG já conectado. O CPLD não precisa estar funcionando para ser gravado.
3. No Quartus II 13.0: **Tools → Programmer**. Em **Hardware Setup** escolha o cabo. Clique em **Add File…** e escolha `cffa12_v161.pof`. Marque **Program/Configure** e **Verify**, e clique em **Start**.
4. Espere o **100% (Successful)**.

> **Use exatamente este .pof.** Ele foi compilado com o *Turbo Bit* desligado em todas as macrocélulas, como a lógica 1.4 original do Rich. Recompilado com as opções padrão do Quartus, o turbo fica ligado e a placa **falha no boot** em cerca de 20% das vezes (problema de temporização; veja o LEIA-ME do projeto).

A lógica 1.6.1 é compatível com a 1.4. Com a EPROM original ainda na placa, ela tem que funcionar exatamente como antes, e esse é um bom teste intermediário.

### Passo 2 — Gravar a EEPROM

1. No gravador de chips, escolha **X28C256** (ou o modelo exato da sua 28C256).
2. Carregue `CFFA_EEPROM_32K_fw15_v1.bin` (32.768 bytes, soma 74A7). Grave e verifique.
3. **Não** ligue a proteção de escrita por software (*SDP / Software Data Protection*). Se o gravador tiver essa opção, deixe-a **desligada**; senão o Apple não consegue mais atualizar o firmware.

Conteúdo dos 8 bancos de 4 KB:

| Banco | Conteúdo |
|---|---|
| 0 | **CFFA 1.5: carregador do menu** (lê o `CFFAMENU.BIN` do cartão) e os nomes das imagens montadas |
| 1 | original do Rich: driver 65C02 v1.2, 4 partições, versão DEBUG (saída serial na SSC do slot 2) |
| 2 | original do Rich: driver 65C02 v1.2, 8 partições |
| 3 | original do Rich: driver 65C02 v1.2, 8 partições, DEBUG |
| 4 | **CFFA 1.5: driver ProDOS/SmartPort 1.5** e a tabela de imagens montadas |
| 5 | original do Rich: driver 6502 v1.0, DEBUG |
| 6, 7 | vazios |

### Passo 3 — Montar o adaptador da EEPROM

Empilhe os dois soquetes torneados. O de **baixo** entra no soquete da placa; a EEPROM vai no de **cima**. No soquete de **cima**, dobre para fora os pinos **1, 22 e 27**, para que eles **não** entrem no soquete de baixo. Os outros 25 pinos passam direto.

<figure>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-140 0 1200 520" width="100%" font-family="Helvetica,Arial,sans-serif" font-size="16">
<rect x="300" y="60" width="140" height="420" rx="6" fill="#222" stroke="#000"/>
<path d="M356.0,60 a14,14 0 0,0 28,0" fill="#fff" stroke="#000"/>
<text x="370.0" y="380" fill="#fff" text-anchor="middle" font-size="16" font-weight="bold">X28C256</text>
<text x="370.0" y="400" fill="#ccc" text-anchor="middle">vista de cima</text>
<line x1="300" y1="75.0" x2="240" y2="75.0" stroke="#e67e22" stroke-width="5"/>
<text x="308" y="79.0" fill="#fff">1 A14</text>
<rect x="440" y="70.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="79.0" fill="#fff" text-anchor="end">VCC 28</text>
<rect x="286" y="100.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="109.0" fill="#fff">2 </text>
<line x1="440" y1="105.0" x2="500" y2="105.0" stroke="#8e5a2b" stroke-width="5"/>
<text x="432" y="109.0" fill="#fff" text-anchor="end">/WE 27</text>
<rect x="286" y="130.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="139.0" fill="#fff">3 </text>
<rect x="440" y="130.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="139.0" fill="#fff" text-anchor="end"> 26</text>
<rect x="286" y="160.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="169.0" fill="#fff">4 </text>
<rect x="440" y="160.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="169.0" fill="#fff" text-anchor="end"> 25</text>
<rect x="286" y="190.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="199.0" fill="#fff">5 </text>
<rect x="440" y="190.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="199.0" fill="#fff" text-anchor="end"> 24</text>
<rect x="286" y="220.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="229.0" fill="#fff">6 </text>
<rect x="440" y="220.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="229.0" fill="#fff" text-anchor="end"> 23</text>
<rect x="286" y="250.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="259.0" fill="#fff">7 </text>
<line x1="440" y1="255.0" x2="500" y2="255.0" stroke="#111" stroke-width="5"/>
<text x="432" y="259.0" fill="#fff" text-anchor="end">/OE 22</text>
<rect x="286" y="280.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="289.0" fill="#fff">8 </text>
<rect x="440" y="280.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="289.0" fill="#fff" text-anchor="end"> 21</text>
<rect x="286" y="310.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="319.0" fill="#fff">9 </text>
<rect x="440" y="310.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="319.0" fill="#fff" text-anchor="end">/CE 20</text>
<rect x="286" y="340.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="349.0" fill="#fff">10 </text>
<rect x="440" y="340.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="349.0" fill="#fff" text-anchor="end"> 19</text>
<rect x="286" y="370.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="379.0" fill="#fff">11 </text>
<rect x="440" y="370.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="379.0" fill="#fff" text-anchor="end"> 18</text>
<rect x="286" y="400.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="409.0" fill="#fff">12 </text>
<rect x="440" y="400.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="409.0" fill="#fff" text-anchor="end"> 17</text>
<rect x="286" y="430.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="439.0" fill="#fff">13 </text>
<rect x="440" y="430.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="439.0" fill="#fff" text-anchor="end"> 16</text>
<rect x="286" y="460.0" width="14" height="10" fill="#bbb"/>
<text x="308" y="469.0" fill="#fff">14 GND</text>
<rect x="440" y="460.0" width="14" height="10" fill="#bbb"/>
<text x="432" y="469.0" fill="#fff" text-anchor="end"> 15</text>
<line x1="240" y1="75.0" x2="240" y2="45.0" stroke="#e67e22" stroke-width="3"/>
<text x="230" y="39.0" text-anchor="end" fill="#b35900" font-weight="bold">pino 1 (A14) dobrado → CPLD pino 27</text>
<text x="230" y="79.0" text-anchor="end" fill="#b35900">+ resistor 10k do pino 1 ao 28</text>
<text x="508" y="109.0" text-anchor="start" fill="#6b3f17" font-weight="bold">pino 27 (/WE) dobrado → CPLD pino 8 (nWE)</text>
<text x="508" y="125.0" text-anchor="start" fill="#6b3f17">+ resistor 33k (10k–33k) do pino 27 ao pino 28</text>
<text x="508" y="259.0" text-anchor="start" fill="#000" font-weight="bold">pino 22 (/OE) dobrado → CPLD pino 26 (NOT_RW)</text>
<text x="508" y="275.0" text-anchor="start" fill="#333">(o mesmo sinal do U2 pino 1)</text>
<text x="460" y="510" text-anchor="middle" fill="#333">Os demais 25 pinos entram no soquete da placa normalmente. Os furos 1, 22 e 27 do soquete da placa ficam vazios.</text>
</svg>
<figcaption>Adaptador visto de cima: os três pinos dobrados e para onde vão.</figcaption>
</figure>

Ligações:

| De (soquete de cima / EEPROM) | Para | Cor usada no protótipo |
|---|---|---|
| pino **1** (A14) | CPLD pino **27** | laranja |
| pino **1** (A14) | resistor de **10 kΩ** → pino **28** (VCC) | — |
| pino **22** (/OE) | CPLD pino **26** (o mesmo sinal do pino 1 do U2) | preto |
| pino **27** (/WE) | CPLD pino **8** | marrom |
| pino **27** (/WE) | resistor de **33 kΩ** → pino **28** (VCC) | — |

Os furos **1, 22 e 27 do soquete de baixo** ficam sem ligação.

**Cuidados importantes:**

- **A CFFA 1.2 não tem pull-up na linha A14.** O resistor de 10 kΩ do pino 1 ao pino 28 é obrigatório. **Não** coloque resistor em série no fio do A14: no protótipo, um de 470 Ω deixava a linha em 1,6 V.
- **Contagem dos pinos do CPLD (PLCC-44).** O pino 1 fica no meio do lado de cima, marcado com um ponto, e a contagem segue no sentido **anti-horário visto de cima**: o pino 8 fica no lado esquerdo, o segundo de cima para baixo; os pinos 26 e 27 ficam no lado de baixo, perto do canto direito. **Pelo lado da solda a contagem fica espelhada.** No protótipo, os primeiros fios caíram em pinos de endereço por causa disso. **Confira cada fio com o multímetro** (continuidade até a perna do CPLD) antes de ligar a placa.
- Os pinos 8 e 27 do CPLD **não têm ligação na placa original** (ficam livres na lógica 1.4); o pino 26 já existe e é o NOT_RW. Confira, sem alimentação, que os pinos 8 e 27 não estão ligados a nada.
- O **3 jumper fix** (A0–A2 do cartão vindos do CPLD) é **opcional**. A lógica 1.6.1 suporta o fix, mas funciona igual sem ele; a placa do protótipo não tem o fix.

### Passo 4 — Jumpers (J6)

Na CFFA original, os três jumpers do J6 escolhem qual dos 8 bancos da EPROM a placa usa (**IN** = jumper colocado = 0; **OUT** = sem jumper = 1). Na 1.5, o **A14 passa a ser comandado pelo CPLD**, e o jumper A14 perde o efeito: o furo 27 do soquete, que ele alimentava, ficou vazio. O A13 e o A12 continuam valendo. O jumper A14 pode ficar colocado ou não.

| A13 | A12 | Banco | O que a placa faz |
|:-:|:-:|:-:|-----------------------------------------------------|
| **IN** | **IN** | 0 (e 4) | **CFFA 1.5** — menu, imagens FAT, firmware 1.5. **Posição normal.** |
| IN | OUT | 1 | firmware original do Rich, 65C02 v1.2, 4 partições, DEBUG (manda mensagens à SSC do slot 2) |
| OUT | IN | 2 | firmware original do Rich, 65C02 v1.2, **8 partições** (cartão cru, sem FAT) |
| OUT | OUT | 3 | firmware original do Rich, 8 partições, DEBUG |

- **Saída de emergência:** se algo der errado com o firmware novo, tire o jumper **A13** (A13 OUT, A12 IN). A placa passa a dar boot com o **firmware original** de 8 partições, que nunca é regravado.
- A troca entre os bancos 0 e 4 é feita pelo próprio firmware, pelos registradores do CPLD. Para o slot 7: **$C0F4** = banco 0, **$C0F5** = banco 4, **$C0F3** escrita = destrava a gravação, leitura = trava. Em outros slots o endereço é $C0n3–$C0n5, com n = 8 + slot.
- Na partida o CPLD começa no banco 0 (A14 = 0).

### Passo 5 — Preparar o cartão CF

1. Formate o cartão em **FAT16 ou FAT32** no PC.
2. Copie `CFFAMENU.BIN` para a **raiz** do cartão.
3. Copie as imagens ProDOS (`.PO`, `.HDV`, `.IMG`). Para imagens `.DSK`, `.DO` ou `.2MG`, converta antes com `ferramentas/converte_imagem_v1.py` do repositório.
   - As imagens precisam estar **contíguas** (sem fragmentação). Num cartão recém-formatado, copiando tudo de uma vez, ficam. Uma imagem fragmentada aparece no menu marcada como **FRAG.**
   - Até 64 itens por pasta; subpastas e nomes longos são aceitos.

### Passo 6 — Primeiro boot e testes

1. Coloque a placa no slot (o protótipo usa o **slot 7**) e o cartão, e ligue o Apple.
2. Na primeira vez, sem nada montado, aparece direto o **menu**. Monte uma imagem: barra em cima dela e tecla **1**. Tecle **RETURN**: o menu grava a escolha na EEPROM e dá o boot.
3. Nos boots seguintes, o menu conta alguns segundos e dá o boot sozinho. **Qualquer tecla** durante a contagem abre o menu. No IIe, segurar a **maçã aberta** também abre.
4. Tecla **H** no menu: ajuda completa, com todos os comandos.

Teclas principais: **1–4** montam a imagem da barra no drive; **SHIFT 1–4** protegem/liberam o drive contra escrita; **CTRL-B** escolhe o boot pelo drive 1 ou 2; **+ / −** ajustam a espera do boot (0 a 30 s); **ESC** sai sem gravar.

## 5. Problemas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| Boot falha de vez em quando (trava, BRK) | CPLD recompilado com o Turbo Bit ligado | gravar exatamente o `cffa12_v161.pof` desta pasta |
| Boot sempre falha ou ROM lida errada | fio do A14 no pino errado do CPLD, ou falta do pull-up de 10 kΩ | conferir cada fio com o multímetro, sem alimentação, e o resistor de 10 kΩ entre os pinos 1 e 28 da EEPROM |
| "CFFA: CARTAO NAO E FAT16/FAT32" e o boot segue pela última imagem | menu antigo (v10 ou anterior) com lixo na RAM | usar o `CFFAMENU.BIN` v11 desta pasta |
| Menu não aparece, boot direto | espera do boot = 0 | segurar a maçã aberta (IIe) ou apertar uma tecla durante o boot |
| A gravação de configurações não "pega" | proteção SDP ligada na EEPROM, ou fio do /WE solto | regravar a EEPROM com o SDP desligado; conferir o pino 27 → CPLD 8 |
| Quero voltar ao original | — | A13 OUT (firmware original de 8 partições), ou recolocar a EPROM original |

## 6. Atualizações futuras

Depois da modificação, o firmware pode ser atualizado **pelo próprio Apple**, pela Super Serial, com o `gravador_v2` do repositório. Ele preserva a tabela de imagens montadas e as configurações. O menu é atualizado só copiando um novo `CFFAMENU.BIN` para o cartão.

---
CFFA original (hardware, firmware 1.3 e lógica 1.4): **Rich Dreher**. CFFA 1.5: **Tabajara Labs** (tabalabs.com.br), 2026.
