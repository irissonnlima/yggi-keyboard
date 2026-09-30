#!/usr/bin/env python3
"""Junta as 5 placas de uma metade num único arquivo do KiCad, na posição do CAD (só para ver).

    python3 hardware/pcb/assemble.py [stagger_pct]      # 0 (ortho, padrão) … 150

As placas ficam separadas por GAP mm (a mais do que no teclado) para ver onde cada uma acaba.

Lê as placas roteadas em hardware/pcb/kicad/ e grava hardware/pcb/kicad/metade_esquerda.kicad_pcb
(com stagger diferente de 0: metade_esquerda_<pct>.kicad_pcb).

As redes de cada placa são renomeadas para os nomes reais da matriz. O barramento rotativo faz o
"C1" de cada coluna ser uma coluna diferente: na 1ª placa de 1u, C1 = COL2 e C2 = COL3; na 2ª,
C1 = COL3; e assim por diante. Com isso o KiCad desenha os jumpers como linhas de ligação
(ratsnest) entre J_OUT de uma placa e J_IN da seguinte. As redes internas de cada placa (switch →
diodo) ganham o prefixo da placa. Este arquivo não vai para fabricação: cada placa é feita à parte.
Não usa o pcbnew, só Python.
"""
import pathlib
import re
import sys
import uuid

HERE = pathlib.Path(__file__).resolve().parent / "kicad"

# Quadro do CAD (x entre colunas, y ao longo da coluna, mm) -> folha A3 do KiCad (y para baixo)
OX, OY = 147.0, 201.5
STAGGER = {"MI": 0, "AN": 9, "ME": 15, "IN": 9}         # stagger de cada coluna em 150% (GAV no CAD)

# (prefixo, arquivo, x do CAD do switch S1, deslocamento no barramento: C1 = COL(2 + k))
BOARDS = [
    ("L", "placa_L", 18, None),
    ("MI", "coluna_1u", 45, 0),     # mindinho
    ("AN", "coluna_1u", 63, 1),     # anelar
    ("ME", "coluna_1u", 81, 2),     # médio
    ("IN", "coluna_2u", 99, 3),     # indicador (S1 = coluna externa da placa dupla)
]
S1_Y = 25.5                          # centro da fileira de baixo (r4) no CAD
GAP = 8.0                            # espaço extra entre placas vizinhas (em x), para ver onde cada uma acaba


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


def net_map(prefix, k):
    def m(name):
        if name == "":
            return name
        if prefix == "L":
            return name if re.fullmatch(r"(R\d|COL\d|GND|LED\d)", name) else f"L.{name}"
        g = re.fullmatch(r"C(\d)", name)
        if g:
            col = 1 + k + int(g.group(1))
            return f"COL{col}" if col <= 6 else f"{prefix}.livre.C{g.group(1)}"
        return name if re.fullmatch(r"R\d", name) else f"{prefix}.{name}"
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
    pct = float(sys.argv[1]) if len(sys.argv) > 1 else 0
    header, items = None, []
    for i, (prefix, fname, cad_x, k) in enumerate(BOARDS):
        root = parse(tokenize((HERE / f"{fname}.kicad_pcb").read_text()))
        if header is None:
            header = [c for c in root[1:] if isinstance(c, list) and c[0] in
                      ("version", "generator", "generator_version", "general", "paper", "layers", "setup")]
        sx, sy = s1_position(root)
        cad_y = S1_Y + STAGGER.get(prefix, 0) * pct / 150
        dx, dy = OX + cad_x + i * GAP - sx, OY - cad_y - (GAP / 2 if i else 0) - sy   # colunas sobem, longe da barra
        rename = net_map(prefix, k)

        def fix(n):
            if n[0] == "net" and len(n) == 2:
                n[1] = f'"{rename(unq(n[1]))}"'
            elif n[0] == "uuid":                      # as 3 colunas de 1u são cópias: uuids novos
                n[1] = f'"{uuid.uuid4()}"'
            elif n[0] == "property" and n[1] == '"Reference"':
                n[2] = f'"{prefix}.{unq(n[2])}"'

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
    title = ["title_block", ["title", f'"Yggi · metade esquerda (visão, stagger {pct:g}%)"'], ["rev", '"rev0"'],
             ["company", '"Yggi Keyboard"'],
             ["comment", "1", '"Só para ver: cada placa é fabricada à parte (placa_L, coluna_1u ×3, coluna_2u)."']]
    board = ["kicad_pcb"] + header + [title] + items
    name = "metade_esquerda" if pct == 0 else f"metade_esquerda_{pct:g}"
    out = HERE / f"{name}.kicad_pcb"
    out.write_text(dump(board) + "\n")
    pro = (HERE / "placa_L.kicad_pro").read_text().replace('"placa_L', f'"{name}')
    out.with_suffix(".kicad_pro").write_text(pro)
    print("gravado:", out)


if __name__ == "__main__":
    main()
