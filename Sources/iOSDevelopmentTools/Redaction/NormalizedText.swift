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

/// Reads a scalar outside ASCII as the ASCII it stands for under Unicode compatibility
/// decomposition (NFKD) without its marks: `ａ` and `𝐚` are `a`, `é` is `e`, `＝` and `︓` are `=`
/// and `:`, `≠` is `=`, a digit of any script is its digit, a dash of any kind is `-`, every space
/// is ` ` and a line or paragraph separator is `\n`. A scalar whose decomposition is not ASCII is
/// read as ``unreadable``. This is Unicode's own mapping, not a list of look-alikes: a Cyrillic
/// `а` stays unreadable.
///
/// The readings are cached per scalar: logs repeat the same few non-ASCII characters, and the
/// normalization goes through Foundation.
final class CompatibilityText {
    /// A byte that no detector or separator matches.
    static let unreadable: UInt8 = 0xFF

    /// A scalar's reading, and whether its compatibility form leaves the safe alphabet of free
    /// text (see ``formLeavesSafeAlphabet(_:)``), found from one normalization.
    private struct Reading {
        let bytes: [UInt8]
        let leavesSafeAlphabet: Bool
    }

    private var cache: [UInt32: Reading] = [:]
    private var foldCache: [UInt32: Bool] = [:]

    /// Whether compatibility decomposition alone reads the scalar as ASCII (`－` as `-`, `＝` as
    /// `=`), without the readings this type adds to it: a dash of any kind as `-`, every space as
    /// ` ` and a digit of any script as its digit.
    func foldsToASCII(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.isASCII { return true }
        if let cached = foldCache[scalar.value] { return cached }
        let parts = String(scalar).decomposedStringWithCompatibilityMapping.unicodeScalars.filter { !ScalarClass.isInvisible($0) }
        let folds = !parts.isEmpty && parts.allSatisfy(\.isASCII)
        foldCache[scalar.value] = folds
        return folds
    }

    func ascii(_ scalar: Unicode.Scalar) -> [UInt8] {
        if scalar.isASCII { return [UInt8(scalar.value)] }
        return reading(scalar).bytes
    }

    /// Whether the compatibility form of a scalar outside ASCII holds a character outside the safe
    /// alphabet of free text: ASCII punctuation (`🄁` is `0,`, `⒈` is `1.`, `⑴` is `(1)`), or a
    /// character outside ASCII that is not a letter, mark or digit (`½` is `1⁄2`). The scanning
    /// copy reads the scalar as that form, so a letter or digit with such a form is outside the
    /// alphabet too (see ``FreeTextScanner/isOutsideSafeAlphabet(_:)``). An ASCII space in the
    /// form is not: a scalar read as a space is judged as one.
    func formLeavesSafeAlphabet(_ scalar: Unicode.Scalar) -> Bool {
        !scalar.isASCII && reading(scalar).leavesSafeAlphabet
    }

    private func reading(_ scalar: Unicode.Scalar) -> Reading {
        if let cached = cache[scalar.value] { return cached }
        let form = String(scalar).decomposedStringWithCompatibilityMapping.unicodeScalars
        let reading = Reading(bytes: Self.read(scalar, form: form), leavesSafeAlphabet: form.contains(where: Self.leavesSafeAlphabet))
        cache[scalar.value] = reading
        return reading
    }

    /// Whether a scalar of a compatibility form is outside the safe alphabet: ASCII other than a
    /// letter, a digit or a space, or a scalar outside ASCII other than a letter, mark or digit.
    private static func leavesSafeAlphabet(_ part: Unicode.Scalar) -> Bool {
        guard part.isASCII else { return !ScalarClass.isLetterOrNumber(part) }
        let byte = UInt8(part.value)
        return !(ASCII.isAlphanumeric(byte) || byte == UInt8(ascii: " "))
    }

    private static func read(_ scalar: Unicode.Scalar, form: String.UnicodeScalarView) -> [UInt8] {
        if let digit = ScalarClass.decimalDigit(scalar) { return [UInt8(ascii: "0") + digit] }
        switch scalar.properties.generalCategory {
        case .lineSeparator, .paragraphSeparator: return [UInt8(ascii: "\n")]
        default: break
        }
        if scalar == "\u{85}" { return [UInt8(ascii: "\n")] }
        // The blank Braille pattern draws nothing, like a space.
        if scalar.properties.isWhitespace || scalar == "\u{2800}" { return [UInt8(ascii: " ")] }
        if scalar.properties.generalCategory == .dashPunctuation { return [UInt8(ascii: "-")] }
        var bytes: [UInt8] = []
        for part in form where !ScalarClass.isInvisible(part) {
            guard part.isASCII else { return [unreadable] }
            bytes.append(UInt8(part.value))
        }
        return bytes.isEmpty ? [unreadable] : bytes
    }
}
