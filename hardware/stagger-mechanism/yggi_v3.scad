// Yggi Keyboard — mecanismo de stagger v3 (layout B, 7 + 7 colunas + baia do e-reader)
// Licença sugerida: CERN-OHL-S-2.0
//
// O que muda em relação ao v2:
//  - FINO: a placa de circuito de cada gaveta é o próprio "plate" (switch Choc montado na PCB,
//    com soquetes hot-swap embaixo). Placa-came e chassi em chapa fina (FR4 no protótipo).
//  - MOLA: uma mola de força constante puxa a placa-came para o stagger. Em ortho uma trava
//    segura a placa. O botão ao lado dos LEDs empurra a trava e as colunas sobem sozinhas até o
//    batente (50/100/150%). Para voltar, empurra-se as colunas até ouvir o clique.
//  - INCLINAÇÃO: bateria, microcontrolador e mola ficam numa cunha na parte de trás (5°).
//  - MÓDULOS: faces de encaixe retas (ímãs + pogo), bordas externas arredondadas.
//
// Eixos (mm): X = entre colunas, Y = ao longo da coluna (+Y = longe do usuário), Z = para cima.
// Tudo é modelado num "quadro plano"; a inclinação é aplicada só na montagem.

/* [Visualização] */
part = "assembly"; // [assembly, left, right, front, tray, cam_plate, chassis, gaveta, fixed_block, thumb_bar, wedge_left, bay, check]
stagger_pct = 100;  // [0:1:150]
stop_pct = 100;     // [50, 100, 150] batente escolhido
explode = 0;        // [0:1:25]
joined = true;      // metades encostadas (true) ou separadas
show_caps = true;
show_ereader = true;
show_internals = false; // mostra bateria, MCU e mola (use com explode ou transparência)
check = "gav_chassis"; // [gav_chassis, gav_bar, gav_fixed, gav_gav, cam_tray, cam_chassis, heads_tray, pins_cam, pawl_cam, stop_cam, strip_tray, plunger_cam]

/* [Grade] */
U = 18;
P = 17;
ROW_Y = [89.5, 68, 51, 34, 17];      // borda frontal de r0 (F) … r4 (shift)

/* [Stagger] */
T = 24;                              // curso da placa-came para 150%
GAV = [                              // [x0, colunas, stagger 150%, pino_x, [pino_y1, pino_y2]]
  [36, 1,  0, 40, [34, 68]],         // mindinho
  [54, 1,  9, 68, [34, 87.25]],      // anelar
  [72, 1, 15, 86, [34, 51]],         // médio
  [90, 2,  9, 94, [68, 87.25]]       // indicador
];

/* [Pilha fina] */
tilt = 5;
clr = 0.25;
side_gap = 0.3;
tray_floor = 1.2;
head_t = 0.6;  head_d = 5;
cam_t = 1.2;                         // FR4 1,2 mm ou aço
chassis_t = 1.6;                     // FR4 1,6 mm
sled_floor = 1.0; sled_wall = 1.0;
sock_h = 1.8;                        // soquete hot-swap Choc
pcb_t = 1.2;
skirt_t = 0.8; skirt_inset = 1.8;
pin_d = 3;
corner_r = 6;

/* [Bateria e eletrônica] */
BATT = [76, 46, 4.0];                // ~1800 mAh (LiPo 4 mm); ajuste conforme o fornecedor
MCU = [18, 34, 3.6];                 // placa nRF52840 tipo "Pro Micro"/nice!nano
led_d = 1.8;
latch = [30, 87.25];                 // trava + botão (no bloco fixo, entre F e números)

$fn = 32;

