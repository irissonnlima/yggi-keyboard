//! `KeyboardSession`: o único objeto que as interfaces usam para falar com o teclado,
//! seja ele simulado ou real.

use std::sync::Arc;

use crate::keyboard::{Keyboard, KeyboardError, StateListener};
use crate::lighting::LightingConfig;
use crate::model::KeyboardState;
use crate::simulator::Simulator;
use crate::stats::{Statistics, StatsPeriod};

#[derive(uniffi::Object)]
pub struct KeyboardSession {
    keyboard: Arc<dyn Keyboard>,
}

#[uniffi::export]
impl KeyboardSession {
    /// Sessão com o teclado simulado. O mesmo `Simulator` serve para controlar a simulação.
    #[uniffi::constructor]
    pub fn simulated(simulator: Arc<Simulator>) -> Arc<Self> {
        Arc::new(Self { keyboard: simulator })
    }

    pub fn state(&self) -> KeyboardState {
        self.keyboard.state()
    }

    /// Passa a receber cada mudança de estado. Devolve um id para `unsubscribe`.
    /// O estado atual chega logo em seguida, então a interface não precisa pedir `state()` antes.
    pub fn subscribe(&self, listener: Arc<dyn StateListener>) -> u64 {
        let id = self.keyboard.listeners().add(listener.clone());
        listener.on_state(self.keyboard.state());
        id
    }

    pub fn unsubscribe(&self, id: u64) {
        self.keyboard.listeners().remove(id);
    }

    pub fn connect(&self) -> Result<(), KeyboardError> {
        self.keyboard.connect()
    }

    pub fn disconnect(&self) -> Result<(), KeyboardError> {
        self.keyboard.disconnect()
    }

    pub fn select_host(&self, index: u8) -> Result<(), KeyboardError> {
        self.keyboard.select_host(index)
    }

    pub fn lighting(&self) -> Result<LightingConfig, KeyboardError> {
        self.keyboard.lighting()
    }

    /// "Enviar ao teclado" da tela de luzes.
    pub fn set_lighting(&self, config: LightingConfig) -> Result<(), KeyboardError> {
        self.keyboard.set_lighting(config)
    }

    pub fn statistics(&self, period: StatsPeriod) -> Result<Statistics, KeyboardError> {
        self.keyboard.statistics(period)
    }
}
