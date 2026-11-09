import SwiftUI

struct ProgressDot: View {
    static let diameter: CGFloat = 8

    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? AppColor.activeDot : AppColor.inactiveDot)
            .frame(width: Self.diameter, height: Self.diameter)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: AppSpacing.small) {
        ProgressDot(isActive: true)
        ProgressDot(isActive: false)
    }
    .padding()
}
