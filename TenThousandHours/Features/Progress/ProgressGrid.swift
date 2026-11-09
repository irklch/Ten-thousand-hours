import SwiftUI

struct ProgressGrid: View {
    let filledDotCount: Int

    private let minimumSpacing: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let layout = GridLayout(size: proxy.size, dotSize: ProgressDot.diameter, minimumSpacing: minimumSpacing)
            VStack(alignment: .leading, spacing: layout.spacing) {
                ForEach(0..<layout.rows, id: \.self) { row in
                    HStack(spacing: layout.spacing) {
                        ForEach(0..<layout.columns, id: \.self) { column in
                            ProgressDot(isActive: row * layout.columns + column < filledDotCount)
                        }
                    }
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private struct GridLayout {
    let columns: Int
    let rows: Int
    let spacing: CGFloat

    init(size: CGSize, dotSize: CGFloat, minimumSpacing: CGFloat) {
        let pitch = dotSize + minimumSpacing
        let columns = max(1, Int((size.width + minimumSpacing) / pitch))
        let spacing = columns > 1
            ? (size.width - CGFloat(columns) * dotSize) / CGFloat(columns - 1)
            : minimumSpacing
        let rowLimit = Int((size.height + spacing) / (dotSize + spacing))
        let neededRows = (ProgressGoal.targetHours + columns - 1) / columns

        self.columns = columns
        self.rows = max(0, min(rowLimit, neededRows))
        self.spacing = spacing
    }
}

#Preview {
    ProgressGrid(filledDotCount: 113)
        .frame(width: 346, height: 333)
        .padding()
}
