import Foundation

extension NetworkEntry {
    /// The request as a `curl` command for a POSIX shell, built from the stored (redacted) values.
    ///
    /// Every argument is quoted, so header values and bodies cannot break out of the command.
    /// The command uses `--globoff` because a redacted URL contains `[` and `]`, which curl would
    /// otherwise read as a range. A body that was omitted, cut off or is not text is left out,
    /// with a comment line above the command that says why, because sending part of a body or a
    /// placeholder would not repeat the request.
    public func curlCommand() -> String {
        var notes: [String] = []
        var arguments = ["curl", "--globoff"]
        if method != "GET" {
            arguments += ["-X", Self.shellQuoted(method)]
        }
        arguments.append(Self.shellQuoted(url))
        for header in requestHeaders where header.name.caseInsensitiveCompare("Content-Length") != .orderedSame {
            // curl sends a header with an empty value only when it is written as "Name;".
            let argument = header.value.isEmpty ? "\(header.name);" : "\(header.name): \(header.value)"
            arguments += ["-H", Self.shellQuoted(argument)]
        }
        if let body = requestBody {
            switch Self.curlBody(body) {
            case .success(let text): arguments += ["--data-binary", Self.shellQuoted(text)]
            case .failure(let note): notes.append(note.message)
            }
        }
        let comments = notes.map { "# \($0)\n" }.joined()
        return comments + arguments.joined(separator: " ")
    }

    private struct BodyNote: Error {
        let message: String
    }

    private static func curlBody(_ body: CapturedBody) -> Result<String, BodyNote> {
        if body.redaction == .omitted {
            return .failure(BodyNote(message: "Request body left out: omitted by redaction (\(body.byteCount) bytes)."))
        }
        if body.isTruncated {
            return .failure(BodyNote(message: "Request body left out: only \(body.data.count) of \(body.byteCount) bytes were stored."))
        }
        // A NUL byte cannot be passed in a shell argument.
        guard let text = body.text, !text.contains("\u{0}") else {
            return .failure(BodyNote(message: "Request body left out: \(body.byteCount) bytes of binary data."))
        }
        return .success(text)
    }

    /// The text in single quotes, with each `'` written as `'\''`.
    ///
    /// Quotes are found as Unicode scalars. `replacingOccurrences(of:with:)` compares Characters
    /// and skips a `'` that a combining mark after it joins into one Character, but the shell
    /// still reads that `'` as the end of the quoted text.
    static func shellQuoted(_ text: String) -> String {
        var quoted = String.UnicodeScalarView()
        quoted.append("'")
        for scalar in text.unicodeScalars {
            if scalar == "'" {
                quoted.append(contentsOf: #"'\''"#.unicodeScalars)
            } else {
                quoted.append(scalar)
            }
        }
        quoted.append("'")
        return String(quoted)
    }
}
