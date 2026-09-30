#!/usr/bin/env python3
"""Gera as configurações do Ergogen das placas do Yggi (uma metade; a outra é espelhada).

Cadeia de placas (metade esquerda, de fora para dentro):
    placa L (bloco fixo + barra do polegar + MCU) -> coluna -> coluna -> coluna -> coluna dupla

Barramento rotativo: todas as ligações usam o mesmo par de pads de 10 vias
    R0..R4 (linhas F, números, cima, meio, baixo) + C1..C5 (colunas).
Cada placa de coluna usa C1 e repassa C2..C5 deslocadas para C1..C4 na saída. Por isso as
3 placas de 1u são idênticas e funcionam em qualquer posição da cadeia.

Coordenadas: origem no centro da tecla da fileira de baixo (r4) da primeira coluna da placa.
Passo 18 × 17 mm (Choc), faixa livre de 4,5 mm entre a fileira F (r0) e a dos números (r1).
"""
import pathlib
import textwrap

HERE = pathlib.Path(__file__).parent
KX, KY, FGAP = 18, 17, 4.5
BAND_Y = 3 * KY + KY / 2 + FGAP / 2       # centro da faixa entre r1 e r0 (61,75)
PITCH = 1.27
BUS = ["R0", "R1", "R2", "R3", "R4", "C1", "C2", "C3", "C4", "C5"]

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


def pads(prefix, ref, x0, nets, back=True):
    """Bloco 2 × 5 de pads SMD (passo 1,27 mm) para fios de silicone ou jumper flexível."""
    out = ""
    for i, net in enumerate(nets):
        col, row = i % 5, i // 5
        x = round(x0 + col * PITCH, 3)
        y = round(BAND_Y + (0.635 if row == 0 else -0.635), 3)
        if not net:
            continue
        out += f"""    {prefix}_{i}:
      what: pad
      where: {ref}
      adjust:
        shift: [{x}, {y}]
      params:
        front: false
        back: {'true' if back else 'false'}
        width: 1
        height: 0.9
        text: ''
        net: {net}
"""
    return out


def switches(where="true"):
    return f"""    choc:
      what: choc
      where: {where}
      params:
        keycaps: true
        reverse: false
        hotswap: false
        from: "{{{{column_net}}}}"
        to: "{{{{colrow}}}}"
    diode:
      what: diode
      where: {where}
      params:
        from: "{{{{colrow}}}}"
        to: "{{{{row_net}}}}"
      adjust:
        shift: [0, -5.3]
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


# ---------- placa de coluna 1u (idêntica ×3) ----------
REF = "matrix_c1_r4"
col1 = HEADER.format(name="yggi_coluna_1u", kx=KX, ky=KY)
col1 += "points:\n  zones:\n" + matrix_zone("matrix", [("c1", {"column_net": "C1"})]) + ROWS
col1 += outline([(0, 36.25, KX - 0.6, 89.5)])
col1 += pcb("coluna_1u",
            switches()
            + pads("jin", REF, -7.0, BUS)                                      # entrada
            + pads("jout", REF, 1.9, ["R0", "R1", "R2", "R3", "R4", "C2", "C3", "C4", "C5", None]))  # saída deslocada
(HERE / "coluna_1u.yaml").write_text(col1)

# ---------- placa de coluna dupla (indicador, fim da cadeia) ----------
REF = "matrix_c1_r4"
col2 = HEADER.format(name="yggi_coluna_2u", kx=KX, ky=KY)
col2 += "points:\n  zones:\n" + matrix_zone("matrix", [("c1", {"column_net": "C1"}), ("c2", {"column_net": "C2"})]) + ROWS
col2 += outline([(KX / 2, 36.25, 2 * KX - 0.6, 89.5)])
col2 += pcb("coluna_2u", switches() + pads("jin", REF, -7.0, BUS))
(HERE / "coluna_2u.yaml").write_text(col2)

# ---------- placa L: bloco fixo + barra do polegar + cabeçalho do MCU ----------
# Origem = centro da tecla r4 da coluna externa (c0). As 3 teclas de 2u (tab, caps, shift) ficam
# numa zona própria, centralizada entre c0 e c1; esc/F1 e Yggi/` numa zona de 2 colunas acima.
REF = "big_c0_r4"          # fica em x = kx/2
lb = HEADER.format(name="yggi_placa_L", kx=KX, ky=KY)
lb += """points:
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
DX = -KX / 2   # converte "x absoluto" (origem em c0) para deslocamento a partir de REF
lb += outline([(9 + DX, 36.25, 35.4, 89.5), (54 + DX, -17.15, 124, 14.7), (9.35 + DX, -9.1, 34.7, 1.6)])
# furo do botão da trava (atravessa a placa L na faixa entre F e números, x = 22 no CAD)
lb = lb.replace("  keys:\n", f"""    - what: circle
      where: {REF}
      adjust:
        shift: [{22 - 9 + DX}, {BAND_Y}]
      radius: 1.4
      operation: subtract
  keys:\n""", 1)
mcu_nets = ["GND", "R0", "R1", "R2", "R3", "R4", "R5", "COL0", "COL1", "COL2", "COL3", "COL4", "COL5", "COL6",
            "LED1", "LED2", "LED3", "GND"]
mcu = ""
for i, net in enumerate(mcu_nets):
    mcu += f"""    mcu_{i}:
      what: pad
      where: {REF}
      adjust:
        shift: [{-6.8 + DX}, {round(-6 + i * PITCH, 3)}]
      params:
        front: false
        back: true
        width: 1.0
        height: 0.9
        text: ''
        net: {net}
"""
lb += pcb("placa_L", switches() + pads("jout", REF, 19.5 + DX, ["R0", "R1", "R2", "R3", "R4", "COL2", "COL3", "COL4", "COL5", "COL6"]) + mcu)
(HERE / "placa_L.yaml").write_text(lb)
print("configs geradas:", [p.name for p in HERE.glob("*.yaml")])
