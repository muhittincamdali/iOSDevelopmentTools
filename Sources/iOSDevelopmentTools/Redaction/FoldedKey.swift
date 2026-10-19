import Foundation

/// A key after folding: escapes decoded (`%XX`, `\uXXXX`, `&#NN;`, `&#xHH;`, repeated up to four
/// times), then NFKC, case folding, and `_`, `-`, `.` and spaces removed.
///
/// A key that is not plain ASCII letters and digits after folding (a Cyrillic or Greek letter, a
/// combining mark, a zero-width or other format character, a `[`, a `;`) is never compared with
/// the secret names: its value is hidden. Look-alike letters are not mapped to Latin ones, so
/// there is no table to keep up to date.
struct FoldedKey: Hashable {
    /// The folded key. Compared with secret names only when ``isPlain``.
    let folded: String
    /// ``folded`` as UTF-8.
    let foldedBytes: [UInt8]
    /// The ASCII letter and digit runs of the key after NFKC, lowercased: split at other
    /// characters and where a lowercase letter or digit meets an uppercase one (`xApiKey` gives
    /// `x`, `api`, `key`), and also split at other characters only, so a mixed-case word such as
    /// `kEy_name` still gives `key`.
    let words: [[UInt8]]
    /// Whether ``folded`` holds only `a`–`z` and `0`–`9`.
    let isPlain: Bool

    private static let maximumUnescapingRounds = 4

    init(_ key: String) {
        // Plain ASCII without escape characters is its own NFKC form, and folds by lowercasing.
        guard !key.utf8.allSatisfy(Self.isPlainASCIIByte) else {
            words = Self.matchingWords(in: key)
            var result = String.UnicodeScalarView()
            for byte in key.utf8 where !Self.foldedSeparators.contains(Unicode.Scalar(byte)) {
                result.append(Unicode.Scalar(("A"..."Z").contains(Unicode.Scalar(byte)) ? byte + 0x20 : byte))
            }
            folded = String(result)
            foldedBytes = Array(folded.utf8)
            isPlain = folded.unicodeScalars.allSatisfy(Self.isLowercaseLetterOrDigit)
            return
        }
        var text = key
        for _ in 0..<Self.maximumUnescapingRounds {
            let next = Self.unescaped(text)
            guard next != text else { break }
            text = next
        }
        let compatible = text.precomposedStringWithCompatibilityMapping
        words = Self.matchingWords(in: compatible)
        let caseFolded = compatible.folding(options: [.caseInsensitive], locale: nil)
        var result = String.UnicodeScalarView()
        for scalar in caseFolded.unicodeScalars where !Self.foldedSeparators.contains(scalar) {
            result.append(scalar)
        }
        folded = String(result)
        foldedBytes = Array(folded.utf8)
        isPlain = folded.unicodeScalars.allSatisfy(Self.isLowercaseLetterOrDigit)
    }

    private static let foldedSeparators: Set<Unicode.Scalar> = ["_", "-", ".", " "]

    /// ASCII other than the characters that start an escape (`%`, `\`, `&`).
    private static func isPlainASCIIByte(_ byte: UInt8) -> Bool {
        byte < 0x80 && byte != UInt8(ascii: "%") && byte != UInt8(ascii: "\\") && byte != UInt8(ascii: "&")
    }

