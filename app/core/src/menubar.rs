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

const HEADER: &str = "yggi-menubar 1";

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
    TwoByTwo,
    ThreeByTwo,
}

impl WidgetSize {
    pub const ALL: [WidgetSize; 5] = [Self::OneByOne, Self::TwoByOne, Self::ThreeByOne, Self::TwoByTwo, Self::ThreeByTwo];

    pub fn columns(self) -> u8 {
        match self {
            Self::OneByOne => 1,
            Self::TwoByOne | Self::TwoByTwo => 2,
            Self::ThreeByOne | Self::ThreeByTwo => 3,
        }
    }

    pub fn rows(self) -> u8 {
        match self {
            Self::OneByOne | Self::TwoByOne | Self::ThreeByOne => 1,
            Self::TwoByTwo | Self::ThreeByTwo => 2,
        }
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
        K::Stagger => ("Stagger", "Teclado", "Colunas ao vivo, abrir e fechar, posições salvas", &[S::ThreeByOne, S::TwoByOne, S::TwoByTwo, S::ThreeByTwo]),
        K::StaggerQuick => ("Stagger rápido", "Teclado", "Só o botão de abrir e fechar", &[S::OneByOne, S::TwoByOne]),
        K::ActiveHost => ("Computador ativo", "Teclado", "Qual computador recebe as teclas; toque para o próximo", &[S::OneByOne, S::TwoByOne]),
        K::Hosts => ("Computadores", "Teclado", "Os computadores pareados, para trocar", &[S::ThreeByTwo, S::TwoByTwo]),
        K::Layer => ("Camada ativa", "Teclado", "Camada e perfil em uso", &[S::OneByOne, S::TwoByOne]),
        K::Battery => ("Bateria", "Energia", "As duas metades, e o e-reader quando encaixado", &[S::OneByOne, S::TwoByOne, S::ThreeByOne]),
        K::Halves => ("Metades e e-reader", "Energia", "Juntas ou separadas, e-reader encaixado ou solto", &[S::OneByOne, S::TwoByOne]),
        K::Brightness => ("Brilho e efeito", "Luz", "Intensidade e efeito das luzes", &[S::ThreeByOne, S::TwoByOne]),
        K::LightColor => ("Cor da luz", "Luz", "Cor do efeito", &[S::TwoByOne, S::OneByOne, S::ThreeByOne]),
        K::Today => ("Hoje", "Escrita", "Palavras, ritmo e tempo digitando", &[S::ThreeByOne, S::TwoByOne, S::TwoByTwo]),
        K::DailyGoal => ("Meta do dia", "Escrita", "Quanto falta para a meta de palavras", &[S::OneByOne, S::TwoByTwo]),
        K::Heatmap => ("Mapa de calor", "Escrita", "Teclas mais usadas, sem guardar o texto", &[S::ThreeByOne, S::ThreeByTwo]),
        K::Break => ("Pausa", "Saúde", "Tempo até a próxima pausa", &[S::OneByOne, S::TwoByOne]),
        K::QuickActions => ("Ações rápidas", "Atalhos", "Captura, Mission Control, ajustes do teclado", &[S::ThreeByOne, S::TwoByOne]),
        K::CustomButton => ("Botão personalizado", "Atalhos", "Uma tecla, macro ou camada à sua escolha", &[S::OneByOne]),
        K::Firmware => ("Firmware", "Sistema", "Versão e atualização", &[S::OneByOne, S::TwoByOne]),
    };
    WidgetInfo { kind, name: name.into(), category: category.into(), summary: summary.into(), sizes: sizes.to_vec() }
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
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, uniffi::Record)]
pub struct MenuTab {
    pub id: u32,
    pub name: String,
    /// Na ordem em que entram na grade.
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
    /// Altura da grade em linhas.
    pub rows: u32,
}

