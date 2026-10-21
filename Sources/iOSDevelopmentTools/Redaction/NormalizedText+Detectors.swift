import Foundation

/// The value detectors read across a vertical tab, a form feed, U+0085, U+2028 and U+2029 (see
/// ``NormalizedText/isBridgedLineBreak(_:)``): as white space between the groups of a card number
/// or an IBAN and after `Bearer`, and as nothing inside an email address, a JSON Web Token and a
/// long token, which white space would end. A finding never starts or ends with one.
extension NormalizedText {
    // MARK: Card numbers

    func cardSpans() -> [RedactionPolicy.Span] {
        var spans: [RedactionPolicy.Span] = []
        var i = 0
        while i < count {
            guard isDigit(i), i == 0 || !gluesToWord(i - 1) else {
                i += 1
                continue
            }
            // Digit groups separated by up to three spaces, tabs, dashes or line separators, read
            // through a window of the groups a card number can still span: a megabyte of
            // `4242 4242 …` is one chain of groups, which an array of them all held in memory.
            var window = CardWindow()
            var groupStart = i
            var j = i
            while j < count {
                if isDigit(j) {
                    j += 1
                    continue
                }
                var separatorEnd = j
                while separatorEnd < count, separatorEnd - j < 3, isCardSeparator(separatorEnd) {
                    separatorEnd += 1
                }
                guard separatorEnd > j, separatorEnd < count, isDigit(separatorEnd) else { break }
                window.append(groupStart..<j, into: &spans, in: self)
                groupStart = separatorEnd
                j = separatorEnd
            }
            // Digits that run into letters are an identifier, not a card number.
            let runsIntoLetters = j < count && isLetter(j) && gluesToWord(j)
            window.finish(last: runsIntoLetters ? nil : groupStart..<j, into: &spans, in: self)
            i = max(j, i + 1)
        }
        return spans
    }

    private func isCardSeparator(_ i: Int) -> Bool {
        bytes[i] == UInt8(ascii: " ") || bytes[i] == UInt8(ascii: "-") || bytes[i] == UInt8(ascii: "\t") || isBridgedLineBreak(i)
    }

    /// Card numbers written in groups have at most this many digits per group (4-4-4-4, 4-6-5).
    static let maximumCardGroupLength = 6

    /// The digit groups of a chain that a card number may still start in. From each group on, the
    /// longest run of consecutive groups that holds 13 to 19 digits and passes the Luhn check is a
    /// card number, and the next run starts after it. A run of several groups holds groups of at
    /// most ``maximumCardGroupLength`` digits, so the digits of a UUID
    /// (`73297603-2915-4643-B7F3-FD58D90F216C`) are not read as a card.
    ///
    /// The runs from a group are read once the groups from it hold more than 19 digits: a run
    /// then ends before the next group is known. Only the last group of a chain may still be
    /// dropped (when it runs into letters), and it is never read before the chain is finished. So
    /// the window holds the groups of 19 digits at most and the groups already read, which it
    /// drops every 64 of them.
    private struct CardWindow {
        private var groups: [Range<Int>] = []
        private var first = 0

        /// Adds a group that another group follows.
        mutating func append(_ group: Range<Int>, into spans: inout [RedactionPolicy.Span], in text: NormalizedText) {
            groups.append(group)
            while first < groups.count, holdsMoreThanACard(from: first) {
                read(into: &spans, in: text)
            }
            if first > 64 {
                groups.removeFirst(first)
                first = 0
            }
        }

        /// Adds the last group of the chain, unless it is dropped, and reads the runs left.
        mutating func finish(last: Range<Int>?, into spans: inout [RedactionPolicy.Span], in text: NormalizedText) {
            if let last { groups.append(last) }
            while first < groups.count { read(into: &spans, in: text) }
        }

        private func holdsMoreThanACard(from start: Int) -> Bool {
            var digits = 0
            for k in start..<groups.count {
                digits += groups[k].count
                if digits > 19 { return true }
            }
            return false
        }

        /// The card number that starts in group `first`, if any, and the group the next one may
        /// start in.
        private mutating func read(into spans: inout [RedactionPolicy.Span], in text: NormalizedText) {
            var digits: [UInt8] = []
            var best: Int?
            var last = first
            groups: while last < groups.count {
                let isLongGroup = groups[first].count > maximumCardGroupLength || groups[last].count > maximumCardGroupLength
                if last > first, isLongGroup { break }
                for k in groups[last] {
                    digits.append(text.bytes[k] - UInt8(ascii: "0"))
                    if digits.count > 19 { break groups }
                }
                if digits.count >= 13, NormalizedText.passesLuhn(digits) { best = last }
                last += 1
            }
            guard let best else {
                first += 1
                return
            }
            spans.append(text.span(groups[first].lowerBound..<groups[best].upperBound))
            first = best + 1
        }

        private var maximumCardGroupLength: Int { NormalizedText.maximumCardGroupLength }
    }

    static func passesLuhn(_ digits: [UInt8]) -> Bool {
        var sum = 0
        for (position, digit) in digits.reversed().enumerated() {
            var value = Int(digit)
            if position % 2 == 1 {
                value *= 2
                if value > 9 { value -= 9 }
            }
            sum += value
        }
        return sum % 10 == 0
    }

    // MARK: Email addresses

