/// Words read after their escapes are decoded, and the secret words in them.
extension FreeTextScanner {
    /// Reads a word that no separator follows, after its escapes are decoded (see
    /// ``EscapeDecoder``): whether it can be read with certainty, and where the first secret word
    /// in it ends.
    func read(_ range: Range<Int>) -> WordReading {
        let scalars = source[text.originalWithInvisiblesBefore(range)]
        guard scalars.contains(where: EscapeDecoder.startsEscape) else {
            if Self.isAmbiguous(scalars) { return .ambiguous }
            return LooseReading(text, [range], source: source, names: policy.secretNameTable)?.secretEnd { _ in true }.map { .valueStart($0) } ?? .plain
        }
        let decoded = DecodedWord(range, in: self)
        if Self.isAmbiguous(scalars) || Self.isAmbiguous(decoded.scalars) { return .ambiguous }
        let reading = LooseReading(decoded.text, [0..<decoded.text.count], source: decoded.scalars, names: policy.secretNameTable)
        return decoded.byteIndex(of: reading?.secretEnd { _ in true }).map { .valueStart($0) } ?? .plain
    }

    /// Whether a word cannot be read with certainty: it holds a character that only hides text
    /// (see ``ScalarClass/hidesText(_:)``) or mixes scripts (see ``ScriptMix``).
    static func isAmbiguous(_ scalars: some Collection<Unicode.Scalar>) -> Bool {
        // Printable ASCII hides nothing and is all one script; most words are read here.
        if scalars.allSatisfy({ $0.isASCII && !ASCII.isHidingControl(UInt8($0.value)) }) { return false }
        return ScalarClass.hidesText(scalars) || ScriptMix.mixesScripts(scalars)
    }

    /// Where a value written into a word with escapes starts: at an escaped `=` or `:`
    /// (`password%3D…`, `a&#61;b`), or where a value detector finds something once the word is
    /// decoded (`a\u0040b.com`, `eyJ…%2EeyJ…`).
    func escapedValueStart(in range: Range<Int>) -> Int? {
        guard source[text.original(range)].contains(where: EscapeDecoder.startsEscape) else { return nil }
        let decoded = DecodedWord(range, in: self)
        let separator = decoded.text.bytes.firstIndex { $0 == UInt8(ascii: "=") || $0 == UInt8(ascii: ":") }
        let finding = policy.detectorSpans(in: decoded.text).map(\.start).min().map { decoded.text.byteIndex(atOrAfter: $0) }
        return decoded.byteIndex(of: [separator, finding].compactMap { $0 }.min())
    }

    /// Whether a text, read in words as the free-text rule reads them, has a word that holds a
    /// secret name or cannot be read: in an array such as `["password","…"]`, the elements after
    /// it are hidden, as such a word hides the rest of a line, and in a URL path the segment after
    /// such a segment is hidden.
    static func mentionsSecret(_ scalars: [Unicode.Scalar], policy: RedactionPolicy, compatibility: CompatibilityText) -> Bool {
        guard !policy.isQuietWord(scalars) else { return false }
        return mentionsSecret(scalars, text: NormalizedText(scalars, compatibility: compatibility), policy: policy, compatibility: compatibility)
    }

    /// Whether a name written as a value (a quoted value, a JSON string) names a secret or cannot
    /// be read: a word of it does (see ``mentionsSecret(_:policy:compatibility:)``), its words mix scripts
    /// (`рԝ d`, as a word that mixes them cannot be read), or its words, with their escapes
    /// decoded, read as one name, as the words of a key are (`pass word`, `id_tok e n`,
    /// `c v%2576`).
    static func nameNamesSecret(_ scalars: [Unicode.Scalar], policy: RedactionPolicy, compatibility: CompatibilityText) -> Bool {
        // One short plain word holds no secret word, alone or read with others.
        guard !policy.isQuietWord(scalars) else { return false }
        let plainText = NormalizedText(scalars, compatibility: compatibility)
        if mentionsSecret(scalars, text: plainText, policy: policy, compatibility: compatibility) { return true }
        let hasEscapes = scalars.contains(where: EscapeDecoder.startsEscape)
        let decoded = hasEscapes ? EscapeDecoder.decode(scalars).scalars : scalars
        if ScriptMix.mixesScripts(decoded) { return true }
        let text = hasEscapes ? NormalizedText(decoded, compatibility: compatibility) : plainText
        return wordsNameSecret(text, decoded: decoded, endingInLastWord: false, policy: policy)
    }

