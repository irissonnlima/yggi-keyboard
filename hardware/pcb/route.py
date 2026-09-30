#!/usr/bin/env python3
"""Termina as placas do Yggi a partir da saída do Ergogen: peças extras, regras e trilhas.

Roda com o Python que vem com o KiCad (precisa do módulo pcbnew):

    KICAD=/Applications/KiCad/KiCad.app/Contents
    $KICAD/Frameworks/Python.framework/Versions/Current/bin/python3 hardware/pcb/route.py [placa ...]

Entrada: hardware/pcb/ergogen/output/<placa>/pcbs/<placa>.kicad_pcb (Ergogen, formato KiCad 5).
Saída:   hardware/pcb/kicad/<placa>.kicad_pcb (formato atual do KiCad, roteada) e o relatório do DRC.

Passos:
 1. Regras da JLCPCB (trilha 0,25, isolamento 0,2, via 0,6/0,3, vias cobertas) e espessura de
    1,2 mm (a do CAD).
 2. Troca o diodo "ComboDiode" do Ergogen (pads SMD nas duas faces + furos passantes, que o
    KiCad exige ligar entre si) por um SOD-123 só na face de baixo.
 3. Placa L: 3 LEDs 0805 (face de cima) + 3 resistores 0805 (face de baixo) na faixa entre a
    fileira F e a dos números, acima da tecla Yggi (CAD x = 4, 9 e 14 mm).
 4. Roteia com o Freerouting (sem interface) e importa as trilhas.
 5. Roda o DRC com o kicad-cli.
"""
import json
import os
import pathlib
import subprocess
import sys

import pcbnew

sys.stdout.reconfigure(encoding="utf-8")

HERE = pathlib.Path(__file__).resolve().parent
KICAD = pathlib.Path(os.environ.get("KICAD", "/Applications/KiCad/KiCad.app/Contents"))
if not KICAD.exists():
    KICAD = pathlib.Path("/opt/homebrew/Caskroom/kicad/10.0.6/KiCad/KiCad.app/Contents")
LIB = KICAD / "SharedSupport" / "footprints"
KICAD_CLI = KICAD / "MacOS" / "kicad-cli"
JAVA = os.environ.get("JAVA", "/opt/homebrew/opt/openjdk/bin/java")   # o /usr/bin/java do macOS é só um atalho
FREEROUTING = pathlib.Path(os.environ.get(
    "FREEROUTING", pathlib.Path.home() / ".local/share/freerouting/freerouting-2.4.1.jar"))
BUILD = HERE / "ergogen" / "output"

mm = pcbnew.FromMM

# Coordenadas do KiCad (y para baixo) -> CAD da placa L: x_cad = x + 9, y_cad = 25,5 - y.
BAND_Y = -61.75                       # centro da faixa entre F e números
LED_X = [-5.0, 0.0, 5.0]              # CAD x = 4, 9, 14 mm


def rules(board):
    ds = board.GetDesignSettings()
    ds.SetBoardThickness(mm(1.2))
    ds.m_TrackMinWidth = mm(0.15)
    ds.m_MinClearance = mm(0.15)
    ds.m_ViasMinSize = mm(0.5)
    ds.m_MinThroughDrill = mm(0.3)
    ds.m_CopperEdgeClearance = mm(0.5)
    ds.m_TentViasFront = ds.m_TentViasBack = True   # vias cobertas: a solda dos fios não escorre
    nc = ds.m_NetSettings.GetDefaultNetclass()
    nc.SetTrackWidth(mm(0.25))
    nc.SetClearance(mm(0.2))
    nc.SetViaDiameter(mm(0.6))
    nc.SetViaDrill(mm(0.3))


def load_fp(lib, name):
    return pcbnew.FootprintLoad(str(LIB / f"{lib}.pretty"), name)


def place(board, fp, ref, x, y, back=False, rot=0):
    fp.SetReference(ref)
    fp.thisown = False                    # a placa passa a ser dona do footprint (evita liberar duas vezes)
    board.Add(fp)
    if back:
        fp.Flip(fp.GetPosition(), pcbnew.FLIP_DIRECTION_LEFT_RIGHT)
    fp.SetOrientationDegrees(rot)
    fp.SetPosition(pcbnew.VECTOR2I(mm(x), mm(y)))
    return fp


def net(board, name):
    n = board.FindNet(name)
    if n is None:
        n = pcbnew.NETINFO_ITEM(board, name)
        board.Add(n)
    return n


def set_nets(fp, nets):
    for p in fp.Pads():
        if p.GetNumber() in nets:
            p.SetNet(nets[p.GetNumber()])