    /// An address: a name of letters, marks and digits of any script and `.`, `_`, `%`, `+` and
    /// `-` (`ayşe.yılmaz`, `bjørn.dæhlie`, `张伟`), `@`, and a domain of such letters and digits,
    /// `.` and `-` that ends in a top-level domain of two or more letters (`example.com`,
    /// `例子.中国`). The whole address is one finding.
    func emailSpans() -> [RedactionPolicy.Span] {
        var spans: [RedactionPolicy.Span] = []
        for at in 0..<count where bytes[at] == UInt8(ascii: "@") {
            var start = at
            while start > 0, isLocalPart(start - 1) { start -= 1 }
            while start < at, bytes[start] == UInt8(ascii: ".") || isBridgedLineBreak(start) { start += 1 }
            var end = at + 1
            while end < count, isAnyAlphanumeric(end) || bytes[end] == UInt8(ascii: ".") || bytes[end] == UInt8(ascii: "-") || isBridgedLineBreak(end) {
                end += 1
            }
            while end > at + 1, bytes[end - 1] == UInt8(ascii: ".") || bytes[end - 1] == UInt8(ascii: "-") || isBridgedLineBreak(end - 1) { end -= 1 }
            guard start < at, end > at + 1, isDomain(at + 1..<end) else { continue }
            spans.append(span(start..<end))
        }
        return spans
    }

    private func isLocalPart(_ i: Int) -> Bool {
        isAnyAlphanumeric(i) || Self.localPartMarks.contains(bytes[i]) || isBridgedLineBreak(i)
    }

    private static let localPartMarks = ByteSet("._%+-")

    private func isDomain(_ range: Range<Int>) -> Bool {
        guard let lastDot = range.last(where: { bytes[$0] == UInt8(ascii: ".") }), lastDot > range.lowerBound else { return false }
        let topLevel = (lastDot + 1)..<range.upperBound
        return topLevel.count >= 2 && topLevel.allSatisfy(isAnyLetter)
    }

    // MARK: JSON Web Tokens

    func jsonWebTokenSpans() -> [RedactionPolicy.Span] {
        let prefix = Array("eyJ".utf8)
        var spans: [RedactionPolicy.Span] = []
        var i = 0
        while i + 3 <= count {
            // A token glued to a word by `_` or `-` (`id_eyJ…`) is still a token.
            guard bytes[i] == prefix[0], bytes[i + 1] == prefix[1], bytes[i + 2] == prefix[2], i == 0 || !gluesToWord(i - 1) else {
                i += 1
                continue
            }
            var j = i
            var segments = 0
            // The characters of each segment, without the line separators read across in it.
            var segmentLengths: [Int] = []
            var headerEnd = i
            while true {
                let segmentStart = j
                var length = 0
                while j < count, isBase64URL(j) || isBridgedLineBreak(j) {
                    if !isBridgedLineBreak(j) { length += 1 }
                    j += 1
                }
                // A token does not end with a line separator; the text goes on after it.
                while j > segmentStart, isBridgedLineBreak(j - 1) { j -= 1 }
                if segments == 0 { headerEnd = j }
                segmentLengths.append(length)
                segments += 1
                let dot = skippingBridgedLineBreaks(from: j)
                guard segments < 5, dot < count, bytes[dot] == UInt8(ascii: ".") else { break }
                // The signature (third segment) is empty in unsecured tokens ("alg": "none").
                let next = skippingBridgedLineBreaks(from: dot + 1)
                let nextIsSegment = next < count && isBase64URL(next)
                guard nextIsSegment || segments == 2 else { break }
                j = nextIsSegment ? next : dot + 1
            }
            // A header and a payload that are both JSON (`eyJ….eyJ…`) are a token whose last dot was
            // cut off, as a URL in a sentence loses it to the full stop after it.
            let payload = skippingBridgedLineBreaks(from: skippingBridgedLineBreaks(from: headerEnd) + 1)
            let isCutToken = segments == 2 && segmentLengths[1] >= 4 && payload + 3 <= count && bytes[payload..<(payload + 3)].elementsEqual(prefix)
            if segments >= 3 || isCutToken, segmentLengths[0] >= 4, segmentLengths[1] >= 4 {
                spans.append(span(i..<j))
                i = j
            } else {
                // No token starts inside the header: skip it in bytes, line separators included, so
                // that a megabyte of them after `eyJ` is read once.
                i = max(headerEnd, i + 1)
            }
        }
        return spans
    }

    // MARK: Bearer tokens

    /// The token after the word `Bearer` and white space of any kind, line separators included
    /// (see ``NormalizedText/isBridgedLineBreak(_:)``), whatever its length.
    func bearerSpans() -> [RedactionPolicy.Span] {
        let word = Array("bearer".utf8)
        var spans: [RedactionPolicy.Span] = []
        var i = 0
        while i < count {
            guard matches(word, at: i), isWordStart(i), i + word.count < count, isSpace(i + word.count) || isBridgedLineBreak(i + word.count) else {
                i += 1
                continue
            }
            var start = i + word.count
            while start < count, isSpace(start) || isBridgedLineBreak(start) { start += 1 }
            var end = start
            while end < count, isTokenCharacter(end) { end += 1 }
            if end > start { spans.append(span(start..<end)) }
            i = max(end, i + 1)
        }
        return spans
    }
}
