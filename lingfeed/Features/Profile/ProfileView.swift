import SwiftUI

struct ProfileView: View {
    let profile: UserProfile
    @Binding var nativeLanguageCode: String
    let targetLanguageCode: String
    @Binding var notificationsEnabled: Bool
    let onChangeLanguage: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("СЕРИЯ · STREAK")
                            .font(AppTheme.eyebrowFont)
                            .foregroundStyle(AppTheme.accent)
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text("\(max(profile.streak, 1))")
                                .font(.system(size: 64, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.ink)
                            Text(verbatim: L10n.string("profile.daysInRow"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.muted)
                        }
                    }

                    StreakBars(activeDays: max(profile.streak, 1))

                    HStack(spacing: 10) {
                        MetricTile(titleKey: "profile.cards", value: "\(profile.totalLearned)", caption: "+32 \(L10n.string("profile.today"))")
                        MetricTile(titleKey: "profile.words", value: "\(profile.totalLearned / 2)", caption: "+6 \(L10n.string("profile.new"))")
                    }

                    HStack(spacing: 10) {
                        MetricTile(titleKey: "profile.grammar", value: "38", caption: "Subjuntivo +1")
                        MetricTile(titleKey: "profile.time", value: "14", caption: "≈8 \(L10n.string("profile.minDay"))")
                    }

                    AccuracyCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(verbatim: L10n.string("profile.weakTopics").uppercased())
                            .font(AppTheme.eyebrowFont)
                            .foregroundStyle(AppTheme.muted)
                        ForEach(profile.weakTopics, id: \.self) { topic in
                            HStack {
                                Text(topic)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Text("5.4%")
                                    .font(AppTheme.bodyMonoFont)
                                    .foregroundStyle(AppTheme.danger)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(18)
                    .appSurface(radius: 22, shadow: true)

                    Button {
                        dismiss()
                        onChangeLanguage()
                    } label: {
                        Text(verbatim: L10n.string("profile.changeLanguage"))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle(L10n.string("profile.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView(
                            nativeLanguageCode: $nativeLanguageCode,
                            targetLanguageCode: targetLanguageCode,
                            notificationsEnabled: $notificationsEnabled
                        ) {
                            dismiss()
                            onChangeLanguage()
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L10n.string("settings.title"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: L10n.string("action.done"))
                    }
                }
            }
        }
    }
}

private struct SettingsView: View {
    @Binding var nativeLanguageCode: String
    let targetLanguageCode: String
    @Binding var notificationsEnabled: Bool
    let onChangeLearningLanguage: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsLanguagePicker(
                    titleKey: "settings.nativeLanguage",
                    selectedCode: $nativeLanguageCode
                )

                SettingsLearningLanguageRow(
                    targetLanguageCode: targetLanguageCode,
                    onChange: onChangeLearningLanguage
                )

                SettingsToggleRow(
                    isOn: $notificationsEnabled,
                    titleKey: "settings.notifications",
                    captionKey: "settings.notificationsCaption"
                )
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle(L10n.string("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsLanguagePicker: View {
    let titleKey: String
    @Binding var selectedCode: String

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemName: "person.text.rectangle")
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: L10n.string(titleKey))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(verbatim: languageDisplayName(LanguageOption.option(for: selectedCode)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Picker(L10n.string(titleKey), selection: $selectedCode) {
                ForEach(LanguageOption.all) { language in
                    Text(verbatim: languageDisplayName(language))
                        .tag(language.code)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.ink)
        }
        .padding(16)
        .appSurface(radius: 22, shadow: true)
    }
}

private struct SettingsLearningLanguageRow: View {
    let targetLanguageCode: String
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemName: "character.book.closed")
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: L10n.string("settings.learningLanguage"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(verbatim: languageDisplayName(LanguageOption.option(for: targetLanguageCode)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Button(action: onChange) {
                Text(verbatim: L10n.string("settings.changeLearningLanguage"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)
        }
        .padding(16)
        .appSurface(radius: 22, shadow: true)
    }
}

private struct SettingsToggleRow: View {
    @Binding var isOn: Bool
    let titleKey: String
    let captionKey: String

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemName: "bell.badge")
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: L10n.string(titleKey))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(verbatim: L10n.string(captionKey))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.accent)
        }
        .padding(16)
        .appSurface(radius: 22, shadow: true)
    }
}

private struct SettingsIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.accent)
            .frame(width: 34, height: 34)
            .background(AppTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MetricTile: View {
    let titleKey: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: L10n.string(titleKey))
                .font(AppTheme.eyebrowFont)
                .foregroundStyle(AppTheme.muted)
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 30, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ink)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(radius: 22, shadow: true)
    }
}

private func languageDisplayName(_ language: LanguageOption) -> String {
    L10n.string(language.titleKey)
}

private struct StreakBars: View {
    let activeDays: Int
    private let days = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(days.indices, id: \.self) { index in
                VStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(index < min(activeDays, days.count) ? AppTheme.ink : AppTheme.hairline.opacity(0.45))
                        .frame(height: 36)
                    Text(days[index])
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
    }
}

private struct AccuracyCard: View {
    private let points: [CGFloat] = [0.1, 0.14, 0.28, 0.23, 0.36, 0.33, 0.47, 0.43, 0.52, 0.49, 0.58, 0.64, 0.57, 0.69]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ТОЧНОСТЬ · 14 ДНЕЙ")
                    .font(AppTheme.eyebrowFont)
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Text("↗ +9%")
                    .font(AppTheme.bodyMonoFont)
                    .foregroundStyle(AppTheme.success)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("92")
                    .font(.system(size: 44, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ink)
                Text("%")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppTheme.ink)
                Text(verbatim: L10n.string("profile.today"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .padding(.leading, 6)
            }

            MiniLineChart(points: points)
                .frame(height: 72)
        }
        .padding(18)
        .appSurface(radius: 22, shadow: true)
    }
}

private struct MiniLineChart: View {
    let points: [CGFloat]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let step = size.width / CGFloat(max(points.count - 1, 1))
            Path { path in
                for index in points.indices {
                    let x = CGFloat(index) * step
                    let y = size.height - (points[index] * size.height)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                for index in points.indices {
                    let x = CGFloat(index) * step
                    let y = size.height - (points[index] * size.height)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
            }
            .fill(AppTheme.accent.opacity(0.10))
        }
    }
}