// ---------- Derivados ----------
KB_W = 7 * U;
KB_H = ROW_Y[0] + P;
S_MAX = max([for (g = GAV) g[2]]);
skirt_len = S_MAX + 0.5;
slot_w = pin_d + 0.4;
Z_CAM = tray_floor + head_t + 0.2;
tray_h = Z_CAM + cam_t + 0.2;
Z_CH = tray_h;
Z_G = Z_CH + chassis_t;
gav_h = sled_floor + sock_h + pcb_t;
bar_z = Z_G + skirt_t + 0.2;
TOP = Z_G + gav_h;                   // topo das PCBs (base dos switches)
pin_len = Z_G - (tray_floor + 0.05 + head_t);
u = stagger_pct / 150;
t = u * T;
PX = [for (g = GAV) g[3]];
plate_x0 = min(PX) - T - slot_w / 2 - 1.5;
plate_x1 = max(PX) + slot_w / 2 + 1.5;
plate_y0 = min([for (g = GAV) min(g[4])]) - slot_w / 2 - 2;
plate_y1 = max([for (g = GAV) max(g[4]) + g[2]]) + slot_w / 2 + 2;
pocket_x0 = plate_x0 - clr;
pocket_x1 = plate_x1 + T + clr;
ch_y0 = plate_y1 + 0.6;              // canal de trás: fita da mola + fios
ch_y1 = KB_H - 1.2;
drum = [118, (ch_y0 + ch_y1) / 2, 8]; // tambor da mola de força constante (eixo em Y)
stop_x = function (pct) plate_x1 + pct / 150 * T + 1.5 + clr;
BAY_W = 4 * U;  BAY_H = 6.5 * U;
ER = [69, 114, 5.9];                 // XTeink X4
Y_PIV = (KB_H - BAY_H) / 2;          // pivô da inclinação (frente da baia)

function kc(r) = ROW_Y[r] + P / 2;

assert(pocket_x0 >= 3 && pocket_x1 <= KB_W - 3);
assert(latch[0] - 1.5 > plate_x0 && latch[0] < 36 - 3);

// ---------- Utilitários ----------

module fp(round_left = false, w = KB_W, h = KB_H) {       // contorno 2D
    if (round_left) hull() {
        translate([corner_r, corner_r]) circle(r = corner_r);
        translate([corner_r, h - corner_r]) circle(r = corner_r);
        translate([w - 1, 0]) square([1, h]);
    } else square([w, h]);
}
module clip(round_left, z0 = -20, z1 = 40) {
    intersection() { union() children(); translate([0, 0, z0]) linear_extrude(z1 - z0) fp(round_left); }
}
module tilt_frame() { translate([0, Y_PIV, 0]) rotate([tilt, 0, 0]) translate([0, -Y_PIV, 0]) children(); }

// ---------- Gaveta e bloco fixo: trenó impresso + PCB ----------

module sled(x0, n) {
    w = n * U - 2 * side_gap;
    difference() {
        translate([x0 + side_gap, ROW_Y[4], 0]) cube([w, KB_H - ROW_Y[4], sled_floor + sock_h]);
        translate([x0 + side_gap + sled_wall, ROW_Y[4] + sled_wall, sled_floor])
            cube([w - 2 * sled_wall, KB_H - ROW_Y[4] - 2 * sled_wall, sock_h + 1]);
    }
}
module pcb(x0, n) {
    color("darkgreen") translate([x0 + side_gap, ROW_Y[4], sled_floor + sock_h])
        cube([n * U - 2 * side_gap, KB_H - ROW_Y[4], pcb_t]);
}

module gaveta(g) {
    x0 = g[0]; n = g[1];
    difference() {
        color("steelblue") union() {
            sled(x0, n);
            for (c = [0:n - 1])                                   // saia
                translate([x0 + c * U + skirt_inset, ROW_Y[4] - skirt_len, 0])
                    cube([U - 2 * skirt_inset, skirt_len + sled_wall, skirt_t]);
            for (py = g[4]) translate([g[3], py, -pin_len]) cylinder(d = pin_d, h = pin_len + 0.01);
        }
        translate([x0 + n * U / 2 - 4, ch_y0 + 0.5, -1]) cube([8, 3, sled_floor + 2]);  // saída de fios
    }
    pcb(x0, n);
}
module gaveta_heads(g) { for (py = g[4]) translate([g[3], py, -pin_len - head_t]) cylinder(d = head_d, h = head_t); }

