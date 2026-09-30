//! A interface do teclado. O simulador e, depois, o teclado real implementam `Keyboard`.
//! As interfaces (Swift, Windows, Linux) só enxergam `KeyboardSession` (ver `session.rs`).

use std::sync::{Arc, Mutex};

use crate::lighting::LightingConfig;
use crate::model::KeyboardState;
use crate::stats::{Statistics, StatsPeriod};

/// Chega às interfaces só com a mensagem (`flat_error`), já em português,
/// para todas as plataformas mostrarem o mesmo texto.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error, uniffi::Error)]
#[uniffi(flat_error)]
pub enum KeyboardError {
    #[error("o teclado não está conectado")]
    NotConnected,
    #[error("não existe a vaga de computador {}", .index + 1)]
    InvalidHost { index: u8 },
    #[error("a vaga {} não tem computador pareado", .index + 1)]
    HostNotPaired { index: u8 },
}

/// Recebe cada mudança de estado. Implementado pela interface (ex.: Swift).
/// Pode ser chamado de qualquer thread.
#[uniffi::export(with_foreign)]
pub trait StateListener: Send + Sync {
    fn on_state(&self, state: KeyboardState);
}

pub trait Keyboard: Send + Sync {
    fn state(&self) -> KeyboardState;
    fn connect(&self) -> Result<(), KeyboardError>;
    fn disconnect(&self) -> Result<(), KeyboardError>;
    /// Troca o computador ativo, como segurar a tecla Yggi + número.
    fn select_host(&self, index: u8) -> Result<(), KeyboardError>;
    /// As regras de luz gravadas no teclado.
    fn lighting(&self) -> Result<LightingConfig, KeyboardError>;
    /// Grava as regras de luz no teclado (funcionam sem o app).
    fn set_lighting(&self, config: LightingConfig) -> Result<(), KeyboardError>;
    fn statistics(&self, period: StatsPeriod) -> Result<Statistics, KeyboardError>;
    fn listeners(&self) -> &Listeners;
}

/// Lista de ouvintes compartilhada pelas implementações de `Keyboard`.
#[derive(Default)]
pub struct Listeners {
    inner: Mutex<ListenersInner>,
}

#[derive(Default)]
struct ListenersInner {
    next_id: u64,
    entries: Vec<(u64, Arc<dyn StateListener>)>,
}

impl Listeners {
    pub fn add(&self, listener: Arc<dyn StateListener>) -> u64 {
        let mut inner = self.inner.lock().unwrap();
        inner.next_id += 1;
        let id = inner.next_id;
        inner.entries.push((id, listener));
        id
    }

    pub fn remove(&self, id: u64) {
        self.inner.lock().unwrap().entries.retain(|(i, _)| *i != id);
    }

    /// Avisa todos. Nunca chame segurando outra trava: o ouvinte pode chamar o teclado de volta.
    pub fn notify(&self, state: &KeyboardState) {
        let entries: Vec<_> = self.inner.lock().unwrap().entries.iter().map(|(_, l)| l.clone()).collect();
        for listener in entries {
            listener.on_state(state.clone());
        }
    }
}
