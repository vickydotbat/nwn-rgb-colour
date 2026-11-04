# Issue tracker

Two trackers, split by who files:

- **Public reports** (bugs, questions, requests from builders) are GitHub Issues on this repository, worked with `gh issue`.
- **Planning** (star charts, anomalies, probes, stars, waiting work) lives in the maintainer's Obsidian vault, in the vault's `nwn-rgb-colour/` folder, one note per ticket. Contributors without the vault work from GitHub Issues only.

The rest of this file is the Obsidian side. A planning ticket that answers a GitHub issue links it by URL, and the issue gets a comment when the ticket closes.

Name a new note `YYYYMMDDHHMMSS <Title>.md`. The frontmatter holds the fields below, and comments go at the bottom under `## Comments`, newest last. A note is never deleted: a ticket ends as `status: done`.

```yaml
---
kind: anomaly        # chart, anomaly, away-team, probe, task or star
status: open         # open, claimed, waiting or done
parent: "[[<chart note name>]]"
blocked_by: ["[[<blocker note title>]]"]
---
```

| Action | How |
| --- | --- |
| Read, whole | Read the note, frontmatter and `## Comments` included. |
| File | Write a new note in `<vault>/nwn-rgb-colour/` with the frontmatter above. |
| Comment | Append `- YYYY-MM-DD: <text>` under `## Comments`. |
| Find | `grep -l '<text>' "<vault>/nwn-rgb-colour/"*.md` |
| Close | Comment the reason, then set `status: done`. |

Ideas: a note in `<vault>/nwn-rgb-colour/` with `kind: idea`.

## Star chart operations

- **Star chart**: a note named `YYYYMMDDHHMMSS Star Chart - <effort>.md` with `kind: chart`. Obsidian refuses a colon in a note name, and a link names the whole note, timestamp included.
- **Ticket**: a note whose `parent` links the chart. A star has `kind: star`.
- **List a chart's tickets**: `grep -l 'parent: "\[\[[0-9]* Star Chart - <effort>\]\]"' "<vault>/nwn-rgb-colour/"*.md`
- **Blocking**: the `blocked_by` links. A ticket is unblocked when every note it links is `status: done`.
- **Frontier**: the chart's tickets with `status: open` and no blocker still open.
- **Chart**: a Mermaid block under `## Chart` in the chart note. Obsidian draws it.
- **Claim**: set `status: claimed` and save, before any other work.

## Waiting work

A waiting ticket can't go on until the thing its `Waits on:` line names is done. It waits on you when that line names you: your decision, answer or merge.

- **List waiting tickets**: `grep -l '^Waits on:' "<vault>/nwn-rgb-colour/"*.md`.
- **List tickets waiting on you**: the same, keeping each note whose `Waits on:` line names you.
- **Move a ticket to <state>**: set `status:` to `open`, `claimed`, `waiting` or `done`.
- **List items created or changed since <time>**: `find "<vault>/nwn-rgb-colour/" -name '*.md' -newermt '<time>'`. A note whose name's timestamp is at or after `<time>` is new, any other is edited. Show at most five, then a count of the rest.
- **List items closed since <time>**: `find "<vault>/nwn-rgb-colour/" -name '*.md' -newermt '<time>' -exec grep -l '^status: done' {} +`. Give the count.
- **Park a ticket**: set `status: waiting` and add a `Waits on: <who or what>` line under the frontmatter.
- **Claim a waiting ticket**: set `status: claimed` and delete its `Waits on:` line, before any other work.

## Ticket drift

Ticket drift: on

Change `on` to `off` to stop the `ticket-drift` check in this repo.

## Pull request bodies

PR template: on

Change `on` to `off` to stop `pr-guard` refusing a pull request body that lacks `ship-it`'s Status, Summary, Proof and Risk sections in this repo.
