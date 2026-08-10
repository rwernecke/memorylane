//
//  MemoryQuiz.swift
//  MemoryLane
//
//  Created by Rafael on 8/9/26.
//

import Foundation

struct MemoryQuizPrompt: Identifiable, Equatable {
    enum Kind: Equatable {
        case year
        case month
        case season
        case city
        case place
        case feeling
    }

    let id = UUID()
    let kind: Kind
    let question: String
    let options: [String]
    let answer: String
    let confirmation: String
    let symbolName: String

    var acceptsAnyAnswer: Bool {
        kind == .feeling
    }

    static func == (lhs: MemoryQuizPrompt, rhs: MemoryQuizPrompt) -> Bool {
        lhs.kind == rhs.kind &&
        lhs.question == rhs.question &&
        lhs.options == rhs.options &&
        lhs.answer == rhs.answer &&
        lhs.confirmation == rhs.confirmation &&
        lhs.symbolName == rhs.symbolName
    }
}

enum MemoryQuizFactory {
    static func prompt(for date: Date?, placeName: String?, calendar: Calendar = .current) -> MemoryQuizPrompt {
        let cleanPlace = cleanedPlaceName(placeName)

        if let date, let cleanPlace {
            let roll = Int.random(in: 1...100)

            switch roll {
            case 1...32:
                return cityPrompt(placeName: cleanPlace)
            case 33...57:
                return seasonPrompt(for: date, calendar: calendar)
            case 58...70:
                return tripPrompt(placeName: cleanPlace)
            case 71...82:
                return yearPrompt(for: date, calendar: calendar)
            case 83...90:
                return monthPrompt(for: date, calendar: calendar)
            default:
                return weekBeforePrompt(for: date, placeName: cleanPlace, calendar: calendar)
            }
        }

        if let date {
            let roll = Int.random(in: 1...100)

            switch roll {
            case 1...42:
                return seasonPrompt(for: date, calendar: calendar)
            case 43...60:
                return yearPrompt(for: date, calendar: calendar)
            case 61...70:
                return monthPrompt(for: date, calendar: calendar)
            case 71...84:
                return tripPrompt(placeName: nil)
            default:
                return storyPrompt(for: date, placeName: nil, calendar: calendar)
            }
        }

        if let cleanPlace {
            let roll = Int.random(in: 1...100)

            switch roll {
            case 1...55:
                return cityPrompt(placeName: cleanPlace)
            case 56...80:
                return tripPrompt(placeName: cleanPlace)
            default:
                return storyPrompt(for: nil, placeName: cleanPlace, calendar: calendar)
            }
        }

        return feelingPrompt()
    }

    static func yearPrompt(for date: Date, calendar: Calendar = .current) -> MemoryQuizPrompt {
        let year = calendar.component(.year, from: date)
        let answer = String(year)

        return MemoryQuizPrompt(
            kind: .year,
            question: "What year was this?",
            options: yearOptions(correctYear: year).shuffled(),
            answer: answer,
            confirmation: "This was from \(answer).",
            symbolName: "calendar"
        )
    }

    static func monthPrompt(for date: Date, calendar: Calendar = .current) -> MemoryQuizPrompt {
        let month = calendar.component(.month, from: date)
        let monthNames = calendar.monthSymbols
        let answer = monthNames[month - 1]

        return MemoryQuizPrompt(
            kind: .month,
            question: "Which month was it?",
            options: monthOptions(correctMonth: month, calendar: calendar).shuffled(),
            answer: answer,
            confirmation: "This photo was taken in \(answer).",
            symbolName: "sun.max"
        )
    }

    static func seasonPrompt(for date: Date, calendar: Calendar = .current) -> MemoryQuizPrompt {
        let month = calendar.component(.month, from: date)
        let answer = seasonName(forMonth: month)

        return MemoryQuizPrompt(
            kind: .season,
            question: "What season was this?",
            options: ["Spring", "Summer", "Fall", "Winter"].shuffled(),
            answer: answer,
            confirmation: "This was a \(answer.lowercased()) memory.",
            symbolName: "leaf.fill"
        )
    }

    static func cityPrompt(placeName: String) -> MemoryQuizPrompt {
        let cleanPlace = cleanedPlaceName(placeName) ?? placeName
        let city = cityName(from: cleanPlace)

        return MemoryQuizPrompt(
            kind: .city,
            question: "What city were you in?",
            options: cityOptions(correctCity: city).shuffled(),
            answer: city,
            confirmation: "This was around \(cleanPlace).",
            symbolName: "building.2.crop.circle.fill"
        )
    }

    static func placePrompt(placeName: String) -> MemoryQuizPrompt {
        cityPrompt(placeName: placeName)
    }

