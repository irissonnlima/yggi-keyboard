//! Barra de menus: abas montadas com widgets, iguais em qualquer sistema.
//!
//! A interface só desenha e repassa gestos. Este módulo decide que widgets existem, que
//! tamanhos cada um aceita, onde cada widget cai na grade de 3 colunas, como abas e widgets
//! são editados e como a configuração é guardada.
//!
//! Toda operação recebe a configuração e devolve uma nova. Pedidos inválidos (id que não
//! existe, tamanho que o widget não aceita) devolvem a configuração sem mudança.

/// Colunas da grade de cada aba.
pub const GRID_COLUMNS: u8 = 3;
/// Máximo de abas (cabem na largura do popover).
pub const MAX_TABS: usize = 6;
/// Máximo de caracteres no nome de uma aba.
pub const MAX_TAB_NAME: usize = 20;

const HEADER: &str = "yggi-menubar 2";
/// Versão sem posições: os widgets eram encaixados na ordem.
const HEADER_V1: &str = "yggi-menubar 1";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, uniffi::Enum)]
pub enum WidgetKind {
    /// Teclado desenhado, abrir/fechar e posições salvas.
    Stagger,
    /// Só o botão de abrir/fechar.
    StaggerQuick,
    /// Computador ativo; toque para o próximo.
    ActiveHost,
    /// Lista dos computadores pareados.
    Hosts,
    /// Camada e perfil ativos.
    Layer,
    Battery,
    /// Metades juntas ou separadas, e-reader.
    Halves,
    /// Brilho e efeito das luzes.
    Brightness,
    LightColor,
    /// Palavras, ritmo e tempo digitando.
    Today,
    DailyGoal,
    /// Teclas mais usadas (só contagens).
    Heatmap,
    /// Tempo até a próxima pausa.
    Break,
    QuickActions,
    /// Uma tecla, macro ou camada escolhida pela pessoa.
    CustomButton,
    Firmware,
}

/// Tamanho em colunas × linhas da grade.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, uniffi::Enum)]
pub enum WidgetSize {
    OneByOne,
    TwoByOne,
    ThreeByOne,
    /// Em pé: uma coluna, duas linhas.
    OneByTwo,
    TwoByTwo,
    ThreeByTwo,
}

impl WidgetSize {
    pub const ALL: [WidgetSize; 6] = [Self::OneByOne, Self::TwoByOne, Self::ThreeByOne, Self::OneByTwo, Self::TwoByTwo, Self::ThreeByTwo];

    pub fn columns(self) -> u8 {
        match self {
            Self::OneByOne | Self::OneByTwo => 1,
            Self::TwoByOne | Self::TwoByTwo => 2,
            Self::ThreeByOne | Self::ThreeByTwo => 3,
        }
    }

    pub fn rows(self) -> u8 {
        match self {
            Self::OneByOne | Self::TwoByOne | Self::ThreeByOne => 1,
            Self::OneByTwo | Self::TwoByTwo | Self::ThreeByTwo => 2,
        }
    }

    fn area(self) -> u8 {
        self.columns() * self.rows()
    }

    fn code(self) -> String {
        format!("{}x{}", self.columns(), self.rows())
    }

    fn from_code(code: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|s| s.code() == code)
    }
}

#[uniffi::export]
pub fn widget_size_columns(size: WidgetSize) -> u8 {
    size.columns()
}

#[uniffi::export]
pub fn widget_size_rows(size: WidgetSize) -> u8 {
    size.rows()
}

/// "2×1", para mostrar na interface.
#[uniffi::export]
pub fn widget_size_label(size: WidgetSize) -> String {
    format!("{}×{}", size.columns(), size.rows())
}

/// O que a biblioteca de widgets mostra sobre cada tipo.
#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct WidgetInfo {
    pub kind: WidgetKind,
    pub name: String,
    pub category: String,
    /// Uma linha explicando o widget.
    pub summary: String,
    /// Tamanhos aceitos; o primeiro é o padrão ao adicionar.
    pub sizes: Vec<WidgetSize>,
}

const KINDS: [WidgetKind; 16] = [
    WidgetKind::Stagger,
    WidgetKind::StaggerQuick,
    WidgetKind::ActiveHost,
    WidgetKind::Hosts,
    WidgetKind::Layer,
    WidgetKind::Battery,
    WidgetKind::Halves,
    WidgetKind::Brightness,
    WidgetKind::LightColor,
    WidgetKind::Today,
    WidgetKind::DailyGoal,
    WidgetKind::Heatmap,
    WidgetKind::Break,
    WidgetKind::QuickActions,
    WidgetKind::CustomButton,
    WidgetKind::Firmware,
];

impl WidgetKind {
    fn code(self) -> &'static str {
        match self {
            Self::Stagger => "stagger",
            Self::StaggerQuick => "stagger_quick",
            Self::ActiveHost => "active_host",
            Self::Hosts => "hosts",
            Self::Layer => "layer",
            Self::Battery => "battery",
            Self::Halves => "halves",
            Self::Brightness => "brightness",
            Self::LightColor => "light_color",
            Self::Today => "today",
            Self::DailyGoal => "daily_goal",
            Self::Heatmap => "heatmap",
            Self::Break => "break",
            Self::QuickActions => "quick_actions",
            Self::CustomButton => "custom_button",
            Self::Firmware => "firmware",
        }
    }

    fn from_code(code: &str) -> Option<Self> {
        KINDS.into_iter().find(|k| k.code() == code)
    }
}

