import SwiftUI
import UniformTypeIdentifiers
import YggiCore

/// O que está sendo arrastado no editor.
enum MenuDragItem: Equatable {
    /// Um widget que já está numa aba.
    case widget(UInt32)
    /// Um widget novo, vindo da biblioteca.
    case kind(WidgetKind)
}

/// Monta as abas do popover: arraste widgets para reordenar, entre abas e da biblioteca.
/// Toda edição é uma operação do núcleo; aqui só se traduz o gesto.
struct MenuBarEditorScreen: View {
    @Environment(KeyboardStore.self) private var store
    @State private var editingTab: UInt32?
    @State private var selected: UInt32?
    @State private var dragging: MenuDragItem?
    /// Onde um widget novo (ou de outra aba) vai entrar, para destacar.
    @State private var dropIndex: Int?
    @State private var hoveredChip: UInt32?

    private let metrics = GridMetrics.popover

    var body: some View {
        HStack(spacing: 0) {
            TabsPanel(editingTab: $editingTab)
                .frame(width: 200)
            Divider()
            ScrollView {
                preview
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            Divider()
            VStack(spacing: 0) {
                if let slot = selectedSlot {
                    WidgetInspector(slot: slot, deselect: { selected = nil })
                    Divider()
                }
                WidgetLibrary(tab: tab, dragging: $dragging, removeDragged: removeDragged)
            }
            .frame(width: 280)
        }
        .navigationTitle("Barra de menus")
        .onAppear { if editingTab == nil { editingTab = store.menuBar.tabs.first?.id } }
    }

    private var tab: MenuTab {
        store.menuBar.tabs.first { $0.id == editingTab } ?? store.menuBar.tabs[0]
    }

    private var selectedSlot: WidgetSlot? {
        guard let selected else { return nil }
        return store.menuBar.tabs.lazy.flatMap(\.widgets).first { $0.id == selected }
    }

    // MARK: prévia

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Arraste para reordenar. Solte sobre uma aba para mudar de aba. Arraste da biblioteca para adicionar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: metrics.width + 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("Yggi").font(.headline)
                    Spacer()
                    Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
                }
                TabChips(tabs: store.menuBar.tabs, current: tab.id, dropTarget: hoveredChip) { select(tab: $0) }
                    .onDrop(of: [.text], delegate: ChipsDrop(
                        tabs: store.menuBar.tabs, width: metrics.width,
                        dragging: $dragging, hovered: $hoveredChip,
                        switchTo: { select(tab: $0) },
                        drop: dropOnTab))

