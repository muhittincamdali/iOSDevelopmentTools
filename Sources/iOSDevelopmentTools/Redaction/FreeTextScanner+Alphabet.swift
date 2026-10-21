/// The safe alphabet of free text: the characters that are read as text. Every other character
/// is a trigger, without a list of the ones that look like separators.
extension FreeTextScanner {
    /// Whether the character of byte `i` is outside the safe alphabet: letters, marks and digits
    /// of any script, the ASCII space, tab, LF and CR, the rest of printable ASCII, and a space
    /// that compatibility normalization reads as an ASCII space (U+00A0, U+3000). Any other
    /// character is judged by its own general category, not by the ASCII that compatibility
    /// normalization makes of it, so every punctuation mark and symbol outside ASCII is outside:
    /// `꞉`, `≔`, `→`, `·`, `’`, `€`, `、`, and also `＝`, `…`, `‥`, `︰`, `™`, `ⓟ` and `¨`. So is
    /// an emoji, a skin tone, a private-use or unassigned code point, a dash outside ASCII (`—`,
    /// `゠`), the blank Braille pattern and U+1680, a line break other than LF and CR (VT, FF,
    /// U+0085, U+2028, U+2029), and a modifier letter (`ʻ`, `ː`), which is written as a separator
    /// as often as a letter, apart from those of East Asian text (`ー`) that are not glued to
    /// ASCII.
    func isOutsideSafeAlphabet(_ i: Int) -> Bool {
        let scalar = source[text.offsets[i]]
        // Of the line breaks, only LF and CR are text: VT, FF, U+0085, U+2028 and U+2029 end a line
        // too, but they are control characters and separators outside ASCII.
        if scalar.isASCII { return scalar.value == 0x0B || scalar.value == 0x0C }
        if text.isLineTerminator(i) { return true }
        if text.bytes[i] == UInt8(ascii: " ") {
            // A spacing accent (`¨`, `´`, `‾`) is read as a space and a mark, but it is a symbol.
            return ScalarTable.category(scalar) != .spaceSeparator || !compatibility.foldsToASCII(scalar)
        }
        switch ScalarTable.category(scalar) {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .otherLetter, .nonspacingMark, .spacingMark, .enclosingMark,
             .decimalNumber, .letterNumber, .otherNumber:
            return false
        case .modifierLetter:
            // `ー` and the other modifier letters of kana belong to the East Asian text around them.
            return !Self.isEastAsian(scalar) || (i > 0 && text.bytes[i - 1] != CompatibilityText.unreadable && !text.isSpace(i - 1))
        default:
            return true
        }
    }

    /// CJK symbols and punctuation, kana and the full-width and half-width forms.
    private static func isEastAsian(_ scalar: Unicode.Scalar) -> Bool {
        (0x3000...0x30FF).contains(scalar.value) || (0xFF00...0xFFEF).contains(scalar.value)
    }

    /// The first byte of the word `range` whose character is outside the safe alphabet and has text
    /// after it: more of the word, or any text after the word, on its line or below. One with
    /// nothing after it hides nothing.
    func firstUnsafeCharacter(in range: Range<Int>) -> Int? {
        range.first { k in
            guard isOutsideSafeAlphabet(k) else { return false }
            return scalarEnd(k) < range.upperBound || firstText(from: range.upperBound) != nil
        }
    }

    /// The byte after the bytes that the scalar of byte `i` became.
    func scalarEnd(_ i: Int) -> Int {
        var k = i + 1
        while k < text.count, text.offsets[k] == text.offsets[i] { k += 1 }
        return k
    }

    /// The offset of a control character that the scanning copy left out right before byte `i`,
    /// after the byte before it: a control character is outside the safe alphabet wherever it
    /// is. One inside a word makes the word one that cannot be read (see ``isAmbiguous(_:)``).
    func hiddenControl(before i: Int) -> Int? {
        let previousEnd = i > 0 ? text.offsets[i - 1] + 1 : 0
        let start = text.offsets[i]
        guard start > previousEnd else { return nil }
        return (previousEnd..<start).first { ScalarTable.category(source[$0]) == .control }
    }

    // MARK: Escapes

    /// The first byte of the word `range` that starts an escape (see ``startsEscape(_:)``).
    func firstEscape(in range: Range<Int>) -> Int? {
        range.first(where: startsEscape)
    }

    /// Whether an escape starts at byte `i`. No list of escape forms is kept, so a form that is
    /// not known counts as well:
    ///
    /// - a backslash before anything but an ASCII space, a tab, a line break or the end of the
    ///   text (see ``backslashEscapes(at:)``): `\x41`, `\u{41}`, `\N{…}`, `\p{L}`, `\8`, `\cJ`,
    ///   `\"`, `\\`, `\/`, a Windows path (`dir\data`) and a literal `\n` all count;
    /// - `%` and two hex digits (`%3D`, `%41`), or `%u` and four (`%u003D`);
    /// - `&` before a letter or `#` (`&amp`, `&lt;`, `&#61;`, `&#x;`, `&#q`, `R&D`), with or
    ///   without a `;`.
    ///
    /// In free text an escape is a trigger and is never decoded: what it stands for cannot be told
    /// without guessing the format. Over-hiding a Windows path or `R&D` is by design.
    func startsEscape(_ i: Int) -> Bool {
        switch text.bytes[i] {
        case UInt8(ascii: "%"):
            if hexDigits(from: i + 1, count: 2) { return true }
            return i + 1 < text.count && text.bytes[i + 1] | 0x20 == UInt8(ascii: "u") && hexDigits(from: i + 2, count: 4)
        case UInt8(ascii: "&"):
            return i + 1 < text.count && (text.bytes[i + 1] == UInt8(ascii: "#") || text.isAnyLetter(i + 1))
        case UInt8(ascii: "\\"):
            return backslashEscapes(at: i)
        default:
            return false
        }
    }

    /// Whether a backslash escape starts at byte `i`: a backslash that does not end the text and
    /// that anything but an ASCII space, a tab or a line break follows in the original text. What
    /// follows it is not read as any form of escape. A mark or an invisible character right after
    /// it, which the scanning copy leaves out, and a space outside ASCII count as what it escapes.
    func startsBackslashEscape(_ i: Int) -> Bool {
        text.bytes[i] == UInt8(ascii: "\\") && backslashEscapes(at: i)
    }

    /// Whether the backslash at byte `i` starts an escape (see ``startsBackslashEscape(_:)``).
    func backslashEscapes(at i: Int) -> Bool {
        let next = text.offsets[i] + 1
        guard next < source.count else { return false }
        let scalar = source[next]
        return !(scalar.isASCII && Self.blanksAfterBackslash.contains(UInt8(scalar.value)))
    }

    /// What a backslash can come before without starting an escape: an ASCII space, a tab or a
    /// line break.
    private static let blanksAfterBackslash = ByteSet(" \t\n\r")

    private func hexDigits(from i: Int, count: Int) -> Bool {
        guard i + count <= text.count else { return false }
        return (i..<(i + count)).allSatisfy { k in
            ASCII.isDigit(text.bytes[k]) || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(text.bytes[k] | 0x20)
        }
    }

    // MARK: Opaque words

    /// The longest word that is read, in Unicode scalars: 256. A longer word is no name or value
    /// that can be read, so it is a trigger; this also bounds the memory that reading a word takes.
    static let longestWord = 256

    /// Whether the word `range` is longer than ``longestWord``.
    func isOpaque(_ range: Range<Int>) -> Bool {
        !range.isEmpty && text.offsets[range.upperBound - 1] - text.offsets[range.lowerBound] + 1 > Self.longestWord
    }
}
