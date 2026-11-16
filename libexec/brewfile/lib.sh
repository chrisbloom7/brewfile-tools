#!/usr/bin/env bash
# lib.sh - shared setup for the brewfile subcommands. Sourced, never executed.
#
# Provides:
#   RUBY                               the Ruby interpreter (BREWFILE_RUBY, default `ruby`), checked to be 2.7+
#   log_info, log_success, log_error   colored messages (colors off when stdout is not a tty or NO_COLOR is set)
#   BREWFILE_DIR                       directory that holds the Brewfiles
#   BREWFILE_PREFIX                    file name prefix of the Brewfiles (default "Brewfile.")
#   brewfile_paths                     prints the Brewfile paths, sorted, one per line

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: lib.sh must be sourced, not executed" >&2
  exit 1
fi

if (( BASH_VERSINFO[0] < 4 )); then
  echo "Error: brewfile requires bash 4 or newer (found ${BASH_VERSION})" >&2
  exit 1
fi

# The Ruby helpers use Array#filter_map, so they need Ruby 2.7 or newer (macOS ships 2.6).
# BREWFILE_RUBY names the interpreter; the Homebrew wrapper sets it, because a shell that
# re-activates a version manager at start-up can put a different `ruby` first on PATH.
RUBY="${BREWFILE_RUBY:-ruby}"
if ! command -v "${RUBY}" >/dev/null 2>&1 \
   || ! "${RUBY}" -e 'exit(Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7") ? 0 : 1)' 2>/dev/null; then
  echo "Error: brewfile requires Ruby 2.7 or newer (${RUBY}; macOS ships 2.6, try: brew install ruby)" >&2
  exit 1
fi

if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then
  _c_red=$'\033[1;31m' _c_green=$'\033[1;32m' _c_blue=$'\033[1;34m' _c_reset=$'\033[0m'
else
  _c_red='' _c_green='' _c_blue='' _c_reset=''
fi
log_info()    { echo "${_c_blue}Info:${_c_reset} $*"; }
log_success() { echo "${_c_green}Success:${_c_reset} $*"; }
log_error()   { echo "${_c_red}Error:${_c_reset} $*" >&2; }

BREWFILE_PREFIX="${BREWFILE_PREFIX:-Brewfile.}"
if [[ -z "${BREWFILE_DIR:-}" ]]; then
  BREWFILE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

brewfile_paths() {
  find "${BREWFILE_DIR}" -maxdepth 1 -name "${BREWFILE_PREFIX}*" | sort
}
