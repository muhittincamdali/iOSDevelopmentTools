# Security policy

iOSDevelopmentTools records network traffic and log messages and replaces sensitive values
before anything is stored. Redaction is a safety net, not a guarantee, but a way around its
documented rules is a vulnerability.

## In scope

- A password, token, cookie, API key or other value under a sensitive name that reaches a
  `NetworkEntry`, an exported HAR file, a cURL command or the console unredacted, for example
  through an unusual spelling or encoding of the name, a body format the policy claims to
  handle, or a body that should have been omitted.
- Input that makes the package crash, hang or use memory without bound (a request or response
  body, a header, a URL, a log message).
- A `curl` command from `curlCommand()` that runs something other than `curl` when pasted into
  a shell.
- A change to what the app sends or receives (the forwarded request or the response differs
  from the original).

Values that the documentation lists as limits (a secret under a plain ASCII name that is not a
secret name, a short secret in a path segment, a look-alike secret word without `=` or `:` in
free text) are known limits, not vulnerabilities; see
[Redacting sensitive data](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata).

## Supported versions

Security fixes are made for the latest release. 1.x is no longer maintained.

## Reporting a vulnerability

Please report vulnerabilities privately, not in a public issue, pull request or discussion.

1. **Preferred:** open the repository's **Security** tab and choose
   **Report a vulnerability** ([how private reporting works](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately)).
2. **Or** email [muhittincamdali@gmail.com](mailto:muhittincamdali@gmail.com) with
   "Security" in the subject.

Include the version (tag or commit), the request or input that shows the problem, and what you
expected to be stored.

## What happens next

- You get a reply within 7 days confirming that the report arrived.
- The issue is confirmed, fixed with a test that reproduces it, and released together with a
  GitHub security advisory on a disclosure date agreed with you.
- You are credited in the advisory unless you prefer not to be.
