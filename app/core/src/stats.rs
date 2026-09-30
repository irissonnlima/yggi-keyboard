//! Estatísticas de digitação: só contagens, nunca o texto digitado.
//!
//! Hoje os números vêm do simulador (`simulated_statistics`). Onde contar de verdade
//! (no teclado ou no app) ainda está em aberto; o formato abaixo serve para os dois.

use crate::layout::yggi_layout;

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum StatsPeriod {
    Today,
    Week,
    Month,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct StatTotals {
    pub keystrokes: u64,
    pub words: u64,
    /// Palavras por minuto, só enquanto digita.
    pub avg_wpm: u32,
    pub peak_wpm: u32,
    /// Quando foi o pico ("às 15h", "quinta-feira").
    pub peak_when: String,
    pub typing_minutes: u32,
    pub sessions: u32,
    /// Variação das teclas digitadas em relação ao período anterior, em %.
    pub change_percent: i32,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct SpeedPoint {
    /// "8h", "seg", "sem. 1".
    pub label: String,
    pub wpm: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct KeyCount {
    pub key_id: String,
    pub count: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct HostShare {
    pub host_index: u8,
    pub percent: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ModeStats {
    pub wpm: u32,
    /// Correções (delete) por mil teclas.
    pub corrections_per_mille: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct Statistics {
    pub period: StatsPeriod,
    pub totals: StatTotals,
    pub speed: Vec<SpeedPoint>,
    pub key_counts: Vec<KeyCount>,
    pub hosts: Vec<HostShare>,
    pub ortho: ModeStats,
    pub stagger: ModeStats,
    /// Números do simulador, não medições.
    pub simulated: bool,
}

/// Intensidade no mapa de calor, de 0 (pouco usada) a 4 (muito usada).
#[uniffi::export]
pub fn heat_level(count: u64, max: u64) -> u8 {
    if max == 0 {
        return 0;
    }
    match count as f64 / max as f64 {
        r if r > 0.45 => 4,
        r if r > 0.2 => 3,
        r if r > 0.08 => 2,
        r if r > 0.02 => 1,
        _ => 0,
    }
}

/// As `n` teclas mais usadas, da mais para a menos usada.
#[uniffi::export]
pub fn top_keys(stats: Statistics, n: u32) -> Vec<KeyCount> {
    let mut keys = stats.key_counts;
    keys.sort_by(|a, b| b.count.cmp(&a.count).then(a.key_id.cmp(&b.key_id)));
    keys.truncate(n as usize);
    keys
}

/// Peso de cada tecla na digitação em português (aproximado), para o simulador.
fn key_weight(id: &str) -> f64 {
    match id {
        "L-space" | "R-space" => 90.0,
        "L-e" => 45.0,
        "L-a" => 43.0,
        "R-o" => 36.0,
        "L-del" => 30.0,
        "L-s" => 29.0,
        "L-r" => 25.0,
        "R-i" => 24.0,
        "R-n" => 19.0,
        "L-d" => 18.0,
        "R-m" => 17.0,
        "R-u" => 17.0,
        "L-t" => 16.0,
        "L-c" => 14.0,
        "R-l" => 10.0,
        "R-p" => 9.0,
        "L-v" => 6.0,
        "L-g" => 5.0,
        "R-h" => 4.5,
        "L-q" => 4.5,
        "L-b" => 4.0,
        "L-f" => 4.0,
        "L-shift" | "R-comma" | "R-dot" | "R-ret" => 8.0,
        "L-cmd" => 6.0,
        "L-z" | "L-x" | "R-j" | "R-y" | "R-k" | "L-w" => 1.5,
        "L-tab" | "R-shift" | "R-slash" | "R-left" | "R-right" | "R-up" | "R-down" | "L-yggi" | "L-esc" => 1.2,
        "L-1" | "L-2" | "R-0" | "R-quote" | "R-semi" | "L-caps" | "L-opt" | "L-ctrl" | "R-cmd" => 1.0,
        _ => 0.3,
    }
}

/// Um período de exemplo: totais, rótulos e ppm do gráfico, divisão por computador (%),
/// e (ppm, correções por mil) em ortho e em stagger.
type Sample = (StatTotals, Vec<&'static str>, Vec<u32>, [u8; 3], (u32, u32), (u32, u32));

/// Estatísticas de exemplo, sempre as mesmas para o mesmo período.
#[uniffi::export]
pub fn simulated_statistics(period: StatsPeriod) -> Statistics {
    let (totals, labels, wpm, hosts, ortho, stagger): Sample = match period {
        StatsPeriod::Today => (
            StatTotals {
                keystrokes: 14_382,
                words: 2_451,
                avg_wpm: 66,
                peak_wpm: 94,
                peak_when: "às 15h".into(),
                typing_minutes: 112,
                sessions: 9,
                change_percent: 12,
            },
            vec!["8h", "9h", "10h", "11h", "12h", "13h", "14h", "15h", "16h", "17h", "18h", "19h"],
            vec![52, 61, 68, 72, 70, 38, 49, 75, 71, 66, 58, 44],
            [64, 28, 8],
            (63, 71),
            (69, 54),
        ),
        StatsPeriod::Week => (
            StatTotals {
                keystrokes: 71_904,
                words: 12_187,
                avg_wpm: 64,
                peak_wpm: 97,
                peak_when: "quinta-feira".into(),
                typing_minutes: 580,
                sessions: 41,
                change_percent: 4,
            },
            vec!["seg", "ter", "qua", "qui", "sex", "sáb", "dom"],
            vec![62, 65, 63, 70, 66, 55, 48],
            [58, 34, 8],
            (61, 74),
            (67, 56),
        ),
        StatsPeriod::Month => (
            StatTotals {
                keystrokes: 288_140,
                words: 48_830,
                avg_wpm: 63,
                peak_wpm: 97,
                peak_when: "dia 18".into(),
                typing_minutes: 2_295,
                sessions: 162,
                change_percent: 9,
            },
            vec!["sem. 1", "sem. 2", "sem. 3", "sem. 4"],
            vec![59, 62, 65, 66],
            [61, 31, 8],
            (60, 76),
            (66, 58),
        ),
    };

    let keys = yggi_layout().keys;
    let total_weight: f64 = keys.iter().map(|k| key_weight(&k.id)).sum();
    let key_counts = keys
        .iter()
        .map(|k| KeyCount { key_id: k.id.clone(), count: (totals.keystrokes as f64 * key_weight(&k.id) / total_weight).round() as u64 })
        .collect();

    Statistics {
        period,
        speed: labels.iter().zip(wpm).map(|(l, w)| SpeedPoint { label: l.to_string(), wpm: w }).collect(),
        key_counts,
        hosts: hosts.iter().enumerate().map(|(i, &p)| HostShare { host_index: i as u8, percent: p }).collect(),
        ortho: ModeStats { wpm: ortho.0, corrections_per_mille: ortho.1 },
        stagger: ModeStats { wpm: stagger.0, corrections_per_mille: stagger.1 },
        totals,
        simulated: true,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn counts_add_up_to_the_total() {
        let s = simulated_statistics(StatsPeriod::Today);
        let sum: u64 = s.key_counts.iter().map(|k| k.count).sum();
        let diff = sum.abs_diff(s.totals.keystrokes);
        assert!(diff < 80, "soma {sum} longe de {}", s.totals.keystrokes);
        assert_eq!(s.hosts.iter().map(|h| h.percent as u32).sum::<u32>(), 100);
    }

    #[test]
    fn space_and_e_lead_the_ranking() {
        let top = top_keys(simulated_statistics(StatsPeriod::Week), 3);
        assert_eq!(top[2].key_id, "L-e");
        assert!(top[0].key_id.ends_with("space"));
    }

    #[test]
    fn heat_levels() {
        assert_eq!(heat_level(0, 100), 0);
        assert_eq!(heat_level(100, 100), 4);
        assert_eq!(heat_level(10, 100), 2);
        assert_eq!(heat_level(5, 0), 0);
    }
}
