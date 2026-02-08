---
name: Proton Mail Bridge CLI
slug: proton-mail-bridge
type: external_cli
requires_binaries:
  - proton-bridge
supported_os:
  - macos
  - linux
install:
  macos: >
    Download from https://proton.me/mail/bridge#download or install via
    brew: brew install --cask protonmail-bridge. Requires a paid Proton
    Mail plan (Plus, Unlimited, or Business).
  linux: >
    Download the .deb or .rpm package from
    https://proton.me/mail/bridge#download. Requires a paid Proton Mail
    plan (Plus, Unlimited, or Business).
verify:
  - "proton-bridge --cli --help"
  - "proton-bridge --version"
verify_install:
  - "proton-bridge --version"
verify_ready:
  - "proton-bridge --cli --help"
risk_level: high
output_format: line_based
output_parsing:
  success_pattern: "connected"
  error_stream: "stderr"
capabilities:
  - id: diagnostics
    description: "Check Bridge status, list accounts, and get account info"
    destructive: false
  - id: management
    description: "Log out accounts and change IMAP/SMTP connection mode"
    destructive: true
    requires_confirmation: true
security_notes:
  - >
    Proton Mail Bridge requires a paid Proton Mail plan (Plus, Unlimited,
    or Business). It will not work with free accounts.
  - >
    Bridge exposes local IMAP (port 1143) and SMTP (port 1025) servers
    on 127.0.0.1. Ensure no other process forwards or exposes these
    ports externally.
  - >
    Bridge stores credentials in the system keychain (macOS Keychain or
    GNOME Keyring / KWallet on Linux). The agent must not attempt to
    read, export, or log keychain entries.
  - >
    Keep the agent and Bridge on the same host. Do not tunnel Bridge
    ports over the network.
  - >
    Avoid logging email content (subjects, bodies, addresses). Log only
    operational metadata (message counts, sync status, errors).
---

# Proton Mail Bridge CLI

[Proton Mail Bridge](https://proton.me/mail/bridge) exposes your
encrypted Proton Mail account as a local IMAP/SMTP server, allowing
standard email clients and CLI tools to interact with Proton Mail. The
CLI mode (`proton-bridge --cli`) provides a terminal interface for
managing accounts, checking status, and controlling the bridge.

## Purpose

Use this skill when an agent needs to:

- Check Proton Mail Bridge status and connectivity
- Manage Bridge accounts (login, logout, list)
- Monitor sync progress
- Troubleshoot Bridge configuration issues

The agent interacts with Bridge exclusively via the `proton-bridge` CLI.
It must never attempt to decrypt mail, access the keychain directly, or
connect to Proton servers outside of Bridge.

## Installation

### macOS

1. Download Proton Mail Bridge from
   https://proton.me/mail/bridge#download, or install via Homebrew:

       brew install --cask protonmail-bridge

2. Launch Bridge at least once to complete initial setup (GUI mode).
3. Log in with your Proton Mail credentials.
4. Verify CLI access:

       proton-bridge --cli --help

### Linux

1. Download the .deb or .rpm package from
   https://proton.me/mail/bridge#download.
2. Install:

       # Debian/Ubuntu
       sudo dpkg -i protonmail-bridge_*.deb
       sudo apt-get install -f

       # Fedora/RHEL
       sudo rpm -i protonmail-bridge-*.rpm

3. Launch Bridge at least once to complete initial setup.
4. Log in with your Proton Mail credentials.
5. Verify CLI access:

       proton-bridge --cli --help

For detailed instructions, see the
[Proton Bridge CLI guide](https://proton.me/support/bridge-cli-guide).

## Prerequisites

- **Paid Proton Mail plan**: Plus, Unlimited, or Business. Free accounts
  cannot use Bridge.
- **System keychain**: macOS Keychain Access or GNOME Keyring / KWallet
  on Linux. Bridge stores credentials here.
- **Initial GUI setup**: Bridge must be launched in GUI mode at least
  once to log in and sync.

## Verify Commands

These non-destructive commands confirm Bridge is installed and
accessible:

    proton-bridge --cli --help
    proton-bridge --version

## Usage Examples

### Start Bridge in CLI mode

    proton-bridge --cli

Once in the interactive CLI, you can run commands. Alternatively, some
commands can be passed directly.

### List accounts

    # Inside the CLI session:
    list

### Check info for a specific account

    # Inside the CLI session:
    info <ACCOUNT_INDEX>

### Change IMAP/SMTP connection mode

    # Inside the CLI session:
    change mode <ACCOUNT_INDEX>

### Log out an account

    # Inside the CLI session:
    logout <ACCOUNT_INDEX>

### Output parsing

The Bridge CLI uses a line-based interactive format, not JSON. When
parsing output:

- Look for status keywords: `connected`, `disconnected`, `syncing`
- Account listings are numbered (1-indexed)
- Errors are printed to stderr

For the full command reference, see the
[Proton Bridge CLI guide](https://proton.me/support/bridge-cli-guide).

## Structured Examples

See [references/examples.json](references/examples.json) for canonical
command/response examples in machine-readable format.

## Security Notes

- **Paid plan required**: Bridge only works with paid Proton Mail plans.
  It will refuse to start or sync with a free account.
- **Local-only ports**: Bridge binds IMAP (1143) and SMTP (1025) to
  127.0.0.1. Never expose these ports on a network interface. Do not
  configure firewall rules to forward them.
- **Keychain**: Bridge stores credentials in the OS keychain. The agent
  must not read, export, or log keychain entries. If keychain access
  fails, instruct the user to re-authenticate in GUI mode.
- **Same-host only**: The agent and Bridge must run on the same machine.
  Do not tunnel Bridge ports over SSH or any network transport.
- **No email content logging**: Never log email subjects, bodies, sender
  or recipient addresses. Log only operational metadata such as message
  counts, sync percentages, and error codes.
- **Updates**: Keep Bridge updated to the latest version. Proton
  regularly patches security issues.
