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
        if let placeName, !placeName.isEmpty, Bool.random() {
            return placePrompt(placeName: placeName)
        }

        if let date {
            return Bool.random()
                ? yearPrompt(for: date, calendar: calendar)
                : monthPrompt(for: date, calendar: calendar)
        }

        if let placeName, !placeName.isEmpty {
            return placePrompt(placeName: placeName)
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

    static func placePrompt(placeName: String) -> MemoryQuizPrompt {
        let cleanPlace = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let decoys = ["At home", "On a trip", "With family", "A favorite spot"]
            .filter { $0 != cleanPlace }

        return MemoryQuizPrompt(
            kind: .place,
            question: "Where was this?",
            options: ([cleanPlace] + decoys.prefix(3)).shuffled(),
            answer: cleanPlace,
            confirmation: "This was near \(cleanPlace).",
            symbolName: "mappin.and.ellipse"
        )
    }

    static func feelingPrompt() -> MemoryQuizPrompt {
        MemoryQuizPrompt(
            kind: .feeling,
            question: "What does this bring back?",
            options: ["A smile", "A story", "A person", "A place"],
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
}