#[uniffi::export]
pub fn widget_info(kind: WidgetKind) -> WidgetInfo {
    use WidgetKind as K;
    use WidgetSize as S;
    let (name, category, summary, sizes): (&str, &str, &str, &[WidgetSize]) = match kind {
        K::Stagger => ("Stagger", "Teclado", "Colunas ao vivo, abrir e fechar e quanto abrir", &[S::ThreeByOne, S::OneByOne, S::TwoByOne, S::OneByTwo, S::TwoByTwo, S::ThreeByTwo]),
        K::StaggerQuick => ("Stagger rápido", "Teclado", "Só o botão de abrir e fechar", &[S::OneByOne, S::TwoByOne, S::ThreeByOne, S::OneByTwo]),
        K::ActiveHost => ("Computador ativo", "Teclado", "Qual computador recebe as teclas; toque para o próximo", &[S::TwoByOne, S::OneByOne, S::ThreeByOne, S::OneByTwo]),
        K::Hosts => ("Computadores", "Teclado", "Os computadores pareados, para trocar", &[S::ThreeByTwo, S::TwoByOne, S::ThreeByOne, S::OneByTwo, S::TwoByTwo]),
        K::Layer => ("Camada ativa", "Teclado", "Camada e perfil em uso", &[S::OneByOne, S::TwoByOne, S::ThreeByOne, S::OneByTwo]),
        K::Battery => ("Bateria", "Energia", "As duas metades, e o e-reader quando encaixado", &[S::OneByOne, S::TwoByOne, S::ThreeByOne, S::OneByTwo, S::TwoByTwo]),
        K::Halves => ("Metades e e-reader", "Energia", "Juntas ou separadas, e-reader encaixado ou solto", &[S::TwoByOne, S::OneByOne, S::ThreeByOne, S::OneByTwo]),
        K::Brightness => ("Brilho e efeito", "Luz", "Intensidade e efeito das luzes", &[S::ThreeByOne, S::TwoByOne, S::OneByTwo, S::TwoByTwo]),
        K::LightColor => ("Cor da luz", "Luz", "Cor do efeito", &[S::TwoByOne, S::OneByOne, S::ThreeByOne, S::OneByTwo, S::TwoByTwo]),
        K::Today => ("Hoje", "Escrita", "Palavras, ritmo e tempo digitando", &[S::ThreeByOne, S::OneByOne, S::TwoByOne, S::OneByTwo, S::TwoByTwo]),
        K::DailyGoal => ("Meta do dia", "Escrita", "Quanto falta para a meta de palavras", &[S::OneByOne, S::TwoByOne, S::ThreeByOne, S::OneByTwo, S::TwoByTwo]),
        K::Heatmap => ("Mapa de calor", "Escrita", "Teclas mais usadas, sem guardar o texto", &[S::ThreeByTwo, S::TwoByOne, S::ThreeByOne, S::TwoByTwo]),
        K::Break => ("Pausa", "Saúde", "Tempo até a próxima pausa", &[S::TwoByOne, S::OneByOne, S::ThreeByOne, S::OneByTwo]),
        K::QuickActions => ("Ações rápidas", "Atalhos", "Abrir o Yggi, apagar a luz, estatísticas", &[S::ThreeByOne, S::TwoByOne, S::OneByTwo, S::TwoByTwo]),
        K::CustomButton => ("Botão personalizado", "Atalhos", "Uma tecla, macro ou camada à sua escolha", &[S::OneByOne, S::TwoByOne, S::ThreeByOne, S::OneByTwo]),
        K::Firmware => ("Firmware", "Sistema", "Versão e atualização", &[S::OneByOne, S::TwoByOne, S::ThreeByOne]),
    };
    WidgetInfo { kind, name: name.into(), category: category.into(), summary: summary.into(), sizes: sizes.to_vec() }
}

/// O maior tamanho que o widget aceita (o da biblioteca). Empate: o mais largo.
#[uniffi::export]
pub fn widget_largest_size(kind: WidgetKind) -> WidgetSize {
    largest(&widget_info(kind).sizes)
}

fn largest(sizes: &[WidgetSize]) -> WidgetSize {
    *sizes.iter().max_by_key(|s| (s.area(), s.columns())).expect("todo widget tem tamanho")
}

/// Todos os widgets, na ordem da biblioteca.
#[uniffi::export]
pub fn widget_catalog() -> Vec<WidgetInfo> {
    KINDS.into_iter().map(widget_info).collect()
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, uniffi::Record)]
pub struct WidgetSlot {
    pub id: u32,
    pub kind: WidgetKind,
    pub size: WidgetSize,
    pub show_title: bool,
    /// Célula do canto de cima à esquerda (coluna 0 a 2, linha a partir de 0).
    pub column: u8,
    pub row: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, uniffi::Record)]
pub struct MenuTab {
    pub id: u32,
    pub name: String,
    /// Cada widget guarda a própria posição; células vazias ficam vazias no popover.
    pub widgets: Vec<WidgetSlot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, uniffi::Record)]
pub struct MenuBarConfig {
    /// Sempre ao menos uma.
    pub tabs: Vec<MenuTab>,
    /// Ao abrir o popover, mostrar a primeira aba (senão, a última usada).
    pub open_first_tab: bool,
    /// Próximo id livre (abas e widgets dividem a numeração).
    pub next_id: u32,
}

/// Uma célula da grade.
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct GridCell {
    pub column: u8,
    pub row: u32,
}

