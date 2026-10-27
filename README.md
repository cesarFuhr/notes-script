# notes-script

A small command-line tool for plain-text notes.

## Model

A space is a directory under `$NOTES_ROOT`, which defaults to `~/.notes`:

```text
~/.notes/
├── work/
│   ├── inbox/
│   ├── journal/
│   ├── plans/
│   └── tasks.md
└── personal/
    ├── inbox/
    ├── journal/
    └── tasks.md
```

The default space is `personal`. Set another default with:

```bash
export NOTES_SPACE=work
```

## Usage

Open today's journal in the default space:

```bash
notes
```

Choose a space or relative day:

```bash
notes work
notes yesterday
notes work tomorrow
```

Open a particular journal date:

```bash
notes journal 2026-09-21
notes work 2026-09-21
```

Capture a timestamped inbox note without deciding where it belongs:

```bash
notes new
notes work new
```

List outstanding tasks or approximately search note contents in a space:

```bash
notes todo
notes work todo
notes search migration
notes work search migration
```

Search tolerates up to two edits, including common misspellings and adjacent transpositions. It passes the matches to `fzf` and opens the selected file at the matching line.

Interactively select a file with `fzf`:

```bash
notes find
notes find migration plan
notes work find support
```

Text after `find` is used as the initial `fzf` query.

`$EDITOR` is launched from `$NOTES_ROOT` when opening files. Missing journal and inbox directories are created automatically.

## Sync

If `$NOTES_ROOT` is a git repository, `notes sync` commits everything, pulls and pushes to its `origin` remote. Run it on demand, or periodically with the timer below:

```bash
notes sync
```

Pulls rebase local commits on top of the remote. When offline, the push is retried on the next sync.

Check how syncing is doing without touching the network:

```bash
notes sync --status
```

It reports uncommitted files, unpushed commits, commits behind as of the last fetch, open conflicts, the timer's last and next run (or a sync in progress), and how many timer runs failed in the last 24 hours with the messages from the latest failure.

Conflicts never block syncing. The remote is merged and committed as-is: text files keep both versions between conflict markers labelled with the host name, and binary files take the remote version while the local one is saved beside it as `name.conflict-<host>.ext`. A desktop notification names the files. Pick one and edit it with:

```bash
notes conflicts
```

Append-mostly files merge cleanly with a `.gitattributes` in the notes repository:

```text
tasks.md merge=union
```

Auto-commits are unsigned, and the system `ssh` runs in batch mode, so the remote key must be usable without a prompt.

### Periodic sync with home-manager

```nix
imports = [ notes-script.homeManagerModules.default ];

programs.notes = {
  enable = true;
  sync.enable = true;
  sync.interval = "5min";
};
```

This installs `notes` and a `notes-sync` systemd user timer that syncs shortly after login and then every `sync.interval`.
