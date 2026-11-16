# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- First standalone release, extracted from the author's dotfiles with its history. One command, `brewfile`, with the subcommands `add`, `remove` and `audit`. `./install` links it into `~/.local/bin`.
- `-C, --dir <dir>` and `BREWFILE_DIR` choose the directory that holds the Brewfiles. The default is the git root of the current directory.
- `BREWFILE_PREFIX` sets the Brewfile file name prefix (default `Brewfile.`).
- `BREWFILE_COMMIT_PREFIX` sets the prefix of the commit messages `add` and `remove` write (default `brewfile add` / `brewfile remove`).

### Changed

- The three scripts `brew_add`, `brew_remove` and `brew_audit` are now `brewfile add`, `brewfile remove` and `brewfile audit`.
- Logging is built in instead of the dotfiles' `log_*` commands. Colors are off when stdout is not a terminal or `NO_COLOR` is set.
- Exits with a clear error on bash older than 4 (macOS ships 3.2).

### Fixed

- `mas` entries whose id is written with underscore digit groups (`id: 935_235_287`) are parsed, so `audit`, `add` and `remove` see them.