module fixed_block(round_left, leds) {
    clip(round_left) difference() {
        union() { color("slategray") sled(0, 2); pcb(0, 2); }
        translate([latch[0], latch[1], -1]) cylinder(d = 2.8, h = 20);           // botão da trava
    }
    if (leds) for (i = [-1:1]) color("lime") translate([U / 2 + i * 5 - 0.8, latch[1] - 0.5, gav_h]) cube([1.6, 1, 0.6]);
}

// ---------- Barra do polegar (fixa, apoiada em pernas entre as saias) ----------
module thumb_bar(round_left) {
    depth = ROW_Y[4] - side_gap;
    clip(round_left) {
        translate([0, 0, bar_z]) difference() {
            cube([KB_W, depth, TOP - bar_z]);
            translate([1, 1, -1]) cube([KB_W - 2, depth - 2, TOP - bar_z + 2]);
        }
        color("darkgreen") translate([1, 1, TOP - pcb_t]) cube([KB_W - 2, depth - 2, pcb_t]);
        // pernas: bloco sob as colunas fixas + uma perna em cada divisa entre saias
        translate([0, 0.5, Z_G]) cube([2 * U + skirt_inset - 0.6, depth - 1, bar_z - Z_G + 0.01]);
        for (g = GAV, c = [1:g[1]]) {
            x = g[0] + c * U;
            translate([x >= KB_W ? KB_W - 1.2 : x - 1.2, 0.5, Z_G]) cube([x >= KB_W ? 1.2 : 2.4, depth - 1, bar_z - Z_G + 0.01]);
        }
    }
}

// ---------- Chassi imutável (chapa) ----------
module chassis(round_left) {
    clip(round_left) difference() {
        cube([KB_W, KB_H, chassis_t]);
        for (g = GAV, py = g[4]) hull() {
            translate([g[3], py, -1]) cylinder(d = slot_w, h = chassis_t + 2);
            translate([g[3], py + g[2], -1]) cylinder(d = slot_w, h = chassis_t + 2);
        }
        for (g = GAV) translate([g[0] + g[1] * U / 2 - 5, ch_y0, -1]) cube([10, KB_H, chassis_t + 2]);
        translate([latch[0], latch[1], -1]) cylinder(d = 2.8, h = chassis_t + 2);
    }
}

// ---------- Placa-came (chapa) ----------
module cam_plate() {
    difference() {
        union() {
            translate([plate_x0, plate_y0, 0]) cube([plate_x1 - plate_x0, plate_y1 - plate_y0, cam_t]);
            translate([plate_x0 + 0.7, plate_y1 - 0.5, 0]) cube([6, ch_y0 + 3.2 - plate_y1, cam_t]);  // aba da fita
        }
        for (g = GAV, py = g[4]) hull() {
            translate([g[3], py, -1]) cylinder(d = slot_w, h = cam_t + 2);
            translate([g[3] - T, py + g[2], -1]) cylinder(d = slot_w, h = cam_t + 2);
        }
        translate([latch[0], latch[1], -1]) cylinder(d = 3.0, h = cam_t + 2);      // furo da trava
    }
}

// ---------- Mola de força constante ----------
module spring_ribbon() {
    color("silver") {
        translate([drum[0], drum[1] - 1.5, Z_CAM + cam_t / 2 - drum[2] / 2]) rotate([-90, 0, 0]) cylinder(d = drum[2], h = 3);
        translate([plate_x0 + 6.7 + t, drum[1] - 1.5, Z_CAM + cam_t / 2 - 0.1]) cube([drum[0] - plate_x0 - 6.7 - t, 3, 0.2]);
    }
}

