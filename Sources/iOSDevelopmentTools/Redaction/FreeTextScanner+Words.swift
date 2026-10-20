/// Words in free text: keys before a separator, and words that name a secret or cannot be read.
extension FreeTextScanner {
    /// What a word says about the text after it.
    enum WordReading: Equatable {
        case plain
        /// The word mixes scripts or holds a character that only hides text: it cannot be read
        /// with certainty.
        case ambiguous
        /// The word holds a secret name or an escaped `=` or `:`; a value starts at this byte:
        /// right after the secret word or at the escape, or at the end of the word.
        case valueStart(Int)
    }

    /// A run of characters up to white space, a separator, a quote or a boundary. It is a
    /// trigger when it holds a separator of its own, escaped or one that only looks like one, and,
    /// in text, when it names a secret (`password hunter2`, `PIN 1234`, also split by a space:
    /// `pass word`) or cannot be read.
    mutating func word() {
        let start = position
        let lineEnd = currentLineEnd()
        let end = wordEnd(from: start, to: lineEnd)
        position = end
        if let embedded = embeddedSeparator(in: start..<end, lineEnd: lineEnd) {
            cut(atByte: embedded)
            return
        }
        if isSeparatorWord(start..<end, lineEnd: lineEnd) {
            cut(atByte: start)
            return
        }
        guard readsWords else { return }
        switch read(start..<end) {
        case .valueStart where namesNoValue(start..<end):
            break
        case .plain:
            if let secretEnd = secretEndAcrossSpace(after: start..<end, lineEnd: lineEnd) { cut(afterByte: secretEnd - 1) }
        case .ambiguous:
            cut(atByte: start)
        case .valueStart(let valueStart):
            cut(afterByte: valueStart - 1)
        }
    }

    /// Whether a word that holds a secret name names no value after it: the name of an end tag
    /// (`</password>`), whose value came before it, and the element name `key`, which in a
    /// property list holds the name of the element after it (`<key>user</key>`), so only a secret
    /// name in it counts (`<key>password</key>`).
    private func namesNoValue(_ word: Range<Int>) -> Bool {
        let start = word.lowerBound
        guard start >= 1, text.bytes[start - 1] == UInt8(ascii: "<") else { return false }
        if text.bytes[start] == UInt8(ascii: "/") { return true }
        return word.count == 3 && text.bytes[word].map(ASCII.lowercased).elementsEqual("key".utf8)
    }

    /// A secret word split by white space or by one of `|`, `,`, `;`, `&` and `?` (`pass word`,
    /// `to ken`, `p|wd`): the byte after it, when it starts in this word and ends in the next one
    /// on the line.
    private func secretEndAcrossSpace(after word: Range<Int>, lineEnd: Int) -> Int? {
        var nextStart = firstNonSpace(from: word.upperBound, to: lineEnd)
        if nextStart < lineEnd, Self.splittingBoundaries.contains(text.bytes[nextStart]) {
            nextStart = firstNonSpace(from: nextStart + 1, to: lineEnd)
        }
        guard nextStart > word.upperBound, nextStart < lineEnd, !endsWord(nextStart) else { return nil }
        let next = nextStart..<wordEnd(from: nextStart, to: lineEnd)
        guard let reading = LooseReading(text, [word, next], source: source, names: policy.secretNameTable) else { return nil }
        let split = reading.letterCount(before: nextStart)
        return reading.secretEnd { $0.lowerBound < split && $0.upperBound > split }
    }

    private static let splittingBoundaries = ByteSet("|,;&?")

    /// Punctuation, a math symbol or a modifier letter or symbol outside ASCII, such as `꞉`, `∶`,
    /// `≔`, `→` or `·`, may be meant as a separator. Glued between other characters of a word
    /// (`user꞉bob`, `e%79≔…`, `token·"…"`), or after other text at the start of a word, and written
    /// as `%3D`, `&#61;` or `:`, it is a trigger. Glued, a connector without an ASCII form
    /// counts too (`user‿bob`); between words of prose it does not. A dash of any kind is read as
    /// `-` (see ``CompatibilityText``), which joins words. Quotation marks, brackets, currency
    /// signs, emoji, skin tones and the punctuation of East Asian scripts are not read this way.
    private func embeddedSeparator(in range: Range<Int>, lineEnd: Int) -> Int? {
        let first = text.offsets[range.lowerBound]
        let followsText = range.lowerBound > 0
        let glued = range.first { k in
            guard text.offsets[k] > first || followsText, isSeparatorLike(k, glued: true) else { return false }
            let after = scalarEnd(k)
            return after < range.upperBound || (range.upperBound < lineEnd && !text.isSpace(range.upperBound))
        }
        return [glued, escapedValueStart(in: range)].compactMap { $0 }.min()
    }

