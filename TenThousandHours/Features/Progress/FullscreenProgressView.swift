import SwiftUI

struct FullscreenProgressView: View {
    @Environment(TrackingStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var scrollState = ProgressGridScrollState()

    var body: some View {
        let display = ProgressDisplay(progress: store.progress)

        GeometryReader { proxy in
            let layout = ProgressGridLayout(
                availableWidth: proxy.size.width - 2 * Layout.horizontalPadding,
                style: .fullscreen
            )
            ScrollViewReader { reader in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: Layout.lineToGridSpacing) {
                        progressLine(display)
                        ProgressGridRows(layout: layout, filledDotCount: display.filledDotCount)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(verbatim: display.accessibilitySummary))
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.top, Layout.contentTopPadding)
                    .padding(.bottom, Layout.contentBottomPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .modifier(ClipBelowSystemScrollEdgeEffect())
                .onAppear {
                    scrollToProgressIfNeeded(layout: layout, size: proxy.size, filledDotCount: display.filledDotCount, reader: reader)
                }
                .onChange(of: layout) { _, newLayout in
                    scrollToProgressIfNeeded(layout: newLayout, size: proxy.size, filledDotCount: display.filledDotCount, reader: reader)
                }
            }
        }
        .background(AppColor.background)
        .overlay(alignment: .topTrailing) {
            CloseButton { dismiss() }
                .padding(.top, Layout.closeButtonTopPadding)
                .padding(.trailing, Layout.closeButtonTrailingPadding)
        }
        .task(id: store.isRunning && scenePhase == .active) {
            guard store.isRunning, scenePhase == .active else { return }
            await store.keepRefreshing()
        }
    }

    private func progressLine(_ display: ProgressDisplay) -> some View {
        HStack(spacing: Layout.progressLineSpacing) {
            Text(verbatim: display.percentText)
                .foregroundStyle(AppColor.primaryText)
            Text(verbatim: display.hoursText)
                .foregroundStyle(AppColor.secondaryText)
        }
        .appTextStyle(.caption)
        .lineLimit(1)
        .frame(height: Layout.progressLineHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("fullscreen.progressLine")
    }

    private func scrollToProgressIfNeeded(
        layout: ProgressGridLayout,
        size: CGSize,
        filledDotCount: Int,
        reader: ScrollViewProxy
    ) {
        guard size.width > 0,
              let target = scrollState.targetIfNeeded(
                  filledDotCount: filledDotCount,
                  layout: layout,
                  viewportHeight: size.height,
                  contentAboveGrid: Layout.contentAboveGrid
              )
        else { return }
        guard !target.isContentStart else { return }
        Task { @MainActor in
            reader.scrollTo(target.row, anchor: target.anchor.unitPoint)
        }
    }
}

private extension FullscreenProgressView {
    enum Layout {
        static let horizontalPadding: CGFloat = 27
        static let contentTopPadding: CGFloat = 66
        static let contentBottomPadding: CGFloat = 24
        static let lineToGridSpacing: CGFloat = 12
        static let progressLineSpacing: CGFloat = 6
        static let progressLineHeight: CGFloat = 18
        static let contentAboveGrid = contentTopPadding + progressLineHeight + lineToGridSpacing
        static let closeButtonTopPadding: CGFloat = 6
        static let closeButtonTrailingPadding: CGFloat = 16
    }
}

private struct ClipBelowSystemScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.clipped()
        }
    }
}

private struct CloseButton: View {
    let action: () -> Void

    private let diameter: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.primaryText)
                .frame(width: diameter, height: diameter)
                .modifier(CloseButtonBackground())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Закрыть"))
    }
}

private struct CloseButtonBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(Circle().fill(AppColor.background.opacity(0.62)))
                .overlay(Circle().strokeBorder(AppColor.primaryText.opacity(0.06), lineWidth: 0.5))
                .shadow(color: AppColor.primaryText.opacity(0.08), radius: 6, y: 6)
        }
    }
}

#Preview {
    FullscreenProgressView()
        .environment(TrackingStore.preview())
}
