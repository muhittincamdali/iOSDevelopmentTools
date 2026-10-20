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

    /// Notes where a tag starts (`<` before a letter of any script, or `/` and one) and where its
    /// name ends, and where it ends (`>`, at byte `i`). The end of a start tag is followed by the
    /// text of its element.
    mutating func noteTag(_ byte: UInt8, at i: Int) {
        if byte == UInt8(ascii: ">") {
            let endedTag = openTag
            openTag = nil
            if let endedTag, isStartTag(endedTag, endingAt: i) { readElementText(of: endedTag, after: i) }
            return
        }
        guard byte == UInt8(ascii: "<"), i + 1 < text.count else { return }
        var nameEnd = i + 1
        if text.bytes[nameEnd] == UInt8(ascii: "/") { nameEnd += 1 }
        guard nameEnd < text.count, text.isAnyLetter(nameEnd) else { return }
        while nameEnd < text.count, text.isAnyAlphanumeric(nameEnd) || Self.tagNameCharacters.contains(text.bytes[nameEnd]) { nameEnd += 1 }
        openTag = (i, nameEnd)
    }

    /// Whether the tag that ends at the `>` at `close` opens an element: it is not an end tag
    /// (`</a>`) and does not close itself (`<br/>`).
    private func isStartTag(_ tag: (start: Int, nameEnd: Int), endingAt close: Int) -> Bool {
        text.bytes[tag.start + 1] != UInt8(ascii: "/") && text.bytes[close - 1] != UInt8(ascii: "/")
    }

    /// The text of an element is the value of its tag, as the value of a key is: unless the tag's
    /// name is on ``allowedKeys``, the text is cut where it starts (`<user>bob</user>`,
    /// `<名前>bob</名前>`, `<key>password</key>`). In an allowed tag that holds a name (`<key>`,
    /// `<name>`, … when the app allows them), the text up to the next `<` is a name in name
    /// position, as a property list writes it (`<key>Şifre</key><string>…`): a name that names a
    /// secret, is not plain ASCII or has no letter hides what follows the start tag.
    private mutating func readElementText(of tag: (start: Int, nameEnd: Int), after close: Int) {
        guard let textStart = firstText(from: close + 1), text.bytes[textStart] != UInt8(ascii: "<") else { return }
        let name = Array(source[text.original((tag.start + 1)..<tag.nameEnd)])
        guard policy.allowsTextKey(name, in: allowedKeys) else {
            cut(atByte: textStart)
            return
        }
        guard WrittenName.holdsNameInText(name) else { return }
        var end = close + 1
        while end < text.count, text.bytes[end] != UInt8(ascii: "<") { end += 1 }
        let range = (close + 1)..<end
        let scalars = range.isEmpty ? [] : Array(source[text.originalWithInvisiblesBefore(range)])
        if WrittenName.namesSecret(scalars, in: .quoted(after: name), policy: policy, compatibility: compatibility) {
            cut(afterByte: close)
        }
    }

    private static let tagNameCharacters = ByteSet(":-_.")
}
