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

/// Onde o widget arrastado cairia na grade, e se cabe ali.
struct DropTarget: Equatable {
    var column: UInt8
    var row: UInt32
    var size: WidgetSize
    var fits: Bool
}

/// Monta as abas do popover numa grade de 3 colunas: cada widget vai para a célula onde é
/// solto, e células vazias continuam vazias. Toda edição é uma operação do núcleo.
struct MenuBarEditorScreen: View {
    @Environment(KeyboardStore.self) private var store
    @State private var editingTab: UInt32?
    @State private var selected: UInt32?
    @State private var dragging: MenuDragItem?
    @State private var target: DropTarget?
    @State private var hoveredChip: UInt32?

    private let metrics = GridMetrics.popover

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                preview
                    .padding(24)
                    .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            Divider()
            // Coluna da direita: abas, ajustes do widget selecionado e a biblioteca.
            VStack(spacing: 0) {
                TabsPanel(editingTab: $editingTab)
                    .frame(height: 250)
                Divider()
                if let slot = selectedSlot {
                    WidgetInspector(slot: slot, deselect: { selected = nil })
                    Divider()
                }
                WidgetLibrary(tab: tab, dragging: $dragging, removeDragged: removeDragged)
            }
            .frame(width: 340)
        }
        .navigationTitle("Barra de menus")
        .onAppear { if editingTab == nil { editingTab = store.menuBar.tabs.first?.id } }
        .onChange(of: dragging) { _, now in
            if now != nil { watchDragEnd() }
        }
    }

    /// Soltar fora de qualquer alvo não avisa ninguém: quando o botão do mouse sobe, o arrasto acabou.
    private func watchDragEnd() {
        Task { @MainActor in
            while dragging != nil {
                try? await Task.sleep(for: .milliseconds(150))
                if NSEvent.pressedMouseButtons & 1 == 0 {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        dragging = nil
                        target = nil
                    }
                }
            }
        }
    }

    private var tab: MenuTab {
        store.menuBar.tabs.first { $0.id == editingTab } ?? store.menuBar.tabs[0]
    }

    private var selectedSlot: WidgetSlot? {
        guard let selected else { return nil }
        return store.menuBar.tabs.lazy.flatMap(\.widgets).first { $0.id == selected }
    }

    /// Linhas desenhadas: as usadas. Só enquanto algo é arrastado aparece uma linha vazia a
    /// mais embaixo, para ter onde soltar. Aba vazia mostra uma linha de células.
    private var shownRows: Int {
        let used = Int(tabGrid(tab: tab).rows)
        guard dragging != nil else { return max(used, 1) }
        let dropBottom = target.map { Int($0.row) + $0.size.rows } ?? 0
        return max(max(used, dropBottom) + 1, 2)
    }

    // MARK: prévia

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Solte cada widget na célula que quiser; pode deixar espaços. Se não couber inteiro, ele se ajusta ao espaço. Sobre uma aba, muda de aba.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Tirar espaços vazios") {
                    store.editMenuBar { menuCompactTab(config: $0, tabId: tab.id) }
                }
                .controlSize(.small)
                .help("Sobe cada widget para o primeiro lugar livre")
            }
            .frame(width: metrics.width + 24)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    YggiMark().frame(height: 16)
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

                ZStack(alignment: .topLeading) {
                    cells
                    WidgetGrid(tab: tab, metrics: metrics, minRows: shownRows) { slot, _ in cell(slot) }
                    ghost
                }
                .frame(width: metrics.width, height: metrics.height(rows: shownRows), alignment: .topLeading)
                .animation(.easeInOut(duration: 0.15), value: shownRows)
                .onDrop(of: [.text], delegate: GridDrop(
                    tab: tab, metrics: metrics, allSlots: store.menuBar.tabs.flatMap(\.widgets),
                    dragging: $dragging, target: $target, drop: dropOnCell))
            }
            .padding(12)
            .frame(width: metrics.width + 24)
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        }
    }

    /// As células vazias da grade, para ver as linhas e colunas.
    private var cells: some View {
        ForEach(0..<shownRows, id: \.self) { row in
            ForEach(0..<3, id: \.self) { column in
                let rect = metrics.rect(WidgetPlacement(widgetId: 0, column: UInt8(column), row: UInt32(row), columns: 1, rows: 1))
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .allowsHitTesting(false)
    }

    /// Onde o widget arrastado vai cair: azul se cabe, vermelho se cobre outro.
    @ViewBuilder private var ghost: some View {
        if let target {
            let rect = metrics.rect(WidgetPlacement(widgetId: 0, column: target.column, row: target.row,
                                                    columns: UInt8(target.size.columns), rows: UInt8(target.size.rows)))
            let color = target.fits ? Color.accentColor : Color.red
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 2))
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.1), value: target)
        }
    }

    private func cell(_ slot: WidgetSlot) -> some View {
        WidgetView(slot: slot, highlighted: selected == slot.id)
            .allowsHitTesting(false)
            .opacity(dragging == .widget(slot.id) ? 0.35 : 1)
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
            .overlay {
                // Bordas da direita e de baixo (e o canto): arrastar muda o tamanho na hora.
                ResizeHandles(slot: slot, metrics: metrics) { columns, rows in
                    selected = slot.id
                    store.editMenuBar { menuResizeWidget(config: $0, widgetId: slot.id, columns: UInt8(columns), rows: UInt8(rows)) }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(store.info(slot.kind).name), \(slot.size.label), coluna \(slot.column + 1), linha \(slot.row + 1)")
            .accessibilityAction(named: "Remover") { remove(slot.id) }
    }

    // MARK: ações

    private func select(tab id: UInt32) {
        withAnimation(.easeInOut(duration: 0.15)) { editingTab = id }
    }

    private func dropOnCell(_ target: DropTarget) {
        switch dragging {
        case .widget(let id):
            store.editMenuBar { menuPlaceWidget(config: $0, widgetId: id, toTabId: tab.id, column: target.column, row: target.row) }
        case .kind(let kind):
            let newId = store.menuBar.nextId
            store.editMenuBar { menuAddWidget(config: $0, tabId: tab.id, kind: kind, at: GridCell(column: target.column, row: target.row), size: target.size) }
            selected = newId
        case nil: break
        }
        dragging = nil
    }

    private func dropOnTab(_ tabId: UInt32) {
        switch dragging {
        case .widget(let id):
            store.editMenuBar { menuMoveWidgetToTab(config: $0, widgetId: id, toTabId: tabId) }
        case .kind(let kind):
            let newId = store.menuBar.nextId
            store.editMenuBar { menuAddWidget(config: $0, tabId: tabId, kind: kind, at: nil, size: nil) }
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

// MARK: - redimensionar pelas bordas

private enum ResizeEdge {
    case right, bottom, corner

    var cursor: NSCursor {
        switch self {
        case .right: .resizeLeftRight
        case .bottom: .resizeUpDown
        case .corner:
            if #available(macOS 15, *) {
                .frameResize(position: .bottomRight, directions: .all)
            } else {
                .crosshair
            }
        }
    }
}

/// Faixas invisíveis na borda direita, na de baixo e no canto. Com o mouse perto, o cursor
/// vira o de redimensionar; arrastando, o widget muda de tamanho encaixando na grade. O núcleo
/// escolhe o tamanho aceito mais perto do puxado (até o máximo do widget, sem cobrir outro).
private struct ResizeHandles: View {
    let slot: WidgetSlot
    let metrics: GridMetrics
    let resize: (_ columns: Int, _ rows: Int) -> Void

    @State private var hovering: ResizeEdge?
    @State private var active: ResizeEdge?
    /// Tamanho em pontos quando o arrasto começou, e o último tamanho pedido.
    @State private var start: CGSize?
    @State private var asked: (Int, Int)?

    private let thickness: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                strip(.right, size: CGSize(width: thickness, height: h - thickness), at: CGPoint(x: w - thickness / 2 - 2, y: 0))
                strip(.bottom, size: CGSize(width: w - thickness, height: thickness), at: CGPoint(x: 0, y: h - thickness / 2 - 2))
                strip(.corner, size: CGSize(width: thickness * 1.8, height: thickness * 1.8),
                      at: CGPoint(x: w - thickness * 1.3, y: h - thickness * 1.3))
            }
        }
    }

    private func strip(_ edge: ResizeEdge, size: CGSize, at origin: CGPoint) -> some View {
        let lit = hovering == edge || active == edge
        return ZStack {
            Color.white.opacity(0.001)
            if lit { mark(edge) }
        }
        .frame(width: max(size.width, 1), height: max(size.height, 1))
        .offset(x: origin.x, y: origin.y)
        .onHover { inside in
            if inside {
                hovering = edge
                edge.cursor.push()
            } else if hovering == edge {
                hovering = nil
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { g in drag(edge, g.translation) }
                .onEnded { _ in
                    active = nil
                    start = nil
                    asked = nil
                }
        )
        .accessibilityHidden(true)
    }

    /// A marquinha que aparece na borda com o mouse perto.
    @ViewBuilder private func mark(_ edge: ResizeEdge) -> some View {
        switch edge {
        case .right: Capsule().fill(Color.accentColor).frame(width: 4, height: 26)
        case .bottom: Capsule().fill(Color.accentColor).frame(width: 26, height: 4)
        case .corner:
            Image(systemName: "arrow.down.right").font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 14, height: 14)
                .background(Circle().fill(Color.accentColor))
        }
    }

    private func drag(_ edge: ResizeEdge, _ t: CGSize) {
        if start == nil {
            active = edge
            let r = metrics.rect(WidgetPlacement(widgetId: 0, column: 0, row: 0,
                                                 columns: UInt8(slot.size.columns), rows: UInt8(slot.size.rows)))
            start = r.size
        }
        guard let start else { return }
        let colW = metrics.cell + metrics.gap, rowH = metrics.row + metrics.gap
        var columns = slot.size.columns, rows = slot.size.rows
        if edge != .bottom {
            columns = min(max(Int(((start.width + metrics.gap + t.width) / colW).rounded()), 1), 3)
        }
        if edge != .right {
            rows = min(max(Int(((start.height + metrics.gap + t.height) / rowH).rounded()), 1), 2)
        }
        if asked.map({ $0 != (columns, rows) }) ?? true {
            asked = (columns, rows)
            resize(columns, rows)
        }
    }
}

