/// Quotes, brackets and tags in free text.
extension FreeTextScanner {
    /// Whether the byte at `i` comes after an odd number of backslashes.
    func isEscaped(_ i: Int) -> Bool {
        var count = 0
        var k = i
        while k > 0, text.bytes[k - 1] == UInt8(ascii: "\\") {
            count += 1
            k -= 1
        }
        return count % 2 == 1
    }

    /// Quotes and brackets, which are a trigger when they do not close.
    static let marks = ByteSet("\"'`([{")
    private static let openings: [UInt8] = Array("([{".utf8)
    private static let closings: [UInt8] = Array(")]}".utf8)
    private static let simpleQuotes: [UInt8] = Array("'`".utf8)

    /// Notes the last closing bracket of each kind and the last single quote and backtick, in one
    /// pass.
    mutating func noteLastMarks() {
        for k in 0..<text.count {
            let byte = text.bytes[k]
            if let kind = Self.closings.firstIndex(of: byte) {
                lastCloses[kind] = k
            } else if let kind = Self.simpleQuotes.firstIndex(of: byte) {
                lastSimpleQuotes[kind] = k
            }
        }
    }

    /// A quote or an opening bracket at the position. It is a trigger when it does not close: a
    /// double quote, plain or escaped (`\"`), with no other one of its kind after it, a single quote
    /// or backtick that opens a value (`status='ok`) with no other one after it, and a bracket with
    /// no closing one of its kind after it. A quote that closes is passed over and the text inside
    /// it is read on, so a name in quotes is read too. Apostrophes inside words (`don't`) are not
    /// quotes.
    mutating func readMark() {
        let byte = text.bytes[position]
        if byte == UInt8(ascii: "\"") {
            let kind = isEscaped(position) ? 1 : 0
            if pendingCloses[kind] == position {
                pendingCloses[kind] = nil
            } else {
                guard let close = closingQuote(after: position, escaped: kind == 1) else {
                    cut(atByte: position)
                    return
                }
                pendingCloses[kind] = close
            }
        } else if let kind = Self.simpleQuotes.firstIndex(of: byte) {
            if opensValue(at: position), lastSimpleQuotes[kind] <= position {
                cut(atByte: position)
                return
            }
        } else if let kind = Self.openings.firstIndex(of: byte), lastCloses[kind] < position {
            cut(atByte: position)
            return
        }
        position += 1
    }

    /// The next double quote after `open`, escaped like it (`\"…\"` in escaped JSON) or not.
    /// The search ends at that quote, and the text up to it is read once more at most, so the
    /// quotes of a text are found in time linear in its length.
    private func closingQuote(after open: Int, escaped: Bool) -> Int? {
        var k = open + 1
        while k < text.count {
            if text.bytes[k] == UInt8(ascii: "\""), isEscaped(k) == escaped { return k }
            k += 1
        }
        return nil
    }

    /// Whether a single quote or backtick at `k` opens a value: it follows a separator, with white
    /// space between at most.
    private func opensValue(at k: Int) -> Bool {
        var j = k
        while j > 0, text.isSpace(j - 1) { j -= 1 }
        return j > 0 && isSeparator(j - 1)
    }

    /// Notes where a tag starts (`<` before a letter or `/`) and where its name ends, and where
    /// it ends (`>`, at byte `i`). The end of the start tag `<key>` is followed by a name.
    mutating func noteTag(_ byte: UInt8, at i: Int) {
        if byte == UInt8(ascii: ">") {
            let endedTag = openTag
            openTag = nil
            if let endedTag, isKeyStartTag(endedTag) { readKeyElement(after: i) }
            return
        }
        guard byte == UInt8(ascii: "<"), i + 1 < text.count else { return }
        var nameEnd = i + 1
        if text.bytes[nameEnd] == UInt8(ascii: "/") { nameEnd += 1 }
        guard nameEnd < text.count, text.isLetter(nameEnd) else { return }
        while nameEnd < text.count, text.isAlphanumeric(nameEnd) || Self.tagNameCharacters.contains(text.bytes[nameEnd]) { nameEnd += 1 }
        openTag = (i, nameEnd)
    }

    private func isKeyStartTag(_ tag: (start: Int, nameEnd: Int)) -> Bool {
        let name = (tag.start + 1)..<tag.nameEnd
        return name.count == 3 && text.bytes[name].map(ASCII.lowercased).elementsEqual("key".utf8)
    }

    /// The text of a `<key>` element, up to the next `<`, is a name in name position, as a
    /// property list writes it (`<key>Şifre</key><string>…`): a name that names a secret, is not
    /// plain ASCII or has no letter hides what follows the start tag.
    private mutating func readKeyElement(after close: Int) {
        var end = close + 1
        while end < text.count, text.bytes[end] != UInt8(ascii: "<") { end += 1 }
        let range = (close + 1)..<end
        let scalars = range.isEmpty ? [] : Array(source[text.originalWithInvisiblesBefore(range)])
        if WrittenName.namesSecret(scalars, in: .quoted(after: Self.keyElement), policy: policy, compatibility: compatibility) {
            cut(afterByte: close)
        }
    }

    private static let keyElement = Array("key".unicodeScalars)

    private static let tagNameCharacters = ByteSet(":-_.")
}
