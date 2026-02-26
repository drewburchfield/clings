# Code Review: --when and --heading for update command

## Query
Review feat/update-when-heading branch adding --when (JXA activationDate) and --heading (Things URL scheme) to clings update command. Focus: security, correctness, edge cases, test coverage.

## Gemini
- CRITICAL: `.urlQueryAllowed` doesn't encode `&`, `=`, `+` in heading values, breaking URLs
- Auth token file created with 0644 (world-readable), should be 0600
- Suggested `URLComponents` for safe URL construction
- Noted `NSWorkspace.open` as alternative to `Process` + `/usr/bin/open`
- Flagged potential race condition with Things async URL processing
- Self-critique: uncertain about output formatter behavior, annotation artifacts in diff

## Codex
- Partial analysis only (timed out before completing)
- Identified key call sites and began checking behavioral test gaps

## Claude (subagent)
- Same URL encoding bug with `.urlQueryAllowed`
- `id` and `token` also not percent-encoded
- Auth token file permissions (0644 vs 0600)
- No exit code check on `open` process
- Heading logic bypasses ThingsClientProtocol (architecture concern)
- Test gaps: no tests for heading-only update, invalid --when, URL encoding, AuthTokenStore
- Self-critique: didn't compile/run tests, uncertain if Things JXA `activationDate` is writable

## Feature-Dev Code Reviewer
- Same URL encoding issue (highest priority)
- Auth token file permissions
- Process exit code not checked
- Heading bypass of protocol abstraction
- `when: Date? = nil` default on protocol implementations is misleading

## Synthesis
**Consensus (all reviewers):** URL encoding broken, auth token file too permissive.
**Fixes applied:** URLComponents for URL construction, 0600 file permissions, exit code check.
**Deferred:** Protocol abstraction for heading (acceptable for first PR), additional test coverage.
