import SwiftUI

struct ProgressGridRows: View {
    let layout: ProgressGridLayout
    let filledDotCount: Int

    var body: some View {
        LazyVStack(alignment: .leading, spacing: layout.style.verticalSpacing) {
            ForEach(0..<layout.rows, id: \.self) { row in
                ProgressGridRow(
                    dotCount: layout.dotCount(inRow: row),
                    filledCount: layout.filledDotCount(inRow: row, totalFilled: filledDotCount),
                    style: layout.style
                )
                .equatable()
                .frame(width: layout.contentWidth, height: layout.rowHeight, alignment: .leading)
                .id(row)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ProgressGridRow: View, Equatable {
    let dotCount: Int
    let filledCount: Int
    let style: ProgressGridStyle

    var body: some View {
        Canvas { context, _ in
            var filled = Path()
            var empty = Path()
            let pitch = style.dotDiameter + style.horizontalSpacing
            for index in 0..<dotCount {
                let rect = CGRect(x: CGFloat(index) * pitch, y: 0, width: style.dotDiameter, height: style.dotDiameter)
                if index < filledCount {
                    filled.addEllipse(in: rect)
                } else {
                    empty.addEllipse(in: rect)
                }
            }
            context.fill(filled, with: .color(ProgressDot.color(isActive: true)))
            context.fill(empty, with: .color(ProgressDot.color(isActive: false)))
        }
    }
}

extension ProgressGridScrollTarget.Anchor {
    var unitPoint: UnitPoint {
        switch self {
        case .top: .top
        case .center: .center
        case .bottom: .bottom
        }
    }
}
