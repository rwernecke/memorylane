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
                        .foregroundStyle(Color.memorySuccess)
                } else if showsWrongIcon {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.memoryError)
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
        return Color.memoryInk
    }

    private var backgroundColors: [Color] {
        if showsWrongIcon {
            return [Color.memoryError.opacity(0.16), Color.memoryHotPink.opacity(0.10)]
        }

        if showsCorrectIcon {
            return [Color.memorySuccess.opacity(0.18), Color.memoryMint.opacity(0.28)]
        }

        return [Color.white.opacity(0.98), Color.memoryPeach.opacity(0.94)]
    }

    private var borderColor: Color {
        if showsWrongIcon { return Color.memoryError.opacity(0.78) }
        if showsCorrectIcon { return Color.memorySuccess.opacity(0.78) }
        return Color.memoryHotPink.opacity(0.18)
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
            .background(
                LinearGradient(
                    colors: feedback.isCorrect
                        ? [Color.memorySuccess.opacity(0.14), Color.memoryMint.opacity(0.22)]
                        : [Color.memoryHotPink.opacity(0.14), Color.memorySun.opacity(0.18)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
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

            Text(reviewedCount == 0 ? "No memory-rich photos found" : "That was a good lane")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.memoryInk)
                .multilineTextAlignment(.center)

            Text(reviewedCount == 0 ? "Choose more photos or try again after your library finishes syncing." : "Take another pass with a fresh set of faces.")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.memorySubtleInk)
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