                WidgetGrid(tab: tab, metrics: metrics, minRows: 2) { slot, _ in
                    cell(slot)
                }
                .overlay(alignment: .topLeading) { emptyHint }
                .onDrop(of: [.text], delegate: GridDrop(
                    tab: tab, metrics: metrics, dragging: $dragging, dropIndex: $dropIndex,
                    move: moveWidget, add: addWidget))
            }
            .padding(12)
            .frame(width: metrics.width + 24)
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        }
    }

    @ViewBuilder private var emptyHint: some View {
        if tab.widgets.isEmpty {
            Text("Aba vazia: arraste widgets da biblioteca para cá")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: metrics.width, height: metrics.height(rows: 2))
                .background(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(dropIndex != nil ? Color.accentColor : Color(nsColor: .separatorColor),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5])))
                .allowsHitTesting(false)
        }
    }

    private func cell(_ slot: WidgetSlot) -> some View {
        let index = tab.widgets.firstIndex { $0.id == slot.id }
        let target = dropIndex != nil && dropIndex == index
        return WidgetView(slot: slot, highlighted: selected == slot.id || target)
            .allowsHitTesting(false)
            .opacity(dragging == .widget(slot.id) ? 0.45 : 1)
            .overlay(alignment: .topTrailing) {
                if selected == slot.id {
                    Text(slot.size.label)
                        .font(.caption2.weight(.semibold)).monospacedDigit()
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .overlay {
                // Camada que recebe clique e arrasto (os controles do widget ficam inertes aqui).
                Color.white.opacity(0.001)
                    .onTapGesture { selected = slot.id }
                    .onDrag {
                        dragging = .widget(slot.id)
                        selected = slot.id
                        return NSItemProvider(object: "yggi-widget" as NSString)
                    }
                    .contextMenu { WidgetMenu(slot: slot, remove: { remove(slot.id) }) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(store.info(slot.kind).name), \(slot.size.label)")
            .accessibilityAction(named: "Remover") { remove(slot.id) }
    }

    // MARK: ações

    private func select(tab id: UInt32) {
        withAnimation(.easeInOut(duration: 0.15)) { editingTab = id }
    }

    private func moveWidget(_ id: UInt32, to index: Int) {
        store.editMenuBar { menuMoveWidget(config: $0, widgetId: id, toTabId: tab.id, toIndex: UInt32(index)) }
    }

    private func addWidget(_ kind: WidgetKind, at index: Int?) {
        let newId = store.menuBar.nextId
        store.editMenuBar { menuAddWidget(config: $0, tabId: tab.id, kind: kind, atIndex: index.map(UInt32.init)) }
        selected = newId
    }

    private func dropOnTab(_ tabId: UInt32) {
        switch dragging {
        case .widget(let id):
            store.editMenuBar { menuMoveWidget(config: $0, widgetId: id, toTabId: tabId, toIndex: .max) }
        case .kind(let kind):
            let newId = store.menuBar.nextId
            store.editMenuBar { menuAddWidget(config: $0, tabId: tabId, kind: kind, atIndex: nil) }
            selected = newId
        case nil: break
        }
        select(tab: tabId)
        dragging = nil
    }

    private func remove(_ id: UInt32) {
        if selected == id { selected = nil }
        store.editMenuBar { menuRemoveWidget(config: $0, widgetId: id) }
    }

    /// Soltar um widget na biblioteca tira ele da aba.
    private func removeDragged() -> Bool {
        guard case .widget(let id) = dragging else { return false }
        remove(id)
        dragging = nil
        return true
    }
}

// MARK: - soltar na grade

/// Enquanto um widget da aba é arrastado, a grade se rearruma ao vivo (o núcleo reposiciona).
/// Widget novo ou de outra aba: mostra onde entra e só adiciona ao soltar.
private struct GridDrop: DropDelegate {
    let tab: MenuTab
    let metrics: GridMetrics
    @Binding var dragging: MenuDragItem?
    @Binding var dropIndex: Int?
    let move: (UInt32, Int) -> Void
    let add: (WidgetKind, Int?) -> Void

    func validateDrop(info: DropInfo) -> Bool { dragging != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let target = index(at: info.location)
        if case .widget(let id) = dragging, let current = tab.widgets.firstIndex(where: { $0.id == id }) {
            // Só troca quando o cursor está sobre outro widget, para não ficar indo e voltando.
            if let over = widgetIndex(at: info.location), over != current {
                move(id, over)
            }
            dropIndex = nil
        } else {
            dropIndex = target
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { dropIndex = nil }

    func performDrop(info: DropInfo) -> Bool {
        let target = index(at: info.location)
        switch dragging {
        case .widget(let id):
            if !tab.widgets.contains(where: { $0.id == id }) { move(id, target) }
        case .kind(let kind):
            add(kind, target)
        case nil:
            return false
        }
        dragging = nil
        dropIndex = nil
        return true
    }

    private func widgetIndex(at point: CGPoint) -> Int? {
        let grid = tabGrid(tab: tab)
        guard let p = grid.placements.first(where: { metrics.rect($0).contains(point) }) else { return nil }
        return tab.widgets.firstIndex { $0.id == p.widgetId }
    }

    /// Posição de entrada: antes do widget sob o cursor (depois, se na metade direita); senão no fim.
    private func index(at point: CGPoint) -> Int {
        let grid = tabGrid(tab: tab)
        guard let p = grid.placements.first(where: { metrics.rect($0).contains(point) }),
              let i = tab.widgets.firstIndex(where: { $0.id == p.widgetId }) else { return tab.widgets.count }
        return point.x > metrics.rect(p).midX ? i + 1 : i
    }
}

/// Parar sobre uma aba abre essa aba; soltar nela manda o widget para o fim dela.
private struct ChipsDrop: DropDelegate {
    let tabs: [MenuTab]
    let width: CGFloat
    @Binding var dragging: MenuDragItem?
    @Binding var hovered: UInt32?
    let switchTo: (UInt32) -> Void
    let drop: (UInt32) -> Void

    func validateDrop(info: DropInfo) -> Bool { dragging != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let id = tab(at: info.location)
        if id != hovered {
            hovered = id
            if let id { switchTo(id) }
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { hovered = nil }

    func performDrop(info: DropInfo) -> Bool {
        hovered = nil
        guard let id = tab(at: info.location) else { return false }
        drop(id)
        return true
    }

    private func tab(at point: CGPoint) -> UInt32? {
        guard !tabs.isEmpty else { return nil }
        let i = Int(point.x / (width / CGFloat(tabs.count)))
        return tabs[min(max(i, 0), tabs.count - 1)].id
    }
}

// MARK: - abas

private struct TabsPanel: View {
    @Environment(KeyboardStore.self) private var store
    @Binding var editingTab: UInt32?

    var body: some View {
        let tabs = store.menuBar.tabs
        VStack(alignment: .leading, spacing: 0) {
            Text("Abas").font(.headline).padding([.horizontal, .top], 14).padding(.bottom, 6)
            List(selection: $editingTab) {
                ForEach(tabs, id: \.id) { tab in
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                        TabNameField(tab: tab)
                        Spacer()
                        Text("\(tab.widgets.count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .tag(tab.id)
                    .contextMenu {
                        Button("Remover aba", role: .destructive) { removeTab(tab.id) }
                            .disabled(tabs.count == 1)
                    }
                }
                .onMove { from, to in
                    guard let first = from.first else { return }
                    let id = tabs[first].id
                    let dest = to > first ? to - 1 : to
                    store.editMenuBar { menuMoveTab(config: $0, tabId: id, toIndex: UInt32(dest)) }
                }
            }
            .listStyle(.inset)

            HStack(spacing: 4) {
                Button {
                    store.editMenuBar { menuAddTab(config: $0, name: "Nova aba") }
                    editingTab = store.menuBar.tabs.last?.id
                } label: { Image(systemName: "plus") }
                    .disabled(tabs.count >= 6)
                    .help("Nova aba (até 6)")
                Button {
                    if let id = editingTab { removeTab(id) }
                } label: { Image(systemName: "minus") }
                    .disabled(tabs.count == 1)
                    .help("Remover a aba selecionada e os widgets dela")
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12).padding(.vertical, 6)

            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Abrir sempre na primeira aba", isOn: Binding(
                    get: { store.menuBar.openFirstTab }, set: { store.setOpenFirstTab($0) }))
                    .font(.callout)
                Button("Restaurar abas de fábrica") {
                    store.resetMenuBar()
                    editingTab = store.menuBar.tabs.first?.id
                }
                .controlSize(.small)
            }
            .padding(14)
        }
    }

    private func removeTab(_ id: UInt32) {
        store.editMenuBar { menuRemoveTab(config: $0, tabId: id) }
        if editingTab == id { editingTab = store.menuBar.tabs.first?.id }
    }
}

/// Nome da aba, editado no lugar. Só grava ao confirmar, para o núcleo não cortar espaços no meio da digitação.
private struct TabNameField: View {
    @Environment(KeyboardStore.self) private var store
    let tab: MenuTab
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Nome", text: $text)
            .textFieldStyle(.plain)
            .focused($focused)
            .onAppear { text = tab.name }
            .onChange(of: tab.name) { _, name in if !focused { text = name } }
            .onChange(of: focused) { _, now in if !now { commit() } }
            .onSubmit(commit)
    }

    private func commit() {
        guard text != tab.name else { return }
        store.editMenuBar { menuRenameTab(config: $0, tabId: tab.id, name: text) }
        text = store.menuBar.tabs.first { $0.id == tab.id }?.name ?? text
    }
}

// MARK: - biblioteca

private struct WidgetLibrary: View {
    @Environment(KeyboardStore.self) private var store
    let tab: MenuTab
    @Binding var dragging: MenuDragItem?
    let removeDragged: () -> Bool
    @State private var search = ""
    @State private var category = "Todos"
    @State private var removeTargeted = false

    var body: some View {
        let categories = ["Todos"] + store.catalog.map(\.category).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        VStack(alignment: .leading, spacing: 8) {
            Text("Biblioteca").font(.headline)
            TextField("Buscar widget", text: $search).textFieldStyle(.roundedBorder)
            Picker("Categoria", selection: $category) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(items, id: \.kind) { info in
                        LibraryRow(info: info) {
                            store.editMenuBar { menuAddWidget(config: $0, tabId: tab.id, kind: info.kind, atIndex: nil) }
                        }
                        .onDrag {
                            dragging = .kind(info.kind)
                            return NSItemProvider(object: "yggi-widget" as NSString)
                        }
                    }
                }
            }
            Label("Solte um widget aqui para tirar da aba", systemImage: "trash")
                .font(.caption)
                .foregroundStyle(removeTargeted ? Color.red : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(removeTargeted ? Color.red.opacity(0.1) : .clear))
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .onDrop(of: [.text], isTargeted: Binding(
            get: { removeTargeted },
            set: { removeTargeted = $0 && isDraggingWidget })) { _ in removeDragged() }
    }

    private var isDraggingWidget: Bool {
        if case .widget = dragging { true } else { false }
    }

    private var items: [WidgetInfo] {
        store.catalog.filter { info in
            (category == "Todos" || info.category == category)
                && (search.isEmpty || info.name.localizedCaseInsensitiveContains(search)
                    || info.summary.localizedCaseInsensitiveContains(search))
        }
    }
}

private struct LibraryRow: View {
    let info: WidgetInfo
    let add: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: info.kind.symbol)
                .font(.system(size: 14))
                .foregroundStyle(.yggiText)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
            VStack(alignment: .leading, spacing: 3) {
                Text(info.name).font(.callout.weight(.medium))
                Text(info.summary).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 3) {
                    ForEach(info.sizes, id: \.self) { size in
                        Text(size.label).font(.system(size: 9, weight: .medium)).monospacedDigit()
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .overlay(Capsule().strokeBorder(.separator))
                    }
                }
            }
            Spacer(minLength: 0)
            Button(action: add) { Image(systemName: "plus.circle.fill").font(.title3) }
                .buttonStyle(.borderless)
                .help("Adicionar à aba")
                .opacity(hover ? 1 : 0.5)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Color.primary.opacity(0.05) : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

// MARK: - inspetor

private struct WidgetInspector: View {
    @Environment(KeyboardStore.self) private var store
    let slot: WidgetSlot
    let deselect: () -> Void

    var body: some View {
        let info = store.info(slot.kind)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: slot.kind.symbol).foregroundStyle(.yggiText)
                Text(info.name).font(.headline)
                Spacer()
                Button(action: deselect) { Image(systemName: "xmark") }.buttonStyle(.borderless)
            }
            Text("Tamanho").font(.caption).foregroundStyle(.secondary)
            SizePicker(allowed: info.sizes, current: slot.size) { size in
                store.editMenuBar { menuSetWidgetSize(config: $0, widgetId: slot.id, size: size) }
            }
            Toggle("Mostrar título", isOn: Binding(
                get: { slot.showTitle },
                set: { show in store.editMenuBar { menuSetWidgetTitle(config: $0, widgetId: slot.id, show: show) } }))
            HStack {
                Menu("Mover para") {
                    WidgetMoveItems(slot: slot)
                }
                .fixedSize()
                Spacer()
                Button("Remover", role: .destructive) {
                    deselect()
                    store.editMenuBar { menuRemoveWidget(config: $0, widgetId: slot.id) }
                }
            }
            .controlSize(.small)
        }
        .padding(14)
    }
}