// ---------- Trava: lingueta flexível na bandeja + botão ----------
module pawl(released) {
    translate([0, 0, released ? -(cam_t + 0.2) : 0]) {
        translate([latch[0] - 2, latch[1] - 1.5, 0]) cube([46.2 - latch[0] + 2, 3, tray_floor]);
        translate([latch[0], latch[1], tray_floor - 0.01]) cylinder(d = 2.6, h = Z_CAM + cam_t - tray_floor);
    }
}
module plunger(pressed) {
    color("tomato") translate([latch[0], latch[1], (pressed ? -(cam_t + 0.4) : 0)]) {
        translate([0, 0, tray_h + 0.05]) cylinder(d = 2.4, h = TOP + 0.6 - tray_h - 0.05);
        translate([0, 0, TOP + 0.05]) cylinder(d = 4, h = 0.8);
    }
}
module stop_pin(pct) { if (pct < 150) color("tomato") translate([stop_x(pct), 45, -4]) cylinder(d = 3, h = Z_CAM + cam_t - 0.2 + 4); }

// ---------- Bandeja ----------
module tray(round_left, faces, released = false) {
    clip(round_left) difference() {
        cube([KB_W, KB_H, tray_h]);
        translate([pocket_x0, plate_y0 - clr, tray_floor]) cube([pocket_x1 - pocket_x0, ch_y0 + 0.1 - plate_y0 + clr, tray_h]);
        translate([2, ch_y0, tray_floor]) cube([KB_W - 4, ch_y1 - ch_y0, tray_h]);
        translate([drum[0] - 5, ch_y0, -1]) cube([10, ch_y1 - ch_y0, tray_floor + 2]);        // tambor desce p/ a cunha
        translate([latch[0] - 2.5, latch[1] - 2, -1]) cube([46 - latch[0] + 2.5, 4, tray_floor + 2]); // janela da trava
        for (p = [50, 100]) translate([stop_x(p), 45, -1]) cylinder(d = 3.2, h = tray_floor + 2);
        connectors(faces, tray_h);
    }
    pawl(released);
}

// ímãs 4×2 mm e 4 contatos pogo nas faces de encaixe (x = 0 e/ou x = KB_W)
module connectors(faces, h) {
    for (f = faces) {
        x = f == "L" ? -0.01 : KB_W - 2.2;
        for (y = [20, 88]) translate([x, y, h / 2 + 0.3]) rotate([0, 90, 0]) cylinder(d = 4.1, h = 2.21);
        for (i = [0:3]) translate([f == "L" ? -0.01 : KB_W - 3, 45 + i * 2.5, 1.8]) rotate([0, 90, 0]) cylinder(d = 1.3, h = 3.01);
    }
}

// ---------- Cunha traseira (bateria, MCU, mola) — no quadro do mundo ----------
module wedge_pockets() {                              // no quadro plano, abaixo da bandeja
    translate([48, 54, -BATT[2] - 0.2]) cube([BATT[0], BATT[1], BATT[2] + 0.21]);
    translate([4, 66, -MCU[2] - 0.2]) cube([MCU[0], MCU[1], MCU[2] + 0.21]);
    translate([8.5, 96, -MCU[2]]) cube([9, 20, 3.2]);                               // USB-C para trás
    translate([latch[0] - 2.5, latch[1] - 2, -2.2]) cube([46 - latch[0] + 2.5, 4, 2.21]);  // curso da lingueta
    translate([drum[0] - 5, ch_y0, -drum[2] - 0.5]) cube([10, ch_y1 - ch_y0, drum[2] + 0.51]);
    for (p = [50, 100]) translate([stop_x(p), 45, -20]) cylinder(d = 3.2, h = 20.1);
}
module wedge(round_left) {
    difference() {
        hull() {
            tilt_frame() translate([0, 0, -0.01]) linear_extrude(0.01) fp(round_left);
            translate([0, Y_PIV, 0]) scale([1, cos(tilt), 1]) translate([0, -Y_PIV, 0]) linear_extrude(0.01) fp(round_left);
        }
        tilt_frame() wedge_pockets();
    }
}
module internals() {
    tilt_frame() {
        color("mediumseagreen") translate([48, 54, -BATT[2] - 0.2]) cube(BATT);
        color("royalblue") translate([4, 66, -MCU[2] - 0.2]) cube(MCU);
    }
}

