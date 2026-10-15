import Foundation

/// Redaction of JSON bodies, and of JSON inside them.
extension RedactionPolicy {
    /// Nested JSON deeper than this is withheld instead of walked.
    static let maximumJSONDepth = 64

    static func looksLikeJSON(_ body: Data) -> Bool {
        // JSONSerialization also reads UTF-16 and UTF-32 after their byte order marks, so such a
        // body is decoded before its first character is looked at.
        if let encoding = wideEncoding(of: body) {
            guard let text = String(data: body, encoding: encoding) else { return false }
            let first = text.unicodeScalars.first { $0 != "\u{FEFF}" && !$0.properties.isWhitespace }
            return first == "{" || first == "["
        }
        // A UTF-8 byte order mark may come first; JSONSerialization reads past it.
        let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]
        let text = body.starts(with: byteOrderMark) ? body.dropFirst(byteOrderMark.count) : body[...]
        guard let first = text.first(where: { !isLinearWhitespace($0) }) else { return false }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }

    /// UTF-16 or UTF-32 when the body starts with one of their byte order marks. The UTF-32
    /// little-endian mark starts like the UTF-16 one, so it is tested first.
    private static func wideEncoding(of body: Data) -> String.Encoding? {
        if body.starts(with: [0xFF, 0xFE, 0x00, 0x00]) || body.starts(with: [0x00, 0x00, 0xFE, 0xFF]) { return .utf32 }
        if body.starts(with: [0xFF, 0xFE]) || body.starts(with: [0xFE, 0xFF]) { return .utf16 }
        return nil
    }

    func redact(json body: Data) -> (Data, RedactionOutcome)? {
        guard let object = try? JSONSerialization.jsonObject(with: body, options: [.fragmentsAllowed]) else {
            return nil
        }
        guard let (redacted, changed) = redact(jsonValue: object, depth: 0) else { return nil }
        guard changed else { return (body, .unchanged) }
        // data(withJSONObject:) raises an Objective-C exception, which Swift cannot catch, for
        // objects it cannot encode (such as an infinite number), so check first.
        guard JSONSerialization.isValidJSONObject(redacted),
              let data = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys, .withoutEscapingSlashes])
        else { return nil }
        return (data, .redacted)
    }

    /// The value with sensitive keys replaced, and whether anything changed; `nil` when the
    /// nesting is too deep to check.
    private func redact(jsonValue: Any, depth: Int) -> (Any, Bool)? {
        guard depth <= Self.maximumJSONDepth else { return nil }
        if let dictionary = jsonValue as? [String: Any] {
            var result: [String: Any] = [:]
            var changed = false
            for (key, value) in dictionary {
                if isSensitive(name: key) {
                    result[key] = Self.replacement
                    changed = true
                } else {
                    guard let (child, childChanged) = redact(jsonValue: value, depth: depth + 1) else { return nil }
                    result[key] = child
                    changed = changed || childChanged
                }
            }
            return (result, changed)
        }
        if let array = jsonValue as? [Any] {
            var result: [Any] = []
            result.reserveCapacity(array.count)
            var changed = false
            for element in array {
                guard let (child, childChanged) = redact(jsonValue: element, depth: depth + 1) else { return nil }
                result.append(child)
                changed = changed || childChanged
            }
            return (result, changed)
        }
        if let string = jsonValue as? String {
            return redact(embeddedJSON: string, depth: depth)
        }
        return (jsonValue, false)
    }

    /// A string value that holds JSON itself, as GraphQL clients often send `variables`, with
    /// sensitive keys replaced inside it. Other strings are returned as they are.
    private func redact(embeddedJSON string: String, depth: Int) -> (Any, Bool)? {
        let data = Data(string.utf8)
        guard Self.looksLikeJSON(data),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is [String: Any] || object is [Any]
        else { return (string, false) }
        guard let (redacted, changed) = redact(jsonValue: object, depth: depth + 1) else { return nil }
        guard changed else { return (string, false) }
        guard JSONSerialization.isValidJSONObject(redacted),
              let encoded = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys, .withoutEscapingSlashes])
        else { return nil }
        return (String(decoding: encoded, as: UTF8.self), true)
    }
}
