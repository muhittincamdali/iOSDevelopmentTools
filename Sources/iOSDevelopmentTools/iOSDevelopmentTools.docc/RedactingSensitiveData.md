# Redacting sensitive data

Understand what is replaced before a request is stored, and how to change it.

## Overview

Every value that reaches a ``NetworkLogger`` goes through its ``RedactionPolicy`` first. The
console, ``HTTPArchive`` files, ``NetworkEntry/curlCommand()`` and screenshots of the console
therefore never contain the original values. Your app still receives everything unchanged.

### How names are matched

A name is sensitive when its normalized form contains one of the policy's
``RedactionPolicy/nameFragments``. Normalizing lowercases the name, removes percent-encoding (up
to four times, so doubly encoded names are caught), applies Unicode compatibility normalization
(NFKC, which turns full-width and similar forms into the letters they stand for) and drops
everything that is not an ASCII letter or digit:

| Name in the request | Normalized | Matches |
| --- | --- | --- |
| `Authorization` | `authorization` | `auth` |
| `X-API-Key` | `xapikey` | `apikey` |
| `refresh_token` | `refreshtoken` | `token` |
| `API%5FKEY` | `apikey` | `apikey` |
| `pass%2577ord` | `password` | `password` |
| `ｐａｓｓｗｏｒｄ` | `password` | `password` |

The default fragments are listed in ``RedactionPolicy/defaultNameFragments``. Matching errs on
the side of hiding too much: a JSON key named `author` is hidden because it contains `auth`.

### What is redacted

- **URLs:** the values of sensitive query parameters (split on `&` and `;`), of sensitive
  parameters in the fragment (as in `#access_token=` of OAuth redirects), of `;name=value`
  parameters in path segments (`;jsessionid=`), and the whole user info (`user:password@`).
- **Headers:** headers with a sensitive name (`Authorization`, `Cookie`, `Set-Cookie`,
  `X-API-Key`, …) and headers whose value starts with an authentication scheme (`Bearer …`,
  `Basic …`, `Token …`, `AWS4-HMAC-SHA256 …` and the other schemes listed in
  ``RedactionPolicy/redact(headers:)``) whatever their name.
- **JSON bodies:** the value of every sensitive key at any depth, including inside string values
  that hold JSON themselves (as GraphQL clients send `variables`), also when the content type
  does not say JSON, or says form, but the body starts with `{` or `[` (after white space or a
  UTF-8, UTF-16 or UTF-32 byte order mark). Unicode escapes in keys are decoded
  first, so `"\u0070assword"` is caught.
- **Form bodies** (`application/x-www-form-urlencoded`): sensitive fields. A body sent without
  a `Content-Type` is checked as a form too, because `URLSession` sends it as one.
- **Multipart bodies:** sensitive fields by their `Content-Disposition` name (quoted names may
  contain `;`, and when a part repeats the header or the `name` parameter, every name is
  checked), and JSON or form parts by their own content type. A part with two `Content-Type`
  headers is withheld, because servers differ in which one they read. As in RFC 2046, a boundary
  counts only at the start of a line, so `--boundary` inside a value cannot end a part early.

### Bodies that cannot be checked are withheld

A structured body that cannot be parsed cannot be checked: a JSON body cut off at the capture
limit, malformed JSON, JSON nested deeper than 64 levels, or a multipart body without its closing
boundary, with more than 1,000 parts, with text before the first boundary or after the closing
one (servers ignore that text, so it is not checked as a field), with a boundary or a part
header line after a bare CR or LF (servers such as Werkzeug take that for a line break), or with
a line that starts with the boundary and goes on, as `--boundaryX` (servers that compare only the
prefix start a part there). Multipart bodies are also withheld when the content type has more
than one `boundary` parameter (or a `boundary*` one), when a part header line starts with a space
or tab and so continues the line before it, and when a `name` is split into RFC 2231 pieces
(`name*0`, `name*1`): Werkzeug, behind Flask, uses the last boundary, joins folded lines and joins
the pieces, so the field it reads could differ from the one checked. Storing such a body unchecked could store a secret, so the policy withholds it: the
entry keeps the body's size and marks it ``RedactionOutcome/withheld``, without its bytes. Raise
``NetworkLogger/Configuration/maximumBodySize`` to keep larger JSON bodies, or create a policy
with `withholdsUncheckedBodies: false` to store them unchecked.

### Change the policy

Add fragments for your own names:

```swift
NetworkLogger.shared.configuration.redaction = RedactionPolicy(
    nameFragments: RedactionPolicy.defaultNameFragments + ["iban", "ssn"]
)
```

Use ``RedactionPolicy/disabled`` only with test servers and test accounts.

### Limits

- Values in plain text, XML and other unstructured bodies are not checked.
- Path segments are not checked, apart from `;name=value` parameters. A secret in the path
  itself (`/reset/8f2c…`) is stored.
- Big-endian UTF-16 or UTF-32 JSON without a byte order mark is recognized only when the
  content type says JSON.
- A JSON value inside a form field, as in `data=%7B%22password%22%3A%22…%22%7D`, is not
  checked; only the field's own name is.
- A secret under a name that contains none of the fragments is stored. Add the name's
  distinctive part to the fragments.
- Log messages in ``LogStore`` are stored as you write them. Do not log secrets.

## See Also

- ``RedactionPolicy``
- ``CapturedBody``
