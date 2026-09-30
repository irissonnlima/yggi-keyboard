#!/usr/bin/env python3
"""Desenha uma prévia SVG das placas (.kicad_pcb do Ergogen + contorno .dxf), sem dependências.

Uso: python3 hardware/tools/pcb_preview.py saida.svg placa1.kicad_pcb [placa2.kicad_pcb ...]
O contorno é lido do .dxf de mesmo nome em hardware/pcb/outlines/.
"""
import math
import pathlib
import re
import sys

COL = {"switch": "#3b7dd8", "diode": "#e39a2d", "pad": "#c9a227", "hole": "#1b1a18", "edge": "#2e8b57",
       "led": "#d6336c", "F.Cu": "#c0392b", "B.Cu": "#5b8fd6", "via": "#6b6860"}


def dxf_shapes(path):
    lines = [l.strip() for l in open(path).read().split("\n")]
    segs, circles, i = [], [], 0
    while i < len(lines):
        if lines[i] == "LINE":
            d = {}
            j = i + 1
            while j < len(lines) and lines[j] not in ("LINE", "CIRCLE", "ARC", "ENDSEC"):
                if lines[j] in ("10", "20", "11", "21"):
                    d[lines[j]] = float(lines[j + 1])
                j += 1
            segs.append((d["10"], d["20"], d["11"], d["21"]))
            i = j
        elif lines[i] == "CIRCLE":
            d = {}
            j = i + 1
            while j < len(lines) and lines[j] not in ("LINE", "CIRCLE", "ARC", "ENDSEC"):
                if lines[j] in ("10", "20", "40"):
                    d[lines[j]] = float(lines[j + 1])
                j += 1
            circles.append((d["10"], d["20"], d["40"]))
            i = j
        else:
            i += 1
    return segs, circles


def sexp(text):
    """Lê uma S-expression do KiCad em listas aninhadas (átomos como texto)."""
    tokens = re.findall(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()]+', text)
    stack = [[]]
    for t in tokens:
        if t == "(":
            stack.append([])
        elif t == ")":
            done = stack.pop()
            stack[-1].append(done)
        else:
            stack[-1].append(t.strip('"'))
    return stack[0][0]


def child(node, key):
    return next((c for c in node if isinstance(c, list) and c and c[0] == key), None)


def children(node, key):
    return [c for c in node if isinstance(c, list) and c and c[0] == key]


def board_items(path):
    """Pads (com o nome do footprint), trilhas e vias. Aceita os formatos do KiCad 5 e do atual."""
    root = sexp(open(path).read())
    pads, tracks, vias = [], [], []
    for fp in children(root, "footprint") + children(root, "module"):
        name = fp[1]
        at = child(fp, "at")
        X, Y, R = float(at[1]), -float(at[2]), float(at[3]) if len(at) > 3 else 0.0
        r = math.radians(R)
        for pad in children(fp, "pad"):
            a, sz = child(pad, "at"), child(pad, "size")
            dx, dy = float(a[1]), -float(a[2])
            pads.append((name, X + dx * math.cos(r) - dy * math.sin(r), Y + dx * math.sin(r) + dy * math.cos(r),
                         float(sz[1]), float(sz[2]), pad[3] == "circle", pad[2] == "np_thru_hole"))
    for seg in children(root, "segment"):
        a, b = child(seg, "start"), child(seg, "end")
        tracks.append((float(a[1]), -float(a[2]), float(b[1]), -float(b[2]),
                       float(child(seg, "width")[1]), child(seg, "layer")[1]))
    for v in children(root, "via"):
        a = child(v, "at")
        vias.append((float(a[1]), -float(a[2]), float(child(v, "size")[1])))
    # o route.py centraliza a placa na folha; o canto do contorno (Edge.Cuts) alinha tudo com o .dxf
    edge = [(float(p[1]), -float(p[2])) for g in children(root, "gr_line")
            if child(g, "layer")[1] == "Edge.Cuts" for p in (child(g, "start"), child(g, "end"))]
    return pads, tracks, vias, (min(x for x, _ in edge), min(y for _, y in edge))