    /// Whether words, with their escapes decoded, read as one name name a secret, as the words
    /// of a key are read; with `endingInLastWord`, only a secret that ends in the last word counts.
    static func wordsNameSecret(_ scalars: [Unicode.Scalar], endingInLastWord: Bool, policy: RedactionPolicy, compatibility: CompatibilityText) -> Bool {
        let hasEscapes = scalars.contains(where: EscapeDecoder.startsEscape)
        let decoded = hasEscapes ? EscapeDecoder.decode(scalars).scalars : scalars
        let text = NormalizedText(decoded, compatibility: compatibility)
        return wordsNameSecret(text, decoded: decoded, endingInLastWord: endingInLastWord, policy: policy)
    }

    private static func wordsNameSecret(_ text: NormalizedText, decoded: [Unicode.Scalar], endingInLastWord: Bool, policy: RedactionPolicy) -> Bool {
        var words: [Range<Int>] = []
        var k = 0
        while k < text.count {
            guard !text.isSpace(k), !text.isLineTerminator(k) else {
                k += 1
                continue
            }
            let start = k
            while k < text.count, !text.isSpace(k), !text.isLineTerminator(k) { k += 1 }
            words.append(start..<k)
        }
        guard let last = words.last, let reading = LooseReading(text, words, source: decoded, names: policy.secretNameTable) else { return false }
        return reading.secretEnd { !endingInLastWord || $0.upperBound > last.lowerBound } != nil
    }

    /// ``mentionsSecret(_:policy:compatibility:)`` on a scanning copy that is already made. A
    /// backslash escape is not read in any form: a name with one cannot be read
    /// (`pa\x{73}sword`), as it cuts free text (see ``backslashEscapes(at:)``). The words of JSON
    /// written into a line are read without this rule (see ``mentionsSecret(in:)``): a backslash
    /// in them is a JSON escape, which the JSON parser reads.
    static func mentionsSecret(_ scalars: [Unicode.Scalar], text: NormalizedText, policy: RedactionPolicy, compatibility: CompatibilityText) -> Bool {
        // Only words are read here, never JSON or URLs, so no nesting is entered.
        let scanner = FreeTextScanner(
            source: scalars, text: text, policy: policy, compatibility: compatibility, nesting: .text(length: 0), allowedKeys: policy.allowedTextKeys)
        if (0..<text.count).contains(where: scanner.startsBackslashEscape) { return true }
        return scanner.mentionsSecret(in: 0..<text.count) || ScalarClass.hidesText(scalars)
    }

    /// Whether a word in the bytes `range` of the text holds a secret name or cannot be read.
    func mentionsSecret(in range: Range<Int>) -> Bool {
        var start = range.lowerBound
        while start < range.upperBound {
            guard !endsWord(start) || referenceLength(at: start) != nil else {
                start += 1
                continue
            }
            let end = wordEnd(from: start, to: range.upperBound)
            if read(start..<end) != .plain { return true }
            start = end
        }
        return false
    }
}

