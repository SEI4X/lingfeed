import SwiftUI

struct SessionSummaryView: View {
    let summary: SessionSummary
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "02 · \(AppLocalization.string("summary.eyebrow"))")
                    .font(AppTheme.eyebrowFont)
                    .foregroundStyle(AppTheme.accent)
                Text(verbatim: AppLocalization.string("summary.title"))
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(verbatim: AppLocalization.string("summary.subtitle"))
                    .font(.body)
                    .foregroundStyle(AppTheme.muted)
            }

            HStack(spacing: 12) {
                SummaryMetric(titleKey: "summary.correct", value: "\(summary.stats.correct)")
                SummaryMetric(titleKey: "summary.fixed", value: "\(summary.stats.fixed)")
                SummaryMetric(titleKey: "summary.skipped", value: "\(summary.stats.skipped)")
            }

            ProgressView(value: summary.stats.accuracy)
                .tint(AppTheme.accent)
            Text(verbatim: AppLocalization.formatted("summary.accuracy", Int(summary.stats.accuracy * 100)))
                .font(AppTheme.bodyMonoFont)
                .foregroundStyle(AppTheme.muted)

            Button {
                dismiss()
                onContinue()
            } label: {
                Text(verbatim: AppLocalization.string("summary.continue"))
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }
}

private struct SummaryMetric: View {
    let titleKey: String
    let value: String

    var body: some View {
        VStack(spacing: 7) {
            Text(value)
                .font(.system(size: 34, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(AppTheme.ink)
            Text(verbatim: AppLocalization.string(titleKey))
                .font(AppTheme.eyebrowFont)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .appSurface(radius: 22, shadow: true)
    }
}
