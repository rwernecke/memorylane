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
    @Test func yearPromptIncludesCorrectYear() async throws {
        let date = Date(timeIntervalSince1970: 1_577_836_800)
        let prompt = MemoryQuizFactory.yearPrompt(for: date, calendar: .gregorianUTC)

        #expect(prompt.question == "What year was this?")
        #expect(prompt.answer == "2020")
        #expect(prompt.options.contains("2020"))
        #expect(prompt.options.count == 4)
    }

    @Test func monthPromptIncludesCorrectMonth() async throws {
        let date = Date(timeIntervalSince1970: 1_625_097_600)
        let prompt = MemoryQuizFactory.monthPrompt(for: date, calendar: .gregorianUTC)

        #expect(prompt.question == "Which month was it?")
        #expect(prompt.answer == "July")
        #expect(prompt.options.contains("July"))
        #expect(prompt.options.count == 4)
    }

    @Test func placePromptUsesKnownLocationAsAnswer() async throws {
        let prompt = MemoryQuizFactory.placePrompt(placeName: "Ocean City, MD")

        #expect(prompt.question == "Where was this?")
        #expect(prompt.answer == "Ocean City, MD")
        #expect(prompt.options.contains("Ocean City, MD"))
        #expect(prompt.options.count == 4)
    }
}

private extension Calendar {
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
