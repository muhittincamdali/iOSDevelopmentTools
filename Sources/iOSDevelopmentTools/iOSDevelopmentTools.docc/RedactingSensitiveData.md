# Redacting sensitive data

Understand what is recorded, what is never recorded, and how to change it.

## Overview

Every request that reaches a ``NetworkLogger`` and every message logged to a ``LogStore`` goes
through a ``RedactionPolicy`` first. The console, ``HTTPArchive`` files,
``NetworkEntry/curlCommand()`` and screenshots of the console only ever see the redacted copy.
Your app still sends and receives everything unchanged.

The policy follows one rule: what it does not fully understand is hidden, never shown. Bodies,
URLs and headers are read with real parsers, a key that is not plain ASCII is hidden, and a body
that cannot be parsed is left out. Free text such as a log message has one cut point: from the
first sign of a secret, everything to the end of the text is hidden.

### A safety net, not a guarantee

Redaction catches mistakes; it does not make it safe to log secrets. It cannot know every name
your app or your server uses for a secret. Keep passwords, tokens and personal data out of the
requests you record and out of log messages in the first place, and treat the policy as the net
under that rule.

### What it is for: the threat model

The policy is built for one threat: a developer who records a secret by accident, such as a
request, a response, a header or user text written to the console, an exported file or a log. It
is not built to stop someone who writes a log line on purpose to get a secret past it.

- **Structured input is default-safe.** JSON, form and multipart bodies with their part headers,
  URLs and headers are read with a parser. What the policy does not fully understand there is
  hidden: a key that is not plain ASCII, a name that cannot be read, a body that does not parse.
- **Free text is a best effort.** A log line has no grammar, so the policy does not try to tell
  where a value ends. After the first trigger, such as a secret name, everything to the end of
  the text is hidden, the lines below included. A secret name written without a separator and
  disguised on purpose by writing two or more of its letters as look-alikes (`pɑsswoʀd hunter2`),
  or with a combining mark in place of one letter (`tͦken hunter2`), is not guaranteed to be
  found; see "What it does not find". No table of look-alikes is kept to chase such names,
  since none is ever complete, and none would make free text safe. Use structured logging
  instead: separate fields, and secrets kept out of messages.
- **Hostile input has a cost bound.** All the documents found inside one input, one inside
  another, read at most four times the input's length together. Past that budget, the string
  that holds the next document is hidden whole.
- **Layouts over several lines need nothing special.** A property list writes `<key>` and its
  value on lines of their own, JSON may be spread over lines, and a multipart body may be written
  into a log line. Everything after the first trigger is hidden, so the value is hidden wherever
  it is written; in free text the first `<` of markup is such a trigger, and so is a quote that
  does not close on its line.

### What is recorded and what is never recorded

