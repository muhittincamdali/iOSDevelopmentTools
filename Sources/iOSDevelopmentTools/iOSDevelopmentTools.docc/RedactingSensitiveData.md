# Redacting sensitive data

Understand what is recorded, what is never recorded, and how to change it.

## Overview

Every request that reaches a ``NetworkLogger`` and every message logged to a ``LogStore`` goes
through a ``RedactionPolicy`` first. The console, ``HTTPArchive`` files,
``NetworkEntry/curlCommand()`` and screenshots of the console only ever see the redacted copy.
Your app still sends and receives everything unchanged.

The policy follows one rule: what it does not fully understand is hidden, never shown. Bodies,
URLs and headers are read with real parsers, a key that is not plain ASCII is hidden, and a body
that cannot be parsed is left out. Free text such as a plain-text body has one cut point: from the
first sign of a secret, everything to the end of the text is hidden.

These are the redaction rules this package shares with iOSSecurityTools and
iOS-Networking-Architecture-Pro, written down as one specification and tested with one shared
corpus of review probes. Release 2.1.0 followed an earlier generation of that specification; 2.1.1
follows its current revision (2.1-r2) in every rule this package applies, and every input that
2.1.0 read differently is kept as a test.

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
  XML and property list bodies are not parsed, so they are left out whole.
