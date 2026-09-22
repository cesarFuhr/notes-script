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
notes work find
```

`$EDITOR` is used to open files. Missing journal and inbox directories are created automatically.
