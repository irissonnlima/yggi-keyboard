//! Núcleo do app Yggi, independente de plataforma.
//!
//! - `model`: o estado do teclado (conexão, baterias, computadores, stagger, e-reader).
//! - `layout`: onde cada tecla fica e quanto cada coluna sobe no stagger.
//! - `lighting`: luz de cada tecla (efeito, cores por tecla, teclas de ação).
//! - `stats`: estatísticas de digitação (só contagens).
//! - `menubar`: abas e widgets do popover da barra de menus.
//! - `keyboard`: a interface que o teclado simulado e o real implementam.
//! - `simulator`: o teclado simulado, usado enquanto o firmware não existe.
//! - `session`: `KeyboardSession`, o ponto de entrada das interfaces.
//!
//! As interfaces de cada sistema (Swift no macOS hoje) chamam este núcleo pela ponte
//! gerada pelo UniFFI. Nada aqui depende de interface gráfica.

pub mod keyboard;
pub mod layout;
pub mod lighting;
pub mod menubar;
pub mod model;
pub mod session;
pub mod simulator;
pub mod stats;

pub use keyboard::{Keyboard, KeyboardError, StateListener};
pub use model::*;
pub use session::KeyboardSession;
pub use simulator::{Scenario, Simulator};

uniffi::setup_scaffolding!();
