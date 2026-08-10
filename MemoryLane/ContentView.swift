//
//  ContentView.swift
//  MemoryLane
//
//  Created by Rafael on 8/9/26.
//

import SwiftUI

#if os(iOS)
import Combine
import CoreLocation
import ImageIO
import Photos
import UIKit
import Vision
#endif

struct ContentView: View {
    var body: some View {
#if os(iOS)
        PhotoMemoryLaneView()
#else
        UnsupportedPlatformView()
#endif
    }
}

#if os(iOS)
private struct PhotoMemoryLaneView: View {
    @StateObject private var deck = PhotoDeckViewModel()

    var body: some View {
        ZStack {
            MemoryLaneBackground()

            Group {
                switch deck.authorizationStatus {
                case .notDetermined:
                    StartExperienceView {
                        Task { await deck.requestAccessAndLoad() }
                    }
                case .authorized, .limited:
                    if deck.isLoading {
                        LoadingLibraryView()
                    } else if let card = deck.currentCard {
                        SwipeQuizView(
                            card: card,
                            prompt: deck.prompt,
                            selectedAnswer: deck.selectedAnswer,
                            feedback: deck.feedback,
                            reviewedCount: deck.reviewedCount,
                            streak: deck.streak,
                            submitAnswer: deck.submitAnswer,
                            nextPhoto: deck.nextPhoto,
                            skipPhoto: deck.skipPhoto
                        )
                    } else {
                        FinishedDeckView(
                            reviewedCards: deck.reviewedCards,
                            reloadAction: { Task { await deck.loadDeck() } }
                        )
                    }
                case .denied, .restricted:
                    PhotoAccessNeededView()
                @unknown default:
                    PhotoAccessNeededView()
                }
            }
            .padding(.horizontal, 18)
        }
        .task {
            await deck.refreshAuthorizationStatus()
        }
    }
}

private struct StartExperienceView: View {
    let startAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 32)

            VStack(spacing: 14) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(Color.memoryAccent)

                Text("MemoryLane")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.memoryInk)
                    .multilineTextAlignment(.center)

                Text("Swipe through photos with people you love and warm up the stories behind them.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.memorySubtleInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            Button(action: startAction) {
                Label("Start Swiping", systemImage: "hand.draw.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.memoryAccent)
            .controlSize(.large)

            Spacer(minLength: 28)
        }
    }
}

