import SwiftUI

enum AppTextStyle: CaseIterable {
    case largeTimer
    case progress
    case body
    case caption

    var size: CGFloat {
        switch self {
        case .largeTimer: 80
        case .progress: 22
        case .body: 17
        case .caption: 13
        }
    }

    var weight: Font.Weight {
        switch self {
        case .largeTimer: .light
        case .progress: .semibold
        case .body, .caption: .regular
        }
    }

    var tracking: CGFloat {
        switch self {
        case .largeTimer: -1.5
        case .progress, .body: -0.4
        case .caption: 0
        }
    }

    var dynamicTypeReference: Font.TextStyle {
        switch self {
        case .largeTimer: .largeTitle
        case .progress: .title2
        case .body: .body
        case .caption: .footnote
        }
    }
}

private struct AppTextStyleModifier: ViewModifier {
    let style: AppTextStyle
    @ScaledMetric private var size: CGFloat

    init(style: AppTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.dynamicTypeReference)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: style.weight))
            .tracking(style.tracking)
    }
}

extension View {
    func appTextStyle(_ style: AppTextStyle) -> some View {
        modifier(AppTextStyleModifier(style: style))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: AppSpacing.medium) {
        Text(verbatim: "00:00").appTextStyle(.largeTimer)
        Text(verbatim: "12,45%").appTextStyle(.progress)
        Text(verbatim: "Body").appTextStyle(.body)
        Text(verbatim: "1 245 / 10 000 ч").appTextStyle(.caption)
    }
    .foregroundStyle(AppColor.primaryText)
}
