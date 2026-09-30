import SwiftUI
import YggiCore

/// O e-reader destacável, na mesma cor do teclado. Encaixado, mostra o estado do teclado;
/// solto, uma página de leitura. Ao encaixar, a tela e-ink pisca (preto, branco, volta).
struct ReaderView: View {
    let state: KeyboardState
    let width: CGFloat
    let height: CGFloat
    let scale: CGFloat

    @State private var flash: Color = Hardware.eInk

    var body: some View {
        let s = scale
        VStack(alignment: .leading, spacing: 8 * s) {
            if state.reader == .docked {
                docked(s)
            } else {
                reading(s)
            }
        }
        .padding(.horizontal, 12 * s)
        .padding(.vertical, 14 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 4 * s).fill(flash))
        .foregroundStyle(Hardware.eInkText)
        .padding(EdgeInsets(top: 10 * s, leading: 10 * s, bottom: 22 * s, trailing: 10 * s))
        .frame(width: width, height: height)
        .background(RoundedRectangle(cornerRadius: 14 * s).fill(Hardware.caseColor)
            .shadow(color: .black.opacity(0.26), radius: 14 * s, y: 10 * s))
        .onChange(of: state.reader) { old, new in
            guard new == .docked, old != .docked else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.easeIn(duration: 0.12)) { flash = Color(white: 0.12) }
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.easeOut(duration: 0.15)) { flash = Color(white: 0.96) }
                try? await Task.sleep(for: .milliseconds(160))
                withAnimation(.easeOut(duration: 0.3)) { flash = Hardware.eInk }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.reader == .docked ? "E-reader encaixado" : "E-reader solto")
    }

    @ViewBuilder
    private func docked(_ s: CGFloat) -> some View {
        Text("YGGI").font(.system(size: 9 * s, weight: .semibold)).tracking(1.5 * s).opacity(0.7)
        Text(state.activeHostName ?? "Sem conexão")
            .font(.system(size: 19 * s, weight: .semibold, design: .serif))
            .lineLimit(2)
        if let index = state.activeHost {
            Text("computador \(index + 1) de \(state.hosts.filter(\.paired).count)")
                .font(.system(size: 11 * s, design: .serif)).opacity(0.8)
        }
        Rectangle().fill(Hardware.eInkText.opacity(0.25)).frame(height: 1).padding(.vertical, 4 * s)
        row("Esquerda", state.left.battery.map { "\($0.level)%" } ?? "—", s)
        row("Direita", state.right.battery.map { "\($0.level)%" } ?? "—", s)
        row("Colunas", state.staggerPercent > 0 ? "stagger \(state.staggerPercent)%" : "ortho", s)
        Spacer(minLength: 0)
        Text("encaixado").font(.system(size: 10 * s, design: .serif)).opacity(0.7)
    }

    @ViewBuilder
    private func reading(_ s: CGFloat) -> some View {
        Text("LEITURA").font(.system(size: 9 * s, weight: .semibold)).tracking(1.5 * s).opacity(0.7)
        Capsule().fill(Hardware.eInkText.opacity(0.55)).frame(width: width * 0.45, height: 6 * s)
        ForEach([1.0, 0.94, 0.98, 0.88, 0.96, 0.6, 1.0, 0.92, 0.97], id: \.self) { w in
            Capsule().fill(Hardware.eInkText.opacity(0.22)).frame(width: (width - 44 * s) * w, height: 4 * s)
        }
        Spacer(minLength: 0)
        Text("solto · modo leitura").font(.system(size: 10 * s, design: .serif)).opacity(0.7)
    }

    private func row(_ label: String, _ value: String, _ s: CGFloat) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
        .font(.system(size: 12 * s, design: .serif))
    }
}
