//! Teclado simulado, para desenvolver o app antes do firmware existir.
//!
//! O tempo anda em passos (`advance`). Com `animated`, uma thread dá um passo por segundo:
//! a bateria desce (ou sobe no USB) e a conexão termina de se estabelecer.
//! Sem `animated`, nada muda sozinho: bom para prévias e testes.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, Weak};
use std::thread;
use std::time::Duration;

use crate::keyboard::{Keyboard, KeyboardError, Listeners};
use crate::layout::MAX_STAGGER_PERCENT;
use crate::lighting::{LightingConfig, default_lighting};
use crate::model::{
    Battery, Connection, HOST_SLOTS, HalfStatus, YGGI_KEY_HOSTS, HostSlot, KeyboardState, ReaderState, Transport,
};
use crate::stats::{Statistics, StatsPeriod, simulated_statistics};

const TICK: Duration = Duration::from_secs(1);
/// Passos até a conexão se estabelecer.
const CONNECT_TICKS: u8 = 2;
/// A metade esquerda perde 1% a cada tantos passos; ela fala com o computador e gasta mais.
const LEFT_DRAIN_EVERY: u64 = 3;
const RIGHT_DRAIN_EVERY: u64 = 5;
/// Quanto a bateria sobe por passo no USB.
const CHARGE_PER_TICK: u8 = 2;

/// Situações prontas para prévias, testes e demonstração.
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum Scenario {
    /// Conectado por Bluetooth a este computador, baterias boas.
    Normal,
    LowBattery,
    /// Metades encaixadas no USB-C, carregando.
    Charging,
    /// A metade direita não responde (desligada ou longe).
    RightHalfOffline,
    /// O teclado está com outro computador.
    OtherComputer,
    Disconnected,
}

/// O que o teclado simulado "é" de verdade. O app vê só o que seria visível (ver `visible`).
#[derive(Debug, Clone)]
struct SimState {
    connection: Connection,
    connecting_ticks: u8,
    usb: bool,
    left: Battery,
    right: Battery,
    right_on: bool,
    active_host: u8,
    hosts: Vec<HostSlot>,
    ticks: u64,
    stagger_percent: u8,
    halves_joined: bool,
    reader: ReaderState,
    caps_lock: bool,
    pairing: bool,
    lighting: LightingConfig,
}

impl SimState {
    fn new(scenario: Scenario) -> Self {
        let names = ["MacBook Pro", "Mac mini", "iPad"];
        let hosts = (0..HOST_SLOTS)
            .map(|index| HostSlot {
                index,
                name: names.get(index as usize).map(|n| n.to_string()),
                paired: (index as usize) < names.len(),
                is_this_computer: index == 0,
            })
            .collect();
        let mut s = Self {
            connection: Connection::Connected { transport: Transport::Bluetooth },
            connecting_ticks: 0,
            usb: false,
            left: Battery { level: 82, charging: false },
            right: Battery { level: 76, charging: false },
            right_on: true,
            active_host: 0,
            hosts,
            ticks: 0,
            stagger_percent: 0,
            halves_joined: true,
            reader: ReaderState::Docked,
            caps_lock: false,
            pairing: false,
            lighting: default_lighting(),
        };
        match scenario {
            Scenario::Normal => {}
            Scenario::LowBattery => {
                s.left.level = 12;
                s.right.level = 7;
            }
            Scenario::Charging => s.set_usb(true),
            Scenario::RightHalfOffline => s.right_on = false,
            Scenario::OtherComputer => s.active_host = 1,
            Scenario::Disconnected => s.connection = Connection::Disconnected,
        }
        s
    }

    fn set_usb(&mut self, plugged: bool) {
        self.usb = plugged;
        self.left.charging = plugged;
        self.right.charging = plugged;
        if let Connection::Connected { .. } = self.connection {
            self.connection = Connection::Connected { transport: self.transport() };
        }
    }

    fn transport(&self) -> Transport {
        if self.usb { Transport::Usb } else { Transport::Bluetooth }
    }

