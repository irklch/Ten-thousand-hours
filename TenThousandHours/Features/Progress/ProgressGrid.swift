import SwiftUI

struct ProgressGrid: View {
    let filledDotCount: Int
    var accessibilitySummary: String = ""
    let onOpen: () -> Void

    @State private var scrollState = ProgressGridScrollState()

    var body: some View {
        GeometryReader { proxy in
            let layout = ProgressGridLayout(availableWidth: proxy.size.width, style: .home)
            ScrollViewReader { reader in
                ScrollView(.vertical) {
                    ProgressGridRows(layout: layout, filledDotCount: filledDotCount)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .clipped()
                .onAppear {
                    scrollToProgressIfNeeded(layout: layout, size: proxy.size, reader: reader)
                }
                .onChange(of: layout) { _, newLayout in
                    scrollToProgressIfNeeded(layout: newLayout, size: proxy.size, reader: reader)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilitySummary))
        .accessibilityHint(Text("Открывает полноэкранный прогресс"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onOpen() }
        .accessibilityIdentifier("home.progressGrid")
    }

    private func scrollToProgressIfNeeded(layout: ProgressGridLayout, size: CGSize, reader: ScrollViewProxy) {
        guard size.width > 0,
              let target = scrollState.targetIfNeeded(
                  filledDotCount: filledDotCount,
                  layout: layout,
                  viewportHeight: size.height
              )
        else { return }
        guard !target.isContentStart else { return }
        Task { @MainActor in
            reader.scrollTo(target.row, anchor: target.anchor.unitPoint)
        }
    }
}

#Preview {
    ProgressGrid(filledDotCount: 2_450) {}
        .frame(width: 346, height: 339)
        .padding()
}
