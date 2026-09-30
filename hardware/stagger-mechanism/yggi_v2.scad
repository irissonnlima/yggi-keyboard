// Yggi Keyboard — mecanismo de stagger v2 (layout B, 7 + 7 colunas)
// Licença sugerida: CERN-OHL-S-2.0
//
// Conceito:
//  - Cada metade tem 4 GAVETAS móveis (colunas que deslizam inteiras em Y) e um BLOCO FIXO
//    de 2 colunas na ponta externa. Em 0% tudo forma um retângulo perfeito.
//  - As gavetas correm sobre um CHASSI imutável, escondido embaixo delas.
//  - Cada gaveta tem 2 pinos que atravessam rasgos em Y no chassi (guia) e rasgos inclinados
//    na PLACA-CAME (acionamento). Deslizar a placa em X faz todas as gavetas subirem na
//    proporção do perfil. A placa é movida por um cursor na borda da frente, sob a barra.
//  - A fileira do polegar é uma BARRA FIXA. Quando as gavetas sobem, a "saia" de cada uma
//    sai de baixo da barra e tampa o vão.
//  - À esquerda, uma baia de 4u × 6,5u recebe o e-reader destacável (tipo XTeink X4).
//
// Eixos (mm): X = entre colunas, Y = ao longo da coluna (+Y = longe do usuário), Z = para cima.
// Origem: canto frontal esquerdo de cada metade, na base da bandeja.

/* [Visualização] */
part = "assembly"; // [assembly, left, right, tray, cam_plate, chassis, gaveta, fixed_block, thumb_bar, bay, check]
stagger_pct = 100;  // [0:1:150]
explode = 0;        // [0:1:25]
show_caps = true;
show_ereader = true;
split_gap = 30;     // distância entre as metades na visualização
check = "gav_chassis"; // [gav_chassis, gav_bar, gav_fixed, gav_gav, cam_tray, cam_chassis, heads_tray, pins_cam]

/* [Grade] */
U = 18;             // passo em X (Choc)
P = 17;             // passo em Y (Choc)
// borda frontal de cada fileira: r0 = F, r1 = números, r2, r3, r4 = shift
ROW_Y = [89.5, 68, 51, 34, 17];

/* [Stagger] */
T = 24;             // curso da placa-came correspondente a 150%
// Gavetas móveis da metade esquerda: [x0, nº colunas, stagger em 150% (mm), pino_x, [pino_y1, pino_y2]]
// Pinos escolhidos por busca para os rasgos da placa nunca se cruzarem (folga mínima de 9 mm).
GAV = [
  [36, 1,  0, 40, [34, 68]],     // mindinho (Q A Z)
  [54, 1,  9, 68, [34, 87.25]],  // anelar
  [72, 1, 15, 86, [34, 51]],     // médio
  [90, 2,  9, 94, [68, 87.25]]   // indicador (R T / F G / V B)
];

/* [Espessuras e folgas] */
clr = 0.25;
side_gap = 0.3;
tray_floor = 1.6;
head_t = 1.0;  head_d = 5.5;   // cabeça do pino-parafuso (sob a placa-came)
cam_t = 2.5;
chassis_t = 2.5;
gav_h = 9.5;   gav_floor = 1.2;   wall = 1.2;   plate_t = 1.3;
skirt_t = 1.2; skirt_inset = 1.8;
pin_d = 3;
cut = 13.8;                    // furo do Choc V1
knob_x = 20;  knob_w = 8;  knob_out = 1.5;
det_x = 70;                    // posição da trava (mola) na borda da frente
led_d = 1.8;

$fn = 36;

// ---------- Derivados ----------
KB_W = 7 * U;
KB_H = ROW_Y[0] + P;           // 106,5
S_MAX = max([for (g = GAV) g[2]]);
skirt_len = S_MAX + 0.5;
slot_w = pin_d + 0.4;
Z_CAM = tray_floor + head_t + 0.2;
tray_h = Z_CAM + cam_t + 0.3;
Z_CH = tray_h;
Z_G = Z_CH + chassis_t;
bar_z = Z_G + skirt_t + 0.3;   // fundo da barra do polegar
bar_h = Z_G + gav_h - bar_z;
pin_len = chassis_t + cam_t + 0.3 + 0.1;
u = stagger_pct / 150;
t = u * T;