private struct LoadingLibraryView: View {
    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.memoryAccent)

            Text("Finding memory-rich moments")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.memoryInk)
                .multilineTextAlignment(.center)

            Text("Building a private swipe deck on your iPhone.")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.memorySubtleInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PhotoAccessNeededView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.photos")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(Color.memoryAccent)

            Text("Photos are turned off")
                .font(.title.bold())
                .foregroundStyle(Color.memoryInk)
                .multilineTextAlignment(.center)

            Text("MemoryLane needs access to your photo library before it can build your swipe deck.")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.memorySubtleInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: openSettings) {
                Label("Open Settings", systemImage: "gearshape.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.memoryAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct SwipeQuizView: View {
    let card: MemoryPhotoCard
    let prompt: MemoryQuizPrompt
    let selectedAnswer: String?
    let feedback: QuizFeedback?
    let reviewedCount: Int
    let streak: Int
    let submitAnswer: (String) -> Void
    let nextPhoto: () -> Void
    let skipPhoto: () -> Void
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                DeckStatusBar(reviewedCount: reviewedCount, streak: streak, skipPhoto: skipPhoto)
                photoCard(height: photoHeight(for: geometry.size.height))
                promptPanel
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .task(id: feedback?.shouldAutoAdvance) {
            guard feedback?.shouldAutoAdvance == true else { return }
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { nextPhoto() }
        }
    }

    private func photoHeight(for availableHeight: CGFloat) -> CGFloat {
        if feedback == nil {
            return min(max(availableHeight * 0.54, 250), 470)
        }

        return min(max(availableHeight * 0.36, 210), 340)
    }

    private func photoCard(height: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { proxy in
                ZStack {
                    Image(uiImage: card.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: 18)
                        .saturation(1.18)
                        .opacity(0.68)

                    LinearGradient(
                        colors: [.black.opacity(0.20), .black.opacity(0.04), .black.opacity(0.24)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Image(uiImage: card.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 5)
                }
            }
            .frame(height: height)

            LinearGradient(
                colors: [.clear, .black.opacity(0.26)],
                startPoint: .center,
                endPoint: .bottom
            )

            if let feedback, feedback.isCorrect {
                CorrectBurstView(title: feedback.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale(scale: 0.84).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            Label("Swipe", systemImage: "hand.draw.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.94))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.28), in: Capsule())
                .padding(14)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: Color.memoryHotPink.opacity(0.24), radius: 22, x: 0, y: 12)
        .offset(x: dragOffset.width, y: dragOffset.height * 0.08)
        .rotationEffect(.degrees(Double(dragOffset.width / 30)))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    if abs(value.translation.width) > 120 {
                        skipPhoto()
                    }

                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = .zero
                    }
                }
        )
    }

    private var promptPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: prompt.symbolName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.memoryAccent)
                    .frame(width: 34, height: 34)
                    .background(
                        LinearGradient(
                            colors: [Color.memorySun.opacity(0.26), Color.memoryHotPink.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Text(prompt.question)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.memoryInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(prompt.options, id: \.self) { option in
                    AnswerOptionButton(
                        option: option,
                        prompt: prompt,
                        selectedAnswer: selectedAnswer,
                        feedback: feedback
                    ) {
                        submitAnswer(option)
                    }
                }
            }

            if let feedback {
                FeedbackBanner(feedback: feedback)

                if feedback.shouldAutoAdvance {
                    AutoAdvanceCue()
                } else {
                    Button(action: nextPhoto) {
                        Label("Next", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.memoryAccent)
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.memoryCardBackground, Color.memoryCardWarmth],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.memoryHotPink.opacity(0.22), lineWidth: 1.2)
        }
        .shadow(color: Color.memoryViolet.opacity(0.12), radius: 18, x: 0, y: 8)
    }
}

private struct DeckStatusBar: View {
    let reviewedCount: Int
    let streak: Int
    let skipPhoto: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label("\(reviewedCount)", systemImage: "photo.stack")
            Spacer()
            Label("\(streak)", systemImage: "bolt.fill")
            Button(action: skipPhoto) {
                Image(systemName: "forward.fill")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.memoryAccent)
            .accessibilityLabel("Skip photo")
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(Color.memoryInk)
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.memoryCardBackground.opacity(0.96), Color.white.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

private struct AnswerOptionButton: View {
    let option: String
    let prompt: MemoryQuizPrompt
    let selectedAnswer: String?
    let feedback: QuizFeedback?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(option)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(foregroundColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.76)
                    .lineLimit(2)

                if showsCorrectIcon {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                } else if showsWrongIcon {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.8)
            }
            .shadow(color: glowColor, radius: showsCorrectIcon || showsWrongIcon ? 12 : 0, x: 0, y: 5)
            .scaleEffect(showsCorrectIcon ? 1.04 : 1.0)
            .animation(.spring(response: 0.30, dampingFraction: 0.68), value: feedback?.isCorrect)
        }
        .buttonStyle(.plain)
        .disabled(feedback != nil)
    }

    private var isSelected: Bool {
        selectedAnswer == option
    }

    private var isCorrectAnswer: Bool {
        option == prompt.answer
    }

    private var showsCorrectIcon: Bool {
        guard feedback != nil else { return false }
        return prompt.acceptsAnyAnswer ? isSelected : isCorrectAnswer
    }

    private var showsWrongIcon: Bool {
        feedback?.isCorrect == false && isSelected
    }

    private var foregroundColor: Color {
        if showsWrongIcon || showsCorrectIcon { return .white }
        return Color.memoryInk
    }

    private var backgroundColors: [Color] {
        if showsWrongIcon {
            return [Color.memoryError, Color.memoryHotPink]
        }

        if showsCorrectIcon {
            return [Color.memorySuccess, Color.memoryTeal]
        }

        return [Color.white.opacity(0.98), Color.memoryPeach.opacity(0.94)]
    }

    private var borderColor: Color {
        if showsWrongIcon || showsCorrectIcon { return Color.white.opacity(0.86) }
        return Color.memoryHotPink.opacity(0.18)
    }

    private var glowColor: Color {
        if showsCorrectIcon { return Color.memorySuccess.opacity(0.36) }
        if showsWrongIcon { return Color.memoryError.opacity(0.26) }
        return .clear
    }
}

private struct FeedbackBanner: View {
    let feedback: QuizFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(feedback.title, systemImage: feedback.isCorrect ? "checkmark.seal.fill" : "sparkles")
                .font(.headline.weight(.heavy))

