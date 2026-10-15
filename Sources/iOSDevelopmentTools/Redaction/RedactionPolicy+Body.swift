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
    /// JSON bodies (by content type, or because they start with `{` or `[`, whatever their content
    /// type says) have the values of sensitive keys replaced at any depth. Form bodies (`application/x-www-form-urlencoded`) and
    /// multipart bodies (`multipart/form-data`) have the values of sensitive fields replaced. A
    /// body without a content type is checked as a form, because `URLSession` sends it as one.
    /// Other bodies are returned unchanged.
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
        // JSON comes before forms: a JSON body sent with a form content type reads as one field
        // with no "=" and would be stored unchecked, with every key in it.
        if mediaType.contains("json") || Self.looksLikeJSON(body) {
            guard isComplete, let result = redact(json: body) else { return unchecked }
            return result
        }
        if mediaType.contains("x-www-form-urlencoded") {
            guard let text = String(data: body, encoding: .utf8) else { return unchecked }
            let redacted = redact(parameters: Substring(text))
            return redacted == text ? (body, .unchanged) : (Data(redacted.utf8), .redacted)
        }
        if contentType == nil {
            // URLSession sends a body without a Content-Type as application/x-www-form-urlencoded.
            // Bytes that are not UTF-8 cannot hide a field name, so they are decoded leniently.
            let text = String(decoding: body, as: UTF8.self)
            let redacted = redact(parameters: Substring(text))
            return redacted == text ? (body, .unchanged) : (Data(redacted.utf8), .redacted)
        }
        return (body, .unchanged)
    }

    private static func looksLikeJSON(_ body: Data) -> Bool {
        // A UTF-8 byte order mark may come first; JSONSerialization reads past it.
        let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]
        let text = body.starts(with: byteOrderMark) ? body.dropFirst(byteOrderMark.count) : body[...]
        guard let first = text.first(where: { !isLinearWhitespace($0) }) else { return false }
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
            switch Self.linePosition(of: found.lowerBound, in: body) {
            case .insideLine:
                searchStart = body.index(after: found.lowerBound)
                continue
            case .afterBareLineBreak:
                // RFC 2046 lines end in CRLF, but Werkzeug (Flask) and other servers also split
                // on a bare LF and would read a part that starts there, so it cannot be content.
                return nil
            case .lineStart:
                break
            }
            // "--boundaryX" is not a delimiter in RFC 2046, but a server that compares only the
            // prefix would start a part there, so such a line cannot be kept as content either.
            guard Self.endsDelimiter(at: found.upperBound, in: body) else { return nil }
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
            guard let headersRange = part.range(of: headerEnd),
                  !Self.containsBareLineBreak(part[part.startIndex..<headersRange.lowerBound])
            else { return nil }
            let headerText = String(decoding: part[part.startIndex..<headersRange.lowerBound], as: UTF8.self)
            guard !Self.hasFoldedHeaderLine(headerText) else { return nil }
            let headers = Self.partHeaders(headerText)
            // Servers differ in which of several Content-Disposition headers, or of several name
            // parameters, they read, so every one is checked.
            let dispositions = headers["content-disposition"] ?? []
            guard !dispositions.contains(where: Self.hasNameContinuation) else { return nil }
            let names = dispositions.flatMap {
                Self.parameterValues("name", in: $0) + Self.parameterValues("name*", in: $0)
            }
            // Likewise, a part with two content types could be read as either.
            let partTypes = headers["content-type"] ?? []
            guard partTypes.count <= 1 else { return nil }
            let hasLineBreak = part.count >= 2 && part.suffix(2).elementsEqual(lineBreak)
            let contentEnd = hasLineBreak ? part.index(part.endIndex, offsetBy: -2) : part.endIndex
            let content = Data(part[headersRange.upperBound..<contentEnd])
            output.append(part[part.startIndex..<headersRange.upperBound])
            if names.contains(where: isSensitive(name:)) {
                output.append(Data(Self.replacement.utf8))
                changed = true
            } else {
                // A part that is not sensitive by name may still be JSON, a form or multipart.
                // A part without a Content-Type is text/plain (RFC 7578), not a form.
                let partType = partTypes.first ?? "text/plain"
                let (checked, outcome) = redact(body: content, contentType: partType, isComplete: true, nesting: nesting + 1)
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

    /// Whether the bytes after a delimiter are `--`, which closes the body, or optional spaces and
    /// tabs followed by a CRLF, the only two endings RFC 2046 allows.
    private static func endsDelimiter(at index: Data.Index, in body: Data) -> Bool {
        let rest = body[index...]
        if rest.starts(with: Data("--".utf8)) { return true }
        return rest.drop(while: { $0 == 0x20 || $0 == 0x09 }).starts(with: Data("\r\n".utf8))
    }

    private enum LinePosition {
        /// The start of the body, or after a CRLF.
        case lineStart
        /// After a CR or LF that is not part of a CRLF.
        case afterBareLineBreak
        case insideLine
    }

    private static func linePosition(of index: Data.Index, in body: Data) -> LinePosition {
        guard index != body.startIndex else { return .lineStart }
        let previous = body[body.index(before: index)]
        if previous == lineFeed, body.distance(from: body.startIndex, to: index) >= 2,
           body[body.index(index, offsetBy: -2)] == carriageReturn {
            return .lineStart
        }
        return previous == lineFeed || previous == carriageReturn ? .afterBareLineBreak : .insideLine
    }

    /// Whether `bytes` hold a CR or LF that is not part of a CRLF. Servers that split part
    /// headers on a bare LF could end the headers, and start the content, earlier than the
    /// first blank CRLF line.
    private static func containsBareLineBreak(_ bytes: Data.SubSequence) -> Bool {
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            let next = bytes.index(after: index)
            if byte == carriageReturn {
                guard next < bytes.endIndex, bytes[next] == lineFeed else { return true }
                index = bytes.index(after: next)
                continue
            }
            if byte == lineFeed { return true }
            index = next
        }
        return false
    }

    private static let carriageReturn: UInt8 = 0x0D
    private static let lineFeed: UInt8 = 0x0A

    /// Whether a header line of a part starts with a space or tab. Such a line continues the one
    /// before it (obsolete line folding, RFC 5322); Werkzeug (Flask) joins the two, so a name on
    /// the folded line would be read by the server but missed here. The text starts with the rest
    /// of the delimiter line, where spaces and tabs are transport padding, so that line is skipped.
    private static func hasFoldedHeaderLine(_ headerText: String) -> Bool {
        headerText.components(separatedBy: "\r\n").dropFirst().contains { $0.hasPrefix(" ") || $0.hasPrefix("\t") }
    }

    /// A part's headers by lowercased name, with every value of a repeated header in order.
    static func partHeaders(_ text: String) -> [String: [String]] {
        var headers: [String: [String]] = [:]
        for line in text.components(separatedBy: "\r\n") {
            let header = line.split(separator: ":", maxSplits: 1)
            guard header.count == 2 else { continue }
            let name = header[0].trimmingCharacters(in: .whitespaces).lowercased()
            headers[name, default: []].append(header[1].trimmingCharacters(in: .whitespaces))
        }
        return headers
    }

    /// The values of a parameter of a header value such as `form-data; name="field"; filename="a.txt"`,
    /// in order; a parameter may appear more than once, as in `name="a"; name="password"`.
    static func parameterValues(_ wanted: String, in value: String) -> [String] {
        parameters(in: value).filter { $0.name == wanted }.map(\.value)
    }

    /// Whether a header value splits its `name` over RFC 2231 continuations (`name*0`, `name*1`, ...).
    /// Werkzeug (Flask) joins the pieces, so `name*0="pass"; name*1="word"` reads as `password`,
    /// and a name spread over pieces cannot be checked piece by piece.
    static func hasNameContinuation(_ value: String) -> Bool {
        parameters(in: value).contains { $0.name.hasPrefix("name*") && $0.name != "name*" }
    }

    /// The parameters of a header value after its first `;`, in order, with lowercased names.
    ///
    /// Quoted values may contain `;` and backslash escapes, so `name="a;password"` reads as one
    /// name instead of ending at the semicolon.
    private static func parameters(in value: String) -> [(name: String, value: String)] {
        var parameters: [(name: String, value: String)] = []
        var characters = value[...]
        // Skip the disposition type.
        guard let firstSemicolon = characters.firstIndex(of: ";") else { return [] }
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
            parameters.append((key.trimmingCharacters(in: .whitespaces).lowercased(), parameterValue))
        }
        return parameters
    }
}