/// Words of the scanned text read loosely for the secret words in them. In every reading,
/// punctuation between letters is read as a separator (`pass~word`, `t*okens`; see
/// ``PlainName/init(looseBytes:wildcards:)``), and format characters are already left out of the
/// scanned text. A letter, mark or number with no ASCII form is a wildcard, read as any one letter
/// or as none:
///
/// - The loose reading takes a letter or number without an ASCII form (`ɑ`, `ı`, `〇`) as any
///   letter (`Authorizɑtion`, `pın`, `passw〇rd`), and leaves marks out, as the scanned text does.
/// - The ASCII skeleton leaves them all out (`tokensı`, `pıaıssword`, `tokenꞏꞏ`, `t̷o̷k̷e̷n̷`).
/// - When the word has a mark written after a character with an ASCII form, which the scanned text
///   leaves out (`tͦken`, U+0366 after the `t`), the marked reading takes that mark as any letter
///   too.
///
/// Read with the next word, `pass word` holds a secret word too.
struct LooseReading {
    private let loose: PlainName
    /// The skeleton; nil when the word has no letter or number without an ASCII form, or only such.
    private let skeleton: PlainName?
    /// The marked reading; nil when the word has no mark after a character with an ASCII form.
    private let marked: PlainName?
    private let names: SecretNameTable
    /// The bytes read, with the byte of the scanned text each came from and those read as any
    /// letter. Where a letter came from is looked up only when a secret word is found.
    private let bytes: [UInt8]
    private let origins: [Int]
    /// Whether each byte is a letter or number without an ASCII form.
    private let wildcards: [Bool]
    /// Whether each byte stands for a mark after a character with an ASCII form, which the
    /// scanned text does not hold.
    private let marks: [Bool]

    /// Reads the bytes of `ranges` of `text`, in order, as one word with a separator between the
    /// ranges. `source` is the text `text` was made from; `names` are the secret words looked for.
    init?(_ text: NormalizedText, _ ranges: [Range<Int>], source: [Unicode.Scalar], names: SecretNameTable) {
        var bytes: [UInt8] = []
        var origins: [Int] = []
        var wildcards: [Bool] = []
        var marks: [Bool] = []
        let count = ranges.reduce(ranges.count) { $0 + $1.count }
        bytes.reserveCapacity(count)
        origins.reserveCapacity(count)
        wildcards.reserveCapacity(count)
        marks.reserveCapacity(count)
        func append(_ byte: UInt8, from origin: Int, wildcard: Bool = false, mark: Bool = false) {
            bytes.append(byte)
            origins.append(origin)
            wildcards.append(wildcard)
            marks.append(mark)
        }
        for range in ranges {
            if !bytes.isEmpty { append(UInt8(ascii: " "), from: range.lowerBound) }
            for k in range {
                // Marks before the byte belong to the character before it: one wildcard, unless
                // that character is a wildcard already.
                if wildcards.last != true, Self.hasMark(in: Self.gap(before: k, in: text), source: source) {
                    append(CompatibilityText.unreadable, from: max(k - 1, range.lowerBound), mark: true)
                }
                let isWildcard = text.bytes[k] == CompatibilityText.unreadable && ScalarClass.isLetterOrNumber(source[text.offsets[k]])
                append(text.bytes[k], from: k, wildcard: isWildcard)
            }
            if let last = range.last, wildcards.last != true, Self.hasMark(in: Self.gap(before: range.upperBound, in: text), source: source) {
                append(CompatibilityText.unreadable, from: last, mark: true)
            }
        }
        let hasMarks = marks.contains(true)
        // Most words have no such mark: their loose reading is all of their bytes.
        let loose = hasMarks ? Self.reading(bytes, wildcards: wildcards, keeping: { !marks[$0] }) : PlainName(looseBytes: bytes, wildcards: wildcards)
        guard let loose else { return nil }
        self.loose = loose
        skeleton = wildcards.contains(true) ? Self.reading(bytes, wildcards: nil, keeping: { !wildcards[$0] && !marks[$0] }) : nil
        marked = hasMarks ? PlainName(looseBytes: bytes, wildcards: zip(wildcards, marks).map { $0 || $1 }) : nil
        self.names = names
        self.bytes = bytes
        self.origins = origins
        self.wildcards = wildcards
        self.marks = marks
    }

