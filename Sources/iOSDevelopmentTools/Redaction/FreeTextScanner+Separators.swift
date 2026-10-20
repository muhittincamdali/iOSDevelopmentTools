/// The separators of `key=value` and `key: value` in free text.
extension FreeTextScanner {
    /// `=` and `:`, apart from a `:` that is part of a number (see ``isInNumber(colon:)``).
    func isSeparator(_ i: Int) -> Bool {
        let byte = text.bytes[i]
        if byte == UInt8(ascii: "=") { return true }
        guard byte == UInt8(ascii: ":") else { return false }
        return !isInNumber(colon: i)
    }

    /// Whether the `:` at byte `i` is part of a time, a date and time or an address and its port
    /// (`12:30:45`, `2026-10-19T12:30:45Z`, `10.0.0.1:8080`). Both sides have to be a whole
    /// number. Before it: an IPv4 address, or a word that ends in one or two digits after its last
    /// `.`, `-` or `T`, holds no letter other than the `T` between the date and the time, and does
    /// not follow a letter, a digit or `_`. After it: a port of at most five digits after an
    /// address; otherwise two digits of minutes, then optionally `:` and two digits of seconds, a
    /// fraction of the seconds, and `Z` or an offset (`+03:00`). Then the text ends, or white space
    /// follows, after closing punctuation or none (`(12:30)`, `[12:30:45] started`, `12:30,`).
    /// Any other `:` is a separator: a key that ends in digits (`user1:2345`) and a number used as
    /// a key (`42:2345678901`, `12:34hunter2`, `10.0.0.1:8080secret`) cut the text at the value.
    func isInNumber(colon i: Int) -> Bool {
        guard i > 0, i + 1 < text.count, text.isDigit(i - 1), text.isDigit(i + 1),
              let start = numberStart(beforeColon: i)
        else { return false }
        let end: Int?
        if isAddress(start..<i) {
            end = digitsEnd(from: i + 1, atMost: Self.longestPort)
        } else if trailingDigitCount(before: i) <= 2 {
            end = timeEnd(afterColon: i, readsSeconds: start > 0 && text.bytes[start - 1] == UInt8(ascii: ":"))
        } else {
            return false
        }
        guard let end else { return false }
        return endsNumber(at: end)
    }

    /// The longest number, date and time that a `:` is read in, in bytes.
    static let longestNumber = 64

    /// The most digits of a port after an address.
    static let longestPort = 5

    /// The most digits of a fraction of a second (nanoseconds).
    private static let longestFraction = 9

    private static let numberMarks = ByteSet(".-")
    private static let closingMarks = ByteSet(",;.!?)]}>\"'")
    private static let offsetSigns = ByteSet("+-")
    private static let fractionMarks = ByteSet(".,")

    /// Where the number before the `:` at byte `i` starts; nil when a letter, a digit or `_` comes
    /// before it, or when it is longer than ``longestNumber`` (then it is read as a key).
    private func numberStart(beforeColon i: Int) -> Int? {
        let wordLimit = max(0, i - Self.longestNumber)
        var k = i
        while k > wordLimit {
            let previous = text.bytes[k - 1]
            if text.isDigit(k - 1) || Self.numberMarks.contains(previous) {
                k -= 1
            } else if previous == UInt8(ascii: "T"), k > 1, text.isDigit(k - 2), text.isDigit(k) {
                k -= 1
            } else {
                break
            }
        }
        guard k > 0 else { return 0 }
        guard k > wordLimit, !text.isAnyAlphanumeric(k - 1), text.bytes[k - 1] != UInt8(ascii: "_") else { return nil }
        return k
    }

    /// Whether `range` is an IPv4 address: four groups of one to three digits between `.`.
    private func isAddress(_ range: Range<Int>) -> Bool {
        var dots = 0
        var digits = 0
        for k in range {
            if text.isDigit(k) {
                digits += 1
                guard digits <= 3 else { return false }
                continue
            }
            guard text.bytes[k] == UInt8(ascii: "."), digits > 0 else { return false }
            dots += 1
            digits = 0
        }
        return dots == 3 && digits > 0
    }

    /// The digits right before byte `i`, counted up to three.
    private func trailingDigitCount(before i: Int) -> Int {
        var count = 0
        while count < 3, i - count > 0, text.isDigit(i - count - 1) { count += 1 }
        return count
    }

    /// Where the minutes after the `:` at byte `colon` end, with the seconds, their fraction and a
    /// `Z` or an offset after them: `30`, `30:45`, `30:45.123Z`, `30:45-05:00`. When the number
    /// before the `:` follows another `:` (`12:30:45`), the digits after it are the seconds.
    private func timeEnd(afterColon colon: Int, readsSeconds: Bool) -> Int? {
        guard var k = twoDigitsEnd(from: colon + 1) else { return nil }
        var hasSeconds = readsSeconds
        if !hasSeconds, isByte(k, ":"), let seconds = twoDigitsEnd(from: k + 1) {
            k = seconds
            hasSeconds = true
        }
        if hasSeconds, k < text.count, Self.fractionMarks.contains(text.bytes[k]),
           let fraction = digitsEnd(from: k + 1, atMost: Self.longestFraction) {
            k = fraction
        }
        if isByte(k, "Z") { return k + 1 }
        return offsetEnd(from: k) ?? k
    }

    /// Where an offset from UTC that starts at byte `k` ends (`+03:00`, `-0500`, `+03`); nil when
    /// none starts there.
    private func offsetEnd(from k: Int) -> Int? {
        guard k < text.count, Self.offsetSigns.contains(text.bytes[k]), let end = digitsEnd(from: k + 1, atMost: 4) else { return nil }
        switch end - k - 1 {
        case 4: return end
        case 2: return isByte(end, ":") ? twoDigitsEnd(from: end + 1) ?? end : end
        default: return nil
        }
    }

    /// The end of exactly two digits from byte `i`.
    private func twoDigitsEnd(from i: Int) -> Int? { digitsEnd(from: i, atMost: 2).flatMap { $0 == i + 2 ? $0 : nil } }

    /// The end of the run of digits from byte `i`; nil when it is empty or longer than `limit`.
    private func digitsEnd(from i: Int, atMost limit: Int) -> Int? {
        var k = i
        while k < text.count, text.isDigit(k) {
            k += 1
            if k - i > limit { return nil }
        }
        return k > i ? k : nil
    }

    /// Whether a number may end at byte `end`: closing punctuation or none, then white space, a
    /// line break or the end of the text.
    private func endsNumber(at end: Int) -> Bool {
        var k = end
        while k < text.count, Self.closingMarks.contains(text.bytes[k]) { k += 1 }
        return k == text.count || text.isSpace(k) || text.isLineTerminator(k)
    }

    private func isByte(_ k: Int, _ character: Unicode.Scalar) -> Bool { k < text.count && text.bytes[k] == UInt8(ascii: character) }
}
