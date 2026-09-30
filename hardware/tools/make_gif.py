#!/usr/bin/env python3
"""Junta PNGs (saída do OpenSCAD) num GIF animado, sem dependências externas.

Uso: python3 hardware/tools/make_gif.py saida.gif quadro1.png quadro2.png ... [--delay 12] [--pingpong]
"""
import struct
import sys
import zlib


def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "não é PNG"
    pos, idat = 8, b""
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
            assert depth == 8 and interlace == 0 and ctype in (2, 6), "PNG não suportado"
        elif kind == b"IDAT":
            idat += chunk
        pos += 12 + length
    bpp = 3 if ctype == 2 else 4
    raw, stride = zlib.decompress(idat), w * bpp
    rows, prev = [], bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    px = [(r[i], r[i + 1], r[i + 2]) for r in rows for i in range(0, stride, bpp)]
    return w, h, px


def build_palette(frames):
    count = {}
    for _, _, px in frames:
        for p in px[::3]:
            k = (p[0] >> 3, p[1] >> 3, p[2] >> 3)
            count[k] = count.get(k, 0) + 1
    top = sorted(count, key=count.get, reverse=True)[:256]
    return [((r << 3) | 4, (g << 3) | 4, (b << 3) | 4) for r, g, b in top]


def index_frame(px, pal, cache):
    out = bytearray(len(px))
    for i, p in enumerate(px):
        k = (p[0] >> 3, p[1] >> 3, p[2] >> 3)
        idx = cache.get(k)
        if idx is None:
            c = ((k[0] << 3) | 4, (k[1] << 3) | 4, (k[2] << 3) | 4)
            idx = min(range(len(pal)), key=lambda j: (pal[j][0] - c[0]) ** 2 + (pal[j][1] - c[1]) ** 2 + (pal[j][2] - c[2]) ** 2)
            cache[k] = idx
        out[i] = idx
    return out


def lzw(indices, min_size=8):
    clear, eoi = 1 << min_size, (1 << min_size) + 1
    table = {bytes([i]): i for i in range(clear)}
    size, nxt = min_size + 1, eoi + 1
    out, buf, nbits = bytearray(), 0, 0

    def emit(code):
        nonlocal buf, nbits
        buf |= code << nbits
        nbits += size
        while nbits >= 8:
            out.append(buf & 255)
            buf >>= 8
            nbits -= 8

    emit(clear)
    w = bytes([indices[0]])
    for b in indices[1:]:
        wb = w + bytes([b])
        if wb in table:
            w = wb
            continue
        emit(table[w])
        if nxt < 4096:
            table[wb] = nxt
            nxt += 1
            if nxt > (1 << size) and size < 12:
                size += 1
        else:
            emit(clear)
            table = {bytes([i]): i for i in range(clear)}
            size, nxt = min_size + 1, eoi + 1
        w = bytes([b])
    emit(table[w])
    emit(eoi)
    if nbits:
        out.append(buf & 255)
    return bytes(out)


def main():
    args = sys.argv[1:]
    delay = 12
    if "--delay" in args:
        i = args.index("--delay")
        delay = int(args[i + 1])
        del args[i:i + 2]
    pingpong = "--pingpong" in args
    if pingpong:
        args.remove("--pingpong")
    out, files = args[0], args[1:]
    frames = [read_png(f) for f in files]
    w, h, _ = frames[0]
    pal = build_palette(frames)
    pal += [(0, 0, 0)] * (256 - len(pal))
    order = list(range(len(frames)))
    if pingpong:
        order += order[-2:0:-1]
    cache, encoded = {}, {}
    gif = bytearray(b"GIF89a" + struct.pack("<HHBBB", w, h, 0xF7, 0, 0))
    gif += bytes(c for p in pal for c in p)
    gif += b"\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00"
    for n, i in enumerate(order):
        if i not in encoded:
            encoded[i] = lzw(index_frame(frames[i][2], pal, cache))
        hold = delay * 6 if n in (0, len(frames) - 1) else delay
        gif += b"\x21\xf9\x04\x04" + struct.pack("<H", hold) + b"\x00\x00"
        gif += b"\x2c" + struct.pack("<HHHHB", 0, 0, w, h, 0) + b"\x08"
        data = encoded[i]
        for k in range(0, len(data), 255):
            block = data[k:k + 255]
            gif += bytes([len(block)]) + block
        gif += b"\x00"
    gif += b"\x3b"
    open(out, "wb").write(gif)
    print(f"{out}: {len(order)} quadros, {len(gif) // 1024} KB")


if __name__ == "__main__":
    main()
