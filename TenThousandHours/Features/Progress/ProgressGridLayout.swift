import CoreGraphics

nonisolated struct ProgressGridStyle: Equatable, Sendable {
    let dotDiameter: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    static let home = ProgressGridStyle(dotDiameter: 6, horizontalSpacing: 3, verticalSpacing: 3)
    static let fullscreen = ProgressGridStyle(dotDiameter: 7, horizontalSpacing: 4, verticalSpacing: 4)
}

nonisolated struct ProgressGridLayout: Equatable, Sendable {
    static let totalDots = ProgressGoal.targetHours

    let style: ProgressGridStyle
    let columns: Int

    init(availableWidth: CGFloat, style: ProgressGridStyle) {
        self.style = style
        let pitch = style.dotDiameter + style.horizontalSpacing
        let fitting = Int(((max(0, availableWidth) + style.horizontalSpacing) / pitch).rounded(.down))
        self.columns = min(max(1, fitting), Self.totalDots)
    }

    var rows: Int {
        (Self.totalDots + columns - 1) / columns
    }

    var contentWidth: CGFloat {
        CGFloat(columns) * style.dotDiameter + CGFloat(columns - 1) * style.horizontalSpacing
    }

    var rowHeight: CGFloat {
        style.dotDiameter
    }

    var contentHeight: CGFloat {
        CGFloat(rows) * style.dotDiameter + CGFloat(rows - 1) * style.verticalSpacing
    }

    func bottom(ofRow row: Int) -> CGFloat {
        CGFloat(row + 1) * style.dotDiameter + CGFloat(row) * style.verticalSpacing
    }

    func dotCount(inRow row: Int) -> Int {
        guard row >= 0, row < rows else { return 0 }
        return min(columns, Self.totalDots - row * columns)
    }

    func filledDotCount(inRow row: Int, totalFilled: Int) -> Int {
        let filled = Self.clampedFilledCount(totalFilled)
        return min(max(0, filled - row * columns), dotCount(inRow: row))
    }

    func row(ofDot index: Int) -> Int {
        min(max(0, index), Self.totalDots - 1) / columns
    }

    static func clampedFilledCount(_ value: Int) -> Int {
        min(max(0, value), totalDots)
    }
}
