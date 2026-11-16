# brewfile-tools

Keep [Homebrew](https://brew.sh) Brewfiles in step with what you install. One command,
`brewfile`, with three subcommands:

```shell
brewfile add ripgrep fd          # look the packages up, add them to a Brewfile, brew install them, commit
brewfile remove ripgrep          # drop them from the Brewfile(s), brew uninstall them, commit
brewfile audit                   # installed but not tracked (+), tracked but not installed (-)
```

`add` and `remove` keep each Brewfile's sections, descriptions and alphabetical order. They look the
description up with `brew info` and write it as the entry's comment. They commit only the Brewfile
they changed, so anything else you have staged stays staged.

## Requirements

- [Homebrew](https://brew.sh)
- Ruby (standard library only)
- [fzf](https://github.com/junegunn/fzf), to pick a Brewfile when you don't name one
- bash 4 or newer (macOS ships 3.2; `brew install bash`)
- Optional, for `audit`: `mas`, `npm` and `code`, for the package types they track

macOS and Linux are supported. Casks, `mas` and VS Code extensions only exist where Homebrew
supports them.

## Install

With Homebrew (once the formula is published):

```shell
brew install chrisbloom7/tap/brewfile-tools
```

From a checkout:

```shell
./install                  # links bin/brewfile into ~/.local/bin
./install /usr/local/bin   # or another directory you can write to
./uninstall                # removes that link
```

## Where the Brewfiles live

The Brewfiles are the files named `Brewfile.<suffix>` (for example `Brewfile.common`) in one
directory. `brewfile` looks in the git root of the current directory. To point it elsewhere:

```shell
brewfile -C ~/.dotfiles add ripgrep
export BREWFILE_DIR=~/.dotfiles      # or set it once
```

| Variable | Default | Meaning |
|---|---|---|
| `BREWFILE_DIR` | git root of the current directory | Directory that holds the Brewfiles (same as `-C`) |
| `BREWFILE_PREFIX` | `Brewfile.` | File name prefix. `Brewfile-` makes `Brewfile-work` a Brewfile |
| `BREWFILE_COMMIT_PREFIX` | `brewfile add` / `brewfile remove` | Prefix of the commit message, for example `brew_add` |

## Usage

```
brewfile [-C <dir>] <command> [options]

Commands:
  add <package>...      Add packages to a Brewfile and optionally install them
  remove <package>...   Remove packages from a Brewfile and optionally uninstall them
  audit                 Compare installed packages with the tracked Brewfiles
  help [<command>]      Show this help, or the help for one command
```

### add

```
brewfile add [options] <package> [<package> ...]

  -b, --brewfile, --brewfile-suffix=<suffix>  Target Brewfile suffix (e.g. "common")
  -S, --skip-commit, --no-commit              Skip git commit after changes
  -I, --skip-install, --no-install            Skip running brew install
```

Without `-b` you pick the Brewfile with fzf. It refuses to run when that Brewfile has uncommitted
changes, unless you pass `--skip-commit`. Packages already in the file are skipped, and a commented-out
entry is uncommented. Post-install caveats from `brew install` are printed at the end.

### remove

```
brewfile remove [options] <package> [<package> ...]

  -b, --brewfile, --brewfile-suffix=<suffix>  Target Brewfile suffix (e.g. "common")
  -a, --all-brewfiles                         Remove from all Brewfiles
  -S, --skip-commit, --no-commit              Skip git commit after changes
  -U, --skip-uninstall, --no-uninstall        Skip running brew uninstall
```

### audit

```
brewfile audit [options]

  -a, --all                     Include all tracked package types (default)
  -f, --formula, --formulae     Include formulae only
  -c, --casks                   Include casks only
  -m, --mas                     Include Mac App Store packages only
  -n, --npm                     Include npm packages only
  -t, --tap, --taps             Include taps only
  -s, --vscode                  Include VS Code extensions only
  -o, --file=<filepath>         Write results to file (plain text); stats to stdout
```

## Development

```shell
./run-tests                                         # bats tests plus Ruby specs
./run-tests tests/bin/add.bats                      # one file
./run-tests --filter "symlink"                      # tests matching a pattern
```

Tests need [bats-core](https://github.com/bats-core/bats-core) and Ruby. `brew`, `git` and `fzf` are
stubbed, so Homebrew need not be installed. `tests/fixtures/` holds output copied from real
`brew info --json=v2` and `brew bundle dump` runs (personal paths removed), so a change in Homebrew's
output shows up as a failing test. To refresh a fixture, capture the command again and remove
anything machine-specific.

The command resolves `libexec/brewfile/` relative to its real path, following symlinks, so the same
file works from a checkout, `./install` and a Homebrew `libexec`.

## License

[MIT](LICENSE)