/// Onde um widget fica na grade da aba, em células.
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct WidgetPlacement {
    pub widget_id: u32,
    pub column: u8,
    pub row: u32,
    pub columns: u8,
    pub rows: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct TabGrid {
    pub placements: Vec<WidgetPlacement>,
    /// Altura da grade em linhas (até o fim do widget mais baixo).
    pub rows: u32,
}

/// Onde cada widget está, na ordem de leitura (linha, depois coluna).
#[uniffi::export]
pub fn tab_grid(tab: MenuTab) -> TabGrid {
    let mut widgets = tab.widgets.clone();
    widgets.sort_by_key(|w| (w.row, w.column));
    let placements: Vec<_> = widgets
        .iter()
        .map(|w| WidgetPlacement { widget_id: w.id, column: w.column, row: w.row, columns: w.size.columns(), rows: w.size.rows() })
        .collect();
    let rows = placements.iter().map(|p| p.row + p.rows as u32).max().unwrap_or(0);
    TabGrid { placements, rows }
}

fn overlaps(a: (u8, u32, WidgetSize), b: (u8, u32, WidgetSize)) -> bool {
    let (ac, ar, asz) = a;
    let (bc, br, bsz) = b;
    ac < bc + bsz.columns() && bc < ac + asz.columns() && ar < br + bsz.rows() as u32 && br < ar + asz.rows() as u32
}

fn fits(tab: &MenuTab, size: WidgetSize, column: u8, row: u32, ignoring: Option<u32>) -> bool {
    column + size.columns() <= GRID_COLUMNS
        && tab
            .widgets
            .iter()
            .filter(|w| Some(w.id) != ignoring)
            .all(|w| !overlaps((column, row, size), (w.column, w.row, w.size)))
}

/// O primeiro lugar livre (de cima para baixo, da esquerda para a direita) onde o tamanho cabe.
fn first_free(tab: &MenuTab, size: WidgetSize, ignoring: Option<u32>) -> (u8, u32) {
    (0u32..)
        .find_map(|row| (0..=GRID_COLUMNS - size.columns()).find(|&c| fits(tab, size, c, row, ignoring)).map(|c| (c, row)))
        .expect("sempre há lugar numa linha nova")
}

/// Se um widget desse tamanho cabe na célula (dentro das 3 colunas e sem cobrir outro).
/// `ignoring` é o widget que está sendo arrastado, que não conta como obstáculo.
#[uniffi::export]
pub fn menu_can_place(tab: MenuTab, size: WidgetSize, column: u8, row: u32, ignoring: Option<u32>) -> bool {
    fits(&tab, size, column, row, ignoring)
}

/// O tamanho com que o widget entra na célula: o preferido se couber; senão o maior que ele
/// aceita e que cabe ali (o widget se ajusta ao espaço). `None` se nenhum couber.
#[uniffi::export]
pub fn widget_fit_size(tab: MenuTab, kind: WidgetKind, preferred: WidgetSize, column: u8, row: u32, ignoring: Option<u32>) -> Option<WidgetSize> {
    fit_size(&tab, kind, preferred, column, row, ignoring)
}

fn fit_size(tab: &MenuTab, kind: WidgetKind, preferred: WidgetSize, column: u8, row: u32, ignoring: Option<u32>) -> Option<WidgetSize> {
    let sizes = widget_info(kind).sizes;
    if sizes.contains(&preferred) && fits(tab, preferred, column, row, ignoring) {
        return Some(preferred);
    }
    let mut candidates: Vec<_> = sizes.into_iter().filter(|&s| fits(tab, s, column, row, ignoring)).collect();
    candidates.sort_by_key(|s| std::cmp::Reverse((s.area(), s.columns())));
    candidates.first().copied()
}

/// As quatro abas de fábrica.
#[uniffi::export]
pub fn default_menu_bar() -> MenuBarConfig {
    use WidgetKind as K;
    use WidgetSize as S;
    let mut config = MenuBarConfig { tabs: Vec::new(), open_first_tab: true, next_id: 1 };
    let tabs: [(&str, &[(WidgetKind, WidgetSize)]); 4] = [
        ("Início", &[(K::Stagger, S::ThreeByOne), (K::Battery, S::OneByOne), (K::ActiveHost, S::TwoByOne), (K::Today, S::ThreeByOne)]),
        ("Computadores", &[(K::Hosts, S::ThreeByTwo), (K::Halves, S::TwoByOne), (K::Layer, S::OneByOne)]),
        ("Luz", &[(K::Brightness, S::ThreeByOne), (K::LightColor, S::TwoByOne), (K::StaggerQuick, S::OneByOne)]),
        ("Escrita", &[(K::DailyGoal, S::OneByOne), (K::Break, S::TwoByOne), (K::Heatmap, S::ThreeByTwo)]),
    ];
    for (name, widgets) in tabs {
        let id = take_id(&mut config);
        let mut tab = MenuTab { id, name: name.into(), widgets: Vec::new() };
        for &(kind, size) in widgets {
            let (column, row) = first_free(&tab, size, None);
            let id = take_id(&mut config);
            tab.widgets.push(WidgetSlot { id, kind, size, show_title: true, column, row });
        }
        config.tabs.push(tab);
    }
    config
}

fn take_id(config: &mut MenuBarConfig) -> u32 {
    let id = config.next_id;
    config.next_id += 1;
    id
}

fn clean_name(name: &str) -> String {
    let name: String = name.split_whitespace().collect::<Vec<_>>().join(" ");
    let name: String = name.chars().take(MAX_TAB_NAME).collect();
    if name.is_empty() { "Nova aba".into() } else { name }
}

fn find_widget(config: &MenuBarConfig, widget_id: u32) -> Option<(usize, usize)> {
    config.tabs.iter().enumerate().find_map(|(t, tab)| tab.widgets.iter().position(|w| w.id == widget_id).map(|i| (t, i)))
}

fn tab_index(config: &MenuBarConfig, tab_id: u32) -> Option<usize> {
    config.tabs.iter().position(|t| t.id == tab_id)
}

/// Nova aba vazia no fim. Nada muda se já houver `MAX_TABS`.
#[uniffi::export]
pub fn menu_add_tab(mut config: MenuBarConfig, name: String) -> MenuBarConfig {
    if config.tabs.len() >= MAX_TABS {
        return config;
    }
    let id = take_id(&mut config);
    config.tabs.push(MenuTab { id, name: clean_name(&name), widgets: Vec::new() });
    config
}

/// Remove a aba e os widgets dela. A última aba não pode ser removida.
#[uniffi::export]
pub fn menu_remove_tab(mut config: MenuBarConfig, tab_id: u32) -> MenuBarConfig {
    if config.tabs.len() > 1 {
        if let Some(i) = tab_index(&config, tab_id) {
            config.tabs.remove(i);
        }
    }
    config
}

#[uniffi::export]
pub fn menu_rename_tab(mut config: MenuBarConfig, tab_id: u32, name: String) -> MenuBarConfig {
    if let Some(i) = tab_index(&config, tab_id) {
        config.tabs[i].name = clean_name(&name);
    }
    config
}

/// Leva a aba para a posição `to_index` (limitada ao fim).
#[uniffi::export]
pub fn menu_move_tab(mut config: MenuBarConfig, tab_id: u32, to_index: u32) -> MenuBarConfig {
    if let Some(i) = tab_index(&config, tab_id) {
        let tab = config.tabs.remove(i);
        let to = (to_index as usize).min(config.tabs.len());
        config.tabs.insert(to, tab);
    }
    config
}

/// Adiciona um widget do tipo `kind`. Com `at`, entra na célula no tamanho `size` (ou no maior
/// que couber ali); sem `at`, ou se nada couber, vai no tamanho padrão para o primeiro lugar livre.
#[uniffi::export]
pub fn menu_add_widget(mut config: MenuBarConfig, tab_id: u32, kind: WidgetKind, at: Option<GridCell>, size: Option<WidgetSize>) -> MenuBarConfig {
    let Some(t) = tab_index(&config, tab_id) else { return config };
    let info = widget_info(kind);
    let tab = &config.tabs[t];
    let wanted = size.filter(|s| info.sizes.contains(s)).unwrap_or(info.sizes[0]);
    let placed = at.and_then(|cell| fit_size(tab, kind, wanted, cell.column, cell.row, None).map(|s| (s, cell.column, cell.row)));
    let (size, column, row) = placed.unwrap_or_else(|| {
        let (c, r) = first_free(tab, info.sizes[0], None);
        (info.sizes[0], c, r)
    });
    let id = take_id(&mut config);
    config.tabs[t].widgets.push(WidgetSlot { id, kind, size, show_title: true, column, row });
    config
}

#[uniffi::export]
pub fn menu_remove_widget(mut config: MenuBarConfig, widget_id: u32) -> MenuBarConfig {
    if let Some((t, i)) = find_widget(&config, widget_id) {
        config.tabs[t].widgets.remove(i);
    }
    config
}

/// Arrastar: põe o widget na célula da aba `to_tab_id`, no tamanho dele se couber; senão no
/// maior tamanho que ele aceita e que cabe ali. Se nenhum couber, nada muda.
#[uniffi::export]
pub fn menu_place_widget(mut config: MenuBarConfig, widget_id: u32, to_tab_id: u32, column: u8, row: u32) -> MenuBarConfig {
    let (Some((t, i)), Some(to_t)) = (find_widget(&config, widget_id), tab_index(&config, to_tab_id)) else { return config };
    let current = config.tabs[t].widgets[i];
    let Some(size) = fit_size(&config.tabs[to_t], current.kind, current.size, column, row, Some(widget_id)) else { return config };
    let mut slot = config.tabs[t].widgets.remove(i);
    (slot.column, slot.row, slot.size) = (column, row, size);
    config.tabs[to_t].widgets.push(slot);
    config
}

/// Leva o widget para outra aba, no primeiro lugar livre dela.
#[uniffi::export]
pub fn menu_move_widget_to_tab(mut config: MenuBarConfig, widget_id: u32, to_tab_id: u32) -> MenuBarConfig {
    let (Some((t, i)), Some(to_t)) = (find_widget(&config, widget_id), tab_index(&config, to_tab_id)) else { return config };
    if t == to_t {
        return config;
    }
    let mut slot = config.tabs[t].widgets.remove(i);
    (slot.column, slot.row) = first_free(&config.tabs[to_t], slot.size, None);
    config.tabs[to_t].widgets.push(slot);
    config
}

/// Muda o tamanho, se o widget aceitar esse tamanho. Fica no mesmo lugar se couber (encostando
/// na direita se passar da 3ª coluna); senão, vai para o primeiro lugar livre.
#[uniffi::export]
pub fn menu_set_widget_size(mut config: MenuBarConfig, widget_id: u32, size: WidgetSize) -> MenuBarConfig {
    let Some((t, i)) = find_widget(&config, widget_id) else { return config };
    let slot = config.tabs[t].widgets[i];
    if !widget_info(slot.kind).sizes.contains(&size) {
        return config;
    }
    let tab = &config.tabs[t];
    let column = slot.column.min(GRID_COLUMNS - size.columns());
    let (column, row) =
        if fits(tab, size, column, slot.row, Some(widget_id)) { (column, slot.row) } else { first_free(tab, size, Some(widget_id)) };
    let slot = &mut config.tabs[t].widgets[i];
    (slot.size, slot.column, slot.row) = (size, column, row);
    config
}

/// Redimensionar arrastando a borda: o canto de cima à esquerda fica parado e o widget vai
/// para o tamanho que ele aceita mais perto de `columns` × `rows`, sem cobrir outro widget.
/// Se nenhum tamanho couber ali, nada muda.
#[uniffi::export]
pub fn menu_resize_widget(mut config: MenuBarConfig, widget_id: u32, columns: u8, rows: u8) -> MenuBarConfig {
    let Some((t, i)) = find_widget(&config, widget_id) else { return config };
    let slot = config.tabs[t].widgets[i];
    let tab = &config.tabs[t];
    let distance = |s: &WidgetSize| (s.columns() as i32 - columns as i32).abs() + (s.rows() as i32 - rows as i32).abs();
    let best = widget_info(slot.kind)
        .sizes
        .into_iter()
        .filter(|&s| fits(tab, s, slot.column, slot.row, Some(widget_id)))
        // Mais perto do pedido; no empate, o que mais muda na direção puxada (o maior).
        .min_by_key(|s| (distance(s), std::cmp::Reverse(s.area())));
    if let Some(size) = best {
        config.tabs[t].widgets[i].size = size;
    }
    config
}

#[uniffi::export]
pub fn menu_set_widget_title(mut config: MenuBarConfig, widget_id: u32, show: bool) -> MenuBarConfig {
    if let Some((t, i)) = find_widget(&config, widget_id) {
        config.tabs[t].widgets[i].show_title = show;
    }
    config
}

/// Tira os buracos da aba: cada widget, na ordem de leitura, sobe para o primeiro lugar livre.
#[uniffi::export]
pub fn menu_compact_tab(mut config: MenuBarConfig, tab_id: u32) -> MenuBarConfig {
    let Some(t) = tab_index(&config, tab_id) else { return config };
    let mut widgets = std::mem::take(&mut config.tabs[t].widgets);
    widgets.sort_by_key(|w| (w.row, w.column));
    for mut w in widgets {
        (w.column, w.row) = first_free(&config.tabs[t], w.size, None);
        config.tabs[t].widgets.push(w);
    }
    config
}

/// Texto para guardar a configuração (no Mac hoje; no teclado quando houver firmware).
#[uniffi::export]
pub fn menu_bar_encode(config: MenuBarConfig) -> String {
    let mut out = format!("{HEADER}\nopen_first_tab {}\n", u8::from(config.open_first_tab));
    for tab in &config.tabs {
        out += &format!("tab {} {}\n", tab.id, escape(&tab.name));
        for w in &tab.widgets {
            out += &format!("widget {} {} {} {} {} {}\n", w.id, w.kind.code(), w.size.code(), u8::from(w.show_title), w.column, w.row);
        }
    }
    out
}

/// Lê o texto de `menu_bar_encode` (e o da versão 1, sem posições). `None` se não for uma
/// configuração válida. Widgets de tipos desconhecidos (de uma versão mais nova) são ignorados,
/// um tamanho que o widget não aceita volta ao padrão, e posição ausente ou ocupada vira o
/// primeiro lugar livre.
#[uniffi::export]
pub fn menu_bar_decode(text: String) -> Option<MenuBarConfig> {
    let mut lines = text.lines();
    let header = lines.next()?;
    if header != HEADER && header != HEADER_V1 {
        return None;
    }
    let mut config = MenuBarConfig { tabs: Vec::new(), open_first_tab: true, next_id: 1 };
    let mut max_id = 0u32;
    for line in lines {
        let mut parts = line.splitn(2, ' ');
        let key = parts.next()?;
        let rest = parts.next().unwrap_or("");
        match key {
            "open_first_tab" => config.open_first_tab = rest == "1",
            "tab" => {
                let mut p = rest.splitn(2, ' ');
                let id: u32 = p.next()?.parse().ok()?;
                let name = unescape(p.next().unwrap_or(""));
                max_id = max_id.max(id);
                if config.tabs.len() < MAX_TABS {
                    config.tabs.push(MenuTab { id, name: clean_name(&name), widgets: Vec::new() });
                }
            }
            "widget" => {
                let f: Vec<&str> = rest.split(' ').collect();
                if f.len() != 4 && f.len() != 6 {
                    return None;
                }
                let id: u32 = f[0].parse().ok()?;
                max_id = max_id.max(id);
                let Some(kind) = WidgetKind::from_code(f[1]) else { continue };
                let info = widget_info(kind);
                let size = WidgetSize::from_code(f[2]).filter(|s| info.sizes.contains(s)).unwrap_or(info.sizes[0]);
                let tab = config.tabs.last_mut()?;
                let wanted = if f.len() == 6 { f[4].parse::<u8>().ok().zip(f[5].parse::<u32>().ok()) } else { None };
                let (column, row) = match wanted {
                    Some((c, r)) if c < GRID_COLUMNS && fits(tab, size, c, r, None) => (c, r),
                    _ => first_free(tab, size, None),
                };
                tab.widgets.push(WidgetSlot { id, kind, size, show_title: f[3] == "1", column, row });
            }
            "" => {}
            _ => continue,
        }
    }
    if config.tabs.is_empty() {
        return None;
    }
    config.next_id = max_id + 1;
    Some(config)
}

fn escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('\n', "\\n")
}