- **Free text is a best effort.** A log line has no grammar, so the policy does not try to tell
  where a value ends. After the first trigger, such as a secret name, everything to the end of
  the text is hidden, the lines below included. One rule reads disguised letters: a letter, mark
  or number with no ASCII form inside an ASCII word stands for any one letter or for none, so
  `tͦken hunter2` (U+0366 after the `t`), `passw〇rd hunter2` and `piꞏn 1234` are found. A secret
  name written without a separator and disguised on purpose by writing two or more of its letters
  as look-alikes (`pɑsswoʀd hunter2`) is not guaranteed to be found; see "What it does not find".
  No table of look-alikes is kept to chase such names, since none is ever complete, and none
  would make free text safe. Use structured logging instead: separate fields, and secrets kept
  out of messages.
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
| URL | Scheme, host, port, path, query parameter names, values of allowlisted query parameters | User info (`user:password@`), the fragment (`#…`), other query values, path segments that look like identifiers or secrets (shown as `:id`), the segment after one that names a secret or is not plain ASCII (`/caf%C3%A9/menu` is recorded as `/caf%C3%A9/:id`), a host that is not a name of ASCII labels or an address or in which a value detector finds something, and a host that names a secret, with its port, path and query (`myapp://pin/4831` is recorded as `myapp://[REDACTED]`; also in ``NetworkEntry/host`` and ``NetworkEntry/path``) |
| Headers | Names; values of the allowlisted headers, after the free-text rule | Values of every other header, and always the values of `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, any header whose name contains `token`, `secret`, `key`, `auth`, `session` or `signature`, and values that start with an authentication scheme (`Bearer …`, `Basic …`, `Token …`) |
| JSON, form and multipart bodies | Keys and member names, and values, as sent, with hidden values replaced | Values of secret keys and of keys that are not plain ASCII; values beside a field that holds a secret name or a name that is not plain ASCII, and beside a label that names a secret or is written outside ASCII (`{"title":"ΡΙΝ:","value":…}`); file parts and file names of multipart bodies, and the values of part headers other than `Content-Length` and `Content-Transfer-Encoding` |
| Other bodies | `text/plain` after the free-text rule; a note for everything else | Bodies with an unknown or missing content type (XML, property lists, HTML), bodies that do not parse, bodies that servers could split into fields differently, and bodies that were cut off at ``NetworkLogger/Configuration/maximumBodySize`` or are larger than ``RedactionPolicy/maximumBodySize`` (256 KiB by default) |
| Log messages, error descriptions and other free text (kept header values, `text/plain` bodies, strings in JSON and forms) | The text up to its first trigger, after the value detectors | Everything from the first trigger to the end of the text, and what the value detectors find |

Every hidden value becomes ``RedactionPolicy/replacement`` (`[REDACTED]`), whatever its type and
length. What a value detector finds becomes `[REDACTED]` too: no part of a card number or an
address is shown.

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
to keep up to date. A key that is empty or longer than 256 characters is hidden too. One function
makes this decision for every path: JSON, forms, queries, multipart parts, headers and the names
written as values described below.

| Key in the request | Read as | Value |
| --- | --- | --- |
| `X-API-Key` | `xapikey` | hidden (`apikey`) |
| `refresh_token` | `refreshtoken` | hidden (`refreshtoken`) |
| `pass%2577ord` in a form | `password` | hidden |
| `ｐａｓｓｗｏｒｄ` | not plain ASCII | hidden |
| `pаssword` (Cyrillic `а`) | not plain ASCII | hidden |
| `şifre` | not plain ASCII | hidden |
| `created_at` | `createdat` | kept |

A secret word of five or more letters counts anywhere in a key: `token`, `secret`, `bearer` and
`session` as well as the longer ones (`dbPassword`, `apitoken`, `secretanswer`, `tokenValue`,
`session_data`), so `secretary`, `tokenizer` and `session_start` are hidden too. A shorter one
(`key`, `pin`, `otp`, `cvv`, `card`, `auth`, `iban`) counts as a word of the key or at its end
(`api-key`, `userPin`, `X-Auth-Key`, `licensekey`), so `keyboard`, `spinner` and `author` keep
their values; `pass`, `pw` and `sid` count only as a word (`DB_PASS`, but not `bypass`,
`inside` or `userpw`). A plural `s` counts too (`tokens`). Words start after a separator, between
letters and digits and at a camel-case hump. A name that only describes a secret, such as
`token_type` or `passwordHint`, is hidden as well: telling the two apart would take a list of
exceptions. The default words are in ``RedactionPolicy/defaultSecretNames``; names you add cannot
remove them. The allowlists follow the same rule: a name that holds a secret word where it counts
(`secretanswer`) is never allowed.

Every repetition of a key is read: in `{"token":"a","token":"b"}` both values are hidden.

### Names written as values

Some objects carry a field's name in one member and its value in another: HTTP archives write
`{"name":"X-Api-Key","value":…}`, JSON Patch (RFC 6902) and SCIM PatchOp (RFC 7644) write
`{"op":"replace","path":"/password","value":…}`, forms write `label=Password&value=…`, and fetch
headers and `URLSearchParams` entries are pairs `[["Authorization","…"]]`. The value of a member
that holds a name (`name`, `key`, `field`, `label`, `type`, `header`, `param`, `path` with every
part between `/`, `id`, `k`, `n`, or a member whose own name is not plain ASCII) is read by the
key rule, with the same function as a key: when it names a secret, is not plain ASCII
(`[a-z0-9]` and `_`, `-`, `.` and spaces), has no letter or digit at all (`ⓟⓘⓝ`, `🔑`, an empty
name), holds a line break or another control character, or is an array or an object, the values
of the other members of the object are hidden whole, apart from the names of pairs and a JSON
Patch or SCIM `op`. An object has no order, so what belongs to the name cannot be told.

This hides on purpose. `{"label":"Şifre","value":…}` is hidden, and so is every record whose
`name`, `id` or `type` is written outside plain ASCII: `{"id":42,"name":"Ayşe Yılmaz","price":12.5}`
is stored as `{"id":"[REDACTED]","name":"Ayşe Yılmaz","price":"[REDACTED]"}`, and
`{"type":"image/png","size":12345}` as `{"type":"image/png","size":"[REDACTED]"}`. The name itself
stays readable. A record with plain ASCII names (`{"id":42,"name":"Ayse","price":12.5}`) keeps
everything.

The second element of a two-element array whose first is such a name is hidden whole
(`[["Authorization","…"]]`), and so is every element of an array after a string that names a
secret (`["password","…"]`). Form fields, query parameters and multipart parts follow the same
rule. In a member that does not hold a name (`question`, `prompt`, `title`, `setting`,
`ParameterKey`, `Tag`), a string names a secret when its words name one
(`{"ParameterKey":"DbPassword","ParameterValue":…}`), also with its line breaks read as spaces or
its character references decoded. An apostrophe between letters is part of a word, as it is in
free text (`What's your PIN?`, `Kartın CVV'si`). A string with a `:`, `=`, `,`, `;`, a quote or a
bracket in it is a sentence, and a secret word in it names a secret when no value is written after
it, as in a label: `{"question":"Enter PIN (4 digits)","answer":…}`, `PIN, 4 digits`,
`PIN: required`, `"Password" field`, `{"Tag":"aws:secret-access-key","Value":…}` and
`api_token[0]` hide the value beside them. A secret word with `=` right after it, or white space
and a word, is the key of a value the sentence carries itself (`pin=1234`, `Error: token expired`,
`login with api_key=abc123`): the free-text rule hides that value in the string, and the members
beside it stay. A JSON object or array written into a string is read as a document of its own,
not as a name.

A label is a key written as a value, so a label written outside printable ASCII hides the value
beside it whatever it says, as a key that is not plain ASCII does: words with a character outside
printable ASCII in them, then a `:` or an `=` (also as written in another form, `：`, `﹕`, `＝`,
`⩴`) or a punctuation mark, a bracket, a quote mark or a math or modifier symbol with no ASCII
form (`꞉`, `∶`, `·`, `→`, `」`, `»`, `“`), and then anything but a letter or a digit: white
space, a line break, the end of the string or a mark (`Пароль:*`, `ΡΙΝ:)`).
`{"title":"ΡΙΝ:","value":…}`, `{"prompt":"Enter your pɑsswoʀd:","answer":…}`,
`{"title":"Şifre: zorunlu","value":…}`, `{"title":"【暗証番号】","value":…}` and
`["note","«Пароль»","…"]` hide the value, in forms, multipart bodies and allowed query
parameters too. This hides on purpose: `{"title":"Цена: 100","id":7}` and
`{"title":"«Привет»","id":7}` are stored with `id` hidden. A sentence end (`。`), a dash and `…`
are not separators, a separator with a letter or a digit after it is part of the words
(`Saat 12:30`), and a string with no such label keeps what is beside it
(`{"title":"Ayşe Yılmaz","id":7}`, `{"title":"Name: Ayşe","id":7}`).

A string is read at any length, in one pass, its words longer than 256 characters too: the label
at the end of a long description (`{"question":"<a paragraph> What is your PIN?","answer":…}`)
hides the value beside it, and so does a secret word glued to a long word (`…xxxxPIN:`). A string
of control characters and white space alone hides it at any length.

### Values

When a key matches, its whole value is hidden: a string, a number, an array or an object. Values
of other keys, header values that are kept and free text are scanned for JWTs, `Bearer`
credentials, hex or Base64 strings of 32 or more characters, card numbers that pass the Luhn
check, IBANs that pass the mod-97 check, email addresses (with names and domains in any script:
`ayşe.yılmaz@…`, `张伟@例子.中国`) and the password in `user:password@host`. They are found after
Unicode compatibility decomposition, without marks and invisible characters, and in the same way
on every path: free text, bodies, JSON strings, forms and URLs. A UUID is kept unless its digit
groups read as a card number that passes the Luhn check, which is hidden as any such run of digits
is. The detectors read across a vertical tab, a form feed, U+0085, U+2028 and U+2029: as white
space between the groups of a card number or an IBAN and after `Bearer`, and as nothing inside an
email address, a JWT and a long token. Each of these separators cuts free text, so a finding
written across one is hidden from its start: `paid 4111 1111 1111`, U+2028 and `1111` is stored
as `paid [REDACTED]`. An address with such a separator right after it is still found and hidden
from its start: when the domain read across the separator does not end in a top-level domain
(`alice@example.com`, a vertical tab and `1`), the address ends at the separator. A line feed or a
carriage return written as such ends a finding, as it ends a line.

A JSON number is read as the decimal it stands for. A number with an exponent, as Jackson and
Gson write a `double` (`4.111111111111111E15`) or as any writer may (`4111111111111111e0`), is
read written out (`4111111111111111`), and when a detector finds something there the whole number
becomes `"[REDACTED]"`. Written out, a number with 32 or more digits in a row (`1e31`, `1e-32`) is
a long token, as it is when written plainly, and is hidden too. A number without an exponent
keeps what is not found: `-4111111111111111` is stored as `"-[REDACTED]"`.

Strings in JSON, form values, query values and multipart text parts are free text; see below. A
string that holds JSON, as GraphQL clients send `variables`, is parsed and redacted by the key
rule.

### Bodies

- **JSON** (`application/json`, `…/json`, `…+json`), in UTF-8, UTF-16 or UTF-32, is read with a
  JSON parser and used only when `JSONSerialization` reads the same tree. It is stored as sent,
  with each hidden value replaced by the string `"[REDACTED]"`, so it is still valid JSON. Member
  names are shown and the values under them hidden, so a secret written into the name of a member
  (`{"password hunter2":…}`) shows; in free text such a name is cut where it starts. UTF-16 and
  UTF-32 bodies are stored as UTF-8; a body whose bytes are in another encoding than its `charset`
  names is omitted. A byte order mark at the start of a body is left out before it is read, the
  same way on every OS version, and a JSON body with a second one is omitted, as JSON allows none.
- **Forms** (`application/x-www-form-urlencoded`) are split on `&` and `=` and decoded with the
  platform's percent decoding. A form is read only when every server splits it the same way: no
  `;`, no `%` that does not start an escape, and no name spelled two ways (`a.b` and `a_b`,
  `pass%77ord` and `password`, `Note` and `note`).
- **Multipart form data** is read only with a single unquoted boundary of at most 70 characters,
  and only when every `--boundary` in it is a delimiter line after a CRLF and every part header
  ends with CRLF. Every part is written again with its field name and its type, and the body ends
  at its closing delimiter. A part header name is a key of the part, so of the other part headers
  only `Content-Length` and `Content-Transfer-Encoding` are written with their value, and only in
  their form, which is not read as free text: a length of ASCII digits in which the value
  detectors find nothing (`Content-Length: 12`, but not a card number), and one of `7bit`,
  `8bit`, `binary`, `base64` and `quoted-printable` in lowercase (`BASE64` is written as
  `base64`). Any other value of theirs is written as `[REDACTED]`: `Content-Length: pin-4831`,
  `Content-Length: 12 hunter2` and `Content-Transfer-Encoding: hunter2` keep only their name, and
  the content of a part whose transfer encoding is hidden is omitted. `Content-ID`,
  `Content-Description`, `Content-Language`, `Content-Location` and `Content-Encoding` are written
  with `[REDACTED]` as their value, and any other is written as `[REDACTED]: [REDACTED]`
  (`User-Agent: …` and `X-4111111111111111: 1` alike).
  ``RedactionPolicy/allowedHeaders`` does not apply to part headers. File parts are always
  replaced by a note, and the file name is never written. Each field is read by its own content
  type (`text/plain` when it has none).
- **`text/plain`** goes through the free-text rule.

Any other content type (XML, property lists, HTML, binary data), a missing content type, a body
that does not parse completely and a body larger than ``RedactionPolicy/maximumBodySize`` (256 KiB by
default) are not stored, and neither is a body that was cut off at
``NetworkLogger/Configuration/maximumBodySize``. A note takes their place, such as
`[body omitted: 512 bytes, application/xml]` or `[body omitted: 22 bytes, no content type]`, and
the body is marked ``RedactionOutcome/omitted``.

### Headers

Only the request and response headers on ``RedactionPolicy/allowedHeaders`` keep their values:
by default `Accept`, `Accept-Encoding`, `Accept-Language`, `Cache-Control`, `Content-Encoding`,
`Content-Length`, `Content-Type`, `ETag` and `User-Agent`. Multipart part headers follow their
own list, described under Bodies above. A kept value goes through the free-text rule, read on
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
names a secret becomes `:id` too (`/pin/4831`). A segment is read by the key rule, as the name of
a field is: one that, decoded, is not plain ASCII is a label too, so the segment after it becomes
`:id` (`/caf%C3%A9/menu`, `/t%CD%A6ken/4831`, `/%C5%9Eifre/4831` and `/a+b/c` keep only their
first segment). This over-hides on purpose.

A path that servers resolve differently from how it is written is not read: one with a `.` or
`..` segment, a `;` anywhere (`/cart;jsessionid=…`, `/a;pin/4831`), or an escaped `.`, `/`, `\`,
`;` or `%` (`%2E`, `%2F`, `%5C`, `%3B`, `%25`, in either case) is recorded as its scheme, host and
port only. `URL.standardized` and servers read `/pin/./4831` and `/pin/x/../4831` as `/pin/4831`
(RFC 3986 §5.2.4), and a `;` starts parameters for some servers but is part of the segment for
others, so the value after the name could not be told from the text. Parameters after a `;`
(matrix parameters) are never parsed. With `urlDetail: .hostOnly` only the scheme, host and port
are written, and the host follows the rules below.

The host is a key of the URL. A host that is neither a name of ASCII letters, digits and hyphens
nor an IP address, or in which a value detector finds something, is not written:
`https://password=hunter2.example/x` is recorded as `https://[REDACTED]`. Nor is a host that
names a secret, by the key rule or as a word, and nothing after it is written either, as its value
may be in the host itself (`myapp://password.hunter2`, `https://pin-4831.example.com`), in the
port (`myapp://pin:4831`) or in the path: with a scheme of the app's own `URLComponents` reads the
first part after `//` as the host, so `myapp://pin/4831` has the host `pin`. Each of them is
recorded as the scheme and `[REDACTED]` (`myapp://[REDACTED]`). A host such as
`auth.example.com` names `auth` too and is hidden the same way, which over-hides on purpose. A
URL that `URLComponents` cannot parse, or that has no scheme and host
(`mailto:ada@example.com`), is recorded as ``RedactionPolicy/unparsedURL``.

