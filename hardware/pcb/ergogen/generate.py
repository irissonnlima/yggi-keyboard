#!/usr/bin/env python3
"""Gera as configurações do Ergogen das placas do Yggi (uma metade; a outra é espelhada).

Cadeia de placas (metade esquerda, de fora para dentro):
    placa L (bloco fixo + barra do polegar + MCU) -> coluna -> coluna -> coluna -> coluna dupla

Barramento rotativo: todas as ligações usam o mesmo par de blocos de 13 vias
    R0..R4 (linhas F, números, cima, meio, baixo) + C1..C5 (colunas) + VLED, GND e DAT (LEDs RGB).
Cada placa de coluna usa C1 e repassa C2..C5 deslocadas para C1..C4 na saída. Por isso as
3 placas de 1u são idênticas e funcionam em qualquer posição da cadeia. O DAT entra (DIN), passa
pelos LEDs da placa e sai (DOUT) na mesma posição do bloco seguinte.

Mão direita: as mesmas placas de coluna com a posição espelhada (a entrada fica do lado direito;
os switches não são espelhados). A placa L direita tem outro bloco fixo (8 teclas de 1u + shift
de 2u) e outra barra (espaço, return, ⌘ e 4 setas táteis de meia altura, postas pelo route.py).

Coordenadas: origem no centro da tecla da fileira de baixo (r4) da primeira coluna da placa.
Passo 18 × 17 mm (Choc), faixa livre de 4,5 mm entre a fileira F (r0) e a dos números (r1).
"""
import pathlib
import textwrap

HERE = pathlib.Path(__file__).parent
KX, KY, FGAP = 18, 17, 4.5
BAND_Y = 3 * KY + KY / 2 + FGAP / 2       # centro da faixa entre r1 e r0 (61,75)
PITCH = 1.27
# Bloco de 2 × 7 pads (passo 1,27). Linha de cima: linhas da matriz + LEDs; de baixo: colunas + dados.
J_IN = ["R0", "R1", "R2", "R3", "R4", "VLED", "GND", "C1", "C2", "C3", "C4", "C5", "DIN", None]
J_OUT = ["R0", "R1", "R2", "R3", "R4", "VLED", "GND", "C2", "C3", "C4", "C5", None, "DOUT", None]
# J_IN fica mais para trás e à esquerda, J_OUT mais para a frente e à direita (lado a lado não cabem
# na coluna de 17,4 mm). O jumper liga J_OUT de uma placa ao J_IN da seguinte, 10,82 mm ao lado.
IN_X, IN_Y = -7.4, BAND_Y + 1.6        # 1º pad, a partir do centro da tecla de baixo da coluna
OUT_X, OUT_Y = -0.22, BAND_Y - 1.6

HEADER = """meta:
  engine: 4.1.0
  name: {name}
  author: Yggi Keyboard
  version: rev0
units:
  kx: {kx}
  ky: {ky}
"""


def matrix_zone(name, cols, anchor=None):
    s = f"    {name}:\n"
    if anchor:
        s += f"      anchor:\n        ref: {anchor[0]}\n        shift: [{anchor[1]}, {anchor[2]}]\n"
    s += "      key:\n        spread: kx\n        padding: ky\n"
    s += "      columns:\n"
    for c, extra in cols:
        s += f"        {c}:\n"
        if extra:
            s += "          key:\n" + "".join(f"            {k}: {v}\n" for k, v in extra.items())
    return s


ROWS = """      rows:
        r4:
          row_net: R4
        r3:
          row_net: R3
        r2:
          row_net: R2
        r1:
          row_net: R1
          padding: ky + {fgap}
        r0:
          row_net: R0
""".format(fgap=FGAP)


def pads(prefix, ref, x0, y0, nets, mirror=False):
    """Bloco 2 × 7 de pads SMD (passo 1,27 mm) embaixo da placa, para fios de silicone ou FPC.
    mirror=True: mesmo bloco espelhado (mão direita), com os pads na ordem inversa em x."""
    out = ""
    step = -PITCH if mirror else PITCH
    for i, net in enumerate(nets):
        if not net:
            continue
        col, row = i % 7, i // 7
        x = round(x0 + col * step, 3)
        y = round(y0 + (0.635 if row == 0 else -0.635), 3)
        out += f"""    {prefix}_{i}:
      what: pad
      where: {ref}
      adjust:
        shift: [{x}, {y}]
      params:
        front: false
        back: true
        width: 1
        height: 0.9
        text: ''
        net: {net}
"""
    return out


