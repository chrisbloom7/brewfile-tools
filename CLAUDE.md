# CLAUDE.md

`brewfile-tools` is one command, `brewfile`, that adds, removes and audits entries in Homebrew
Brewfiles (`add`, `remove`, `audit`). A bash dispatcher plus Ruby helpers (standard library only).
macOS and Linux. Read `README.md` before opening a PR.

## Commands

```bash
./run-tests                                   # bats tests plus Ruby specs
./run-tests tests/bin/add.bats                # one bats file
./run-tests tests/helpers/brewfile_spec.rb    # one Ruby spec (plain `ruby`, minitest)
./run-tests --filter "symlink"                # tests matching a pattern
./install [dir]                               # link bin/brewfile into ~/.local/bin (or dir)
./uninstall
```

Needs `bats-core` (`brew install bats-core`; override the path with `BATS_BIN`), `ruby`, `fzf` and
bash 4+ (macOS ships 3.2: `brew install bash`). There is no separate lint step.

## Architecture

- `bin/brewfile`: the dispatcher. It resolves its own path through symlinks, so it works from
  `./install`, a Homebrew `libexec` and a plain checkout. Its leading comment block is the `--help`
  text, so keep that block and the README usage section in step.
- `libexec/brewfile/add`, `remove`, `audit`: the subcommands (bash). Each one's leading comment block
  is its `--help`. They source `libexec/brewfile/lib.sh` (logging, bash guard, `BREWFILE_DIR`,
  `BREWFILE_PREFIX`).
- `libexec/brewfile/brewfile.rb`: parses and rewrites Brewfiles. The `*_helper.rb` files wrap it for
  each subcommand. `brew_info.rb` is not called by anything yet.
- `tests/bin/*.bats` (CLI) and `tests/helpers/*_spec.rb` (Ruby); `tests/test_helper.bash` is the
  shared bats setup.

## Gotchas

- `tests/fixtures/` holds output copied from real `brew info --json=v2` and `brew bundle dump` runs,
  with personal paths removed. To refresh one, capture the command again and scrub anything
  machine-specific; do not hand-write the JSON, because Homebrew's real output is what the tests
  exist to match.
- Homebrew writes tap formulae and casks with their tap prefix (`brew "user/tap/name"`). `audit`
  compares brew and cask entries on the short name; `add` and `remove` accept either form.
- Bash 4+ only. Do not use features that need newer than 4, and do not assume the system `/bin/bash`.
- Ruby specs run with plain `ruby <file>`, not rspec. `./run-tests` runs both suites and exits non-zero
  if either fails.
- CI (`.github/workflows/ci.yml`) runs on macOS and Linux and includes an install smoke test. Actions
  are pinned by commit SHA with a version comment; keep that when editing workflows.
- Keep `CHANGELOG.md` current under `[Unreleased]`. Releases go through a `chore/release-vX.Y.Z` PR,
  then a `vX.Y.Z` tag after the merge. The Homebrew formula lives in `chrisbloom7/homebrew-tap` and is
  bumped there, not here.
- The default branch is `main`; changes go through PRs.

## Claude Code setup

`.claude/settings.json` allows `./run-tests` and registers `syntax-check-shell-ruby.sh`, a hook that
runs `bash -n` on edited shell files (including the extensionless scripts) and `ruby -c` on edited
`.rb` files. Hooks skip quietly when a tool they need is missing.

Changes to `.claude/` (hooks, agents and the allowlist) and to this file run or steer Claude Code on
the machine of whoever opens the repo, so `.github/CODEOWNERS` routes them to the maintainer. When
reviewing an outside PR that touches them, read the diff first (`gh pr diff <number> -- .claude
CLAUDE.md`) before checking the branch out and starting Claude Code there.
