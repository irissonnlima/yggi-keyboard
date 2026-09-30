#!/usr/bin/env python3
"""Desenha uma prévia SVG das placas (.kicad_pcb do Ergogen + contorno .dxf), sem dependências.

Uso: python3 tools/pcb_preview.py saida.svg placa1.kicad_pcb [placa2.kicad_pcb ...]
O contorno é lido do .dxf de mesmo nome em hardware/pcb/outlines/.
"""
import math
import pathlib
import re
import sys

COL = {"switch": "#3b7dd8", "diode": "#e39a2d", "pad": "#c9a227", "hole": "#1b1a18", "edge": "#2e8b57"}


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


def pads(path):
    s = open(path).read()
    out = []
    for m in s.split("(module ")[1:]:
        name = m.split()[0]
        at = re.search(r"\(at ([-\d.]+) ([-\d.]+)(?: ([-\d.]+))?\)", m)
        X, Y, R = float(at.group(1)), -float(at.group(2)), float(at.group(3) or 0)
        for line in m.splitlines():
            if "(pad " not in line:
                continue
            a = re.search(r"\(at ([-\d.]+) ([-\d.]+)", line)
            sz = re.search(r"\(size ([-\d.]+) ([-\d.]+)\)", line)
            dx, dy = float(a.group(1)), -float(a.group(2))
            r = math.radians(R)
            out.append((name, X + dx * math.cos(r) - dy * math.sin(r), Y + dx * math.sin(r) + dy * math.cos(r),
                        float(sz.group(1)), float(sz.group(2)), "circle" in line, "np_thru" in line))
    return out


def main():
    out, files = sys.argv[1], sys.argv[2:]
    root = pathlib.Path(files[0]).resolve().parents[1]
    boards, x_off, gap, S = [], 0, 14, 4
    for f in files:
        name = pathlib.Path(f).stem
        segs, circles = dxf_shapes(root / "outlines" / f"{name}.dxf")
        xs = [v for s in segs for v in (s[0], s[2])]
        ys = [v for s in segs for v in (s[1], s[3])]
        boards.append((name, segs, circles, pads(f), min(xs), max(xs), min(ys), max(ys)))
    total_w = sum(b[5] - b[4] for b in boards) + gap * (len(boards) - 1)
    ymin, ymax = min(b[6] for b in boards), max(b[7] for b in boards)
    W, H = (total_w + 20) * S, (ymax - ymin + 30) * S
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}" width="100%" font-family="sans-serif">',
           f'<rect width="{W:.0f}" height="{H:.0f}" fill="#f7f6f2"/>']
    x0 = 10
    for name, segs, circles, P, bx0, bx1, by0, by1 in boards:
        tx = lambda x: (x0 + x - bx0) * S
        ty = lambda y: (ymax - y + 10) * S
        for a, b, c, d in segs:
            svg.append(f'<line x1="{tx(a):.1f}" y1="{ty(b):.1f}" x2="{tx(c):.1f}" y2="{ty(d):.1f}" stroke="{COL["edge"]}" stroke-width="2"/>')
        for cx, cy, r in circles:
            svg.append(f'<circle cx="{tx(cx):.1f}" cy="{ty(cy):.1f}" r="{r * S:.1f}" fill="none" stroke="{COL["edge"]}" stroke-width="2"/>')
        for fp, x, y, w, h, circ, npth in P:
            c = COL["hole"] if npth else COL["switch"] if fp == "PG1350" else COL["diode"] if "Diode" in fp else COL["pad"]
            if circ:
                svg.append(f'<circle cx="{tx(x):.1f}" cy="{ty(y):.1f}" r="{w / 2 * S:.1f}" fill="{c}" opacity="{0.85 if npth else 0.9}"/>')
            else:
                svg.append(f'<rect x="{tx(x) - w / 2 * S:.1f}" y="{ty(y) - h / 2 * S:.1f}" width="{w * S:.1f}" height="{h * S:.1f}" fill="{c}"/>')
        svg.append(f'<text x="{tx((bx0 + bx1) / 2):.1f}" y="{ty(by0) + 7 * S:.1f}" font-size="{3.2 * S:.0f}" text-anchor="middle" fill="#3a3834">{name.replace("_", " ")}</text>')
        x0 += bx1 - bx0 + gap
    legend = [("contorno", COL["edge"]), ("pinos do switch Choc", COL["switch"]), ("diodo", COL["diode"]), ("pads da cadeia / MCU", COL["pad"]), ("furos", COL["hole"])]
    lx = 10 * S
    for label, c in legend:
        svg.append(f'<rect x="{lx}" y="{H - 5 * S}" width="{2.5 * S}" height="{2.5 * S}" fill="{c}"/><text x="{lx + 3.5 * S}" y="{H - 3 * S}" font-size="{2.6 * S:.0f}" fill="#3a3834">{label}</text>')
        lx += (len(label) * 1.7 + 9) * S
    svg.append("</svg>")
    pathlib.Path(out).write_text("\n".join(svg))
    print("prévia:", out)


if __name__ == "__main__":
    main()
