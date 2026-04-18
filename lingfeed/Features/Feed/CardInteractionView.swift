import SwiftUI

struct CardInteractionView: View {
    let card: LearningCard
    let isBusy: Bool
    let onSubmit: (String) -> Void

    @State private var textAnswer = ""
    @State private var selectedWords: [String] = []

    var body: some View {
        Group {
            switch card.type {
            case .translate:
                textEntry(actionTitleKey: "action.check")
            case .multipleChoice, .fillGap, .chat:
                optionsGrid
            case .reorder:
                reorderView
            case .fixMistake:
                textEntry(actionTitleKey: "action.fix")
                    .onAppear {
                        textAnswer = cleanedFixPrompt
                    }
            }
        }
        .disabled(isBusy)
    }

    private var optionsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            if card.type == .chat {
                ChatTranscript(messages: card.chatMessages)
            }

            ForEach(card.options, id: \.self) { option in
                Button {
                    onSubmit(option)
                } label: {
                    HStack {
                        Text(verbatim: option)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .appSurface(fill: AppTheme.surface, border: AppTheme.hairline, radius: AppTheme.controlRadius)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("option-\(option)")
            }
        }
    }

    private func textEntry(actionTitleKey: String) -> some View {
        VStack(spacing: 12) {
            TextField(L10n.string("answer.placeholder"), text: $textAnswer, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(1...4)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .appSurface(fill: AppTheme.recessed, border: AppTheme.hairline.opacity(0.4), radius: AppTheme.controlRadius)
                .accessibilityIdentifier("answer-field")

            Button {
                onSubmit(textAnswer)
            } label: {
                Text(verbatim: L10n.string(actionTitleKey))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("submit-answer")
        }
    }

    private var reorderView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: selectedWords.isEmpty ? L10n.string("reorder.placeholder") : selectedWords.joined(separator: " "))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selectedWords.isEmpty ? AppTheme.muted : AppTheme.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appSurface(fill: AppTheme.recessed, border: AppTheme.hairline.opacity(0.4), radius: AppTheme.controlRadius)

            FlowLayout(spacing: 9) {
                ForEach(remainingWords, id: \.self) { word in
                    Button {
                        selectedWords.append(word)
                    } label: {
                        Text(verbatim: word)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(AppTheme.hairline.opacity(0.62), lineWidth: 0.7)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Button {
                    selectedWords = []
                } label: {
                    Text(verbatim: L10n.string("action.reset"))
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(selectedWords.isEmpty)

                Button {
                    onSubmit(selectedWords.joined(separator: " "))
                } label: {
                    Text(verbatim: L10n.string("action.check"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedWords.count != card.options.count)
            }
        }
    }

    private var cleanedFixPrompt: String {
        card.prompt
            .replacingOccurrences(of: "Fix the sentence:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var remainingWords: [String] {
        card.options.filter { !selectedWords.contains($0) }
    }
}

private struct ChatTranscript: View {
    let messages: [ChatMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(messages) { message in
                HStack {
                    if message.isUser { Spacer() }
                    Text(verbatim: message.text)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .foregroundStyle(AppTheme.ink)
                        .background(message.isUser ? AppTheme.accent.opacity(0.13) : AppTheme.recessed, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(AppTheme.hairline.opacity(0.55), lineWidth: 0.7)
                        )
                    if !message.isUser { Spacer() }
                }
            }
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? AppTheme.muted : AppTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .appSurface(fill: AppTheme.surface, border: AppTheme.hairline, radius: AppTheme.buttonRadius)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
