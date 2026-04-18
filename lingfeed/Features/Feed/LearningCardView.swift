import SwiftUI

struct LearningCardView: View {
    let card: LearningCard
    let feedback: FeedbackState?
    let isBusy: Bool
    let onSubmit: (String) -> Void
    let onContinue: () -> Void
    let onTooEasy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            PromptContentView(card: card)

            Spacer(minLength: 10)

            if let feedback {
                FeedbackPanel(feedback: feedback, onContinue: onContinue)
            } else {
                CardInteractionView(card: card, isBusy: isBusy, onSubmit: onSubmit)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(maxWidth: 620, maxHeight: .infinity)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(.white.opacity(0.44), lineWidth: 0.8)
                .blendMode(.overlay)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .strokeBorder(borderColor.opacity(feedback == nil ? 0.58 : 0.9), lineWidth: feedback == nil ? 0.8 : 2)
        )
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 14)
        .accessibilityIdentifier("learning-card")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: L10n.string(card.type.titleKey))
                    .font(AppTheme.eyebrowFont)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.muted)
                Text(verbatim: card.context)
                    .font(AppTheme.bodyMonoFont)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Menu {
                Button(action: onTooEasy) {
                    Label {
                        Text(verbatim: L10n.string("card.action.tooEasy"))
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.muted)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.recessed.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(isBusy)
            .accessibilityLabel(L10n.string("card.action.tooEasy"))
        }
    }

    private var cardBackground: Color {
        switch feedback {
        case .success:
            AppTheme.success.opacity(0.10)
        case .error:
            AppTheme.danger.opacity(0.08)
        case nil:
            AppTheme.surface
        }
    }

    private var borderColor: Color {
        switch feedback {
        case .success: AppTheme.success
        case .error: AppTheme.danger
        case nil: AppTheme.hairline
        }
    }

    private var iconColor: Color {
        switch card.type {
        case .translate: AppTheme.accent
        case .multipleChoice: AppTheme.success
        case .fillGap: AppTheme.accent
        case .reorder: AppTheme.ink
        case .fixMistake: AppTheme.danger
        case .chat: AppTheme.success
        }
    }

    private var iconName: String {
        switch card.type {
        case .translate: "character.book.closed"
        case .multipleChoice: "checklist"
        case .fillGap: "text.cursor"
        case .reorder: "arrow.left.arrow.right"
        case .fixMistake: "pencil.and.scribble"
        case .chat: "message"
        }
    }
}

private struct PromptContentView: View {
    let card: LearningCard

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(verbatim: instruction)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.muted)

            if card.type == .fillGap, let blankRange = bodyText.range(of: "___") {
                FillGapPrompt(prefix: String(bodyText[..<blankRange.lowerBound]), suffix: String(bodyText[blankRange.upperBound...]))
            } else {
                Text(verbatim: bodyText)
                    .font(.system(size: 34, weight: .semibold, design: .default))
                    .minimumScaleFactor(0.72)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(AppTheme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var instruction: String {
        if let colonIndex = card.prompt.firstIndex(of: ":") {
            return String(card.prompt[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        switch card.type {
        case .translate:
            return L10n.string("card.instruction.translate")
        case .multipleChoice:
            return L10n.string("card.instruction.multipleChoice")
        case .fillGap:
            return L10n.string("card.instruction.fillGap")
        case .reorder:
            return L10n.string("card.instruction.reorder")
        case .fixMistake:
            return L10n.string("card.instruction.fixMistake")
        case .chat:
            return L10n.string("card.instruction.chat")
        }
    }

    private var bodyText: String {
        if let colonIndex = card.prompt.firstIndex(of: ":") {
            return String(card.prompt[card.prompt.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return card.prompt
    }
}

private struct FillGapPrompt: View {
    let prefix: String
    let suffix: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: prefix)
            Text(verbatim: "___")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 22)
                .padding(.vertical, 7)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.accent.opacity(0.82), lineWidth: 1.4)
                )
            Text(verbatim: suffix)
        }
        .font(.system(size: 34, weight: .semibold, design: .default))
        .foregroundStyle(AppTheme.ink)
        .minimumScaleFactor(0.68)
        .lineLimit(4)
    }
}

private struct FeedbackPanel: View {
    let feedback: FeedbackState
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch feedback {
            case .success:
                Label {
                    Text(verbatim: L10n.string("feedback.success"))
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.success)
            case .error(let userAnswer, let correctAnswer, let explanation):
                Label {
                    Text(verbatim: L10n.string("feedback.tryAgain"))
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.danger)
                answerCompareRow(titleKey: "feedback.yourAnswer", value: userAnswer, color: AppTheme.danger)
                Text(verbatim: "\(L10n.string("feedback.correctAnswer")) \(correctAnswer)")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(verbatim: explanation)
                    .font(.body)
                    .foregroundStyle(AppTheme.muted)
                Button(action: onContinue) {
                    Text(verbatim: L10n.string("action.continue"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(fill: AppTheme.recessed.opacity(0.72), border: AppTheme.hairline, radius: 18)
    }

    private func answerCompareRow(titleKey: String, value: String, color: Color) -> some View {
        Text(verbatim: "\(L10n.string(titleKey)) \(value)")
            .font(.body.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}
