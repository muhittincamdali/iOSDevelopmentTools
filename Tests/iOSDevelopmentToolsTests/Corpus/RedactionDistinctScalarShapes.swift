import Foundation
@testable import iOSDevelopmentTools

/// A megabyte of different characters outside ASCII, each written once, as the seventeenth review
/// measured it: 17.5 MiB of memory for free text, a kept header value and the shapes of a body, all
/// of it in readings that a dictionary kept for every character, each with an array of its own.
/// Characters from U+40000 on are unassigned, so each is read through Foundation; those from U+4E00
/// on are letters of the Basic Multilingual Plane, most of them ideographs.
enum DistinctScalarShapes {
    /// Words of `word` different scalars from `start` on, every scalar once, to about `bytes`
    /// bytes with a byte of `overhead` for each word.
    static func words(bytes: Int = RedactionTimeLimitTests.size, word: Int = 10, from start: UInt32 = 0x40000, overhead: Int = 1) -> [String] {
        var words: [String] = []
        var current = String.UnicodeScalarView()
        var value = start
        var total = 2
        while total < bytes - 40 {
            defer { value += 1 }
            guard let scalar = Unicode.Scalar(value) else { continue }
            current.append(scalar)
            guard current.count == word else { continue }
            let text = String(current)
            total += text.utf8.count + overhead
            words.append(text)
            current = String.UnicodeScalarView()
        }
        return words
    }

    private static func text() -> String { words().joined(separator: " ") }

    static let all: [TimedInput] = {
        let redactor = Redactor.largeBodies
        let header: @Sendable (String) -> String = { RedactionPolicy.default.redact(headers: [HTTPHeader(name: "User-Agent", value: $0)])[0].value }
        return [
            TimedInput(testDescription: "a megabyte of text of different characters", make: text, redact: redactor.redact),
            TimedInput(testDescription: "a megabyte of text of different letters", make: {
                words(from: 0x4E00).joined(separator: " ")
            }, redact: redactor.redact),
            TimedInput(testDescription: "a kept header value of a megabyte of different characters", make: text, redact: header),
            TimedInput(testDescription: "a plain-text body of a megabyte of different characters", make: text, redact: {
                redactor.redact(body: Data($0.utf8), contentType: "text/plain")
            }),
            TimedInput(testDescription: "a JSON array of strings of a megabyte of different characters", make: {
                "[" + words(overhead: 3).map { "\"\($0)\"" }.joined(separator: ",") + "]"
            }, redact: { redactor.redact(body: Data($0.utf8), contentType: "application/json") }),
        ]
    }()

    /// A log message of a million different characters, about four megabytes, which is shorter in
    /// scalars than ``LogStore/maximumRedactedMessageLength`` and so is redacted whole.
    static func logMessage() -> String {
        words(bytes: 4_160_000, word: 1_000, from: 0x10000).joined(separator: " ") + "\n"
    }
}
