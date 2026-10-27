# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.2] - 2026-10-27

A security release. Checked again against the shared redaction specification (revision 2.1-r2,
with the required tests added to it on 26 October 2026), 2.1.1 showed most of a text longer than
its reading limit. The API is unchanged, and every text of up to 2^28 − 1 Unicode scalars is
stored as 2.1.1 stores it.

### Security

- A text longer than 2^28 − 1 Unicode scalars (268,435,455) is hidden whole, as the 2.1.1 notes
  and the guide said it was. 2.1.1 hid only its first scalars and stored the rest as it was: a
  text of 2^28 + 99 scalars passed to `RedactionPolicy.redact(text:)` was stored as `[REDACTED]`
  followed by all but its first 99 scalars, so a secret after them showed. The same happened to a
  kept header value (`redact(headers:)`), to the value of an allowed query parameter
  (`redact(url:)`, the recorded URL, HAR files and cURL commands) and to an error description
  that `NetworkEntry` records, at that length. A message logged to `LogStore` is redacted up to
  1 MiB and a body over 16 MiB is omitted, so neither was affected. Such a text is now not read
  at all and is stored as `[REDACTED]`, and a path segment of that length becomes `:id` with the
  segment after it. 2.1.0 had the same flaw for texts longer than 2^32 − 1 scalars.
- A span, the internal record of what to replace in a text, keeps its offsets in 28 bits. An
  offset that does not fit now makes the span hide the whole text instead of keeping the low 28
  bits of the offset, so no path that reaches a span with such an offset can show the rest of
  the text.

### Changed

- The port of the specification's required test set checks item 2 with the JSON escape it is
  written with (the port tested the plain name before), item 17c on every path that reads text,
  with the limit made short for the test, and the value detectors on form, query and multipart
  names, query values, path segments and kept header values (rule P4). The new span tests fail on
  2.1.1 and pass now; the tests for item 2 and rule P4 pass on 2.1.1 too.
- The redaction guide lists what is stored for a text over the limit, and its introduction names
  the rule 2.1.1 missed.
- `HTTPArchive.creatorVersion` is `2.1.2`.

## [2.1.1] - 2026-10-26

A security release. 2.1.0 followed an earlier generation of the redaction specification that this
package shares with iOSSecurityTools and iOS-Networking-Architecture-Pro. Checked against the
specification's current revision (2.1-r2), it showed values that the specification hides in a
URL host that names a secret, in paths with some escapes, in free text with white space outside
ASCII, beside names of control characters or names written outside ASCII, and in multipart part
headers, and it read some other input differently from the specification. 2.1.1 replaces the
redaction rules with the current generation, the design iOSSecurityTools 2.1.0 and
iOS-Networking-Architecture-Pro 2.0.0 use, behind the same `RedactionPolicy` API. The API is
source compatible. Stored text can differ from 2.1.0 for the same traffic: mostly more is hidden,
and the cases where less is hidden are listed under Changed.

### Security

- A URL host that names a secret is hidden with everything after it, as its value may be in the
  host itself: `myapp://password.hunter2`, `myapp://pin-4831` and
  `https://pin-4831.example.com/a` were recorded with their host in 2.1.0 and are now recorded as
  `myapp://[REDACTED]` and `https://[REDACTED]`, in `redact(url:)`, in the host and path that the
  console lists (`NetworkEntry.host`, `NetworkEntry.path`), in HAR files and in cURL commands.
  `myapp://pin/4831` is now `myapp://[REDACTED]` instead of `myapp://pin`, and a host such as
  `auth.example.com` is hidden whole, which over-hides on purpose. An IP address names nothing.
