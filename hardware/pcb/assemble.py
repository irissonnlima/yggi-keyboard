#!/usr/bin/env python3
"""Monta o teclado inteiro (as 10 placas das duas mãos) num único arquivo do KiCad, na posição do
CAD, só para ver o circuito todo de uma vez.

    python3 hardware/pcb/assemble.py [stagger_pct]      # 150 (padrão) … 0 (ortho)

Lê as placas roteadas em hardware/pcb/kicad/ e grava hardware/pcb/kicad/teclado_<pct>.kicad_pcb.

As redes de cada placa são renomeadas para os nomes reais da matriz, com o prefixo da mão (E. ou
D.: cada metade tem o próprio MCU). O barramento rotativo faz o "C1" de cada coluna ser uma coluna
diferente: na 1ª placa de 1u, C1 = COL2 e C2 = COL3; na 2ª, C1 = COL3; e assim por diante. O DAT
dos LEDs RGB sai de uma placa (DOUT) e entra na seguinte (DIN). Com isso o KiCad desenha os jumpers
como linhas de ligação (ratsnest) entre J_OUT de uma placa e J_IN da seguinte.
As placas ficam afastadas GAP mm (a mais do que no teclado) para ver onde cada uma acaba.
Este arquivo não vai para fabricação: cada placa é feita à parte. Não usa o pcbnew, só Python.
"""
import pathlib
import re
import sys
import uuid

HERE = pathlib.Path(__file__).resolve().parent / "kicad"

KB_W = 126                           # largura de uma metade (7u)
STAGGER = {"MI": 0, "AN": 9, "ME": 15, "IN": 9}         # stagger de cada coluna em 150% (GAV no CAD)
S1_Y = 25.5                          # centro da fileira de baixo (r4) no CAD
GAP = 8.0                            # espaço extra entre placas vizinhas
MID = 24.0                           # espaço extra entre as duas mãos

# (mão, prefixo, arquivo, x do switch S1 no quadro da metade esquerda do CAD, k: C1 = COL(2 + k))
# A mão direita é o espelho: x no mundo = 2 × KB_W - x (e as placas _dir já têm a posição espelhada).
BOARDS = [
    ("E", "L", "placa_L", 18, None), ("E", "MI", "coluna_1u", 45, 0), ("E", "AN", "coluna_1u", 63, 1),
    ("E", "ME", "coluna_1u", 81, 2), ("E", "IN", "coluna_2u", 99, 3),
    ("D", "L", "placa_L_dir", 18, None), ("D", "MI", "coluna_1u_dir", 45, 0), ("D", "AN", "coluna_1u_dir", 63, 1),
    ("D", "ME", "coluna_1u_dir", 81, 2), ("D", "IN", "coluna_2u_dir", 99, 3),
]


def tokenize(text):
    return re.findall(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()]+', text)


def parse(tokens):
    stack = [[]]
    for t in tokens:
        if t == "(":
            stack.append([])
        elif t == ")":
            done = stack.pop()
            stack[-1].append(done)
        else:
            stack[-1].append(t)
    return stack[0][0]


def dump(node, depth=0):
    if not isinstance(node, list):
        return node
    if all(not isinstance(c, list) for c in node):
        return "(" + " ".join(node) + ")"
    pad = "\t" * (depth + 1)
    inner = "\n".join(pad + dump(c, depth + 1) for c in node[1:])
    return f"({node[0]}\n{inner}\n" + "\t" * depth + ")"


def unq(s):
    return s[1:-1] if s.startswith('"') else s


def net_map(side, prefix, k, n_board):
    """Nome real de cada rede no teclado. n_board = posição da placa na cadeia (0 = placa L)."""
    def m(name):
        if name == "":
            return name
        if name in ("VLED", "GND"):
            return f"{side}.{name}"
        if name == "DIN":                     # dados que chegam da placa anterior (ou do MCU)
            return f"{side}.DAT{n_board}"
        if name == "DOUT":
            return f"{side}.DAT{n_board + 1}"
        if prefix == "L":
            return f"{side}.{name}" if re.fullmatch(r"(R\d|COL\d|LED\d)", name) else f"{side}.L.{name}"
        g = re.fullmatch(r"C(\d)", name)
        if g:
            col = 1 + k + int(g.group(1))
            return f"{side}.COL{col}" if col <= 6 else f"{side}.{prefix}.livre.C{g.group(1)}"
        return f"{side}.{name}" if re.fullmatch(r"R\d", name) else f"{side}.{prefix}.{name}"
    return m