/// Encaixa os widgets na grade de 3 colunas, na ordem da aba: cada um vai para o primeiro
/// lugar livre (de cima para baixo, da esquerda para a direita) onde cabe inteiro.
/// Assim um widget pequeno depois de um grande preenche o buraco ao lado dele.
#[uniffi::export]
pub fn tab_grid(tab: MenuTab) -> TabGrid {
    let cols = GRID_COLUMNS as usize;
    let mut used: Vec<[bool; GRID_COLUMNS as usize]> = Vec::new();
    let mut placements = Vec::with_capacity(tab.widgets.len());
    for w in &tab.widgets {
        let (wc, wr) = (w.size.columns() as usize, w.size.rows() as usize);
        let mut row = 0usize;
        let (r, c) = 'search: loop {
            while used.len() < row + wr {
                used.push([false; GRID_COLUMNS as usize]);
            }
            for c in 0..=(cols - wc) {
                if (row..row + wr).all(|r| (c..c + wc).all(|cc| !used[r][cc])) {
                    break 'search (row, c);
                }
            }
            row += 1;
        };
        for rr in r..r + wr {
            for cc in c..c + wc {
                used[rr][cc] = true;
            }
        }
        placements.push(WidgetPlacement { widget_id: w.id, column: c as u8, row: r as u32, columns: wc as u8, rows: wr as u8 });
    }
    let rows = placements.iter().map(|p| p.row + p.rows as u32).max().unwrap_or(0);
    TabGrid { placements, rows }
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
        let widgets = widgets
            .iter()
            .map(|&(kind, size)| WidgetSlot { id: take_id(&mut config), kind, size, show_title: true })
            .collect();
        config.tabs.push(MenuTab { id, name: name.into(), widgets });
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

/// Adiciona um widget do tipo `kind`, no tamanho padrão dele, na posição `at_index`
/// da aba (ou no fim).
#[uniffi::export]
pub fn menu_add_widget(mut config: MenuBarConfig, tab_id: u32, kind: WidgetKind, at_index: Option<u32>) -> MenuBarConfig {
    let Some(t) = tab_index(&config, tab_id) else { return config };
    let id = take_id(&mut config);
    let slot = WidgetSlot { id, kind, size: widget_info(kind).sizes[0], show_title: true };
    let widgets = &mut config.tabs[t].widgets;
    let at = at_index.map_or(widgets.len(), |i| (i as usize).min(widgets.len()));
    widgets.insert(at, slot);
    config
}

#[uniffi::export]
pub fn menu_remove_widget(mut config: MenuBarConfig, widget_id: u32) -> MenuBarConfig {
    if let Some((t, i)) = find_widget(&config, widget_id) {
        config.tabs[t].widgets.remove(i);
    }
    config
}

/// Arrastar: leva o widget para a aba `to_tab_id`, na posição `to_index` (limitada ao fim).
/// Serve para reordenar dentro da mesma aba e para mudar de aba.
#[uniffi::export]
pub fn menu_move_widget(mut config: MenuBarConfig, widget_id: u32, to_tab_id: u32, to_index: u32) -> MenuBarConfig {
    let (Some((t, i)), Some(to_t)) = (find_widget(&config, widget_id), tab_index(&config, to_tab_id)) else { return config };
    let slot = config.tabs[t].widgets.remove(i);
    let widgets = &mut config.tabs[to_t].widgets;
    let to = (to_index as usize).min(widgets.len());
    widgets.insert(to, slot);
    config
}