// ---------- Baia do e-reader ----------
module bay_body() {
    top = TOP;
    pd = 3;
    difference() {
        linear_extrude(top) fp(true, BAY_W, BAY_H);
        translate([2, 2, tray_floor]) cube([BAY_W - 4, BAY_H - 4, top - tray_floor - pd - 1.2]);
        translate([(BAY_W - ER[0]) / 2 - 0.3, (BAY_H - ER[1]) / 2 - 0.3, top - pd]) cube([ER[0] + 0.6, ER[1] + 0.6, pd + 1]);
        for (x = [12, BAY_W - 12], y = [16, BAY_H - 16]) translate([x, y, top - pd - 1.6]) cylinder(d = 5.2, h = 1.7);
        for (i = [-2:2]) translate([BAY_W - 8, BAY_H / 2 + i * 2.54, top - pd - 2]) cylinder(d = 1.5, h = 3);
        translate([BAY_W / 2, -1, top]) rotate([-90, 0, 0]) cylinder(r = 8, h = 8);
        translate([BAY_W - KB_W, -Y_PIV, 0]) connectors(["R"], tray_h);
    }
}
module bay_wedge() {
    hull() {
        tilt_frame() translate([-BAY_W, Y_PIV, -0.01]) linear_extrude(0.01) fp(true, BAY_W, BAY_H);
        translate([-BAY_W, Y_PIV, 0]) scale([1, cos(tilt), 1]) linear_extrude(0.01) fp(true, BAY_W, BAY_H);
    }
}

// ---------- Montagem ----------
LEFT_FACES = ["L", "R"];
RIGHT_FACES = ["R"];

module caps(x0, n, dy = 0) {
    for (c = [0:n - 1], r = [0:4]) {
        %translate([x0 + c * U + 1.75, ROW_Y[r] + 1.25 + dy, TOP]) cube([U - 3.5, P - 2.5, 3]);
        %translate([x0 + c * U + 0.25, ROW_Y[r] + 0.25 + dy, TOP + 3.8]) cube([U - 0.5, P - 0.5, 2.4]);
    }
}
module bar_caps(keys) {
    for (k = keys) %translate([k[0] + 0.25, (k[2] == "up" ? P / 2 : 0) + 0.25, TOP + 3.8])
        cube([k[1] * U - 0.5, (k[2] == "f" ? P : P / 2) - 0.5, 2.4]);
}
LEFT_BAR  = [[0,1,"f"],[18,1,"f"],[36,1,"f"],[54,1,"f"],[72,1.5,"f"],[99,1.5,"f"]];
RIGHT_BAR = [[0,1.5,"f"],[27,1.5,"f"],[54,1,"f"],[72,1,"lo"],[90,1,"up"],[90,1,"lo"],[108,1,"lo"]];

module mech_flat(round_left, faces, leds, e) {
    released = t > 0.01;
    color("gainsboro") tray(round_left, faces, released);
    color("orange") translate([t, 0, Z_CAM + e]) cam_plate();
    translate([0, 0, e]) spring_ribbon();
    stop_pin(stop_pct);
    color("silver", 0.95) translate([0, 0, Z_CH + 2 * e]) chassis(round_left);
    for (g = GAV) translate([0, g[2] * u, Z_G + 3 * e]) {
        gaveta(g);
        color("dimgray") gaveta_heads(g);
        if (show_caps) caps(g[0], g[1]);
    }
    translate([0, 0, Z_G + 3 * e]) { fixed_block(round_left, leds); if (show_caps) caps(0, 2); }
    translate([0, 0, 3 * e]) plunger(false);
}

