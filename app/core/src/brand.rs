//! A marca do Yggi (três cápsulas em Y) e o ícone da barra de menus, que muda com o teclado.
//!
//! O desenho sai daqui em cápsulas (centro, comprimento, largura, ângulo) para toda
//! interface desenhar igual. As medidas batem com `docs/brand/yggi-marca.svg`.

use crate::model::{KeyboardState, is_low_battery, lowest_battery};

/// Caixa comum a todas as poses, para o ícone não mudar de tamanho na barra.
pub const MARK_WIDTH: f32 = 105.0;
pub const MARK_HEIGHT: f32 = 98.0;
/// Onde a marca de 80 de largura começa dentro da caixa (sobra espaço para abrir e separar).
const X0: f32 = 12.5;

const ARM_LENGTH: f32 = 40.8;
const ARM_WIDTH: f32 = 20.0;
/// Distância entre os centros das pontas da cápsula do braço.
const ARM_SPAN: f32 = ARM_LENGTH - ARM_WIDTH;
/// Centro da ponta de dentro do braço esquerdo; fica parado quando o Y abre.
const ARM_INNER: (f32, f32) = (21.97, 27.02);
const ARM_ANGLE: f32 = 55.0;
const ARM_ANGLE_OPEN: f32 = 38.0;
const STEM: (f32, f32, f32, f32) = (40.0, 69.0, 58.0, 18.0);
/// Quanto cada lado se afasta quando as metades estão separadas.
const SPLIT: f32 = 8.0;
const STEM_HALF_WIDTH: f32 = 7.0;
/// Comprimento da haste com a bateria baixa.
const DRAINED: f32 = 26.0;

/// Como a marca aparece.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, uniffi::Record)]
pub struct MarkPose {
    /// Stagger ligado: os braços do Y abrem.
    pub open: bool,
    /// Metades separadas: os lados se afastam e a haste se divide.
    pub separated: bool,
    /// Só o contorno (teclado desconectado).
    pub outline: bool,
    /// Bateria baixa: a haste esvazia e fica só um toco embaixo, como um nível caindo.
    pub low_battery: bool,
}