PX = [for (g = GAV) g[3]];
plate_x0 = min(PX) - T - slot_w / 2 - 1.5;
plate_x1 = max(PX) + slot_w / 2 + 1.5;
plate_y0 = min([for (g = GAV) min(g[4])]) - slot_w / 2 - 2;
plate_y1 = max([for (g = GAV) max(g[4]) + g[2]]) + slot_w / 2 + 2;
pocket_x0 = plate_x0 - clr;
pocket_x1 = plate_x1 + T + clr;
wire_y0 = plate_y1 + 0.6;      // canal de fios atrás da placa-came

function kc(r) = ROW_Y[r] + P / 2;

assert(pocket_x0 >= 3 && pocket_x1 <= KB_W - 3, "placa-came não cabe na bandeja");
assert(plate_y1 <= KB_H - 5, "placa-came invade o canal de fios");

// ---------- Peças comuns ----------

module choc_cut(x, y, z_top) {
    translate([x - cut / 2, y - cut / 2, z_top - plate_t - 1]) cube([cut, cut, plate_t + 2]);
}

module shell(x0, n) {  // caixa com fundo e placa, aberta por dentro
    w = n * U - 2 * side_gap;
    difference() {
        translate([x0 + side_gap, ROW_Y[4], 0]) cube([w, KB_H - ROW_Y[4], gav_h]);
        translate([x0 + side_gap + wall, ROW_Y[4] + wall, gav_floor])
            cube([w - 2 * wall, KB_H - ROW_Y[4] - 2 * wall, gav_h - gav_floor - plate_t]);
    }
}

// ---------- Gaveta móvel ----------

module gaveta(g) {
    x0 = g[0]; n = g[1];
    difference() {
        union() {
            shell(x0, n);
            // saia: uma língua por coluna, sai de baixo da barra quando a gaveta sobe
            for (c = [0:n - 1])
                translate([x0 + c * U + skirt_inset, ROW_Y[4] - skirt_len, 0])
                    cube([U - 2 * skirt_inset, skirt_len + wall, skirt_t]);
            for (py = g[4]) translate([g[3], py, -pin_len]) cylinder(d = pin_d, h = pin_len + 0.01);
        }
        for (c = [0:n - 1], r = [0:4]) choc_cut(x0 + c * U + U / 2, kc(r), gav_h);
        // saída dos fios (desce para o canal na bandeja)
        translate([x0 + n * U / 2 - 4, wire_y0 + 0.5, -1]) cube([8, 3, gav_floor + 2]);
    }
}

module gaveta_heads(g) {
    for (py = g[4]) translate([g[3], py, -pin_len - head_t]) cylinder(d = head_d, h = head_t);
}

// ---------- Bloco fixo (2 colunas da ponta) ----------
// rows: "pair" = duas teclas 1u, "2u" = uma tecla de 2u centralizada
module fixed_block(rows, leds = false) {
    difference() {
        shell(0, 2);
        for (r = [0:4]) {
            if (rows[r] == "2u") choc_cut(U, kc(r), gav_h);
            else for (c = [0, 1]) choc_cut(c * U + U / 2, kc(r), gav_h);
        }
        // 3 LEDs de aparelho, entre a fileira F e a dos números, acima da tecla Yggi
        if (leds) for (i = [-1:1]) translate([U / 2 + i * 5, (ROW_Y[1] + P + ROW_Y[0]) / 2, gav_h - plate_t - 1])
            cylinder(d = led_d, h = plate_t + 2);
    }
}

// ---------- Barra do polegar (fixa) ----------
// keys: [x, largura_u, tipo] com tipo "f" (inteira), "lo" (meia, embaixo), "up" (meia, em cima)
module thumb_bar(keys) {
    depth = ROW_Y[4] - side_gap;
    difference() {
        cube([KB_W, depth, bar_h]);
        translate([wall, wall, gav_floor]) cube([KB_W - 2 * wall, depth - 2 * wall, bar_h - gav_floor - plate_t]);
        for (k = keys) {
            cx = k[0] + k[1] * U / 2;
            if (k[2] == "f") choc_cut(cx, P / 2, bar_h);
            else translate([cx - 6, (k[2] == "lo" ? P / 4 : 3 * P / 4) - 3, bar_h - plate_t - 1])
                cube([12, 6, plate_t + 2]);  // meia-altura: switch menor, a definir
        }
    }
}

// ---------- Chassi imutável ----------

