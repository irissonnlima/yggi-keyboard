//! A marca desenhada pelo núcleo tem que ser a mesma dos arquivos em `docs/brand/`.
//!
//! Regressão que isto evita: a marca existia em dois lugares (o SVG, gerado à parte, e
//! `yggi_mark` no núcleo) e as medidas podiam divergir sem ninguém perceber.

use std::fs;
use std::path::Path;
use yggi_core::brand::yggi_mark;

fn brand_file(name: &str) -> String {
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../docs/brand").join(name);
    fs::read_to_string(&path).unwrap_or_else(|e| panic!("não li {}: {e}", path.display()))
}

/// Números depois de `key` até `end` (ex.: `translate(` … `)`).
fn numbers_after(text: &str, key: &str, end: char) -> Vec<Vec<f32>> {
    text.match_indices(key)
        .map(|(i, _)| {
            let rest = &text[i + key.len()..];
            rest[..rest.find(end).unwrap()].split([' ', ',']).filter(|s| !s.is_empty()).map(|n| n.parse().unwrap()).collect()
        })
        .collect()
}

fn attr(text: &str, name: &str) -> Vec<f32> {
    numbers_after(text, &format!("{name}=\""), '"').into_iter().map(|v| v[0]).collect()
}

#[test]
fn svg_da_marca_bate_com_o_nucleo() {
    for file in ["yggi-marca.svg", "yggi-marca-branca.svg"] {
        let svg = brand_file(file);
        let mark = yggi_mark();
        let view_box = numbers_after(&svg, "viewBox=\"", '"')[0].clone();
        assert!((view_box[2] - mark.width).abs() < 0.01 && (view_box[3] - mark.height).abs() < 0.01, "{file}: caixa {view_box:?}");

        let centers = numbers_after(&svg, "translate(", ')');
        let angles = numbers_after(&svg, "rotate(", ')');
        let (widths, heights) = (attr(&svg, "width"), attr(&svg, "height"));
        assert_eq!(centers.len(), mark.capsules.len(), "{file}: número de barrinhas");
        for (i, c) in mark.capsules.iter().enumerate() {
            let (cx, cy) = (centers[i][0], centers[i][1]);
            assert!(
                (cx - c.cx).abs() < 0.02 && (cy - c.cy).abs() < 0.02,
                "{file}: barrinha {i} em ({cx}, {cy}), núcleo em ({}, {})",
                c.cx,
                c.cy
            );
            assert!((angles[i][0] - c.angle).abs() < 0.01, "{file}: ângulo da barrinha {i}");
            // width/height das barrinhas vêm depois do width/height do <svg>.
            assert!((widths[i + 1] - c.length).abs() < 0.01 && (heights[i + 1] - c.width).abs() < 0.01, "{file}: tamanho da barrinha {i}");
        }
    }
}