            Text(feedback.message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(feedback.isCorrect ? Color.memorySuccess : Color.memoryAccent)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: feedback.isCorrect
                    ? [Color.memorySuccess.opacity(0.18), Color.memoryMint.opacity(0.28)]
                    : [Color.memoryHotPink.opacity(0.14), Color.memorySun.opacity(0.18)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

private struct CorrectBurstView: View {
    let title: String
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54, weight: .heavy))

            Text(title)
                .font(.largeTitle.weight(.heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [Color.memorySuccess, Color.memoryTeal, Color.memoryMint.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.75), lineWidth: 1.4)
        }
        .shadow(color: Color.memorySuccess.opacity(0.46), radius: 28, x: 0, y: 12)
        .scaleEffect(isVisible ? 1 : 0.82)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                isVisible = true
            }
        }
    }
}

private struct AutoAdvanceCue: View {
    var body: some View {
        Label("Next memory coming up", systemImage: "arrow.right.circle.fill")
            .font(.headline.weight(.bold))
            .foregroundStyle(Color.memorySuccess)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.memorySuccess.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FinishedDeckView: View {
    let reviewedCards: [MemoryPhotoCard]
    let reloadAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            if reviewedCards.isEmpty {
                emptyState
            } else {
                recapState
            }

            Button(action: reloadAction) {
                Label(reviewedCards.isEmpty ? "New Deck" : "Review More Memories", systemImage: "shuffle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.memoryAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.memoryAccent)

            Text("No memory-rich photos found")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.memoryInk)
                .multilineTextAlignment(.center)

            Text("Choose more photos or try again after your library finishes syncing.")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.memorySubtleInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recapState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Color.memoryAccent)

                VStack(spacing: 7) {
                    Text("You reviewed \(reviewedCards.count) memories")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.memoryInk)
                        .multilineTextAlignment(.center)

                    Text("These are the pictures you just revisited.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.memorySubtleInk)
                        .multilineTextAlignment(.center)
                }

                ReviewedPhotoGrid(cards: reviewedCards)
            }
            .padding(.vertical, 10)
        }
    }
}

private struct ReviewedPhotoGrid: View {
    let cards: [MemoryPhotoCard]
    private let columns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            ForEach(cards) { card in
                ReviewedPhotoTile(card: card)
            }
        }
        .padding(10)
        .background(Color.memoryCardBackground.opacity(0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ReviewedPhotoTile: View {
    let card: MemoryPhotoCard

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: card.image)
                .resizable()
                .scaledToFill()
                .frame(height: 104)
                .frame(maxWidth: .infinity)
                .clipped()

            if let caption {
                Text(caption)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.34), in: Capsule())
                    .padding(5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.44), lineWidth: 1)
        }
    }

    private var caption: String? {
        if let placeName = card.placeName, !placeName.isEmpty {
            return placeName
        }

        if let creationDate = card.creationDate {
            return creationDate.formatted(.dateTime.year())
        }

        return nil
    }
}

private struct MemoryPhotoCard: Identifiable {
    let id: String
    let image: UIImage
    let creationDate: Date?
    let placeName: String?
}

private struct QuizFeedback {
    let title: String
    let isCorrect: Bool
    let message: String
    let shouldAutoAdvance: Bool
}

