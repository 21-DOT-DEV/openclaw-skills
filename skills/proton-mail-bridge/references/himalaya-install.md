# Himalaya Installation — Proton Bridge Compatibility

Himalaya is a cross-platform CLI email client written in Rust. It
provides JSON output and IMAP/SMTP support, making it ideal for
agent-driven email operations against Proton Mail Bridge.

---

## Known Issue: v1.1.0 + Proton Bridge v3.21.x

**Problem**: himalaya v1.1.0 (the current Homebrew release) fails
AUTH PLAIN with Proton Bridge. Bridge sends a non-standard SASL PLAIN
continuation response that himalaya's IMAP parser rejects with a
`MalformedMessage` error during the authentication exchange.

**GitHub issue**: [pimalaya/himalaya#620](https://github.com/pimalaya/himalaya/issues/620)
(closed — fixed on master, not yet released to Homebrew)

**What does NOT work on v1.1.0**:

- `encryption.type = "start-tls"` — rustls_platform_verifier rejects
  Bridge's self-signed certificate, even with
  `danger-accept-invalid-certs = true`
- Adding Bridge's cert to the macOS system keychain via
  `security add-trusted-cert` resolves the TLS issue, but AUTH PLAIN
  still fails
- Only the master build with `encryption.type = "none"` works

---

## Install the Fix

### macOS (Apple Silicon)

1. Download the CI build from GitHub Actions:
   - Repository: `pimalaya/himalaya`
   - Actions run: `#21368879390`
   - Artifact: `himalaya-aarch64-darwin`
   - Commit: `9baaa65` (master, post-fix)

2. Replace the Homebrew binary:

       # Back up the existing binary
       cp /opt/homebrew/bin/himalaya /opt/homebrew/bin/himalaya.v1.1.0.bak

       # Copy the CI build
       cp ~/Downloads/himalaya /opt/homebrew/bin/himalaya
       chmod +x /opt/homebrew/bin/himalaya

3. Verify:

       himalaya --version
       # Should show a version newer than 1.1.0 or a commit hash

### macOS (Intel)

Same process, but download the `himalaya-x86_64-darwin` artifact.

### Linux (x86_64)

1. Download the `himalaya-x86_64-linux` artifact from the same
   Actions run
2. Place in PATH (e.g., `/usr/local/bin/himalaya`)
3. `chmod +x /usr/local/bin/himalaya`

### Linux (aarch64)

1. Download the `himalaya-aarch64-linux` artifact
2. Place in PATH and `chmod +x`

---

## When to Switch Back to Homebrew

Once `brew info himalaya` shows a version **newer than 1.1.0**,
switch back:

    brew upgrade himalaya

The upstream fix is merged on master. It will ship in the next
tagged release. Check periodically:

    brew outdated himalaya

---

## Verify Installation

After installing the fixed binary:

    # Check version
    himalaya --version

    # Test IMAP connectivity to Bridge
    himalaya account list -o json

If `account list` returns your Proton account with no errors,
the fix is working. If you see `MalformedMessage` or
`authentication failed`, you are still running v1.1.0.

---

## Configuration

See [config-example.toml](config-example.toml) for a complete
working himalaya configuration for Proton Bridge. The critical
setting is:

    backend.encryption.type = "none"

Bridge handles encryption locally on 127.0.0.1. No TLS is needed
(or functional) for the localhost connection.
