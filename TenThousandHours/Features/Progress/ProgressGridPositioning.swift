import CoreGraphics

nonisolated struct ProgressGridScrollTarget: Equatable, Sendable {
    enum Anchor: Equatable, Sendable {
        case top
        case center
        case bottom
    }

    let row: Int
    let anchor: Anchor

    static let contentStart = ProgressGridScrollTarget(row: 0, anchor: .top)

    var isContentStart: Bool { self == Self.contentStart }
}

nonisolated enum ProgressGridPositioning {
    static func boundaryRow(filledDotCount: Int, layout: ProgressGridLayout) -> Int {
        let filled = ProgressGridLayout.clampedFilledCount(filledDotCount)
        guard filled < ProgressGridLayout.totalDots else { return layout.rows - 1 }
        return layout.row(ofDot: filled)
    }

    static func initialTarget(
        filledDotCount: Int,
        layout: ProgressGridLayout,
        viewportHeight: CGFloat,
        contentAboveGrid: CGFloat = 0
    ) -> ProgressGridScrollTarget {
        let filled = ProgressGridLayout.clampedFilledCount(filledDotCount)
        let start = ProgressGridScrollTarget.contentStart
        if filled == 0 {
            return start
        }
        if filled == ProgressGridLayout.totalDots {
            return ProgressGridScrollTarget(row: layout.rows - 1, anchor: .bottom)
        }
        let row = boundaryRow(filledDotCount: filled, layout: layout)
        if contentAboveGrid + layout.bottom(ofRow: row) <= viewportHeight {
            return start
        }
        return ProgressGridScrollTarget(row: row, anchor: .center)
    }
}

nonisolated struct ProgressGridScrollState: Equatable, Sendable {
    private(set) var hasPositioned = false

    mutating func targetIfNeeded(
        filledDotCount: Int,
        layout: ProgressGridLayout,
        viewportHeight: CGFloat,
        contentAboveGrid: CGFloat = 0
    ) -> ProgressGridScrollTarget? {
        guard !hasPositioned, viewportHeight > 0 else { return nil }
        hasPositioned = true
        return ProgressGridPositioning.initialTarget(
            filledDotCount: filledDotCount,
            layout: layout,
            viewportHeight: viewportHeight,
            contentAboveGrid: contentAboveGrid
        )
    }
}