@MainActor
private final class PhotoDeckViewModel: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var cards: [MemoryPhotoCard] = []
    @Published var reviewedCards: [MemoryPhotoCard] = []
    @Published var prompt = MemoryQuizFactory.feelingPrompt()
    @Published var selectedAnswer: String?
    @Published var feedback: QuizFeedback?
    @Published var isLoading = false
    @Published var reviewedCount = 0
    @Published var streak = 0

    var currentCard: MemoryPhotoCard? {
        cards.first
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if canReadLibrary, cards.isEmpty, reviewedCards.isEmpty, !isLoading {
            await loadDeck()
        }
    }

    func requestAccessAndLoad() async {
        authorizationStatus = await requestLibraryAccess()

        if canReadLibrary {
            await loadDeck()
        }
    }

    func loadDeck() async {
        guard !isLoading else { return }
        isLoading = true
        selectedAnswer = nil
        feedback = nil
        reviewedCards = []
        reviewedCount = 0
        streak = 0

        let assets = fetchPhotoAssets().shuffled()
        var loadedCards: [MemoryPhotoCard] = []
        loadedCards.reserveCapacity(18)

        for asset in assets {
            guard loadedCards.count < 18 else { break }
            guard let image = await image(for: asset) else { continue }
            guard await hasFace(in: image) else { continue }

            let placeName = await placeName(for: asset.location)
            loadedCards.append(
                MemoryPhotoCard(
                    id: asset.localIdentifier,
                    image: image,
                    creationDate: asset.creationDate,
                    placeName: placeName
                )
            )
        }

        cards = loadedCards
        preparePrompt()
        isLoading = false
    }

    func submitAnswer(_ answer: String) {
        guard feedback == nil else { return }
        selectedAnswer = answer

        let isCorrect = prompt.acceptsAnyAnswer || answer == prompt.answer
        if isCorrect {
            streak += 1
            let title = prompt.acceptsAnyAnswer ? "Nice choice" : "Correct!"
            feedback = QuizFeedback(
                title: title,
                isCorrect: true,
                message: prompt.confirmation,
                shouldAutoAdvance: true
            )
        } else {
            streak = 0
            feedback = QuizFeedback(
                title: "Almost",
                isCorrect: false,
                message: "Close. \(prompt.confirmation)",
                shouldAutoAdvance: false
            )
        }
    }

    func nextPhoto() {
        advanceDeck(keepsStreak: true)
    }

    func skipPhoto() {
        advanceDeck(keepsStreak: false)
    }

    private var canReadLibrary: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    private func advanceDeck(keepsStreak: Bool) {
        if let card = cards.first {
            reviewedCards.append(card)
            cards.removeFirst()
            reviewedCount = reviewedCards.count
        }

        if !keepsStreak {
            streak = 0
        }

        selectedAnswer = nil
        feedback = nil
        preparePrompt()
    }

    private func preparePrompt() {
        guard let card = currentCard else {
            prompt = MemoryQuizFactory.feelingPrompt()
            return
        }

        prompt = MemoryQuizFactory.prompt(for: card.creationDate, placeName: card.placeName)
    }

    private func requestLibraryAccess() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func fetchPhotoAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.fetchLimit = 500
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }

    private func image(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            let targetSize = CGSize(width: 1200, height: 1200)
            var didResume = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !didResume else { return }

                let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
                let error = info?[PHImageErrorKey] as? Error

                if isCancelled || error != nil {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }

                if let image {
                    didResume = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    private func hasFace(in image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return false }

        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, _ in
                let observations = request.results as? [VNFaceObservation]
                continuation.resume(returning: observations?.isEmpty == false)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImagePropertyOrientation)

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    private func placeName(for location: CLLocation?) async -> String? {
        guard let location else { return nil }

        return await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }

                let place = [placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")

                continuation.resume(returning: place.isEmpty ? placemark.name : place)
            }
        }
    }
}

private extension UIImage {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
#endif

private struct UnsupportedPlatformView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "iphone")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.memoryAccent)

            Text("MemoryLane is built for iPhone")
                .font(.title.bold())
                .foregroundStyle(Color.memoryInk)
                .multilineTextAlignment(.center)

            Text("Run it on an iPhone simulator or device to use the photo swipe deck.")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.memorySubtleInk)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MemoryLaneBackground())
    }
}

private struct MemoryLaneBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.memorySun,
                    Color.memorySunsetOrange,
                    Color.memoryHotPink,
                    Color.memoryViolet
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.50), Color.white.opacity(0.0)],
                center: .topLeading,
                startRadius: 20,
                endRadius: 360
            )

            RadialGradient(
                colors: [Color.memoryPeach.opacity(0.60), Color.memoryHotPink.opacity(0.0)],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

private extension Color {
    static var memoryAccent: Color {
        Color(red: 0.96, green: 0.12, blue: 0.45)
    }

    static var memoryHotPink: Color {
        Color(red: 0.99, green: 0.09, blue: 0.45)
    }

    static var memorySunsetOrange: Color {
        Color(red: 1.00, green: 0.47, blue: 0.18)
    }

    static var memorySun: Color {
        Color(red: 1.00, green: 0.78, blue: 0.20)
    }

    static var memoryViolet: Color {
        Color(red: 0.43, green: 0.24, blue: 0.92)
    }

    static var memoryPeach: Color {
        Color(red: 1.00, green: 0.90, blue: 0.82)
    }

    static var memoryMint: Color {
        Color(red: 0.71, green: 0.98, blue: 0.82)
    }

    static var memoryTeal: Color {
        Color(red: 0.00, green: 0.68, blue: 0.54)
    }

    static var memoryInk: Color {
        Color(red: 0.10, green: 0.06, blue: 0.13)
    }

    static var memorySubtleInk: Color {
        Color(red: 0.34, green: 0.21, blue: 0.30)
    }

    static var memoryCardBackground: Color {
        Color(red: 1.00, green: 0.98, blue: 0.95).opacity(0.97)
    }

    static var memoryCardWarmth: Color {
        Color(red: 1.00, green: 0.93, blue: 0.87).opacity(0.97)
    }

    static var memorySuccess: Color {
        Color(red: 0.06, green: 0.54, blue: 0.28)
    }

    static var memoryError: Color {
        Color(red: 0.82, green: 0.13, blue: 0.27)
    }
}

#Preview {
    ContentView()
}