```swift
let url = URL(string: "https://bob:pw@api.example.com/users/12345678/reset?code=x&page=2#y")!
RedactionPolicy.default.redact(url: url)
// https://api.example.com/users/:id/reset?code=[REDACTED]&page=[REDACTED]
RedactionPolicy(allowedQueryParameters: ["page"]).redact(url: url)
// https://api.example.com/users/:id/reset?code=[REDACTED]&page=2
RedactionPolicy.default.redact(url: URL(string: "myapp://pin/4831")!)
// myapp://[REDACTED]
RedactionPolicy.default.redact(url: URL(string: "myapp://password.hunter2")!)
// myapp://[REDACTED]
```

### Free text: one cut point

Log messages, error descriptions, the values of kept headers, `text/plain` bodies and the strings
that structured input holds have no grammar, so the policy does not try to tell where a value in
them ends. It reads the text
once and stops at the first trigger. From there, everything to the end of the text is hidden, the
lines below included. Hiding more than the secret is how the rule is meant to work.
``RedactionPolicy/redact(text:)`` applies the rule to text of your own. Text with no trigger is kept as
it is, apart from what the value detectors find.

```swift
RedactionPolicy.default.redact(text: "status=200 method=GET path=/api/items")
// status=200 method=GET path=/api/items
RedactionPolicy.default.redact(text: "login user=ada status=401 password=hunter2")
// login user=[REDACTED]
RedactionPolicy(allowedTextKeys: ["user"]).redact(text: "login user=ada status=401 password=hunter2")
// login user=ada status=401 password=[REDACTED]
```

