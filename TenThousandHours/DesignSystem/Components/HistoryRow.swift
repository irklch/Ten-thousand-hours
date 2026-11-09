import SwiftUI

struct HistoryRow: View {
    let duration: String
    let date: String

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text(duration)
                    .appTextStyle(.progress)
                    .foregroundStyle(AppColor.primaryText)
                Text(date)
                    .appTextStyle(.caption)
                    .foregroundStyle(AppColor.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, AppSpacing.medium)
        .padding(.trailing, AppSpacing.large)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColor.separator)
                .frame(height: 0.5)
        }
        .padding(.leading, AppSpacing.large)
        .background(AppColor.background)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 0) {
        HistoryRow(duration: "2 ч 34 мин", date: "9 ноября 2026 · 10:30")
        HistoryRow(duration: "1 ч 45 мин", date: "8 ноября 2026 · 14:15")
    }
}
