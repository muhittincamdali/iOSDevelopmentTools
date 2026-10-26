/// Character classes of Unicode scalars, shared by the readers of ``RedactionPolicy``.
enum ScalarClass {
    /// Letters of any script: the general categories Lu, Ll, Lt, Lm and Lo.
    static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: true
        default: false
        }
    }

    /// Letters, marks and numbers of any script: the general categories L*, M* and N*.
    static func isLetterOrNumber(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
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
        let properties = scalar.properties
        switch properties.generalCategory {
        case .format, .nonspacingMark, .enclosingMark, .spacingMark: return true
        case .control: return !isKeptControl(scalar)
        default: return properties.isVariationSelector || properties.isDefaultIgnorableCodePoint
        }
    }

    /// The invisible scalars that only hide text: all of them but marks and variation selectors,
    /// which belong to letters and emoji. A word of free text that holds one cannot be read with
    /// certainty.
    static func isHiding(_ scalar: Unicode.Scalar) -> Bool {
        let properties = scalar.properties
        switch properties.generalCategory {
        case .format: return true
        case .control: return !isKeptControl(scalar)
        case .nonspacingMark, .enclosingMark, .spacingMark: return false
        default: return properties.isDefaultIgnorableCodePoint && !properties.isVariationSelector
        }
    }

    /// Tab, line feed, carriage return, vertical tab, form feed and U+0085: the control characters
    /// that are white space or end a line.
    private static func isKeptControl(_ scalar: Unicode.Scalar) -> Bool {
        (0x09...0x0D).contains(scalar.value) || scalar.value == 0x85
    }
}
