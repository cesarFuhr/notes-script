# notes-script

Not a featureful notes taking script.

## What it does

Its almost easier to point you to the script itself since its so simple and small, but notes script will use your `$EDITOR` to open markdown files based on the date inside the `~/.notes/{subject}` directory.

## How to use it

### notes

```bash
notes subject
```

Will open the `~/.notes/{subject}/YYYY/MM/DD.md` file with the editor in your `$EDITOR` environment variable.
If no `subject` is given it will default to `personal`. So, running:

```bash
notes
```

`notes` will open the `~/.notes/personal/YYYY/MM/DD.md` file with the editor in your `$EDITOR` environment variable.

If the directories don't exist it will create them for you. When you close your editor it will move your shell back to the folder you were before calling the notes script.

### todo

```bash
todo subject
```

`todo` follows the same pattern, but instead of opening your editor it will search for unmarked markdown checkboxes (`[ ]`) across all files in your `subject` directory and list the lines of the matches.
If `subject` is omitted it will default to `personal`.

### todo-done

```bash
todo-done subject
```

`todo-done` its the same as todo, but searches for for marked markdown checkboxes (`[x]`) across all files in your `subject` directory and list the lines of the matches.
If `subject` is omitted it will default to `personal`.