def replace_diodes(board):
    """ComboDiode -> SOD-123 na face de baixo, mesmo lugar e mesmo sentido (catodo = pad 1 = linha)."""
    for old in [f for f in board.GetFootprints() if f.GetFPIDAsString().endswith("ComboDiode")]:
        pads = {p.GetNumber(): p.GetNet() for p in old.Pads()}
        pos, ref = old.GetPosition(), old.GetReference()
        board.Delete(old)
        new = load_fp("Diode_SMD", "D_SOD-123")
        place(board, new, ref, pos.x / 1e6, pos.y / 1e6, back=True)
        # na face de baixo o footprint fica espelhado; gira para o catodo ficar à esquerda (-x)
        if new.FindPadByNumber("1").GetPosition().x > pos.x:
            new.SetOrientationDegrees(180)
        set_nets(new, pads)
        new.SetValue("1N4148W")


def add_leds(board):
    gnd = net(board, "GND")
    for i, x in enumerate(LED_X, 1):
        a = net(board, f"led{i}_a")
        led = place(board, load_fp("LED_SMD", "LED_0805_2012Metric"), f"LED{i}", x, BAND_Y)
        set_nets(led, {"1": gnd, "2": a})                  # pad 1 = catodo
        led.SetValue("LED 0805")
        r = place(board, load_fp("Resistor_SMD", "R_0805_2012Metric"), f"R{i}", x, BAND_Y, back=True)
        set_nets(r, {"1": net(board, f"LED{i}"), "2": a})
        r.SetValue("1k")


def keepout(board, x, y, r, n=24):
    """Área proibida (sem trilhas nem vias) circular nas duas faces. O Freerouting não aplica a
    folga de borda aos furos internos do contorno, então o furo do botão da trava precisa dela."""
    import math
    z = pcbnew.ZONE(board)
    z.SetIsRuleArea(True)
    z.SetDoNotAllowTracks(True)
    z.SetDoNotAllowVias(True)
    z.SetDoNotAllowZoneFills(True)
    z.SetDoNotAllowPads(False)
    z.SetDoNotAllowFootprints(False)
    ls = pcbnew.LSET()
    ls.AddLayer(pcbnew.F_Cu)
    ls.AddLayer(pcbnew.B_Cu)
    z.SetLayerSet(ls)
    poly = z.Outline()
    poly.NewOutline()
    for i in range(n):
        a = 2 * math.pi * i / n
        poly.Append(mm(x + r * math.cos(a)), mm(y + r * math.sin(a)))
    z.thisown = False
    board.Add(z)


def freeroute(board, work):
    dsn, ses = work / "board.dsn", work / "board.ses"
    if not pcbnew.ExportSpecctraDSN(board, str(dsn)):
        sys.exit("falha ao exportar o DSN")
    subprocess.run([JAVA, "-jar", str(FREEROUTING), "-de", str(dsn), "-do", str(ses), "-mp", "40",
                    "-mt", "1", "--gui.enabled=false"], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not pcbnew.ImportSpecctraSES(board, str(ses)):
        sys.exit("falha ao importar o SES")


def drc(path):
    rpt = path.with_suffix(".drc.json")
    subprocess.run([str(KICAD_CLI), "pcb", "drc", "--format", "json", "-o", str(rpt), str(path)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    d = json.loads(rpt.read_text())
    rpt.unlink()
    return d["violations"], d["unconnected_items"]


def finish(name):
    src = BUILD / name / "pcbs" / f"{name}.kicad_pcb"
    board = pcbnew.LoadBoard(str(src))
    rules(board)
    replace_diodes(board)
    if name == "placa_L":
        add_leds(board)
        keepout(board, 13, BAND_Y, 1.4 + 0.7)        # furo do botão da trava (CAD 22; 87,25)
    work = BUILD / name / "route"
    work.mkdir(exist_ok=True)
    freeroute(board, work)
    out = HERE / "kicad" / f"{name}.kicad_pcb"
    pcbnew.SaveBoard(str(out), board)
    for extra in (".kicad_pro", ".kicad_prl"):     # arquivos de projeto que o SaveBoard cria
        p = out.with_suffix(extra)
        if extra == ".kicad_prl" and p.exists():
            p.unlink()
    v, u = drc(out)
    txt = out.read_text()                          # (a lista de trilhas do SWIG não itera no KiCad 10)
    n_tracks = txt.count("(segment") + txt.count("(via")
    print(f"{name}: {n_tracks} trilhas/vias, DRC {len(v)} violações, {len(u)} sem ligação")
    for x in v + u:
        print("  -", x["description"], [i["description"] for i in x["items"]])
    return not v and not u


if __name__ == "__main__":
    names = sys.argv[1:] or ["coluna_1u", "coluna_2u", "placa_L"]
    ok = all([finish(n) for n in names])
    sys.exit(0 if ok else 1)