    /// The byte after the bytes that the scalar of byte `i` became.
    private func scalarEnd(_ i: Int) -> Int {
        var k = i + 1
        while k < text.count, text.offsets[k] == text.offsets[i] { k += 1 }
        return k
    }

    /// Whether the word is only such characters, between other text and more text after it
    /// (`user ꞉ bob`).
    private func isSeparatorWord(_ range: Range<Int>, lineEnd: Int) -> Bool {
        guard range.lowerBound > 0, range.allSatisfy({ isSeparatorLike($0) }) else { return false }
        return firstText(from: range.upperBound) != nil
    }

    /// A character without an ASCII reading that may be a separator; one that has an ASCII
    /// reading (`．`, `‥`, `－`) is read as that. With `glued`, for a character between other
    /// characters of a word, connectors count too.
    private func isSeparatorLike(_ i: Int, glued: Bool = false) -> Bool {
        guard text.bytes[i] == CompatibilityText.unreadable else { return false }
        let scalar = source[text.offsets[i]]
        // A skin tone belongs to the emoji before it (`👍🏽`).
        guard !scalar.properties.isEmojiModifier else { return false }
        switch scalar.properties.generalCategory {
        case .otherPunctuation, .mathSymbol, .modifierLetter, .modifierSymbol: break
        case .connectorPunctuation:
            guard glued else { return false }
        default: return false
        }
        // `、`, `。`, `ー` and `・` belong to the East Asian text around them, but not to ASCII.
        return !Self.isEastAsian(scalar) || (i > 0 && text.bytes[i - 1] != CompatibilityText.unreadable && !text.isSpace(i - 1))
    }

    /// CJK symbols and punctuation, kana and the full-width and half-width forms (the full-width
    /// `＝` and `：` are read as separators already).
    private static func isEastAsian(_ scalar: Unicode.Scalar) -> Bool {
        (0x3000...0x30FF).contains(scalar.value) || (0xFF00...0xFFEF).contains(scalar.value)
    }

    /// The end of the word that starts at `start`. An HTML character reference (`&#97;`) and a
    /// `\u{…}` escape are part of a word, though `&`, `;` and `{` end words elsewhere.
    func wordEnd(from start: Int, to lineEnd: Int) -> Int {
        var end = start
        while end < lineEnd {
            if let length = referenceLength(at: end) ?? bracedEscapeLength(at: end) {
                end += length
            } else if end > start, endsWord(end) {
                break
            } else {
                end += 1
            }
        }
        return min(end, lineEnd)
    }

    func endsWord(_ i: Int) -> Bool {
        let byte = text.bytes[i]
        return text.isSpace(i) || text.isLineTerminator(i) || isSeparator(i) || byte == UInt8(ascii: "\"") || Self.boundaries.contains(byte)
    }

    /// The length of `&#NN;` or `&#xHH;` at `i`, also without the `;` (`&#61`) and behind `&amp;`
    /// (`&amp;#97;`), or of `&amp;` alone, or nil.
    func referenceLength(at i: Int) -> Int? {
        guard text.bytes[i] == UInt8(ascii: "&") else { return nil }
        var k = i + 1
        if k + 4 <= text.count, text.bytes[k..<(k + 4)].elementsEqual("amp;".utf8) {
            k += 4
            guard k < text.count, text.bytes[k] == UInt8(ascii: "#") else { return k - i }
        }
        guard k + 1 < text.count, text.bytes[k] == UInt8(ascii: "#") else { return nil }
        let isHex = text.bytes[k + 1] | 0x20 == UInt8(ascii: "x")
        k += isHex ? 2 : 1
        let digitsStart = k
        while k < text.count, k - digitsStart < EscapeDecoder.maximumReferenceDigits,
              isHex ? Self.isHexDigit(text.bytes[k]) : ASCII.isDigit(text.bytes[k]) {
            k += 1
        }
        guard k > digitsStart else { return nil }
        return (k < text.count && text.bytes[k] == UInt8(ascii: ";") ? k + 1 : k) - i
    }

    /// The length of `\u{…}` at `i`, or nil.
    private func bracedEscapeLength(at i: Int) -> Int? {
        guard text.bytes[i] == UInt8(ascii: "\\"), i + 3 < text.count, text.bytes[i + 1] == UInt8(ascii: "u"), text.bytes[i + 2] == UInt8(ascii: "{")
        else { return nil }
        var k = i + 3
        while k < text.count, k - i < 12, Self.isHexDigit(text.bytes[k]) { k += 1 }
        guard k > i + 3, k < text.count, text.bytes[k] == UInt8(ascii: "}") else { return nil }
        return k + 1 - i
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        ASCII.isDigit(byte) || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte | 0x20)
    }
}
