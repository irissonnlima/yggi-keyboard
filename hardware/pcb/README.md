# Placas de circuito do Yggi (rev0)

![Prévia das placas](preview.svg)

Cada mão usa **5 placas em cadeia**:

```
placa L  ──►  coluna 1u  ──►  coluna 1u  ──►  coluna 1u  ──►  coluna 2u
(MCU)         (mindinho)      (anelar)        (médio)         (indicador)
```

São **6 projetos** no total, 3 por mão:

| Placa | Esquerda | Direita |
|---|---|---|
| **Placa L** (bloco fixo + barra do polegar, fixa, com o MCU) | esc, Yggi, `` ` ``, tab, caps e shift de 2u; barra com fn, ⌃, ⌥, ⌘, ⌫ e espaço | 8 teclas de 1u (F12, lock, `-`, `=`, `[`, `]`, `'`, `\`) e shift de 2u; barra com espaço, return, ⌘ e 4 setas de meia altura |
| **Coluna 1u** (×3 por mão, **idênticas**) | `coluna_1u` | `coluna_1u_dir` |
| **Coluna 2u** (indicador, fim da cadeia) | `coluna_2u` | `coluna_2u_dir` |

As placas das colunas da direita são as da esquerda com a posição espelhada: a entrada do jumper fica do lado direito. Os switches não são espelhados.

Cada tecla Choc tem um **LED RGB** (SK6812MINI-E). As **setas** da mão direita têm meia altura e o Choc não cabe nelas, então usam uma **chave tátil SMD** (XKB TS-1187A, 5,1 × 5,1 mm) sob um keycap de 0,5u. As setas não têm LED.