def move(node, dx, dy, keys=("at", "start", "end", "center", "mid", "xy")):
    """Desloca as coordenadas dos filhos diretos (e, em zonas, de todos os pontos)."""
    for c in node[1:]:
        if isinstance(c, list) and c and c[0] in keys and len(c) >= 3:
            c[1] = f"{float(c[1]) + dx:.4f}"
            c[2] = f"{float(c[2]) + dy:.4f}"


def walk(node, fn):
    if isinstance(node, list):
        fn(node)
        for c in node[1:]:
            walk(c, fn)


def s1_position(root):
    for fp in root[1:]:
        if isinstance(fp, list) and fp[0] == "footprint":
            for c in fp:
                if isinstance(c, list) and c[:3] == ["property", '"Reference"', '"S1"']:
                    at = next(x for x in fp if isinstance(x, list) and x[0] == "at")
                    return float(at[1]), float(at[2])
    raise SystemExit("S1 não encontrado")


def main():
    pct = float(sys.argv[1]) if len(sys.argv) > 1 else 150
    header, items = None, []
    for side, prefix, fname, cad_x, k in BOARDS:
        n_board = 0 if k is None else k + 1
        root = parse(tokenize((HERE / f"{fname}.kicad_pcb").read_text()))
        if header is None:
            header = [c for c in root[1:] if isinstance(c, list) and c[0] in
                      ("version", "generator", "generator_version", "general", "paper", "layers", "setup")]
        sx, sy = s1_position(root)
        # afastamento: as placas de fora vão para fora, as colunas sobem um pouco (longe da barra)
        spread = (n_board - 4) * GAP - MID / 2
        wx = cad_x + spread if side == "E" else 2 * KB_W - cad_x - spread
        cad_y = S1_Y + STAGGER.get(prefix, 0) * pct / 150 + (GAP / 2 if n_board else 0)
        ox, oy = 210 - KB_W, 148.5 + 60        # centro da folha A3 no centro do teclado
        dx, dy = ox + wx - sx, oy - cad_y - sy
        rename = net_map(side, prefix, k, n_board)

        def fix(n):
            if n[0] == "net" and len(n) == 2:
                n[1] = f'"{rename(unq(n[1]))}"'
            elif n[0] == "uuid":                      # as colunas de 1u são cópias: uuids novos
                n[1] = f'"{uuid.uuid4()}"'
            elif n[0] == "property" and n[1] == '"Reference"':
                n[2] = f'"{side}.{prefix}.{unq(n[2])}"'

        for c in root[1:]:
            if not isinstance(c, list) or c[0] not in ("footprint", "segment", "via", "gr_line", "gr_circle",
                                                        "gr_arc", "gr_rect", "zone"):
                continue
            walk(c, fix)
            if c[0] == "zone":
                walk(c, lambda n: move(n, dx, dy, ("xy",)))
            else:
                move(c, dx, dy)
            items.append(c)
    title = ["title_block", ["title", f'"Yggi · teclado inteiro (visão, stagger {pct:g}%)"'], ["rev", '"rev0"'],
             ["company", '"Yggi Keyboard"'],
             ["comment", "1", '"Só para ver: cada placa é fabricada à parte. E. = mão esquerda, D. = mão direita."']]
    board = ["kicad_pcb"] + header + [title] + items
    name = f"teclado_{pct:g}"
    out = HERE / f"{name}.kicad_pcb"
    out.write_text(dump(board) + "\n")
    pro = (HERE / "placa_L.kicad_pro").read_text().replace('"placa_L', f'"{name}')
    out.with_suffix(".kicad_pro").write_text(pro)
    # mesma regra de borda das placas; os LEDs agora se chamam E.MI.L3 etc.
    out.with_suffix(".kicad_dru").write_text((HERE / "placa_L.kicad_dru").read_text().replace("'L*'", "'*.L*'"))
    print("gravado:", out)


if __name__ == "__main__":
    main()
