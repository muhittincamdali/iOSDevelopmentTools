/// A JSON number read as the decimal it stands for.
///
/// A serializer may write a card number with an exponent: Jackson and Gson write a `double` as
/// `4.111111111111111E15`, and any writer may produce `4111111111111111e0`. The value detectors
/// read digits that run into a letter as an identifier, and a `.` ends a run of digits, so the
/// number as written holds no card number. Written out without its exponent, it is the same text
/// as the same value written plainly, and the detectors read it the same way.
enum JSONNumber {
    /// The most zeros the exponent adds before or after the digits. A longer run of digits is a
    /// long token either way (``NormalizedText/longTokenLength``) and never a card number, so a
    /// larger exponent changes nothing the detectors find, and `1e999999999` is not written out.
    static let longestPadding = NormalizedText.longTokenLength

    /// The exponent is read up to this value: past it the padding is at its longest anyway.
    private static let largestExponent = 1_000_000_000

    private enum Part {
        case integer, fraction, exponent
    }

    /// The decimal that `literal` stands for, or nil when it has no exponent and is already
    /// written as its decimal. `literal` is a number as the JSON grammar writes it,
    /// `-? (0 | [1-9][0-9]*) (. [0-9]+)? ([eE] [+-]? [0-9]+)?`, as ``JSONDocument`` reads it.
    ///
    /// The decimal has no sign, no leading zeros before its point and no trailing zeros after it:
    /// `4.111111111111111E15`, `41111111111111110e-1` and `0.4111111111111111e16` are all
    /// `4111111111111111`, and `5105105105105e3` is `5105105105105000`.
    static func plainDecimal(_ literal: some Collection<Unicode.Scalar>) -> [Unicode.Scalar]? {
        var digits: [Unicode.Scalar] = []
        digits.reserveCapacity(literal.count)
        var integerCount = 0
        var exponent = 0
        var exponentIsNegative = false
        var part = Part.integer
        for scalar in literal {
            switch scalar {
            case ".": part = .fraction
            case "e", "E": part = .exponent
            case "-": exponentIsNegative = part == .exponent
            case "+": break
            default:
                switch part {
                case .integer:
                    digits.append(scalar)
                    integerCount += 1
                case .fraction:
                    digits.append(scalar)
                case .exponent:
                    exponent = min(exponent * 10 + Int(scalar.value - ("0" as Unicode.Scalar).value), largestExponent)
                }
            }
        }
        guard part == .exponent else { return nil }
        return written(digits, point: integerCount + (exponentIsNegative ? -exponent : exponent))
    }

    /// `digits` with the decimal point before the digit at `point`, which may be before the
    /// first digit or after the last; the zeros that fill the gap are at most ``longestPadding``.
    private static func written(_ digits: [Unicode.Scalar], point: Int) -> [Unicode.Scalar] {
        func zeros(_ count: Int) -> Repeated<Unicode.Scalar> {
            repeatElement("0", count: min(count, longestPadding))
        }
        let integer: [Unicode.Scalar]
        let fraction: [Unicode.Scalar]
        if point <= 0 {
            integer = []
            fraction = Array(zeros(-point)) + digits
        } else if point >= digits.count {
            integer = digits + zeros(point - digits.count)
            fraction = []
        } else {
            integer = Array(digits[..<point])
            fraction = Array(digits[point...])
        }
        let integerStart = integer.firstIndex { $0 != "0" } ?? integer.endIndex
        let fractionEnd = (fraction.lastIndex { $0 != "0" }).map { $0 + 1 } ?? 0
        var plain: [Unicode.Scalar] = integerStart == integer.endIndex ? ["0"] : Array(integer[integerStart...])
        if fractionEnd > 0 {
            plain.append(".")
            plain += fraction[..<fractionEnd]
        }
        return plain
    }
}