/// Uma cápsula da marca.
#[derive(Debug, Clone, Copy, PartialEq, uniffi::Record)]
pub struct MarkCapsule {
    pub cx: f32,
    pub cy: f32,
    /// Ao longo do eixo, de ponta a ponta.
    pub length: f32,
    pub width: f32,
    /// Ângulo do eixo em graus, a partir da horizontal, com y para baixo (90 = em pé).
    pub angle: f32,
    /// Desenhar só o contorno.
    pub hollow: bool,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct MarkDrawing {
    pub width: f32,
    pub height: f32,
    pub capsules: Vec<MarkCapsule>,
}

/// As cápsulas da marca numa pose, dentro de uma caixa de `MARK_WIDTH` × `MARK_HEIGHT`.
#[uniffi::export]
pub fn yggi_mark(pose: MarkPose) -> MarkDrawing {
    let angle = if pose.open { ARM_ANGLE_OPEN } else { ARM_ANGLE };
    let (sin, cos) = angle.to_radians().sin_cos();
    let split = if pose.separated { SPLIT } else { 0.0 };
    // Braço esquerdo: a ponta de dentro fica no lugar e o braço gira em volta dela.
    let left_x = ARM_INNER.0 - ARM_SPAN / 2.0 * cos - split;
    let arm_y = ARM_INNER.1 - ARM_SPAN / 2.0 * sin;
    let mid = 40.0;
    let arm = |cx: f32, angle: f32| MarkCapsule {
        cx: cx + X0,
        cy: arm_y,
        length: ARM_LENGTH,
        width: ARM_WIDTH,
        angle,
        hollow: pose.outline,
    };
    let mut capsules = vec![arm(left_x, angle), arm(2.0 * mid - left_x, -angle)];

    let (sx, sy, sl, sw) = STEM;
    // Bateria baixa: a haste encolhe para baixo (o pé fica no mesmo lugar).
    let (sl, sy) = if pose.low_battery { (DRAINED, sy + (sl - DRAINED) / 2.0) } else { (sl, sy) };
    let stem = |cx: f32, width: f32| MarkCapsule { cx: cx + X0, cy: sy, length: sl, width, angle: 90.0, hollow: pose.outline };
    if pose.separated {
        let off = STEM_HALF_WIDTH / 2.0 + 3.0;
        capsules.push(stem(sx - off, STEM_HALF_WIDTH));
        capsules.push(stem(sx + off, STEM_HALF_WIDTH));
    } else {
        capsules.push(stem(sx, sw));
    }
    MarkDrawing { width: MARK_WIDTH, height: MARK_HEIGHT, capsules }
}

/// A pose do ícone da barra de menus para o estado do teclado.
/// Desconectado não se sabe a forma do teclado: só o contorno, na pose de fábrica.
#[uniffi::export]
pub fn menu_bar_pose(state: KeyboardState) -> MarkPose {
    if !state.is_connected() {
        return MarkPose { outline: true, ..MarkPose::default() };
    }
    MarkPose {
        open: state.stagger_percent > 0,
        separated: !state.halves_joined,
        outline: false,
        low_battery: lowest_battery(state.clone()).is_some_and(is_low_battery),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn bounds(d: &MarkDrawing) -> (f32, f32, f32, f32) {
        let mut b = (f32::MAX, f32::MAX, f32::MIN, f32::MIN);
        for c in &d.capsules {
            let (s, co) = c.angle.to_radians().sin_cos();
            let half = (c.length - c.width) / 2.0;
            let (dx, dy) = ((half * co).abs() + c.width / 2.0, (half * s).abs() + c.width / 2.0);
            b = (b.0.min(c.cx - dx), b.1.min(c.cy - dy), b.2.max(c.cx + dx), b.3.max(c.cy + dy));
        }
        b
    }

    fn all_poses() -> Vec<MarkPose> {
        let mut v = Vec::new();
        for i in 0..16u8 {
            v.push(MarkPose { open: i & 1 != 0, separated: i & 2 != 0, outline: i & 4 != 0, low_battery: i & 8 != 0 });
        }
        v
    }

    #[test]
    fn pose_de_fabrica_e_o_logo() {
        let d = yggi_mark(MarkPose::default());
        assert_eq!(d.capsules.len(), 3);
        let (x0, y0, x1, y1) = bounds(&d);
        assert!((x0 - X0).abs() < 0.2 && (x1 - (X0 + 80.0)).abs() < 0.2, "{x0} {x1}");
        assert!(y0.abs() < 0.2 && (y1 - 98.0).abs() < 0.2, "{y0} {y1}");
    }

    #[test]
    fn toda_pose_cabe_na_caixa_e_e_simetrica() {
        for pose in all_poses() {
            let d = yggi_mark(pose);
            let (x0, y0, x1, y1) = bounds(&d);
            assert!(x0 >= -0.05 && y0 >= -0.05 && x1 <= MARK_WIDTH + 0.05 && y1 <= MARK_HEIGHT + 0.05, "{pose:?}: {x0} {y0} {x1} {y1}");
            assert!(((x0 + x1) / 2.0 - MARK_WIDTH / 2.0).abs() < 0.01, "{pose:?} fora do centro");
        }
    }

    #[test]
    fn separado_divide_a_haste_e_nada_se_encosta() {
        let d = yggi_mark(MarkPose { separated: true, open: true, ..Default::default() });
        assert_eq!(d.capsules.len(), 4);
        let (a, b) = (d.capsules[2], d.capsules[3]);
        assert!((b.cx - a.cx) - a.width >= 5.9, "fresta da haste pequena demais para 16 pt");
    }

    #[test]
    fn cada_pose_desenha_diferente() {
        let drawings: Vec<_> = all_poses().into_iter().filter(|p| !(p.outline && p.low_battery)).map(yggi_mark).collect();
        for (i, a) in drawings.iter().enumerate() {
            for b in &drawings[i + 1..] {
                assert_ne!(a, b);
            }
        }
    }
}
