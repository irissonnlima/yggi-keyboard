import SwiftUI
import YggiCore

extension WidgetSize {
    var columns: Int { Int(widgetSizeColumns(size: self)) }
    var rows: Int { Int(widgetSizeRows(size: self)) }
    var label: String { widgetSizeLabel(size: self) }
}

/// Medidas da grade de 3 colunas. O popover e a prévia do editor usam as mesmas.
struct GridMetrics {
    var cell: CGFloat = 112
    var row: CGFloat = 78
    var gap: CGFloat = 8

    static let popover = GridMetrics()

    var width: CGFloat { cell * 3 + gap * 2 }

    func height(rows: Int) -> CGFloat {
        rows == 0 ? 0 : CGFloat(rows) * row + CGFloat(rows - 1) * gap
    }

    func rect(_ p: WidgetPlacement) -> CGRect {
        CGRect(x: CGFloat(p.column) * (cell + gap),
               y: CGFloat(p.row) * (row + gap),
               width: CGFloat(p.columns) * cell + CGFloat(p.columns - 1) * gap,
               height: height(rows: Int(p.rows)))
    }
}

/// Desenha os widgets de uma aba onde o núcleo mandou (`tabGrid`).
struct WidgetGrid<Cell: View>: View {
    let tab: MenuTab
    var metrics = GridMetrics.popover
    /// Linhas mínimas, para a aba vazia ainda ter onde soltar.
    var minRows = 0
    @ViewBuilder var cell: (WidgetSlot, WidgetPlacement) -> Cell

    var body: some View {
        let grid = tabGrid(tab: tab)
        ZStack(alignment: .topLeading) {
            ForEach(grid.placements, id: \.widgetId) { p in
                if let slot = tab.widgets.first(where: { $0.id == p.widgetId }) {
                    let r = metrics.rect(p)
                    cell(slot, p)
                        .frame(width: r.width, height: r.height)
                        .offset(x: r.minX, y: r.minY)
                }
            }
        }
        .frame(width: metrics.width, height: metrics.height(rows: max(Int(grid.rows), minRows)), alignment: .topLeading)
    }
}

/// Moldura comum dos widgets.
struct WidgetCard<Content: View>: View {
    let title: String?
    var highlighted = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            // O conteúdo fica centrado no espaço que sobra embaixo do título.
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.opacity(0.75)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(highlighted ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.7),
                              lineWidth: highlighted ? 2 : 0.5)
        )
    }
}
