import Foundation

/// Finds values that look like secrets or personal data whatever key they are under: JWTs,
/// bearer tokens, long hex or Base64 strings, card numbers (Luhn), IBANs (mod 97) and email
/// addresses. Everything works on Unicode scalars, never on `Character`s.
enum ValueDetectors {
    /// Hex and Base64 strings at least this long are hidden.
    static let longTokenLength = 32

    /// The scalars with every detected value replaced by ``RedactionPolicy/replacement``, and
    /// whether anything was replaced.
    static func redacting(_ scalars: [Unicode.Scalar]) -> (scalars: [Unicode.Scalar], changed: Bool) {
        let ranges = merged(secretRanges(in: scalars))
        guard !ranges.isEmpty else { return (scalars, false) }
        var output: [Unicode.Scalar] = []
        output.reserveCapacity(scalars.count)
        var index = 0
        for range in ranges {
            output += scalars[index..<range.lowerBound]
            output += RedactionPolicy.replacement.unicodeScalars
            index = range.upperBound
        }
        output += scalars[index...]
        return (output, true)
    }

    static func secretRanges(in scalars: [Unicode.Scalar]) -> [Range<Int>] {
        jsonWebTokens(in: scalars) + bearerTokens(in: scalars) + longTokens(in: scalars)
            + Checksums.cardNumbers(in: scalars) + Checksums.ibans(in: scalars) + emailAddresses(in: scalars)
    }

    private static func merged(_ ranges: [Range<Int>]) -> [Range<Int>] {
        var result: [Range<Int>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }

    // MARK: Character classes

    static func isDigit(_ scalar: Unicode.Scalar) -> Bool { ("0"..."9").contains(scalar) }

    static func isLetter(_ scalar: Unicode.Scalar) -> Bool { ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) }

    static func isLetterOrDigit(_ scalar: Unicode.Scalar) -> Bool { isLetter(scalar) || isDigit(scalar) }

    private static func asciiLowercased(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        ("A"..."Z").contains(scalar) ? Unicode.Scalar(UInt8(scalar.value + 0x20)) : scalar
    }

    private static func isHexDigit(_ scalar: Unicode.Scalar) -> Bool {
        isDigit(scalar) || ("a"..."f").contains(scalar) || ("A"..."F").contains(scalar)
    }

    private static func isBase64URL(_ scalar: Unicode.Scalar) -> Bool {
        isLetterOrDigit(scalar) || scalar == "-" || scalar == "_"
    }

    private static func isBase64(_ scalar: Unicode.Scalar) -> Bool {
        isBase64URL(scalar) || scalar == "+" || scalar == "/"
    }

    // MARK: Detectors

    /// `eyJ…` header, payload and an optional signature, separated by dots.
    static func jsonWebTokens(in scalars: [Unicode.Scalar]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var index = 0
        while index + 3 <= scalars.count {
            let startsToken = scalars[index] == "e" && scalars[index + 1] == "y" && scalars[index + 2] == "J"
            if startsToken, index == 0 || !isBase64URL(scalars[index - 1]), let end = jsonWebTokenEnd(scalars, from: index) {
                ranges.append(index..<end)
                index = end
            } else {
                index += 1
            }
        }
        return ranges
    }

    private static func jsonWebTokenEnd(_ scalars: [Unicode.Scalar], from start: Int) -> Int? {
        var index = start
        for segment in 0..<3 {
            let segmentStart = index
            while index < scalars.count, isBase64URL(scalars[index]) { index += 1 }
            guard segment < 2 else { break }
            guard index > segmentStart, index < scalars.count, scalars[index] == "." else { return nil }
            index += 1
        }
        return index
    }

    /// The credentials after the word `Bearer`, in any case: everything up to the next white
    /// space, after skipping what cannot start a token (white space of any kind, a comma, a
    /// combining mark), so `Bearer\u{A0}abc` and `Bearer \u{301}abc` are found too.
    static func bearerTokens(in scalars: [Unicode.Scalar]) -> [Range<Int>] {
        let word = Array("bearer".unicodeScalars)
        var ranges: [Range<Int>] = []
        var index = 0
        while index + word.count < scalars.count {
            let matches = (0..<word.count).allSatisfy { asciiLowercased(scalars[index + $0]) == word[$0] }
            guard matches, index == 0 || !isLetterOrDigit(scalars[index - 1]), !isLetterOrDigit(scalars[index + word.count]) else {
                index += 1
                continue
            }
            var tokenStart = index + word.count
            while tokenStart < scalars.count, !isBase64(scalars[tokenStart]) { tokenStart += 1 }
            var end = tokenStart
            while end < scalars.count, !scalars[end].properties.isWhitespace { end += 1 }
            if end > tokenStart { ranges.append(tokenStart..<end) }
            index = max(end, index + 1)
        }
        return ranges
    }

    /// Runs of 32 or more hex digits, or of Base64 characters with letters and digits. A run of
    /// hex digits and hyphens only, such as a UUID, is an identifier and is kept; a run with many
    /// slashes is a path and is kept.
    static func longTokens(in scalars: [Unicode.Scalar]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var index = 0
        while index < scalars.count {
            guard isBase64(scalars[index]) else {
                index += 1
                continue
            }
            let start = index
            var digits = 0, letters = 0, slashes = 0, hyphens = 0, nonHex = 0
            while index < scalars.count, isBase64(scalars[index]) {
                let scalar = scalars[index]
                if isDigit(scalar) { digits += 1 } else if isLetter(scalar) { letters += 1 }
                if scalar == "/" { slashes += 1 } else if scalar == "-" { hyphens += 1 }
                if !isHexDigit(scalar), scalar != "-" { nonHex += 1 }
                index += 1
            }
            let length = index - start
            var end = index
            while end < scalars.count, end - index < 2, scalars[end] == "=" { end += 1 }
            guard length >= longTokenLength else { continue }
            let isHex = nonHex == 0 && hyphens == 0
            let isHyphenatedHex = nonHex == 0 && hyphens > 0
            let isBase64Token = digits > 0 && letters > 0 && slashes * 8 < length
            if isHex || (!isHyphenatedHex && isBase64Token) { ranges.append(start..<end) }
        }
        return ranges
    }

    /// `local@domain.tld` with ASCII characters.
    static func emailAddresses(in scalars: [Unicode.Scalar]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        for at in scalars.indices where scalars[at] == "@" {
            var start = at
            while start > 0, isEmailLocal(scalars[start - 1]) { start -= 1 }
            var end = at + 1
            while end < scalars.count, isLetterOrDigit(scalars[end]) || scalars[end] == "." || scalars[end] == "-" { end += 1 }
            while end > at + 1, scalars[end - 1] == "." || scalars[end - 1] == "-" { end -= 1 }
            guard start < at, let dot = scalars[(at + 1)..<end].lastIndex(of: "."), dot > at + 1 else { continue }
            let topLevel = scalars[(dot + 1)..<end]
            guard topLevel.count >= 2, topLevel.allSatisfy(isLetter) else { continue }
            ranges.append(start..<end)
        }
        return ranges
    }

    private static func isEmailLocal(_ scalar: Unicode.Scalar) -> Bool {
        isLetterOrDigit(scalar) || "._%+-".unicodeScalars.contains(scalar)
    }
}
