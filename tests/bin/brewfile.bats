bats_require_minimum_version 1.5.0

load "../test_helper"

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
  _setup_common

  FIXTURE_DIR="${TEST_TMPDIR}/brewfiles"
  mkdir -p "${FIXTURE_DIR}"
  cat > "${FIXTURE_DIR}/Brewfile.test" <<'BREWFILE'
## Formulae
brew "git" # Distributed revision control system
BREWFILE

  # Mock brew: canned info JSON for "fzf"; no-op everything else
  cat > "${TEST_TMPDIR}/mock_bin/brew" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "info" ]]; then
  echo '{"formulae":[{"name":"fzf","desc":"Fuzzy finder"}],"casks":[]}'
  exit 0
fi
exit 0
MOCK
  chmod +x "${TEST_TMPDIR}/mock_bin/brew"
}

teardown() {
  _teardown_common
}

brewfile() {
  run env PATH="${TEST_TMPDIR}/mock_bin:${PATH}" "${REPO_BIN}/brewfile" "$@"
}

# ---------------------------------------------------------------------------
# Dispatch and help
# ---------------------------------------------------------------------------

@test "brewfile: --help lists the commands and exits 0" {
  brewfile --help
  [ "${status}" -eq 0 ]
  for word in "Usage:" "add" "remove" "audit" "BREWFILE_DIR"; do
    [[ "${output}" == *"${word}"* ]] || { echo "Missing '${word}' in: ${output}"; return 1; }
  done
}

@test "brewfile: --help prints only the header comment block" {
  brewfile --help
  [ "${status}" -eq 0 ]
  last_line="$(printf '%s\n' "${output}" | tail -1)"
  header_last="$(sed -n '/^set -euo pipefail/{x;p;q;};h' "${REPO_BIN}/brewfile" | sed 's/^# \{0,1\}//')"
  [ "${last_line}" = "${header_last}" ] || {
    echo "Expected '${header_last}'; got '${last_line}'"; return 1
  }
}

@test "brewfile: no command prints usage and exits non-zero" {
  brewfile
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Usage:"* ]] || { echo "Got: ${output}"; return 1; }
}

@test "brewfile: unknown command exits non-zero" {
  brewfile frobnicate
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Unknown command: frobnicate"* ]] || { echo "Got: ${output}"; return 1; }
}

@test "brewfile: unknown global option exits non-zero" {
  brewfile --bogus add fzf
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Unknown option: --bogus"* ]] || { echo "Got: ${output}"; return 1; }
}

@test "brewfile: help <command> shows that command's help" {
  brewfile help add
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"--skip-install"* ]] || { echo "Got: ${output}"; return 1; }
}

@test "brewfile: help <unknown> exits non-zero" {
  brewfile help frobnicate
  [ "${status}" -eq 1 ]
}

@test "brewfile: add --help shows the add options" {
  brewfile add --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"brewfile add [options]"* ]] || { echo "Got: ${output}"; return 1; }
}

# ---------------------------------------------------------------------------
# Locating the Brewfiles
# ---------------------------------------------------------------------------

@test "brewfile: -C <dir> selects the Brewfile directory" {
  brewfile -C "${FIXTURE_DIR}" add -b test -S -I fzf
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  grep -q '"fzf"' "${FIXTURE_DIR}/Brewfile.test"
}

@test "brewfile: --dir=<dir> selects the Brewfile directory" {
  brewfile --dir="${FIXTURE_DIR}" add -b test -S -I fzf
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  grep -q '"fzf"' "${FIXTURE_DIR}/Brewfile.test"
}

@test "brewfile: BREWFILE_DIR selects the Brewfile directory" {
  run env PATH="${TEST_TMPDIR}/mock_bin:${PATH}" BREWFILE_DIR="${FIXTURE_DIR}" \
    "${REPO_BIN}/brewfile" add -b test -S -I fzf
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  grep -q '"fzf"' "${FIXTURE_DIR}/Brewfile.test"
}

@test "brewfile: defaults to the git root of the current directory" {
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  git -C "${FIXTURE_DIR}" init -q
  mkdir -p "${FIXTURE_DIR}/sub/dir"
  cd "${FIXTURE_DIR}/sub/dir"
  brewfile add -b test -S -I fzf
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  grep -q '"fzf"' "${FIXTURE_DIR}/Brewfile.test"
}

@test "brewfile: BREWFILE_PREFIX changes which files are Brewfiles" {
  mv "${FIXTURE_DIR}/Brewfile.test" "${FIXTURE_DIR}/Brewfile-work"
  run env PATH="${TEST_TMPDIR}/mock_bin:${PATH}" BREWFILE_PREFIX="Brewfile-" \
    "${REPO_BIN}/brewfile" -C "${FIXTURE_DIR}" add -b work -S -I fzf
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  [[ "${output}" == *"to Brewfile-work"* ]] || { echo "Got: ${output}"; return 1; }
  grep -q '"fzf"' "${FIXTURE_DIR}/Brewfile-work"
}

