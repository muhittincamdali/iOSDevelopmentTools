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

/// Words of the scanned text compared with the secret names by their ASCII skeleton: the one
/// wildcard rule of free text.
///
/// The scanned text has already read each character as the ASCII it stands for under
/// compatibility normalization and left out marks and format characters (`pässword`, `ｐａｓｓ`
/// are `password`, `pass`). Every letter, mark or number outside ASCII that is still without an
/// ASCII form is then left out: a letter or number such as `ꞏ`, `ı`, `ɑ`, `ø` or `〇`, a decimal
/// digit of another script, which the scanned text reads as its ASCII digit for numbers and the
/// detectors (`၀`, `०`, see ``ScalarClass/isDigitWithoutASCIIForm(_:)``), and a mark that the
/// scanned text left out (`ͦ`, U+0366). What remains is compared, lowercased, with the secret
/// names, a plural `s` included (see ``PlainName/firstSecret(in:where:)``).
///
/// Each such character counts as nothing or as any one letter. As nothing, `piꞏn`, `tokeın`,
/// `tokenꞏs`, `to၀ken` and `keyıs` read as `pin`, `token`, `tokens`, `token` and `keys`, however
/// many are put in. As a letter, a name counts with one of its letters missing where such a
/// character was left out, so one put in place of one of its letters is found too (`pɑssword`,
/// `user_pın`, `tͦken`, `passw〇rd`, `t၀ken`), also with more of them put in elsewhere
/// (`tͦkenͦ`, `pını`), and a word of another language that reads as a name this way is read as
/// that name (Turkish `yapın` as `pin`), which hides more on purpose. Two or more letters put in
/// place of letters of one name (`pɑsswoʀd`) are not found: no list of look-alikes is kept, a
/// documented limit of free text written without a separator. Punctuation between letters is read
/// as a separator (`pass~word`, `t*okens`), and read with the next word, `pass word` holds a
/// secret name across the space.
struct LooseReading {
    private let name: PlainName
    private let names: SecretNameTable
    /// The bytes of the skeleton, with the byte of the scanned text each came from. Where a
    /// letter came from is looked up only when a secret word is found.
    private let bytes: [UInt8]
    private let origins: [Int]

    /// Reads the bytes of `ranges` of `text`, in order, as one word with a separator between the
    /// ranges. `source` is the text `text` was made from; `names` are the secret words looked for.
    init?(_ text: NormalizedText, _ ranges: [Range<Int>], source: [Unicode.Scalar], names: SecretNameTable) {
        var bytes: [UInt8] = []
        var origins: [Int] = []
        var leftOutBefore: [Bool] = []
        var isLeavingOut = false
        let count = ranges.reduce(ranges.count) { $0 + $1.count }
        bytes.reserveCapacity(count)
        origins.reserveCapacity(count)
        leftOutBefore.reserveCapacity(count)
        func append(_ byte: UInt8, from k: Int) {
            bytes.append(byte)
            origins.append(k)
            leftOutBefore.append(isLeavingOut)
            if ASCII.isAlphanumeric(byte) { isLeavingOut = false }
        }
        for range in ranges {
            if !bytes.isEmpty { append(UInt8(ascii: " "), from: range.lowerBound) }
            for k in range {
                if Self.leftOutLetter(before: k, in: text, source: source) { isLeavingOut = true }
                let byte = text.bytes[k]
                let scalar = source[text.offsets[k]]
                if byte == CompatibilityText.unreadable, ScalarClass.isLetterOrNumber(scalar) {
                    isLeavingOut = true
                } else if ASCII.isDigit(byte), ScalarClass.isDigitWithoutASCIIForm(scalar) {
                    // The scanned text reads a digit of another script as its digit, for numbers
                    // and the detectors. It has no ASCII form, so a word leaves it out.
                    isLeavingOut = true
                } else {
                    append(byte, from: k)
                }
            }
            if !range.isEmpty, Self.leftOutLetter(before: range.upperBound, in: text, source: source) { isLeavingOut = true }
        }
        guard let name = PlainName(skeleton: bytes, leftOutBefore: leftOutBefore, leftOutAtEnd: isLeavingOut) else { return nil }
        self.name = name
        self.names = names
        self.bytes = bytes
        self.origins = origins
    }

    /// Whether the scanned text left out a mark, or a letter or number, right before byte `k`:
    /// between the scalar of the byte before it and the scalar of byte `k`, or the end of the text.
    /// Such a mark is left out of the word like a letter without an ASCII form (`tͦken`).
    private static func leftOutLetter(before k: Int, in text: NormalizedText, source: [Unicode.Scalar]) -> Bool {
        let start = k > 0 ? text.offsets[k - 1] + 1 : 0
        let end = text.offset(at: k)
        guard start < end else { return false }
        return source[start..<end].contains(where: ScalarClass.isLetterOrNumber)
    }

    /// The byte after the last letter of the first secret word that `accepts` takes. `accepts` is
    /// given the bytes of the scanned text from the first letter of the secret word to its last.
    func secretEnd(where accepts: (Range<Int>) -> Bool) -> Int? {
        var letterBytes: [Int] = []
        func span(_ letters: Range<Int>) -> Range<Int> {
            if letterBytes.isEmpty { letterBytes = bytes.indices.filter { ASCII.isAlphanumeric(bytes[$0]) } }
            return origins[letterBytes[letters.lowerBound]]..<(origins[letterBytes[letters.upperBound - 1]] + 1)
        }
        return name.firstSecret(in: names) { accepts(span($0)) }.map { span($0).upperBound }
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