    fn step(&mut self) {
        self.ticks += 1;

        if self.connection == Connection::Connecting {
            self.connecting_ticks = self.connecting_ticks.saturating_sub(1);
            if self.connecting_ticks == 0 {
                self.connection = Connection::Connected { transport: self.transport() };
            }
        }

        step_battery(&mut self.left, self.ticks, LEFT_DRAIN_EVERY);
        if self.right_on {
            step_battery(&mut self.right, self.ticks, RIGHT_DRAIN_EVERY);
        }
    }

    fn connect(&mut self) {
        if self.connection == Connection::Disconnected {
            self.connection = Connection::Connecting;
            self.connecting_ticks = CONNECT_TICKS;
        }
    }

    fn select_host(&mut self, index: u8) -> Result<(), KeyboardError> {
        let host = self
            .hosts
            .iter()
            .find(|h| h.index == index)
            .ok_or(KeyboardError::InvalidHost { index })?;
        if !host.paired {
            return Err(KeyboardError::HostNotPaired { index });
        }
        self.active_host = index;
        Ok(())
    }

    /// Toque na tecla Yggi: vai para o próximo computador pareado.
    /// A tecla Yggi passa para o próximo computador pareado entre os `YGGI_KEY_HOSTS` primeiros.
    fn tap_yggi_key(&mut self) {
        let paired: Vec<u8> = self.hosts.iter().filter(|h| h.paired && h.index < YGGI_KEY_HOSTS).map(|h| h.index).collect();
        if let Some(pos) = paired.iter().position(|&i| i == self.active_host) {
            self.active_host = paired[(pos + 1) % paired.len()];
        } else if let Some(&first) = paired.first() {
            self.active_host = first;
        }
    }

    /// O que o app enxergaria. Desconectado, ele não sabe bateria nem computador ativo.
    fn visible(&self) -> KeyboardState {
        let connected = matches!(self.connection, Connection::Connected { .. });
        let half = |on: bool, battery: Battery| HalfStatus {
            reachable: connected && on,
            battery: (connected && on).then_some(battery),
        };
        KeyboardState {
            connection: self.connection,
            left: half(true, self.left),
            right: half(self.right_on, self.right),
            active_host: connected.then_some(self.active_host),
            hosts: self.hosts.clone(),
            stagger_percent: self.stagger_percent,
            halves_joined: self.halves_joined,
            reader: self.reader,
            caps_lock: connected && self.caps_lock,
            pairing: self.pairing,
        }
    }
}

fn step_battery(b: &mut Battery, ticks: u64, drain_every: u64) {
    if b.charging {
        b.level = (b.level + CHARGE_PER_TICK).min(100);
    } else if ticks % drain_every == 0 {
        b.level = b.level.saturating_sub(1);
    }
}

/// Teclado simulado. Também é o painel de controle da simulação.
#[derive(uniffi::Object)]
pub struct Simulator {
    state: Mutex<SimState>,
    animated: AtomicBool,
    listeners: Listeners,
}

#[uniffi::export]
impl Simulator {
    #[uniffi::constructor]
    pub fn new(scenario: Scenario, animated: bool) -> Arc<Self> {
        let sim = Arc::new(Self {
            state: Mutex::new(SimState::new(scenario)),
            animated: AtomicBool::new(animated),
            listeners: Listeners::default(),
        });
        spawn_clock(Arc::downgrade(&sim));
        sim
    }

    pub fn load_scenario(&self, scenario: Scenario) {
        self.update(|s| *s = SimState::new(scenario));
    }

    pub fn set_animated(&self, animated: bool) {
        self.animated.store(animated, Ordering::Relaxed);
    }

    pub fn is_animated(&self) -> bool {
        self.animated.load(Ordering::Relaxed)
    }

    /// Avança o tempo `ticks` passos (1 passo = 1 s quando animado).
    pub fn advance(&self, ticks: u32) {
        self.update(|s| (0..ticks).for_each(|_| s.step()));
    }

    pub fn tap_yggi_key(&self) {
        self.update(SimState::tap_yggi_key);
    }

    pub fn set_usb(&self, plugged: bool) {
        self.update(|s| s.set_usb(plugged));
    }

    pub fn set_right_half_on(&self, on: bool) {
        self.update(|s| s.right_on = on);
    }