- A recorded URL whose path holds an escaped `/`, `\` or `%` (`%2F`, `%5C`, `%25`, in either case)
  is recorded with its scheme, host and port only, as a path with a dot segment or a `;` already
  was. Servers decode such escapes before they route, some of them twice, so which segment follows
  a secret name depends on the server; 2.1.0 read such a path segment by segment
  (`/pin%2F4831/x` as `/:id/:id`, `/a%25/x` as `/a%25/:id`).
- White space outside ASCII (U+00A0, U+2009, U+3000 and the others) cuts free text where it
  stands, as every other character outside the safe alphabet does: `ok`, U+00A0, `status=1`,
  U+00A0 and `x=hunter2` is stored as `ok[REDACTED]`. 2.1.0 read such a space as a space and read
  on. A word that mixes scripts with no separator after it (`120µs`, as the micro sign reads as a
  Greek letter) cuts the text at its start, and `Bearer` with U+2028 after it no longer keeps the
  separator.
- A string of control characters and white space alone (`"\t"`, `"\n"`, `"\u0000"`, a form value
  `%0A`) names a secret beside any member or field: `{"ParameterKey":"\t","ParameterValue":"x"}`,
  `{"title":"\t","data":"x"}` and `ParameterKey=%0A&ParameterValue=x` showed `x` in 2.1.0.
- A name written outside plain ASCII in a member that holds a name (`name`, `id`, `type`, …) hides
  the other members of the object: `{"id":42,"name":"Ayşe Yılmaz","price":12.5}` is stored as
  `{"id":"[REDACTED]","name":"Ayşe Yılmaz","price":"[REDACTED]"}`, and
  `{"name":"Şifre","x":"hunter2"}` hides `x`. 2.1.0 kept the other members of such a record. This
  over-hides on purpose: the name itself stays readable.
- `token`, `secret` and `bearer` count anywhere in a key, as the guide already said every secret
  word of five or more letters does; 2.1.0 counted them only as a word or at the end, so
  `{"secretanswer":…}`, `{"secretvalue":…}`, `[["secretvalue",…]]` and `/v1/secretanswer/…` kept
  their values. `secretary` and `tokenizer` are hidden too.
- An escape (a backslash, `%` and two hex digits, `&` before a letter) cuts free text at the start
  of the word it is in, so no letter before it shows: `login pa\x{73}sword hunter2` is stored as
  `login [REDACTED]` (2.1.0: `login pa[REDACTED]`) and `R&D team` as `[REDACTED]`.
- JSON in a line of text, a two-element array and a quoted key that is not allowed cut the text at
  the opening quote of the name, so the name does not show: `{"status":200,"user":"bob"} done` is
  stored as `{"status":200,[REDACTED]` and `log [["X-User","bob"]]` as `log [[[REDACTED]`. A quote
  glued to the word before it (`x"status": 200`) cuts at the start of that word, and
  `field name="password" hunter2` no longer keeps the opening quote.
- Multipart part headers follow their own list instead of `allowedHeaders`, which is the
  allowlist of request and response headers. 2.1.0 applied `allowedHeaders` to part headers, so
  with the default policy `User-Agent: hunter2`, `ETag: "hunter2"`, `Accept-Language: hunter2` and
  `Cache-Control: max-age=hunter2` in a part were stored with their values, and so was any part
  header an app added to `allowedHeaders`. They are now stored as `[REDACTED]: [REDACTED]`. Only
  `Content-Length` and `Content-Transfer-Encoding` keep their value, in their form only (next
  item); `Content-ID`, `Content-Description`, `Content-Language`, `Content-Location` and
  `Content-Encoding` keep their name (`Content-Encoding: [REDACTED]`). Such headers are rare in a
  part, and in 2.1.0 their values still went through the free-text rule, which hid what it
  detects there.
- The value of `Content-Length` and `Content-Transfer-Encoding` in a multipart part is written by
  its form and no longer read as free text, which keeps the text before a finding and all of a
  value without one: 2.1.0 stored `Content-Length: 12 hunter2` and `Content-Length: ok hunter2`
  as they were sent and `Content-Length: pin-4831` as `Content-Length: pin[REDACTED]`. A
  `Content-Length` is now kept only as ASCII digits in which the value detectors find nothing (a
  card number written as one run of digits stays hidden), and a `Content-Transfer-Encoding` only
  as `7bit`, `8bit`, `binary`, `base64` or `quoted-printable`, in lowercase. Any other value is
  stored as `[REDACTED]` (`Content-Length: [REDACTED]`), and the content of a part whose transfer
  encoding is hidden is omitted; a transfer encoding with white space outside ASCII after it
  (`8bit` and U+00A0) no longer counts as `8bit`.
- Also hidden now, by rules taken from iOS-Networking-Architecture-Pro: a label written outside
  ASCII and ended by a separator, in a member that holds no name (`{"title":"Пароль:","value":…}`,
  `{"title":"【暗証番号】","value":…}`); a card number in a JSON number written with an exponent
  (`4.111111111111111E15`) and a JSON number of 32 or more digits written out (`1e31`); a
  character outside the safe alphabet at the end of a text (`done 👍` is stored as
  `done [REDACTED]`).
- Free text longer than 2^28 − 1 Unicode scalars is hidden whole (2.1.0: 2^32 − 1), the limit of
  the specification. (This did not hold in 2.1.1, which hid only the first scalars of such a
  text; see 2.1.2.)

### Changed

- Where 2.1.0 hid more than the specification asks, the text is now kept as the specification
  reads it: `status=200&count=3` is kept (an `&` that starts a field before `=` is no escape),
  `say (hello` keeps `say (` (the text is cut after a bracket that does not close),
  `line 42:10: error` keeps `line 42:10: `, `1:2:3` and `ratio 16:9` are kept (a line and column),
  `pаssword=hunter2` with a Cyrillic `а` keeps its key, and a path segment `:id` is no label, so
  `/users/:id/x` is kept as it is.
- A multipart part keeps its `Content-Transfer-Encoding` header when it names one of the five
  encodings, written in lowercase (`Content-Transfer-Encoding: BASE64` is stored as
  `Content-Transfer-Encoding: base64`), which 2.1.0 stored as `[REDACTED]: [REDACTED]` by default,
  and the names `Content-ID`, `Content-Description`, `Content-Language` and `Content-Location` with
  the value hidden.
- A URL without a scheme and a host is recorded as `<unparsed URL>`: `mailto:ada@example.com` was
  recorded as `mailto::id`.
- The note of an omitted body says `no content type` when there is none and
  `unreadable content type` when it cannot be read (2.1.0: `no known content type` for both), and
  `1 byte` for a body of one byte.
- JSON bodies in UTF-16 or UTF-32 and a byte order mark are read the same way on every OS version;
  a JSON body with a second byte order mark is omitted.
- The readings cache of characters outside ASCII has up to 8,192 slots (2.1.0: 4,096), in sets of
  two chosen with a hash seeded at random in every process.
- The tests hold the specification's required test set, and the shared corpus of review probes
  grows from 5,077 to 9,147 probes with the later review rounds of iOSSecurityTools.
- `HTTPArchive.creatorVersion` is `2.1.1`.

## [2.1.0] - 2026-10-21

This is a security release for everyone who records traffic that can carry secrets: redaction in
2.0.0 could be bypassed by names and bodies it did not fully understand, and 2.1.0 replaces its
patches with one shared specification instead of a patch per reported bypass. The rule: what
the policy does not fully understand is hidden, never shown. It is built for secrets recorded by
accident; structured input is default-safe and free text is a best effort with one cut point (see
"Threat model" in the redaction guide). Redaction is a safety net, not a guarantee; keep secrets
out of logs in the first place.

### Breaking changes

Redaction hides more than 2.0.0 did, so what an app reads back from the console, a HAR file or a
cURL command can differ for the same traffic. The API is source compatible; the old names are
deprecated and still build (see Deprecated).

- A key that is not made of ASCII letters, digits, `_`, `-`, `.` and spaces has its value hidden:
  `{"Şifre":"…"}`, a full-width or look-alike spelling, a key with a zero-width character, a
  combining mark or an emoji, an empty key and a key over 256 characters. A field with an ordinary
  name in another script (`{"名前":"…"}`) is hidden as well, since the policy cannot tell it from
  a secret; keys in plain ASCII that are not secret names keep their values.
- A body that cannot be parsed completely is no longer stored. Invalid or truncated JSON, a form
  or multipart body that a common server parser could read differently, a body over
  `maximumBodySize`, and a body with an unknown or missing content type (XML and other types,
  which 2.0.0 stored unchecked) are replaced by a note such as
  `[body omitted: 512 bytes, application/xml]`. Code that read the stored text of such a body, in
  the console, `NetworkEntry`, HAR files or cURL commands, now finds the note.
- `RedactionOutcome.withheld` is now `.omitted`. A `switch` over `RedactionOutcome` needs the new
  case name; `.withheld` remains as a deprecated static property.

### Security

- Keys (JSON member names, form, query and multipart field names, header names) are read after
  their escapes are decoded by the parser. Only a key made of ASCII letters, digits, `_`, `-`, `.`
  and spaces is compared with the secret names, with the separators folded away and the letters
  lowercased. Any other key has its value hidden: a letter outside ASCII (also a full-width one),
  look-alike letters from another script, format characters such as ZWJ or a soft hyphen,
  combining marks, other punctuation, an empty key and a key longer than 256 characters. A key
  that matches hides its whole value, whatever its type, at every repetition.
- Names written as values are read by the same rule: `{"name":"Authorization","value":…}`, JSON
  Patch and SCIM `{"op":…,"path":"/password","value":…}`, `label=Password&value=…`,
  `[["Authorization","…"]]`, and a name that is not plain ASCII or has no letter or digit
  (`Şifre`, `ⓟⓘⓝ`, `🔑`) hide the value beside them (`value`, `data`, `content`, … and any member
  with such a word in its name). A name that names a secret word, has no letter or digit, is
  written in styled letters or is held by `key`, `label`, `param` or another member that only
  pairs use hides every member beside it. A `name`, `id` or `type` written in another script or
  with punctuation is as often a person, a place, a product or a media type, so the rest of such
  a record stays: `{"id":42,"name":"Ayşe Yılmaz","price":12.5}` is stored as it is.
- Bodies are parsed, never scanned by hand: JSON with a JSON parser whose tree must agree with
  `JSONSerialization` (stored as sent, with hidden values replaced, so it stays valid JSON), forms
  with the platform's percent decoding, multipart with a strict RFC 2046 and RFC 7578 parser that
  always omits file parts and file names. A body is omitted with a note such as
  `[body omitted: 512 bytes, application/xml]` when its content type is unknown or missing, when it
  does not parse completely, was cut off or is over `maximumBodySize` (256 KiB by default, at
  most 16 MiB), when JSON is in another encoding than
  its `charset` names, and when a common server parser could split it into fields differently: a
  form with a `;`, a bare `%` or a name spelled two ways, a multipart body with `--boundary` other
  than at a CRLF delimiter, LF-only part headers, or a quoted, repeated or over-long boundary. In
  2.0.0, plain-text, XML and other bodies were stored unchecked.
- Headers keep their values only when they are on an allowlist (by default `Accept`,
  `Accept-Encoding`, `Accept-Language`, `Cache-Control`, `Content-Encoding`, `Content-Length`,
  `Content-Type`, `ETag` and `User-Agent`). `Authorization`, `Proxy-Authorization`, `Cookie`,
  `Set-Cookie`, `X-Api-Key`, names with `token`, `secret`, `key`, `auth`, `session` or `signature`
  and names that are not ASCII tokens stay hidden when listed, and so do values that start with an
  authentication scheme, as in 2.0.0.
- URLs lose their user info and fragment. Query values are hidden unless the parameter is on an
  allowlist, which is empty by default, and a query that servers could split differently is
  written as `?[REDACTED]`. A host that is neither a name of ASCII labels nor an IP address, or in
  which a value detector finds something, is reduced to the scheme. Path segments that look like identifiers or secrets become `:id`, and
  so does the segment after one that names a secret. A path of more than 64 segments or a query of
  more than 128 parameters is recorded with its scheme, host and port only, and so is a path that
  servers resolve differently from how it is written: one with a `.` or `..` segment, `%2E` in any
  case, a `;` anywhere, raw or as `%3B` in any case, or an escape escaped again (`%252E`). No
  parameter after a `;` (matrix parameter) is parsed.
- Free text (`LogStore` messages, error descriptions of failed requests, kept header values,
  `text/plain` bodies and the strings of structured input) has one cut point: from the first
  trigger, everything to the end of the text is hidden, the lines below included. The triggers
  are a key before `=` or `:` that is not on `allowedTextKeys` (`status`, `method`, `path`,
  `duration_ms` and `count` by default), also in JSON members, two-element arrays and quoted keys
  in the text; a secret name with or without a separator, quoted or not, also written as a value
  (`name="pin"`); a key that is not plain ASCII, has no letter or digit, or
  is missing; the words of a key that name a secret when read together (`pass word=`); a
  character outside the safe alphabet (letters, marks and digits of any script, the ASCII space,
  tab, LF and CR, printable ASCII), judged by its own Unicode category, so `꞉`, `≔`, `＝`, `…`,
  `‥`, `№`, emoji, VT, FF, U+0085 and U+2028 cut the text, and a letter or digit judged also by
  the compatibility form the rule reads, so `🄁` (read as `0,`), `⒈`, `⑴` and `½` cut it too; an
  escape, which is never decoded and of which no list of forms is kept: a backslash before
  anything but an ASCII space, a tab, a line break or the end of the text, `%` and two hex
  digits, and `&` before a letter or `#` (`%3D`, `&#61;`, `&amp`, `R&D`, `\u0041`, `\p{L}`, `\"`,
  `dir\data`); a word longer than 256 characters; a word that mixes scripts or
  holds an invisible character; markup, from its first `<` that is not a comparison; a quote that
  does not close on its line; a bracket that does not close; and JSON that does not parse. Text
  with no trigger is kept as it is, apart from the value detectors, and JSON in it is read by the
  key rule of structured input.
- A URL in free text has no island logic. It stays visible only when it is clean:
  `scheme://host` with an optional path of ASCII letters, digits, `.`, `_`, `-` and `/`, a host
  name or IPv4 address, no host or path segment that names a secret, and after it white space, a
  line break, the end of the text or one of `.`, `,`, `!` and `)` followed by one of those. Any
  other URL hides the text from where the URL starts: one with a query, a fragment, `;`, `%`, `=`,
  `:`, `@`, `\`, a port, user info, an escape or a character outside ASCII, and one that a quote,
  `>`, a backtick, `]`, `}` or two marks follow (`GET https://api.example.com/v1/items?page=2 done`
  is stored as `GET [REDACTED]`). `allowedQueryParameters` applies to recorded URLs, not to URLs in
  text. Earlier builds of this release read the query, fragment and path parameters of a URL in
  text and read on after them; reviews got values past that reading through an empty or allowed
  section after a secret segment (`/password# hunter2`), an encoded `=` or `:` at the end
  (`/user%3A hunter2`) and an escape in the path (`/x\u003d hunter2`).
- A `:` between two digits is part of a number only when both sides are a whole number: a
  number before it, and after it the two digits of a time (with seconds, a fraction, `Z` or an
  offset) or, after an IPv4 address, a port of at most five digits, then white space, the end of
  the text or closing punctuation (`12:30`, `12:30:45,123`, `2026-10-19T12:30:00Z`,
  `10.0.0.1:8080`). Any other `:` is a separator, so `curl -u admin1:2345678901` is stored as
  `curl -u admin1:[REDACTED]` and `curl -u 42:2345678901` as `curl -u 42:[REDACTED]`. An earlier
  build of this release looked only at the left side; a review got values through after a number
  used as a key (`42:2345678901`, `12:34hunter2`, `10.0.0.1:8080secretvalue`, `12:30:4f9a2c7b`),
  in a line, a JSON string and an allowed header. A ratio such as `16:9` is now cut as well.
- One letter that has no ASCII form put in before the last letter of a secret word
  (`tokeꞏn`, `piın`, `keıy`, `pꞏw`) is read as no letter as well as the last letter, so the word
  is found where it has to end a name. Before, the match took the first reading only and missed
  14 of 16 short secret words in free text, URL path segments, record names and allowed query
  values.
- Such a letter right after a secret word is read as its plural `s` and as no letter before a
  plural `s`, so `tokenꞏ`, `tokenꞏs`, `keyꞏs` and `/v1/otpł/…` are found like `tokens`. Before,
  the match stopped once the word was spelled whole, and short secret words (`token`, `key`,
  `pin`, `otp`, `card`, …) followed by such a letter were not found in free text, JSON strings,
  form values, text/plain and multipart parts, an allowed header, LogStore lines and URL path
  segments.
- Each word of free text is also read as its ASCII skeleton, as the redaction spec says: every
  letter that has no ASCII form is left out, however many there are and wherever they stand, and
  the rest is compared with the secret names, the plural `s` included. `tokensı`, `keysꞏ`,
  `pinsı`, `otpsł`, `user_tokensı`, `myTokensı`, `tokenꞏꞏ`, `tokenꞏsꞏ` and `pıaıssword` are found
  like `tokens`, `keys`, `pins`, `otps`, `user_tokens`, `myTokens`, `token`, `tokens` and
  `password`. Before, the match read one such letter and none after the plural `s`, so these
  words and the values after them were stored as they were in free text, JSON strings, form
  values, text/plain bodies, an allowed header and URL path segments. A name with two or more of
  its letters replaced by look-alikes (`pɑsswoʀd hunter2`) is still not found, as the guide says.
- The one wildcard rule of the redaction spec covers marks and numbers as well as letters: one
  letter, mark or number with no ASCII form inside a word stands for any one letter or for none.
  A mark written after an ASCII letter in place of the next one (`tͦken`, `pͥn`, `passwͦrd`,
  `sͤcret`, `p\u{0301}ssword`) and a number without an ASCII form (`passw〇rd`, `t〇ken`, with
  U+3007 in place of the `o`) were not read as a letter: the scanned text leaves marks out, and
  only a letter counted as a wildcard. These names and the values after them were stored as they
  were in free text, JSON strings, form values, multipart parts, text/plain bodies and LogStore
  lines. A mark on a letter that is a wildcard belongs to it (`pɑ́ssword`), and marks on every
  letter are still left out (`t̷o̷k̷e̷n̷`).
- Markup in free text is not parsed, as the redaction spec says, and what may follow a `<` is
  listed instead of what makes a tag: a `<` is a comparison only before an ASCII space, a tab, a
  line break, an ASCII digit, `=` or the end of the text. Before anything else it cuts the text,
  so `<status>200</status> hunter2`, `<!-- hunter2 -->`, `<![CDATA[hunter2]]>`, `<?pi hunter2?>`,
  `</x> hunter2`, `<!DOCTYPE html> hunter2`, `<br/> hunter2`, `a <# c`, `1 <> 2` and
  `List<String> items` are cut at the `<`. Before, an allowlist of tags and the text of the
  element that was open decided: an allowed tag kept its text, and comments, CDATA, processing
  instructions, end tags and self-closing tags kept the text after them.
- A quote that does not close on its line cuts the text at the quote, and so does a quoted key
  with a line break in it: `msg "abc` with `hunter2" done` on the next line is stored as
  `msg [REDACTED]`, in a log line, a `text/plain` body and a JSON string alike. Before, a quote
  closed at the next one anywhere in the text, so the lines in between were kept.
- Quotes in free text are read as nested: a quote of one of six kinds (`"`, `'` and a
  backtick, plain or escaped) opens inside a quote of another and closes at the next one of its
  kind on its line only while it is the innermost quote open. Quotes that overlap (`'x "y' z"`,
  `"a \" b"`) cut the text at the earliest quote still open, as a quote still open at a line
  break does. `status='x "y'` with `hunter2" ok` on the next line is stored as
  `status=[REDACTED]`, and so is `status='x "y' "c` with `hunter2" ok`, in a log line, a
  `text/plain` body and a JSON string alike; the same holds for a backtick quote, `"x \"y"`,
  `"x 'y"` and `'"note'` before `Qx31": 1`. Before, one quote was kept open at a time and the
  quotes inside it opened nothing, so the value on the next line showed; and a first fix that
  read each kind of quote on its own took the second `"` of `'x "y' "c` for the close of the
  first, so it showed again. `"a \" b" done` is now stored as `[REDACTED]`.
- A backslash in free text is an escape before anything but an ASCII space, a tab, a line break
  or the end of the text, and `&` before any letter or `#`; no list of their forms is kept. Before,
  a backslash was an escape only before an octal digit or `x`, `u`, `U`, `N` or `o`, and `&` only
  with a name and `;` or with `#` and a digit, so `dir\data\hunter2`, a written `\n` or `\t`,
  `\"hi\"`, `a\\b`, `\p{L}`, `\e`, `\8`, `\cJ`, `\k`, `a\/b`, `R&D`, `&amp` without `;`,
  `&#x;` and `&#q` kept the text after them in a log line, a `text/plain` body, a JSON string, a
  form value, an allowed query value and a multipart part. An escaped quote is now cut at its
  backslash (`"x \"y\" z"` is stored as `"x [REDACTED]`), and so are pairs joined by `&`
  (`status=200&count=3` is stored as `status=200[REDACTED]`). JSON in the text is read by its
  parser, so its escapes are not escapes of free text. A backslash escape in a JSON member name
  cuts the name at the backslash, and a name read for secret words that holds one (a URL path
  segment, a name written as a value) counts as one that names a secret.
- A letter or digit whose compatibility form holds ASCII punctuation or a character outside the
  safe alphabet cuts free text, as the scanner reads that form. Before, such a character was
  judged by its own category only, so U+1F101 to U+1F10A (`🄁` to `🄊`, read as `0,` to `9,`)
  let the `,` end a key before an allowed one: `🄁status=hunter2`, `x🄁status=`, `🄁count: `,
  `🄊method=` and `🄁"status": ` kept their values in a log line, a JSON string, a form value
  and a `text/plain` body. Every scalar from U+0021 to U+3FFFF is now tested before an allowed key.
- A recorded URL whose path has a dot segment is recorded with its scheme, host and port only.
  Before, a `.`, `%2E` or empty `;` segment right after a secret name took the `:id`, so
  `/v1/pin/./4831` was stored as `/v1/pin/:id/4831` and `/token/x/../4831` as
  `/token/:id/../4831`, while servers and `URL.standardized` resolve both to the value after the
  name.
- A recorded URL whose path has a `;` anywhere, raw or as `%3B` in either case, is recorded with
  its scheme, host and port only, and no parameter after a `;` is parsed. Before, only a `;` with
  nothing before it in its segment did this, and `%3B` was not checked (`/a%3Bb/c` was stored as
  it is). The other matrix parameters were read one by one, without the rule that a field naming
  a secret hides the value beside it: with `value` allowed, `/a;label=password;value=…`,
  `/a;name=api_key;value=…`, `/a;value=…;name=password` and `/a;name=%C5%9Eifre;value=…` kept
  the value, which `?label=password&value=…` hides. The default policy, which allows no
  parameter, hid all of these values.
- A recorded URL whose host names a secret, by the key rule or as a word, is recorded with its
  scheme, host and port only. With a scheme of the app's own `URLComponents` reads the first
  part after `//` as the host, so in `myapp://pin/4831` the host is `pin` and the path `/4831`.
  Only the host's shape was checked and the path was read as if nothing came before it, so
  `myapp://pin/4831`, `myapp://password/hunter2`, `myapp://token/abc123`,
  `myapp://session/s3cr3t` and `https://pin/4831` were stored as they are in the URL and path
  of a `NetworkEntry`, in HAR files and in cURL commands, while the same URL in a log line cut
  the text. A host such as `auth.example.com` names `auth` and now hides its path and query too.
  `NetworkEntry.path` is also empty when the host is hidden: `myapp://pin_x/4831` kept `/4831`
  there while its URL was `myapp://[REDACTED]`.
- A URL path segment is read by the key rule, as the spec says: a segment that, decoded, is not
  plain ASCII (letters, digits, `_`, `-`, `.` and spaces, with a letter or digit among them) is a
  label, and the segment after it becomes `:id`, as after a secret name. Before, only a segment
  in which free text read a secret word labelled the next one, so
  `https://x.example/t%CD%A6ken/…`, `/p%CD%A5n/…`, `/passw%CD%A6rd/…`, `/s%CD%A4cret/…`,
  `/user/passw%E3%80%87rd/…` and `/api/%C5%9Eifre/…` kept the segment after the name. Paths such
  as `/caf%C3%A9/menu`, `/u/ada%40example.com/profile`, `/a+b/c` and `/.../x` now keep only
  their first segment (`/caf%C3%A9/:id`), which over-hides on purpose.
- A quoted key that is not on `allowedTextKeys` cuts the text at its opening quote, whichever
  quote it is written in: `"x":"hunter2"`, `"x"="hunter2"`, `'x': 'hunter2'` and `"hunter2":"v"`
  are stored as `[REDACTED]`. Before, the cut came after the separator, so the key showed.
- A clean URL in free text may be followed only by white space, a line break, the end of the text
  or one of `.`, `,`, `!` and `)` and then one of those; anything else cuts the text where the URL
  starts. Before, one of `.,!)]}>"'` and a backtick ended a clean URL whatever came after it, so
  `see https://a.example/v1/x), ok`, `x'y ok`, `x>y ok` and `x> ok` kept the URL, and `x"y` cut
  the text at the quote with the URL showing. The last segment of a clean URL is read with the
  next word, as two words are (`https://x.example/to ken hunter2`).
- `NetworkEntry.host` is the host as the recorded URL writes it: `[REDACTED]` when the URL rule
  hides it (`myapp://password=hunter2/x`, a card number or a token in the host). Before, it kept
  the host as the request had it, and the list of requests in the console showed it.
- A backslash before `x`, `u`, `U`, `N`, `o` or an octal digit is an escape in free text whatever
  follows it, so `\x{70}assword`, `\U00000070assword`, `\N{LATIN SMALL LETTER P}assword` and
  `\o{160}assword` cut the text like `\u0070assword` does.
- Multipart part headers keep their names only when they are on the header allowlist; any other
  is written as `[REDACTED]: [REDACTED]`.
- A `LogStore` message is redacted up to 1 MiB of Unicode scalars, on the thread that logs it; a
  longer one is redacted up to its last line break before that length and the rest is hidden.
- Values are scanned for JWTs, bearer credentials, hex or Base64 strings of 32 or more characters,
  card numbers (Luhn), IBANs (mod 97), email addresses with names and domains in any script and the
  password in `user:password@host`, in the same way in bodies, free text, URLs and JSON strings.
- The value detectors read across VT, FF, U+0085, U+2028 and U+2029, as the redaction spec says:
  as white space between the groups of a card number or an IBAN and after `Bearer`, and as
  nothing inside an email address, a JWT and a long token. Each of these separators cuts free
  text, and the finding joins the cut, so the text is hidden from where the finding starts:
  `paid 4111 1111 1111`, U+2028 and `1111` is stored as `paid [REDACTED]`. Before, the detectors
  stopped at them, and the text before the cut kept 12 of the 16 digits of that card number, 20 of
  the 22 characters of `DE89 3704 0044 0532 0130` and U+2029 before `00`, and the name of an email
  address, in free text, JSON strings, text/plain bodies and LogStore lines. A line feed or a
  carriage return written as such still ends a finding. Card groups are read through a window of
  the groups a card number can span, so a megabyte of them is not held in one array.
- A word of free text is compared with the secret names by one reading, its ASCII skeleton, in
  place of three that took a letter, mark or number with no ASCII form as any letter, as none or
  as a mark after a letter, one reading at a time. Every such character is left out, and a name
  also counts with one of its letters missing where one was left out, so each counts as nothing or
  as one letter on its own, as the one wildcard rule of the spec says. A decimal digit of another
  script is one of them: the scanned text reads it as its ASCII digit, for numbers and the value
  detectors, and the word read that digit too, so `t၀ken`, `p١n`, `c๐okie`, `passw०rd`,
  `sessi၀n`, `cre০ential` and `to၀ken` named nothing. A name with one character in place of a
  letter and another put in (`tͦkenͦ`, also with 300 marks after it, `pını`, `t〇ken〇`) was not
  found either. These names and the values after them were stored as they were in free text,
  LogStore lines, JSON strings, forms, multipart text parts, text/plain bodies, allowed query
  values and the `User-Agent` header, and beside a name written as a value
  (`{"name":"t၀ken","note":…}`, `["a","t၀ken",…]`). A digit that decomposes to an ASCII digit is
  still that digit (`passw０rd` reads as `passw0rd`), numbers written in other scripts stay as
  they are, and a card number written in them is still found. `ᴘwᴅ` now reads as `pw`, which the
  eleventh review listed as not found.
- An email address with a vertical tab, a form feed, U+0085, U+2028 or U+2029 right after it and a
  letter, a digit or `-` after that (`alice@example.com`, a vertical tab and `ok`), or with such a
  separator inside or right before its top-level domain (`example.c`, a vertical tab and `om`), was
  not found: its domain ran across the separator and the top-level domain was read with it. The cut
  the separator makes in free text kept the address before it (`mail alice@example.com[REDACTED]`),
  in free text, LogStore lines, JSON strings, forms, multipart parts, the `User-Agent` header,
  allowed query values and the network log with its cURL command and HTTP archive. The top-level
  domain is now read without the separators in it, and a domain that ends in none when read across
  a separator ends at the separator.
- A secret name with a line break or a character reference, held by a member that does not hold
  names (`{"setting":"password\n","value":…}`, `{"Parameter":"api\nkey","Value":…}`,
  `{"ParameterKey":"&#x0070;in",…}`, `{"setting":"pass&#119;ord",…}`), was taken for a sentence
  and named nothing, so the value beside it showed in JSON, forms, multipart bodies and URL queries
  with allowed names. A string of at most 256 scalars with a line break or an `&` is now read as a
  name once its line breaks are read as spaces and its escapes are decoded; a sentence keeps its
  `:` or `,` and still leaves the record as it is.
- Hostile input is bounded: JSON may be open 64 levels deep across every document a text is in, at
  most four documents are read one inside another, and the documents found in one input read at
  most four times its length. The tests run on a thread with 512 KiB of stack and, in a release
  build, check that a megabyte of input takes less than a second and, on macOS, that a megabyte of
  free text takes less than 16 MB of memory beyond the input.
- What a character outside ASCII is read as is kept in one table of a fixed number of slots, at
  most 4,096, for a whole text, body, URL or list of headers, as the spec says. Two dictionaries
  that grew with every different character, each reading with an array of its own and every
  character normalized twice, took 17.5 MiB for a megabyte of different characters in free text,
  a kept header value, a text/plain body or a JSON array of strings, and 70.5 MiB and 1.46 s for
  a log message of a million of them; every form field, multipart part, path segment, query value
  and header made a table of its own. The same inputs now take 2.5 to 5.7 MiB, and the log
  message 11.2 MiB and 1.3 s.

### Added

- `RedactionPolicy(additionalSecretNames:allowedHeaders:allowedQueryParameters:allowedTextKeys:maximumBodySize:urlDetail:)`,
  `redact(text:)`, `URLDetail` (`.hostOnly` records only scheme, host and port),
  `defaultSecretNames`, `defaultAllowedHeaders`, `defaultAllowedTextKeys`, `headerParameterNames`,
  `secretNames`, `allowedHeaders`, `allowedQueryParameters`, `allowedTextKeys`, `maximumBodySize`,
  `defaultMaximumBodySize`, `bodySizeLimit`, `maximumJSONDepth`, `maximumNestedDocuments`,
  `maximumPathSegments`, `maximumQueryParameters`, `LogStore.Configuration.redaction` and
  `LogStore.maximumRedactedMessageLength`.
- A test for each bypass class of the specification, every bypass reported against earlier
  versions, the test inputs of 2.0.0, property tests with generated obfuscations of every secret
  name, generated triggers after which no value may show and generated keys, tests that ordinary
  keys, allowlisted headers and text with no trigger stay readable, parser-differential, stack,
  time-limit and peak-memory tests, the probes of every review of the shared rules, and the
  examples of the guide. 631 tests run on macOS and 628 on an iOS simulator.

### Changed

- `RedactionOutcome.withheld` is now `.omitted`, and an omitted body stores the note in place of
  its bytes. The console, HAR files and cURL commands say why a body is missing.
- Secret names replace name fragments: a name of five or more letters counts anywhere in a key, a
  shorter one (`key`, `pin`, `otp`) as one of its words or at its end, and `pass`, `pw` and `sid`
  only as a word, so `keyboard` and `bypass` keep their values while `author` no longer matches
  `auth`. `bearer` is one of the names, since what follows it is a credential.
- JSON bodies are stored as sent instead of serialized again, and UTF-16 and UTF-32 JSON is stored
  as UTF-8. A query parameter without `=` is kept only when it is allowlisted.
- The Unicode properties redaction asks of a scalar are looked up once for the Basic Multilingual
  Plane and shared, and JSON and form text is encoded for the platform parsers without building
  a string scalar by scalar. A megabyte of an array of strings quoted in JSON three times took
  0.72 s on a 512 KiB thread in a release build and takes about 0.3 s on the same machine; no
  shape of the time-limit tests takes more than 0.4 s there.
- Whether another field of a form, URL query, multipart body or JSON object hides a field's value
  is told from the positions of the first two fields of each kind that name a secret, instead of
  reading every such field again for every field. Many fields whose `name`, `id` or `type` is
  written outside plain ASCII (`name=Ay%C5%9Fe&…`, `{"name":"Ayşe",…}`) made the time grow with
  the square of the body: on a 512 KiB thread in a release build a megabyte took 1.5 to 2.9 s and
  two megabytes 5.4 to 10.6 s, so a body near the 16 MiB that `maximumBodySize` allows would have
  taken minutes. They now take 0.2 to 0.4 s a megabyte, also at 16 MB, and the redacted bodies
  are the same.

### Deprecated

- `RedactionPolicy(nameFragments:withholdsUncheckedBodies:)`,
  `RedactionPolicy(withholdsUncheckedBodies:)`, `defaultNameFragments`, `nameFragments`,
  `withholdsUncheckedBodies` and `RedactionOutcome.withheld`. They still build and map to the new
  rules; an empty fragment list and `withholdsUncheckedBodies: false` no longer weaken redaction.

### Known limitations

No finding of the last two reviews is open: both were fixed and have tests. What remains is what
the redaction guide lists as limits, which is a best effort by design: free text has one cut point
and a secret with no label, a label not followed by `=` or `:`, or a short secret in a path segment
cannot be told from other text. See [Redacting sensitive data](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
and `SECURITY.md`. Redaction is a safety net, not a guarantee; keep secrets out of logs.

## [2.0.0] - 2026-10-15

A new package with a new API: an in-app network inspector, log console and device report. The
1.0.0 code (a network client built on Alamofire, storage, analytics and logging managers and
utility extensions) was removed in June 2026 and replaced with placeholders: a network
interceptor whose `URLProtocol` never sent the request, so every intercepted request hung, a
swizzling check that always returned `false`, a `SecureStorage` wrapper that wrote "sensitive"
values to `UserDefaults`, and circuit-breaker, retry and event-bus types unrelated to
development tools. None of that is kept. Because every public name changes, this release is a
new major version.

### Added

- `NetworkCapture` records the HTTP and HTTPS requests of `URLSession.shared` and of every
  session created from the default or ephemeral configuration after `start(logger:)`;
  `install(into:)` adds recording to any other configuration. Requests are sent on unchanged and
  responses reach the app unchanged; redirects, cancellations, errors and
  `URLSessionTaskMetrics` timings are recorded. A redirect that the app's session refuses
  returns the redirect response, half a second after it arrives.
- `NetworkLogger` stores the requests in a ring buffer with clamped limits (1–10,000 entries,
  0–16 MiB per body), can ignore hosts and their subdomains, accepts manual records for traffic
  capture cannot see, and publishes changes through an `AsyncStream`.
- `RedactionPolicy` replaces sensitive values before anything is stored: headers by name and by
  authentication scheme, query, fragment and matrix parameters, URL user info, JSON keys at any
  depth (also inside strings that hold JSON, and inside form and URL parameter values that decode to
  JSON), form fields (also in bodies sent without a `Content-Type`, and in JSON bodies sent as a
  form, which are checked both ways) and multipart fields. Names are normalized (case, separators,
  percent-encoding, invisible characters, NFKC compatibility forms such as full-width letters)
  before they are matched. Structured bodies that cannot be checked (cut off, malformed, nested
  deeper than 64 levels, multipart with more than 1,000 parts, with text outside its boundaries,
  with bare CR or LF line breaks, with a line that starts with the boundary and goes on, with more
  than one boundary parameter, with a folded part header, with a name split into RFC 2231 pieces,
  with a malformed header parameter or header name, or with a boundary outside the RFC 2046
  characters) are withheld. JSON is also recognized in UTF-16 and UTF-32, with or without a byte
  order mark.
  Separators are found in the UTF-8 bytes, so a combining mark after one cannot hide it.
  Parameters are checked both as split on `&` alone, as Python and `URLSearchParams` read them,
  and as split on `&` and `;`. JSON in
  which an object repeats a key is withheld, because parsers differ in which value they keep.
- `NetworkEntry.curlCommand()` and `HTTPArchive` export requests as shell-safe `curl` commands
  and as HAR 1.2 files.
- `LogStore` keeps leveled, categorized log messages in a ring buffer and writes them to the
  unified logging system; messages and categories are cut off at a number of Unicode scalars, so
  combining marks cannot stretch them; `LogFilter` filters them.
- `DeviceSnapshot` reports app version, OS, model, memory and memory footprint, thermal state,
  Low Power Mode, attached debugger, locale and uptime.
- `DevToolsConsole`, a SwiftUI console with Network, Logs and Device tabs, search, filters and
  share menus; `NetworkEntryView` for one request; `devToolsConsole(isPresented:)` and, on iOS,
  `devToolsConsoleOnShake()`.
- DocC documentation with four articles, and the DevToolsDemo example app for iOS and macOS.
- 148 Swift Testing tests that run on macOS, and 149 on an iOS simulator, including end-to-end
  capture through a stub server, redaction bypass attempts, and NaN, infinite and out-of-range
  inputs to every conversion.

### Changed

- Requires Swift 6.2 (Xcode 26), iOS 17 and macOS 14. watchOS and tvOS are no longer listed.
- No dependencies; the Alamofire, SwiftLint, Quick and Nimble dependencies of 1.0.0 are gone.

### Removed

- The 1.0.0 modules (`NetworkTools`, `StorageTools`, `AnalyticsTools`, `DebugTools`,
  `UtilityTools`) and the June 2026 placeholders described above.
- The CocoaPods podspec; the pod was never published to trunk.

## [1.0.0] - 2026-02-03

First tagged release: a network client built on Alamofire, storage, analytics and logging
managers and utility extensions in five modules, each also offered as its own library.

[Unreleased]: https://github.com/muhittincamdali/iOSDevelopmentTools/compare/v2.1.2...HEAD
[2.1.2]: https://github.com/muhittincamdali/iOSDevelopmentTools/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/muhittincamdali/iOSDevelopmentTools/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/muhittincamdali/iOSDevelopmentTools/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/muhittincamdali/iOSDevelopmentTools/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/muhittincamdali/iOSDevelopmentTools/releases/tag/v1.0.0
