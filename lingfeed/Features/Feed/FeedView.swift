import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel
    @State private var isProfilePresented = false
    @State private var visibleCardID: LearningCard.ID?
    @State private var keyboardHeight: CGFloat = 0
    @State private var pageCommitTask: Task<Void, Never>?

    let targetLanguageCode: String
    @Binding var nativeLanguageCode: String
    @Binding var notificationsEnabled: Bool
    let onChangeLanguage: () -> Void

    init(
        viewModel: FeedViewModel,
        targetLanguageCode: String,
        nativeLanguageCode: Binding<String>,
        notificationsEnabled: Binding<Bool>,
        onChangeLanguage: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.targetLanguageCode = targetLanguageCode
        _nativeLanguageCode = nativeLanguageCode
        _notificationsEnabled = notificationsEnabled
        self.onChangeLanguage = onChangeLanguage
    }

    var body: some View {
        ZStack {
            AppBackground()

            switch viewModel.phase {
            case .idle, .loading:
                LoadingView()
            case .ready, .answering:
                feedContent
            case .failed(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.retry() }
                }
            }
        }
        .background(KeyboardDismissTapCatcher())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            await viewModel.start()
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileView(
                profile: viewModel.profile,
                nativeLanguageCode: $nativeLanguageCode,
                targetLanguageCode: targetLanguageCode,
                notificationsEnabled: $notificationsEnabled,
                onChangeLanguage: onChangeLanguage
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.summary != nil },
                set: { if !$0 { viewModel.dismissSummary() } }
            )
        ) {
            if let summary = viewModel.summary {
                SessionSummaryView(summary: summary) {
                    viewModel.dismissSummary()
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var feedContent: some View {
        GeometryReader { proxy in
            let topBarHeight: CGFloat = 58
            let pageHeight = max(1, proxy.size.height - topBarHeight)

            ZStack(alignment: .top) {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.cards) { card in
                            LearningCardView(
                                card: card,
                                feedback: card.id == viewModel.currentCardID ? viewModel.feedback : nil,
                                isBusy: viewModel.isBusy && card.id == viewModel.currentCardID,
                                onSubmit: { answer in
                                    viewModel.activateCard(card.id)
                                    Task { await viewModel.submit(answer) }
                                },
                                onContinue: {
                                    viewModel.activateCard(card.id)
                                    viewModel.continueAfterFeedback()
                                },
                                onTooEasy: {
                                    viewModel.activateCard(card.id)
                                    viewModel.markCurrentCardTooEasy()
                                }
                            )
                            .id(card.id)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 18)
                            .frame(height: pageHeight)
                            .offset(y: card.id == viewModel.currentCardID ? -keyboardLift(for: pageHeight) : 0)
                        }
                    }
                    .padding(.top, topBarHeight)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $visibleCardID, anchor: .top)
                .simultaneousGesture(shortPagingGesture)
                .onChange(of: visibleCardID) { _, newValue in
                    guard let newValue else { return }
                    viewModel.previewCard(newValue)
                    schedulePageCommit(for: newValue)
                }
                .onChange(of: viewModel.currentCardID) { _, newValue in
                    guard let newValue, visibleCardID != newValue else { return }
                    withAnimation(.easeInOut(duration: 0.34)) {
                        visibleCardID = newValue
                    }
                }
                .onAppear {
                    visibleCardID = viewModel.currentCardID
                }
                .onDisappear {
                    pageCommitTask?.cancel()
                    pageCommitTask = nil
                }

                FeedNavigationGradient()
                    .frame(height: topBarHeight + 54)
                    .allowsHitTesting(false)

                FeedTopBar(
                    stats: viewModel.stats,
                    profile: viewModel.profile,
                    onProfileTap: { isProfilePresented = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .frame(height: topBarHeight)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.feedback)
        .animation(.easeOut(duration: 0.24), value: keyboardHeight)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            keyboardHeight = keyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private func schedulePageCommit(for cardID: LearningCard.ID) {
        pageCommitTask?.cancel()
        pageCommitTask = Task {
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !Task.isCancelled else { return }
            await viewModel.pageToCard(cardID)
        }
    }

    private var shortPagingGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let projected = value.predictedEndTranslation.height
                let actual = value.translation.height
                let decisiveDistance: CGFloat = 76
                let decisiveFlick: CGFloat = 132

                guard abs(actual) > decisiveDistance || abs(projected) > decisiveFlick else { return }

                let direction = abs(projected) > abs(actual) ? projected : actual
                guard let targetID = direction < 0 ? nextCardID() : previousCardID() else { return }

                withAnimation(.easeInOut(duration: 0.28)) {
                    visibleCardID = targetID
                }
            }
    }

    private func nextCardID() -> LearningCard.ID? {
        guard
            let currentID = visibleCardID ?? viewModel.currentCardID,
            let index = viewModel.cards.firstIndex(where: { $0.id == currentID })
        else {
            return viewModel.cards.first?.id
        }

        let nextIndex = viewModel.cards.index(after: index)
        guard nextIndex < viewModel.cards.endIndex else { return nil }
        return viewModel.cards[nextIndex].id
    }

    private func previousCardID() -> LearningCard.ID? {
        guard
            let currentID = visibleCardID ?? viewModel.currentCardID,
            let index = viewModel.cards.firstIndex(where: { $0.id == currentID }),
            index > viewModel.cards.startIndex
        else {
            return nil
        }

        return viewModel.cards[viewModel.cards.index(before: index)].id
    }

    private func keyboardLift(for pageHeight: CGFloat) -> CGFloat {
        guard keyboardHeight > 0 else { return 0 }
        return min(keyboardHeight * 0.62, pageHeight * 0.30, 220)
    }

    private func keyboardHeight(from notification: Notification) -> CGFloat {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }
        return max(0, frame.height)
    }
}

