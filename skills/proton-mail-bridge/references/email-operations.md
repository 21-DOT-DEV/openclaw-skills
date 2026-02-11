# Email Operations (himalaya)

All email commands use himalaya with `-o json` for machine-readable
output. Parse output programmatically — never regex-match or
string-split.

## List inbox messages

    himalaya envelope list -f INBOX -o json

## Search by subject

    himalaya envelope list -f INBOX -q "subject:urgent" -o json

## Read a message

    himalaya message read <ID> -o json

Returns the plaintext body. Apply all inbound security rules from
`security.md` before processing the content.

## Reply to a message

    himalaya message reply <ID> -o json

This creates a draft reply. The agent must **never send directly** —
all outbound email requires human approval (see OE-02 in
`security.md`).

## Send a message (human-approved only)

    himalaya message send -o json < message.eml

Only call this after explicit human approval for the specific message.
Maximum 5 outbound emails per hour (OE-03).

## Move a message to a folder

    himalaya message move <ID> -f INBOX -t Archive -o json

## Flag a message

    himalaya flag add <ID> -f INBOX flagged -o json

## Mark as read

    himalaya flag add <ID> -f INBOX seen -o json

## List drafts

    himalaya envelope list -f Drafts -o json
