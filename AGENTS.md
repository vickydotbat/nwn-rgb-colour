# nwn-rgb-colour: agent rules

A public, standalone package that shows NWN:EE builders how to give worn stock parts any RGB colour on the stock client, using NWScript alone. Every file here is read by strangers.

## Where work lands

- `main` is the released line. Never commit to it. Every change is a branch and a pull request on GitHub, merged after CI is green.
- One pull request per effort. A follow-up stacks on it.
- A release is a `v*` tag on `main`, cut by `just release <game folder>` on a machine with the game installed. It builds one zip: the demo `.mod`, the `.hak`, and any demonstration extras and screenshots worth including. The zip goes on the GitHub Release, and a person uploads the same zip to the Neverwinter Vault. Nothing publishes from a pull request.
- Generated game files (masks, materials, models, haks) never go into git. They are built from a game install and ship only as release assets.

## Code comments

The demo module exists to teach. Its scripts carry as many comments as a builder needs to follow them: what each call does, and why the engine needs it. Library and tool code keeps comments to the why.

## Agent setup

`.claude/` holds this repo's skills and settings, and `.agents` links to it so every harness finds them. `CLAUDE.md` loads this file. Generic engineering skills come from the vicky-skills plugin, which `.claude/settings.json` offers; never vendor a copy.

## What a file may say

- No local paths: no absolute path, home folder, user name or host. Name the game install and the game's user folder by role ("the game folder", the `development` folder).
- No dependency on any other project. A tool, script or doc that needs something outside this repo names it as a public download.
- No AI credit and no agent-tool markers in commits, pull requests, docs or code.
- No decompiled engine code. Describe engine behaviour in prose.

## Agent skills

- Tickets: public reports on GitHub Issues; planning in the maintainer's Obsidian vault. See `docs/agents/issue-tracker.md`.
- Domain: single-context. See `docs/agents/domain.md`.
- Testing: see `TESTING_STANDARDS.md`.
