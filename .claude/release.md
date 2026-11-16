# Release parameters

Read by the shared `release` skill (the `chrisbloom7-development` plugin). The generic steps live there;
this file holds only what differs for `brewfile-tools`.

## Release parameters

- project: brewfile-tools
- flow: release-branch
- base_branch: main
- preconditions:
  - `./run-tests`: the full suite (bats plus Ruby specs) passes
  - `gh run list --branch main --limit 1 --json conclusion,workflowName`: the latest CI run on `main` is `success`
- informational:
  - `gh api repos/chrisbloom7/homebrew-tap/contents/Formula/brewfile-tools.rb -q .name`: not a gate. A 404
    means the formula is not on the tap's `main` yet, so the tap bump cannot run; tell the owner, and say
    the release reaches Homebrew only when the formula's first PR merges.
- version_pattern: SemVer `X.Y.Z` (the default)
- tag_prefix: v
- tag_style: annotated
- tag_message: brewfile-tools <version>
- branch_name: chore/release-v<version>
- commit_message: Release v<version>: date the changelog
- pr_title: Release v<version>
- merge_method: merge commit
- changelog: keep-a-changelog
- audit:
  - (blocking) Run `bin/brewfile --help` and `bin/brewfile help add`, `help remove` and `help audit`. Compare them
    with the Usage sections and option lists in `README.md` and with the options each script in
    `libexec/brewfile/` actually parses. Flag options or commands that are missing, removed or have a
    different default.
  - (blocking) The environment variable table in `README.md` (`BREWFILE_DIR`, `BREWFILE_PREFIX`,
    `BREWFILE_COMMIT_PREFIX`) matches `libexec/brewfile/lib.sh` and the header of `bin/brewfile`.
  - (advisory) The Requirements list in `README.md` (Homebrew, Ruby, fzf, bash 4+) is current.
  - (advisory) The Install section says the Homebrew formula is available "once the formula is published".
    After the formula's first PR has merged that wording is stale; propose removing it and adding a
    `brew trust chrisbloom7/tap` note, as `wt-cleanup` did.
- pre_tag_wait: CI on the merge commit finishes with `success` (`gh run watch <id> --exit-status`); report
  the result per job
- post_tag:
  - Homebrew tap bump: formula `brewfile-tools`, repo `chrisbloom7/brewfile-tools`, tap `chrisbloom7/tap`
    (`chrisbloom7/homebrew-tap`). Smoke command: `brewfile --help`. If the formula is not on the tap yet,
    stop after the tag and ask the owner to write its first formula PR (see `Formula/wt-cleanup.rb` for the
    shape: `depends_on` bash, fzf and ruby, an `install` that pins the bash shebang and writes a wrapper into
    `bin`, and a `test do` that runs `--help`).
