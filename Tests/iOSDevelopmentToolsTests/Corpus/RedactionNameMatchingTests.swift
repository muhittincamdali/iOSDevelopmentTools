import Foundation
import Testing
@testable import iOSDevelopmentTools

/// How a word of free text is matched with the secret words, in readings of one pass per secret
/// word: with at most one letter or number that has no ASCII form (a wildcard) standing for a
/// letter or, between two letters, for none, as its ASCII skeleton, with every such letter left
/// out, and, when a mark follows an ASCII letter, with that mark as a wildcard too.
@Suite("Redaction corpus: name matching")
struct RedactionNameMatchingTests {
    let redactor = Redactor()

    @Test("one letter without an ASCII form stands for a letter or for none", arguments: [
        "pɑssword hunter2", "passwıord hunter2", "passꞏword hunter2", "ıd_token hunter2", "tokɛns hunter2", "ɑpi_key hunter2",
        "Authorizɑtion hunter2", "user_pın hunter2", "sɛcret hunter2",
        // Before the last letter of a short word, read as no letter (the sixth review of the spec branch).
        "tokeꞏn hunter2", "piın hunter2", "secreꞏt hunter2", "keıy hunter2", "userPiłn hunter2", "my piꞏn is hunter2",
    ])
    func oneWildcard(line: String) {
        #expect(!redactor.redact(line).contains("hunter2"), "\(line)")
    }

    // The eighth review of the spec branch: letters without an ASCII form put into a name are
    // left out of its skeleton, however many there are.
    @Test("letters without an ASCII form put into a name are left out of its skeleton", arguments: [
        "passꞏwoꞏrd hunter2", "pıaıssword hunter2", "passıwoırd hunter2", "seıcreıt hunter2", "tokenꞏꞏ hunter2",
        "tokenıı hunter2", "ꞏtoꞏkeꞏnꞏ hunter2",
    ])
    func skeleton(line: String) {
        #expect(!redactor.redact(line).contains("hunter2"), "\(line)")
    }

    // The logging guide names this limit under "What it does not find": free text without a
    // separator is a best effort, and no list of look-alikes is kept to chase it.
    @Test("a name written without a separator with two or more letters replaced by ones without an ASCII form is not found", arguments: [
        "pɑsswoʀd hunter2", "tɵkɛn hunter2",
    ])
    func twoWildcards(line: String) {
        #expect(redactor.redact(line).contains("hunter2"), "\(line) is found: update the guide")
        let separated = line.replacingOccurrences(of: " hunter2", with: ": hunter2")
        #expect(!redactor.redact(separated).contains("hunter2"), "\(separated)")
    }

    // The one wildcard rule of section 0 of the redaction spec: a mark (M*) or a number (N*) with
    // no ASCII form stands for any letter as a letter does. The sixteenth review found
    // `t\u{0366}ken` and `passw\u{3007}rd` (see RedactionOneWildcardTests).
    @Test("a mark after an ASCII letter or a number without an ASCII form in place of one letter stands for it", arguments: [
        "t\u{0366}ken hunter2", "p\u{0301}ssword hunter2", "passw\u{3007}rd hunter2", "toke\u{0366} hunter2",
    ])
    func markOrNumberInPlaceOfALetter(line: String) {
        #expect(!redactor.redact(line).contains("hunter2"), "\(line)")
        let separated = line.replacingOccurrences(of: " hunter2", with: ": hunter2")
        #expect(!redactor.redact(separated).contains("hunter2"), "\(separated)")
    }

    // A mark of a letter that is a wildcard belongs to it, and marks on every letter are left out.
    @Test("marks on a wildcard or on every letter leave the name found", arguments: [
        "p\u{0251}\u{0301}ssword hunter2", "t\u{0337}o\u{0337}k\u{0337}e\u{0337}n\u{0337} hunter2", "pa\u{FE0F}ssphrase hunter2",
    ])
    func marksOnLetters(line: String) {
        #expect(!redactor.redact(line).contains("hunter2"), "\(line)")
    }

    @Test("words in Turkish and other languages that hold a wildcard stay readable", arguments: [
        "Kullanıcı sisteme başarıyla giriş yaptı", "kapıdaki ılgın ağaçları", "Ayşe ılgın", "bjørn dæhlie kom hjem",
    ])
    func ordinaryWords(line: String) {
        #expect(redactor.redact(line) == line)
    }

    /// The one-pass match finds the same secret words as trying the wildcard at every position,
    /// the way 2.1.0's first change did, on generated words.
    @Test("one pass finds what trying every wildcard position finds", arguments: 0..<8)
    func sameAsEveryPosition(seed: Int) {
        var random = SeededRandom(seed: UInt64(seed) + 71)
        var found = 0
        for _ in 0..<2_000 {
            let (bytes, wildcards) = Self.word(using: &random)
            guard let name = PlainName(looseBytes: bytes, wildcards: wildcards) else { continue }
            let reference = ReferenceMatch(looseBytes: bytes, wildcards: wildcards)
            let split = Int.random(in: 0...max(1, name.letters.count), using: &random)
            let across = { (range: Range<Int>) in range.lowerBound < split && range.upperBound > split }
            let first = name.firstSecret(in: .standard) { _ in true }
            #expect(first == reference.firstSecret { _ in true }, "\(Self.shown(bytes, wildcards))")
            #expect(name.firstSecret(in: .standard, where: across) == reference.firstSecret(where: across), "\(Self.shown(bytes, wildcards)) split \(split)")
            if first != nil { found += 1 }
        }
        // Most generated words hold a secret word, some do not: both kinds are compared.
        #expect(found > 1_000 && found < 2_000)
    }

