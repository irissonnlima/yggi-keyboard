// Yggi Keyboard — mecanismo de stagger ajustável (conceito v0)
// Licença sugerida: CERN-OHL-S-2.0
//
// Princípio: came linear. Uma placa-came desliza em X por baixo das colunas.
// Cada coluna tem um pino que corre num rasgo inclinado da placa. Como a coluna
// só pode andar em Y (presa por linguetas em túneis), empurrar a placa em X faz
// cada coluna subir proporcionalmente à inclinação do seu rasgo.
//   placa em 0%   -> ortholinear
//   placa em 100% -> column stagger completo (perfil = vetor `stagger`)
// Trocar o perfil de stagger = imprimir outra placa-came.
// v1: a placa-came fica inteira dentro da bandeja em qualquer posição. Ela é
// acionada por um cursor que sai pela borda da frente (como a chave de mudo de um celular).
//
// Eixos (mm): X = entre colunas, Y = ao longo da coluna (+Y = longe do usuário), Z = para cima.

/* [Visualização] */
part = "assembly"; // [assembly, tray, cam_plate, base, carrier, tunnel_front, tunnel_back, print_all]
stagger_pct = 100; // [0:1:100]
explode = 0;       // [0:1:20]
show_caps = true;

/* [Layout] */
cols = 5;
rows = 3;
pitch_x = 18;                // espaçamento Choc
pitch_y = 17;
// Deslocamento em Y de cada coluna no modo 100% (mindinho -> indicador interno).
// A coluna 0 é a referência fixa. Valores devem ficar entre 0 e s_max_design.
stagger = [0, 5, 8, 5, 2];
s_max_design = 8;            // curso máximo previsto nos túneis e rasgos da base
travel = 16;                 // curso da placa-came em X

/* [Espessuras e folgas] */
clr = 0.25;
tray_floor = 1.6;
cam_t = 2.5;
base_t = 2.5;
plate_t = 1.3;               // espessura p/ clipe do Choc V1
carrier_h = 6.5;
wall = 1.5;
tongue_w = 10;
tongue_t = 2.5;
tongue_len = 16;
pin_d = 3;
slot_w = pin_d + 0.4;
switch_cut = 13.8;
body_margin = 2;
screw_d = 2.3;               // M2 passante
screw_pilot = 1.8;           // M2 autoatarraxante no plástico
detent_x = 40;
pin_dx = -3.3;               // pino deslocado p/ o lado do mindinho: encolhe o curso total
knob_x = 60;                 // posição do cursor (em 0%) na borda da frente
knob_w = 6;
knob_out = 2;                // quanto o cursor sai da borda (0 = rente)

$fn = 40;

// ---------- Geometria derivada ----------
cw = pitch_x - 0.6;                         // largura do carrinho da coluna
key_len = rows * pitch_y;
body_y0 = -body_margin;
body_y1 = key_len + body_margin;
pin_front_y = body_y0 - 10;
pin_back_y = body_y1 + 12;
tunnel_front_y1 = body_y0 - 0.5;
tunnel_back_y0 = body_y1 + s_max_design + 0.5;
tunnel_h = tongue_t + 0.3 + 2.7;

plate_y0 = pin_front_y - 6;
plate_y1 = pin_back_y + s_max_design + 6;
tray_y0 = plate_y0 - clr - 9.5;
tray_y1 = plate_y1 + clr + 8.5;
tray_x0 = -pitch_x / 2 - 3;
tray_x1 = (cols - 1) * pitch_x + pitch_x / 2 + 10;
tray_h = tray_floor + cam_t + 0.4;

plate_x0 = (1 * pitch_x + pin_dx - travel) - slot_w / 2 - 1;
plate_x1 = (cols - 1) * pitch_x + pin_dx + slot_w / 2 + 1;
pocket_x0 = plate_x0 - clr;
pocket_x1 = plate_x1 + travel + clr;        // a placa anda dentro do bolsão, nunca sai
knob_win = [knob_x - clr, knob_x + knob_w + travel + clr];

screw_front_y = (tray_y0 + plate_y0 - clr) / 2;
screw_back_y = (plate_y1 + clr + tray_y1) / 2;
screw_xs = concat([tray_x0 + 4], [for (i = [0:cols - 2]) (i + 0.5) * pitch_x], [tray_x1 - 4]);
// na frente, pula os parafusos que cairiam na janela do cursor
screw_front_xs = [for (x = screw_xs) if (x < knob_win[0] - 3 || x > knob_win[1] + 3) x];

