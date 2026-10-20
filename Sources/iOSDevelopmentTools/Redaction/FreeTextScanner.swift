/// Reads free text for its first trigger: the point from which the rest of the text is hidden.
///
/// Free text has no grammar, so the scanner does not try to tell where a value ends. It reads the
/// text once, left to right, on the scanning copy (``NormalizedText``), and stops at the first
/// trigger:
///
/// - a secret name, with or without a separator, quoted or not, also written as a value
///   (`name="password"`, `<key>password</key>`): the text is hidden from the value after it;
/// - a key, or a name held by a key (`name=`, `label=`, …), that is not plain ASCII or has no
///   letter or digit: hidden from its value;
/// - a separator that is escaped (`%3D`, `&#61;`, `\=`) or only looks like one (`꞉`): hidden from
///   there;
/// - a word that cannot be read with certainty (mixed scripts, an invisible character in it), a
///   quote or bracket that does not close, and JSON that does not parse: hidden from there.
///
/// Everything from the trigger to the end of the text is hidden, whatever lines follow; a trigger
/// inside a tag that has not ended hides the tag from its `<`. JSON and URLs before the trigger
/// are read with their parsers and recorded as regions, which the value detectors do not read
/// again. Besides its position and the cut, the scanner keeps a few positions only: the closing
/// quote it is in, the last closing bracket and quote of each kind, the open tag and the end of
/// the line.
struct FreeTextScanner {
    /// What kind of text is read.
    enum Role {
        /// A log line, a message, a string value: every rule applies.
        case text
        /// A key that is written out, such as a JSON name or a form field name. The key rule hides
        /// its value, so its words are not read as triggers. A separator in it, plain, escaped or
        /// one that only looks like one, starts a value written into the name
        /// (`{"password=hunter2":1}`), hidden from there.
        case name
    }

    let source: [Unicode.Scalar]
    let text: NormalizedText
    let policy: RedactionPolicy
    let compatibility: CompatibilityText
    let role: Role
    /// The documents the text is in and the JSON objects and arrays around it.
    let nesting: Nesting

    /// The replacements of the JSON and URLs read before the cut.
    private(set) var spans: [RedactionPolicy.Span] = []
    private(set) var regions: [Range<Int>] = []
    /// The offset in the original scalars from which the rest of the text is hidden.
    private(set) var cut: Int?
    /// Whether JSON or a URL in the text went past a limit of ``nesting`` while the text is inside
    /// a document, so the text is hidden whole.
    private(set) var hidesWholeText = false

    var position = 0
    /// The closing double quote of the quoted text being read, plain and escaped (`\"`).
    var pendingCloses: [Int?] = [nil, nil]
    /// The last closing bracket of each kind and the last single quote and backtick in the text,
    /// so that whether one opened later closes is known without searching (see ``readMark()``).
    var lastCloses: [Int] = [-1, -1, -1]
    var lastSimpleQuotes: [Int] = [-1, -1]
    /// The `<` of a tag that has not ended yet (`<input value="…"`) and the end of its name. A
    /// trigger in it after its name moves the cut back to the `<`: an attribute that names a
    /// secret (`name="password"`, `type="password"`) may name the value of one written before it.
    var openTag: (start: Int, nameEnd: Int)?
    /// The end of the line the position is on, found once per line (see ``currentLineEnd()``).
    private var lineEndCache = -1

    init(
        source: [Unicode.Scalar], text: NormalizedText, policy: RedactionPolicy, compatibility: CompatibilityText, role: Role = .text,
        nesting: Nesting
    ) {
        self.source = source
        self.text = text
        self.policy = policy
        self.compatibility = compatibility
        self.role = role
        self.nesting = nesting
    }

    /// Whether words, quotes and brackets are read as triggers: in text, not in a name.
    var readsWords: Bool { role == .text }

    mutating func run() {
        if readsWords { noteLastMarks() }
        while position < text.count, cut == nil, !hidesWholeText { step() }
    }

    // MARK: Reading

    private mutating func step() {
        let byte = text.bytes[position]
        if text.isSpace(position) || text.isLineTerminator(position) {
            position += 1
        } else if isSeparator(position) {
            separator()
        } else if startsJSON(position) {
            embeddedJSON()
        } else if Self.marks.contains(byte), readsWords {
            readMark()
        } else if Self.boundaries.contains(byte) || Self.quotes.contains(byte), referenceLength(at: position) == nil {
            position += 1
            noteTag(byte, at: position - 1)
        } else if let end = urlEnd(from: position, lineEnd: currentLineEnd()) {
            url(to: end)
        } else {
            word()
        }
    }

    /// Characters that end a key and a word without being part of either.
    static let boundaries = ByteSet(",;&?|()[]{}<>")

    static let quotes = ByteSet("\"'`")

    /// `=` and `:`; a `:` between two digits is part of a time (`12:30`).
    func isSeparator(_ i: Int) -> Bool {
        let byte = text.bytes[i]
        if byte == UInt8(ascii: "=") { return true }
        guard byte == UInt8(ascii: ":") else { return false }
        return !(i > 0 && i + 1 < text.count && text.isDigit(i - 1) && text.isDigit(i + 1))
    }

