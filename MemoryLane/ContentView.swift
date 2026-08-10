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
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(Color.memoryAccent)

                Text("MemoryLane")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Swipe through photos with people you love and warm up the stories behind them.")
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

            Text("Finding photos with people")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

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
    }

    private func photoHeight(for availableHeight: CGFloat) -> CGFloat {
        let fraction = feedback == nil ? 0.56 : 0.50
        return min(max(availableHeight * fraction, 280), 470)
    }

    private func photoCard(height: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: card.image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.22)],
                startPoint: .center,
                endPoint: .bottom
            )

            Label("Swipe", systemImage: "hand.draw.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.26), in: Capsule())
                .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
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
                    .background(Color.memoryAccent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(prompt.question)
                    .font(.title3.weight(.bold))
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

                Button(action: nextPhoto) {
                    Label("Next", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.memoryAccent)
            }
        }
        .padding(14)
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
        .foregroundStyle(Color.memoryAccent)
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Color.memoryCardBackground.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                        .foregroundStyle(Color.memorySuccess)
                } else if showsWrongIcon {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.memoryError)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 58)
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
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(feedback.isCorrect ? Color.memorySuccess : Color.memoryAccent)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((feedback.isCorrect ? Color.memorySuccess : Color.memoryAccent).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FinishedDeckView: View {
    let reviewedCount: Int
    let reloadAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: reviewedCount == 0 ? "person.crop.rectangle.stack" : "checkmark.seal.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.memoryAccent)

            Text(reviewedCount == 0 ? "No people photos found" : "That was a good lane")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text(reviewedCount == 0 ? "Choose more photos or try again after your library finishes syncing." : "Take another pass with a fresh set of faces.")
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
