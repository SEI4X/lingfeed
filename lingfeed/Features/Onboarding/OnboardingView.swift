import SwiftUI

struct OnboardingView: View {
    @State private var selectedCode: String

    let onComplete: (LanguageOption) -> Void

    init(selectedLanguageCode: String, onComplete: @escaping (LanguageOption) -> Void) {
        _selectedCode = State(initialValue: selectedLanguageCode)
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 22) {
                topRuler

                VStack(alignment: .leading, spacing: 14) {
                    Text("01 · \(L10n.string("onboarding.step"))")
                        .font(AppTheme.eyebrowFont)
                        .foregroundStyle(AppTheme.accent)
                    Text(L10n.string("onboarding.title"))
                        .font(.system(size: 34, weight: .semibold))
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(AppTheme.ink)
                    Text(L10n.string("onboarding.subtitle"))
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                }

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(LanguageOption.all) { language in
                            Button {
                                selectedCode = language.code
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(languageDisplayName(language))
                                            .font(.system(size: 18, weight: .semibold))
                                        Text(languageSubtitle(language))
                                            .font(AppTheme.bodyMonoFont)
                                            .opacity(0.72)
                                    }
                                    Spacer()
                                    if selectedCode == language.code {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(selectedCode == language.code ? AppTheme.actionText : AppTheme.ink)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 17)
                                .background(
                                    selectedCode == language.code ? AppTheme.action : AppTheme.surface,
                                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(selectedCode == language.code ? AppTheme.action : AppTheme.hairline.opacity(0.6), lineWidth: 0.8)
                                )
                                .shadow(color: selectedCode == language.code ? .black.opacity(0.10) : .clear, radius: 14, x: 0, y: 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button(L10n.string("onboarding.start")) {
                    onComplete(LanguageOption.option(for: selectedCode))
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
            .frame(maxWidth: 560)
        }
    }

    private var topRuler: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.muted)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index == 0 ? AppTheme.ink : AppTheme.hairline.opacity(0.55))
                        .frame(height: 3)
                }
            }
            Text("01 / 05")
                .font(AppTheme.eyebrowFont)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.top, 8)
    }

    private func languageDisplayName(_ language: LanguageOption) -> String {
        switch language.code {
        case "es": "Español"
        case "en": "English"
        case "de": "Deutsch"
        case "fr": "Français"
        case "ja": "日本語"
        case "it": "Italiano"
        case "pt": "Português"
        case "ko": "한국어"
        case "zh-Hans": "中文"
        case "ru": "Русский"
        default: L10n.string(language.titleKey)
        }
    }

    private func languageSubtitle(_ language: LanguageOption) -> String {
        switch language.code {
        case "es": "\(L10n.string(language.titleKey)) · 480M \(L10n.string("language.speakers"))"
        case "en": "\(L10n.string(language.titleKey)) · 1.5B \(L10n.string("language.speakers"))"
        case "de": "\(L10n.string(language.titleKey)) · 130M \(L10n.string("language.speakers"))"
        case "fr": "\(L10n.string(language.titleKey)) · 300M \(L10n.string("language.speakers"))"
        case "ja": "\(L10n.string(language.titleKey)) · 125M \(L10n.string("language.speakers"))"
        case "it": "\(L10n.string(language.titleKey)) · 67M \(L10n.string("language.speakers"))"
        case "pt": "\(L10n.string(language.titleKey)) · 260M \(L10n.string("language.speakers"))"
        case "ko": "\(L10n.string(language.titleKey)) · 80M \(L10n.string("language.speakers"))"
        case "zh-Hans": "\(L10n.string(language.titleKey)) · 1.1B \(L10n.string("language.speakers"))"
        case "ru": "\(L10n.string(language.titleKey)) · 258M \(L10n.string("language.speakers"))"
        default: L10n.string(language.titleKey)
        }
    }
}