    /// A run of `=`, `:` and `>` (`:=`, `==`, `=>`) after a key. In a name every separator starts
    /// a value. In text, a separator escaped with a backslash (`status\=…`, which a properties
    /// file reads as part of the key) is a trigger. So is a key that is not plain ASCII or has no
    /// letter or digit, no key at all (`=hunter2`), the last words before the separator when, read as one name, they name a
    /// secret (`pass word`, `c v v`, `secret&#107.;ey`), and a name after a key that holds one
    /// (`name=`, `label=`, …) that names a secret, is not plain ASCII or is JSON, which cannot be
    /// read as a name. The value of any other key is read on as text.
    private mutating func separator() {
        let start = position
        var end = position + 1
        while end < text.count, isSeparator(end) || text.bytes[end] == UInt8(ascii: ">") { end += 1 }
        position = end
        guard readsWords else {
            cut(afterByte: end - 1)
            return
        }
        if isEscaped(start) {
            cut(atByte: start)
            return
        }
        // A separator with no key before it has a name with no letter (`=hunter2`).
        guard let name = keyName(before: start), PlainName(name) != nil, !keyWordsNameSecret(before: start) else {
            cut(afterByte: end - 1)
            return
        }
        guard WrittenName.holdsNameInText(name), let valueStart = firstText(from: end) else { return }
        let valueLineEnd = valueStart <= currentLineEnd() ? currentLineEnd() : lineEnd(from: valueStart)
        if namedValueIsSecret(at: valueStart, lineEnd: valueLineEnd, key: name) { cut(afterByte: end - 1) }
    }

    /// Whether the value after a key that holds a name (`name="password"`, `label=Пароль`,
    /// `name=["pin"]`) names a secret or cannot be read as a name.
    private func namedValueIsSecret(at start: Int, lineEnd: Int, key: [Unicode.Scalar]) -> Bool {
        let byte = text.bytes[start]
        if byte == UInt8(ascii: "{") || byte == UInt8(ascii: "[") { return true }
        var range = start..<wordEnd(from: start, to: lineEnd)
        if Self.quotes.contains(byte) {
            var close = start + 1
            while close < text.count, text.bytes[close] != byte, !text.isLineTerminator(close) { close += 1 }
            range = (start + 1)..<close
        }
        let scalars = range.isEmpty ? [] : Array(source[text.originalWithInvisiblesBefore(range)])
        return WrittenName.namesSecret(scalars, in: .quoted(after: key), policy: policy, compatibility: compatibility)
    }

    // MARK: Lines

    /// The end of the line the position is on. Positions only grow, so a line's end is looked
    /// for once, not once for every word on it.
    mutating func currentLineEnd() -> Int {
        if lineEndCache < position { lineEndCache = lineEnd(from: position) }
        return lineEndCache
    }

    func lineEnd(from i: Int) -> Int {
        var end = i
        while end < text.count, !text.isLineTerminator(end) { end += 1 }
        return end
    }

    func firstNonSpace(from i: Int, to end: Int) -> Int {
        var k = i
        while k < end, text.isSpace(k) { k += 1 }
        return k
    }

    /// The first byte at or after `i` that is not white space or a line terminator; nil at the
    /// end of the text.
    func firstText(from i: Int) -> Int? {
        var k = i
        while k < text.count, text.isSpace(k) || text.isLineTerminator(k) { k += 1 }
        return k < text.count ? k : nil
    }

    // MARK: The cut

    /// Hides the text from byte `i`, the trigger, invisible characters before it included.
    mutating func cut(atByte i: Int) {
        guard i < text.count else { return }
        setCut(startOffset(ofByte: i), trigger: i)
    }

    /// The offset where byte `i` starts, invisible characters before it included.
    func startOffset(ofByte i: Int) -> Int {
        i > 0 ? min(text.offsets[i - 1] + 1, text.offsets[i]) : 0
    }

    /// Hides the text after byte `i`, the end of a trigger: what follows a secret name or a
    /// separator. White space, separators and quotes right after it are kept, so
    /// `password = "…"` reads as such.
    mutating func cut(afterByte i: Int) {
        var k = i + 1
        while k < text.count, text.isSpace(k) || text.isLineTerminator(k) || Self.keptAfterName.contains(text.bytes[k]) { k += 1 }
        setCut(k < text.count ? text.offsets[k - 1] + 1 : text.sourceCount, trigger: i)
    }

    private static let keptAfterName = ByteSet("=:\"'`")

    /// Ends the scan with the text hidden from `offset`, or from the `<` of the tag the trigger
    /// is in when it comes after the tag's name.
    private mutating func setCut(_ offset: Int, trigger: Int) {
        var offset = offset
        if let openTag, trigger >= openTag.nameEnd { offset = min(offset, startOffset(ofByte: openTag.start)) }
        cut = min(cut ?? offset, offset)
        position = text.count
    }

    /// Ends the scan with the whole text hidden: JSON or a URL in it went past a limit of the
    /// nesting budget, so what the text holds cannot be read.
    mutating func hideWholeText() {
        hidesWholeText = true
        position = text.count
    }

    mutating func record(spans found: [RedactionPolicy.Span], region: Range<Int>) {
        spans += found
        regions.append(region)
    }
}
