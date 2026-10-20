import Foundation
@testable import iOSDevelopmentTools

/// A megabyte of JSON written in one JSON string, one to three times, and a megabyte string full
/// of quotes or line breaks that a value detector changes. The third review of 2.1.0 timed them at
/// 1.4 to 4.9 seconds a megabyte in a release build, growing with the square of the length (1.9 s
/// for one megabyte, 6.3 s for two, 23.6 s for four): a string that the free-text rule changed
/// was escaped again into a `String.UnicodeScalarView`, and every escape copied what was written
/// before it.
extension RedactionTimeLimitTests {
    private static let oneStringRedactor = Redactor()

    /// An object of the review, with Turkish letters, a non-ASCII key and two secrets.
    static let turkishObject = #"{"ad":"Iğdır ılık ışık","şifre":"GizliParola1","password":"hunter2"}"#
    /// The same object without a secret.
    static let turkishObjectWithoutSecret = #"{"ad":"Iğdır ılık ışık","durum":"başarılı","adet":3}"#

    /// A JSON array of `count` times `unit`, written as the string of `{"data":…}` `levels` times.
    static func inOneString(_ unit: String, count: Int, levels: Int) -> String {
        var text = "[" + Array(repeating: unit, count: count).joined(separator: ",") + "]"
        for _ in 0..<levels { text = "{\"data\":\"" + RedactionStackTests.escaped(text) + "\"}" }
        return text
    }

    /// ``inOneString(_:count:levels:)`` with as many units as make about `total` bytes: each
    /// level escapes a fixed number of bytes per unit, so the length grows in a straight line.
    static func inOneString(_ unit: String, levels: Int, total: Int = size) -> String {
        let one = inOneString(unit, count: 100, levels: levels).utf8.count
        let two = inOneString(unit, count: 200, levels: levels).utf8.count
        let perUnit = (two - one) / 100
        return inOneString(unit, count: max(1, (total - one) / perUnit + 100), levels: levels)
    }

    /// A JSON object with one string of about a megabyte: `unit` repeated, then `last`.
    static func oneLongString(_ unit: String, then last: String, total: Int = size) -> String {
        let prefix = "{\"msg\":\""
        let suffix = last + "\"}"
        return prefix + String(repeating: unit, count: (total - prefix.utf8.count - suffix.utf8.count) / unit.utf8.count) + suffix
    }

    private static func oneStringBody(_ text: String) -> String {
        oneStringRedactor.redact(body: Data(text.utf8), contentType: "application/json")
    }

    static let oneStringPayloads: [TimedInput] = (1...3).flatMap { levels in
        [
            TimedInput(testDescription: "a JSON body of Turkish objects with secrets in one string, \(levels) levels", make: {
                inOneString(turkishObject, levels: levels)
            }, redact: oneStringBody),
            TimedInput(testDescription: "a log line of Turkish objects with secrets in one string, \(levels) levels", make: {
                "yanıt " + inOneString(turkishObject, levels: levels, total: size - 8)
            }, redact: oneStringRedactor.redact),
            TimedInput(testDescription: "a log line of Turkish objects without a secret in one string, \(levels) levels", make: {
                "yanıt " + inOneString(turkishObjectWithoutSecret, levels: levels, total: size - 8)
            }, redact: oneStringRedactor.redact),
        ]
    } + [
        TimedInput(testDescription: "a JSON body of one string of quotes, then an email address", make: {
            oneLongString("say \\\"hi\\\" ", then: "ayse@ornek.com")
        }, redact: oneStringBody),
        TimedInput(testDescription: "a JSON body of one string of escaped line breaks, then an email address", make: {
            oneLongString("INFO request ok\\n", then: "mail ayse@ornek.com")
        }, redact: oneStringBody),
        TimedInput(testDescription: "a JSON body of one string of escaped line breaks, then a secret name", make: {
            oneLongString("INFO request ok\\n", then: "password hunter2")
        }, redact: oneStringBody),
        TimedInput(testDescription: "a log line of JSON with one string of quotes, then an email address", make: {
            oneLongString("say \\\"hi\\\" ", then: "ayse@ornek.com")
        }, redact: oneStringRedactor.redact),
    ]
}