/// Os cinco tamanhos, com os que o widget não aceita apagados.
private struct SizePicker: View {
    let allowed: [WidgetSize]
    let current: WidgetSize
    let pick: (WidgetSize) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WidgetSize.allCases, id: \.self) { size in
                let ok = allowed.contains(size)
                let on = size == current
                Button { pick(size) } label: {
                    VStack(spacing: 4) {
                        SizeGlyph(size: size).frame(width: 30, height: 20)
                        Text(size.label).font(.caption2).monospacedDigit()
                    }
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 6).fill(on ? Color.accentColor.opacity(0.16) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(on ? Color.accentColor : Color(nsColor: .separatorColor)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!ok)
                .opacity(ok ? 1 : 0.3)
                .help(ok ? "Tamanho \(size.label)" : "Este widget não tem tamanho \(size.label)")
            }
        }
    }
}

/// Grade 3×2 com as células que o tamanho ocupa preenchidas.
private struct SizeGlyph: View {
    let size: WidgetSize

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<2, id: \.self) { r in
                GridRow {
                    ForEach(0..<3, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(r < size.rows && c < size.columns ? Color.accentColor : Color.secondary.opacity(0.25))
                    }
                }
            }
        }
    }
}

private struct WidgetMenu: View {
    @Environment(KeyboardStore.self) private var store
    let slot: WidgetSlot
    let remove: () -> Void

