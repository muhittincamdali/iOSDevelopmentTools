import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The table of readings of characters outside ASCII (``CompatibilityText``), from section 5 of the
/// redaction spec: fixed in size (direct-mapped), never grown when two characters meet, and one
/// for a whole text, body, URL or list of headers. The seventeenth review measured 15 MiB of
/// readings for a megabyte of different characters, kept in dictionaries that grew with each one,
/// and a table made for every form field, multipart part, path segment, query value and header.
@Suite("Redaction corpus: the table of readings")
struct RedactionCompatibilityTableTests {
    /// Scalars outside ASCII that are not ideographs or Hangul syllables, so each is read through
    /// Foundation once it is not in the table.
    static func differentScalars(_ count: Int, from start: UInt32 = 0x40000) -> [Unicode.Scalar] {
        (start..<(start + UInt32(count))).compactMap(Unicode.Scalar.init)
    }

    @Test("ASCII text makes no table, and a short text a small one")
    func sizes() {
        let ascii = CompatibilityText(length: 1_000_000)
        for scalar in "status=200 method=GET".unicodeScalars { _ = ascii.ascii(scalar) }
        #expect(ascii.slotCount == 0)
        let short = CompatibilityText(length: 3)
        _ = short.ascii("é")
        #expect(short.slotCount == CompatibilityText.fewestSlots)
        let long = CompatibilityText(length: 1_000_000)
        _ = long.ascii("é")
        #expect(long.slotCount == CompatibilityText.mostSlots)
    }

    @Test("the table never grows, however many different characters are read")
    func neverGrows() {
        let table = CompatibilityText(length: 1_000_000)
        let scalars = Self.differentScalars(50_000)
        for scalar in scalars {
            _ = table.ascii(scalar)
            _ = table.formLeavesSafeAlphabet(scalar)
            _ = table.foldsToASCII(scalar)
        }
        #expect(table.slotCount == CompatibilityText.mostSlots)
        // One normalization serves the reading and both questions about a character just read.
        #expect(table.uncachedReadings == scalars.count)
    }

    @Test("a character that comes again is read once")
    func repeatedCharacters() {
        let table = CompatibilityText(length: 100)
        for _ in 0..<1_000 { _ = table.ascii("é") }
        #expect(table.uncachedReadings == 1)
    }

    @Test("characters that meet in a slot take it over and the table keeps its size")
    func meetingCharacters() {
        // With a multiplier of 1 every scalar of the planes meets in the first slot.
        let table = CompatibilityText(length: 16, multiplier: 1)
        for _ in 0..<10 {
            for scalar in "é ü ı".unicodeScalars where !scalar.isASCII { _ = table.ascii(scalar) }
        }
        #expect(table.slotCount == CompatibilityText.fewestSlots)
        #expect(table.uncachedReadings == 30)
        #expect(Array(table.ascii("é")) == [UInt8(ascii: "e")])
    }

    @Test("ideographs and Hangul syllables are read as Foundation reads them, and every reading fits in place")
    func readings() {
        var longest = 0
        for value in UInt32(0x80)...0x10FFFF {
            guard let scalar = Unicode.Scalar(value) else { continue }
            if CompatibilityText.readsOutsideASCII(scalar) {
                #expect(CompatibilityText.decomposedReading(scalar) == CompatibilityText.outsideASCII, "U+\(String(value, radix: 16))")
                continue
            }
            longest = max(longest, CompatibilityText.read(scalar).bytes.count)
        }
        #expect(longest <= 4)
    }

    /// A table in which the slot of a scalar is its value modulo the number of slots, so that `é`
    /// and `ü` never meet.
    static func table() -> CompatibilityText { CompatibilityText(length: CompatibilityText.mostSlots, multiplier: 1 << 52) }

    @Test("a form, a multipart body, a URL and a header read with one table")
    func oneTablePerInput() throws {
        let policy = RedactionPolicy.default
        let form = String(repeating: "note=caf%C3%A9&", count: 50) + "x=%C3%A9"
        let formTable = Self.table()
        let type = try #require(MediaType("application/x-www-form-urlencoded"))
        _ = policy.redact(body: Data(form.utf8), as: type, nesting: .document(length: form.utf8.count), compatibility: formTable)
        #expect(formTable.uncachedReadings == 1)

        let part = "--B\r\nContent-Disposition: form-data; name=\"note\"\r\nContent-Language: fr\r\n\r\ncafé\r\n"
        let multipart = String(repeating: part, count: 20) + "--B--\r\n"
        let multipartTable = Self.table()
        let multipartType = try #require(MediaType("multipart/form-data; boundary=B"))
        _ = policy.redact(body: Data(multipart.utf8), as: multipartType, nesting: .document(length: multipart.utf8.count), compatibility: multipartTable)
        #expect(multipartTable.uncachedReadings == 1)

        let url = "https://x.example/caf%C3%A9/men%C3%BC/caf%C3%A9-x/m%C3%BCnchen?q=%C3%A9&r=%C3%BC"
        let urlTable = Self.table()
        _ = RedactionPolicy(allowedQueryParameters: ["q", "r"]).redactedURL(url, nesting: .document(length: url.utf8.count), compatibility: urlTable)
        #expect(urlTable.uncachedReadings == 2)

        let headerTable = Self.table()
        for value in ["text/html; charset=utf-8 é", "MyApp/1.0 é ü", "ü"] {
            _ = policy.redactedHeaderValue(name: "User-Agent", value: value, compatibility: headerTable)
        }
        #expect(headerTable.uncachedReadings == 2)
    }
}
