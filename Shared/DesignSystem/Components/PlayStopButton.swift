import SwiftUI

/// Круг Play/Stop из Figma Design System (88 pt, иконка 36 pt). Общий для приложения и виджетов.
struct PlayStopButtonLabel: View {
    enum Appearance {
        /// Чёрный круг с белой иконкой, как в Figma.
        case standard
        /// Для тонированных режимов виджета (iOS 18+): система перекрашивает содержимое в один оттенок,
        /// поэтому иконка вырезается из круга, а не рисуется белым поверх него.
        case monochrome
    }

    let isRunning: Bool
    var appearance: Appearance = .standard

    static let diameter: CGFloat = 88
    private let iconSize: CGFloat = 36

    var body: some View {
        switch appearance {
        case .standard:
            icon
                .foregroundStyle(AppColor.onPrimary)
                .frame(width: Self.diameter, height: Self.diameter)
                .background(
                    Circle().fill(
                        AppColor.primaryText
                            .shadow(.inner(color: .white.opacity(0.22), radius: 0.5, y: 1))
                    )
                )
                .shadow(color: .black.opacity(0.14), radius: 6, y: 8)
                .contentShape(Circle())
        case .monochrome:
            Circle()
                .frame(width: Self.diameter, height: Self.diameter)
                .overlay { icon.blendMode(.destinationOut) }
                .compositingGroup()
                .contentShape(Circle())
        }
    }

    private var icon: some View {
        Image(systemName: isRunning ? "stop.fill" : "play.fill")
            .font(.system(size: iconSize * 0.75, weight: .bold))
            .frame(width: iconSize, height: iconSize)
    }
}

struct PlayStopButton: View {
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PlayStopButtonLabel(isRunning: isRunning)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRunning ? Text("Остановить") : Text("Начать"))
    }
}

#Preview {
    VStack(spacing: AppSpacing.large) {
        HStack(spacing: AppSpacing.large) {
            PlayStopButton(isRunning: false) {}
            PlayStopButton(isRunning: true) {}
        }
        HStack(spacing: AppSpacing.large) {
            PlayStopButtonLabel(isRunning: false, appearance: .monochrome)
            PlayStopButtonLabel(isRunning: true, appearance: .monochrome)
        }
    }
    .padding()
}
