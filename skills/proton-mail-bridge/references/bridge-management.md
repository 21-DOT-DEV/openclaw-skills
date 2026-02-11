# Bridge Management

Bridge CLI is an **interactive shell** — it cannot be called with
one-shot arguments. Commands must be piped via stdin. The CLI
**cannot run alongside the GUI** (lock file prevents it). Only use
these commands when the GUI is not running.

## List accounts

    echo -e "list\nexit" | proton-bridge --cli

Accounts are **0-indexed** (account 0 is the first account).

## Account info

    echo -e "info 0\nexit" | proton-bridge --cli

## Account sync status

Accounts can be in a **locked** state during initial sync. If you
see `locked` status, wait 30 seconds and retry. Do not attempt
operations on a locked account.

## Log out an account

    echo -e "logout 0\nexit" | proton-bridge --cli

This is destructive — requires re-authentication in GUI mode.

## Output parsing

Bridge CLI output is line-based, not JSON. Look for:

- Status keywords: `connected`, `disconnected`, `syncing`, `locked`
- Account lines: `0: user@proton.me (connected, ...)`
- Errors on stderr
