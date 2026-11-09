import SwiftUI

struct PlayStopButton: View {
    let isRunning: Bool
    let action: () -> Void

    private let diameter: CGFloat = 88
    private let iconSize: CGFloat = 36

    var body: some View {
        Button(action: action) {
            Image(systemName: isRunning ? "stop.fill" : "play.fill")
                .font(.system(size: iconSize * 0.75, weight: .bold))
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(AppColor.onPrimary)
                .frame(width: diameter, height: diameter)
                .background(
                    Circle().fill(
                        AppColor.primaryText
                            .shadow(.inner(color: .white.opacity(0.22), radius: 0.5, y: 1))
                    )
                )
                .shadow(color: .black.opacity(0.14), radius: 6, y: 8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRunning ? Text("Остановить") : Text("Начать"))
    }
}

#Preview {
    HStack(spacing: AppSpacing.large) {
        PlayStopButton(isRunning: false) {}
        PlayStopButton(isRunning: true) {}
    }
    .padding()
}