def header_pads(ref, x, nets):
    """Cabeçalho do MCU externo da rev0 (nice!nano por fios), pads SMD embaixo, passo 1,27."""
    out = ""
    for i, net in enumerate(nets):
        out += f"""    mcu_{i}:
      what: pad
      where: {ref}
      adjust:
        shift: [{x}, {round(-6 + i * PITCH, 3)}]
      params:
        front: false
        back: true
        width: 1.0
        height: 0.9
        text: ''
        net: {net}
"""
    return out


def switches(where="true", name="", rotate=0):
    """Switch Choc + diodo. rotate=180 vira o switch (pinos para a frente) e leva o diodo para trás."""
    rot = f"\n      adjust:\n        rotate: {rotate}" if rotate else ""
    return f"""    choc{name}:
      what: choc
      where: {where}{rot}
      params:
        keycaps: true
        reverse: false
        hotswap: false
        from: "{{{{column_net}}}}"
        to: "{{{{colrow}}}}"
    diode{name}:
      what: diode
      where: {where}
      params:
        from: "{{{{colrow}}}}"
        to: "{{{{row_net}}}}"
      adjust:
        shift: [0, {5.3 if rotate else -5.3}]
"""


def outline(rects):
    s = "outlines:\n  board:\n"
    for i, (cx, cy, w, h) in enumerate(rects):
        s += f"""    - what: rectangle
      where: ref
      adjust:
        shift: [{cx}, {cy}]
      size: [{w}, {h}]
"""
    s += "  keys:\n    - what: rectangle\n      where: true\n      size: [kx-0.5, ky-0.5]\n"
    return s.replace("where: ref", "where: " + REF)


def pcb(name, footprints):
    import textwrap
    return f"pcbs:\n  {name}:\n    outlines:\n      main:\n        outline: board\n    footprints:\n" + textwrap.indent(footprints, "  ")


# ---------- placas de coluna (1u idêntica ×3, 2u no fim da cadeia), esquerda e direita ----------
REF = "matrix_c1_r4"
for side, m in (("", 1), ("_dir", -1)):
    col1 = HEADER.format(name="yggi_coluna_1u" + side, kx=KX, ky=KY)
    col1 += "points:\n  zones:\n" + matrix_zone("matrix", [("c1", {"column_net": "C1"})]) + ROWS
    col1 += outline([(0, 36.25, KX - 0.6, 89.5)])
    col1 += pcb("coluna_1u" + side, switches()
                + pads("jin", REF, m * IN_X, IN_Y, J_IN, m < 0)
                + pads("jout", REF, m * OUT_X, OUT_Y, J_OUT, m < 0))
    (HERE / f"coluna_1u{side}.yaml").write_text(col1)

    col2 = HEADER.format(name="yggi_coluna_2u" + side, kx=KX, ky=KY)
    col2 += "points:\n  zones:\n" + matrix_zone(
        "matrix", [("c1", {"column_net": "C1"}), ("c2", {"column_net": "C2", "spread": m * KX})]) + ROWS
    col2 += outline([(m * KX / 2, 36.25, 2 * KX - 0.6, 89.5)])
    col2 += pcb("coluna_2u" + side, switches() + pads("jin", REF, m * IN_X, IN_Y, J_IN, m < 0))
    (HERE / f"coluna_2u{side}.yaml").write_text(col2)