    /// Solta as colunas (0 = ortho, até 100%). Na mão, é o botão ao lado dos LEDs.
    pub fn set_stagger(&self, percent: u8) {
        self.update(|s| s.stagger_percent = percent.min(MAX_STAGGER_PERCENT));
    }

    pub fn set_halves_joined(&self, joined: bool) {
        self.update(|s| s.halves_joined = joined);
    }

    pub fn set_reader(&self, reader: ReaderState) {
        self.update(|s| s.reader = reader);
    }

    /// No teclado real, o computador informa o caps lock.
    pub fn set_caps_lock(&self, on: bool) {
        self.update(|s| s.caps_lock = on);
    }

    /// Segurar a tecla Yggi 3 s.
    pub fn set_pairing(&self, on: bool) {
        self.update(|s| s.pairing = on);
    }

    pub fn is_usb(&self) -> bool {
        self.state.lock().unwrap().usb
    }

    pub fn is_right_half_on(&self) -> bool {
        self.state.lock().unwrap().right_on
    }
}

impl Simulator {
    fn update<R>(&self, f: impl FnOnce(&mut SimState) -> R) -> R {
        let (result, visible) = {
            let mut s = self.state.lock().unwrap();
            let before = s.visible();
            let result = f(&mut s);
            let after = s.visible();
            (result, (after != before).then_some(after))
        };
        if let Some(state) = visible {
            self.listeners.notify(&state);
        }
        result
    }
}

impl Keyboard for Simulator {
    fn state(&self) -> KeyboardState {
        self.state.lock().unwrap().visible()
    }

    fn connect(&self) -> Result<(), KeyboardError> {
        self.update(SimState::connect);
        Ok(())
    }

    fn disconnect(&self) -> Result<(), KeyboardError> {
        self.update(|s| s.connection = Connection::Disconnected);
        Ok(())
    }

    fn select_host(&self, index: u8) -> Result<(), KeyboardError> {
        self.update(|s| {
            if !matches!(s.connection, Connection::Connected { .. }) {
                return Err(KeyboardError::NotConnected);
            }
            s.select_host(index)
        })
    }

    fn lighting(&self) -> Result<LightingConfig, KeyboardError> {
        Ok(self.state.lock().unwrap().lighting.clone())
    }

    fn set_lighting(&self, config: LightingConfig) -> Result<(), KeyboardError> {
        let mut s = self.state.lock().unwrap();
        if !matches!(s.connection, Connection::Connected { .. }) {
            return Err(KeyboardError::NotConnected);
        }
        s.lighting = config;
        Ok(())
    }

    fn statistics(&self, period: StatsPeriod) -> Result<Statistics, KeyboardError> {
        Ok(simulated_statistics(period))
    }

    fn listeners(&self) -> &Listeners {
        &self.listeners
    }
}