| Part | Recorded | Never recorded |
| --- | --- | --- |
| URL | Scheme, host, port, path, query parameter names, values of allowlisted query parameters | User info (`user:password@`), the fragment (`#…`), other query values, path segments that look like identifiers or secrets (shown as `:id`), a host that is not a name of ASCII labels or an address or in which a value detector finds something (also in ``NetworkEntry/host``), and the path and query after a host that names a secret (`myapp://pin/4831` is recorded as `myapp://pin`, also in ``NetworkEntry/path``) |
| Headers | Names; values of the allowlisted headers, after the free-text rule | Values of every other header, and always the values of `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, any header whose name contains `token`, `secret`, `key`, `auth`, `session` or `signature`, and values that start with an authentication scheme (`Bearer …`, `Basic …`, `Token …`) |
| JSON, form and multipart bodies | Keys and values, as sent, with hidden values replaced | Values of secret keys and of keys that are not plain ASCII; values named by a field that holds a secret name; file parts and file names of multipart bodies |
| Other bodies | `text/plain` after the free-text rule; a note for everything else | Bodies with an unknown or missing content type, bodies that do not parse, bodies that servers could split into fields differently, and bodies that were cut off or are larger than ``RedactionPolicy/maximumBodySize`` (256 KiB by default) |
| Log messages and error descriptions | The text up to its first trigger, after the value detectors | Everything from the first trigger to the end of the text, and what the value detectors find |

Every hidden value becomes ``RedactionPolicy/replacement`` (`[REDACTED]`), whatever its type and
length.

### Keys: plain ASCII is compared, any other key is hidden

JSON member names, form and query names, multipart field names and header names are read after
their escapes are decoded: JSON escapes by the JSON parser, percent escapes in forms and queries
by the platform's percent decoding. Only a key made of ASCII letters, digits, `_`, `-`, `.` and
spaces is compared with ``RedactionPolicy/secretNames``; the separators are folded away and the
letters lowercased, so `PASS-WORD`, `pass_word` and `pass.word` read as `password`.

**Any other key has its value hidden**, whatever it says: one with a letter outside ASCII, also
one that Unicode normalization would turn into ASCII (`ｐａｓｓｗｏｒｄ`, `ﬁle`), look-alike letters
from other scripts (`pаssword` with a Cyrillic `а`), format characters such as a zero-width
joiner or a soft hyphen, combining marks, other punctuation (`user[password]`, `pass;word`) and
keys in any language that is not written in ASCII (`şifre`, `名前`). There is no look-alike table
to keep up to date. A key that is empty or longer than 256 characters is hidden too.

| Key in the request | Read as | Value |
| --- | --- | --- |
| `X-API-Key` | `xapikey` | hidden (`apikey`) |
| `refresh_token` | `refreshtoken` | hidden (`refreshtoken`) |
| `pass%2577ord` in a form | `password` | hidden |
| `ｐａｓｓｗｏｒｄ` | not plain ASCII | hidden |
| `pаssword` (Cyrillic `а`) | not plain ASCII | hidden |
| `şifre` | not plain ASCII | hidden |
| `created_at` | `createdat` | kept |

A secret word of five or more letters counts anywhere in a key (`dbPassword`, `sessionCount`). A
shorter one (`key`, `pin`, `otp`, `card`, `auth`, `token`) counts as a word of the key or at its
end (`api-key`, `userPin`, `X-Auth-Key`, `apitoken`), so `keyboard`, `spinner` and `author` keep
their values; `pass`, `pw` and `sid` count only as a word (`DB_PASS`, but not `bypass` or
`inside`). A plural `s` counts too (`tokens`). Words start after a separator, between letters and
digits and at a camel-case hump. A name that only describes a secret, such as `token_type` or
`passwordHint`, is hidden as well: telling the two apart would take a list of exceptions. The
default words are in ``RedactionPolicy/defaultSecretNames``; names you add cannot remove them.

Every repetition of a key is read: in `{"token":"a","token":"b"}` both values are hidden.

### Names written as values

Some objects carry a field's name in one member and its value in another: HTTP archives write
`{"name":"X-Api-Key","value":…}`, JSON Patch (RFC 6902) and SCIM PatchOp (RFC 7644) write
`{"op":"replace","path":"/password","value":…}`, forms write `label=Password&value=…`, and fetch
headers and `URLSearchParams` entries are pairs `[["Authorization","…"]]`. The value of a member
that holds a name (`name`, `key`, `field`, `label`, `type`, `header`, `param`, `path` with every
part between `/`, `id`, `k`, `n`) is read by the key rule: when it names a secret, or is not
plain ASCII, or has no letter or digit at all (`Şifre`, `ⓟⓘⓝ`, `🔑`), the members that carry
the value of the pair are hidden whole: `value`, `values`, `val`, `v`, `content`, `data`, `text`,
`input`, `answer`, and any member with one of these as a word (`ParameterValue`, `userData`).
When the name names a secret word, has no letter or digit, is written in symbols or styled letters
(`ⓟ`, `𝐩`, `ｐ`), or is held by a member that only pairs use (`key`, `field`, `label`, `header`,
`param`, `path`, `k`, `n`), every other member is hidden too, apart from the names of pairs and a
JSON Patch or SCIM `op`. A `name`, `id` or `type` written in another script or with punctuation
is as often a person, a place, a product or a media type, so the rest of the record stays:
`{"id":42,"name":"Ayşe Yılmaz","price":12.5}` and `{"type":"image/png","size":12345}` are
stored as they are, and `{"name":"Ayşe","value":"…"}` hides only `value`. The second element of a
two-element array whose first is such a name is hidden, and so is every element of an array after
a string that names a secret (`["password","…"]`). Form fields, query parameters and multipart
parts follow the same rule. `{"label":"Şifre","value":…}` is hidden on purpose.

### Values

When a key matches, its whole value is hidden: a string, a number, an array or an object. Values
of other keys, header values that are kept and free text are scanned for JWTs, `Bearer`
credentials, hex or Base64 strings of 32 or more characters, card numbers that pass the Luhn
check, IBANs that pass the mod-97 check, email addresses (with names and domains in any script:
`ayşe.yılmaz@…`, `张伟@例子.中国`) and the password in `user:password@host`. They are found after
Unicode compatibility decomposition, without marks and invisible characters, and in the same way
on every path: free text, bodies, JSON strings, forms and URLs. The digits of a UUID are not a card
number.

Strings in JSON, form values, query values and multipart text parts are free text; see below. A
string that holds JSON, as GraphQL clients send `variables`, is parsed and redacted by the key
rule.

### Bodies

- **JSON** (`application/json`, `…/json`, `…+json`), in UTF-8, UTF-16 or UTF-32, is read with a
  JSON parser and used only when `JSONSerialization` reads the same tree. It is stored as sent,
  with each hidden value replaced by the string `"[REDACTED]"`, so it is still valid JSON. UTF-16
  and UTF-32 bodies are stored as UTF-8; a body whose bytes are in another encoding than its
  `charset` names is omitted.
- **Forms** (`application/x-www-form-urlencoded`) are split on `&` and `=` and decoded with the
  platform's percent decoding. A form is read only when every server splits it the same way: no
  `;`, no `%` that does not start an escape, and no name spelled two ways (`a.b` and `a_b`,
  `pass%77ord` and `password`, `Note` and `note`).
- **Multipart form data** is read only with a single unquoted boundary of at most 70 characters,
  and only when every `--boundary` in it is a delimiter line after a CRLF, every part header ends
  with CRLF and each part has exactly one `form-data` name. Every part is written again with its
  field name and its type. Another part header keeps its name only when the name is on
  ``RedactionPolicy/allowedHeaders`` and no value detector finds something in it; any other is
  written as `[REDACTED]: [REDACTED]`, and a kept one's value follows the header rule. File parts
  are always replaced by a note, and the file name is never written. Each field is read by its own
  content type (`text/plain` when it has none).
- **`text/plain`** goes through the free-text rule.

Any other content type, a missing content type, a body that does not parse completely, a body that
was cut off at ``NetworkLogger/Configuration/maximumBodySize`` and a body larger than
``RedactionPolicy/maximumBodySize`` (256 KiB by default) are not stored. A note takes their place,
such as `[body omitted: 512 bytes, application/xml]`, and the body is marked
``RedactionOutcome/omitted``.

### Headers

Only the headers on ``RedactionPolicy/allowedHeaders`` keep their values: by default `Accept`,
`Accept-Encoding`, `Accept-Language`, `Cache-Control`, `Content-Encoding`, `Content-Length`,
`Content-Type`, `ETag` and `User-Agent`. A kept value goes through the free-text rule, read on
after ``RedactionPolicy/allowedTextKeys`` and after the parameters these headers are written with
(``RedactionPolicy/headerParameterNames``: `charset`, `boundary`, `q`, `max-age`, …), so
`application/json; charset=utf-8` and `max-age=60` stay as they are. The headers listed in the
table above are hidden even when you allow them, and so is a header whose name is not an ASCII
token.

### URLs

URLs are read with `URLComponents`. The user name, password and fragment are never written. A
query parameter keeps its value only when its name is on
``RedactionPolicy/allowedQueryParameters`` (empty by default); a parameter without `=` is kept
only when allowed, and a query that servers could split differently is written as
`?[REDACTED]`. Path segments that look like identifiers or secrets become `:id`: UUIDs, numbers of
six or more digits, tokens of 16 or more letters and digits, long hex or Base64 strings, JWTs and
segments in which the free-text rule or a detector finds something; the segment after one that
names a secret becomes `:id` too (`/pin/4831`). A path that servers resolve differently from how
it is written is not read: one with a `.` or `..` segment, `%2E` in any case, a `;` anywhere, raw
or as `%3B` in any case (`/cart;jsessionid=…`, `/a;pin/4831`), or an escape escaped again
(`%252E`) is recorded as its scheme, host and port only. `URL.standardized` and servers read
`/pin/./4831` and `/pin/x/../4831` as `/pin/4831` (RFC 3986 §5.2.4), and a `;` starts parameters
for some servers but is part of the segment for others, so the value after the name could not be
told from the text. Parameters after a `;` (matrix parameters) are never parsed. With
`urlDetail: .hostOnly` only the scheme, host and port are written. A host that is neither a name
of ASCII letters, digits and hyphens nor an IP address, or in which a value detector finds
something, is not written either: `https://password=hunter2.example/x` is recorded as
`https://[REDACTED]`. A host that names a secret, by the key rule or as a word, is recorded with
the scheme and port only, as the path after it is its value: with a scheme of the app's own
`URLComponents` reads the first part after `//` as the host, so `myapp://pin/4831` has the host
`pin` and the path `/4831`, and is recorded as `myapp://pin`. A host such as `auth.example.com`
names `auth` too and hides its whole path and query, which over-hides on purpose;
`myapp://callback/x` names no secret and is recorded as it is.