// MARK: - soltar na grade

/// Calcula a célula sob o cursor (o widget fica centrado nele) e pergunta ao núcleo se cabe.
private struct GridDrop: DropDelegate {
    let tab: MenuTab
    let metrics: GridMetrics
    let allSlots: [WidgetSlot]
    @Binding var dragging: MenuDragItem?
    @Binding var target: DropTarget?
    let drop: (DropTarget) -> Void

    func validateDrop(info: DropInfo) -> Bool { dragging != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let new = targetAt(info.location)
        if new != target { target = new }
        return DropProposal(operation: new?.fits == true ? .move : .forbidden)
    }

    func dropExited(info: DropInfo) { target = nil }

    func performDrop(info: DropInfo) -> Bool {
        defer { target = nil }
        guard let t = targetAt(info.location), t.fits else {
            dragging = nil
            return false
        }
        drop(t)
        return true
    }

    private func targetAt(_ point: CGPoint) -> DropTarget? {
        let kind: WidgetKind
        let preferred: WidgetSize
        let ignoring: UInt32?
        switch dragging {
        case .widget(let id):
            // Pode vir de outra aba (depois de parar sobre a aba): procura na config inteira.
            guard let slot = allSlots.first(where: { $0.id == id }) else { return nil }
            (kind, preferred, ignoring) = (slot.kind, slot.size, id)
        case .kind(let k):
            // Da biblioteca: o maior tamanho, como aparece lá.
            (kind, preferred, ignoring) = (k, widgetLargestSize(kind: k), nil)
        case nil:
            return nil
        }
        let colW = metrics.cell + metrics.gap, rowH = metrics.row + metrics.gap
        let col = Int((point.x / colW - CGFloat(preferred.columns) / 2).rounded())
        let row = Int((point.y / rowH - CGFloat(preferred.rows) / 2).rounded())
        let column = UInt8(min(max(col, 0), 3 - preferred.columns))
        let r = UInt32(max(row, 0))
        // O núcleo diz com que tamanho ele entra ali (o preferido, ou o maior que couber).
        if let size = widgetFitSize(tab: tab, kind: kind, preferred: preferred, column: column, row: r, ignoring: ignoring) {
            return DropTarget(column: column, row: r, size: size, fits: true)
        }
        return DropTarget(column: column, row: r, size: preferred, fits: false)
    }
}

