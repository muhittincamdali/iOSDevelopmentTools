import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A `:` between two digits is part of a number only after a number. The fifth review of this
/// branch showed that reading every such `:` as part of a time let the value of a key that ends in
/// digits through (`curl -u admin1:2…`, `redis-cli -a db1:2…`, `user1:2345678901`), in a line, a
/// JSON string, a form value, a text/plain body and an allowed header alike.
@Suite("Redaction corpus: colons between digits")
struct RedactionNumberColonTests {
    let redactor = Redactor()
    static let secret = "2345678901"

    @Test("after a key that ends in digits, a colon is a separator", arguments: [
        "user1:2345678", "acct2:44556677", "phone1:905551234567", "user_id2:998877", "status=ok retry3:5", "user\u{FF11}:\u{FF12}345678",
        "user1:2345", "item2-1:2345", "db.port1:5432", "T1:2345", "v1.2:3", "id-9:12", "a.b.1:44",
    ])
    func keyEndingInDigits(input: String) {
        let output = redactor.redact(input)
        #expect(output.hasSuffix("[REDACTED]"), "\(input.debugDescription) -> \(output.debugDescription)")
        #expect(!output.contains("2345") && !output.contains("4455") && !output.contains("9988"), "\(input.debugDescription) -> \(output.debugDescription)")
    }

    @Test("times, dates and times, and addresses with ports are kept", arguments: [
        "at 12:30", "at 12:30:45", "2026-10-19T12:30:45Z", "2026-10-19T12:30:45.123+03:00", "2026-10-19T12:30:45-05:00",
        "connect 10.0.0.1:8080 ok", "connect 192.168.1.100:8080 ok", "took 1:05", "(12:30)", "[12:30:45] started", "line 42:10",
    ])
    func numbersAreKept(input: String) {
        #expect(redactor.redact(input) == input)
    }

    /// The reviews' commands and lines, in every place free text is read.
    @Test("the review's commands hide the value after the key in every place", arguments: [
        "curl -u admin1:\(secret) https://x.example", "redis-cli -a db1:\(secret) ping", "user1:\(secret)", "login user1:\(secret) ok",
    ])
    func reviewCommands(line: String) {
        var outputs = RedactionWrittenURLTests.places(line).map(\.1)
        let header = RedactionPolicy.default.redact(headers: [HTTPHeader(name: "User-Agent", value: line)])[0].value
        outputs.append(header)
        let encoded = "note=" + line.replacingOccurrences(of: ":", with: "%3A").replacingOccurrences(of: " ", with: "+")
        outputs.append(Redactor(allowedTextKeys: ["note"]).redact(body: Data(encoded.utf8), contentType: "application/x-www-form-urlencoded"))
        for output in outputs {
            #expect(!output.contains(Self.secret), "\(line.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("a colon after digits glued to a key cuts a JSON string and a form value too")
    func structuredPaths() {
        let json = redactor.redact(body: Data(#"{"note":"acct2:44556677","status":"12:30"}"#.utf8), contentType: "application/json")
        #expect(json == #"{"note":"acct2:[REDACTED]","status":"12:30"}"#)
        let form = redactor.redact(body: Data("note=acct2%3A44556677".utf8), contentType: "application/x-www-form-urlencoded")
        #expect(!form.contains("44556677"), "\(form)")
        #expect(redactor.redact(body: Data(#"{"note":"at 12:30:45"}"#.utf8), contentType: "application/json") == #"{"note":"at 12:30:45"}"#)
        #expect(redactor.redact(body: Data("ts 2026-10-19T12:30:00Z ok".utf8), contentType: "text/plain") == "ts 2026-10-19T12:30:00Z ok")
    }

    @Test("a number longer than the colon rule reads is a key")
    func longNumbers() {
        let long = String(repeating: "1-", count: FreeTextScanner.longestNumber) + "1:2345"
        #expect(!redactor.redact(long).contains("2345"))
        #expect(redactor.redact("1-1-1:2345") == "1-1-1:2345")
    }
}