```swift
let url = URL(string: "https://bob:pw@api.example.com/users/12345678/reset?code=x&page=2#y")!
RedactionPolicy.default.redact(url: url)
// https://api.example.com/users/:id/reset?code=[REDACTED]&page=[REDACTED]
RedactionPolicy(allowedQueryParameters: ["page"]).redact(url: url)
// https://api.example.com/users/:id/reset?code=[REDACTED]&page=2
RedactionPolicy.default.redact(url: URL(string: "myapp://pin/4831")!)
// myapp://pin
```

### Free text: one cut point

Log messages, error descriptions, the values of kept headers, `text/plain` bodies and the strings
that structured input holds have no grammar, so the policy does not try to tell where a value in
them ends. It reads the text once and stops at the first trigger. From there, everything to the
end of the text is hidden, the lines below included. Hiding more than the secret is how the rule
is meant to work. Text with no trigger is kept as it is, apart from what the value detectors
find.

```swift
RedactionPolicy.default.redact(text: "status=200 method=GET path=/api/items")
// status=200 method=GET path=/api/items
RedactionPolicy.default.redact(text: "login user=ada status=401 password=hunter2")
// login user=[REDACTED]
RedactionPolicy(allowedTextKeys: ["user"]).redact(text: "login user=ada status=401 password=hunter2")
// login user=ada status=401 password=[REDACTED]
```

