---
name: Notion CLI
slug: notion-cli
type: external_cli
requires_binaries:
  - notion
supported_os:
  - macos
  - linux
install:
  macos: "Install via Homebrew: brew install salmonumbrella/tap/notion-cli."
  linux: "Install via npm: npm install -g notion-cli. Requires Node.js 16+."
verify:
  - "notion --version"
  - "notion --help"
verify_install:
  - "notion --version"
verify_ready:
  - "notion config get token"
risk_level: medium
output_format: json
capabilities:
  - id: query
    description: "Search pages, read page content, and query databases"
    destructive: false
  - id: create
    description: "Create new pages and database items"
    destructive: true
  - id: update
    description: "Update existing page properties"
    destructive: true
    requires_confirmation: true
security_notes:
  - >
    Requires a Notion integration token. Set via NOTION_TOKEN environment
    variable or configure with 'notion config set token <TOKEN>'.
  - >
    The token grants read/write access to pages and databases shared with
    the integration. Scope the integration to the minimum required pages.
  - >
    Config is stored in ~/.notion-cli/config.json. Ensure this file has
    restrictive permissions (chmod 600).
  - "Never log or echo the token value."
---

# Notion CLI

A command-line interface for the Notion API, provided by the
[notion-cli](https://github.com/salmonumbrella/notion-cli) project. This
skill enables an AI agent to interact with Notion workspaces — searching
pages, reading content, creating pages, and updating databases — entirely
from the terminal.

## Purpose

Use this skill when an agent needs to:

- Search for pages or databases in a Notion workspace
- Read page content or database entries
- Create new pages or database items
- Update existing page properties

All operations go through the `notion` CLI binary. The agent must never
call the Notion API directly.

## Installation

### macOS

1. Install via Homebrew:

       brew install salmonumbrella/tap/notion-cli

2. Verify:

       notion --version

### Linux

1. Install Node.js 16+ via your package manager or nvm.
2. Install the CLI globally:

       npm install -g notion-cli

3. Verify:

       notion --version

For the latest installation instructions, see the
[notion-cli README](https://github.com/salmonumbrella/notion-cli).

## Configuration

Before first use, configure your Notion integration token:

    notion config set token <YOUR_NOTION_INTEGRATION_TOKEN>

Alternatively, export the token as an environment variable:

    export NOTION_TOKEN=<YOUR_NOTION_INTEGRATION_TOKEN>

To create a Notion integration token:

1. Visit https://www.notion.so/my-integrations
2. Create a new internal integration
3. Copy the token
4. Share the target pages/databases with the integration

## Verify Commands

These non-destructive commands confirm the CLI is installed and
configured:

    notion --version
    notion --help

## Usage Examples

### Search for pages

    notion search --query "Meeting Notes"

### Read a page

    notion page get <PAGE_ID>

### List database entries

    notion database query <DATABASE_ID>

### Create a page

    notion page create --parent <PAGE_ID> --title "New Page"

### Update a database entry

    notion page update <PAGE_ID> --property "Status" --value "Done"

### Output parsing

The CLI outputs JSON by default. Parse output programmatically — do not
regex-match or string-split results. Check the exit code to determine
success (0) or failure (non-zero).

## Structured Examples

See [references/examples.json](references/examples.json) for canonical
command/response examples in machine-readable format.

## Security Notes

- **Token handling**: The Notion integration token grants read/write
  access to shared pages. Store it in an environment variable or the
  CLI config file — never hard-code it in scripts or logs.
- **Config file**: Located at `~/.notion-cli/config.json`. Set
  permissions to 600 (`chmod 600 ~/.notion-cli/config.json`).
- **Minimum scope**: Only share the specific pages and databases the
  agent needs with the integration. Do not share the entire workspace.
- **Audit**: Review integration activity in Notion's audit log
  periodically.
