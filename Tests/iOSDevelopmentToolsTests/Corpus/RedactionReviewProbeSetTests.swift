import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The probes of every adversarial review of the shared redaction rules — the third, fifth,
/// seventh, ninth, tenth, twelfth and thirteenth of iOSSecurityTools, the correctness repros of
/// the twelfth and thirteenth, and the twentieth and twenty-second sets of this package's
/// sixteenth review (`a-16n20`, `a-16n22`: a letter, mark or number with no ASCII form in place of
/// one letter of a name, in every shape) and the wildcard probes of its eighteenth (`a-18n25`: a
/// decimal digit of another script and the other wildcards in place of a letter or put into a
/// name, on every path, and two long texts) — as `Resources/ReviewProbes.jsonl` holds them, run
/// against this package's rules. Each probe the documentation says is hidden is hidden, apart from the
/// limitations that "What it does not find" names.
@Suite("Redaction corpus: review probe sets")
struct RedactionReviewProbeSetTests {
    static let reviews = ["a-3", "a-5", "a-7", "a-9", "a-10", "a-12", "a-13", "c-12", "c-13", "a-16n20", "a-16n22", "a-18n25"]

    /// The probes that show their secret, by review and number, with the limitation each one is.
    static let documentedLimitations: [String: String] = {
        var limitations: [String: String] = [:]
        // #43 is a URL path: a segment that is not plain ASCII is a label, so the one after it is hidden.
        let twoLookAlikeLetters = Array(1...14) + Array(23...25) + Array(27...29) + Array(37...42) + [336]
        let byReason: [(String, [String])] = [
            ("a value written before its name", ["a-3#311"]),
            ("the value of an allowed query parameter, also repeated or in another case", ["a-3#379", "a-3#381"]),
            ("a card number glued to an ASCII letter", ["a-5#367"]),
            ("the value of `status`, which is allowed by default", ["a-7#496"]),
            ("a name with two or more letters that have no ASCII form, without a separator", twoLookAlikeLetters.map { "a-10#\($0)" }),
        ]
        for (reason, names) in byReason {
            for name in names { limitations[name] = reason }
        }
        return limitations
    }()

    @Test("the resource holds every probe of the reviews")
    func counts() {
        let counts = Dictionary(grouping: ReviewProbes.all, by: \.review).mapValues(\.count)
        #expect(counts == [
            "a-3": 453, "a-5": 452, "a-7": 560, "a-9": 353, "a-10": 475, "a-12": 613, "a-13": 579, "c-12": 66, "c-13": 245,
            "a-16n20": 240, "a-16n22": 766, "a-18n25": 275,
        ])
        #expect(Self.documentedLimitations.count == 32)
        #expect(Self.large.count == 51)
    }

    /// The probes of up to a few megabytes, each a test case of its own so that they run side by side.
    static let large = ReviewProbes.all.filter { $0.isLarge && $0.claim == "C" }.map(\.name)

    @Test("no probe the documentation says is hidden shows its secret", arguments: reviews)
    func probesHideTheirSecrets(review: String) {
        for probe in ReviewProbes.of(review) where !probe.isLarge {
            expectHidden(probe)
        }
    }

    @Test("no large probe the documentation says is hidden shows its secret", arguments: large)
    func largeProbesHideTheirSecrets(name: String) throws {
        expectHidden(try #require(ReviewProbes.all.first { $0.name == name }))
    }

    private func expectHidden(_ probe: ReviewProbe) {
        guard probe.claim == "C", Self.documentedLimitations[probe.name] == nil else { return }
        let output = probe.redacted()
        #expect(probe.leakedPiece(in: output) == nil, "\(probe.name) \(probe.category): \(probe.text.prefix(300).debugDescription) -> \(output.prefix(300).debugDescription)")
    }

    // A limitation that no longer shows its secret has been fixed: the list and the
    // documentation are updated with it.
    @Test("every documented limitation is still one")
    func limitationsAreCurrent() {
        let probes = Dictionary(uniqueKeysWithValues: ReviewProbes.all.map { ($0.name, $0) })
        for name in Self.documentedLimitations.keys.sorted() {
            guard let probe = probes[name] else {
                Issue.record("no probe \(name)")
                continue
            }
            #expect(probe.leakedPiece(in: probe.redacted()) != nil, "\(name) is fixed: \(probe.text.debugDescription)")
        }
    }
}