// Colunas ímpares têm o pino na frente, pares atrás: os rasgos vizinhos não se cruzam.
function pin_front(i) = (i == 0) || (i % 2 == 1);
function pin_y(i) = pin_front(i) ? pin_front_y : pin_back_y;

assert(max(stagger) <= s_max_design && min(stagger) >= 0, "stagger fora do curso previsto");
assert(travel + slot_w < 2 * pitch_x, "rasgos de mesma paridade se cruzam");
assert(pocket_x0 >= tray_x0 + 3 && pocket_x1 <= tray_x1 - 3, "placa-came não cabe dentro da bandeja");
assert(abs(pin_dx) + pin_d / 2 <= tongue_w / 2, "pino fora da lingueta");

// ---------- Peças ----------

module tray() {
    pf = plate_y0 - clr;                    // face frontal do bolsão
    difference() {
        translate([tray_x0, tray_y0, 0]) cube([tray_x1 - tray_x0, tray_y1 - tray_y0, tray_h]);
        // bolsão da placa-came, aberto no lado direito
        translate([pocket_x0, pf, tray_floor])
            cube([pocket_x1 - pocket_x0, plate_y1 - plate_y0 + 2 * clr, tray_h]);
        // janela do cursor na parede da frente
        translate([knob_win[0], tray_y0 - 1, tray_floor])
            cube([knob_win[1] - knob_win[0], pf - tray_y0 + 1.1, tray_h]);
        // mola de trava (flexure): alívio atrás, na ponta, sob e sobre o braço
        translate([detent_x - 12, pf - 2.2, -1]) cube([15, 1, tray_h + 2]);
        translate([detent_x + 2, pf - 2.2, -1]) cube([1, 2.3, tray_h + 2]);
        translate([detent_x - 12, pf - 0.01, -1]) cube([15, 1, tray_floor + 1.01]);
        translate([detent_x - 12, pf - 1.3, tray_h - 0.4]) cube([15, 1.4, 1]);
        for (x = screw_front_xs) translate([x, screw_front_y, 0.8]) cylinder(d = screw_pilot, h = tray_h);
        for (x = screw_xs) translate([x, screw_back_y, 0.8]) cylinder(d = screw_pilot, h = tray_h);
    }
    // dente da trava
    translate([detent_x, pf, tray_floor]) cylinder(r = 1, h = tray_h - tray_floor - 0.4);
}

module cam_plate() {
    difference() {
        translate([plate_x0, plate_y0, 0]) cube([plate_x1 - plate_x0, plate_y1 - plate_y0, cam_t]);
        for (i = [1:cols - 1]) hull() {
            translate([i * pitch_x + pin_dx, pin_y(i), -1]) cylinder(d = slot_w, h = cam_t + 2);
            translate([i * pitch_x + pin_dx - travel, pin_y(i) + stagger[i], -1]) cylinder(d = slot_w, h = cam_t + 2);
        }
        // entalhes da trava: 0%, 50%, 100%
        for (f = [0, 0.5, 1]) translate([detent_x - f * travel, plate_y0, -1]) cylinder(r = 1.2, h = cam_t + 2);
    }
    // cursor: atravessa a parede da frente e sai knob_out mm
    translate([knob_x, tray_y0 - knob_out, 0]) cube([knob_w, plate_y0 - tray_y0 + knob_out + 0.01, cam_t]);
    if (knob_out > 0.5)
        translate([knob_x, tray_y0 - knob_out, cam_t - 0.01]) cube([knob_w, knob_out - 0.3, 1.5]);
}

module base() {
    difference() {
        translate([tray_x0, tray_y0, 0]) cube([tray_x1 - tray_x0, tray_y1 - tray_y0, base_t]);
        // coluna 0: furo redondo (fixa). Demais: rasgo em Y do tamanho do curso.
        translate([pin_dx, pin_y(0), -1]) cylinder(d = pin_d + 2 * clr, h = base_t + 2);
        for (i = [1:cols - 1]) hull() {
            translate([i * pitch_x + pin_dx, pin_y(i), -1]) cylinder(d = slot_w, h = base_t + 2);
            translate([i * pitch_x + pin_dx, pin_y(i) + stagger[i], -1]) cylinder(d = slot_w, h = base_t + 2);
        }
        for (x = screw_front_xs) translate([x, screw_front_y, -1]) cylinder(d = screw_d, h = base_t + 2);
        for (x = screw_xs) translate([x, screw_back_y, -1]) cylinder(d = screw_d, h = base_t + 2);
    }
}

