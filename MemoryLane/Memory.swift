//
//  Memory.swift
//  MemoryLane
//
//  Created by Rafael on 8/9/26.
//

import Foundation
import SwiftData

enum MemoryMood: String, CaseIterable, Identifiable, Hashable {
    case warm
    case joyful
    case grateful
    case bittersweet
    case quiet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warm:
            return "Warm"
        case .joyful:
            return "Joyful"
        case .grateful:
            return "Grateful"
        case .bittersweet:
            return "Bittersweet"
        case .quiet:
            return "Quiet"
        }
    }

    var symbolName: String {
        switch self {
        case .warm:
            return "sun.max.fill"
        case .joyful:
            return "sparkles"
        case .grateful:
            return "heart.fill"
        case .bittersweet:
            return "moon.stars.fill"
        case .quiet:
            return "leaf.fill"
        }
    }
}

@Model
final class Memory {
    var title: String
    var story: String
    var capturedAt: Date
    var locationName: String
    var moodRawValue: String
    var tagsText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        story: String,
        capturedAt: Date = Date(),
        locationName: String = "",
        mood: MemoryMood = .warm,
        tags: [String] = []
    ) {
        let now = Date()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.story = story.trimmingCharacters(in: .whitespacesAndNewlines)
        self.capturedAt = capturedAt
        self.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.moodRawValue = mood.rawValue
        self.tagsText = Self.serializedTags(tags)
        self.createdAt = now
        self.updatedAt = now
    }

    var mood: MemoryMood {
        get { MemoryMood(rawValue: moodRawValue) ?? .warm }
        set {
            moodRawValue = newValue.rawValue
            touch()
        }
    }

    var tags: [String] {
        get { Self.normalizedTags(from: tagsText) }
        set {
            tagsText = Self.serializedTags(newValue)
            touch()
        }
    }

    var hasLocation: Bool {
        !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func update(
        title: String,
        story: String,
        capturedAt: Date,
        locationName: String,
        mood: MemoryMood,
        tags: [String]
    ) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.story = story.trimmingCharacters(in: .whitespacesAndNewlines)
        self.capturedAt = capturedAt
        self.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.moodRawValue = mood.rawValue
        self.tagsText = Self.serializedTags(tags)
        touch()
    }

    static func normalizedTags(from input: String) -> [String] {
        input
            .split { character in
                character == "," || character == "\n"
            }
            .map { tag in
                tag.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .map { tag in
                tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
            }
            .map { tag in
                tag.lowercased()
            }
            .filter { tag in
                !tag.isEmpty
            }
            .reduce(into: [String]()) { result, tag in
                if !result.contains(tag) {
                    result.append(tag)
                }
            }
    }

    static func serializedTags(_ tags: [String]) -> String {
        normalizedTags(from: tags.joined(separator: ","))
            .joined(separator: ",")
    }

    private func touch() {
        updatedAt = Date()
    }
}
