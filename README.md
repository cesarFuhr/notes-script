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

If `$NOTES_ROOT` is a git repository, notes are synced with its `origin` remote. Before opening a file the script pulls, and after the editor exits it commits everything and pushes. Sync on demand with:

```bash
notes sync
```

Pulls rebase local commits on top of the remote. On a conflict the rebase is aborted, local commits are kept, and a message asks you to resolve it in `$NOTES_ROOT`. When offline, the push is retried on the next sync. Set `NOTES_SYNC=0` to disable syncing.

Append-mostly files merge cleanly with a `.gitattributes` in the notes repository:

```text
tasks.md merge=union
```

Auto-commits are unsigned, and SSH runs in batch mode, so the remote key must be usable without a prompt.

### Periodic sync with home-manager

```nix
imports = [ notes-script.homeManagerModules.default ];

programs.notes = {
  enable = true;
  sync.enable = true;
  sync.interval = "15min";
};
```

This installs `notes` and a `notes-sync` systemd user timer.