The triggers:

- **A key that is not allowed.** In `key=value`, `key: value`, `key = value` and `"key":"value"`
  the text is read on only after a key that is plain ASCII, names no secret and is on
  ``RedactionPolicy/allowedTextKeys``: `status`, `method`, `path`, `duration_ms` and `count` by
  default, and the keys you add. Any other key cuts the text at its value: `x=hunter2` is stored
  as `x=[REDACTED]`, `curl -u bob:hunter2` as `curl -u bob:[REDACTED]`. A `:` between two digits
  is part of a number only when both sides are a whole number: a number before it, and after it
  the two digits of a time (with seconds, a fraction, `Z` or an offset after them) or, after an
  IPv4 address, a port of at most five digits, followed by white space, the end of the text or
  closing punctuation. `12:30`, `12:30:45,123`, `2026-10-19T12:30:00Z` and `10.0.0.1:8080` are
  kept. Any other `:` is a separator, after a key that ends in digits and after a number alike:
  `user1:2345678901` is stored as `user1:[REDACTED]`, `curl -u 42:2345678901` as
  `curl -u 42:[REDACTED]`, `12:34hunter2` as `12:[REDACTED]` and a ratio such as `16:9` as
  `16:[REDACTED]`. JSON in the text follows the same rule member by member, and a two-element
  array by its first string (`["user","bob"]`). A key in quotes (`"x": …`, `'x'=…`, or in
  backticks) follows it too, but the text is cut at its opening quote, so nothing written in the
  quotes shows: `"x":"hunter2"` and `"hunter2":"v"` are stored as `[REDACTED]`, while
  `"status": 200` is kept.