    var body: some View {
        let info = store.info(slot.kind)
        Menu("Tamanho") {
            ForEach(info.sizes, id: \.self) { size in
                Button {
                    store.editMenuBar { menuSetWidgetSize(config: $0, widgetId: slot.id, size: size) }
                } label: {
                    if size == slot.size { Label(size.label, systemImage: "checkmark") } else { Text(size.label) }
                }
            }
        }
        Menu("Mover para") { WidgetMoveItems(slot: slot) }
        Divider()
        Button("Remover", role: .destructive, action: remove)
    }
}

private struct WidgetMoveItems: View {
    @Environment(KeyboardStore.self) private var store
    let slot: WidgetSlot

    var body: some View {
        let home = store.menuBar.tabs.first { $0.widgets.contains { $0.id == slot.id } }?.id
        ForEach(store.menuBar.tabs, id: \.id) { tab in
            Button(tab.name) {
                store.editMenuBar { menuMoveWidget(config: $0, widgetId: slot.id, toTabId: tab.id, toIndex: .max) }
            }
            .disabled(tab.id == home)
        }
    }
}

extension WidgetSize: @retroactive CaseIterable {
    public static var allCases: [WidgetSize] { [.oneByOne, .twoByOne, .threeByOne, .twoByTwo, .threeByTwo] }
}

extension WidgetKind {
    var symbol: String {
        switch self {
        case .stagger: "keyboard"
        case .staggerQuick: "arrow.up.and.down.square"
        case .activeHost: "laptopcomputer"
        case .hosts: "desktopcomputer"
        case .layer: "square.3.layers.3d"
        case .battery: "battery.75percent"
        case .halves: "rectangle.split.2x1"
        case .brightness: "sun.max"
        case .lightColor: "paintpalette"
        case .today: "text.word.spacing"
        case .dailyGoal: "target"
        case .heatmap: "square.grid.3x3.fill"
        case .break: "cup.and.saucer"
        case .quickActions: "bolt"
        case .customButton: "star.circle"
        case .firmware: "cpu"
        }
    }
}
