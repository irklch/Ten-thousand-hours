import SwiftUI

struct ProgressDot: View {
    static let defaultDiameter: CGFloat = 8

    let isActive: Bool
    var diameter: CGFloat = Self.defaultDiameter

    static func color(isActive: Bool) -> Color {
        isActive ? AppColor.activeDot : AppColor.inactiveDot
    }

    var body: some View {
        Circle()
            .fill(Self.color(isActive: isActive))
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: AppSpacing.small) {
        ProgressDot(isActive: true)
        ProgressDot(isActive: false)
        ProgressDot(isActive: true, diameter: 6)
        ProgressDot(isActive: false, diameter: 6)
    }
    .padding()
}