- **A secret name**, with or without a separator, quoted or not: `password=…`, `password …`,
  `"token":"…"`, `export AWS_SECRET_ACCESS_KEY …`, `Bearer: …`. The text is hidden from the value
  after the name. Punctuation inside a word is read as a separator (`pass~word`), two words are
  read together (`pass word`), and one letter that has no ASCII form is read as any letter or,
  between two letters, as none (`passꞏword`). The plural `s` is a letter of the word here too:
  `tokenꞏ` reads as `tokens` and `tokenꞏs` as `tokens`. Each word is also read as its ASCII
  skeleton: every letter that has no ASCII form is left out, however many there are and wherever
  they stand, and the rest is compared with the secret names, the plural `s` included
  (`pıaıssword` reads as `password`, `tokensı` as `tokens` and `tokenꞏꞏ` as `token`). Both
  readings hide more than the secret on purpose: `pın 1234` is read as `pin 1234`.
- **A secret name written as a value.** After a key that holds a name and that the app allows
  (`name`, `key`, `label`, `type`, `id`, …, but never `path`, the route of a request), a name that
  names a secret, is not plain ASCII or is JSON: `name="password"`, `label="Пароль"`,
  `name=["pin"]`.
- **Markup**, which is not parsed. A `<` is a comparison only before an ASCII space, a tab, a line
  break, an ASCII digit, `=` or the end of the text (`a < b`, `<3`, `1<2`). Before anything
  else (a letter of any script, `/`, `!`, `?`, `_`, `:`, other punctuation, a symbol, a digit
  outside ASCII) it starts markup, and the text is cut at it: `<b>`, `</x>`, `<br/>`, `<!--`,
  `<![CDATA[`, `<?xml`, `<!DOCTYPE`, `<#`, `<-`, `<>` and `List<String>`. No tag keeps its text,
  whatever its name and whatever keys you allow: `<status>200</status>`, `</password>`,
  `<key>password</key>` and `<input value="…" name="password">` are stored as `[REDACTED]`.
- **A key that is not plain ASCII**, has no letter or digit, or is missing, before `=` or `:`
  (`pаssword=…` with a Cyrillic `а`, `🔑=…`, `user[name]=…`, `=…`), and the last words of a key
  that, read as one name, name a secret (`pass word=…`, `c v v: …`).
- **A character outside the safe alphabet.** Letters, marks and digits of any script, the ASCII
  space, tab and line breaks (LF, CR), printable ASCII and spaces such as U+00A0 are text. Every
  other character with text after it is a trigger, judged by its own Unicode category:
  punctuation and symbols outside ASCII (`꞉`, `≔`, `→`, `·`, `—`, `’`, `€`), also those that
  compatibility normalization turns into ASCII (`＝`, `：`, `…`, `‥`, `™`, `№`, `ⓟ`), emoji,
  control characters, the line breaks VT, FF, U+0085, U+2028 and U+2029, and private-use or
  unassigned code points. A letter or digit is also judged by the compatibility form the rule
  reads it as: one whose form holds ASCII punctuation or a character outside the alphabet is a
  trigger too (`🄁` is read as `0,`, `⒈` as `1.`, `⑴` as `(1)`, `½` as `1⁄2`), so
  `🄁status=hunter2` is stored as `[REDACTED]`. No list of look-alikes is kept.
