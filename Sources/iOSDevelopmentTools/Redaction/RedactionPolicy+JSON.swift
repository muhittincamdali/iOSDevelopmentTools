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
    static func wideEncoding(of body: Data) -> String.Encoding? {
        if body.starts(with: [0xFF, 0xFE, 0x00, 0x00]) || body.starts(with: [0x00, 0x00, 0xFE, 0xFF]) { return .utf32 }
        if body.starts(with: [0xFF, 0xFE]) || body.starts(with: [0xFE, 0xFF]) { return .utf16 }
        return nil
    }

    /// What checking a piece of text as JSON found.
    enum JSONCheck {
        /// The text is not JSON.
        case notJSON
        /// The text is JSON but cannot be checked: nested too deeply, an object repeats a key,
        /// or the redacted value cannot be encoded.
        case unreadable
        /// The JSON has no sensitive keys.
        case unchanged
        /// The JSON with sensitive values replaced.
        case redacted(Data)
    }

    func redact(json body: Data) -> (Data, RedactionOutcome)? {
        switch check(json: body, allowingFragments: true, depth: 0) {
        case .notJSON, .unreadable: nil
        case .unchanged: (body, .unchanged)
        case .redacted(let data): (data, .redacted)
        }
    }

    /// Parses `data` as JSON and replaces the values of sensitive keys.
    ///
    /// - Parameters:
    ///   - allowingFragments: Whether a lone string, number or literal counts as JSON; otherwise
    ///     only an object or an array does.
    ///   - depth: How deep `data` sits inside the JSON it was found in.
    func check(json data: Data, allowingFragments: Bool, depth: Int) -> JSONCheck {
        let options: JSONSerialization.ReadingOptions = allowingFragments ? [.fragmentsAllowed] : []
        guard let object = try? JSONSerialization.jsonObject(with: data, options: options) else { return .notJSON }
        guard let (redacted, changed) = redact(jsonValue: object, depth: depth) else { return .unreadable }
        // JSONSerialization keeps one of two equal keys in an object, while Python's json module and
        // JavaScript keep the last, so the value a server reads may be one that was never checked.
        guard Self.hasUniqueKeys(json: data) else { return .unreadable }
        guard changed else { return .unchanged }
        // data(withJSONObject:) raises an Objective-C exception, which Swift cannot catch, for
        // objects it cannot encode (such as an infinite number), so check first.
        guard JSONSerialization.isValidJSONObject(redacted),
              let encoded = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys, .withoutEscapingSlashes])
        else { return .unreadable }
        return .redacted(encoded)
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
        guard Self.looksLikeJSON(data) else { return (string, false) }
        switch check(json: data, allowingFragments: false, depth: depth + 1) {
        case .notJSON, .unchanged: return (string, false)
        case .unreadable: return nil
        case .redacted(let encoded): return (String(decoding: encoded, as: UTF8.self), true)
        }
    }
}
