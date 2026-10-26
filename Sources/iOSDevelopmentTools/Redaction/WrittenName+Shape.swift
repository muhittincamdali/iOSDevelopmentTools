/// Strings in fields that hold no name: whether one reads as a name, as a sentence or as neither.
extension WrittenName {
    /// How a string in a field that holds no name reads as a name.
    enum Shape {
        /// A name: between its first and last letter or digit, no `:`, `=`, `,`, `;`, quote or
        /// bracket (`Password`, `Enter PIN`, `What is your PIN?`, `the token expired`). It names a
        /// secret when its words do.
        case plain
        /// A sentence: one of those marks is in it (`What's your PIN?` is a name: an apostrophe
        /// between letters is part of a word, as in free text). Its label is the part before a
        /// `:` or `=` that white space follows (see ``labelPart(of:)``). A label that is a name
        /// names a secret when its words do (`PIN: required`); any other names one when a secret
        /// word in it has no value written after it, as a label has none (`Enter PIN (4 digits)`,
        /// `PIN, 4 digits`, `"Password" field`, `aws:secret-access-key`, `api_token[0]`). A
        /// secret word with `=` right after it, or
        /// white space and a word, is the key of a value the string carries (`pin=1234`,
        /// `login with api_key=abc123`, `invalid, token\nretry`), and so is a secret word after
        /// the label (`Error: token expired`, `Error: pin`): the free-text rule hides that value
        /// in the string itself.
        case sentence
    }

    /// How a string reads as a name; nil when it is none: without a letter or digit, or a JSON
    /// object or array (`{"password":"x"}`), whose members are read as a document of their own.
    /// A string of any length is read, in one pass: the label of a long sentence
    /// (`… What is your PIN?`) is still a label. A symbol
    /// whose compatibility form is a letter or digit (`ⓟ`, `🄿`, `①`) counts as one, so a name
    /// written only in such symbols is a name. The `;` that ends a character reference
    /// (`p&#97;ssword`, `&#x63;ard`, `&amp;#xauth`) pairs nothing: it is part of the escape, which
    /// the name is read through (see ``FreeTextScanner/nameNamesSecret(_:compatibility:readsLongWords:)``). A
    /// line break does not keep a string from being a name: a name with one in it
    /// (`DbPassword\n`, `Db\nPassword`) names a secret by the one decision of
    /// ``nameNamesSecret(_:byKeyRule:readsAsLabel:readsLongWords:compatibility:)``.
    static func shape(of scalars: [Unicode.Scalar], compatibility: CompatibilityText) -> Shape? {
        let isLetterOrDigit = { (scalar: Unicode.Scalar) in Self.isLetterOrDigit(scalar, compatibility: compatibility) }
        guard let first = scalars.firstIndex(where: isLetterOrDigit), let last = scalars.lastIndex(where: isLetterOrDigit) else { return nil }
        if scalars[..<first].contains(where: { $0 == "{" || $0 == "[" }), JSONDocument.isContainer(scalars) { return nil }
        // The last scalar before the one read that cannot be inside a character reference: a `;`
        // ends one when this is the `&` that starts it. It is kept as the scan goes, so a string
        // of any length is read in one pass.
        var referenceBreak = first - 1
        while referenceBreak >= 0, continuesReference(scalars[referenceBreak]) { referenceBreak -= 1 }
        for i in first...last {
            let scalar = scalars[i]
            let pairs: Bool
            switch scalar {
            case ";": pairs = !(referenceBreak >= 0 && referenceBreak < i - 1 && scalars[referenceBreak] == "&")
            // Between two letters or digits, as `first` and `last` are.
            case "'": pairs = !(isLetterOrDigit(scalars[i - 1]) && isLetterOrDigit(scalars[i + 1]))
            default: pairs = notInNames.contains(scalar)
            }
            if pairs { return .sentence }
            if !continuesReference(scalar) { referenceBreak = i }
        }
        return .plain
    }

    /// The label of a sentence: its scalars before the first `:` or `=` that comes after a letter
    /// or digit and that white space or a line break follows (`Error` of `Error: token expired`,
    /// `PIN` of `PIN: required`, `Password ` of `Password = new`); the whole sentence when it has
    /// none (`aws:secret-access-key`, `pin=1234`).
    static func labelPart(of scalars: [Unicode.Scalar]) -> ArraySlice<Unicode.Scalar> {
        var hasWord = false
        for i in scalars.indices {
            let scalar = scalars[i]
            if scalar.isASCII ? ASCII.isAlphanumeric(UInt8(scalar.value)) : ScalarClass.isLetterOrNumber(scalar) {
                hasWord = true
            } else if hasWord, scalar == ":" || scalar == "=", i + 1 < scalars.count, scalars[i + 1].properties.isWhitespace {
                return scalars[..<i]
            }
        }
        return scalars[...]
    }