# ---------- placa L: bloco fixo + barra do polegar + cabeçalho do MCU ----------
# Origem = centro da tecla r4 da coluna externa (c0). REF = shift de 2u, centralizado entre c0 e c1.
# Barra do polegar: switches girados 180°. Com o pino 2 para trás, o anel dele ficaria a 0,28 mm
# da borda de trás da barra (a JLCPCB pede 0,3 mm e o DRC 0,5 mm); virado, fica a 0,58 mm da frente.
REF = "big_c0_r4"
LEFT_ZONES = """points:
  zones:
    big:
      anchor:
        shift: [kx/2, 0]
      key:
        padding: ky
        width: 2*kx
        column_net: COL0
      columns:
        c0:
      rows:
        r4:
          row_net: R4
        r3:
          row_net: R3
        r2:
          row_net: R2
    fixed:
      anchor:
        shift: [0, 3*ky]
      key:
        spread: kx
        padding: ky + {fgap}
      columns:
        c0:
          key:
            column_net: COL0
        c1:
          key:
            column_net: COL1
      rows:
        r1:
          row_net: R1
        r0:
          row_net: R0
    bar:
      anchor:
        shift: [0, -ky]
      key:
        padding: ky
        row_net: R5
      columns:
        fn:
          key:
            column_net: COL0
        ctl:
          key:
            spread: kx
            column_net: COL1
        opt:
          key:
            spread: kx
            column_net: COL2
        cmd:
          key:
            spread: kx
            column_net: COL3
        del:
          key:
            spread: 22.5
            width: 1.5*kx
            column_net: COL4
        spc:
          key:
            spread: 27
            width: 1.5*kx
            column_net: COL5
      rows:
        r5:
""".format(fgap=FGAP)
# Direita (x espelhado): 8 teclas de 1u nas fileiras r0..r3 das duas colunas fixas, shift de 2u em r4;
# na barra, só ⌘, return e espaço são Choc (as 4 setas de meia altura são táteis, postas pelo route.py).
RIGHT_ZONES = """points:
  zones:
    big:
      anchor:
        shift: [-kx/2, 0]
      key:
        width: 2*kx
        column_net: COL0
      columns:
        c0:
      rows:
        r4:
          row_net: R4
    fixed:
      anchor:
        shift: [0, ky]
      key:
        spread: -kx
        padding: ky
      columns:
        c0:
          key:
            column_net: COL0
        c1:
          key:
            column_net: COL1
      rows:
        r3:
          row_net: R3
        r2:
          row_net: R2
        r1:
          row_net: R1
          padding: ky + {fgap}
        r0:
          row_net: R0
    bar:
      anchor:
        shift: [-54, -ky]
      key:
        padding: ky
        row_net: R5
      columns:
        cmd:
          key:
            column_net: COL4
        ret:
          key:
            spread: -22.5
            width: 1.5*kx
            column_net: COL5
        spc:
          key:
            spread: -27
            width: 1.5*kx
            column_net: COL6
      rows:
        r5:
""".format(fgap=FGAP)
L_OUT_X = 17.78                  # 1º pad do J_OUT da placa L, a partir de c0 (= coluna vizinha - 10,82)
for side, m, zones, extra in (("", 1, LEFT_ZONES, ["LED1", "LED2", "LED3"]), ("_dir", -1, RIGHT_ZONES, [])):
    dx = -m * KX / 2             # "x a partir de c0" -> deslocamento a partir de REF
    lb = HEADER.format(name="yggi_placa_L" + side, kx=KX, ky=KY) + zones
    lb += outline([(m * 9 + dx, 36.25, 35.4, 89.5), (m * 54 + dx, -17.15, 124, 14.7), (m * 9.35 + dx, -9.1, 34.7, 1.6)])
    # furo do botão da trava (atravessa a placa L na faixa entre F e números, x = 22 no CAD)
    lb = lb.replace("  keys:\n", f"""    - what: circle
      where: {REF}
      adjust:
        shift: [{m * 13 + dx}, {BAND_Y}]
      radius: 1.4
      operation: subtract
  keys:\n""", 1)
    mcu_nets = ["GND", "VLED", "DIN", "R0", "R1", "R2", "R3", "R4", "R5",
                "COL0", "COL1", "COL2", "COL3", "COL4", "COL5", "COL6"] + extra + ["GND"]
    jout = [{"C2": "COL2", "C3": "COL3", "C4": "COL4", "C5": "COL5"}.get(n, n) for n in J_OUT]
    jout[11] = "COL6"
    lb += pcb("placa_L" + side, switches("-/_r5$/") + switches("/_r5$/", "_bar", 180)
              + pads("jout", REF, m * L_OUT_X + dx, OUT_Y, jout, m < 0)
              + header_pads(REF, m * -6.8 + dx, mcu_nets))
    (HERE / f"placa_L{side}.yaml").write_text(lb)
print("configs geradas:", sorted(p.name for p in HERE.glob("*.yaml")))
