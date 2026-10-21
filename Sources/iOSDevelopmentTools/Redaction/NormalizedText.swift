import Foundation

/// The scanning copy of a text: invisible scalars (format characters, marks, variation selectors,
/// default-ignorable code points and control characters, see ``ScalarClass/isInvisible(_:)``)
/// removed and every other scalar read as the ASCII it stands for under Unicode compatibility
/// normalization (see ``CompatibilityText``), with the offset each byte came from in the original
/// scalars. One scalar can become several bytes (`ﬁ` is read as `fi`).
///
/// The free-text rule and the value detectors read this copy; their findings are mapped back to
/// the original scalars. Keys are judged on the original scalars, never on this copy.
struct NormalizedText {
    let bytes: [UInt8]
    /// The offset in the original scalars of the scalar a byte came from.
    let offsets: ScalarOffsets
    /// The original scalars.
    let source: [Unicode.Scalar]
    /// The number of original scalars.
    var sourceCount: Int { source.count }

    /// A byte of a masked range: like ``CompatibilityText/unreadable`` it matches no detector or
    /// separator, and unlike it, it never stands for a letter.
    static let masked: UInt8 = 0xFE

    /// - Parameter masked: Ranges of original scalars to read as ``masked``, so that no finding
    ///   starts, ends or runs inside them.
    init(_ scalars: [Unicode.Scalar], compatibility: CompatibilityText, masked: [Range<Int>] = []) {
        // Most log text is plain ASCII: each byte is the scalar at its own offset, so no offsets
        // are stored.
        if scalars.allSatisfy({ $0.isASCII && !ASCII.isHidingControl(UInt8($0.value)) }) {
            var bytes = scalars.map { UInt8($0.value) }
            for range in masked {
                for k in range.clamped(to: bytes.indices) { bytes[k] = Self.masked }
            }
            self.bytes = bytes
            offsets = .identity
            source = scalars
            return
        }
        var bytes: [UInt8] = []
        var offsets: [UInt32] = []
        bytes.reserveCapacity(scalars.count)
        offsets.reserveCapacity(scalars.count)
        var mask = masked.sorted { $0.lowerBound < $1.lowerBound }.makeIterator()
        var nextMask = mask.next()
        for (offset, scalar) in scalars.enumerated() {
            while let range = nextMask, range.upperBound <= offset { nextMask = mask.next() }
            if let range = nextMask, range.contains(offset) {
                bytes.append(Self.masked)
                offsets.append(UInt32(truncatingIfNeeded: offset))
                continue
            }
            if scalar.isASCII {
                // Control characters other than tab and line terminators hide like format ones.
                guard !ASCII.isHidingControl(UInt8(scalar.value)) else { continue }
                bytes.append(UInt8(scalar.value))
                offsets.append(UInt32(truncatingIfNeeded: offset))
                continue
            }
            guard !ScalarClass.isInvisible(scalar) else { continue }
            for byte in compatibility.ascii(scalar) {
                bytes.append(byte)
                offsets.append(UInt32(truncatingIfNeeded: offset))
            }
        }
        self.bytes = bytes
        self.offsets = .stored(offsets)
        self.source = scalars
    }

    var count: Int { bytes.count }

    /// A finding over bytes `range`, as a span of the original scalars hidden whole.
    func span(_ range: Range<Int>) -> RedactionPolicy.Span {
        RedactionPolicy.Span(
            start: offsets[range.lowerBound], end: offsets[range.upperBound - 1] + 1, replacement: RedactionPolicy.replacement)
    }

    /// The offset in the original scalars where byte `i` starts; the end of the text for
    /// `i == count`.
    func offset(at i: Int) -> Int {
        i < count ? offsets[i] : sourceCount
    }

    /// The original scalars of a range of bytes, with the invisible scalars up to the next byte.
    func original(_ range: Range<Int>) -> Range<Int> {
        offset(at: range.lowerBound)..<offset(at: range.upperBound)
    }

    /// ``original(_:)`` together with the invisible scalars right before the range, which belong
    /// to the key or word that starts there: `\u{200D}status` is not the key `status`.
    func originalWithInvisiblesBefore(_ range: Range<Int>) -> Range<Int> {
        let end = offset(at: range.upperBound)
        guard range.lowerBound > 0 else { return 0..<end }
        return min(offsets[range.lowerBound - 1] + 1, offset(at: range.lowerBound))..<end
    }

    /// The first byte at or after an offset in the original scalars.
    func byteIndex(atOrAfter offset: Int) -> Int {
        var low = 0
        var high = count
        while low < high {
            let middle = (low + high) / 2
            if offsets[middle] < offset { low = middle + 1 } else { high = middle }
        }
        return low
    }

