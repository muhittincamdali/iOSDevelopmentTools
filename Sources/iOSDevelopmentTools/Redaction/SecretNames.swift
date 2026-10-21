/// The words that make a key secret, and where in a key each has to sit.
///
/// The words are lowercase ASCII letters and digits without separators. ``PlainName`` compares a
/// plain-ASCII key with them; any other key is hidden without being compared. Words of free text
/// are compared with them by their ASCII skeleton (see ``LooseReading``), which only ever hides
/// more.
///
/// A table is built once per ``RedactionPolicy`` and shared by every redaction it makes; the
/// default policy's table is built once for the whole process.
struct SecretNameTable: Sendable, Hashable {
    /// Where a secret word has to sit in a key for the key to hold the secret.
    enum Placement: Sendable {
        /// Anywhere, also inside a longer word: `dbpassword`, `userapikey`.
        case anywhere
        /// As a word of the key (`user_pin`, `X-Auth-Key`) or at the end of the key (`apitoken`,
        /// `licensekey`).
        case wordOrEnd
        /// As a word of the key only: `DB_PASS` but not `bypass` or `passport`.
        case word
    }

    struct Entry: Sendable {
        let letters: [UInt8]
        let placement: Placement
    }

    /// The shared list of the redaction spec (password, passwd, pwd, secret, token, access_token,
    /// refresh_token, id_token, api_key, apikey, key, auth, authorization, cookie, set-cookie,
    /// session, sid, otp, pin, cvv, card, iban, ssn, private_key, client_secret, signature), and
    /// this library's extensions, folded.
    static let defaultEntries: [Entry] = {
        // `session` counts anywhere, as in the header rule: `session_data` and `XSession2` hold
        // a session as often as `laravel_session` does.
        let anywhere = [
            "authorization", "clientsecret", "refreshtoken", "accesstoken", "accesskey", "authkey", "privatekey",
            "secretkey", "session", "sessid", "passphrase", "password", "passcode", "passwd", "idtoken",
            "apikey", "credential", "signature", "cookie", "pincode", "otpcode", "securitycode", "verificationcode",
            "authcode", "cardnumber",
        ]
        let wordOrEnd = ["token", "secret", "pwd", "key", "pin", "otp", "cvv", "cvc", "ssn", "iban", "card", "auth", "bearer"]
        return anywhere.map { Entry(letters: Array($0.utf8), placement: .anywhere) }
            + wordOrEnd.map { Entry(letters: Array($0.utf8), placement: .wordOrEnd) }
            + ["pass", "sid", "pw"].map { Entry(letters: Array($0.utf8), placement: .word) }
    }()

    /// The folded default words.
    static let defaultWords: [String] = defaultEntries.map { String(decoding: $0.letters, as: UTF8.self) }

    /// The table of a policy without added names, built once.
    static let standard = SecretNameTable(words: Set(defaultWords))

    /// Added words at least this long count anywhere in a key; shorter ones as a word or at the end.
    static let anywhereLength = 5

    /// The folded words: the default ones and the ones a policy added.
    let words: Set<String>
    private let byFirstLetter: [[Entry]]
    private let bySecondLetter: [[Entry]]

    /// A table of the default words and the other folded `words`, which must be plain lowercase
    /// ASCII letters and digits. An added word keeps the placement of a default word it equals.
    init(words: Set<String>) {
        let defaults = Set(Self.defaultWords)
        let added = words.subtracting(defaults).sorted().map { word in
            Entry(letters: Array(word.utf8), placement: word.utf8.count >= Self.anywhereLength ? .anywhere : .wordOrEnd)
        }
        let entries = Self.defaultEntries + added
        self.words = defaults.union(words)
        byFirstLetter = Self.table(entries) { $0.letters.first }
        bySecondLetter = Self.table(entries) { $0.letters.count > 1 ? $0.letters[1] : nil }
    }

    static func == (lhs: SecretNameTable, rhs: SecretNameTable) -> Bool { lhs.words == rhs.words }

    func hash(into hasher: inout Hasher) { hasher.combine(words) }

    /// Letters `a`–`z` and digits `0`–`9` each have a bucket.
    private static let bucketCount = 36

    private static func bucket(_ byte: UInt8) -> Int? {
        if ASCII.isLetter(byte) { return Int(ASCII.lowercased(byte) - UInt8(ascii: "a")) }
        if ASCII.isDigit(byte) { return 26 + Int(byte - UInt8(ascii: "0")) }
        return nil
    }

    private static func table(_ entries: [Entry], _ letter: (Entry) -> UInt8?) -> [[Entry]] {
        var table = [[Entry]](repeating: [], count: bucketCount)
        for entry in entries {
            guard let byte = letter(entry), let bucket = bucket(byte) else { continue }
            table[bucket].append(entry)
        }
        return table
    }

    /// The entries that start with the lowercase `letter`.
    func entries(startingWith letter: UInt8) -> [Entry] {
        Self.bucket(letter).map { byFirstLetter[$0] } ?? []
    }

    /// The entries whose second letter is the lowercase `letter`: the ones a name can spell from
    /// that letter when its first letter is missing where a word of free text left characters out
    /// (see ``PlainName/firstSecret(in:where:)``).
    func entries(withSecondLetter letter: UInt8) -> [Entry] {
        Self.bucket(letter).map { bySecondLetter[$0] } ?? []
    }
}
