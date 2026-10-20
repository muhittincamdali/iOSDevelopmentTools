import Foundation

/// Generates disguised spellings of secret names and generated secrets for the property tests,
/// from a fixed seed, so a failure can be repeated.
struct Obfuscator {
    /// How many obfuscations of each name are checked.
    static let rounds = 100

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// A seed that depends only on the text, unlike `hashValue`, which changes between runs.
    static func seed(for text: String) -> UInt64 {
        text.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
    }

    // MARK: Random numbers (SplitMix64)

    private mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    private mutating func number(below bound: Int) -> Int {
        Int(next() % UInt64(bound))
    }

    private mutating func element<T>(of array: [T]) -> T {
        array[number(below: array.count)]
    }

    private mutating func chance(_ percent: Int) -> Bool {
        number(below: 100) < percent
    }

    // MARK: Obfuscated names

    /// One to three disguises applied to the name, and whether the result can be written as a
    /// `key=value` in free text (it holds no white space).
    mutating func obfuscate(_ name: String) -> (key: String, isFreeTextSafe: Bool) {
        var scalars = Array(name.lowercased().unicodeScalars)
        var disguises = [
            Self.mixCase, Self.changeSeparators, Self.confusable, Self.formCharacter, Self.combiningMark,
            Self.escape, Self.compatibilityForm,
        ]
        // A name of five letters or more matches inside a longer key; a shorter one with a word
        // added is another word (`pin` and `pinvalue`), so only long names get an affix.
        if scalars.filter({ !Self.separators.contains($0) }).count >= 5 { disguises.append(Self.affix) }
        for _ in 0..<(1 + number(below: 3)) {
            let disguise = element(of: disguises)
            scalars = disguise(&self, scalars)
        }
        let key = String(String.UnicodeScalarView(scalars))
        return (key, !scalars.contains(where: \.properties.isWhitespace))
    }

    private static func letterIndices(_ scalars: [Unicode.Scalar]) -> [Int] {
        scalars.indices.filter { ("a"..."z").contains(scalars[$0]) }
    }

