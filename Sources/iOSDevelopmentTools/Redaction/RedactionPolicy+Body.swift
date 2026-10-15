import Foundation

/// What redaction did to a stored body.
public enum RedactionOutcome: String, Sendable, Hashable, Codable {
    /// Nothing sensitive was found, or the body is not a kind that is checked.
    case unchanged
    /// One or more sensitive values were replaced.
    case redacted
    /// The body looked structured but could not be checked, so it was not stored.
    case withheld
}

extension RedactionPolicy {
    /// Nested JSON deeper than this is withheld instead of walked.
    static let maximumJSONDepth = 64
    /// A multipart body with more parts than this is withheld; the parts are tracked in memory,
    /// and a body of nothing but delimiters would otherwise need millions of them.
    static let maximumMultipartParts = 1_000

    /// The body with sensitive values replaced.
    ///
    /// JSON bodies (by content type, or because they start with `{` or `[`) have the values of
    /// sensitive keys replaced at any depth. Form bodies (`application/x-www-form-urlencoded`) and
    /// multipart bodies (`multipart/form-data`) have the values of sensitive fields replaced. Other
    /// bodies are returned unchanged.
    ///
    /// - Parameters:
    ///   - body: The bytes to check.
    ///   - contentType: The `Content-Type` header value, if any.
    ///   - isComplete: `false` when `body` holds only the first part of a longer body.
    public func redact(body: Data, contentType: String?, isComplete: Bool = true) -> (body: Data, outcome: RedactionOutcome) {
        redact(body: body, contentType: contentType, isComplete: isComplete, nesting: 0)
    }

    private func redact(body: Data, contentType: String?, isComplete: Bool, nesting: Int) -> (body: Data, outcome: RedactionOutcome) {
        guard isEnabled, !body.isEmpty else { return (body, .unchanged) }
        let mediaType = contentType?.lowercased() ?? ""
        let withheld = (Data(), RedactionOutcome.withheld)
        let unchecked = withholdsUncheckedBodies ? withheld : (body, .unchanged)

        if mediaType.contains("multipart/") {
            // A multipart part may itself be multipart; one level of nesting is checked.
            guard isComplete, nesting < 2, let boundary = Self.boundary(in: contentType ?? ""),
                  let result = redact(multipart: body, boundary: boundary, nesting: nesting) else { return unchecked }
            return result
        }
        if mediaType.contains("x-www-form-urlencoded") {
            guard let text = String(data: body, encoding: .utf8) else { return unchecked }
            let redacted = redact(parameters: Substring(text))
            return redacted == text ? (body, .unchanged) : (Data(redacted.utf8), .redacted)
        }
        if mediaType.contains("json") || Self.looksLikeJSON(body) {
            guard isComplete, let result = redact(json: body) else { return unchecked }
            return result
        }
        return (body, .unchanged)
    }

    private static func looksLikeJSON(_ body: Data) -> Bool {
        guard let first = body.first(where: { !($0 == 0x20 || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D) }) else {
            return false
        }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }

    // MARK: JSON

    private func redact(json body: Data) -> (Data, RedactionOutcome)? {
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
        return (jsonValue, false)
    }

    // MARK: Multipart

    /// The `boundary` parameter of a multipart content type, without quotes.
    static func boundary(in contentType: String) -> String? {
        for parameter in contentType.split(separator: ";").dropFirst() {
            let parts = parameter.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "boundary" else { continue }
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            // RFC 2046: 1 to 70 characters.
            return (1...70).contains(value.utf8.count) ? value : nil
        }
        return nil
    }