    static func isLowercaseLetterOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar)
    }

    static func isASCIILetterOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        isLowercaseLetterOrDigit(scalar) || ("A"..."Z").contains(scalar)
    }

    /// The words of ``words``: the case-split runs, then the runs of the lowercased text.
    private static func matchingWords(in text: String) -> [[UInt8]] {
        words(in: text) + words(in: text.lowercased())
    }

    /// The ASCII letter and digit runs of the text, split at other characters and where a
    /// lowercase letter or digit meets an uppercase one, lowercased.
    static func words(in text: String) -> [[UInt8]] {
        var words: [[UInt8]] = []
        var current: [UInt8] = []
        var previous: Unicode.Scalar?
        for scalar in text.unicodeScalars {
            guard isASCIILetterOrDigit(scalar) else {
                if !current.isEmpty { words.append(current) }
                current = []
                previous = nil
                continue
            }
            let isUppercase = ("A"..."Z").contains(scalar)
            if let previous, isUppercase, isLowercaseLetterOrDigit(previous), !current.isEmpty {
                words.append(current)
                current = []
            }
            current.append(UInt8(scalar.value) + (isUppercase ? 0x20 : 0))
            previous = scalar
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    // MARK: Escapes

    /// The text with one round of `%XX`, `\uXXXX`, `&#NN;` and `&#xHH;` escapes decoded. Invalid
    /// sequences are kept, so they leave a `%`, `\` or `&` that makes the key not plain.
    static func unescaped(_ text: String) -> String {
        let percentDecoded = percentDecoded(text)
        let scalars = Array(percentDecoded.unicodeScalars)
        var output = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            if let (scalar, length) = escape(in: scalars, at: index) {
                output.append(scalar)
                index += length
            } else {
                output.append(scalars[index])
                index += 1
            }
        }
        return String(output)
    }

    /// The text with every valid `%XX` sequence decoded as UTF-8 bytes; bytes that do not form
    /// UTF-8 become U+FFFD, which is not plain.
    static func percentDecoded(_ text: String) -> String {
        let bytes = Array(text.utf8)
        guard bytes.contains(UInt8(ascii: "%")) else { return text }
        var decoded: [UInt8] = []
        decoded.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "%"), index + 2 < bytes.count,
               let high = hexValue(Unicode.Scalar(bytes[index + 1])), let low = hexValue(Unicode.Scalar(bytes[index + 2])) {
                decoded.append(UInt8(high << 4 | low))
                index += 3
            } else {
                decoded.append(bytes[index])
                index += 1
            }
        }
        return String(decoding: decoded, as: UTF8.self)
    }

    /// The scalar of a `\uXXXX`, `&#NN;` or `&#xHH;` escape at `index`, and its length.
    private static func escape(in scalars: [Unicode.Scalar], at index: Int) -> (Unicode.Scalar, Int)? {
        if scalars[index] == "\\", index + 5 < scalars.count, scalars[index + 1] == "u" {
            let digits = scalars[(index + 2)..<(index + 6)]
            guard let value = number(digits, radix: 16), let scalar = Unicode.Scalar(value) else { return nil }
            return (scalar, 6)
        }
        guard scalars[index] == "&", index + 3 < scalars.count, scalars[index + 1] == "#" else { return nil }
        let isHex = scalars[index + 2] == "x" || scalars[index + 2] == "X"
        let digitsStart = index + (isHex ? 3 : 2)
        guard let end = scalars[digitsStart...].prefix(9).firstIndex(of: ";"), end > digitsStart,
              let value = number(scalars[digitsStart..<end], radix: isHex ? 16 : 10),
              let scalar = Unicode.Scalar(value) else { return nil }
        return (scalar, end + 1 - index)
    }

    private static func number(_ digits: ArraySlice<Unicode.Scalar>, radix: UInt32) -> UInt32? {
        // Eight digits fit in a UInt32 in both bases; no scalar needs more.
        guard digits.count <= 8 else { return nil }
        var value: UInt32 = 0
        for digit in digits {
            guard let digitValue = radix == 16 ? hexValue(digit) : decimalValue(digit) else { return nil }
            value = value * radix + digitValue
        }
        return value
    }

    private static func hexValue(_ scalar: Unicode.Scalar) -> UInt32? {
        switch scalar {
        case "0"..."9": scalar.value - 0x30
        case "a"..."f": scalar.value - 0x61 + 10
        case "A"..."F": scalar.value - 0x41 + 10
        default: nil
        }
    }

    private static func decimalValue(_ scalar: Unicode.Scalar) -> UInt32? {
        ("0"..."9").contains(scalar) ? scalar.value - 0x30 : nil
    }
}

extension RedactionPolicy {
    /// Whether the value under this key is hidden: the key is not plain, or it is a secret name.
    func hidesValue(of key: FoldedKey) -> Bool {
        !key.isPlain || isSecret(key)
    }

    /// Whether a plain key matches a secret name (see ``SecretNameMatcher``).
    func isSecret(_ key: FoldedKey) -> Bool {
        key.isPlain && secretNameMatcher.matches(key)
    }

}

/// Matches folded keys against secret names, on bytes. A name of five or more letters matches
/// anywhere in a key; a shorter one (`key`, `pin`, `sid`) would match too many ordinary words
/// (`keyboard`, `spinner`, `inside`) that way, so it matches as one of the key's words, as all
/// of it, or at its end.
struct SecretNameMatcher: Sendable, Hashable {
    static let containedNameLength = 5

    private let containedNames: [[UInt8]]
    private let shortNames: [[UInt8]]
    private let allNames: [[UInt8]]

    init(names: Set<String>) {
        allNames = names.sorted().map { Array($0.utf8) }
        containedNames = allNames.filter { $0.count >= Self.containedNameLength }
        shortNames = allNames.filter { $0.count < Self.containedNameLength }
    }

    func matches(_ key: FoldedKey) -> Bool {
        let bytes = key.foldedBytes
        for name in containedNames where name.count <= bytes.count && Self.contains(name, in: bytes) {
            return true
        }
        for name in shortNames where name.count <= bytes.count && bytes.suffix(name.count).elementsEqual(name) {
            return true
        }
        return key.words.contains(where: shortNames.contains)
    }

    /// Whether the word (lowercase ASCII) is one of the names.
    func isName(_ word: [UInt8]) -> Bool {
        allNames.contains(word)
    }

    private static func contains(_ name: [UInt8], in bytes: [UInt8]) -> Bool {
        var start = 0
        while start + name.count <= bytes.count {
            if bytes[start] == name[0], bytes[start..<(start + name.count)].elementsEqual(name) { return true }
            start += 1
        }
        return false
    }
}
