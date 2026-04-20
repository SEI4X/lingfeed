import SwiftUI

struct OnboardingView: View {
    @State private var selectedNativeCode: String
    @State private var selectedTargetCode: String
    @State private var selectedGoals: [LearningGoal]
    @State private var step: Step = .native

    let onComplete: (LanguageOption, LanguageOption, [LearningGoal]) -> Void

    init(
        selectedNativeLanguageCode: String,
        selectedTargetLanguageCode: String,
        selectedLearningGoals: [LearningGoal] = LearningGoal.defaultGoals,
        onComplete: @escaping (LanguageOption, LanguageOption, [LearningGoal]) -> Void
    ) {
        _selectedNativeCode = State(initialValue: selectedNativeLanguageCode)
        _selectedTargetCode = State(initialValue: selectedTargetLanguageCode)
        _selectedGoals = State(initialValue: selectedLearningGoals.isEmpty ? LearningGoal.defaultGoals : selectedLearningGoals)
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 22) {
                topRuler

                VStack(alignment: .leading, spacing: 14) {
                    Text(verbatim: "\(stepNumber) · \(localized("onboarding.step"))")
                        .font(AppTheme.eyebrowFont)
                        .foregroundStyle(AppTheme.accent)
                    Text(verbatim: localized(titleKey))
                        .font(.system(size: 34, weight: .semibold))
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(AppTheme.ink)
                    Text(verbatim: localized(subtitleKey))
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                }

                ScrollView {
                    VStack(spacing: 10) {
                        if step == .goals {
                            ForEach(LearningGoal.allCases, id: \.self) { goal in
                                goalButton(goal)
                            }
                        } else {
                            ForEach(languages) { language in
                                languageButton(language)
                            }
                        }
                    }
                }

                Button(step == .goals ? localized("onboarding.start") : localized("onboarding.next")) {
                    if step == .native {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            step = .target
                        }
                    } else if step == .target {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            step = .goals
                        }
                    } else {
                        onComplete(
                            LanguageOption.option(for: selectedNativeCode),
                            LanguageOption.option(for: selectedTargetCode),
                            selectedGoals
                        )
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
            .frame(maxWidth: 560)
        }
    }

    private enum Step {
        case native
        case target
        case goals
    }

    private var languages: [LanguageOption] {
        switch step {
        case .native:
            LanguageOption.nativeChoices
        case .target, .goals:
            LanguageOption.learningChoices
        }
    }

    private var selectedCode: String {
        get {
            switch step {
            case .native:
                selectedNativeCode
            case .target:
                selectedTargetCode
            case .goals:
                selectedTargetCode
            }
        }
        nonmutating set {
            switch step {
            case .native:
                selectedNativeCode = newValue
            case .target:
                selectedTargetCode = newValue
            case .goals:
                selectedTargetCode = newValue
            }
        }
    }

    private var titleKey: String {
        switch step {
        case .native: "onboarding.nativeTitle"
        case .target: "onboarding.targetTitle"
        case .goals: "onboarding.goalsTitle"
        }
    }

    private var subtitleKey: String {
        switch step {
        case .native: "onboarding.nativeSubtitle"
        case .target: "onboarding.targetSubtitle"
        case .goals: "onboarding.goalsSubtitle"
        }
    }

    private var stepNumber: String {
        switch step {
        case .native: "01"
        case .target: "02"
        case .goals: "03"
        }
    }

    private var localization: AppLocalization {
        AppLocalization(languageCode: step == .native ? LanguageOption.supportedCode() : selectedNativeCode)
    }

    private func localized(_ key: String) -> String {
        localization.string(key)
    }

    private var topRuler: some View {
        HStack(spacing: 8) {
            Button {
                guard step != .native else { return }
                withAnimation(.easeInOut(duration: 0.24)) {
                    step = step == .goals ? .target : .native
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(step != .native ? AppTheme.ink : AppTheme.muted.opacity(0.45))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(step == .native)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= stepIndex ? AppTheme.ink : AppTheme.hairline.opacity(0.55))
                        .frame(height: 3)
                }
            }
            Text("\(stepNumber) / 03")
                .font(AppTheme.eyebrowFont)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.top, 8)
    }

    private var stepIndex: Int {
        switch step {
        case .native: 0
        case .target: 1
        case .goals: 2
        }
    }

    private func languageButton(_ language: LanguageOption) -> some View {
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

    private func goalButton(_ goal: LearningGoal) -> some View {
        let isSelected = selectedGoals.contains(goal)
        return Button {
            toggle(goal)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: localized(goal.titleKey))
                        .font(.system(size: 18, weight: .semibold))
                    Text(verbatim: localized(goal.subtitleKey))
                        .font(AppTheme.bodyMonoFont)
                        .opacity(0.72)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(isSelected ? AppTheme.actionText : AppTheme.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 17)
            .background(
                isSelected ? AppTheme.action : AppTheme.surface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.action : AppTheme.hairline.opacity(0.6), lineWidth: 0.8)
            )
            .shadow(color: isSelected ? .black.opacity(0.10) : .clear, radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ goal: LearningGoal) {
        if selectedGoals.contains(goal) {
            guard selectedGoals.count > 1 else { return }
            selectedGoals.removeAll { $0 == goal }
        } else {
            selectedGoals.append(goal)
        }
    }

    private func languageDisplayName(_ language: LanguageOption) -> String {
        language.nativeName
    }

    private func languageSubtitle(_ language: LanguageOption) -> String {
        switch language.code {
        case "es": "\(localized(language.titleKey)) · 480M \(localized("language.speakers"))"
        case "en": "\(localized(language.titleKey)) · 1.5B \(localized("language.speakers"))"
        case "de": "\(localized(language.titleKey)) · 130M \(localized("language.speakers"))"
        case "fr": "\(localized(language.titleKey)) · 300M \(localized("language.speakers"))"
        case "ja": "\(localized(language.titleKey)) · 125M \(localized("language.speakers"))"
        case "it": "\(localized(language.titleKey)) · 67M \(localized("language.speakers"))"
        case "pt": "\(localized(language.titleKey)) · 260M \(localized("language.speakers"))"
        case "ko": "\(localized(language.titleKey)) · 80M \(localized("language.speakers"))"
        case "zh-Hans": "\(localized(language.titleKey)) · 1.1B \(localized("language.speakers"))"
        case "ru": "\(localized(language.titleKey)) · 258M \(localized("language.speakers"))"
        default: localized(language.titleKey)
        }
    }
}