The triggers, none of them kept as a list of variants:

- **A key that is not allowed.** In `key=value`, `key: value`, `key = value` and `"key":"value"`
  the text is read on only after a key that is plain ASCII without a space, names no secret and
  is on ``RedactionPolicy/allowedTextKeys``: `status`, `method`, `path`, `duration_ms` and `count` by
  default, and the keys you add. Any other key cuts the text at its value: `x=hunter2` is stored
  as `x=[REDACTED]`, `curl -u bob:hunter2` as `curl -u bob:[REDACTED]`. A key in quotes of any
  kind (`"x": …`, `'x'=…`, or in backticks) that is not allowed cuts the text at its opening
  quote, so nothing written in the quotes shows: `"x":"hunter2"` and `"hunter2":"v"` are stored as
  `[REDACTED]`, while `"status": 200` is kept. JSON in the text follows the same rule member by
  member, a member name that is not allowed cutting it at its opening quote, and the first string
  of a two-element array is a key too (`["user","bob"]` is stored as `[[REDACTED]`).
- **A `:` between digits** is part of a number only when both sides have the whole shape of one —
  a time (`12:30:45`, `10:30:00.250+03:00`), a date and time (`2026-10-19T12:30:45Z`), an address
  and its port (`10.0.0.1:8080`) or a line and column (`42:10`) — and a word ends after it. A
  word of another shape before the `:` (`1.234:56`, `1-1-1:2345`), a letter after the digits
  (`12:34hunter2` is stored as `12:[REDACTED]`) or right after the punctuation that follows them
  (`12:30,hunter2`), five or more digits right after the `:` (`1:482913`) and a key that ends in
  digits (`user1:2345`) make it a separator.