/// Relógio da simulação. Para sozinho quando o `Simulator` deixa de existir.
fn spawn_clock(sim: Weak<Simulator>) {
    thread::Builder::new()
        .name("yggi-simulator".into())
        .spawn(move || {
            loop {
                thread::sleep(TICK);
                let Some(sim) = sim.upgrade() else { break };
                if sim.is_animated() {
                    sim.advance(1);
                }
            }
        })
        .expect("não foi possível iniciar o relógio do simulador");
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::keyboard::StateListener;

    fn sim(scenario: Scenario) -> Arc<Simulator> {
        Simulator::new(scenario, false)
    }

    #[test]
    fn normal_starts_connected_on_this_computer() {
        let s = sim(Scenario::Normal).state();
        assert!(s.is_connected());
        assert_eq!(s.active_host, Some(0));
        assert!(s.host(0).unwrap().is_this_computer);
        assert_eq!(s.hosts.len(), HOST_SLOTS as usize);
        assert_eq!(s.left.battery.unwrap().level, 82);
    }

    #[test]
    fn disconnected_hides_what_the_app_cannot_know() {
        let s = sim(Scenario::Disconnected).state();
        assert_eq!(s.connection, Connection::Disconnected);
        assert_eq!(s.active_host, None);
        assert_eq!(s.left.battery, None);
        assert!(!s.right.reachable);
    }

    #[test]
    fn connect_takes_a_couple_of_ticks() {
        let sim = sim(Scenario::Disconnected);
        sim.connect().unwrap();
        assert_eq!(sim.state().connection, Connection::Connecting);
        sim.advance(CONNECT_TICKS as u32);
        assert_eq!(
            sim.state().connection,
            Connection::Connected { transport: Transport::Bluetooth }
        );
    }

    #[test]
    fn battery_drains_left_faster_and_charges_on_usb() {
        let sim = sim(Scenario::Normal);
        sim.advance(15);
        let s = sim.state();
        assert_eq!(s.left.battery.unwrap().level, 82 - 5);
        assert_eq!(s.right.battery.unwrap().level, 76 - 3);

        sim.set_usb(true);
        sim.advance(100);
        let s = sim.state();
        assert_eq!(s.left.battery, Some(Battery { level: 100, charging: true }));
        assert_eq!(s.connection, Connection::Connected { transport: Transport::Usb });
    }

    #[test]
    fn right_half_offline_has_no_battery() {
        let s = sim(Scenario::RightHalfOffline).state();
        assert!(!s.right.reachable);
        assert_eq!(s.right.battery, None);
        assert!(s.left.reachable);
    }

    #[test]
    fn select_host_validates() {
        let sim = sim(Scenario::Normal);
        assert_eq!(sim.select_host(9), Err(KeyboardError::InvalidHost { index: 9 }));
        assert_eq!(sim.select_host(4), Err(KeyboardError::HostNotPaired { index: 4 }));
        sim.select_host(2).unwrap();
        assert_eq!(sim.state().active_host, Some(2));

        sim.disconnect().unwrap();
        assert_eq!(sim.select_host(1), Err(KeyboardError::NotConnected));
    }

    #[test]
    fn yggi_key_cycles_through_paired_hosts() {
        let sim = sim(Scenario::Normal);
        let mut seen = vec![];
        for _ in 0..4 {
            sim.tap_yggi_key();
            seen.push(sim.state().active_host.unwrap());
        }
        assert_eq!(seen, [1, 2, 0, 1]);
    }

    #[test]
    fn yggi_key_only_cycles_the_three_legs() {
        // Um 4º computador pareado não entra no ciclo da tecla (a marca só tem 3 perninhas).
        let mut s = SimState::new(Scenario::Normal);
        s.hosts[3].paired = true;
        s.active_host = 2;
        s.tap_yggi_key();
        assert_eq!(s.active_host, 0);
    }

    #[test]
    fn physical_state_is_reported() {
        let sim = sim(Scenario::Normal);
        let s = sim.state();
        assert_eq!((s.stagger_percent, s.halves_joined, s.reader), (0, true, ReaderState::Docked));
        sim.set_stagger(200);
        sim.set_halves_joined(false);
        sim.set_reader(ReaderState::Loose);
        sim.set_caps_lock(true);
        let s = sim.state();
        assert_eq!((s.stagger_percent, s.halves_joined, s.reader, s.caps_lock), (100, false, ReaderState::Loose, true));
    }

    #[test]
    fn lighting_is_stored_on_the_keyboard() {
        let sim = sim(Scenario::Normal);
        let mut config = sim.lighting().unwrap();
        config.fn_map = false;
        sim.set_lighting(config.clone()).unwrap();
        assert_eq!(sim.lighting().unwrap(), config);

        sim.disconnect().unwrap();
        assert_eq!(sim.set_lighting(config), Err(KeyboardError::NotConnected));
    }

    #[test]
    fn listeners_get_changes_only() {
        struct Count(Mutex<Vec<KeyboardState>>);
        impl StateListener for Count {
            fn on_state(&self, state: KeyboardState) {
                self.0.lock().unwrap().push(state);
            }
        }
        let sim = sim(Scenario::Normal);
        let count = Arc::new(Count(Mutex::new(vec![])));
        let id = sim.listeners().add(count.clone());

        sim.advance(1); // nenhuma bateria mudou ainda
        sim.advance(2); // passo 3: esquerda perde 1%
        sim.tap_yggi_key();
        assert_eq!(count.0.lock().unwrap().len(), 2);

        sim.listeners().remove(id);
        sim.tap_yggi_key();
        assert_eq!(count.0.lock().unwrap().len(), 2);
    }
}
