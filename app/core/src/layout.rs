//! Layout físico do Yggi (v9, cenário B): onde cada tecla fica, em unidades de tecla (u).
//! Igual para todas as interfaces, que só desenham o que vem daqui.
//!
//! Coordenadas: x de 4 a 19 (o layout original reserva x 0–4 para a baia do e-reader,
//! que agora é um aparelho à parte), y de 0 a 6,25. A metade esquerda vai de x 4 a 11 e a
//! direita de x 12 a 19; juntas, as metades encostam (não há espaço entre elas).

/// Maior stagger que o mecanismo permite.
pub const MAX_STAGGER_PERCENT: u8 = 150;

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum Half {
    Left,
    Right,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum KeyKind {
    /// Letras, números e pontuação.
    Alpha,
    /// shift, command, espaço, setas…
    Modifier,
    /// Fileira F e esc.
    Function,
    /// A tecla Yggi (troca de computador).
    Yggi,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct KeyDef {
    /// Identificador estável (ex.: "L-caps"). Usado pelas luzes e estatísticas.
    pub id: String,
    /// Legenda principal.
    pub label: String,
    /// Legenda pequena de cima (símbolo do shift, ⌘…). Vazia se não houver.
    pub sub: String,
    /// Nome para leitores de tela.
    pub name: String,
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
    pub kind: KeyKind,
    pub half: Half,
    /// Coluna móvel a que a tecla pertence (índice em `KeyboardLayout::columns`). `None` = parte fixa.
    pub column: Option<u8>,
}

/// Uma coluna que desliza no stagger.
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct ColumnDef {
    pub index: u8,
    pub half: Half,
    pub x: f32,
    pub w: f32,
    /// Quanto a coluna sobe no stagger máximo (150%), em u.
    /// Médio 15 mm, anelar e indicador 9 mm, mindinho 0.
    pub lift_at_max: f32,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct KeyboardLayout {
    pub keys: Vec<KeyDef>,
    pub columns: Vec<ColumnDef>,
    /// As colunas móveis ocupam de y 0 até aqui; abaixo fica a barra do polegar, fixa.
    pub columns_bottom: f32,
    pub width: f32,
    pub height: f32,
    pub max_stagger_percent: u8,
}

struct K {
    id: &'static str,
    label: &'static str,
    sub: &'static str,
    name: Option<&'static str>,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    kind: KeyKind,
}

const fn k(id: &'static str, label: &'static str, x: f32, y: f32) -> K {
    K { id, label, sub: "", name: None, x, y, w: 1.0, h: 1.0, kind: KeyKind::Alpha }
}

impl K {
    const fn sub(mut self, sub: &'static str) -> Self {
        self.sub = sub;
        self
    }
    const fn w(mut self, w: f32) -> Self {
        self.w = w;
        self
    }
    const fn h(mut self, h: f32) -> Self {
        self.h = h;
        self
    }
    const fn kind(mut self, kind: KeyKind) -> Self {
        self.kind = kind;
        self
    }
    const fn name(mut self, name: &'static str) -> Self {
        self.name = Some(name);
        self
    }
    const fn func(self) -> Self {
        self.kind(KeyKind::Function)
    }
    const fn modifier(self) -> Self {
        self.kind(KeyKind::Modifier)
    }
}

/// (x, largura, subida a 150% em u) de cada coluna móvel, esquerda e direita.
const LEFT_COLUMNS: [(f32, f32, f32); 4] = [(6.0, 1.0, 0.0), (7.0, 1.0, 0.5), (8.0, 1.0, 0.83), (9.0, 2.0, 0.5)];
const RIGHT_COLUMNS: [(f32, f32, f32); 4] = [(12.0, 2.0, 0.5), (14.0, 1.0, 0.83), (15.0, 1.0, 0.5), (16.0, 1.0, 0.0)];
const COLUMNS_BOTTOM: f32 = 5.25;

fn keys_left() -> Vec<K> {
    vec![
        k("L-esc", "esc", 4.0, 0.0).func(),
        k("L-F1", "F1", 5.0, 0.0).func(),
        k("L-F2", "F2", 6.0, 0.0).func(),
        k("L-F3", "F3", 7.0, 0.0).func(),
        k("L-F4", "F4", 8.0, 0.0).func(),
        k("L-F5", "F5", 9.0, 0.0).func(),
        k("L-F6", "F6", 10.0, 0.0).func(),
        k("L-yggi", "yggi", 4.0, 1.25).sub("⇄").kind(KeyKind::Yggi).name("tecla Yggi"),
        k("L-grave", "`", 5.0, 1.25).sub("~"),
        k("L-1", "1", 6.0, 1.25).sub("!"),
        k("L-2", "2", 7.0, 1.25).sub("@"),
        k("L-3", "3", 8.0, 1.25).sub("#"),
        k("L-4", "4", 9.0, 1.25).sub("$"),
        k("L-5", "5", 10.0, 1.25).sub("%"),
        k("L-tab", "tab", 4.0, 2.25).sub("⇥").w(2.0).modifier(),
        k("L-q", "Q", 6.0, 2.25),
        k("L-w", "W", 7.0, 2.25),
        k("L-e", "E", 8.0, 2.25),
        k("L-r", "R", 9.0, 2.25),
        k("L-t", "T", 10.0, 2.25),
        k("L-caps", "caps lock", 4.0, 3.25).sub("⇪").w(2.0).modifier(),
        k("L-a", "A", 6.0, 3.25),
        k("L-s", "S", 7.0, 3.25),
        k("L-d", "D", 8.0, 3.25),
        k("L-f", "F", 9.0, 3.25),
        k("L-g", "G", 10.0, 3.25),
        k("L-shift", "shift", 4.0, 4.25).sub("⇧").w(2.0).modifier().name("shift esquerdo"),
        k("L-z", "Z", 6.0, 4.25),
        k("L-x", "X", 7.0, 4.25),
        k("L-c", "C", 8.0, 4.25),
        k("L-v", "V", 9.0, 4.25),
        k("L-b", "B", 10.0, 4.25),
        k("L-fn", "fn", 4.0, 5.25).modifier(),
        k("L-ctrl", "control", 5.0, 5.25).sub("⌃").modifier(),
        k("L-opt", "option", 6.0, 5.25).sub("⌥").modifier(),
        k("L-cmd", "command", 7.0, 5.25).sub("⌘").modifier().name("command esquerdo"),
        k("L-del", "delete", 8.0, 5.25).sub("⌫").w(1.5).modifier(),
        k("L-space", "espaço", 9.5, 5.25).w(1.5).modifier().name("espaço esquerdo"),
    ]
}

fn keys_right() -> Vec<K> {
    vec![
        k("R-F7", "F7", 12.0, 0.0).func(),
        k("R-F8", "F8", 13.0, 0.0).func(),
        k("R-F9", "F9", 14.0, 0.0).func(),
        k("R-F10", "F10", 15.0, 0.0).func(),
        k("R-F11", "F11", 16.0, 0.0).func(),
        k("R-F12", "F12", 17.0, 0.0).func(),
        k("R-lock", "lock", 18.0, 0.0).func().name("bloquear tela"),
        k("R-6", "6", 12.0, 1.25).sub("^"),
        k("R-7", "7", 13.0, 1.25).sub("&"),
        k("R-8", "8", 14.0, 1.25).sub("*"),
        k("R-9", "9", 15.0, 1.25).sub("("),
        k("R-0", "0", 16.0, 1.25).sub(")"),
        k("R-minus", "-", 17.0, 1.25).sub("_"),
        k("R-equal", "=", 18.0, 1.25).sub("+"),
        k("R-y", "Y", 12.0, 2.25),
        k("R-u", "U", 13.0, 2.25),
        k("R-i", "I", 14.0, 2.25),
        k("R-o", "O", 15.0, 2.25),
        k("R-p", "P", 16.0, 2.25),
        k("R-lbr", "[", 17.0, 2.25).sub("{"),
        k("R-rbr", "]", 18.0, 2.25).sub("}"),
        k("R-h", "H", 12.0, 3.25),
        k("R-j", "J", 13.0, 3.25),
        k("R-k", "K", 14.0, 3.25),
        k("R-l", "L", 15.0, 3.25),
        k("R-semi", ";", 16.0, 3.25).sub(":"),
        k("R-quote", "'", 17.0, 3.25).sub("\""),
        k("R-bslash", "\\", 18.0, 3.25).sub("|"),
        k("R-n", "N", 12.0, 4.25),
        k("R-m", "M", 13.0, 4.25),
        k("R-comma", ",", 14.0, 4.25).sub("<"),
        k("R-dot", ".", 15.0, 4.25).sub(">"),
        k("R-slash", "/", 16.0, 4.25).sub("?"),
        k("R-shift", "shift", 17.0, 4.25).sub("⇧").w(2.0).modifier().name("shift direito"),
        k("R-space", "espaço", 12.0, 5.25).w(1.5).modifier().name("espaço direito"),
        k("R-ret", "return", 13.5, 5.25).sub("↩").w(1.5).modifier(),
        k("R-cmd", "command", 15.0, 5.25).sub("⌘").modifier().name("command direito"),
        k("R-up", "↑", 17.0, 5.25).h(0.5).modifier().name("seta para cima"),
        k("R-left", "←", 16.0, 5.75).h(0.5).modifier().name("seta para a esquerda"),
        k("R-down", "↓", 17.0, 5.75).h(0.5).modifier().name("seta para baixo"),
        k("R-right", "→", 18.0, 5.75).h(0.5).modifier().name("seta para a direita"),
    ]
}

fn columns() -> Vec<ColumnDef> {
    LEFT_COLUMNS
        .iter()
        .map(|c| (Half::Left, c))
        .chain(RIGHT_COLUMNS.iter().map(|c| (Half::Right, c)))
        .enumerate()
        .map(|(i, (half, &(x, w, lift)))| ColumnDef { index: i as u8, half, x, w, lift_at_max: lift })
        .collect()
}

fn column_of(columns: &[ColumnDef], half: Half, x: f32, y: f32) -> Option<u8> {
    if y >= COLUMNS_BOTTOM {
        return None;
    }
    columns
        .iter()
        .find(|c| c.half == half && x >= c.x && x < c.x + c.w)
        .map(|c| c.index)
}

/// O layout completo do Yggi.
#[uniffi::export]
pub fn yggi_layout() -> KeyboardLayout {
    let columns = columns();
    let mut keys = Vec::new();
    for (half, list) in [(Half::Left, keys_left()), (Half::Right, keys_right())] {
        for key in list {
            keys.push(KeyDef {
                id: key.id.into(),
                label: key.label.into(),
                sub: key.sub.into(),
                name: key.name.unwrap_or(key.label).into(),
                x: key.x,
                y: key.y,
                w: key.w,
                h: key.h,
                kind: key.kind,
                half,
                column: column_of(&columns, half, key.x, key.y),
            });
        }
    }
    KeyboardLayout {
        keys,
        columns,
        columns_bottom: COLUMNS_BOTTOM,
        width: 15.0,
        height: 6.25,
        max_stagger_percent: MAX_STAGGER_PERCENT,
    }
}

/// Quanto uma coluna está levantada (em u) num dado stagger (0 = ortho, 150 = máximo).
#[uniffi::export]
pub fn column_lift(column: ColumnDef, stagger_percent: u8) -> f32 {
    column.lift_at_max * stagger_percent.min(MAX_STAGGER_PERCENT) as f32 / MAX_STAGGER_PERCENT as f32
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn has_all_keys_with_unique_ids() {
        let layout = yggi_layout();
        assert_eq!(layout.keys.len(), 79);
        let mut ids: Vec<_> = layout.keys.iter().map(|k| k.id.clone()).collect();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), 79);
    }

    #[test]
    fn keys_belong_to_the_right_columns() {
        let layout = yggi_layout();
        let key = |id: &str| layout.keys.iter().find(|k| k.id == id).unwrap().clone();
        let col = |id: &str| key(id).column.map(|c| layout.columns[c as usize].clone());

        assert_eq!(col("L-e").unwrap().lift_at_max, 0.83); // médio
        assert_eq!(col("L-t").unwrap().x, 9.0); // indicador de 2u
        assert!(col("L-caps").is_none()); // coluna fixa
        assert!(col("L-space").is_none()); // barra do polegar
        assert_eq!(col("R-p").unwrap().lift_at_max, 0.0); // mindinho
    }

    #[test]
    fn lift_scales_with_stagger() {
        let layout = yggi_layout();
        let middle = || layout.columns[2].clone();
        assert_eq!(column_lift(middle(), 0), 0.0);
        assert!((column_lift(middle(), 150) - 0.83).abs() < 1e-6);
        assert!((column_lift(middle(), 75) - 0.415).abs() < 1e-6);
        assert_eq!(column_lift(middle(), 200), column_lift(middle(), 150));
    }
}