fn unescape(s: &str) -> String {
    let mut out = String::new();
    let mut chars = s.chars();
    while let Some(c) = chars.next() {
        if c == '\\' {
            match chars.next() {
                Some('n') => out.push('\n'),
                Some(other) => out.push(other),
                None => {}
            }
        } else {
            out.push(c);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use WidgetSize as S;

    fn slot(id: u32, size: WidgetSize, column: u8, row: u32) -> WidgetSlot {
        WidgetSlot { id, kind: WidgetKind::Battery, size, show_title: true, column, row }
    }

    fn tab_of(widgets: Vec<WidgetSlot>) -> MenuTab {
        MenuTab { id: 99, name: "t".into(), widgets }
    }

    fn pos(c: &MenuBarConfig, id: u32) -> (u8, u32) {
        let (t, i) = find_widget(c, id).unwrap();
        let w = c.tabs[t].widgets[i];
        (w.column, w.row)
    }

    #[test]
    fn tamanhos_tem_colunas_e_linhas_certas() {
        let dims: Vec<_> = WidgetSize::ALL.iter().map(|s| (s.columns(), s.rows())).collect();
        assert_eq!(dims, vec![(1, 1), (2, 1), (3, 1), (1, 2), (2, 2), (3, 2)]);
    }

    #[test]
    fn grade_respeita_as_posicoes_e_deixa_buracos() {
        let grid = tab_grid(tab_of(vec![slot(1, S::OneByOne, 2, 3), slot(2, S::TwoByOne, 0, 0)]));
        assert_eq!(grid.placements.iter().map(|p| p.widget_id).collect::<Vec<_>>(), vec![2, 1], "ordem de leitura");
        assert_eq!(grid.rows, 4, "linhas vazias no meio continuam");
        assert_eq!(tab_grid(tab_of(vec![])).rows, 0);
    }

    #[test]
    fn cabe_so_dentro_das_colunas_e_sem_cobrir_outro() {
        let tab = tab_of(vec![slot(1, S::TwoByTwo, 0, 0)]);
        assert!(menu_can_place(tab.clone(), S::OneByOne, 2, 0, None));
        assert!(!menu_can_place(tab.clone(), S::OneByOne, 1, 1, None), "dentro do 2x2");
        assert!(!menu_can_place(tab.clone(), S::TwoByOne, 2, 5, None), "passa da 3ª coluna");
        assert!(menu_can_place(tab.clone(), S::ThreeByOne, 0, 2, None));
        assert!(menu_can_place(tab, S::TwoByTwo, 0, 1, Some(1)), "o próprio widget não atrapalha");
    }

    #[test]
    fn padrao_tem_quatro_abas_ids_unicos_e_nada_se_cobre() {
        let c = default_menu_bar();
        assert_eq!(c.tabs.iter().map(|t| t.name.as_str()).collect::<Vec<_>>(), ["Início", "Computadores", "Luz", "Escrita"]);
        let mut ids: Vec<u32> = c.tabs.iter().flat_map(|t| std::iter::once(t.id).chain(t.widgets.iter().map(|w| w.id))).collect();
        let n = ids.len();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), n);
        assert!(ids.iter().all(|&id| id < c.next_id));
        for tab in &c.tabs {
            for w in &tab.widgets {
                assert!(fits(tab, w.size, w.column, w.row, Some(w.id)), "{:?} cobre outro", w.kind);
            }
        }
        // Início: stagger 3x1 em cima, bateria e computador ativo lado a lado, hoje embaixo.
        assert_eq!(c.tabs[0].widgets.iter().map(|w| (w.column, w.row)).collect::<Vec<_>>(), vec![(0, 0), (0, 1), (1, 1), (0, 2)]);
    }

    #[test]
    fn catalogo_esta_completo_e_sem_tamanho_repetido() {
        let catalog = widget_catalog();
        assert_eq!(catalog.len(), KINDS.len());
        for info in catalog {
            let mut sizes = info.sizes.clone();
            sizes.dedup();
            assert_eq!(sizes.len(), info.sizes.len(), "{} repete tamanho", info.name);
        }
    }

    #[test]
    fn arrastar_poe_na_celula_se_couber() {
        let c = default_menu_bar();
        let inicio = c.tabs[0].id;
        let bateria = c.tabs[0].widgets[1].id;
        // Linha 5, deixando buraco: pode.
        let c = menu_place_widget(c, bateria, inicio, 2, 5);
        assert_eq!(pos(&c, bateria), (2, 5));
        // Em cima do stagger: não pode, fica onde estava.
        let c = menu_place_widget(c, bateria, inicio, 1, 0);
        assert_eq!(pos(&c, bateria), (2, 5), "nenhum tamanho da bateria cabe dentro do stagger");
        // Para outra aba, numa célula livre.
        let luz = c.tabs[2].id;
        let c = menu_place_widget(c, bateria, luz, 0, 3);
        assert_eq!(pos(&c, bateria), (0, 3));
        assert_eq!(c.tabs[0].widgets.len(), 3);
        assert_eq!(c.tabs[2].widgets.len(), 4);
    }

    #[test]
    fn mudar_de_aba_vai_para_o_primeiro_lugar_livre() {
        let c = default_menu_bar();
        let bateria = c.tabs[0].widgets[1].id;
        let luz = c.tabs[2].id;
        let c = menu_move_widget_to_tab(c, bateria, luz);
        // Luz: brilho 3x1 na linha 0, cor 2x1 e stagger rápido 1x1 na linha 1.
        assert_eq!(pos(&c, bateria), (0, 2));
    }

    #[test]
    fn tamanho_novo_fica_no_lugar_ou_procura_outro() {
        let c = default_menu_bar();
        let stagger = c.tabs[0].widgets[0];
        let bateria = c.tabs[0].widgets[1].id;
        let c = menu_set_widget_size(c, bateria, S::ThreeByTwo);
        assert_eq!(c.tabs[0].widgets[1].size, S::OneByOne, "tamanho que o widget não aceita");
        // 2x2 no lugar do 3x1 cobriria a bateria (linha 1): vai para o primeiro lugar livre.
        let c = menu_set_widget_size(c, stagger.id, S::TwoByTwo);
        assert_eq!(c.tabs[0].widgets[0].size, S::TwoByTwo);
        let (t, i) = find_widget(&c, stagger.id).unwrap();
        let w = c.tabs[t].widgets[i];
        assert!(fits(&c.tabs[t], w.size, w.column, w.row, Some(w.id)));
        // Bateria 1x1 na coluna 2 virando 3x1: encosta na esquerda da linha se couber.
        let tab = c.tabs[0].id;
        let bat = c.tabs[0].widgets[1].id;
        let c = menu_place_widget(c, bat, tab, 2, 7);
        let c = menu_set_widget_size(c, bat, S::ThreeByOne);
        assert_eq!(pos(&c, bat), (0, 7));
    }

    #[test]
    fn adicionar_na_celula_ou_no_primeiro_livre() {
        let c = default_menu_bar();
        let tab = c.tabs[1].id;
        let c = menu_add_widget(c, tab, WidgetKind::Firmware, Some(GridCell { column: 2, row: 6 }), None);
        assert_eq!(c.tabs[1].widgets.last().map(|w| (w.column, w.row)), Some((2, 6)));
        // Célula ocupada: primeiro lugar livre.
        let c = menu_add_widget(c, tab, WidgetKind::Firmware, Some(GridCell { column: 0, row: 0 }), None);
        let w = *c.tabs[1].widgets.last().unwrap();
        assert!(fits(&c.tabs[1], w.size, w.column, w.row, Some(w.id)));
        assert_ne!((w.column, w.row), (0, 0));
    }

    #[test]
    fn todo_widget_tem_2x1_ou_3x1_e_quase_todos_ficam_em_pe() {
        for info in widget_catalog() {
            assert!(info.sizes.contains(&S::TwoByOne) || info.sizes.contains(&S::ThreeByOne), "{} deitado", info.name);
        }
        let em_pe = widget_catalog().iter().filter(|i| i.sizes.contains(&S::OneByTwo)).count();
        assert!(em_pe >= 13, "{em_pe}");
        assert_eq!(widget_largest_size(WidgetKind::Stagger), S::ThreeByTwo);
        assert_eq!(widget_largest_size(WidgetKind::Firmware), S::ThreeByOne);
    }

    #[test]
    fn soltar_ajusta_o_tamanho_ao_espaco() {
        // Uma linha com um 1x1 na coluna 2: sobram 2 colunas em cima e a linha de baixo livre.
        let tab = tab_of(vec![slot(1, S::OneByOne, 2, 0)]);
        // Preferido 3x2 não cabe; o maior que cabe na coluna 0 é 2x2.
        assert_eq!(widget_fit_size(tab.clone(), WidgetKind::Stagger, S::ThreeByTwo, 0, 0, None), Some(S::TwoByTwo));
        // Preferido cabe: fica ele.
        assert_eq!(widget_fit_size(tab.clone(), WidgetKind::Stagger, S::TwoByOne, 0, 0, None), Some(S::TwoByOne));
        // Em cima do 1x1: nada cabe.
        assert_eq!(widget_fit_size(tab, WidgetKind::Stagger, S::OneByOne, 2, 0, None), None);

        // Arrastar o stagger 3x1 para a linha da bateria (coluna 1): encolhe para caber.
        let c = default_menu_bar();
        let inicio = c.tabs[0].id;
        let stagger = c.tabs[0].widgets[0].id;
        let hoje = c.tabs[0].widgets[3].id;
        let c = menu_remove_widget(c, hoje);
        let c = menu_place_widget(c, stagger, inicio, 1, 2);
        let (t, i) = find_widget(&c, stagger).unwrap();
        assert_eq!((c.tabs[t].widgets[i].column, c.tabs[t].widgets[i].row, c.tabs[t].widgets[i].size), (1, 2, S::TwoByTwo));
    }

    #[test]
    fn da_biblioteca_entra_no_maior_que_cabe() {
        let c = default_menu_bar();
        let tab = c.tabs[0].id;
        let c = menu_add_widget(c, tab, WidgetKind::Heatmap, Some(GridCell { column: 0, row: 3 }), Some(S::ThreeByTwo));
        assert_eq!(c.tabs[0].widgets.last().map(|w| (w.size, w.column, w.row)), Some((S::ThreeByTwo, 0, 3)));
        // Na coluna 1 não cabe 3 de largura: vira 2x2.
        let c = menu_add_widget(c, tab, WidgetKind::Heatmap, Some(GridCell { column: 1, row: 5 }), Some(S::ThreeByTwo));
        assert_eq!(c.tabs[0].widgets.last().map(|w| (w.size, w.column, w.row)), Some((S::TwoByTwo, 1, 5)));
    }

    #[test]
    fn puxar_a_borda_vai_para_o_tamanho_mais_perto_que_cabe() {
        // Stagger sozinho numa aba: aceita todos os tamanhos.
        let mut c = default_menu_bar();
        let tab = c.tabs[0].id;
        c.tabs[0].widgets.retain(|w| w.kind == WidgetKind::Stagger);
        let id = c.tabs[0].widgets[0].id;
        let size = |c: &MenuBarConfig| c.tabs[0].widgets[0].size;
        let c = menu_resize_widget(c, id, 2, 1);
        assert_eq!(size(&c), S::TwoByOne);
        let c = menu_resize_widget(c, id, 2, 2);
        assert_eq!(size(&c), S::TwoByTwo);
        let c = menu_resize_widget(c, id, 9, 9);
        assert_eq!(size(&c), S::ThreeByTwo, "limitado ao máximo do widget");
        let c = menu_resize_widget(c, id, 1, 2);
        assert_eq!(size(&c), S::OneByTwo);
        // Firmware não fica em pé nem cresce além de 3x1.
        let c = menu_add_widget(c, tab, WidgetKind::Firmware, Some(GridCell { column: 0, row: 4 }), Some(S::OneByOne));
        let fw = c.tabs[0].widgets.last().unwrap().id;
        let c = menu_resize_widget(c, fw, 3, 2);
        assert_eq!(c.tabs[0].widgets.last().unwrap().size, S::ThreeByOne);
        // Um vizinho na frente limita: com um 1x1 na coluna 2, não passa de 2 colunas.
        let c = menu_add_widget(c, tab, WidgetKind::Layer, Some(GridCell { column: 2, row: 6 }), Some(S::OneByOne));
        let c = menu_add_widget(c, tab, WidgetKind::Break, Some(GridCell { column: 0, row: 6 }), Some(S::OneByOne));
        let pausa = c.tabs[0].widgets.last().unwrap().id;
        let c = menu_resize_widget(c, pausa, 3, 1);
        assert_eq!(c.tabs[0].widgets.last().unwrap().size, S::TwoByOne);
    }

    #[test]
    fn compactar_tira_os_buracos() {
        let c = default_menu_bar();
        let tab = c.tabs[0].id;
        let hoje = c.tabs[0].widgets[3].id;
        let c = menu_place_widget(c, hoje, tab, 0, 6);
        let c = menu_compact_tab(c, tab);
        assert_eq!(pos(&c, hoje), (0, 2));
        assert_eq!(tab_grid(c.tabs[0].clone()).rows, 3);
    }

    #[test]
    fn abas_tem_limites() {
        let mut c = default_menu_bar();
        for _ in 0..10 {
            c = menu_add_tab(c, "  muito   espaço  ".into());
        }
        assert_eq!(c.tabs.len(), MAX_TABS);
        assert_eq!(c.tabs[4].name, "muito espaço");
        let first = c.tabs[0].id;
        let mut c = menu_rename_tab(c, first, "".into());
        assert_eq!(c.tabs[0].name, "Nova aba");
        while c.tabs.len() > 1 {
            let id = c.tabs[0].id;
            c = menu_remove_tab(c, id);
        }
        let last = c.tabs[0].id;
        assert_eq!(menu_remove_tab(c, last).tabs.len(), 1);
    }

    #[test]
    fn guardar_e_ler_devolve_a_mesma_configuracao() {
        let c = default_menu_bar();
        let tab = c.tabs[0].id;
        let bat = c.tabs[0].widgets[1].id;
        let c = menu_place_widget(c, bat, tab, 2, 4);
        let c = menu_rename_tab(c, tab, "Meu \\ início\nnovo".into());
        let mut c = menu_move_tab(c, tab, 3);
        c.open_first_tab = false;
        let back = menu_bar_decode(menu_bar_encode(c.clone())).expect("lê o que gravou");
        assert_eq!(back, c);
    }

    #[test]
    fn le_a_versao_1_encaixando_e_tolera_widget_novo() {
        let text = format!("{HEADER_V1}\nopen_first_tab 1\ntab 1 A\nwidget 2 widget_do_futuro 1x1 1\nwidget 3 firmware 2x2 1\nwidget 4 battery 1x1 1\n");
        let c = menu_bar_decode(text).unwrap();
        let w = &c.tabs[0].widgets;
        assert_eq!(w.len(), 2);
        assert_eq!((w[0].size, w[0].column, w[0].row), (S::OneByOne, 0, 0), "2x2 não é do firmware: volta ao padrão");
        assert_eq!((w[1].column, w[1].row), (1, 0));
        assert_eq!(c.next_id, 5);
        assert!(menu_bar_decode("outra coisa".into()).is_none());
        assert!(menu_bar_decode(format!("{HEADER}\n")).is_none());
    }

    #[test]
    fn leitura_resolve_posicao_ocupada() {
        let text = format!("{HEADER}\nopen_first_tab 1\ntab 1 A\nwidget 2 battery 1x1 1 0 0\nwidget 3 battery 1x1 1 0 0\n");
        let c = menu_bar_decode(text).unwrap();
        assert_eq!(c.tabs[0].widgets.iter().map(|w| (w.column, w.row)).collect::<Vec<_>>(), vec![(0, 0), (1, 0)]);
    }
}