module left_half(e = explode) {
    tilt_frame() {
        mech_flat(false, LEFT_FACES, true, e);
        color("lightsteelblue") translate([0, 0, 4 * e]) thumb_bar(false);
        if (show_caps) translate([0, 0, 4 * e]) bar_caps(LEFT_BAR);
    }
    color("whitesmoke") translate([0, 0, -2 * e]) wedge(false);
    if (show_internals) translate([0, 0, -2 * e]) internals();
}
module right_half(e = explode) {
    translate([KB_W, 0, 0]) mirror([1, 0, 0]) {
        tilt_frame() mech_flat(true, RIGHT_FACES, false, e);
        color("whitesmoke") translate([0, 0, -2 * e]) wedge(true);
        if (show_internals) translate([0, 0, -2 * e]) internals();
    }
    tilt_frame() {
        color("lightsteelblue") translate([0, 0, 4 * e]) mirror_bar();
        if (show_caps) translate([0, 0, 4 * e]) bar_caps(RIGHT_BAR);
    }
}
module mirror_bar() { translate([KB_W, 0, 0]) mirror([1, 0, 0]) thumb_bar(true); }

module bay_assembly(e = explode) {
    tilt_frame() translate([-BAY_W, Y_PIV, 0]) {
        color("gainsboro") bay_body();
        if (show_ereader) color("white", 0.95)
            translate([(BAY_W - ER[0]) / 2, (BAY_H - ER[1]) / 2, TOP - 3 + 5 * e]) cube(ER);
    }
    color("whitesmoke") translate([0, 0, -2 * e]) bay_wedge();
}

module keyboard() {
    gap = joined ? 0 : 30;
    translate([joined ? 0 : -20, 0, 0]) bay_assembly();
    left_half();
    translate([KB_W + gap, 0, 0]) right_half();
}

// ---------- Verificação de colisões (quadro plano, metade esquerda) ----------
module check_pair() {
    released = t > 0.01;
    if (check == "gav_chassis") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G + 0.01]) gaveta(g);
        translate([0, 0, Z_CH]) chassis(false); }
    if (check == "gav_bar") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G + 0.01]) gaveta(g);
        thumb_bar(false); }
    if (check == "gav_fixed") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G]) gaveta(g);
        translate([0, 0, Z_G]) fixed_block(false, true); }
    if (check == "gav_gav") for (i = [0:len(GAV) - 2]) intersection() {
        translate([0, GAV[i][2] * u, 0]) gaveta(GAV[i]);
        translate([0, GAV[i + 1][2] * u, 0]) gaveta(GAV[i + 1]); }
    if (check == "cam_tray") intersection() { translate([t, 0, Z_CAM]) cam_plate(); difference() { tray(false, LEFT_FACES); pawl(false); } }
    if (check == "cam_chassis") intersection() { translate([t, 0, Z_CAM]) cam_plate(); translate([0, 0, Z_CH]) chassis(false); }
    if (check == "heads_tray") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G]) gaveta_heads(g);
        union() { tray(false, LEFT_FACES); translate([t, 0, Z_CAM]) cam_plate(); } }
    if (check == "pins_cam") intersection() {
        for (g = GAV) translate([0, g[2] * u, Z_G]) gaveta(g);
        translate([t, 0, Z_CAM]) cam_plate(); }
    if (check == "pawl_cam") intersection() { pawl(released); translate([t, 0, Z_CAM]) cam_plate(); }
    if (check == "stop_cam") intersection() { stop_pin(stop_pct); translate([t, 0, Z_CAM]) cam_plate(); }
    if (check == "strip_tray") intersection() { spring_ribbon(); difference() { tray(false, LEFT_FACES); pawl(false); } }
    if (check == "plunger_cam") intersection() { plunger(false); union() { translate([t, 0, Z_CAM]) cam_plate(); for (g = GAV) translate([0, g[2] * u, Z_G]) gaveta(g); } }
}

if (part == "assembly") keyboard();
else if (part == "left") left_half();
else if (part == "right") right_half();
else if (part == "front") keyboard();
else if (part == "tray") tray(false, LEFT_FACES);
else if (part == "cam_plate") cam_plate();
else if (part == "chassis") chassis(false);
else if (part == "gaveta") gaveta(GAV[2]);
else if (part == "fixed_block") fixed_block(false, true);
else if (part == "thumb_bar") thumb_bar(false);
else if (part == "wedge_left") wedge(false);
else if (part == "bay") bay_body();
else if (part == "check") check_pair();
