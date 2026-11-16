bats_require_minimum_version 1.5.0

load "../test_helper"

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
  _setup_common

  BREWFILE_DIR="${TEST_TMPDIR}/dotfiles"
  mkdir -p "${BREWFILE_DIR}"

  # Brewfile tracks git and wget; NOT fzf
  cat > "${BREWFILE_DIR}/Brewfile.test" <<'EOF'
## Formulae
brew "git" # Distributed revision control system
brew "wget" # Internet file retriever
EOF

  # Default dump fixture: git and fzf installed (not wget)
  cat > "${TEST_TMPDIR}/dump_fixture" <<'EOF'
# Distributed revision control system
brew "git"
# Fuzzy finder
brew "fzf"
EOF

  # Mock brew bundle dump: writes dump_fixture to --file= and records its args
  # in bundle_args. Rejects flags the real `brew bundle dump` doesn't accept,
  # so the tests catch upstream flag removals (e.g. --describe in Homebrew 7).
  cat > "${TEST_TMPDIR}/mock_bin/brew" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "bundle" && "\$2" == "dump" ]]; then
  echo "\$@" > "${TEST_TMPDIR}/bundle_args"
  outfile=""
  for arg in "\${@:3}"; do
    case "\$arg" in
      --file=*) outfile="\${arg#--file=}" ;;
      --quiet|--no-restart|--formulae|--casks|--taps|--mas|--vscode|--npm) ;;
      *) echo "Error: invalid option: \$arg" >&2; exit 1 ;;
    esac
  done
  [[ -n "\${outfile}" ]] || exit 1
  cp "${TEST_TMPDIR}/dump_fixture" "\${outfile}"
fi
exit 0
EOF
  chmod +x "${TEST_TMPDIR}/mock_bin/brew"
}

teardown() {
  _teardown_common
}

invoke() {
  run env \
    PATH="${TEST_TMPDIR}/mock_bin:${PATH}" \
    BREWFILE_DIR="${BREWFILE_DIR}" \
    "${REPO_BIN}/brewfile" audit "$@"
}

# ---------------------------------------------------------------------------
# Early-exit validation
# ---------------------------------------------------------------------------

@test "brewfile audit: fails when no Brewfiles found" {
  run env \
    PATH="${TEST_TMPDIR}/mock_bin:${PATH}" \
    BREWFILE_DIR="${TEST_TMPDIR}/empty" \
    "${REPO_BIN}/brewfile" audit
  [ "${status}" -ne 0 ]
}

@test "brewfile audit: fails when --all and type-specific flags both given" {
  invoke --all --formulae
  [ "${status}" -ne 0 ]
}

@test "brewfile audit: fails when --file given with empty value" {
  invoke --file=
  [ "${status}" -ne 0 ]
}

@test "brewfile audit: --help exits 0 and prints usage" {
  invoke --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Usage"* ]] || {
    echo "Expected usage output, got: ${output}"; return 1
  }
}

@test "brewfile audit: --help works when invoked by a relative path" {
  cd "${REPO_ROOT}"
  run bin/brewfile audit --help
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  [[ "${output}" == *"Usage:"* ]] || { echo "Expected usage text; got: ${output}"; return 1; }
}

@test "brewfile audit: --help prints only the header comment block" {
  run "${REPO_BIN}/brewfile" audit --help
  [ "${status}" -eq 0 ]
  [[ "${output}" != *"-----"* ]] || { echo "Expected no section dividers in help; got: ${output}"; return 1; }
  last_line="$(printf '%s\n' "${output}" | tail -1)"
  header_last="$(sed -n '/^set -euo pipefail/{x;p;q;};h' "${REPO_ROOT}/libexec/brewfile/audit" | sed 's/^# \{0,1\}//')"
  [ "${last_line}" = "${header_last}" ] || {
    echo "Expected help to end with the header's last line '${header_last}'; got '${last_line}'"; return 1
  }
}

# ---------------------------------------------------------------------------
# Diff output
# ---------------------------------------------------------------------------

@test "brewfile audit: marks installed-but-not-tracked packages with +" {
  invoke
  [ "${status}" -eq 0 ]
  # fzf is installed but not in any Brewfile → should appear with +
  [[ "${output}" == *"+ brew"*"fzf"* ]] || [[ "${output}" == *"fzf"*"+"* ]] || {
    echo "Expected fzf with + status, got: ${output}"; return 1
  }
}

@test "brewfile audit: marks tracked-but-not-installed packages with -" {
  invoke
  [ "${status}" -eq 0 ]
  # wget is in Brewfile but not in dump → should appear with -
  [[ "${output}" == *"- brew"*"wget"* ]] || [[ "${output}" == *"wget"*"-"* ]] || {
    echo "Expected wget with - status, got: ${output}"; return 1
  }
}

@test "brewfile audit: does not flag packages present in both sets" {
  invoke
  [ "${status}" -eq 0 ]
  # git appears in both installed dump and Brewfile — should not appear in output
  # (it will appear in stats but not the diff list)
  # Check that git doesn't appear as + or -
  ! [[ "${output}" =~ [+-][[:space:]]+brew[[:space:]]+"git" ]] || {
    echo "git should not appear in diff output: ${output}"; return 1
  }
}

@test "brewfile audit: reports statistics on stdout" {
  invoke
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"installed but not tracked"* ]] || {
    echo "Expected statistics in output, got: ${output}"; return 1
  }
}

# ---------------------------------------------------------------------------
# --file output
# ---------------------------------------------------------------------------

