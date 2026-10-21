/// Character classes of Unicode scalars, shared by the readers of keys, free text and values.
enum ScalarClass {
    /// Letters of any script: the general categories Lu, Ll, Lt, Lm and Lo.
    static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch ScalarTable.category(scalar) {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: true
        default: false
        }
    }

    /// Letters, marks and numbers of any script: the general categories L*, M* and N*.
    static func isLetterOrNumber(_ scalar: Unicode.Scalar) -> Bool {
        switch ScalarTable.category(scalar) {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber: true
        default: false
        }
    }

    /// The value of a decimal digit in any script (ASCII, full-width, Arabic-Indic, ...).
    static func decimalDigit(_ scalar: Unicode.Scalar) -> UInt8? {
        guard scalar.properties.numericType == .decimal,
              let value = scalar.properties.numericValue,
              value >= 0, value <= 9
        else { return nil }
        return UInt8(value)
    }

    /// Whether a scalar is a decimal digit of another script, one with no ASCII form under
    /// compatibility decomposition (`၀` U+1040, `०` U+0966, `٠` U+0660): every decimal digit outside
    /// ASCII but the full-width, outlined, mathematical and segmented ones, which decompose to an
    /// ASCII digit. The scanning copy reads it as its digit, for numbers and the value detectors,
    /// and a word reads it as the wildcard (see ``LooseReading``). A test compares this with
    /// Foundation's decomposition for every decimal digit.
    static func isDigitWithoutASCIIForm(_ scalar: Unicode.Scalar) -> Bool {
        guard !scalar.isASCII, decimalDigit(scalar) != nil else { return false }
        return !digitsWithASCIIForm.contains { $0.contains(scalar.value) }
    }

    private static let digitsWithASCIIForm: [ClosedRange<UInt32>] = [0xFF10...0xFF19, 0x1CCF0...0x1CCF9, 0x1D7CE...0x1D7FF, 0x1FBF0...0x1FBF9]

    /// Scalars that can be put into a value without changing how it looks, and that the scanning
    /// copy leaves out: format characters, marks, variation selectors, every default-ignorable
    /// code point (fillers such as U+115F and U+3164, unassigned ones such as U+FFF0 and
    /// U+E0080), and control characters other than tab and the line terminators.
    static func isInvisible(_ scalar: Unicode.Scalar) -> Bool {
        switch ScalarTable.category(scalar) {
        case .format, .nonspacingMark, .enclosingMark, .spacingMark: return true
        case .control: return !isKeptControl(scalar)
        default: return ScalarTable.isVariationSelector(scalar) || ScalarTable.isDefaultIgnorable(scalar)
        }
    }

    /// The invisible scalars that only hide text: all of them but marks and variation selectors,
    /// which belong to letters and emoji. A word of free text that holds one cannot be read with
    /// certainty.
    static func isHiding(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.isASCII { return scalar.value < 0x20 && !isKeptControl(scalar) || scalar.value == 0x7F }
        switch ScalarTable.category(scalar) {
        case .format: return true
        case .control: return !isKeptControl(scalar)
        case .nonspacingMark, .enclosingMark, .spacingMark: return false
        default: return ScalarTable.isDefaultIgnorable(scalar) && !ScalarTable.isVariationSelector(scalar)
        }
    }

    /// Whether the scalars hold one that only hides text (see ``isHiding(_:)``). A zero-width
    /// joiner between two emoji (`👩‍💻`, `❤️‍🔥`) joins them into one emoji, as Unicode defines
    /// emoji sequences, and hides nothing; one next to a letter, digit or other character does.
    static func hidesText(_ scalars: some Collection<Unicode.Scalar>) -> Bool {
        let scalars = Array(scalars)
        for (index, scalar) in scalars.enumerated() where isHiding(scalar) {
            guard scalar == zeroWidthJoiner, index > 0, index + 1 < scalars.count else { return true }
            let before = scalars[..<index].last { !ScalarTable.isVariationSelector($0) }
            guard let before, isEmoji(before), isEmoji(scalars[index + 1]) else { return true }
        }
        return false
    }

    private static let zeroWidthJoiner: Unicode.Scalar = "\u{200D}"

    /// An emoji that is not ASCII (`#` and digits are emoji too, with a keycap) or a skin tone.
    static func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
        !scalar.isASCII && ScalarTable.isEmoji(scalar)
    }

    /// Tab, line feed, carriage return, vertical tab, form feed and U+0085: the control characters
    /// that are white space or end a line.
    private static func isKeptControl(_ scalar: Unicode.Scalar) -> Bool {
        (0x09...0x0D).contains(scalar.value) || scalar.value == 0x85
    }
}
