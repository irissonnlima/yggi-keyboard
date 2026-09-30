//! Modelo do teclado: o que o app sabe sobre o Yggi num dado momento.
//! Tipos de valor, sem Bluetooth nem interface. Atravessam a ponte para Swift.

/// Quantos computadores o teclado guarda (limite do ZMK).
pub const HOST_SLOTS: u8 = 5;

/// Computadores que a tecla Yggi alterna: um por perninha da marca, que acende no ativo.
pub const YGGI_KEY_HOSTS: u8 = 3;

/// Abaixo deste nível a bateria é considerada baixa.
pub const LOW_BATTERY_PERCENT: u8 = 15;

/// Por onde o app fala com o teclado.
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum Transport {
    Bluetooth,
    /// Cabo USB-C. Com as metades encaixadas, carrega as duas.
    Usb,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum Connection {
    Disconnected,
    Connecting,
    Connected { transport: Transport },
}

/// O e-reader destacável (fase 2). O teclado funciona sem ele.
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum ReaderState {
    /// Encaixado na lateral esquerda, pelos ímãs e pogo.
    Docked,
    /// Ligado, mas solto do teclado.
    Loose,
    /// Não há e-reader.
    Absent,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct Battery {
    /// 0 a 100.
    pub level: u8,
    pub charging: bool,
}

/// Uma metade do teclado. A esquerda fala com o computador; a direita chega por ela.
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct HalfStatus {
    /// A metade está ligada e falando com a outra.
    pub reachable: bool,
    /// `None` quando o nível não é conhecido.
    pub battery: Option<Battery>,
}

/// Uma das 5 vagas de computador do teclado.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct HostSlot {
    /// 0 a 4. Na tecla Yggi, segurar + 1…5.
    pub index: u8,
    /// Nome do computador, se conhecido. Onde o nome fica guardado ainda está em aberto.
    pub name: Option<String>,
    pub paired: bool,
    /// Esta vaga é o computador onde o app está rodando.
    pub is_this_computer: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct KeyboardState {
    pub connection: Connection,
    pub left: HalfStatus,
    pub right: HalfStatus,
    /// Vaga do computador ativo. `None` quando não se sabe.
    pub active_host: Option<u8>,
    /// Sempre `HOST_SLOTS` vagas, na ordem.
    pub hosts: Vec<HostSlot>,
    /// Abertura do stagger, de 0 (ortho) a 100%. Depende de um sensor no teclado (em aberto).
    pub stagger_percent: u8,
    /// Metades encaixadas pelo pogo (um teclado só) ou separadas.
    pub halves_joined: bool,
    pub reader: ReaderState,
    /// Estado do caps lock informado pelo computador (relatório de LEDs do HID).
    pub caps_lock: bool,
    /// A tecla Yggi foi segurada 3 s e o teclado está pareando.
    pub pairing: bool,
}

impl KeyboardState {
    pub fn is_connected(&self) -> bool {
        matches!(self.connection, Connection::Connected { .. })
    }

    pub fn host(&self, index: u8) -> Option<&HostSlot> {
        self.hosts.iter().find(|h| h.index == index)
    }
}

// Regras expostas às interfaces, para ficarem num lugar só em todas as plataformas.

#[uniffi::export]
pub fn is_low_battery(battery: Battery) -> bool {
    !battery.charging && battery.level < LOW_BATTERY_PERCENT
}

/// A menor bateria entre as metades alcançáveis (o que a barra de menus mostra).
#[uniffi::export]
pub fn lowest_battery(state: KeyboardState) -> Option<Battery> {
    [state.left, state.right]
        .into_iter()
        .filter(|h| h.reachable)
        .filter_map(|h| h.battery)
        .min_by_key(|b| b.level)
}

#[uniffi::export]
pub fn host_slot_count() -> u8 {
    HOST_SLOTS
}