- **An escape**, which is never decoded. No list of escape forms is kept: a backslash before
  anything but an ASCII space, a tab, a line break or the end of the text (`\x41`, `\u{41}`,
  `\N{…}`, `\p{L}`, `\8`, `\=`, `\"`, `\\`, a written `\n` and a Windows path such as
  `dir\data`), `%` and two hex digits (`%3D`) or `%u` and four, and `&` before a letter or `#`
  (`&amp`, `&lt;`, `&#61;`, `&#q`, `R&D`). The text is hidden from the escape on:
  `pass%77ord=hunter2` is stored as `pass[REDACTED]`, `status=200&count=3` as
  `status=200[REDACTED]` and `saved logs\app.txt` as `saved logs[REDACTED]`. JSON in the text is
  read by its parser, so its escapes are not escapes of free text.
- **A word longer than 256 characters**, which is no name or value that can be read.
- **A token that cannot be read with certainty**: a word that mixes scripts (`tоken` with a
  Cyrillic `о`; Latin with Japanese, Chinese or Korean is not mixed) or holds an invisible
  character other than a mark, such as a zero-width space; a bracket that does not close; and
  JSON that does not parse. The text is hidden from there. A joiner between two emoji (`👩‍💻`)
  and a skin tone (`👍🏽`) are part of the emoji.
- **A quote that does not close on its line, or quotes that overlap.** There are six kinds of
  quote: `"`, `'` and a backtick, each plain or escaped (`\"`). The backslash of an escaped quote
  is an escape, which cuts the text by itself (`"x \"y\" z"` is stored as `"x [REDACTED]`); the
  escaped kinds pair the quotes of JSON written into the text. A `"` or a backtick opens a quote
  of its kind anywhere, a `'` only at the start of a word (so `don't` and `İstanbul'a` open
  none). A quote of one kind opens inside a quote of another (`'a "b" c'`, `"say 'hi'"`), and a
  quote closes at the next one of its kind on the same line when it is the innermost quote
  open. When a quote of a kind that is open comes while a quote opened after it is still open
  (`'x "y' z"`, `"a \" b"`), the quotes overlap: which quote it closes cannot be told, and the
  text is cut at the earliest quote still open. A quote still open at a line break or at the
  end of the text cuts it there too, at the earliest such quote. So a value or a quoted key
  written over two lines does not show however the quotes before it pair up: `msg "abc` and
  `hunter2" done` on the next line are stored as `msg [REDACTED]`, and `status='x "y' "c` and
  `hunter2" ok` as `status=[REDACTED]`. Quotes that nest and close on their line keep the text
  (`say "it's 'fine'"`); `"a \" b" done` is stored as `[REDACTED]`.

JSON in the text (`{"…`, `[{…`, `["…`, `[[…`) is parsed with a JSON parser and redacted by the
key rule of structured input, as a body is; its strings are free text again, with this rule.
A URL with a scheme and `//` has no island logic: it stays visible only when it is clean, and
any other URL is a trigger that hides the text from where the URL starts. A clean URL is
`scheme://host` with an optional path, written only in the ASCII letters, digits, `.`, `_`, `-`
and `/` after the scheme (so no `?`, `#`, `;`, `%`, `=`, `:`, `@` or `\`, no port, no user info
and no escape), with a host that is a host name or an IPv4 address and neither the host nor a
path segment that names a secret or has no letter or digit. It is followed by white space, a line
break or the end of the text, or by one of `.`, `,`, `!` and `)` and then one of those. Any other
character after it (a quote, `>`, a backtick, `]`, `}`, `?`, `;`, `:` or a second mark) leaves
open where the URL ends, so it cuts the text where the URL starts: `see https://a.example/v1/x), ok`
is stored as `see [REDACTED]` and `see "https://a.example/v1" ok` as `see "[REDACTED]`. A clean URL is recorded as
``RedactionPolicy/redact(url:)`` records it, so an identifier in its path becomes `:id`, and its
last segment is read with the next word, as two words are (`https://x.example/to ken …`).
``RedactionPolicy/allowedQueryParameters`` applies to the URL of a request, not to a URL in text:
`GET https://api.example.com/v1/items?page=2 done` is stored as `GET [REDACTED]` whatever the
allowed parameters. Line breaks are kept as they are written.