- **A secret name**, with or without a separator, quoted or not: `password=…`, `password …`,
  `"token":"…"`, `export AWS_SECRET_ACCESS_KEY …`. The text is hidden from the value after the
  name. Punctuation inside a word is read as a separator (`pass~word`), two words are read
  together (`pass word`), and each word is compared by its ASCII skeleton: a letter, mark or
  number with no ASCII form counts as nothing or as any one letter (`piꞏn`, `tokeın`, `tokenꞏs`,
  `pɑssword`, `user_pın`, `passw〇rd`). The skeleton hides more than the secret on purpose:
  Turkish `yapın` reads as `pin`.
- **A secret name written as a value.** After an allowed key that holds a name (`id=`, `type=`,
  … but never `path=`, the route of a request), a name that names a secret or is not plain ASCII
  cuts the text after it, as in JSON (`type="Пароль"`), and so does JSON there.
- **Markup**, which is not parsed. A `<` is a comparison only before an ASCII space, a tab, a line
  break, an ASCII digit, `=` or the end of the text (`a < b`, `<3`, `1<2`). Before anything
  else it starts markup, and the text is cut at it: `<b>`, `</x>`, `<br/>`, `<!--`,
  `<![CDATA[`, `<?xml`, `<०>` and `List<String>`. No tag keeps its text, whatever its name and
  whatever keys you allow: `<status>200</status>`, `</password>`, `<key>password</key>` and
  `<input value="…" name="password">` are stored as `[REDACTED]`.
