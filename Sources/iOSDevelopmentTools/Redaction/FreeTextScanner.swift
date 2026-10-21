/// Reads free text for its first trigger: the point from which the rest of the text is hidden.
///
/// Free text has no grammar, so the scanner does not try to tell where a value ends. It reads the
/// text once, left to right, on the scanning copy (``NormalizedText``), and stops at the first
/// trigger:
///
/// - a key before `=` or `:` that is not on the allowlist (``RedactionPolicy/allowedTextKeys``),
///   is not plain ASCII, names a secret or is missing (`x=…`, `pаssword=…`, `=…`), and JSON
///   with a member whose name is not on it (`{"x":…}`): hidden from the value;
/// - a key in quotes (`"x": …`, `'x'=…`) that is not on the allowlist: hidden from its opening
///   quote, so nothing written in the quotes shows (see ``quote()``);
/// - a secret name, with or without a separator, quoted or not, also written as a value
///   (`name="password"`): the text is hidden from the value after it;
/// - a name held by an allowed key that holds one (`name=`, `label=`, …) that names a secret or
///   is not plain ASCII: hidden from its value;
/// - a character outside the safe alphabet (see ``isOutsideSafeAlphabet(_:)``), an escape
///   (`%3D`, `&#61;`, `\x41`), which is never decoded, and a word longer than ``longestWord``:
///   hidden from there;
/// - markup: a `<` before anything but an ASCII space, tab or line break, an ASCII digit, `=` or
///   the end of the text (`<b>`, `</x>`, `<!--`, `<?pi`, `<#`): hidden from the `<` (see
///   ``startsMarkup(at:)``);
/// - a word that cannot be read with certainty (mixed scripts, an invisible character in it), a
///   quote that does not close on its line, a bracket that does not close and JSON that does not
///   parse: hidden from there;
/// - a URL that is not clean: anything but `scheme://host` with an optional path of ASCII
///   letters, digits, `.`, `_`, `-` and `/` that names no secret, followed by white space, a line
///   break or punctuation that ends a sentence (`?page=2`, `:8080`, `user@`, `%3D`, `/password`):
///   hidden from where the URL starts (see ``url(to:)``).
///
/// Everything from the trigger to the end of the text is hidden, whatever lines follow. JSON and
/// URLs before the trigger are read with their parsers and recorded as regions, which the value
/// detectors do not read again. No tag, quote or bracket is open while the scan reads: markup is
/// never parsed, and one pass of its own finds the first quote that does not close on its line
/// and the last closing bracket of each kind (see ``noteMarks()``). Besides its position and the
/// cut, the scanner keeps those positions and the end of the line only.
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
    /// The folded keys after which the text is read on.
    let allowedKeys: Set<String>

    /// The replacements of the JSON and URLs read before the cut.
    private(set) var spans: [RedactionPolicy.Span] = []
    private(set) var regions: [Range<Int>] = []
    /// The offset in the original scalars from which the rest of the text is hidden.
    private(set) var cut: Int?
    /// Whether JSON or a URL in the text went past a limit of ``nesting`` while the text is inside
    /// a document, so the text is hidden whole.
    private(set) var hidesWholeText = false

    var position = 0
    /// The last closing bracket of each kind in the text, so that whether one opened later
    /// closes is known without searching (see ``readMark()``).
    var lastCloses: [Int] = [-1, -1, -1]
    /// The first quote that does not close on its line: the byte of the quote, or of the
    /// backslashes before it when it is escaped (`\"`). The text is cut there at the latest.
    var unclosedQuote: Int?
    /// The end of the line the position is on, found once per line (see ``currentLineEnd()``).
    private var lineEndCache = -1

    init(
        source: [Unicode.Scalar], text: NormalizedText, policy: RedactionPolicy, compatibility: CompatibilityText, role: Role = .text,
        nesting: Nesting, allowedKeys: Set<String>
    ) {
        self.source = source
        self.text = text
        self.policy = policy
        self.compatibility = compatibility
        self.role = role
        self.nesting = nesting
        self.allowedKeys = allowedKeys
    }

    /// Whether words, quotes and brackets are read as triggers: in text, not in a name.
    var readsWords: Bool { role == .text }

    mutating func run() {
        if readsWords { noteMarks() }
        while position < text.count, cut == nil, !hidesWholeText { step() }
        // A quote that does not close on its line may hold a key and its value over lines
        // (`"note\nQx31": 1`): the text is cut at it, whatever the scan found after it.
        if !hidesWholeText, let unclosedQuote { cut(atByte: unclosedQuote) }
    }

    // MARK: Reading

    private mutating func step() {
        if readsWords, let control = hiddenControl(before: position) {
            cut(atOffset: control)
            return
        }
        // A character outside ASCII that the scanning copy reads as a space, a quote, a bracket or
        // a boundary (the blank Braille pattern, `（`, `，`) is judged as the character it is; a
        // separator written outside ASCII (`＝`, `：`) hides the text after it, and ``word()``
        // judges a character inside a word.
        if !isSeparator(position), isOutsideSafeAlphabet(position), firstText(from: scalarEnd(position)) != nil {
            cut(atByte: position)
            return
        }
        let byte = text.bytes[position]
        if text.isSpace(position) || text.isLineTerminator(position) {
            position += 1
        } else if isSeparator(position) {
            separator()
        } else if startsJSON(position) {
            embeddedJSON()
        } else if Self.marks.contains(byte), readsWords {
            readMark()
        } else if readsWords, startsMarkup(at: position) {
            cut(atByte: position)
        } else if Self.boundaries.contains(byte) || Self.quotes.contains(byte), referenceLength(at: position) == nil {
            // A character reference by name (`&amp;`, `&lt;`) is an escape.
            if readsWords, namedReferenceLength(at: position) != nil {
                cut(atByte: position)
                return
            }
            position += 1
        } else if let end = urlEnd(from: position, lineEnd: currentLineEnd()) {
            url(to: end)
        } else {
            word()
        }
    }

    /// Characters that end a key and a word without being part of either.
    static let boundaries = ByteSet(",;&?|()[]{}<>")

    static let quotes = ByteSet("\"'`")

    /// A run of `=`, `:` and `>` (`:=`, `==`, `=>`) after a key. In a name every separator starts
    /// a value. In text, the value is read on only after a key on ``allowedKeys``: plain ASCII,
    /// naming no secret, on the same line as its separator, which is written in ASCII. Any other
    /// key cuts the text at its value (`x=hunter2`, `Error: …`, `pаssword=…`, `user：bob`), and so
    /// does a separator with no key before it (`=hunter2`) and the last words before the separator
    /// when, read as one name, they name a secret (`pass word`, `c v v`, `secret&#107.;ey`). A
    /// separator escaped with a backslash (`status\=…`, which a properties file reads as part of
    /// the key) cuts it at the backslash. After an allowed key that holds a name (`name=`, `id=`,
    /// … when the app allows them), a name that names a secret, is not plain ASCII or is JSON,
    /// which cannot be read as a name, cuts it too.
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
        let isLookAlike = (start..<end).contains { !source[text.offsets[$0]].isASCII }
        guard !isLookAlike, !isKeyOnLineBefore(separator: start), let name = keyName(before: start),
              policy.allowsTextKey(name, in: allowedKeys), !keyWordsNameSecret(before: start)
        else {
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

    /// Whether a line break comes between the separator at `separator` and the key before it: a
    /// key is never read on from the line above.
    private func isKeyOnLineBefore(separator: Int) -> Bool {
        var k = separator
        while k > 0, text.isSpace(k - 1) || text.isLineTerminator(k - 1) {
            if text.isLineTerminator(k - 1) { return true }
            k -= 1
        }
        return false
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
        cut(atOffset: startOffset(ofByte: i))
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
        cut(atOffset: k < text.count ? text.offsets[k - 1] + 1 : text.sourceCount)
    }

    private static let keptAfterName = ByteSet("=:\"'`")

    /// Hides the text from the original scalar `offset` to its end, or from an earlier cut, and
    /// ends the scan.
    mutating func cut(atOffset offset: Int) {
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
