import Foundation

/// Redaction of JSON on the tree `JSONSerialization` parses. The result is always serialized
/// again from that tree, so nothing of the original text that the parse did not keep (such as
/// the other value of a key that appears twice) is stored.
extension RedactionPolicy {
    /// JSON nested deeper than this is not walked: a body is omitted, an embedded value hidden.
    static let maximumJSONDepth = 64

    /// The JSON body with secrets hidden and whether anything was hidden; `nil` when it does not
    /// parse or is nested too deeply. UTF-16 and UTF-32 bodies are read as `JSONSerialization`
    /// reads them; the result is UTF-8.
    func redact(jsonBody body: Data) -> (Data, Bool)? {
        guard let object = try? JSONSerialization.jsonObject(with: body, options: [.fragmentsAllowed]),
              let redacted = redact(jsonValue: object, depth: 0),
              let data = Self.serializedJSON(redacted)
        else { return nil }
        return (data, !(redacted as AnyObject).isEqual(object))
    }

    /// The value with secrets hidden; `nil` when it is nested deeper than ``maximumJSONDepth``.
    ///
    /// The value of a key that is a secret name or not plain ASCII is hidden whole, whatever its
    /// type. Other strings go through ``redact(value:depth:)``, and integers that are card numbers
    /// are hidden. Every key that is kept goes through ``redact(text:)``.
    func redact(jsonValue: Any, depth: Int) -> Any? {
        guard depth <= Self.maximumJSONDepth else { return nil }
        switch jsonValue {
        case let object as [String: Any]:
            var result: [String: Any] = [:]
            for (key, value) in object {
                let shownKey = redact(text: key)
                if hidesValue(of: FoldedKey(key)) {
                    result[shownKey] = Self.replacement
                    continue
                }
                guard let child = redact(jsonValue: value, depth: depth + 1) else { return nil }
                // Two keys can show as the same text once redacted; the hidden value wins.
                if result[shownKey] as? String != Self.replacement { result[shownKey] = child }
            }
            return result
        case let array as [Any]:
            var result: [Any] = []
            result.reserveCapacity(array.count)
            for element in array {
                guard let child = redact(jsonValue: element, depth: depth + 1) else { return nil }
                result.append(child)
            }
            return result
        case let string as String:
            return redact(value: string, depth: depth)
        case let number as NSNumber:
            return Self.isCardNumber(number) ? Self.replacement : number
        default:
            return jsonValue
        }
    }

    /// A value of a key that is not hidden: JSON inside it (as GraphQL clients send `variables`)
    /// is parsed, redacted and serialized again, anything else goes through ``redact(text:)``.
    /// Embedded JSON that is nested too deeply is hidden whole.
    func redact(value: String, depth: Int) -> String {
        guard Self.startsLikeJSON(value),
              let object = try? JSONSerialization.jsonObject(with: Data(value.utf8)),
              object is [Any] || object is [String: Any]
        else { return redact(text: value) }
        // Serialized even when nothing was hidden: the original text may repeat a key whose
        // other value the parse did not keep.
        guard let redacted = redact(jsonValue: object, depth: depth + 1), let data = Self.serializedJSON(redacted) else {
            return Self.replacement
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// Whether the first scalar that is not white space is `{` or `[`.
    static func startsLikeJSON(_ text: String) -> Bool {
        let first = text.unicodeScalars.first { !$0.properties.isWhitespace }
        return first == "{" || first == "["
    }

    /// The value as compact UTF-8 JSON with sorted keys. It is written inside an array, which
    /// `JSONSerialization` accepts at the top level on every version, and the brackets are removed.
    static func serializedJSON(_ value: Any) -> Data? {
        let wrapped: [Any] = [value]
        guard JSONSerialization.isValidJSONObject(wrapped),
              let data = try? JSONSerialization.data(withJSONObject: wrapped, options: [.sortedKeys, .withoutEscapingSlashes]),
              data.count >= 2
        else { return nil }
        return Data(data.dropFirst().dropLast())
    }

    /// Whether the number is an integer of 13 to 19 digits that passes the Luhn check.
    private static func isCardNumber(_ number: NSNumber) -> Bool {
        guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
        let digits = number.stringValue.unicodeScalars
        guard ValueDetectors.Checksums.cardDigits.contains(digits.count), digits.allSatisfy(ValueDetectors.isDigit) else { return false }
        return ValueDetectors.Checksums.passesLuhn(digits.map { Int($0.value - 0x30) })
    }
}