- **A character outside the safe alphabet.** Letters, marks and digits of any script, the ASCII
  space, tab and line breaks, and printable ASCII are text. Every other character cuts the text
  where it stands, judged by its own Unicode category: punctuation, symbols and spaces outside
  ASCII (`꞉`, `≔`, `→`, `·`, `＝`, `—`, `€`, U+00A0, U+3000), emoji, control and format
  characters, the line breaks VT, FF, U+0085, U+2028 and U+2029, and every default-ignorable code
  point. A letter or number is also judged by its compatibility form, which is what the text is
  read as: one whose form is not in the alphabet cuts the text too (`🄁` is `0,`, `⑴` is `(1)`,
  `½` is `1⁄2`, `ﷺ` holds spaces), so `🄁status=hunter2` is stored as `[REDACTED]`. A modifier
  letter (`ː`, `ー`) is text only after a letter or digit outside ASCII, as in Japanese or Thai.
- **An escape**, which is never decoded and cuts the text at the start of the word it is in. No
  list of forms is kept: a backslash before anything but an ASCII space, a tab, a line break or
  the end of the text (`\x41`, `\u{41}`, `\N{…}`, `\p{L}`, `\8`, `\"`, `\\`, a written `\n` and a
  Windows path such as `dir\data`), `%` and two hex digits (`%3D`) or `%u` and four, `&#` before
  anything, and `&` before a letter (`&amp`, `&lt;`, `R&D`) unless it starts the name of a field
  before `=` (`status=200&count=3` is kept; the key rule reads `count`). `pass%77ord=hunter2` is
  stored as `[REDACTED]` and `saved logs\app.txt` as `saved [REDACTED]`. JSON in the text is read
  by its parser; a backslash in the line is still a backslash of free text.
- **A word longer than 256 characters**, which is no name or value that can be read.
- **A token that cannot be read with certainty**: a word that mixes scripts (`tоken` with a
  Cyrillic `о`; `120µs` too, as the micro sign reads as a Greek letter), a bracket that does not
  close before the text ends (the text is cut after it), and JSON that does not parse or is
  longer than 65,536 scalars (the text is cut at its first bracket).
- **A quote that does not close on its line, or quotes that overlap.** A `"` or a backtick opens
  a quote anywhere, a `'` only at the start of a word (so `don't` and `İstanbul'a` open none),
  each plain or escaped (`\"`). A quote of another kind opens inside a quote (`'a "b" c'`,
  `say "it's 'fine'"`), and a quote closes at the next one of its kind when it is the innermost
  quote open. When a quote of a kind that is open comes while a quote opened after it is still
  open (`'x "y' z"`, `"a \" b"`), the quotes overlap: which quote it closes cannot be told, and
  the text is cut at the earliest quote still open. A quote still open at a line break, or before
  the first character outside the safe alphabet, cuts the text at the earliest quote still open,
  so a value or a quoted key written over two lines never shows: `msg "abc` and `hunter2" done` on
  the next line are stored as `msg [REDACTED]`, and `status='x "y' "c` and `hunter2" ok` as
  `status=[REDACTED]`.