/// Parar sobre uma aba abre essa aba; soltar nela manda o widget para o primeiro lugar livre dela.
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Biblioteca").font(.headline)
            HStack(spacing: 8) {
                TextField("Buscar widget", text: $search).textFieldStyle(.roundedBorder)
                Picker("Categoria", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            Text(removeTargeted ? "Solte para tirar o widget da aba" : "Arraste para a célula que quiser. Arraste um widget da prévia para cá para tirar da aba.")
                .font(.caption)
                .foregroundStyle(removeTargeted ? Color.red : .secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(items, id: \.kind) { info in
                        LibraryItem(info: info) {
                            store.editMenuBar { menuAddWidget(config: $0, tabId: tab.id, kind: info.kind, at: nil, size: nil) }
                        }
                        .onDrag {
                            dragging = .kind(info.kind)
                            return NSItemProvider(object: "yggi-widget" as NSString)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(removeTargeted ? Color.red.opacity(0.06) : .clear)
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

/// Um widget da biblioteca, desenhado de verdade no maior tamanho dele (reduzido para caber).
private struct LibraryItem: View {
    let info: WidgetInfo
    let add: () -> Void
    @State private var hover = false

    /// Largura útil da coluna da biblioteca.
    private let width: CGFloat = 312

    var body: some View {
        let size = widgetLargestSize(kind: info.kind)
        let metrics = GridMetrics.popover
        let rect = metrics.rect(WidgetPlacement(widgetId: 0, column: 0, row: 0, columns: UInt8(size.columns), rows: UInt8(size.rows)))
        let scale = min(1, width / metrics.width)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(info.name).font(.callout.weight(.medium))
                Spacer(minLength: 0)
                Text(info.sizes.map(\.label).joined(separator: " · "))
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Button(action: add) { Image(systemName: "plus.circle.fill") }
                    .buttonStyle(.borderless)
                    .help("Adicionar à aba")
            }
            WidgetView(slot: WidgetSlot(id: 0, kind: info.kind, size: size, showTitle: true, column: 0, row: 0))
                .frame(width: rect.width, height: rect.height)
                .allowsHitTesting(false)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: rect.width * scale, height: rect.height * scale, alignment: .topLeading)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: hover ? 2 : 0))
                .onHover { hover = $0 }
                .help(info.summary)
        }
        .contentShape(Rectangle())
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
                store.editMenuBar { menuMoveWidgetToTab(config: $0, widgetId: slot.id, toTabId: tab.id) }
            }
            .disabled(tab.id == home)
        }
    }
}

extension WidgetSize: @retroactive CaseIterable {
    public static var allCases: [WidgetSize] { [.oneByOne, .twoByOne, .threeByOne, .oneByTwo, .twoByTwo, .threeByTwo] }
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