def main():
    out, files = sys.argv[1], sys.argv[2:]
    root = pathlib.Path(files[0]).resolve().parents[1]
    boards, x_off, gap, S = [], 0, 14, 4
    for f in files:
        name = pathlib.Path(f).stem
        segs, circles = dxf_shapes(root / "outlines" / f"{name}.dxf")
        xs = [v for s in segs for v in (s[0], s[2])]
        ys = [v for s in segs for v in (s[1], s[3])]
        pads_, tracks, vias, (ex, ey) = board_items(f)
        dx, dy = min(xs) - ex, min(ys) - ey
        items = ([(n, x + dx, y + dy, *r) for n, x, y, *r in pads_],
                 [(a + dx, b + dy, c + dx, d + dy, w, l) for a, b, c, d, w, l in tracks],
                 [(x + dx, y + dy, d) for x, y, d in vias])
        boards.append((name, segs, circles, items, min(xs), max(xs), min(ys), max(ys)))
    total_w = sum(b[5] - b[4] for b in boards) + gap * (len(boards) - 1)
    ymin, ymax = min(b[6] for b in boards), max(b[7] for b in boards)
    W, H = (total_w + 20) * S, (ymax - ymin + 34) * S
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}" width="100%" font-family="sans-serif">',
           f'<rect width="{W:.0f}" height="{H:.0f}" fill="#f7f6f2"/>']
    x0 = 10
    for name, segs, circles, (P, T, V), bx0, bx1, by0, by1 in boards:
        tx = lambda x: (x0 + x - bx0) * S
        ty = lambda y: (ymax - y + 10) * S
        for a, b, c, d in segs:
            svg.append(f'<line x1="{tx(a):.1f}" y1="{ty(b):.1f}" x2="{tx(c):.1f}" y2="{ty(d):.1f}" stroke="{COL["edge"]}" stroke-width="2"/>')
        for cx, cy, r in circles:
            svg.append(f'<circle cx="{tx(cx):.1f}" cy="{ty(cy):.1f}" r="{r * S:.1f}" fill="none" stroke="{COL["edge"]}" stroke-width="2"/>')
        for a, b, c, d, w, layer in sorted(T, key=lambda t: t[5] == "F.Cu"):
            svg.append(f'<line x1="{tx(a):.1f}" y1="{ty(b):.1f}" x2="{tx(c):.1f}" y2="{ty(d):.1f}" stroke="{COL[layer]}" '
                       f'stroke-width="{w * S:.1f}" stroke-linecap="round" opacity="0.8"/>')
        for fp, x, y, w, h, circ, npth in P:
            c = (COL["hole"] if npth else COL["switch"] if fp == "PG1350" else COL["diode"] if "Diode" in fp or "SOD" in fp
                 else COL["led"] if fp.startswith(("LED", "R_")) else COL["pad"])
            if circ:
                svg.append(f'<circle cx="{tx(x):.1f}" cy="{ty(y):.1f}" r="{w / 2 * S:.1f}" fill="{c}" opacity="{0.85 if npth else 0.9}"/>')
            else:
                svg.append(f'<rect x="{tx(x) - w / 2 * S:.1f}" y="{ty(y) - h / 2 * S:.1f}" width="{w * S:.1f}" height="{h * S:.1f}" fill="{c}"/>')
        for x, y, d in V:
            svg.append(f'<circle cx="{tx(x):.1f}" cy="{ty(y):.1f}" r="{d / 2 * S:.1f}" fill="{COL["via"]}"/>')
        svg.append(f'<text x="{tx((bx0 + bx1) / 2):.1f}" y="{ty(by0) + 7 * S:.1f}" font-size="{3.2 * S:.0f}" text-anchor="middle" fill="#3a3834">{name.replace("_", " ")}</text>')
        x0 += bx1 - bx0 + gap
    legend = [("contorno", COL["edge"]), ("pinos do switch Choc", COL["switch"]), ("diodo", COL["diode"]), ("LEDs e resistores", COL["led"]), ("pads da cadeia / MCU", COL["pad"]),
              ("trilha em cima", COL["F.Cu"]), ("trilha embaixo", COL["B.Cu"]), ("furos", COL["hole"])]
    for i, (label, c) in enumerate(legend):          # duas linhas de 4
        lx, ly = (10 + (i % 4) * (W / S - 20) / 4) * S, H - (9 - (i // 4) * 4.5) * S
        svg.append(f'<rect x="{lx:.0f}" y="{ly:.0f}" width="{2.5 * S}" height="{2.5 * S}" fill="{c}"/><text x="{lx + 3.5 * S:.0f}" y="{ly + 2 * S:.0f}" font-size="{2.6 * S:.0f}" fill="#3a3834">{label}</text>')
    svg.append("</svg>")
    pathlib.Path(out).write_text("\n".join(svg))
    print("prévia:", out)


if __name__ == "__main__":
    main()