    static func tripPrompt(placeName: String? = nil) -> MemoryQuizPrompt {
        let cleanPlace = cleanedPlaceName(placeName)
        let confirmation = cleanPlace.map { "Nice. \($0) is the doorway; the story is the good part." }
            ?? "Nice. The point is to unlock the story, not grade the memory."

        return MemoryQuizPrompt(
            kind: .feeling,
            question: "Was this a trip or close to home?",
            options: ["A trip", "Close to home", "Visiting family", "A day out"].shuffled(),
            answer: "A trip",
            confirmation: confirmation,
            symbolName: "suitcase.rolling.fill"
        )
    }

    static func weekBeforePrompt(for date: Date, placeName: String?, calendar: Calendar = .current) -> MemoryQuizPrompt {
        let oneWeekEarlier = calendar.date(byAdding: .day, value: -7, to: date) ?? date
        let dateText = oneWeekEarlier.formatted(.dateTime.month(.abbreviated).day())
        let city = cleanedPlaceName(placeName).map(cityName(from:))
        let placeHint = city.map { "before \($0)" } ?? "before this"

        return MemoryQuizPrompt(
            kind: .feeling,
            question: "One week \(placeHint), what was life like?",
            options: ["Getting ready", "Already traveling", "Seeing family", "Normal routine"].shuffled(),
            answer: "Getting ready",
            confirmation: "Around \(dateText), that little before-and-after can bring back the real story.",
            symbolName: "clock.arrow.circlepath"
        )
    }

    static func storyPrompt(for date: Date? = nil, placeName: String? = nil, calendar: Calendar = .current) -> MemoryQuizPrompt {
        let cleanPlace = cleanedPlaceName(placeName)

        if let cleanPlace {
            let city = cityName(from: cleanPlace)

            return MemoryQuizPrompt(
                kind: .feeling,
                question: "What do you remember most about \(city)?",
                options: ["The people", "The food", "The reason you went", "The feeling"].shuffled(),
                answer: "The people",
                confirmation: "That is the thread worth pulling.",
                symbolName: "bubble.left.and.text.bubble.right.fill"
            )
        }

        if let date {
            let season = seasonName(forMonth: calendar.component(.month, from: date)).lowercased()

            return MemoryQuizPrompt(
                kind: .feeling,
                question: "What kind of \(season) memory is this?",
                options: ["Family time", "A vacation", "A celebration", "Everyday life"].shuffled(),
                answer: "Family time",
                confirmation: "Good. That is exactly the kind of cue MemoryLane is for.",
                symbolName: "sparkles"
            )
        }

        return feelingPrompt()
    }

    static func feelingPrompt() -> MemoryQuizPrompt {
        MemoryQuizPrompt(
            kind: .feeling,
            question: "What does this bring back?",
            options: ["A smile", "A story", "A person", "A place"].shuffled(),
            answer: "A story",
            confirmation: "Some photos are here to open a door, not test a fact.",
            symbolName: "sparkles"
        )
    }

    static func yearOptions(correctYear: Int) -> [String] {
        [correctYear - 6, correctYear - 2, correctYear, correctYear + 3]
            .filter { $0 > 1900 }
            .map(String.init)
    }

    static func monthOptions(correctMonth: Int, calendar: Calendar = .current) -> [String] {
        let monthNames = calendar.monthSymbols
        let nearbyMonths = [correctMonth, correctMonth + 2, correctMonth + 5, correctMonth + 8]
            .map { (($0 - 1) % 12) + 1 }

        return nearbyMonths.map { monthNames[$0 - 1] }
    }

    static func cityOptions(correctCity: String) -> [String] {
        var options = [correctCity]
        let decoys = [
            "New York City",
            "Los Angeles",
            "Chicago",
            "Miami",
            "San Francisco",
            "Seattle",
            "Denver",
            "Boston",
            "Austin",
            "Phoenix",
            "Las Vegas",
            "Nashville"
        ].shuffled()

        for city in decoys where city.caseInsensitiveCompare(correctCity) != .orderedSame {
            options.append(city)

            if options.count == 4 {
                break
            }
        }

        return options
    }

    private static func cleanedPlaceName(_ placeName: String?) -> String? {
        guard let placeName else { return nil }

        let cleanPlace = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanPlace.isEmpty ? nil : cleanPlace
    }

    private static func cityName(from placeName: String) -> String {
        let firstPart = placeName.split(separator: ",").first.map(String.init) ?? placeName
        let city = firstPart.trimmingCharacters(in: .whitespacesAndNewlines)
        return city.isEmpty ? placeName : city
    }

    private static func seasonName(forMonth month: Int) -> String {
        switch month {
        case 3...5:
            return "Spring"
        case 6...8:
            return "Summer"
        case 9...11:
            return "Fall"
        default:
            return "Winter"
        }
    }
}