module chassis() {
    difference() {
        cube([KB_W, KB_H, chassis_t]);
        for (g = GAV, py = g[4]) hull() {
            translate([g[3], py, -1]) cylinder(d = slot_w, h = chassis_t + 2);
            translate([g[3], py + g[2], -1]) cylinder(d = slot_w, h = chassis_t + 2);
        }
        // passagem dos fios de cada gaveta para o canal da bandeja
        for (g = GAV) translate([g[0] + g[1] * U / 2 - 5, wire_y0, -1]) cube([10, KB_H, chassis_t + 2]);
    }
    // apoio da barra do polegar: bloco sob as colunas fixas + nervuras entre as saias
    rib_h = bar_z - Z_G;
    translate([0, 0.5, chassis_t - 0.01]) cube([2 * U + skirt_inset - 0.6, ROW_Y[4] - 0.8, rib_h]);
    for (g = GAV, c = [1:g[1]]) {
        x = g[0] + c * U;
        w = (x >= KB_W) ? 1.2 : 2.4;
        translate([x >= KB_W ? KB_W - 1.2 : x - 1.2, 0.5, chassis_t - 0.01]) cube([w, ROW_Y[4] - 0.8, rib_h]);
    }
}

// ---------- Placa-came ----------

module cam_plate() {
    difference() {
        translate([plate_x0, plate_y0, 0]) cube([plate_x1 - plate_x0, plate_y1 - plate_y0, cam_t]);
        for (g = GAV, py = g[4]) hull() {
            translate([g[3], py, -1]) cylinder(d = slot_w, h = cam_t + 2);
            translate([g[3] - T, py + g[2], -1]) cylinder(d = slot_w, h = cam_t + 2);
        }
        // entalhes da trava: 0%, 50%, 100%, 150%
        for (f = [0, 1/3, 2/3, 1]) translate([det_x - f * T, plate_y0, -1]) cylinder(r = 1.2, h = cam_t + 2);
    }
    // cursor: sai pela borda da frente, embaixo da barra do polegar
    translate([knob_x, -knob_out, 0]) cube([knob_w, plate_y0 + knob_out + 0.01, cam_t]);
}

// ---------- Bandeja (fundo) ----------

module tray() {
    pf = plate_y0 - clr;
    difference() {
        cube([KB_W, KB_H, tray_h]);
        translate([pocket_x0, pf, tray_floor]) cube([pocket_x1 - pocket_x0, plate_y1 - plate_y0 + 2 * clr, tray_h]);
        // janela do cursor
        translate([knob_x - clr, -1, Z_CAM - 0.2]) cube([knob_w + T + 2 * clr, pf + 1.1, tray_h]);
        // canal de fios (atrás da placa), leva até o bloco fixo
        translate([2, wire_y0, tray_floor]) cube([KB_W - 4, KB_H - wire_y0 - 1.2, tray_h]);
        // mola da trava
        translate([det_x - 12, pf - 2.2, -1]) cube([15, 1, tray_h + 2]);
        translate([det_x + 2, pf - 2.2, -1]) cube([1, 2.3, tray_h + 2]);
        translate([det_x - 12, pf - 0.01, -1]) cube([15, 1, tray_floor + 1.01]);
        translate([det_x - 12, pf - 1.3, tray_h - 0.4]) cube([15, 1.4, 1]);
    }
    translate([det_x, pf, tray_floor]) cylinder(r = 1, h = tray_h - tray_floor - 0.4);
}

// ---------- Baia do e-reader ----------
BAY_W = 4 * U;  BAY_H = 6.5 * U;
ER = [69, 114, 5.9];           // XTeink X4
module bay() {
    top = Z_G + gav_h;
    pd = 3;
    difference() {
        cube([BAY_W, BAY_H, top]);
        translate([2, 2, tray_floor]) cube([BAY_W - 4, BAY_H - 4, top - tray_floor - pd - 2.5]);
        translate([(BAY_W - ER[0]) / 2 - 0.3, (BAY_H - ER[1]) / 2 - 0.3, top - pd])
            cube([ER[0] + 0.6, ER[1] + 0.6, pd + 1]);
        // ímãs 6×2 mm
        for (x = [12, BAY_W - 12], y = [16, BAY_H - 16]) translate([x, y, top - pd - 2.2]) cylinder(d = 6.2, h = 2.3);
        // pinos pogo (5) na borda interna
        for (i = [-2:2]) translate([BAY_W - 8, BAY_H / 2 + i * 2.54, top - pd - 3]) cylinder(d = 1.6, h = 4);
        // entalhe para tirar o e-reader
        translate([BAY_W / 2, -1, top]) rotate([-90, 0, 0]) cylinder(r = 8, h = 8);
    }
}

