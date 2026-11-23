# CFFA 1.5 — novo software para as CFFA 1.2, 1.3 e 1.4

**Tabajara Labs — 2026** · [tabalabs.com.br](https://tabalabs.com.br)

Novo firmware, menu de boot e imagens de disco em cartão FAT para a **CFFA** (CompactFlash for Apple II, de Rich Dreher),
placas 1.2, 1.3 e 1.4, com a EPROM 27C256 trocada por uma **EEPROM 28C256** gravável no próprio Apple e uma lógica nova no CPLD.

A documentação completa, com todo o histórico de desenvolvimento, medições e decisões, está no **[LEIA-ME_v37.md](LEIA-ME_v37.md)**
(também em [PDF](LEIA-ME_v37.pdf)).

## O que a placa ganha

- **Imagens ProDOS num cartão FAT16/FAT32** (`.PO`, `.HDV`, `.IMG`), montadas como drives 1 a 4. Basta copiar as imagens no PC.
  Os volumes ProDOS crus (modo clássico) continuam funcionando.
- **Menu de boot** (CFFAMENU.BIN, no cartão):
  - nomes longos, subpastas, páginas e salto pela inicial;
  - molduras em MouseText no IIe;
  - dois cartões (mestre e escravo);
  - proteção contra escrita por drive;
  - tempo de espera configurável com contagem regressiva;
  - boot pelo drive 2;
  - ajuda completa na tecla H.
- **Firmware 1.5** (driver ProDOS no banco 4 da EEPROM): escrita mais rápida, proteção contra escrita e suporte ao cartão escravo.
- **Gravador da EEPROM pelo próprio Apple** (gravador_v2), sem tirar o chip.
  Também gera uma imagem de 32 KB pronta para um gravador de chips.
- **Transferência de imagens pela Super Serial a 115200 bps** (serimg): backup do cartão para o PC e gravação de imagens do PC para o cartão.
- **Conversor de imagens** DSK/DO/2MG → PO (ferramentas/converte_imagem_v1.py).

Tudo foi **simulado antes de ir para a placa**: há simuladores em Python, com 65C02, CFFA, cartão FAT e Super Serial emulados.

## Organização

| Pasta | Conteúdo |
|---|---|
| `firmware/` | drivers ProDOS 1.3 (original desmontado), 1.4 e 1.5; simuladores e comparadores |
| `menu/` | carregador do banco 0 e menu CFFAMENU (v1…v11); `para_o_cartao/CFFAMENU.BIN` é a versão atual |
| `rom/` | imagens dos bancos 0 e 4 e a EEPROM inteira de 32 KB (`CFFA_EEPROM_32K_fw15_v1.bin`) |
| `gravador/` | gravador da EEPROM que roda no Apple |
| `cpld/` | lógica nova do CPLD EPM7064 (projetos Quartus II 13.0) |
| `fat/` | protótipos de leitura de FAT (fatcat) e carregador rápido |
| `serial/` | serimg (transferência de imagens) e o gerador de envios |
| `ferramentas/` | conversor de imagens |
| `disco/` | disco de utilitários ProDOS |
| `testes/` | programas de teste da placa e resultados de bancada |
| `osc/` | capturas do osciloscópio |
| `original/` | material original do Rich Dreher: firmware 1.3, lógica 1.4, esquemas e o "3 jumper fix" |
| `Placa tabajara labs/` | esquema da CFFA Lite, a versão miniatura da Tabajara Labs |
| `arquivo/` | versões antigas do LEIA-ME |

## Instalação rápida

1. Grave `rom/CFFA_EEPROM_32K_fw15_v1.bin` numa 28C256 (ou use o gravador no próprio Apple) e instale-a com o adaptador
   descrito no LEIA-ME. O CPLD precisa da lógica nova (`cpld/`).
2. Formate um cartão em FAT16 ou FAT32 e copie para a raiz `menu/para_o_cartao/CFFAMENU.BIN` e as suas imagens `.PO`/`.HDV`.
   As imagens precisam estar contíguas; num cartão recém-formatado, ficam.
3. Dê boot pelo slot da CFFA. O menu aparece; monte as imagens com as teclas 1–4, tecle RETURN para dar boot e H para ver a ajuda.

## Créditos

- **CFFA** (hardware, firmware 1.3 e lógica 1.4 originais): Rich Dreher. O material dele está em `original/` como referência.
- Firmware 1.4/1.5, menu, carregador, gravador, serimg, lógica nova e ferramentas: Tabajara Labs, 2026,
  desenvolvidos com a ajuda do Claude (Anthropic).
