/// Labels written as sentences: whether a secret word in one is a label for a value elsewhere or
/// the key of a value the sentence carries itself.
extension FreeTextScanner {
    /// Whether the label of a sentence in a field that holds no name names a secret (see
    /// ``WrittenName/Shape/sentence``: `Enter PIN (4 digits)`, `PIN` of `PIN: required`,
    /// `aws:secret-access-key`): read as ``nameNamesSecret(_:compatibility:readsLongWords:)`` reads it, every
    /// word and every reading of it, but a secret word counts only when it ends a label (see
    /// ``NormalizedText/endsLabel(at:)``). `pin=1234` and `invalid, token\nretry` carry their
    /// value, which the free-text rule hides in the string, and name nothing beside it. A word
    /// that cannot be read counts, as it does there. With `readsLongWords`, a word longer than
    /// ``longestWord`` is read as any other word is (see ``readsLongWords``).
    static func labelNamesSecret(_ scalars: [Unicode.Scalar], compatibility: CompatibilityText, readsLongWords: Bool = false) -> Bool {
        guard !RedactionPolicy.isQuietWord(scalars, names: compatibility.secretNames) else { return false }
        if scalars.contains(where: ScalarClass.isHiding) || ScriptMix.mixesScripts(scalars) { return true }
        let text = NormalizedText(scalars, compatibility: compatibility)
        // Only words are read here, never JSON or URLs, so no nesting is entered.
        let scanner = FreeTextScanner(
            source: scalars, text: text, policy: .standard, compatibility: compatibility, nesting: .text(length: 0), readsLongWords: readsLongWords)
        if scanner.holdsLabel(in: 0..<text.count) { return true }
        let words = words(of: text)
        let endsLabel = { (end: Int) in text.endsLabel(at: end) }
        if LooseReading(text, words, source: scalars, names: compatibility.secretNames)?.firstSecretEnd(where: endsLabel) != nil { return true }
        if LooseReading.holdsEscapeStart(text, in: 0..<text.count),
           LooseReading(text, words, source: scalars, names: compatibility.secretNames, readsEscapeStartsAsPunctuation: true)?
               .firstSecretEnd(where: endsLabel) != nil {
            return true
        }
        guard scalars.contains(where: EscapeDecoder.startsEscape) else { return false }
        let decoded = EscapeDecoder.decode(scalars).scalars
        if ScriptMix.mixesScripts(decoded) { return true }
        let decodedText = NormalizedText(decoded, compatibility: compatibility)
        let reading = LooseReading(decodedText, Self.words(of: decodedText), source: decoded, names: compatibility.secretNames)
        return reading?.firstSecretEnd { decodedText.endsLabel(at: $0) } != nil
    }

    /// Whether a word in the bytes `range` cannot be read, or holds a secret word, also one split
    /// by a space (`pass word`), that no value follows.
    private func holdsLabel(in range: Range<Int>) -> Bool {
        var start = range.lowerBound
        while start < range.upperBound {
            guard !endsWord(start) || referenceLength(at: start) != nil else {
                start += 1
                continue
            }
            let end = wordEnd(from: start, to: range.upperBound)
            switch read(start..<end) {
            case .ambiguous:
                return true
            case .valueStart(let secretEnd):
                if text.endsLabel(at: secretEnd) { return true }
            case .plain:
                if let secretEnd = secretEndAcrossSpace(after: start..<end), text.endsLabel(at: secretEnd) { return true }
            }
            start = end
        }
        return false
    }
}

extension NormalizedText {
    /// Whether a secret word that ends before byte `end` ends a label: it ends a word, and no
    /// value is written after it. A value is `=` right after the word (`pin=1234`,
    /// `api_key=abc`), or white space or a line break and then a letter or digit
    /// (`token expired`, `token\nretry`). A label has none: the end of the text, punctuation, a
    /// quote or a bracket follows its secret word (`PIN?`, `PIN (4 digits)`, `PIN, 4 digits`,
    /// `PIN: required`, `Password = new`, `aws:secret-access-key`). A secret word that a letter or
    /// digit follows is read inside a longer word (`tokenretry`), which names no label.
    func endsLabel(at end: Int) -> Bool {
        guard end < count else { return true }
        if ASCII.isAlphanumeric(bytes[end]) || bytes[end] == CompatibilityText.unreadable || bytes[end] == UInt8(ascii: "=") { return false }
        var k = end
        while k < count, isSpace(k) || isLineTerminator(k) { k += 1 }
        return k == end || k == count || !(ASCII.isAlphanumeric(bytes[k]) || bytes[k] == CompatibilityText.unreadable)
    }
}