@test "brewfile audit: writes plain text results to --file" {
  outfile="${TEST_TMPDIR}/audit_results.txt"
  invoke --file="${outfile}"
  [ "${status}" -eq 0 ]
  [ -f "${outfile}" ] || {
    echo "Expected output file to be created"; return 1
  }
  grep -q 'fzf\|wget' "${outfile}" || {
    echo "Expected diff results in output file"
    cat "${outfile}"
    return 1
  }
}

@test "brewfile audit: --file output contains no ANSI escape codes" {
  outfile="${TEST_TMPDIR}/audit_results.txt"
  invoke --file="${outfile}"
  [ "${status}" -eq 0 ]
  # ANSI escape sequences start with ESC (\033 / \x1b)
  ! grep -qP '\x1b\[' "${outfile}" || {
    echo "Expected no ANSI color codes in file output"
    return 1
  }
}

@test "brewfile audit: reports save location when --file is used" {
  outfile="${TEST_TMPDIR}/audit_results.txt"
  invoke --file="${outfile}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"${outfile}"* ]] || {
    echo "Expected output file path in stdout, got: ${output}"; return 1
  }
}

# ---------------------------------------------------------------------------
# Type filtering
# ---------------------------------------------------------------------------

@test "brewfile audit: --formulae limits output to brew entries" {
  # Add a cask discrepancy to the dump
  cat > "${TEST_TMPDIR}/dump_fixture" <<'EOF'
brew "fzf"
cask "extra-cask"
EOF
  invoke --formulae
  [ "${status}" -eq 0 ]
  # cask entries should not appear in formulae-only output
  ! [[ "${output}" == *"extra-cask"* ]] || {
    echo "cask entry should not appear when --formulae is set; got: ${output}"; return 1
  }
}

@test "brewfile audit: --npm limits output to npm entries" {
  cat > "${TEST_TMPDIR}/dump_fixture" <<'EOF'
brew "fzf"
npm "eslint"
EOF
  invoke --npm
  [ "${status}" -eq 0 ]
  # brew entries should not appear; npm entry should
  ! [[ "${output}" == *" brew "*"fzf"* ]] || {
    echo "brew entry should not appear when --npm is set; got: ${output}"; return 1
  }
  [[ "${output}" == *"eslint"* ]] || {
    echo "Expected eslint in --npm output; got: ${output}"; return 1
  }
}

@test "brewfile audit: default --all expands to tracked-type flags, not --all" {
  invoke
  [ "${status}" -eq 0 ]
  args=$(cat "${TEST_TMPDIR}/bundle_args")
  for flag in --formulae --casks --taps --mas --vscode --npm; do
    [[ "${args}" == *"${flag}"* ]] || {
      echo "Expected ${flag} in dump args; got: ${args}"; return 1
    }
  done
  ! [[ "${args}" == *" --all"* ]] && ! [[ "${args}" == "--all"* ]] || {
    echo "--all flag should not be passed to brew bundle dump; got: ${args}"; return 1
  }
}

# ---------------------------------------------------------------------------
# brew bundle dump failure
# ---------------------------------------------------------------------------

@test "brewfile audit: exits non-zero when brew bundle dump fails" {
  cat > "${TEST_TMPDIR}/mock_bin/brew" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "bundle" && "$2" == "dump" ]]; then
  echo "Error: bundle dump failed" >&2
  exit 1
fi
exit 0
EOF
  invoke
  [ "${status}" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Real `brew bundle dump` output (tests/fixtures/brew-bundle-dump.txt)
# ---------------------------------------------------------------------------
# The fixture holds lines copied from a real dump: taps and formulae with
# trailing options (`trusted: true`, `link: true`), a cask with `args: {...}`
# and mas entries.

@test "brewfile audit: reads real brew bundle dump lines, options included" {
  cp "${REPO_ROOT}/tests/fixtures/brew-bundle-dump.txt" "${TEST_TMPDIR}/dump_fixture"
  cat > "${BREWFILE_DIR}/Brewfile.test" <<'BREWFILE'
## Formulae
brew "fzf" # Command-line fuzzy finder written in Go
brew "jq" # Lightweight and flexible command-line JSON processor
BREWFILE
  invoke
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  # Untracked, and all of them carry options or come from the real dump
  for name in aom 'postgresql@18' iterm2 'buo/cask-upgrade' Bear; do
    [[ "${output}" == *"${name}"* ]] || { echo "Expected ${name} in: ${output}"; return 1; }
  done
  # Tracked in both, so not flagged
  [[ "${output}" != *"+ brew"*"fzf"* ]] || { echo "fzf should not be flagged: ${output}"; return 1; }
}

@test "brewfile audit: matches a tap formula dumped with its tap prefix to its short name" {
  cat > "${TEST_TMPDIR}/dump_fixture" <<'DUMP'
# Interactive fzf cleanup for Worktrunk worktrees and branches
brew "chrisbloom7/tap/wt-cleanup", trusted: true
DUMP
  cat > "${BREWFILE_DIR}/Brewfile.test" <<'BREWFILE'
## Formulae
brew "wt-cleanup" # Interactive fzf cleanup for Worktrunk worktrees and branches
BREWFILE
  invoke --formulae
  [ "${status}" -eq 0 ] || { echo "status ${status}: ${output}"; return 1; }
  [[ "${output}" != *'"wt-cleanup"'* ]] || { echo "wt-cleanup should match: ${output}"; return 1; }
  [[ "${output}" != *'tap/wt-cleanup'* ]] || { echo "tap name should match: ${output}"; return 1; }
}
