#!/usr/bin/env bash
# test_helper.bash - shared setup/teardown for the brewfile-tools BATS suite

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
REPO_BIN="${REPO_ROOT}/bin"

# _setup_common
# Call at the top of each test file's setup() function.
# Creates an isolated temp directory with a mock_bin/ for stubbing commands
# (brew, git, fzf and so on). mock_bin/ also gets a bash symlink so tests that
# restrict PATH still find a bash new enough for the scripts (macOS's /bin/bash is 3.2).
_setup_common() {
  TEST_TMPDIR="$(mktemp -d)"
  mkdir -p "${TEST_TMPDIR}/mock_bin"
  ln -s "$(command -v bash)" "${TEST_TMPDIR}/mock_bin/bash"
  unset BREWFILE_DIR BREWFILE_PREFIX BREWFILE_COMMIT_PREFIX
  # Pin the Ruby that is current now, so tests that cd elsewhere (or run under a shell
  # that re-activates a version manager) still use the same interpreter.
  export BREWFILE_RUBY="$(ruby -e 'puts RbConfig.ruby')"
}

# _teardown_common
# Call at the bottom of each test file's teardown() function.
_teardown_common() {
  rm -rf "${TEST_TMPDIR}"
}