| Log message | Stored |
| --- | --- |
| `GET /v1/items status=200 duration_ms=35` | unchanged |
| `password hunter2` | `password [REDACTED]` |
| `login password=hunter2 status=200` and a line below | `login password=[REDACTED]` |
| `GET https://api.example.com/v1/users/12345678 done` | `GET https://api.example.com/v1/users/:id done` |
| `GET https://api.example.com/v1/items?page=2 done` | `GET [REDACTED]` |
| `health http://localhost:8080/health ok` | `health [REDACTED]` |
| `x=hunter2` | `x=[REDACTED]` |
| `pаssword=hunter2` (Cyrillic `а`) | `[REDACTED]` |
| `saved {"status":200,"name":"ada","card":"x"}` | `saved {"status":200,"name":[REDACTED]` |
| `payload {"a": "hunter2"` | `payload [REDACTED]` |
| `msg="unterminated hunter2` | `msg=[REDACTED]` |
| `msg "abc` and `hunter2" done` on the next line | `msg [REDACTED]` |
| `"x":"hunter2"` | `[REDACTED]` |
| `"status": 200, "x": hunter2` | `"status": 200, [REDACTED]` |
| `field name="password" hunter2` | `field name="[REDACTED]` |
| `<key>password</key>` and a `<string>` below | `[REDACTED]` |
| `status=200 <status>200</status> hunter2` | `status=200 [REDACTED]` |
| `if a < b` | unchanged |
| `Payment failed: card declined` | `Payment failed: [REDACTED]` |
| `git clone https://github.com/x/y.git` | unchanged |
| `git clone https://bob:hunter2@github.com/x/y.git` | `git clone [REDACTED]` |
| `GET https://a.example/x?api_key= hunter2` | `GET [REDACTED]` |
| `see https://a.example/cb#access_token= hunter2` | `see [REDACTED]` |
| `see https://a.example/v1/password= hunter2` | `see [REDACTED]` |
| `see https://a.example/v1/x), ok` | `see [REDACTED]` |
| `status=200&count=3` | `status=200[REDACTED]` |
| `saved logs\app.txt` | `saved logs[REDACTED]` |
| `🄁status=hunter2` | `[REDACTED]` |

### Limits keep hostile input from exhausting the stack, the time and the memory

Strings are read as free text, and free text may hold JSON or a URL again, so a reader can find a
document inside a document many times over. One budget bounds that descent, and with it the stack
and the time that a request or a log message can use:

- A body larger than ``RedactionPolicy/maximumBodySize`` is omitted unread: 256 KiB by default,
  at most ``RedactionPolicy/bodySizeLimit`` (16 MiB). Reading a body takes up to about 60 bytes of
  memory for each byte of it, so a larger limit costs memory in proportion.
- A log message is redacted up to ``LogStore/maximumRedactedMessageLength`` (1 MiB of Unicode
  scalars), on the thread that logs it. A longer message is redacted up to its last line break
  before that length, and the rest of it is hidden.
- JSON in a line of free text is parsed when it is at most 65,536 scalars long. Longer JSON cuts
  the text at its first bracket, as JSON that does not parse does.
- JSON objects and arrays may be open ``RedactionPolicy/maximumJSONDepth`` (64) levels deep in
  all, counting the levels of every document a JSON string is in.
- At most ``RedactionPolicy/maximumNestedDocuments`` (4) documents are read one inside another. A
  body, JSON in a line or a string, a URL and a multipart part each count.
- The documents found inside one input read at most four times its length, all together.
- A URL whose path has more than ``RedactionPolicy/maximumPathSegments`` (64) segments, or whose
  query has more than ``RedactionPolicy/maximumQueryParameters`` (128) parameters, is recorded
  with its scheme, host and port only. A multipart body has at most 1,000 parts.