# ---------------------------------------------------------------------------
# Commit messages
# ---------------------------------------------------------------------------

_init_real_repo() {
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
  git -C "${FIXTURE_DIR}" init -q
  git -C "${FIXTURE_DIR}" add -A
  git -C "${FIXTURE_DIR}" commit -q -m initial
}

@test "brewfile: add commits with the default message prefix" {
  _init_real_repo
  brewfile -C "${FIXTURE_DIR}" add -b test -I fzf
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  [ "$(git -C "${FIXTURE_DIR}" log -1 --format=%s)" = "brewfile add: add fzf to Brewfile.test" ]
}

@test "brewfile: BREWFILE_COMMIT_PREFIX overrides the commit message prefix" {
  _init_real_repo
  run env PATH="${TEST_TMPDIR}/mock_bin:${PATH}" BREWFILE_COMMIT_PREFIX="brew_add" \
    "${REPO_BIN}/brewfile" -C "${FIXTURE_DIR}" add -b test -I fzf
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  [ "$(git -C "${FIXTURE_DIR}" log -1 --format=%s)" = "brew_add: add fzf to Brewfile.test" ]
}

# ---------------------------------------------------------------------------
# Symlinked install
# ---------------------------------------------------------------------------

@test "brewfile: works when invoked through a symlink" {
  mkdir -p "${TEST_TMPDIR}/link"
  ln -s "${REPO_BIN}/brewfile" "${TEST_TMPDIR}/link/brewfile"
  run env PATH="${TEST_TMPDIR}/mock_bin:${PATH}" \
    "${TEST_TMPDIR}/link/brewfile" -C "${FIXTURE_DIR}" add -b test -S -I fzf
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  grep -q '"fzf"' "${FIXTURE_DIR}/Brewfile.test"
}

# ---------------------------------------------------------------------------
# Ruby version guard (the helpers need Ruby 2.7+; macOS ships 2.6)
# ---------------------------------------------------------------------------

@test "brewfile: subcommands exit with a clear message when Ruby is too old" {
  # Stand-in for an old Ruby: the version check (ruby -e ...) fails
  printf '#!/usr/bin/env bash\nexit 1\n' > "${TEST_TMPDIR}/old_ruby"
  chmod +x "${TEST_TMPDIR}/old_ruby"
  for name in add remove audit; do
    run env PATH="${TEST_TMPDIR}/mock_bin:${PATH}" BREWFILE_RUBY="${TEST_TMPDIR}/old_ruby" \
      "${REPO_BIN}/brewfile" -C "${FIXTURE_DIR}" "${name}" -b test -S fzf
    [ "${status}" -eq 1 ] || { echo "${name}: status ${status}: ${output}"; return 1; }
    [[ "${output}" == *"requires Ruby 2.7 or newer"* ]] || { echo "${name}: got: ${output}"; return 1; }
    [[ "${output}" != *"NoMethodError"* ]] || { echo "${name}: got: ${output}"; return 1; }
  done
}

@test "brewfile: subcommands exit with a clear message when Ruby is missing" {
  run env PATH="${TEST_TMPDIR}/mock_bin:${PATH}" BREWFILE_RUBY="${TEST_TMPDIR}/no/such/ruby" \
    "${REPO_BIN}/brewfile" -C "${FIXTURE_DIR}" add -b test -S fzf
  [ "${status}" -eq 1 ] || { echo "status ${status}: ${output}"; return 1; }
  [[ "${output}" == *"requires Ruby 2.7 or newer"* ]] || { echo "Got: ${output}"; return 1; }
}

@test "brewfile: BREWFILE_RUBY selects the interpreter" {
  # A wrapper that records its use and runs the real Ruby
  cat > "${TEST_TMPDIR}/ruby_wrapper" <<WRAPPER
#!/usr/bin/env bash
echo used >> "${TEST_TMPDIR}/ruby_used"
exec "${BREWFILE_RUBY}" "\$@"
WRAPPER
  chmod +x "${TEST_TMPDIR}/ruby_wrapper"
  run env PATH="${TEST_TMPDIR}/mock_bin:${PATH}" BREWFILE_RUBY="${TEST_TMPDIR}/ruby_wrapper" \
    "${REPO_BIN}/brewfile" -C "${FIXTURE_DIR}" add -b test -S -I fzf
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  [ -s "${TEST_TMPDIR}/ruby_used" ] || { echo "wrapper was not used"; return 1; }
}

@test "brewfile: dispatcher help does not need Ruby" {
  printf '#!/usr/bin/env bash\nexit 1\n' > "${TEST_TMPDIR}/old_ruby"
  chmod +x "${TEST_TMPDIR}/old_ruby"
  run env PATH="${TEST_TMPDIR}/mock_bin:${PATH}" BREWFILE_RUBY="${TEST_TMPDIR}/old_ruby" "${REPO_BIN}/brewfile" --help
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
}
