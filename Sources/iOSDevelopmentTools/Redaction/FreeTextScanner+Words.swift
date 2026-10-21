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
    /// trigger when it holds a character outside the safe alphabet with text after it (see
    /// ``isOutsideSafeAlphabet(_:)``) or an escaped separator, and, in text, when it holds an
    /// escape (see ``startsEscape(_:)``), is longer than ``longestWord``, names a secret
    /// (`password hunter2`, `PIN 1234`, also split by a space: `pass word`) or cannot be read.
    /// Only the part of the word before its first escape or unsafe character is read for names:
    /// escapes are never decoded to read a name in text, and the cut is there at the latest.
    mutating func word() {
        let start = position
        let lineEnd = currentLineEnd()
        let end = wordEnd(from: start, to: lineEnd)
        position = end
        let range = start..<end
        guard readsWords else {
            // In a name, a separator of its own, escaped or one that only looks like one, starts a
            // value written into the name.
            if let embedded = [firstUnsafeCharacter(in: range), escapedValueStart(in: range)].compactMap({ $0 }).min() {
                cut(atByte: embedded)
            }
            return
        }
        guard !isOpaque(range) else {
            cut(atByte: start)
            return
        }
        // What a value detector finds in the word with its escapes decoded starts the cut there
        // (`a\u0040b.com`), so the decoding only ever hides more.
        let stop = [firstUnsafeCharacter(in: range), firstEscape(in: range), escapedValueStart(in: range)].compactMap { $0 }.min()
        let readable = start..<(stop ?? end)
        if !readable.isEmpty {
            switch read(readable) {
            case .valueStart where namesNoValue(readable):
                break
            case .plain:
                if stop == nil, let secretEnd = secretEndAcrossSpace(after: range, lineEnd: lineEnd) {
                    cut(afterByte: secretEnd - 1)
                    return
                }
            case .ambiguous:
                cut(atByte: start)
                return
            case .valueStart(let valueStart):
                cut(afterByte: valueStart - 1)
                return
            }
        }
        if let stop { cut(atByte: stop) }
    }

    /// Whether a word that holds a secret name names no value after it: the element name `key` in
    /// a start tag, whose text the rule for the text of an element cuts where it starts (see
    /// ``noteTag(_:at:)``). The name of an end tag is a secret name like any other: whether
    /// `</password` ends an element or what follows it is a value cannot be told (`</pin 1234`).
    private func namesNoValue(_ word: Range<Int>) -> Bool {
        let start = word.lowerBound
        guard start >= 1, text.bytes[start - 1] == UInt8(ascii: "<") else { return false }
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
        return reading.secretEnd { $0.lowerBound < nextStart && $0.upperBound > nextStart }
    }

    private static let splittingBoundaries = ByteSet("|,;&?")

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
    func bracedEscapeLength(at i: Int) -> Int? {
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