JSON past a limit is not read: a body is omitted, and a string or other text inside a document that
holds such JSON is hidden whole. The free-text rule reads a text once and keeps only its position,
the cut, the quotes open on the line (six at most, one of each kind), the first quote that does not
close on its line or overlaps another, and the last closing bracket of each kind.
The package's tests run every limit on a thread with 512 KiB of stack, and in a release build
(`swift test -c release`) they check that a megabyte of text, nested input or a body takes less
than a second of CPU time, and, on macOS, that a megabyte of free text takes less than 16 MB of
memory beyond the input.

### Change the policy

Add your own secret names and allow the query parameters and headers you want to read:

```swift
NetworkLogger.shared.configuration.redaction = RedactionPolicy(
    additionalSecretNames: ["license_number"],
    allowedHeaders: RedactionPolicy.defaultAllowedHeaders + ["X-Request-ID"],
    allowedQueryParameters: ["page", "sort"]
)
LogStore.shared.configuration.redaction = RedactionPolicy(
    additionalSecretNames: ["license_number"],
    allowedTextKeys: ["user", "request_id"]
)
```

An added name of five or more letters counts anywhere in a key, a shorter one as a word or at the
end. A secret name stays hidden when it is on an allowlist. `allowedTextKeys` adds the keys your
log lines write to `status`, `method`, `path`, `duration_ms` and `count`, so free text is read on
after them; a key that names a secret or is not plain ASCII is never allowed. Use `urlDetail: .hostOnly` to record
only the scheme, host and port of each URL.

Use ``RedactionPolicy/disabled`` only with test servers and test accounts.

### What it does not find

- A secret with no label, or a label not followed by `=` or `:`: `curl -u bob hunter2`,
  `login -p hunter2` and `{bob hunter2}` are stored as they are, unless a detector finds the
  value. With a separator, a key that is not on the allowed text keys hides its value in free text
  (`creds=hunter2` is stored as `creds=[REDACTED]`). In a body, a plain ASCII key that is not a
  secret name keeps its value (`{"creds":"hunter2"}`); add the name with `additionalSecretNames`.
- The value of an allowed key: `status=hunter2` keeps `hunter2`.
- A secret name in free text written without a separator with two or more of its letters
  replaced by letters that have no ASCII form: `pɑsswoʀd hunter2` is stored as it is. Such letters
  put in beside the name's own are left out of its skeleton, so `pıaıssword hunter2` is hidden.
  With a separator (`pɑsswoʀd=hunter2`) the value is hidden. A secret word in another language, such as
  `пароль hunter2`, is not one either.
- A secret name in free text written without a separator with a combining mark in place of one
  of its letters: `tͦken hunter2` (a `t`, then U+0366 where the `o` belongs) is stored as it
  is. Only a letter put in place of a letter is read as any letter. With a separator
  (`tͦken=hunter2`) the key is not plain ASCII and the value is hidden.
- A value written before its name, with no key before it: `hunter2 is my password` is stored as
  it is.
- A card number grouped with `+` or `.` (`4111+1111+1111+1111`).
- A short secret in a path segment, such as `/reset/abc123`; only identifiers, tokens of the shapes
  listed above and segments in which a rule finds something become `:id`. In free text the same
  holds for a clean URL (`see https://x.example/reset/abc123`).
- Beside a `name`, `id` or `type` written in another script or with punctuation, the fields that
  do not carry a value: `{"name":"Şifre","x":"hunter2"}` keeps `x`, since such a name is as often a
  person, a place or a product (see "Names written as values").

Where it cannot tell, it hides more than it has to: everything after the first trigger, the lines
below included (`Payment failed: card declined` keeps only `Payment failed:`, and
`заказ №42 отправлен` only `заказ`), the rest of a text from its first tag (`Loaded
Array<Item> in 3 ms` keeps only `Loaded Array`), the rest of a text after a quote that does not
close on its line or a bracket that does not close (`Order 1234 shipped :(`), the rest of a text
after a URL that is not clean or that two marks follow (`health http://localhost:8080/health ok`
keeps only `health`), the rest of a text from a backslash or an `&` before a letter
(`R&D team` keeps only `R`), and the value of a name that only describes a secret
(`token_type`).

## See Also

- ``RedactionPolicy``
- ``CapturedBody``