    /// The multipart body with the content of sensitive fields replaced; `nil` when the body does
    /// not have the structure its content type promises.
    private func redact(multipart body: Data, boundary: String, nesting: Int) -> (Data, RedactionOutcome)? {
        let delimiter = Data("--\(boundary)".utf8)
        let headerEnd = Data("\r\n\r\n".utf8)
        let lineBreak = Data("\r\n".utf8)
        var delimiters: [Range<Data.Index>] = []
        var searchStart = body.startIndex
        while let found = body.range(of: delimiter, in: searchStart..<body.endIndex) {
            // RFC 2046: a delimiter starts a line. "--boundary" inside a line is content; taking it
            // for a delimiter would let a part end early, and a server would still read the parts
            // that follow it.
            guard Self.startsLine(at: found.lowerBound, in: body) else {
                searchStart = body.index(after: found.lowerBound)
                continue
            }
            // The closing delimiter is one more than the parts.
            guard delimiters.count <= Self.maximumMultipartParts else { return nil }
            delimiters.append(found)
            searchStart = found.upperBound
        }
        guard !delimiters.isEmpty else { return nil }
        // Servers ignore the preamble before the first delimiter and the epilogue after the
        // closing one, but both would be stored as they are. Only line breaks are kept there.
        let preamble = body[body.startIndex..<delimiters[0].lowerBound]
        guard preamble.allSatisfy(Self.isLinearWhitespace) else { return nil }

        var output = Data(preamble)
        var changed = false
        var closed = false
        for (position, found) in delimiters.enumerated() {
            output.append(delimiter)
            let partEnd = position + 1 < delimiters.count ? delimiters[position + 1].lowerBound : body.endIndex
            let part = body[found.upperBound..<partEnd]
            if part.starts(with: Data("--".utf8)) {
                let epilogue = body[body.index(found.upperBound, offsetBy: 2)...]
                guard epilogue.allSatisfy(Self.isLinearWhitespace) else { return nil }
                output.append(body[found.upperBound...])
                closed = true
                break
            }
            guard let headersRange = part.range(of: headerEnd) else { return nil }
            let headerText = String(decoding: part[part.startIndex..<headersRange.lowerBound], as: UTF8.self)
            let headers = Self.partHeaders(headerText)
            let name = headers["content-disposition"].flatMap { Self.parameter("name", in: $0) ?? Self.parameter("name*", in: $0) }
            let hasLineBreak = part.count >= 2 && part.suffix(2).elementsEqual(lineBreak)
            let contentEnd = hasLineBreak ? part.index(part.endIndex, offsetBy: -2) : part.endIndex
            let content = Data(part[headersRange.upperBound..<contentEnd])
            output.append(part[part.startIndex..<headersRange.upperBound])
            if let name, isSensitive(name: name) {
                output.append(Data(Self.replacement.utf8))
                changed = true
            } else {
                // A part that is not sensitive by name may still be JSON, a form or multipart.
                let (checked, outcome) = redact(body: content, contentType: headers["content-type"], isComplete: true, nesting: nesting + 1)
                if outcome == .withheld { return nil }
                output.append(checked)
                changed = changed || outcome == .redacted
            }
            if hasLineBreak { output.append(lineBreak) }
        }
        guard closed else { return nil }
        return changed ? (output, .redacted) : (body, .unchanged)
    }

    /// Space, tab, CR or LF.
    private static func isLinearWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0D || byte == 0x0A
    }

    /// Whether `index` is the start of `body` or follows a CRLF.
    private static func startsLine(at index: Data.Index, in body: Data) -> Bool {
        guard index != body.startIndex else { return true }
        guard body.distance(from: body.startIndex, to: index) >= 2 else { return false }
        return body[index - 2] == 0x0D && body[index - 1] == 0x0A
    }

    /// A part's headers by lowercased name. A repeated header keeps its first value.
    static func partHeaders(_ text: String) -> [String: String] {
        var headers: [String: String] = [:]
        for line in text.components(separatedBy: "\r\n") {
            let header = line.split(separator: ":", maxSplits: 1)
            guard header.count == 2 else { continue }
            let name = header[0].trimmingCharacters(in: .whitespaces).lowercased()
            if headers[name] == nil {
                headers[name] = header[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return headers
    }

    /// A parameter of a header value such as `form-data; name="field"; filename="a.txt"`.
    ///
    /// Quoted values may contain `;` and backslash escapes, so `name="a;password"` reads as one
    /// name instead of ending at the semicolon.
    static func parameter(_ wanted: String, in value: String) -> String? {
        var characters = value[...]
        // Skip the disposition type.
        guard let firstSemicolon = characters.firstIndex(of: ";") else { return nil }
        characters = characters[characters.index(after: firstSemicolon)...]
        while !characters.isEmpty {
            characters = characters.drop(while: { $0 == " " || $0 == "\t" || $0 == ";" })
            let key = characters.prefix(while: { $0 != "=" && $0 != ";" })
            characters = characters.dropFirst(key.count)
            var parameterValue = ""
            if characters.first == "=" {
                characters = characters.dropFirst()
                if characters.first == "\"" {
                    characters = characters.dropFirst()
                    var escaped = false
                    while let character = characters.first {
                        characters = characters.dropFirst()
                        if escaped {
                            parameterValue.append(character)
                            escaped = false
                        } else if character == "\\" {
                            escaped = true
                        } else if character == "\"" {
                            break
                        } else {
                            parameterValue.append(character)
                        }
                    }
                    characters = characters.drop(while: { $0 != ";" })
                } else {
                    let raw = characters.prefix(while: { $0 != ";" })
                    parameterValue = raw.trimmingCharacters(in: .whitespaces)
                    characters = characters.dropFirst(raw.count)
                }
            }
            if key.trimmingCharacters(in: .whitespaces).lowercased() == wanted {
                return parameterValue
            }
        }
        return nil
    }
}