/// Muda o tamanho, se o widget aceitar esse tamanho.
#[uniffi::export]
pub fn menu_set_widget_size(mut config: MenuBarConfig, widget_id: u32, size: WidgetSize) -> MenuBarConfig {
    if let Some((t, i)) = find_widget(&config, widget_id) {
        let slot = &mut config.tabs[t].widgets[i];
        if widget_info(slot.kind).sizes.contains(&size) {
            slot.size = size;
        }
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

/// Texto para guardar a configuração (no Mac hoje; no teclado quando houver firmware).
#[uniffi::export]
pub fn menu_bar_encode(config: MenuBarConfig) -> String {
    let mut out = format!("{HEADER}\nopen_first_tab {}\n", u8::from(config.open_first_tab));
    for tab in &config.tabs {
        out += &format!("tab {} {}\n", tab.id, escape(&tab.name));
        for w in &tab.widgets {
            out += &format!("widget {} {} {} {}\n", w.id, w.kind.code(), w.size.code(), u8::from(w.show_title));
        }
    }
    out
}

/// Lê o texto de `menu_bar_encode`. `None` se não for uma configuração válida.
/// Widgets de tipos desconhecidos (de uma versão mais nova) são ignorados, e um tamanho
/// que o widget não aceita volta ao padrão dele.
#[uniffi::export]
pub fn menu_bar_decode(text: String) -> Option<MenuBarConfig> {
    let mut lines = text.lines();
    if lines.next()? != HEADER {
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
                if f.len() != 4 {
                    return None;
                }
                let id: u32 = f[0].parse().ok()?;
                max_id = max_id.max(id);
                let Some(kind) = WidgetKind::from_code(f[1]) else { continue };
                let info = widget_info(kind);
                let size = WidgetSize::from_code(f[2]).filter(|s| info.sizes.contains(s)).unwrap_or(info.sizes[0]);
                let tab = config.tabs.last_mut()?;
                tab.widgets.push(WidgetSlot { id, kind, size, show_title: f[3] == "1" });
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

    fn tab_with(sizes: &[WidgetSize]) -> MenuTab {
        let widgets = sizes.iter().enumerate().map(|(i, &size)| WidgetSlot { id: i as u32, kind: WidgetKind::Battery, size, show_title: true }).collect();
        MenuTab { id: 99, name: "t".into(), widgets }
    }

    fn cells(grid: &TabGrid) -> Vec<(u8, u32)> {
        grid.placements.iter().map(|p| (p.column, p.row)).collect()
    }

    #[test]
    fn tamanhos_tem_colunas_e_linhas_certas() {
        let dims: Vec<_> = WidgetSize::ALL.iter().map(|s| (s.columns(), s.rows())).collect();
        assert_eq!(dims, vec![(1, 1), (2, 1), (3, 1), (2, 2), (3, 2)]);
    }

    #[test]
    fn grade_enche_linha_por_linha() {
        use WidgetSize as S;
        let grid = tab_grid(tab_with(&[S::ThreeByOne, S::OneByOne, S::TwoByOne, S::OneByOne]));
        assert_eq!(cells(&grid), vec![(0, 0), (0, 1), (1, 1), (0, 2)]);
        assert_eq!(grid.rows, 3);
    }

    #[test]
    fn pequeno_preenche_o_buraco_ao_lado_do_2x2() {
        use WidgetSize as S;
        let grid = tab_grid(tab_with(&[S::TwoByTwo, S::OneByOne, S::OneByOne, S::ThreeByOne]));
        assert_eq!(cells(&grid), vec![(0, 0), (2, 0), (2, 1), (0, 2)]);
        assert_eq!(grid.rows, 3);
    }

    #[test]
    fn largo_desce_quando_nao_cabe() {
        use WidgetSize as S;
        let grid = tab_grid(tab_with(&[S::OneByOne, S::ThreeByTwo]));
        assert_eq!(cells(&grid), vec![(0, 0), (0, 1)]);
        assert_eq!(grid.rows, 3);
    }

    #[test]
    fn aba_vazia_tem_zero_linhas() {
        assert_eq!(tab_grid(tab_with(&[])).rows, 0);
    }

    #[test]
    fn padrao_tem_quatro_abas_e_ids_unicos() {
        let c = default_menu_bar();
        assert_eq!(c.tabs.iter().map(|t| t.name.as_str()).collect::<Vec<_>>(), ["Início", "Computadores", "Luz", "Escrita"]);
        let mut ids: Vec<u32> = c.tabs.iter().flat_map(|t| std::iter::once(t.id).chain(t.widgets.iter().map(|w| w.id))).collect();
        let n = ids.len();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), n);
        assert!(ids.iter().all(|&id| id < c.next_id));
    }

    #[test]
    fn todo_widget_aceita_o_proprio_tamanho_padrao_e_o_catalogo_esta_completo() {
        let catalog = widget_catalog();
        assert_eq!(catalog.len(), KINDS.len());
        for info in catalog {
            assert!(!info.sizes.is_empty());
            let mut sizes = info.sizes.clone();
            sizes.dedup();
            assert_eq!(sizes.len(), info.sizes.len(), "{} repete tamanho", info.name);
        }
    }

    #[test]
    fn arrastar_reordena_e_muda_de_aba() {
        let c = default_menu_bar();
        let inicio = c.tabs[0].id;
        let luz = c.tabs[2].id;
        let last = c.tabs[0].widgets[3].id;
        let c = menu_move_widget(c, last, inicio, 0);
        assert_eq!(c.tabs[0].widgets[0].id, last);
        let c = menu_move_widget(c, last, luz, 1);
        assert_eq!(c.tabs[0].widgets.len(), 3);
        assert_eq!(c.tabs[2].widgets[1].id, last);
        let c = menu_move_widget(c, last, luz, 999);
        assert_eq!(c.tabs[2].widgets.last().unwrap().id, last);
    }

    #[test]
    fn tamanho_nao_aceito_e_ignorado() {
        let c = default_menu_bar();
        let stagger = c.tabs[0].widgets[0];
        assert_eq!(stagger.kind, WidgetKind::Stagger);
        let c = menu_set_widget_size(c, stagger.id, WidgetSize::OneByOne);
        assert_eq!(c.tabs[0].widgets[0].size, WidgetSize::ThreeByOne);
        let c = menu_set_widget_size(c, stagger.id, WidgetSize::TwoByTwo);
        assert_eq!(c.tabs[0].widgets[0].size, WidgetSize::TwoByTwo);
    }

    #[test]
    fn abas_tem_limites() {
        let mut c = default_menu_bar();
        for _ in 0..10 {
            c = menu_add_tab(c, "  muito   espaço  ".into());
        }
        assert_eq!(c.tabs.len(), MAX_TABS);
        assert_eq!(c.tabs[4].name, "muito espaço");
        let c = menu_rename_tab(c.clone(), c.tabs[0].id, "".into());
        assert_eq!(c.tabs[0].name, "Nova aba");
        let mut c = c;
        while c.tabs.len() > 1 {
            let id = c.tabs[0].id;
            c = menu_remove_tab(c, id);
        }
        let last = c.tabs[0].id;
        let c = menu_remove_tab(c, last);
        assert_eq!(c.tabs.len(), 1);
    }

    #[test]
    fn adicionar_usa_o_tamanho_padrao_e_a_posicao() {
        let c = default_menu_bar();
        let tab = c.tabs[1].id;
        let c = menu_add_widget(c, tab, WidgetKind::Heatmap, Some(1));
        let w = c.tabs[1].widgets[1];
        assert_eq!((w.kind, w.size), (WidgetKind::Heatmap, WidgetSize::ThreeByOne));
    }

    #[test]
    fn guardar_e_ler_devolve_a_mesma_configuracao() {
        let c = default_menu_bar();
        let tab = c.tabs[0].id;
        let c = menu_rename_tab(c, tab, "Meu \\ início\nnovo".into());
        let c = menu_move_tab(c, tab, 3);
        let mut c = c;
        c.open_first_tab = false;
        let back = menu_bar_decode(menu_bar_encode(c.clone())).expect("lê o que gravou");
        assert_eq!(back, c);
    }

    #[test]
    fn leitura_tolera_versao_nova_e_rejeita_lixo() {
        let text = format!("{HEADER}\nopen_first_tab 1\ntab 1 A\nwidget 2 widget_do_futuro 1x1 1\nwidget 3 stagger 1x1 1\n");
        let c = menu_bar_decode(text).unwrap();
        assert_eq!(c.tabs[0].widgets.len(), 1);
        assert_eq!(c.tabs[0].widgets[0].size, WidgetSize::ThreeByOne);
        assert_eq!(c.next_id, 4);
        assert!(menu_bar_decode("outra coisa".into()).is_none());
        assert!(menu_bar_decode(format!("{HEADER}\n")).is_none());
    }
}
