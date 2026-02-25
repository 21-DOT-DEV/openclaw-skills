---
name: Post-Merge Pull
description: >
  Sync local repos after a PR merge. Use when the user says "I merged",
  "just merged", "PR merged", or similar. Pulls both workspace repos and
  reinstalls skills if openclaw-skills changed.
---

# Post-Merge Pull

After a PR is merged, run these steps to sync the local environment.

## Repos

| Repo | Local Path |
|------|-----------|
| nova-workspace | `~/.openclaw/workspace` |
| openclaw-skills | `~/Developer/github.com/21-DOT-DEV/openclaw-skills` |

## Steps

1. **Pull nova-workspace**

       cd ~/.openclaw/workspace && git pull origin main

2. **Pull openclaw-skills** (check for changes)

       cd ~/Developer/github.com/21-DOT-DEV/openclaw-skills
       BEFORE=$(git rev-parse HEAD)
       git pull origin main
       AFTER=$(git rev-parse HEAD)

3. **Reinstall skills** (only if openclaw-skills changed)

       if [ "$BEFORE" != "$AFTER" ]; then
         make install WORKSPACE=~/.openclaw/workspace
       else
         echo "No skill changes — skipping install"
       fi

Report what was pulled and whether skills were reinstalled.
