import Foundation

/// Redaction of free text: log messages, header values, form and JSON string values.
extension RedactionPolicy {
    /// The text with secrets replaced, line by line.
    ///
    /// - `key=value`, `key: value` and `"key":"value"` are matched with the key rule: when the key
    ///   is a secret name or not plain ASCII, a quoted value is replaced up to its closing quote,
    ///   and an unquoted value with the rest of the line, because where it ends is unknown. When
    ///   nothing follows the `=` or `:` on the line, the next line with text is replaced.
    /// - A secret name that no `=` or `:` follows, as in `token abc123`, makes the rest of the
    ///   line after it ambiguous, so the rest of the line is replaced.
    /// - JWTs, bearer tokens, long hex or Base64 strings, card numbers, IBANs and email addresses
    ///   are replaced wherever they are.
    ///
    /// U+2028, U+2029, U+0085, vertical tab and form feed are folded to LF before the text is
    /// split into lines, so the stored text breaks lines where the check did. CR and CRLF end a
    /// line too and are kept as they are.
    public func redact(text: String) -> String {
        guard isEnabled, !text.isEmpty else { return text }
        var output = String.UnicodeScalarView()
        var hidesLine = false
        for line in Self.lines(of: text) {
            if hidesLine, line.content.contains(where: { !$0.properties.isWhitespace }) {
                output.append(contentsOf: line.content.prefix { $0.properties.isWhitespace })
                output.append(contentsOf: Self.replacement.unicodeScalars)
                hidesLine = false
            } else {
                let (keyed, valueContinues) = redactKeyedValues(in: line.content)
                output.append(contentsOf: ValueDetectors.redacting(keyed).scalars)
                hidesLine = hidesLine || valueContinues
            }
            output.append(contentsOf: Self.foldedLineSeparators.contains(line.terminator) ? ["\n"] : line.terminator)
        }
        return String(output)
    }

    /// The line separators that are written as LF.
    private static let foldedLineSeparators: Set<[Unicode.Scalar]> = [["\u{0B}"], ["\u{0C}"], ["\u{85}"], ["\u{2028}"], ["\u{2029}"]]

    /// The text split into lines, each with its terminator (empty for the last line).
    static func lines(of text: String) -> [(content: [Unicode.Scalar], terminator: [Unicode.Scalar])] {
        let scalars = Array(text.unicodeScalars)
        var lines: [(content: [Unicode.Scalar], terminator: [Unicode.Scalar])] = []
        var start = 0
        var index = 0
        while index < scalars.count {
            guard lineTerminators.contains(scalars[index]) else {
                index += 1
                continue
            }
            let isCRLF = scalars[index] == "\r" && index + 1 < scalars.count && scalars[index + 1] == "\n"
            let end = index + (isCRLF ? 2 : 1)
            lines.append((Array(scalars[start..<index]), Array(scalars[index..<end])))
            start = end
            index = end
        }
        lines.append((Array(scalars[start...]), []))
        return lines
    }

    private static let lineTerminators: Set<Unicode.Scalar> = ["\n", "\r", "\u{0B}", "\u{0C}", "\u{85}", "\u{2028}", "\u{2029}"]

    /// How a hidden value ended.
    enum HiddenValue {
        /// A quoted value was replaced; scanning goes on at this index.
        case resume(Int)
        /// The rest of the line was replaced.
        case restOfLine
        /// Nothing followed the `=` or `:`; the value may be on the next line.
        case onNextLine
    }

    /// Appends the hidden value that starts at `start`, after optional spaces: a quoted value is
    /// replaced up to its closing quote, anything else up to the end of the line.
    func appendHiddenValue(of line: [Unicode.Scalar], from start: Int, to output: inout [Unicode.Scalar]) -> HiddenValue {
        var index = start
        while index < line.count, Self.isSpaceOrTab(line[index]) {
            output.append(line[index])
            index += 1
        }
        guard index < line.count else { return .onNextLine }
        if let (open, close) = Self.quotedValue(in: line, at: index) {
            output += line[index..<open]
            output += Self.replacement.unicodeScalars
            output += line[close]
            return .resume(close.upperBound)
        }
        output += Self.replacement.unicodeScalars
        return .restOfLine
    }

    /// The end of the opening quote at `index` and the range of its closing quote: `"…"`, `'…'`,
    /// or `\"…\"` in escaped JSON. A quote after an odd number of backslashes does not close.
    private static func quotedValue(in line: [Unicode.Scalar], at index: Int) -> (Int, Range<Int>)? {
        let isEscaped = line[index] == "\\"
        let quoteIndex = isEscaped ? index + 1 : index
        guard quoteIndex < line.count, line[quoteIndex] == "\"" || line[quoteIndex] == "'" else { return nil }
        let quote = line[quoteIndex]
        var backslashes = 0
        for position in (quoteIndex + 1)..<max(quoteIndex + 1, line.count) {
            let scalar = line[position]
            if scalar == quote {
                if isEscaped, backslashes % 2 == 1 { return (quoteIndex + 1, (position - 1)..<(position + 1)) }
                if !isEscaped, backslashes % 2 == 0 { return (quoteIndex + 1, position..<(position + 1)) }
            }
            backslashes = scalar == "\\" ? backslashes + 1 : 0
        }
        return nil
    }

    static func isSpaceOrTab(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t"
    }

    static func isLetterOrNumber(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isAlphabetic || scalar.properties.numericType != nil
    }
}
