//
//  MemoryLaneTests.swift
//  MemoryLaneTests
//
//  Created by Rafael on 8/9/26.
//

import Foundation
import Testing
@testable import MemoryLane

struct MemoryLaneTests {
    @Test func normalizesTags() async throws {
        let tags = Memory.normalizedTags(from: " Family, #Summer\nfamily,firsts, ")

        #expect(tags == ["family", "summer", "firsts"])
    }

    @Test func trimsNewMemoryFields() async throws {
        let memory = Memory(
            title: "  Beach morning  ",
            story: "  The tide was quiet.  ",
            locationName: "  Ocean City  ",
            mood: .quiet,
            tags: ["#Summer", "family"]
        )

        #expect(memory.title == "Beach morning")
        #expect(memory.story == "The tide was quiet.")
        #expect(memory.locationName == "Ocean City")
        #expect(memory.mood == .quiet)
        #expect(memory.tags == ["summer", "family"])
        #expect(memory.hasLocation)
    }

    @Test func updateRefreshesMemoryFields() async throws {
        let capturedAt = Date(timeIntervalSince1970: 100)
        let memory = Memory(title: "Old", story: "Old story")

        memory.update(
            title: "  First bike ride  ",
            story: "  Wobbly, fast, unforgettable.  ",
            capturedAt: capturedAt,
            locationName: "  Boardwalk  ",
            mood: .joyful,
            tags: ["firsts", "#Family", "firsts"]
        )

        #expect(memory.title == "First bike ride")
        #expect(memory.story == "Wobbly, fast, unforgettable.")
        #expect(memory.capturedAt == capturedAt)
        #expect(memory.locationName == "Boardwalk")
        #expect(memory.mood == .joyful)
        #expect(memory.tags == ["firsts", "family"])
    }
}