    /// The original scalars between byte `k` and the byte before it, which the scanned text left
    /// out: marks, format characters and other invisible scalars.
    private static func gap(before k: Int, in text: NormalizedText) -> Range<Int> {
        let start = k > 0 ? text.offsets[k - 1] + 1 : 0
        return start..<max(start, text.offset(at: k))
    }

    private static func hasMark(in gap: Range<Int>, source: [Unicode.Scalar]) -> Bool {
        source[gap].contains { scalar in
            switch ScalarTable.category(scalar) {
            case .nonspacingMark, .spacingMark, .enclosingMark: true
            default: false
            }
        }
    }

    /// The bytes that `keeps` keeps, read as a name, with `wildcards` (none when nil) read as any
    /// letter: the skeleton reads `tokensı` and `tokenꞏsꞏ` as `tokens`, `myTokensı` as
    /// `myTokens`, `pıaıssword` as `password` and `t̷o̷k̷e̷n̷` as `token`.
    private static func reading(_ bytes: [UInt8], wildcards: [Bool]?, keeping keeps: (Int) -> Bool) -> PlainName? {
        let kept = bytes.indices.filter(keeps)
        return PlainName(looseBytes: kept.map { bytes[$0] }, wildcards: kept.map { wildcards?[$0] ?? false })
    }

    /// The byte after the last letter of the first secret word that `accepts` takes, in the
    /// reading where it ends first. `accepts` is given the bytes of the scanned text from the
    /// first letter of the secret word to its last.
    func secretEnd(where accepts: (Range<Int>) -> Bool) -> Int? {
        var ends = [secretEnd(in: loose, letters: { ASCII.isAlphanumeric(bytes[$0]) || wildcards[$0] }, accepts)]
        if let skeleton { ends.append(secretEnd(in: skeleton, letters: { ASCII.isAlphanumeric(bytes[$0]) }, accepts)) }
        if let marked { ends.append(secretEnd(in: marked, letters: { ASCII.isAlphanumeric(bytes[$0]) || wildcards[$0] || marks[$0] }, accepts)) }
        return ends.compactMap { $0 }.min()
    }

    /// `isLetter` tells which bytes are the letters of `reading`.
    private func secretEnd(in reading: PlainName, letters isLetter: (Int) -> Bool, _ accepts: (Range<Int>) -> Bool) -> Int? {
        var letterBytes: [Int] = []
        func span(_ letters: Range<Int>) -> Range<Int> {
            if letterBytes.isEmpty { letterBytes = bytes.indices.filter(isLetter) }
            return origins[letterBytes[letters.lowerBound]]..<(origins[letterBytes[letters.upperBound - 1]] + 1)
        }
        return reading.firstSecret(in: names) { accepts(span($0)) }.map { span($0).upperBound }
    }
}

/// A word of free text with its escapes decoded, and the way back to the bytes it came from.
struct DecodedWord {
    let scalars: [Unicode.Scalar]
    let text: NormalizedText
    private let origins: [Int]
    private let original: Range<Int>
    private let wordEnd: Int
    private let scannedText: NormalizedText

    init(_ range: Range<Int>, in scanner: FreeTextScanner) {
        original = scanner.text.original(range)
        (scalars, origins) = EscapeDecoder.decode(Array(scanner.source[original]))
        text = NormalizedText(scalars, compatibility: scanner.compatibility)
        wordEnd = range.upperBound
        scannedText = scanner.text
    }

    /// The byte of the scanned text that a byte of the decoded word came from; the end of the
    /// word for the end of the decoded word.
    func byteIndex(of decodedByte: Int?) -> Int? {
        guard let decodedByte else { return nil }
        let scalar = text.offset(at: decodedByte)
        guard scalar < scalars.count else { return wordEnd }
        return scannedText.byteIndex(atOrAfter: original.lowerBound + origins[scalar])
    }
}