// ---------- Layout das metades ----------
LEFT_FIXED  = ["pair", "pair", "2u", "2u", "2u"];     // esc F1 / Yggi ` / tab / caps / shift
RIGHT_FIXED = ["pair", "pair", "pair", "pair", "2u"]; // F12 lock / - = / [ ] / ' \ / shift
LEFT_BAR  = [[0,1,"f"],[18,1,"f"],[36,1,"f"],[54,1,"f"],[72,1.5,"f"],[99,1.5,"f"]];    // fn ⌃ ⌥ ⌘ ⌫ ␣
RIGHT_BAR = [[0,1.5,"f"],[27,1.5,"f"],[54,1,"f"],[72,1,"lo"],[90,1,"up"],[90,1,"lo"],[108,1,"lo"]]; // ␣ ↩ ⌘ ← ↑ ↓ →

module caps_for(x0, n, rows_2u = []) {
    for (c = [0:n - 1], r = [0:4])
        %translate([x0 + c * U + 0.25, ROW_Y[r] + 0.25, gav_h + 3]) cube([U - 0.5, P - 0.5, 2.5]);
}

module mech(fixed_rows, leds, e = explode) {
    color("gainsboro") tray();
    color("orange") translate([t, 0, Z_CAM + e]) cam_plate();
    color("silver") translate([0, 0, Z_CH + 2 * e]) chassis();
    for (g = GAV) translate([0, g[2] * u, Z_G + 3 * e]) {
        color("steelblue") gaveta(g);
        color("dimgray") gaveta_heads(g);
        if (show_caps) caps_for(g[0], g[1]);
    }
    translate([0, 0, Z_G + 3 * e]) {
        color("slategray") fixed_block(fixed_rows, leds);
        if (show_caps) caps_for(0, 2);
    }
    if (leds) for (i = [-1:1]) color("lime")
        translate([U / 2 + i * 5, (ROW_Y[1] + P + ROW_Y[0]) / 2, Z_G + 3 * e + gav_h - 0.2]) cylinder(d = led_d - 0.2, h = 0.4);
}

module left_half(e = explode) {
    mech(LEFT_FIXED, true, e);
    color("lightsteelblue") translate([0, 0, bar_z + 4 * e]) thumb_bar(LEFT_BAR);
    translate([-BAY_W - 3, (KB_H - BAY_H) / 2, 0]) {
        color("gainsboro") bay();
        if (show_ereader) color("white", 0.9)
            translate([(BAY_W - ER[0]) / 2, (BAY_H - ER[1]) / 2, Z_G + gav_h - 3 + 5 * e]) cube(ER);
    }
}

module right_half(e = explode) {
    translate([KB_W, 0, 0]) mirror([1, 0, 0]) mech(RIGHT_FIXED, false, e);
    color("lightsteelblue") translate([0, 0, bar_z + 4 * e]) thumb_bar(RIGHT_BAR);
}

// ---------- Verificação de colisões (use com -D part="check") ----------
module check_pair() {
    if (check == "gav_chassis") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G + 0.01]) gaveta(g);
        translate([0, 0, Z_CH]) chassis();
    }
    if (check == "gav_bar") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G + 0.01]) gaveta(g);
        translate([0, 0, bar_z]) thumb_bar(LEFT_BAR);
    }
    if (check == "gav_fixed") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G]) gaveta(g);
        translate([0, 0, Z_G]) fixed_block(LEFT_FIXED, true);
    }
    if (check == "gav_gav") for (i = [0:len(GAV) - 2]) intersection() {
        translate([0, GAV[i][2] * u, 0]) gaveta(GAV[i]);
        translate([0, GAV[i + 1][2] * u, 0]) gaveta(GAV[i + 1]);
    }
    if (check == "cam_tray") intersection() { translate([t, 0, Z_CAM]) cam_plate(); tray(); }
    if (check == "cam_chassis") intersection() { translate([t, 0, Z_CAM]) cam_plate(); translate([0, 0, Z_CH]) chassis(); }
    if (check == "heads_tray") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G]) gaveta_heads(g);
        union() { tray(); translate([t, 0, Z_CAM]) cam_plate(); }
    }
    if (check == "pins_cam") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G]) gaveta(g);
        translate([t, 0, Z_CAM]) cam_plate();
    }
}

if (part == "assembly") { left_half(); translate([KB_W + split_gap, 0, 0]) right_half(); }
else if (part == "left") left_half();
else if (part == "right") right_half();
else if (part == "tray") tray();
else if (part == "cam_plate") cam_plate();
else if (part == "chassis") chassis();
else if (part == "gaveta") gaveta(GAV[2]);
else if (part == "fixed_block") fixed_block(LEFT_FIXED, true);
else if (part == "thumb_bar") thumb_bar(RIGHT_BAR);
else if (part == "bay") bay();
else if (part == "check") check_pair();