    // MARK: Character classes

    func isDigit(_ i: Int) -> Bool { ASCII.isDigit(bytes[i]) }

    func isUppercase(_ i: Int) -> Bool { ASCII.isUppercase(bytes[i]) }

    func isLetter(_ i: Int) -> Bool { ASCII.isLetter(bytes[i]) }

    func isAlphanumeric(_ i: Int) -> Bool { isDigit(i) || isLetter(i) }

    /// A letter of any script: an ASCII letter, or one without an ASCII reading (`ı`, `ø`, `张`).
    func isAnyLetter(_ i: Int) -> Bool {
        isLetter(i) || (bytes[i] == CompatibilityText.unreadable && ScalarClass.isLetter(source[offsets[i]]))
    }

    /// A letter or digit of any script; marks are not in the scanning copy, so a letter with
    /// marks is one too.
    func isAnyAlphanumeric(_ i: Int) -> Bool {
        isAlphanumeric(i) || (bytes[i] == CompatibilityText.unreadable && ScalarClass.isLetterOrNumber(source[offsets[i]]))
    }

    func isBase64URL(_ i: Int) -> Bool { isAlphanumeric(i) || bytes[i] == UInt8(ascii: "-") || bytes[i] == UInt8(ascii: "_") }

    func isTokenCharacter(_ i: Int) -> Bool {
        isAlphanumeric(i) || [UInt8(ascii: "-"), UInt8(ascii: "."), UInt8(ascii: "_"), UInt8(ascii: "~"), UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "=")].contains(bytes[i])
    }

    func isSpace(_ i: Int) -> Bool { bytes[i] == UInt8(ascii: " ") || bytes[i] == UInt8(ascii: "\t") }

    /// LF (also read from U+2028, U+2029 and U+0085), CR, vertical tab and form feed.
    func isLineTerminator(_ i: Int) -> Bool {
        let byte = bytes[i]
        return byte == 0x0A || byte == 0x0D || byte == 0x0B || byte == 0x0C
    }

    /// Whether byte `i` is a line separator that the value detectors read across: a vertical tab,
    /// a form feed, or a line feed read from U+0085, U+2028 or U+2029. Each of them is outside the
    /// safe alphabet and cuts free text, so a card number, an IBAN, an email address or a token
    /// written across one is found whole and the cut, merged with it, moves back to its start
    /// (`paid 4111 1111 1111` and U+2028 before `1111` keeps `paid `). A line feed or a carriage
    /// return written as such ends a finding, as it ends a line.
    func isBridgedLineBreak(_ i: Int) -> Bool {
        switch bytes[i] {
        case 0x0B, 0x0C: true
        case 0x0A: !source[offsets[i]].isASCII
        default: false
        }
    }

    /// The first byte at or after `i` that is not a line separator read across (see
    /// ``isBridgedLineBreak(_:)``); ``count`` when there is none.
    func skippingBridgedLineBreaks(from i: Int) -> Int {
        var k = i
        while k < count, isBridgedLineBreak(k) { k += 1 }
        return k
    }

    /// Whether a word starts at `i`: after a character that does not glue to it (see
    /// ``gluesToWord(_:)``), or at a lowercase to uppercase change (`accessToken`).
    func isWordStart(_ i: Int) -> Bool {
        guard i > 0 else { return true }
        if !gluesToWord(i - 1) { return true }
        return isUppercase(i) && isLetter(i - 1) && !isUppercase(i - 1)
    }

    /// Whether byte `i` is a letter or digit written in ASCII, which makes the digits or the token
    /// next to it part of a word (`id4242…`, `xeyJ…`) that the value detectors leave alone. A letter
    /// read from another character (`é`, `𝐚`, `№`) does not: the detectors find a card number or a
    /// token after it, as 2.0.0 did.
    func gluesToWord(_ i: Int) -> Bool {
        isAlphanumeric(i) && source[offsets[i]].isASCII
    }

    func matches(_ word: [UInt8], at i: Int) -> Bool {
        guard i + word.count <= count else { return false }
        for (k, byte) in word.enumerated() where ASCII.lowercased(bytes[i + k]) != byte {
            return false
        }
        return true
    }
}

/// The offset in the original scalars of each byte of a scanning copy: none stored for plain
/// ASCII, where each byte is the scalar at its own offset, and 32 bits each otherwise, since the
/// copy of a megabyte of text holds a million of them. A text of more scalars than 32 bits count
/// is hidden whole before a copy is made (see ``RedactionPolicy/maximumTextLength``).
enum ScalarOffsets {
    case identity
    case stored([UInt32])

    subscript(i: Int) -> Int {
        switch self {
        case .identity: i
        case .stored(let storage): Int(storage[i])
        }
    }
}
