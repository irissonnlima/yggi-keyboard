//! A marca do Yggi (três cápsulas em Y) e o teclado em miniatura do ícone da barra de menus.
//!
//! Os desenhos saem daqui em cápsulas (centro, comprimento, largura, ângulo) para toda
//! interface desenhar igual. A marca bate com `docs/brand/yggi-marca.svg`.

use crate::layout::{Half, MAX_STAGGER_PERCENT, yggi_layout};
use crate::model::KeyboardState;

// Marca isométrica: três cápsulas iguais a 120° (a haste em pé, os braços a 30° da horizontal,
// como os eixos de um desenho isométrico), todas à mesma distância do centro.
const MARK_BAR_LENGTH: f32 = 44.0;
const MARK_BAR_WIDTH: f32 = 20.0;
/// Do centro da marca até o centro da tampa de dentro de cada cápsula.
const MARK_INNER: f32 = 18.0;

/// Caixa da marca (bate com `docs/brand/yggi-marca.svg`).
pub const MARK_WIDTH: f32 = 92.75;
pub const MARK_HEIGHT: f32 = 83.0;

/// Uma cápsula de um desenho.
#[derive(Debug, Clone, Copy, PartialEq, uniffi::Record)]
pub struct MarkCapsule {
    pub cx: f32,
    pub cy: f32,
    /// Ao longo do eixo, de ponta a ponta.
    pub length: f32,
    pub width: f32,
    /// Ângulo do eixo em graus, a partir da horizontal, com y para baixo (90 = em pé).
    pub angle: f32,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct MarkDrawing {
    pub width: f32,
    pub height: f32,
    pub capsules: Vec<MarkCapsule>,
    /// Desenhar apagado (teclado desconectado).
    pub dimmed: bool,
}

/// Qual perninha da marca acende para cada computador da tecla Yggi (índices de `yggi_mark`):
/// o 1º é o braço da esquerda, o 2º o da direita e o 3º a haste, na ordem de leitura.
const HOST_LEGS: [usize; 3] = [1, 2, 0];

/// A legenda da tecla Yggi: a marca com a perninha do computador ativo acesa.
/// `true` na posição de cada cápsula de `yggi_mark` que deve acender.
#[uniffi::export]
pub fn yggi_key_lit_legs(active_host: Option<u8>) -> Vec<bool> {
    let mut lit = vec![false; 3];
    if let Some(leg) = active_host.and_then(|h| HOST_LEGS.get(h as usize)) {
        lit[*leg] = true;
    }
    lit
}

/// A marca do Yggi: três barrinhas iguais em Y.
#[uniffi::export]
pub fn yggi_mark() -> MarkDrawing {
    let r = MARK_INNER + (MARK_BAR_LENGTH - MARK_BAR_WIDTH) / 2.0;
    // Centro da marca dentro da caixa: metade da largura; na altura, o topo dos braços em 0.
    let (ox, oy) = (MARK_WIDTH / 2.0, MARK_HEIGHT - r - MARK_BAR_LENGTH / 2.0);
    let capsules = [90.0f32, 210.0, 330.0]
        .into_iter()
        .map(|deg| {
            let (sin, cos) = deg.to_radians().sin_cos();
            MarkCapsule {
                cx: ox + r * cos,
                cy: oy + r * sin,
                length: MARK_BAR_LENGTH,
                width: MARK_BAR_WIDTH,
                angle: deg % 180.0,
            }
        })
        .collect();
    MarkDrawing { width: MARK_WIDTH, height: MARK_HEIGHT, capsules, dimmed: false }
}

// Teclado em miniatura: uma barrinha por coluna de 1u das que andam (mindinho a indicador),
// subindo com o stagger como no teclado.
const BAR_WIDTH: f32 = 1.6;
const BAR_GAP: f32 = 1.0;
const BAR_HEIGHT: f32 = 11.0;
/// Quanto a coluna que mais sobe (médio, 0,83u) sobe no desenho.
const GLYPH_MAX_LIFT: f32 = 4.0;
const HALVES_GAP_JOINED: f32 = 1.8;
const HALVES_GAP_SEPARATED: f32 = 6.5;
/// Colunas de 1u desenhadas em cada metade: x 6 a 10 na esquerda e 12 a 16 na direita.
const COLUMNS_PER_HALF: usize = 5;
const HALF_WIDTH: f32 = COLUMNS_PER_HALF as f32 * BAR_WIDTH + (COLUMNS_PER_HALF - 1) as f32 * BAR_GAP;
/// Largura fixa (a das metades separadas), para o ícone não mudar de tamanho na barra.
pub const GLYPH_WIDTH: f32 = 2.0 * HALF_WIDTH + HALVES_GAP_SEPARATED;
/// Barra do polegar, fixa, embaixo de cada metade.
const THUMB_HEIGHT: f32 = 1.8;
const THUMB_GAP: f32 = 1.2;
pub const GLYPH_HEIGHT: f32 = GLYPH_MAX_LIFT + BAR_HEIGHT + THUMB_GAP + THUMB_HEIGHT;

/// O teclado visto de cima, simplificado: colunas abertas ou em ortho, metades juntas ou separadas.
#[uniffi::export]
pub fn keyboard_glyph(stagger_percent: u8, halves_joined: bool) -> MarkDrawing {
    keyboard_glyph_frame(stagger_percent as f32, if halves_joined { 0.0 } else { 1.0 })
}

/// Um quadro da animação entre estados: `stagger` de 0 a 100 (com casas decimais) e
/// `separation` de 0 (metades juntas) a 1 (separadas). Valores fora da faixa são limitados.
#[uniffi::export]
pub fn keyboard_glyph_frame(stagger: f32, separation: f32) -> MarkDrawing {
    let layout = yggi_layout();
    let max_lift = layout.columns.iter().map(|c| c.lift_at_max).fold(0.0, f32::max);
    let opening = stagger.clamp(0.0, MAX_STAGGER_PERCENT as f32) / MAX_STAGGER_PERCENT as f32;
    // Subida (fração da maior) da coluna que cobre a posição x, ou 0 nas colunas fixas.
    let lift_at = |half: Half, ux: f32| {
        layout
            .columns
            .iter()
            .find(|c| c.half == half && ux >= c.x && ux < c.x + c.w)
            .map_or(0.0, |c| c.lift_at_max / max_lift * opening)
    };
    let gap = HALVES_GAP_JOINED + (HALVES_GAP_SEPARATED - HALVES_GAP_JOINED) * separation.clamp(0.0, 1.0);
    let left_x0 = (GLYPH_WIDTH - 2.0 * HALF_WIDTH - gap) / 2.0;
    let mut capsules = Vec::with_capacity(2 * COLUMNS_PER_HALF + 2);
    for (half, first_u, x0) in [(Half::Left, 6.0, left_x0), (Half::Right, 12.0, left_x0 + HALF_WIDTH + gap)] {
        for i in 0..COLUMNS_PER_HALF {
            let lift = lift_at(half, first_u + i as f32) * GLYPH_MAX_LIFT;
            capsules.push(MarkCapsule {
                cx: x0 + i as f32 * (BAR_WIDTH + BAR_GAP) + BAR_WIDTH / 2.0,
                cy: GLYPH_MAX_LIFT + BAR_HEIGHT / 2.0 - lift,
                length: BAR_HEIGHT,
                width: BAR_WIDTH,
                angle: 90.0,
            });
        }
        capsules.push(MarkCapsule {
            cx: x0 + HALF_WIDTH / 2.0,
            cy: GLYPH_HEIGHT - THUMB_HEIGHT / 2.0,
            length: HALF_WIDTH,
            width: THUMB_HEIGHT,
            angle: 0.0,
        });
    }
    MarkDrawing { width: GLYPH_WIDTH, height: GLYPH_HEIGHT, capsules, dimmed: false }
}

/// Ícone da barra de menus: o teclado como está agora. Desconectado, apagado.
#[uniffi::export]
pub fn menu_bar_glyph(state: KeyboardState) -> MarkDrawing {
    MarkDrawing { dimmed: !state.is_connected(), ..keyboard_glyph(state.stagger_percent, state.halves_joined) }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Topo das colunas (sem as barras do polegar), da esquerda para a direita.
    fn tops(d: &MarkDrawing) -> Vec<f32> {
        d.capsules.iter().filter(|c| c.angle == 90.0).map(|c| c.cy - c.length / 2.0).collect()
    }

    fn columns(d: &MarkDrawing) -> Vec<MarkCapsule> {
        d.capsules.iter().copied().filter(|c| c.angle == 90.0).collect()
    }

    #[test]
    fn ortho_tem_tudo_alinhado() {
        let d = keyboard_glyph(0, true);
        assert_eq!(d.capsules.len(), 12);
        assert_eq!(columns(&d).len(), 10);
        assert!(tops(&d).iter().all(|&t| (t - GLYPH_MAX_LIFT).abs() < 1e-5));
    }

    #[test]
    fn stagger_sobe_o_medio_mais_e_o_mindinho_nada() {
        let d = keyboard_glyph(100, true);
        let t = tops(&d);
        // Metade esquerda: x 6..10. Mindinho em x 6 (índice 0), anelar 1, médio 2, indicador (2u) 3 e 4.
        assert_eq!(t[0], GLYPH_MAX_LIFT);
        assert!(t[1] < GLYPH_MAX_LIFT && t[1] > 0.0);
        assert!(t[2].abs() < 1e-5, "médio no topo");
        // A coluna do indicador tem 2u: as duas barrinhas sobem juntas.
        assert_eq!(t[3], t[4]);
        // Espelhado na direita.
        for i in 0..5 {
            assert!((t[i] - t[9 - i]).abs() < 1e-5);
        }
        // Meio caminho, meia subida.
        assert!((tops(&keyboard_glyph(50, true))[2] - GLYPH_MAX_LIFT / 2.0).abs() < 1e-5);
    }

    #[test]
    fn separado_afasta_as_metades_sem_mudar_a_caixa() {
        let joined = keyboard_glyph(0, true);
        let apart = keyboard_glyph(0, false);
        let gap = |d: &MarkDrawing| columns(d)[5].cx - columns(d)[4].cx - BAR_WIDTH;
        assert!(gap(&apart) > gap(&joined) + 4.0);
        assert_eq!((joined.width, joined.height), (apart.width, apart.height));
        for d in [&joined, &apart] {
            let left = columns(d)[0].cx - BAR_WIDTH / 2.0;
            let right = columns(d)[9].cx + BAR_WIDTH / 2.0;
            assert!(left >= -1e-5 && right <= d.width + 1e-5);
            assert!(((left + right) / 2.0 - d.width / 2.0).abs() < 1e-4, "centralizado");
        }
    }

    #[test]
    fn quadros_da_animacao_ficam_entre_os_estados() {
        let meio = keyboard_glyph_frame(50.0, 0.5);
        let (fechado, aberto) = (keyboard_glyph(0, true), keyboard_glyph(100, false));
        for ((m, a), b) in meio.capsules.iter().zip(&fechado.capsules).zip(&aberto.capsules) {
            assert!((m.cy - (a.cy + b.cy) / 2.0).abs() < 1e-4);
            assert!((m.cx - (a.cx + b.cx) / 2.0).abs() < 1e-4);
        }
        // Quadros inteiros batem com o desenho do estado.
        assert_eq!(keyboard_glyph_frame(100.0, 1.0), aberto);
        // Fora da faixa não sai da caixa.
        assert_eq!(keyboard_glyph_frame(130.0, 1.4), aberto);
    }

    #[test]
    fn cada_computador_acende_uma_perninha() {
        let mark = yggi_mark();
        let lit_capsule = |h| {
            let lit = yggi_key_lit_legs(Some(h));
            assert_eq!(lit.iter().filter(|&&on| on).count(), 1);
            mark.capsules[lit.iter().position(|&on| on).unwrap()]
        };
        // 1º braço esquerdo, 2º braço direito, 3º haste.
        assert!(lit_capsule(0).cx < mark.width / 2.0 && lit_capsule(0).cy < 30.0);
        assert!(lit_capsule(1).cx > mark.width / 2.0 && lit_capsule(1).cy < 30.0);
        assert!((lit_capsule(2).cx - mark.width / 2.0).abs() < 0.1 && lit_capsule(2).cy > 50.0);
        assert_eq!(yggi_key_lit_legs(None), vec![false; 3]);
        assert_eq!(yggi_key_lit_legs(Some(4)), vec![false; 3], "vagas 4 e 5 não têm perninha");
    }

    #[test]
    fn marca_e_isometrica_e_cabe_na_caixa() {
        let d = yggi_mark();
        assert_eq!(d.capsules.len(), 3);
        assert!(d.capsules.iter().all(|c| c.length == MARK_BAR_LENGTH && c.width == MARK_BAR_WIDTH), "barrinhas iguais");
        // Mesma distância entre as três (120°).
        let dist = |a: &MarkCapsule, b: &MarkCapsule| ((a.cx - b.cx).powi(2) + (a.cy - b.cy).powi(2)).sqrt();
        let (a, b, c) = (&d.capsules[0], &d.capsules[1], &d.capsules[2]);
        assert!((dist(a, b) - dist(b, c)).abs() < 1e-3 && (dist(b, c) - dist(a, c)).abs() < 1e-3);
        // Bate com o SVG: haste em (46,37; 61) e braços em y 16.
        assert!((a.cx - 46.375).abs() < 0.02 && (a.cy - 61.0).abs() < 0.02, "{a:?}");
        assert!((b.cy - 16.0).abs() < 0.02 && (c.cy - 16.0).abs() < 0.02);
    }
}
