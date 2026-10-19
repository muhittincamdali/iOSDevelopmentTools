# Redacting sensitive data

Understand what is recorded, what is never recorded, and how to change it.

## Overview

Every request that reaches a ``NetworkLogger`` and every message logged to a ``LogStore`` goes
through a ``RedactionPolicy`` first. The console, ``HTTPArchive`` files,
``NetworkEntry/curlCommand()`` and screenshots of the console only ever see the redacted copy.
Your app still sends and receives everything unchanged.

The policy follows one rule: what it does not fully understand is hidden, never shown. Bodies are
parsed with real parsers, a key that is not plain ASCII is hidden, and a body that cannot be
parsed is left out.

Redaction is a safety net, not a guarantee. It cannot know every name your app or your server
uses for a secret. Keep secrets out of requests you record and out of log messages in the first
place.

### What is recorded and what is never recorded

| Part | Recorded | Never recorded |
| --- | --- | --- |
| URL | Scheme, host, port, path, query parameter names | User info (`user:password@`), the fragment (`#…`), query values (unless allowlisted), path segments that look like identifiers or secrets (shown as `:id`) |
| Headers | Names; values of the allowlisted headers | Values of every other header, and always the values of `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key` and any header whose name contains `token`, `secret`, `key`, `auth`, `session` or `signature` |
| JSON, form and multipart bodies | Keys and values, after redaction | Values of secret keys and of keys that are not plain ASCII; file parts of multipart bodies |
| Other bodies | `text/plain` after the free-text rule; a note for everything else | Bodies with an unknown or missing content type, bodies that do not parse, and bodies that were cut off or are larger than 1 MiB |
| Log messages | The message after the free-text rule | Values after a secret key, and detected secrets |

### How keys are matched

JSON field names, query and form names, multipart field names and header names are folded before
they are compared: percent, `\u` and `&#` escapes are decoded (up to four rounds), then NFKC is
applied, the key is case-folded, and `_`, `-`, `.` and spaces are removed.

Only a key that is then plain ASCII letters and digits is compared with
``RedactionPolicy/secretNames``. Any other key has its value hidden, whatever it says. That covers
look-alike letters from other scripts (`pаssword` with a Cyrillic `а`), zero-width and other
format characters (`pass\u{200D}word`), combining marks, other separators (`user[password]`,
`pass;word`) and keys in any language that is not written in ASCII. There is no look-alike table
to keep up to date.

| Key in the request | Folded | Value |
| --- | --- | --- |
| `X-API-Key` | `xapikey` | hidden (`apikey`) |
| `refresh_token` | `refreshtoken` | hidden (`token`) |
| `pass%2577ord` | `password` | hidden |
| `ｐａｓｓｗｏｒｄ` | `password` | hidden |
| `pаssword` (Cyrillic `а`) | not plain ASCII | hidden |
| `şifre` | not plain ASCII | hidden |
| `created_at` | `createdat` | kept |

A secret name of five or more letters matches anywhere in a folded key (`newPassword`). A shorter
one (`key`, `pin`, `sid`, `otp`) matches when it is one of the key's words or its end
(`api-key`, `userPin`), so `keyboard` and `spinner` keep their values. The default names are in
``RedactionPolicy/defaultSecretNames``; names you add cannot remove them.

### Values

When a key matches, its whole value is hidden: a string, a number, an array or an object. Values
of other keys, header values that are kept and free text are scanned for JWTs, `Bearer`
credentials, hex or Base64 strings of 32 or more characters, card numbers that pass the Luhn
check, IBANs that pass the mod-97 check, and email addresses.

A string value that holds JSON, as GraphQL clients send `variables`, is parsed and redacted too,
and so is JSON in a form value or an allowlisted query value. Other values, such as a form value
that holds `a=1&token=x`, go through the free-text rule below.

### Bodies

- **JSON** (`application/json` and `+json` types) is parsed with `JSONSerialization`, redacted on
  the parsed tree and serialized again, with sorted keys. When an object repeats a key, the parse
  keeps one value and the other is not stored at all.
- **Forms** (`application/x-www-form-urlencoded`) are split on `&` and `=` and decoded with the
  platform API. A field that does not decode makes the whole body unparsed.
- **Multipart** bodies are split on their boundary as strictly as RFC 2046 reads them. File parts
  (with a `filename`) are always replaced by a note, other part headers follow the header rule,
  and each field is parsed by its own content type.
- **`text/plain`** goes through the free-text rule.

Any other content type, a missing content type, a body that does not parse or is nested deeper
than 64 levels, a body that was cut off at ``NetworkLogger/Configuration/maximumBodySize`` and a
body larger than ``RedactionPolicy/maximumCheckedBodySize`` are not stored. A note takes their
place, such as `[body omitted: 512 bytes, application/xml]`, and the body is marked
``RedactionOutcome/omitted``. Malformed multipart (a second boundary parameter, folded or repeated
part headers, a malformed parameter, text outside the boundaries, a line that starts with the
boundary and goes on) is omitted too, because servers read it in different ways.

### Free text

Log messages, error descriptions and kept header values are read line by line. U+2028, U+2029,
U+0085, vertical tab and form feed are folded to line feeds first.

- In `key=value`, `key: value` and `"key":"value"`, the key follows the key rule above. A quoted
  value is hidden up to its closing quote; an unquoted value is hidden with the rest of the line,
  because where it ends is unknown. A key at the end of a line hides the next line with text, and
  a line that starts with `=` or `:` takes the last word of the line before as its key.
- A secret word that no `=` or `:` follows, as in `token abc123`, makes the line ambiguous, so the
  rest of the line is hidden.
- The value detectors run on every line.

### Change the policy

Add your own secret names and allow the query parameters and headers you want to read:

```swift
NetworkLogger.shared.configuration.redaction = RedactionPolicy(
    additionalSecretNames: ["license_number"],
    allowedHeaders: RedactionPolicy.defaultAllowedHeaders + ["X-Request-ID"],
    allowedQueryParameters: ["page", "sort"]
)
```

A secret name stays hidden when it is on an allowlist. Use `urlDetail: .hostOnly` to record only
the scheme, host and port of each URL. The same policy type is used by
``LogStore/Configuration/redaction``.

Use ``RedactionPolicy/disabled`` only with test servers and test accounts.

### Limits

- A secret under a key that is plain ASCII but not a secret name, such as `creds` or `pass`, is
  stored unless the detectors find it. Add the name with `additionalSecretNames`.
- Short secrets in a path segment, such as `/reset/abc123`, are stored; only identifiers and
  tokens of the shapes listed above become `:id`.
- In free text, a secret word written with look-alike letters and followed by a space instead of
  `=` or `:` is not recognized.
- Header names, and query parameter names in which the detectors find nothing, are stored as
  they were sent.

## See Also

- ``RedactionPolicy``
- ``CapturedBody``
