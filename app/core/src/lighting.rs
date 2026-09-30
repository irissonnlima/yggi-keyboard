//! Luzes do teclado: um LED RGB em cada tecla (a luz passa pela legenda).
//!
//! Três camadas, de baixo para cima:
//! 1. efeito geral (estático, respiração, onda, arco-íris, ao tocar);
//! 2. cores por tecla, pintadas pelo usuário;
//! 3. teclas de ação (caps lock ligado, fn segurada, pareando, bateria baixa), sempre por cima.
//!
//! `LightingConfig` é o que vai gravado no teclado. `LightingEngine` calcula, quadro a quadro,
//! a cor e a intensidade de cada tecla, para todas as interfaces desenharem igual.
//! Os LEDs de computador (brancos, um por computador) não fazem parte daqui.

use std::collections::HashMap;
use std::f32::consts::TAU;
use std::sync::Mutex;

use crate::layout::{KeyDef, yggi_layout};
use crate::model::{KeyboardState, is_low_battery};

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct Rgb {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Rgb {
    pub const fn hex(v: u32) -> Self {
        Self { r: (v >> 16) as u8, g: (v >> 8) as u8, b: v as u8 }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum EffectKind {
    Off,
    Static,
    Breathing,
    Wave,
    Rainbow,
    /// A tecla acende ao ser tocada e apaga devagar.
    Reactive,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum Speed {
    Slow,
    Medium,
    Fast,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum WaveDirection {
    Right,
    Left,
    Up,
    FromCenter,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct Effect {
    pub kind: EffectKind,
    /// Não usada no arco-íris.
    pub color: Rgb,
    pub speed: Speed,
    /// Só na onda.
    pub direction: WaveDirection,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum ActionTrigger {
    Always,
    CapsLock,
    FnHeld,
    Pairing,
    LowBattery,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum LightMode {
    Solid,
    Pulse,
    Blink,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct ActionRule {
    pub key_id: String,
    pub trigger: ActionTrigger,
    pub color: Rgb,
    pub mode: LightMode,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum Brightness {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct KeyColor {
    pub key_id: String,
    pub color: Rgb,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct LightingConfig {
    pub effect: Effect,
    /// Cores pintadas tecla a tecla (camada do meio).
    pub key_colors: Vec<KeyColor>,
    /// Teclas de ação (camada de cima). Se duas valem para a mesma tecla, vence a última.
    pub actions: Vec<ActionRule>,
    pub brightness: Brightness,
    /// Onda de luz pelas teclas ao encaixar o e-reader.
    pub wave_on_dock: bool,
    /// Segurando fn, acender as teclas que têm função (fileira F), na cor da regra de fn.
    pub fn_map: bool,
    /// Apagar depois de 30 s sem digitar (economiza bateria).
    pub idle_off: bool,
}

/// Cores prontas oferecidas nas telas (além do seletor livre).
#[uniffi::export]
pub fn lighting_palette() -> Vec<Rgb> {
    [0x30d158, 0x64d2ff, 0x0a84ff, 0xbf5af2, 0xff9f0a, 0xff453a, 0xf2f2f7].map(Rgb::hex).to_vec()
}

#[uniffi::export]
pub fn default_lighting() -> LightingConfig {
    let rule = |key: &str, trigger, color, mode| ActionRule { key_id: key.into(), trigger, color: Rgb::hex(color), mode };
    LightingConfig {
        effect: Effect {
            kind: EffectKind::Wave,
            color: Rgb::hex(0x64d2ff),
            speed: Speed::Medium,
            direction: WaveDirection::Right,
        },
        key_colors: vec![],
        actions: vec![
            rule("L-caps", ActionTrigger::CapsLock, 0x30d158, LightMode::Solid),
            rule("L-fn", ActionTrigger::FnHeld, 0x0a84ff, LightMode::Solid),
            rule("L-yggi", ActionTrigger::Pairing, 0x0a84ff, LightMode::Blink),
            rule("L-esc", ActionTrigger::LowBattery, 0xff453a, LightMode::Pulse),
        ],
        brightness: Brightness::Medium,
        wave_on_dock: true,
        fn_map: true,
        idle_off: true,
    }
}

/// Luz de uma tecla num instante.
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct KeyGlow {
    pub key_id: String,
    pub color: Rgb,
    /// 0 a 1, já com o brilho aplicado.
    pub intensity: f32,
}

const DOCK_WAVE: Rgb = Rgb::hex(0x64d2ff);
const DOCK_WAVE_SECONDS: f64 = 0.65;
const REACTIVE_SECONDS: f64 = 1.1;
const FN_ROW: [&str; 12] = ["L-F1", "L-F2", "L-F3", "L-F4", "L-F5", "L-F6", "R-F7", "R-F8", "R-F9", "R-F10", "R-F11", "R-F12"];

fn speed_factor(speed: Speed) -> f64 {
    match speed {
        Speed::Slow => 1.6,
        Speed::Medium => 1.0,
        Speed::Fast => 0.55,
    }
}

fn brightness_factor(b: Brightness) -> f32 {
    match b {
        Brightness::Low => 0.45,
        Brightness::Medium => 0.75,
        Brightness::High => 1.0,
    }
}

/// Sobe e desce entre `low` e 1, começando em 1.
fn swing(t: f64, period: f64, low: f32) -> f32 {
    let v = 0.5 + 0.5 * ((t / period) as f32 * TAU).cos();
    low + (1.0 - low) * v
}

fn hsv(h: f32) -> Rgb {
    let h6 = h.rem_euclid(1.0) * 6.0;
    let x = 1.0 - (h6 % 2.0 - 1.0).abs();
    let (r, g, b) = match h6 as u32 {
        0 => (1.0, x, 0.0),
        1 => (x, 1.0, 0.0),
        2 => (0.0, 1.0, x),
        3 => (0.0, x, 1.0),
        4 => (x, 0.0, 1.0),
        _ => (1.0, 0.0, x),
    };
    Rgb { r: (r * 255.0) as u8, g: (g * 255.0) as u8, b: (b * 255.0) as u8 }
}

/// Posição da tecla ao longo da onda, de 0 a 1.
fn wave_position(key: &KeyDef, direction: WaveDirection) -> f32 {
    let cx = key.x + key.w / 2.0;
    match direction {
        WaveDirection::Right => (key.x - 4.0) / 15.0,
        WaveDirection::Left => (19.0 - key.x) / 15.0,
        WaveDirection::Up => (6.25 - key.y) / 6.25,
        WaveDirection::FromCenter => (cx - 11.5).abs() / 7.5,
    }
}

fn trigger_active(trigger: ActionTrigger, state: &KeyboardState, fn_held: bool) -> bool {
    match trigger {
        ActionTrigger::Always => true,
        ActionTrigger::CapsLock => state.caps_lock,
        ActionTrigger::FnHeld => fn_held,
        ActionTrigger::Pairing => state.pairing,
        ActionTrigger::LowBattery => [state.left, state.right]
            .iter()
            .filter_map(|h| h.battery)
            .any(is_low_battery),
    }
}

#[derive(Default)]
struct EngineState {
    presses: HashMap<String, f64>,
    dock_wave_at: Option<f64>,
}

/// Calcula as luzes quadro a quadro. Cada interface chama `frame` no seu relógio de tela.
#[derive(uniffi::Object)]
pub struct LightingEngine {
    keys: Vec<KeyDef>,
    config: Mutex<LightingConfig>,
    state: Mutex<EngineState>,
}

#[uniffi::export]
impl LightingEngine {
    #[uniffi::constructor]
    pub fn new(config: LightingConfig) -> Self {
        Self { keys: yggi_layout().keys, config: Mutex::new(config), state: Mutex::default() }
    }

    pub fn set_config(&self, config: LightingConfig) {
        *self.config.lock().unwrap() = config;
    }

    pub fn config(&self) -> LightingConfig {
        self.config.lock().unwrap().clone()
    }

    /// Uma tecla foi tocada no instante `at` (segundos, no mesmo relógio de `frame`).
    pub fn press(&self, key_id: String, at: f64) {
        self.state.lock().unwrap().presses.insert(key_id, at);
    }

    /// O e-reader acabou de encaixar: dispara a onda de luz, se estiver ligada.
    pub fn dock(&self, at: f64) {
        self.state.lock().unwrap().dock_wave_at = Some(at);
    }

    /// Luz de cada tecla acesa no instante `time`. Teclas apagadas não aparecem.
    pub fn frame(&self, state: KeyboardState, fn_held: bool, time: f64) -> Vec<KeyGlow> {
        let config = self.config.lock().unwrap().clone();
        let engine = self.state.lock().unwrap();
        let bright = brightness_factor(config.brightness);
        let effect = config.effect;
        let sp = speed_factor(effect.speed);
        let painted: HashMap<&str, Rgb> = config.key_colors.iter().map(|c| (c.key_id.as_str(), c.color)).collect();

        // Camada de cima: regra ativa de cada tecla (a última vence).
        let mut actions: HashMap<&str, (Rgb, LightMode)> = HashMap::new();
        let fn_rule = config.actions.iter().find(|r| r.trigger == ActionTrigger::FnHeld);
        if let (true, true, Some(rule)) = (config.fn_map, fn_held, fn_rule) {
            for id in FN_ROW {
                actions.insert(id, (rule.color, LightMode::Solid));
            }
        }
        for rule in &config.actions {
            if trigger_active(rule.trigger, &state, fn_held) {
                actions.insert(rule.key_id.as_str(), (rule.color, rule.mode));
            }
        }

        let mut out = Vec::new();
        for key in &self.keys {
            let (mut color, mut level) = if let Some(&(color, mode)) = actions.get(key.id.as_str()) {
                let level = match mode {
                    LightMode::Solid => 1.0,
                    LightMode::Pulse => swing(time, 1.6, 0.3),
                    LightMode::Blink => if (time / 0.9).fract() < 0.5 { 1.0 } else { 0.08 },
                };
                (color, level)
            } else if let Some(&color) = painted.get(key.id.as_str()) {
                (color, 1.0)
            } else {
                match effect.kind {
                    EffectKind::Off => (effect.color, 0.0),
                    EffectKind::Static => (effect.color, 1.0),
                    EffectKind::Breathing => (effect.color, swing(time, 3.0 * sp, 0.12)),
                    EffectKind::Wave => {
                        let period = 2.0 * sp;
                        let pos = wave_position(key, effect.direction) as f64;
                        (effect.color, swing(time + pos * period, period, 0.12))
                    }
                    EffectKind::Rainbow => {
                        let period = 5.0 * sp;
                        let pos = (key.x - 4.0) / 15.0;
                        (hsv((time / period) as f32 + pos), 1.0)
                    }
                    EffectKind::Reactive => {
                        let since = engine.presses.get(&key.id).map(|at| time - at);
                        let fade = REACTIVE_SECONDS * sp;
                        let level = match since {
                            Some(s) if (0.0..fade).contains(&s) => 1.0 - (s / fade) as f32,
                            _ => 0.0,
                        };
                        (effect.color, level)
                    }
                }
            };

            // Onda do encaixe do e-reader, da esquerda (lado do e-reader) para a direita.
            if let (true, Some(at)) = (config.wave_on_dock, engine.dock_wave_at) {
                let start = at + 0.25 + (key.x as f64 - 4.0) * 0.045;
                let s = time - start;
                if (0.0..DOCK_WAVE_SECONDS).contains(&s) {
                    let p = (s / DOCK_WAVE_SECONDS) as f32;
                    let wave = if p < 0.3 { p / 0.3 } else { 1.0 - (p - 0.3) / 0.7 };
                    if wave > level {
                        color = DOCK_WAVE;
                        level = wave;
                    }
                }
            }

            if level > 0.01 {
                out.push(KeyGlow { key_id: key.id.clone(), color, intensity: level * bright });
            }
        }
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::simulator::{Scenario, Simulator};
    use crate::keyboard::Keyboard;

    fn state() -> KeyboardState {
        Simulator::new(Scenario::Normal, false).state()
    }

    fn glow<'a>(frame: &'a [KeyGlow], id: &str) -> Option<&'a KeyGlow> {
        frame.iter().find(|g| g.key_id == id)
    }

    fn solid(effect: EffectKind) -> LightingConfig {
        let mut c = default_lighting();
        c.effect.kind = effect;
        c.brightness = Brightness::High;
        c
    }

    #[test]
    fn off_lights_nothing_without_actions() {
        let mut c = solid(EffectKind::Off);
        c.actions.clear();
        assert!(LightingEngine::new(c).frame(state(), false, 1.0).is_empty());
    }

    #[test]
    fn layers_action_over_paint_over_effect() {
        let mut c = solid(EffectKind::Static);
        c.effect.color = Rgb::hex(0x0000ff);
        c.key_colors = vec![
            KeyColor { key_id: "L-caps".into(), color: Rgb::hex(0xff00ff) },
            KeyColor { key_id: "L-a".into(), color: Rgb::hex(0xff00ff) },
        ];
        let engine = LightingEngine::new(c);
        let mut s = state();
        s.caps_lock = true;
        let f = engine.frame(s, false, 0.0);
        assert_eq!(glow(&f, "L-caps").unwrap().color, Rgb::hex(0x30d158)); // ação
        assert_eq!(glow(&f, "L-a").unwrap().color, Rgb::hex(0xff00ff)); // pintada
        assert_eq!(glow(&f, "L-q").unwrap().color, Rgb::hex(0x0000ff)); // efeito
    }

    #[test]
    fn caps_rule_follows_caps_lock() {
        let engine = LightingEngine::new(solid(EffectKind::Off));
        assert!(glow(&engine.frame(state(), false, 0.0), "L-caps").is_none());
        let mut s = state();
        s.caps_lock = true;
        assert!(glow(&engine.frame(s, false, 0.0), "L-caps").is_some());
    }

    #[test]
    fn fn_map_lights_the_f_row() {
        let engine = LightingEngine::new(solid(EffectKind::Off));
        let f = engine.frame(state(), true, 0.0);
        assert_eq!(glow(&f, "R-F9").unwrap().color, Rgb::hex(0x0a84ff));
        assert!(glow(&f, "L-fn").is_some());
    }

    #[test]
    fn low_battery_pulses_esc() {
        let engine = LightingEngine::new(solid(EffectKind::Off));
        let low = Simulator::new(Scenario::LowBattery, false).state();
        let a = glow(&engine.frame(low.clone(), false, 0.0), "L-esc").unwrap().intensity;
        let b = glow(&engine.frame(low, false, 0.8), "L-esc").unwrap().intensity;
        assert!(a > b);
    }

    #[test]
    fn reactive_fades_after_press() {
        let engine = LightingEngine::new(solid(EffectKind::Reactive));
        engine.press("L-a".into(), 10.0);
        assert!(glow(&engine.frame(state(), false, 10.1), "L-a").unwrap().intensity > 0.8);
        assert!(glow(&engine.frame(state(), false, 12.0), "L-a").is_none());
    }

    #[test]
    fn dock_wave_runs_left_to_right() {
        let engine = LightingEngine::new(solid(EffectKind::Off));
        engine.dock(0.0);
        let f = engine.frame(state(), false, 0.3);
        assert!(glow(&f, "L-esc").is_some());
        assert!(glow(&f, "R-lock").is_none());
    }

    #[test]
    fn brightness_scales_intensity() {
        let mut c = solid(EffectKind::Static);
        c.brightness = Brightness::Low;
        let f = LightingEngine::new(c).frame(state(), false, 0.0);
        assert!((glow(&f, "L-a").unwrap().intensity - 0.45).abs() < 1e-6);
    }
}