private struct FeedNavigationGradient: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: AppTheme.background, location: 0),
                .init(color: AppTheme.background.opacity(0.98), location: 0.42),
                .init(color: AppTheme.background.opacity(0.72), location: 0.72),
                .init(color: AppTheme.background.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .top)
    }
}

private struct KeyboardDismissTapCatcher: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = KeyboardDismissView()
        view.configure(coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var installedWindow: UIWindow?
        weak var installedRecognizer: UITapGestureRecognizer?

        @objc func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let touchedView = touch.view else { return true }
            return !touchedView.isTextInput
        }
    }

    final class KeyboardDismissView: UIView {
        private weak var coordinator: Coordinator?

        func configure(coordinator: Coordinator) {
            self.coordinator = coordinator
            backgroundColor = .clear
            isUserInteractionEnabled = false
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            guard let window, let coordinator else { return }
            guard coordinator.installedWindow !== window else { return }

            if let recognizer = coordinator.installedRecognizer {
                coordinator.installedWindow?.removeGestureRecognizer(recognizer)
            }

            let recognizer = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = coordinator
            window.addGestureRecognizer(recognizer)

            coordinator.installedWindow = window
            coordinator.installedRecognizer = recognizer
        }
    }
}

private extension UIView {
    var isTextInput: Bool {
        if self is UITextField || self is UITextView {
            return true
        }

        return superview?.isTextInput ?? false
    }
}

private struct FeedTopBar: View {
    let stats: SessionStats
    let profile: UserProfile
    let onProfileTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            statStrip
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.leading, 28)

            Button(action: onProfileTap) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(L10n.string("profile.title"))
        }
        .overlay(alignment: .bottom) {
            ProgressRuler(segments: 5, completed: min(stats.answered % 5, 5))
                .offset(y: 22)
        }
    }

    private var statStrip: some View {
        ViewThatFits(in: .horizontal) {
            statsText(
                streak: "\(max(profile.streak, 1))d \(L10n.string("feed.streak"))",
                done: String(format: L10n.string("feed.done"), stats.answered),
                accuracy: "\(accuracyPercent)% \(L10n.string("feed.accuracy"))"
            )

            statsText(
                streak: "\(max(profile.streak, 1))d",
                done: "\(stats.answered)",
                accuracy: "\(accuracyPercent)%"
            )
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private func statsText(streak: String, done: String, accuracy: String) -> some View {
        HStack(spacing: 6) {
            Text(streak)
                .foregroundStyle(AppTheme.ink)
            Text("·")
                .foregroundStyle(AppTheme.muted)
            Text(done)
                .foregroundStyle(AppTheme.muted)
            Text("·")
                .foregroundStyle(AppTheme.muted)
            Text(accuracy)
                .foregroundStyle(AppTheme.ink)
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var accuracyPercent: Int {
        stats.answered == 0 ? 100 : Int(stats.accuracy * 100)
    }
}

private struct ProgressRuler: View {
    let segments: Int
    let completed: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<segments, id: \.self) { index in
                Capsule()
                    .fill(index <= completed ? AppTheme.ink : AppTheme.hairline.opacity(0.55))
                    .frame(height: 3)
            }
        }
        .frame(width: 170)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(AppTheme.ink)
            Text(L10n.string("feed.loading"))
                .font(AppTheme.bodyMonoFont)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.ink)
            Text(L10n.string("error.title"))
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.muted)
            Button(L10n.string("action.retry"), action: retry)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: 420)
    }
}

struct AppBackground: View {
    var body: some View {
        AppTheme.background
        .ignoresSafeArea()
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.actionText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                configuration.isPressed ? AppTheme.action.opacity(0.76) : AppTheme.action,
                in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 0.8)
                    .blendMode(.screen)
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.14), radius: 14, x: 0, y: 8)
    }
}