    /// A word made of a secret word or two, changed: letters made wildcards, uppercase or left
    /// out, wildcards and separators put in, other letters around them.
    private static func word(using random: inout SeededRandom) -> ([UInt8], [Bool]) {
        var bytes: [UInt8] = []
        var wildcards: [Bool] = []
        func append(_ byte: UInt8, wildcard: Bool = false) {
            bytes.append(byte)
            wildcards.append(wildcard)
        }
        let letters = Array("abcdeikmnoprstuwxyz".utf8)
        for _ in 0..<Int.random(in: 1...2, using: &random) {
            for _ in 0..<Int.random(in: 0...2, using: &random) { append(letters.randomElement(using: &random)!) }
            let secret = SecretNameTable.defaultEntries.randomElement(using: &random)!.letters
            for letter in secret {
                switch Int.random(in: 0..<20, using: &random) {
                case 0: append(CompatibilityText.unreadable, wildcard: true)
                case 1: append(letter)
                    append(CompatibilityText.unreadable, wildcard: true)
                case 2: append(ASCII.isLetter(letter) ? letter - 32 : letter)
                case 3: continue
                case 4: append(letter)
                    append(["_", "-", ".", " ", "~"].randomElement(using: &random)!.utf8.first!)
                default: append(letter)
                }
            }
            if Bool.random(using: &random) { append(UInt8(ascii: "s")) }
            if Int.random(in: 0..<4, using: &random) == 0 { append(UInt8(ascii: "_")) }
        }
        return (bytes, wildcards)
    }

    private static func shown(_ bytes: [UInt8], _ wildcards: [Bool]) -> String {
        String(zip(bytes, wildcards).map { $1 ? "?" : Character(Unicode.Scalar($0)) })
    }
}

/// The matching that tried a wildcard as no letter at every position of a secret word in turn,
/// kept here to check the one-pass match against.
private struct ReferenceMatch {
    let letters: [UInt8]
    let startsWord: [Bool]

    init(looseBytes bytes: [UInt8], wildcards: [Bool]) {
        var name = bytes
        for i in name.indices where !ASCII.isNameCharacter(name[i]) {
            name[i] = wildcards[i] ? UInt8(ascii: "x") : UInt8(ascii: "_")
        }
        var letters: [UInt8] = []
        var startsWord: [Bool] = []
        for i in name.indices where ASCII.isAlphanumeric(name[i]) {
            letters.append(wildcards[i] ? PlainName.wildcard : ASCII.lowercased(name[i]))
            startsWord.append(Self.startsWord(i, in: name))
        }
        self.letters = letters
        self.startsWord = startsWord
    }

    func firstSecret(where accepts: (Range<Int>) -> Bool) -> Range<Int>? {
        for start in letters.indices {
            let entries = SecretNameTable.defaultEntries.filter { letters[start] == PlainName.wildcard || $0.letters[0] == letters[start] }
            for entry in entries {
                for end in matchEnds(of: entry.letters, at: start) where holds(entry.placement, start: start, end: end) && accepts(start..<end) {
                    return start..<end
                }
            }
        }
        return nil
    }

    /// Every reading of the word, with a plural `s` after it when one ends it there, then every
    /// reading of its plural, whose `s` the wildcard may stand for or come before (`tokenꞏ`,
    /// `tokenꞏs`).
    private func matchEnds(of word: [UInt8], at start: Int) -> [Int] {
        let singular = readings(of: word, at: start).map { end in
            end < letters.count && letters[end] == UInt8(ascii: "s") && endsPlural(end + 1) ? end + 1 : end
        }
        return singular + readings(of: word + [UInt8(ascii: "s")], at: start).filter(endsPlural)
    }

    /// Whether the letter before `end`, read as a plural `s`, ends the word.
    private func endsPlural(_ end: Int) -> Bool { !startsWord[end - 1] && endsWord(end) }

    /// The wildcard as a letter, then as no letter at each place in turn.
    private func readings(of word: [UInt8], at start: Int) -> [Int] {
        var ends = [spelledEnd(of: word, at: start, skipping: nil)]
        if word.count > 1 {
            for k in (start + 1)..<max(start + 1, min(start + word.count, letters.count)) where letters[k] == PlainName.wildcard {
                ends.append(spelledEnd(of: word, at: start, skipping: k))
            }
        }
        return ends.compactMap { $0 }
    }

    private func spelledEnd(of word: [UInt8], at start: Int, skipping skipped: Int?) -> Int? {
        let end = start + word.count + (skipped == nil ? 0 : 1)
        guard end <= letters.count else { return nil }
        var usedWildcard = skipped != nil
        var k = start
        for expected in word {
            if k == skipped { k += 1 }
            if letters[k] != expected {
                guard letters[k] == PlainName.wildcard, !usedWildcard else { return nil }
                usedWildcard = true
            }
            k += 1
        }
        return end
    }

    private func holds(_ placement: SecretNameTable.Placement, start: Int, end: Int) -> Bool {
        switch placement {
        case .anywhere: true
        case .wordOrEnd: end == letters.count || (startsWord[start] && endsWord(end))
        case .word: startsWord[start] && endsWord(end)
        }
    }

    private func endsWord(_ k: Int) -> Bool { k == letters.count || startsWord[k] }

    private static func startsWord(_ i: Int, in bytes: [UInt8]) -> Bool {
        guard i > 0 else { return true }
        let previous = bytes[i - 1]
        if !ASCII.isAlphanumeric(previous) || ASCII.isDigit(previous) != ASCII.isDigit(bytes[i]) { return true }
        guard ASCII.isUppercase(bytes[i]), ASCII.isLetter(previous) else { return false }
        if !ASCII.isUppercase(previous) { return true }
        return i + 1 < bytes.count && ASCII.isLetter(bytes[i + 1]) && !ASCII.isUppercase(bytes[i + 1])
    }
}
