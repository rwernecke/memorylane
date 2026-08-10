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
import Photos
import UIKit
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
                            reviewedCount: deck.reviewedCount,
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
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(Color.memoryAccent)

                Text("MemoryLane")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Swipe through your own photos and warm up the stories behind them.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
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

            Text("Finding a few good photos")
                .font(.title2.weight(.bold))

            Text("This stays on your iPhone.")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
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
                .multilineTextAlignment(.center)

            Text("MemoryLane needs access to your photo library before it can build your swipe deck.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
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
        VStack(spacing: 14) {
            DeckStatusBar(reviewedCount: reviewedCount, streak: streak)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    photoCard
                    promptPanel
                }
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
        }
    }

    private var photoCard: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: card.image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 430)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.58)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                if let date = card.creationDate {
                    Text(date, format: .dateTime.month(.wide).day().year())
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                if let placeName = card.placeName {
                    Label(placeName, systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
        .offset(x: dragOffset.width, y: dragOffset.height * 0.12)
        .rotationEffect(.degrees(Double(dragOffset.width / 28)))
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: prompt.symbolName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.memoryAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.memoryAccent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(prompt.question)
                    .font(.title2.weight(.bold))
                    .minimumScaleFactor(0.8)
            }

            VStack(spacing: 10) {
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

                Button(action: nextPhoto) {
                    Label("Next Photo", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 58)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.memoryAccent)
            } else {
                Button(action: skipPhoto) {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.bordered)
                .tint(Color.memoryAccent)
            }
        }
        .padding(16)
        .background(Color.memoryCardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct DeckStatusBar: View {
    let reviewedCount: Int
    let streak: Int

    var body: some View {
        HStack(spacing: 10) {
            Label("\(reviewedCount) seen", systemImage: "photo.stack")
            Spacer()
            Label("\(streak) streak", systemImage: "bolt.fill")
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(Color.memoryAccent)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.memoryCardBackground.opacity(0.9), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            HStack(spacing: 12) {
                Text(option)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(foregroundColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.78)
                    .lineLimit(2)

                if showsCorrectIcon {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.memorySuccess)
                } else if showsWrongIcon {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.memoryError)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(feedback != nil)
    }

    private var isSelected: Bool {
        selectedAnswer == option
    }

    private var isCorrectAnswer: Bool {
        option == prompt.answer || prompt.kind == .feeling
    }

    private var showsCorrectIcon: Bool {
        feedback != nil && isCorrectAnswer
    }

    private var showsWrongIcon: Bool {
        feedback?.isCorrect == false && isSelected
    }

    private var foregroundColor: Color {
        if showsWrongIcon { return Color.memoryError }
        if showsCorrectIcon { return Color.memorySuccess }
        return .primary
    }

    private var backgroundColor: Color {
        if showsWrongIcon { return Color.memoryError.opacity(0.12) }
        if showsCorrectIcon { return Color.memorySuccess.opacity(0.14) }
        return Color.white.opacity(0.72)
    }

    private var borderColor: Color {
        if showsWrongIcon { return Color.memoryError.opacity(0.7) }
        if showsCorrectIcon { return Color.memorySuccess.opacity(0.7) }
        return Color.primary.opacity(0.08)
    }
}

private struct FeedbackBanner: View {
    let feedback: QuizFeedback

    var body: some View {
        Label(feedback.message, systemImage: feedback.isCorrect ? "checkmark.seal.fill" : "sparkles")
            .font(.headline.weight(.semibold))
            .foregroundStyle(feedback.isCorrect ? Color.memorySuccess : Color.memoryAccent)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((feedback.isCorrect ? Color.memorySuccess : Color.memoryAccent).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FinishedDeckView: View {
    let reviewedCount: Int
    let reloadAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: reviewedCount == 0 ? "photo" : "checkmark.seal.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.memoryAccent)

            Text(reviewedCount == 0 ? "No photos found" : "That was a good lane")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text(reviewedCount == 0 ? "Choose more photos in Settings, then come back." : "Take another pass with a fresh set of photos.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: reloadAction) {
                Label("New Deck", systemImage: "shuffle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.memoryAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MemoryPhotoCard: Identifiable {
    let id: String
    let image: UIImage
    let creationDate: Date?
    let placeName: String?
}

private struct QuizFeedback {
    let isCorrect: Bool
    let message: String
}

@MainActor
private final class PhotoDeckViewModel: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var cards: [MemoryPhotoCard] = []
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

        if canReadLibrary, cards.isEmpty, !isLoading {
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
        streak = 0

        let assets = fetchPhotoAssets().shuffled().prefix(18)
        var loadedCards: [MemoryPhotoCard] = []

        for asset in assets {
            guard let image = await image(for: asset) else { continue }
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

        let isCorrect = prompt.kind == .feeling || answer == prompt.answer
        if isCorrect {
            streak += 1
            feedback = QuizFeedback(isCorrect: true, message: prompt.confirmation)
        } else {
            streak = 0
            feedback = QuizFeedback(isCorrect: false, message: "Close. \(prompt.confirmation)")
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
        if !cards.isEmpty {
            cards.removeFirst()
            reviewedCount += 1
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
        options.fetchLimit = 300
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
                contentMode: .aspectFill,
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
#endif

private struct UnsupportedPlatformView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "iphone")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.memoryAccent)

            Text("MemoryLane is built for iPhone")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Run it on an iPhone simulator or device to use the photo swipe deck.")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MemoryLaneBackground())
    }
}

private struct MemoryLaneBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.95, blue: 0.88),
                Color(red: 0.88, green: 0.94, blue: 0.91),
                Color(red: 0.90, green: 0.92, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private extension Color {
    static var memoryAccent: Color {
        Color(red: 0.12, green: 0.42, blue: 0.38)
    }

    static var memoryCardBackground: Color {
        Color.white.opacity(0.9)
    }

    static var memorySuccess: Color {
        Color(red: 0.12, green: 0.50, blue: 0.27)
    }

    static var memoryError: Color {
        Color(red: 0.72, green: 0.22, blue: 0.20)
    }
}

#Preview {
    ContentView()
}