As placas saem em duas etapas:
1. O [Ergogen](https://ergogen.xyz) posiciona switches, diodos e pads a partir de [`ergogen/generate.py`](ergogen/generate.py).
2. O [`route.py`](route.py) termina cada placa no KiCad: diodos SOD-123, LEDs RGB, setas táteis, regras da JLCPCB, trilhas pelo [Freerouting](https://github.com/freerouting/freerouting) e DRC.

Os resultados ficam versionados:

| Arquivo | O que é |
|---|---|
| [`kicad/*.kicad_pcb`](kicad/) | as 6 placas roteadas para o KiCad 10, com DRC limpo (0 violações, 0 ligações faltando) |
| [`kicad/teclado_*.kicad_pcb`](kicad/) | **só para ver**: as 10 placas do teclado juntas, na posição do CAD (`teclado_150`: stagger 150%; `teclado_0`: ortho), afastadas para ver onde cada uma acaba. Os jumpers aparecem como linhas de ligação. Gerado por [`assemble.py`](assemble.py) |
| [`kicad/*.kicad_pro`, `*.kicad_dru`](kicad/) | regras de projeto: trilha 0,25, isolamento 0,2, via 0,6/0,3, borda 0,5 mm (0,2 mm só nos pads do LED RGB, que ficam junto do próprio recorte) |
| [`outlines/*.dxf`](outlines/) | contornos de corte, os mesmos usados no CAD |
| [`preview.svg`](preview.svg) | a prévia acima (`python3 hardware/tools/pcb_preview.py`) |

## A ligação em cadeia

Cada placa se liga à vizinha por um **jumper flexível de 13 vias**, que atravessa as paredes das colunas na **faixa livre entre a fileira F e a dos números** (y = 87,25 mm no CAD). É o único corredor sem switches ao longo de toda a coluna.

As colunas vizinhas andam uma em relação à outra quando o stagger muda. Com o perfil padrão em 150%, a diferença é:

| Ligação | Movimento relativo |
|---|---|
| placa L → mindinho | 0 mm |
| mindinho → anelar | 9 mm |
| anelar → médio | 6 mm |
| médio → indicador | 6 mm |

O jumper e os rasgos nas paredes foram dimensionados para **até 15 mm**, então qualquer perfil de placa-came funciona.

- **Protótipo:** 13 fios de silicone 30 AWG, soldados nos pads.
- **Produto:** jumper em placa flexível (FPC) de pé, com 1,6 mm de altura, dobrado em S.

### Barramento rotativo: por que as 3 placas de 1u são iguais

Os dois blocos de pads têm 2 × 7 posições (passo 1,27 mm), na mesma ordem. Dois blocos lado a lado não cabem na coluna de 17,4 mm. Por isso o **J_IN** (entrada) fica 1,6 mm mais para trás e à esquerda, e o **J_OUT** (saída) 1,6 mm mais para a frente e à direita. O jumper liga o J_OUT de uma placa ao J_IN da seguinte, 10,82 mm ao lado. Na mão direita, é o espelho.

| Posição | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| **J_IN**, linha de cima | R0 | R1 | R2 | R3 | R4 | VLED | GND |
| **J_IN**, linha de baixo | C1 | C2 | C3 | C4 | C5 | — | DIN |
| **J_OUT**, linha de cima | R0 | R1 | R2 | R3 | R4 | VLED | GND |
| **J_OUT**, linha de baixo | C2 | C3 | C4 | C5 | — | — | DOUT |

Cada placa **usa a coluna C1** e repassa as outras deslocadas uma posição. Na placa seguinte, o que era C2 chega como C1, e assim por diante. Por isso a mesma placa serve em qualquer posição da cadeia. A coluna 2u usa C1 e C2 e não tem saída.

Os **dados dos LEDs** entram em DIN, passam pelos LEDs da placa, um depois do outro, e saem em DOUT, na mesma posição do bloco seguinte. VLED e GND passam direto.

### Matriz (uma mão)

**6 linhas × 7 colunas = 13 pinos do MCU**, mais 1 para os LEDs RGB e, na esquerda, 3 para os LEDs da tecla Yggi.

| Linha | Esquerda | Direita |
|---|---|---|
| R0 | fileira F | fileira F |
| R1 | números (inclui a tecla Yggi) | números |
| R2, R3, R4 | letras (tab, caps e shift de 2u em COL0) | letras (shift de 2u em COL0) |
| R5 | barra do polegar (toda na placa L) | barra: espaço COL6, return COL5, ⌘ COL4, ← COL3, ↑ COL2, ↓ COL1, → COL0 |

| Coluna | Onde fica |
|---|---|
| COL0, COL1 | bloco fixo, na placa L |
| COL2 | 1ª placa de 1u (mindinho) |
| COL3 | 2ª placa de 1u (anelar) |
| COL4 | 3ª placa de 1u (médio) |
| COL5, COL6 | placa 2u (indicador) |

Diodos no sentido **COL2ROW**, o padrão do ZMK: coluna → switch → diodo → linha.

### Posição das peças em cada tecla Choc

| Peça | Onde | Face |
|---|---|---|
| LED RGB SK6812MINI-E | 4,7 mm ao sul do centro, na janela do LED do Choc V1, brilhando por um recorte na placa | baixo (montagem invertida) |
| Diodo 1N4148W (SOD-123) | canto noroeste, 3,6 mm à esquerda e 4,5 mm ao norte, na vertical | baixo |

Na barra do polegar os switches ficam girados 180°, e tudo gira junto.

## Decisões e limites da rev0

- **Sem soquete hot-swap Kailh.** O soquete passa ~0,9 mm da borda de uma coluna de 17,4 mm e bateria na parede do trenó. As placas usam os **furos passantes do Choc**: dá para soldar o switch ou usar **soquetes Mill-Max** (tubinhos dentro do furo) e manter a troca de switches.
- **MCU externo na rev0.** Cada placa L tem um **cabeçalho de pads**. Na esquerda são 20: GND, VLED, DIN, R0–R5, COL0–COL6, LED1–3 e GND. Na direita são 17, sem os LEDs da tecla Yggi. Na bancada, ele se liga por fios a uma placa nRF52840 (nice!nano). O VLED vem do VCC chaveado do nice!nano.
- **Na rev1** entram na própria placa L: o módulo nRF52840 (~10 × 15,5 mm), o carregador, o conector da bateria, o USB-C, o conector magnético de 5 pinos e a chave (MOSFET) que corta a energia dos LEDs RGB. As posições do MCU e do USB-C já estão reservadas no CAD.
- **Espessura:** o CAD usa placa de **1,2 mm**. Encomendar com 1,2 mm, ou ajustar `pcb_t` no CAD para 1,6.
- **Trilhas traçadas pelo Freerouting**, em 2 camadas, e conferidas pelo DRC do KiCad. O traçado é automático (funciona, mas não é o mais bonito). O barramento rotativo obriga as trilhas a trocar de face na faixa entre F e números: J_IN e J_OUT têm a mesma ordem, deslocada, e isso não cabe numa face só.
- **LEDs RGB (SK6812MINI-E):** um por tecla Choc, 38 na mão esquerda e 35 na direita. Cuidados:
  - cada LED gasta **~1 mA mesmo apagado** (~75 mA por mão). Por isso a energia deles precisa ser cortada quando estiverem desligados: o VCC chaveado do nice!nano na rev0 e um MOSFET na rev1;
  - em branco total, cada LED puxa até 60 mA, o que dá mais de 2 A por mão. O **brilho precisa ser limitado no firmware**, e as trilhas de 0,25 mm e os fios de 30 AWG do jumper não aguentam o brilho máximo;
  - o SK6812 foi feito para 3,7–5,5 V. No VCC de 3,3 V do nice!nano ele funciona, mas o azul e o branco ficam mais fracos;
  - a posição da janela do LED (4,7 mm ao sul) segue os projetos de referência com Choc V1. **Conferir com um switch na mão** antes de fabricar;
  - os pads do LED ficam a 0,25 mm do canto do recorte, como no footprint oficial do KiCad. O mínimo de borda da placa fica em 0,2 mm, e a regra em `*.kicad_dru` volta a exigir 0,5 mm de todo o resto;
  - um capacitor de 4,7 µF por placa, entre VLED e GND.
- **Setas táteis (direita):** XKB TS-1187A na face de cima, com o diodo embaixo. A altura e o curso são diferentes dos do Choc, então o keycap de 0,5u precisa ser desenhado para elas.
- **Diodos SOD-123 na face de baixo** (1N4148W). O `route.py` troca o diodo do Ergogen, que tem pads nas duas faces e furos passantes, por um SMD simples: fácil de soldar à mão e montável pela JLCPCB.
- **Barra do polegar com os switches girados 180°.** Com o pino 2 virado para trás, o anel dele ficava a 0,28 mm da borda de trás da barra (abaixo do mínimo da JLCPCB). Virado, fica a 0,58 mm da borda da frente. O keycap do Choc é simétrico, então nada muda para quem digita.
- **LEDs da tecla Yggi** (só na esquerda): 3 LEDs 0805 na face de cima, na faixa entre F e números (CAD x = 4, 9 e 14 mm), cada um com um resistor 0805 de 1 kΩ embaixo, no mesmo lugar. Ligação: pino LEDn do MCU → resistor → LED → GND (acende com o pino em nível alto).
- **Furo do botão da trava** (CAD 22; 87,25, espelhado na direita): o `route.py` põe uma área proibida de 2,1 mm de raio em volta dele, e outra em volta de cada recorte de LED RGB, porque o Freerouting não aplica a folga de borda aos recortes internos.
- **Ainda não tem:** furos de fixação das placas (M2 na faixa + presilhas no trenó), o conector magnético entre as mãos e o recorte do USB-C no contorno da placa L. Tudo isso entra na rev1.

## Como regenerar

Precisa do KiCad 10 (`brew install --cask kicad`), do Java (`brew install openjdk`) e do [Freerouting 2.4.1](https://github.com/freerouting/freerouting/releases) em `~/.local/share/freerouting/` (ou na variável `FREEROUTING`). A partir da raiz do repositório:

```bash
python3 hardware/pcb/ergogen/generate.py
```

```bash
(cd hardware/pcb/ergogen && for d in coluna_1u coluna_2u placa_L coluna_1u_dir coluna_2u_dir placa_L_dir; do npx ergogen@4.2.1 $d.yaml -o output/$d && cp output/$d/outlines/board.dxf ../outlines/$d.dxf; done)
```

```bash
/Applications/KiCad/KiCad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python3 hardware/pcb/route.py
```

```bash
python3 hardware/pcb/assemble.py && python3 hardware/pcb/assemble.py 0
```

```bash
python3 hardware/tools/pcb_preview.py hardware/pcb/preview.svg hardware/pcb/kicad/placa_L.kicad_pcb hardware/pcb/kicad/coluna_1u.kicad_pcb hardware/pcb/kicad/coluna_2u.kicad_pcb hardware/pcb/kicad/coluna_2u_dir.kicad_pcb hardware/pcb/kicad/coluna_1u_dir.kicad_pcb hardware/pcb/kicad/placa_L_dir.kicad_pcb
```