module carrier(i = 1) {
    pin_len = (i == 0) ? base_t - 0.3 : base_t + cam_t - 0.3;
    difference() {
        union() {
            difference() {
                translate([-cw / 2, body_y0, 0]) cube([cw, body_y1 - body_y0, carrier_h]);
                translate([-cw / 2 + wall, body_y0 + wall, -1])
                    cube([cw - 2 * wall, body_y1 - body_y0 - 2 * wall, carrier_h - plate_t + 1]);
            }
            // linguetas que correm nos túneis
            translate([-tongue_w / 2, body_y0 - tongue_len, 0]) cube([tongue_w, tongue_len + wall, tongue_t]);
            translate([-tongue_w / 2, body_y1 - wall, 0]) cube([tongue_w, tongue_len + wall, tongue_t]);
            // pino da came
            translate([pin_dx, pin_y(i), -pin_len]) cylinder(d = pin_d, h = pin_len + 0.01);
        }
        for (r = [0:rows - 1])
            translate([-switch_cut / 2, r * pitch_y + (pitch_y - switch_cut) / 2, carrier_h - plate_t - 1])
                cube([switch_cut, switch_cut, plate_t + 2]);
        // passagem dos fios (laço de serviço) na parede de trás
        translate([-4, body_y1 - wall - 1, tongue_t + 0.5])
            cube([8, wall + 2, carrier_h - plate_t - tongue_t - 0.5]);
    }
}

module tunnel_block(front = true) {
    y0 = front ? tray_y0 : tunnel_back_y0;
    y1 = front ? tunnel_front_y1 : tray_y1;
    cy0 = front ? tray_y0 + 2 : tunnel_back_y0 - 1;
    cy1 = front ? tunnel_front_y1 + 1 : tray_y1 - 2;
    difference() {
        translate([tray_x0, y0, 0]) cube([tray_x1 - tray_x0, y1 - y0, tunnel_h]);
        for (i = [0:cols - 1])
            translate([i * pitch_x - tongue_w / 2 - clr, cy0, -1])
                cube([tongue_w + 2 * clr, cy1 - cy0, tongue_t + 0.3 + 1]);
        for (x = front ? screw_front_xs : screw_xs)
            translate([x, front ? screw_front_y : screw_back_y, -1]) cylinder(d = screw_d, h = tunnel_h + 2);
    }
}

module keycap_ghost() {
    %translate([-17.5 / 2, (pitch_y - 16.5) / 2, 0]) cube([17.5, 16.5, 3]);
}

// ---------- Montagem ----------

module assembly(pct = stagger_pct) {
    u = pct / 100;
    e = explode;
    z_plate = tray_floor + 0.2;
    z_base = tray_h;
    z_car = tray_h + base_t;

    color("gainsboro") tray();
    color("orange") translate([u * travel, 0, z_plate + e]) cam_plate();
    color("silver", 0.8) translate([0, 0, z_base + 2 * e]) base();
    for (i = [0:cols - 1]) translate([i * pitch_x, stagger[i] * u, z_car + 3 * e]) {
        color("steelblue") carrier(i);
        if (show_caps)
            for (r = [0:rows - 1]) translate([0, r * pitch_y, carrier_h + 5 + 3 * e]) keycap_ghost();
    }
    color("dimgray") translate([0, 0, z_car + 4 * e]) {
        tunnel_block(true);
        tunnel_block(false);
    }
}

module print_all() {
    tray();
    translate([0, tray_y1 - tray_y0 + 10, 0]) base();
    translate([0, 2 * (tray_y1 - tray_y0 + 10), 0]) cam_plate();
    // carrinhos de cabeça para baixo (placa na mesa); suporte só sob as linguetas
    for (i = [0:cols - 1])
        translate([tray_x1 + 25 + i * (cw + 6), 0, carrier_h]) rotate([180, 0, 0]) carrier(i);
    translate([0, -(tray_y1 - tray_y0) - 10, 0]) {
        tunnel_block(true);
        translate([0, tunnel_front_y1 - tunnel_back_y0 - 40, 0]) tunnel_block(false);
    }
}

if (part == "assembly") assembly();
else if (part == "tray") tray();
else if (part == "cam_plate") cam_plate();
else if (part == "base") base();
else if (part == "carrier") carrier(1);
else if (part == "tunnel_front") tunnel_block(true);
else if (part == "tunnel_back") tunnel_block(false);
else if (part == "print_all") print_all();