- **A URL that is not clean.** A URL in free text has no island logic: it stays visible only when
  it is `scheme://host` with an optional path of ASCII letters, digits, `.`, `_`, `-` and `/` (no
  `?`, `#`, `;`, `%`, `=`, `:`, `@` or `\`), its host and segments name no secret, and white
  space, a line break, the end of the text or one `.`, `,`, `!` or `)` before one of those follows
  it. Any other URL cuts the text where it starts. A clean URL is recorded as
  ``RedactionPolicy/redact(url:)`` records it, so an identifier in its path becomes `:id`.
  ``RedactionPolicy/allowedQueryParameters`` applies to the URL of a request, not to a URL in text.

| Text | Stored |
| --- | --- |
| `GET /v1/items status=200 duration_ms=35` | unchanged |
| `password hunter2` | `password [REDACTED]` |
| `login password=hunter2 status=200` and a line below | `login password=[REDACTED]` |
| `GET https://api.example.com/v1/users/12345678 done` | `GET https://api.example.com/v1/users/:id done` |
| `GET https://api.example.com/v1/items?page=2 done` | `GET [REDACTED]` |
| `x=hunter2` | `x=[REDACTED]` |
| `saved {"status":200,"name":"ada","card":"x"}` | `saved {"status":200,[REDACTED]` |
| `payload {"a": "hunter2"` | `payload [REDACTED]` |
| `msg="unterminated hunter2` | `msg=[REDACTED]` |
| `"x":"hunter2"` | `[REDACTED]` |
| `"status": 200, "x": hunter2` | `"status": 200, [REDACTED]` |
| `field name="password" hunter2` | `field name=[REDACTED]` |
| `<key>password</key>` and a `<string>` below | `[REDACTED]` |
| `status=200 <status>200</status> hunter2` | `status=200 [REDACTED]` |
| `if a < b` | unchanged |
| `Payment failed: card declined` | `Payment failed: [REDACTED]` |
| `git clone https://bob:hunter2@github.com/x/y.git` | `git clone [REDACTED]` |
| `status=200&count=3` | unchanged |
| `saved logs\app.txt` | `saved [REDACTED]` |
| `🄁status=hunter2` | `[REDACTED]` |

### Limits keep hostile input from exhausting the stack, the time and the memory

Strings are read as free text, and free text may hold JSON or a URL again, so a reader can find a
document inside a document many times over. One budget bounds that descent, and with it the stack
and the time that a request or a log message can use:

- A body larger than ``RedactionPolicy/maximumBodySize`` is omitted unread: 256 KiB by default,
  at most ``RedactionPolicy/bodySizeLimit`` (16 MiB). Reading a body takes memory in proportion to its
  size: a body of 256 KiB in any shape takes less than 16 MB more.
- A log message is redacted up to ``LogStore/maximumRedactedMessageLength`` (1 MiB of Unicode
  scalars), on the thread that logs it. A longer message is redacted up to its last line break
  before that length, and the rest of it is hidden.
- A text longer than 2^28 − 1 Unicode scalars (256 Mi) is hidden whole.
- JSON in a line of free text is parsed when it is at most 65,536 scalars long. Longer JSON cuts
  the text at its first bracket, as JSON that does not parse does.
- JSON objects and arrays may be open ``RedactionPolicy/maximumJSONDepth`` (64) levels deep in
  all, counting the levels of every document a JSON string is in.
- At most ``RedactionPolicy/maximumNestedDocuments`` (4) documents are read one inside another. A
  body, JSON in a line or a string, a URL and a multipart part each count.
- The documents found inside one input read at most four times its length, all together.
- What a character outside ASCII is read as is kept in one table for the whole text, body, URL
  or list of headers, with every field, part, segment and header in it. The table has a fixed
  number of slots, at most 8,192 (192 KiB), and never grows; its slots are chosen with a hash
  seeded at random in every process, so no text can choose characters that meet in one.
- A URL whose path has more than ``RedactionPolicy/maximumPathSegments`` (64) segments, or whose
  query has more than ``RedactionPolicy/maximumQueryParameters`` (128) parameters, is recorded
  with its scheme, host and port only. A multipart body has at most 1,000 parts.
- Header fields are read from a response, sorted and redacted with one table of readings, in time
  linear in their number. A server can send tens of thousands of them, and `URLSession` accepts
  them.

JSON past a limit is not read: a body is omitted, and a string or other text inside a document that
holds such JSON is hidden whole. Free text is read in one pass that keeps a fixed number of
positions. The package's tests run every limit on a thread with 512 KiB of stack, and in a release
build (`swift test -c release`) they check that a megabyte of text, nested input or a body in any
shape takes less than a second, that 32,000 response header fields take less than a second per
megabyte, and, on macOS, that a megabyte of free text takes less than 16 MB
of memory beyond the input, also when it is dense with findings or every character of it is a
different one outside ASCII.