    /// Random upper and lower case for each ASCII letter.
    private static func mixCase(_ generator: inout Obfuscator, _ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        scalars.map { scalar in
            guard ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar), generator.chance(50) else { return scalar }
            let flipped = ("a"..."z").contains(scalar) ? scalar.value - 0x20 : scalar.value + 0x20
            return Unicode.Scalar(flipped) ?? scalar
        }
    }

    private static let separators: [Unicode.Scalar] = ["_", "-", ".", " "]

    /// The name's own separators replaced, and a separator put between two letters.
    private static func changeSeparators(_ generator: inout Obfuscator, _ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var result = scalars.map { separators.contains($0) ? generator.element(of: separators) : $0 }
        guard result.count > 1 else { return result }
        let separator = generator.element(of: separators)
        result.insert(separator, at: 1 + generator.number(below: result.count - 1))
        return result
    }

    /// One letter replaced by a Cyrillic, Greek, mathematical or circled look-alike.
    private static func confusable(_ generator: inout Obfuscator, _ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let indices = letterIndices(scalars)
        guard !indices.isEmpty else { return scalars }
        let index = generator.element(of: indices)
        let letter = scalars[index]
        let offset = letter.value - 0x61
        var choices: [UInt32] = [0x1D41A + offset, 0x24D0 + offset, 0x1D5BA + offset]
        if let cyrillic = cyrillicLookAlikes[letter] { choices.append(cyrillic) }
        if let greek = greekLookAlikes[letter] { choices.append(greek) }
        var result = scalars
        result[index] = Unicode.Scalar(generator.element(of: choices)) ?? letter
        return result
    }

    private static let cyrillicLookAlikes: [Unicode.Scalar: UInt32] = [
        "a": 0x0430, "c": 0x0441, "e": 0x0435, "i": 0x0456, "j": 0x0458, "o": 0x043E, "p": 0x0440,
        "s": 0x0455, "x": 0x0445, "y": 0x0443,
    ]

    private static let greekLookAlikes: [Unicode.Scalar: UInt32] = [
        "a": 0x03B1, "e": 0x03B5, "i": 0x03B9, "k": 0x03BA, "n": 0x03B7, "o": 0x03BF, "p": 0x03C1,
        "t": 0x03C4, "u": 0x03C5, "v": 0x03BD, "x": 0x03C7,
    ]

    /// A zero-width or other format character (Unicode Cf) inserted.
    private static func formCharacter(_ generator: inout Obfuscator, _ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let characters: [Unicode.Scalar] = ["\u{200D}", "\u{200C}", "\u{00AD}", "\u{200B}", "\u{2060}", "\u{FEFF}", "\u{200E}", "\u{180E}"]
        var result = scalars
        result.insert(generator.element(of: characters), at: generator.number(below: result.count + 1))
        return result
    }

    /// A combining mark inserted after a letter.
    private static func combiningMark(_ generator: inout Obfuscator, _ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let marks: [Unicode.Scalar] = ["\u{0301}", "\u{0308}", "\u{0327}", "\u{034F}", "\u{20DD}"]
        var result = scalars
        result.insert(generator.element(of: marks), at: generator.number(below: result.count) + 1)
        return result
    }

    /// One ASCII letter written as `%XX`, `%25XX`, `\uXXXX`, `&#NN;` or `&#xHH;`.
    private static func escape(_ generator: inout Obfuscator, _ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let indices = scalars.indices.filter { ("a"..."z").contains(scalars[$0]) || ("A"..."Z").contains(scalars[$0]) }
        guard !indices.isEmpty else { return scalars }
        let index = generator.element(of: indices)
        let value = scalars[index].value
        let hex = String(value, radix: 16, uppercase: generator.chance(50))
        let escaped = generator.element(of: ["%\(hex)", "%25\(hex)", "\\u00\(hex)", "&#\(value);", "&#x\(hex);"])
        var result = scalars
        result.replaceSubrange(index...index, with: escaped.unicodeScalars)
        return result
    }

    /// The whole name in full-width letters, which NFKC maps back to ASCII.
    private static func compatibilityForm(_ generator: inout Obfuscator, _ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        scalars.map { scalar in
            guard ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) || scalar == "_" else { return scalar }
            return Unicode.Scalar(scalar.value - 0x20 + 0xFF00) ?? scalar
        }
    }

    /// A word before or after the name.
    private static func affix(_ generator: inout Obfuscator, _ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let prefixes = ["x_", "user-", "new.", "X", "my_"]
        let suffixes = ["_value", "-id", ".x", "_2"]
        if generator.chance(50) {
            return Array(generator.element(of: prefixes).unicodeScalars) + scalars
        }
        return scalars + Array(generator.element(of: suffixes).unicodeScalars)
    }

    // MARK: Random keys

    /// A random key of one of several shapes: lowercase letters, camel case, words joined by `_`,
    /// `-` or `.`, letters with digits, or a key with letters outside ASCII, a format character
    /// or an escape. It holds no white space, quote, backslash, `=` or `:`.
    mutating func randomKey() -> String {
        let letters = Array("abcdefghijklmnopqrstuvwxyz".unicodeScalars)
        var word = characters(1 + number(below: 10), from: letters)
        switch number(below: 7) {
        case 0: break
        case 1: word += element(of: ["Id", "Name", "Value", "Ref", "X"]) + characters(1 + number(below: 4), from: letters)
        case 2: word += element(of: ["_", "-", "."]) + characters(1 + number(below: 6), from: letters)
        case 3: word += String(number(below: 1_000))
        case 4: word += element(of: ["é", "ş", "ı", "\u{0430}", "\u{03BF}", "名", "ü"])
        case 5: word.insert(contentsOf: element(of: ["\u{200D}", "\u{00AD}", "\u{0301}"]), at: word.index(after: word.startIndex))
        default: word = element(of: ["%61", "&#98;", "\u{FF43}"]) + word
        }
        return word
    }

    /// A random value that free text keeps under a plain key and that holds nothing the detectors
    /// or the secret words find: digits, a short word or a path.
    mutating func harmlessValue() -> String {
        switch number(below: 3) {
        case 0: String(number(below: 100_000))
        case 1: element(of: ["GET", "POST", "ok", "done", "warning", "items", "2xx"])
        default: "/v1/" + element(of: ["items", "orders", "users"]) + "/" + String(number(below: 1_000))
        }
    }

    // MARK: Secrets

    private static let alphanumerics = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".unicodeScalars)

    private mutating func characters(_ count: Int, from alphabet: [Unicode.Scalar]) -> String {
        String(String.UnicodeScalarView((0..<count).map { _ in element(of: alphabet) }))
    }

    /// A random secret value that appears nowhere else in what is stored.
    mutating func secret() -> String {
        "Zq9" + characters(6 + number(below: 14), from: Self.alphanumerics)
    }

    /// A random value of a kind the value detectors find: a JWT, a long hex or Base64 string, a
    /// card number, an IBAN or an email address.
    mutating func detectableSecret() -> String {
        switch number(below: 6) {
        case 0:
            let base64URL = Self.alphanumerics + ["-", "_"]
            return "eyJ" + characters(10 + number(below: 30), from: base64URL) + ".eyJ"
                + characters(10 + number(below: 60), from: base64URL) + "." + characters(20 + number(below: 40), from: base64URL)
        case 1:
            return characters(32 + number(below: 33), from: Array("0123456789abcdef".unicodeScalars))
        case 2:
            let body = characters(30 + number(below: 40), from: Self.alphanumerics + ["+"])
            return "k7" + body + (chance(50) ? "=" : "")
        case 3:
            return cardNumber()
        case 4:
            return iban()
        default:
            let local = characters(4 + number(below: 8), from: Array("abcdefghijklmnopqrstuvwxyz0123456789".unicodeScalars))
            return local + "@" + characters(3 + number(below: 8), from: Array("abcdefghijklmnopqrstuvwxyz".unicodeScalars)) + ".com"
        }
    }

    /// Sixteen digits that start with 4 and pass the Luhn check.
    private mutating func cardNumber() -> String {
        var digits = [4] + (0..<14).map { _ in number(below: 10) }
        for check in 0...9 where ValueDetectorsLuhn.passes(digits + [check]) {
            digits.append(check)
            break
        }
        return digits.map(String.init).joined()
    }

    /// A German IBAN with random account digits and correct check digits.
    private mutating func iban() -> String {
        let account = (0..<18).map { _ in String(number(below: 10)) }.joined()
        // D = 13, E = 14; the check digits are 98 minus the remainder of account + "DE00".
        let remainder = (account + "131400").reduce(0) { ($0 * 10 + Int(String($1))!) % 97 }
        return "DE" + String(format: "%02d", 98 - remainder) + account
    }
}

/// Percent-encodes everything but ASCII letters and digits; `CharacterSet.alphanumerics` would
/// also keep letters outside ASCII.
func percentEncodedASCII(_ text: String) -> String {
    text.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"))!
}

/// The Luhn check, written here again so the generator does not depend on the code under test.
enum ValueDetectorsLuhn {
    static func passes(_ digits: [Int]) -> Bool {
        var sum = 0
        for (position, digit) in digits.reversed().enumerated() {
            let doubled = position % 2 == 1 ? digit * 2 : digit
            sum += doubled > 9 ? doubled - 9 : doubled
        }
        return sum % 10 == 0
    }
}