    /// Whether a string holds a label written outside printable ASCII: a separator that anything
    /// but a letter or a digit follows (white space, a line break, the end of the string, a mark),
    /// after words with a scalar outside printable ASCII in them since the start of the string or
    /// the separator before (`ΡΙΝ:`, `Enter your pɑsswoʀd:`, `Şifre: zorunlu`, `Пароль =`,
    /// `Пароль:*`, `ＰＩＮ：`, `ΡΙΝ꞉`). A separator is a `:` or an `=`, as written or as its
    /// compatibility form reads (`：`, `﹕`, `＝`, `⩴`), or a punctuation mark of any kind but a
    /// dash, or a math or modifier symbol, with no ASCII form and that does not end a sentence
    /// (`꞉`, `∶`, `·`, `→`, `」`, `»`, `“`, but not `。`, and not a dash or `…`, which read as ASCII).
    ///
    /// A label is a key written as a value, so the key rule decides it: a key that is not plain
    /// ASCII hides its value whatever it says, as a name held by a field that holds names does
    /// (`{"label":"ΡΙΝ:"}`). A label in printable ASCII is read by its words (see
    /// ``shape(of:compatibility:)``). The string is read once, at any length.
    static func holdsLabelOutsideASCII(_ scalars: [Unicode.Scalar], compatibility: CompatibilityText) -> Bool {
        var labelIsPlain = true
        var labelHasText = false
        for i in scalars.indices {
            let scalar = scalars[i]
            if isLabelSeparator(scalar, compatibility: compatibility), separatorEnds(scalars, after: i, compatibility: compatibility) {
                if labelHasText, !labelIsPlain { return true }
                labelIsPlain = true
                labelHasText = false
            } else if !scalar.properties.isWhitespace {
                labelHasText = true
                if !printableASCII.contains(scalar.value) { labelIsPlain = false }
            }
        }
        return false
    }

    private static let printableASCII: ClosedRange<UInt32> = 0x21...0x7E

    private static func isLabelSeparator(_ scalar: Unicode.Scalar, compatibility: CompatibilityText) -> Bool {
        let reading = compatibility.ascii(scalar)
        // `⩴` reads as `::=`, `⩵` as `==`: a separator however many `:` and `=` it reads as.
        if !reading.isEmpty, reading.allSatisfy({ $0 == UInt8(ascii: ":") || $0 == UInt8(ascii: "=") }) { return true }
        guard reading.count == 1, reading.first == CompatibilityText.unreadable, !scalar.properties.isSentenceTerminal else { return false }
        switch scalar.properties.generalCategory {
        case .otherPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation, .finalPunctuation,
             .connectorPunctuation, .mathSymbol, .modifierSymbol:
            return true
        default: return false
        }
    }

    /// Whether anything but a letter or a digit follows the separator at `i`, with only invisible
    /// scalars between (see ``ScalarClass/isInvisible(_:)``): white space, a line break, the end
    /// of the string or a mark (`Пароль:*`, `ΡΙΝ:)`, `Şifre=?`), but not `12:30`. Each scalar is
    /// passed over for one separator at most, so the label is still read in one pass.
    private static func separatorEnds(_ scalars: [Unicode.Scalar], after i: Int, compatibility: CompatibilityText) -> Bool {
        var j = i + 1
        while j < scalars.count, ScalarClass.isInvisible(scalars[j]) { j += 1 }
        return j == scalars.count || !isLetterOrDigit(scalars[j], compatibility: compatibility)
    }

    /// Whether a string reads as a name (see ``shape(of:compatibility:)``).
    static func isName(_ scalars: [Unicode.Scalar], compatibility: CompatibilityText) -> Bool {
        shape(of: scalars, compatibility: compatibility) != nil
    }

    /// Whether a scalar can be inside a character reference after its `&`: an ASCII letter or
    /// digit, `#`, or the `;` of a reference before it. A `;` ends a reference when only such
    /// scalars stand between it and an `&` (`&amp;`, `&#97;`, `&#x61;`, `&amp;#x63;`). Reading more
    /// as a name only ever hides more: the name still has to name a secret.
    private static func continuesReference(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isASCII && (ASCII.isAlphanumeric(UInt8(scalar.value)) || scalar == "#" || scalar == ";")
    }

    private static let notInNames = Set(":=,;\"'()[]{}<>".unicodeScalars)

    /// A letter, mark or number of any script, or a symbol whose compatibility form is ASCII
    /// letters and digits.
    private static func isLetterOrDigit(_ scalar: Unicode.Scalar, compatibility: CompatibilityText) -> Bool {
        if scalar.isASCII { return ASCII.isAlphanumeric(UInt8(scalar.value)) }
        if ScalarClass.isLetterOrNumber(scalar) { return true }
        let reading = compatibility.ascii(scalar)
        return !reading.isEmpty && reading.allSatisfy(ASCII.isAlphanumeric)
    }
}