### Change the policy

Add your own secret names and allow the query parameters, headers and text keys you want to read:

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

An added name of five or more letters counts anywhere in a key, a shorter one as a word of it or at
its end, and it is read wherever the default names are: in free text (`license_number 12345` is
stored as `license_number [REDACTED]`), in names written as values
(`{"name":"license_number","value":…}`), in URL hosts and path segments and in query parameters.
No allowlist holds a key with a secret name or an added name. `allowedTextKeys` adds the keys your
log lines write to `status`, `method`, `path`, `duration_ms` and `count`, so free text is read on
after them; a key that names a secret or is not plain ASCII is never allowed. Use
`urlDetail: .hostOnly` to record only the scheme, host and port of each URL.

Use ``RedactionPolicy/disabled`` only with test servers and test accounts.

### What it does not find

- A secret with no label, or a label not followed by `=` or `:`: `curl -u bob hunter2`,
  `login -p hunter2` and `{bob hunter2}` are stored as they are, unless a detector finds the
  value. With a separator, a key that is not on the allowed text keys hides its value in free text
  (`creds=hunter2` is stored as `creds=[REDACTED]`). In a body, a plain ASCII key that is not a
  secret name keeps its value (`{"creds":"hunter2"}`); add the name with `additionalSecretNames`.
- A secret word followed by a value in a sentence written into a member that does not hold a
  name: `{"error":"Error: PIN expired","answer":"1234"}` keeps `answer`, as `PIN expired` is read
  as the value the sentence carries; the free-text rule hides it in the string. Labels written as
  labels (`PIN`, `PIN (4 digits)`, `PIN: required`) hide the value beside them.
- The value of an allowed key: `status=hunter2` keeps `hunter2`.
- A secret name in free text written without a separator with two or more of its letters
  replaced by letters that have no ASCII form: `pɑsswoʀd hunter2` is stored as it is. With a
  separator (`pɑsswoʀd=hunter2`) the value is hidden. A secret word in another language, such as
  `пароль hunter2`, is not one either.
- A label in another language without a `:`, an `=` or another separator, in a member that does
  not hold a name: `{"title":"Пароль","value":…}` and `{"title":"Пароль — ","value":…}` keep the
  value, as `пароль hunter2` does in free text; a dash is not a separator. With one
  (`{"title":"Пароль:","value":…}`), or in a member that holds a name
  (`{"label":"Пароль","value":…}`), the value is hidden. A separator with a letter or a digit
  right after it does not end a label: `{"title":"「パスワード」を入力","value":…}` keeps the value.
- A value written before its name, with no key before it: `hunter2 is my password` is stored as
  it is.
- A card number grouped with `+` or `.` (`4111+1111+1111+1111`), and a card number or an IBAN
  split over two lines by a line feed or a carriage return (`4111 1111 1111` on one line and
  `1111` on the next).
- A card number written with an exponent in free text, in a JSON string or in a form value
  (`paid 4111111111111111e0`, `{"amount":"4111111111111111e0"}`): digits that run into a letter
  are read as an identifier. Written as a JSON number, it is found.
- A short secret in a path segment, such as `/reset/abc123`; only identifiers, tokens of the shapes
  listed above and segments in which a rule finds something become `:id`. In free text the same
  holds for a clean URL (`see https://x.example/reset/abc123`).
- A secret in a URL host that names no secret, unless a detector finds it:
  `https://hunter2.example.com/a` keeps its host. A host that names one is hidden whole.
- A secret in the name of a JSON member (`{"password hunter2":…}`): structured member names are
  shown.

Where it cannot tell, it hides more than it has to: everything after the first trigger, the lines
below included (`Payment failed: card declined` keeps only `Payment failed:`, and
`заказ №42 отправлен` only `заказ`), the rest of a text from its first tag (`Loaded
Array<Item> in 3 ms` keeps only `Loaded Array`), the rest of a text after a quote that does not
close on its line or a bracket that does not close, the rest of a text after a URL that is not
clean, the rest of a text from the start of a word with a backslash or an `&` before a letter
(`R&D team` keeps nothing), the values beside a name that is not plain ASCII, the value of a
name that only describes a secret (`token_type`), and a URL host that names a secret with all
that follows it (`https://auth.example.com/login` is recorded as `https://[REDACTED]`).

## See Also

- ``RedactionPolicy``
- ``RedactionOutcome``
- ``NetworkLogger``
- ``LogStore``
