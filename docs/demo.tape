# Demo of `brewfile add` and `brewfile remove`. Regenerate the GIF with:
#   vhs docs/demo.tape
# It works in a throwaway git repo and passes --skip-install / --skip-uninstall, so it never
# touches your Brewfiles or your installed packages. `brew info` still runs for the lookups.
#
# The GIF opens and ends on the same title card (docs/banner.py), so it loops without a jump.

Output docs/demo.gif

Set Shell "bash"
Set FontSize 16
Set Width 1000
Set Height 560
Set Padding 20
Set TypingSpeed 40ms
Set Theme "Catppuccin Mocha"

# Setup (hidden): a scratch repo with one Brewfile, brewfile on PATH, and a clean environment
Hide
Type "unset BREWFILE_DIR BREWFILE_PREFIX BREWFILE_COMMIT_PREFIX BASH_ENV"
Enter
Type "export REPO=$PWD PATH=$PWD/bin:$PATH"
Enter
Type "cd $(mktemp -d) && git init -q && git config user.name Demo && git config user.email demo@example.com"
Enter
Type `printf '# CLI tools\nbrew "jq"\n' > Brewfile.common && git add . && git commit -qm 'Add Brewfile' && clear`
Enter
Type `banner() { clear; python3 $REPO/docs/banner.py "brewfile" "Keep Brewfiles in step with what you install"; }`
Enter
Type "PS1= && banner"
Enter
Show

# Title card
Sleep 2500ms

Hide
Type "tput cnorm && PS1='$ ' && clear"
Enter
Show

# Show the Brewfile we start with
Type "cat Brewfile.common; echo"
Sleep 500ms
Enter
Sleep 2s

# Add two packages: brewfile looks up their descriptions, writes them in order and commits
Ctrl+L
Type "brewfile add -b common --skip-install ripgrep fd"
Sleep 500ms
Enter
Sleep 4s

# The Brewfile now has both entries, sorted and with their descriptions as comments
Ctrl+L
Type "cat Brewfile.common; echo"
Sleep 500ms
Enter
Sleep 3s

# Remove one of them again; brewfile drops the entry and commits
Ctrl+L
Type "brewfile remove -b common --skip-uninstall fd"
Sleep 500ms
Enter
Sleep 4s

# Each change was its own commit, touching only the Brewfile
Ctrl+L
Type "git log --oneline"
Sleep 500ms
Enter
Sleep 4s

# Back to the title card, so the loop restarts on the frame it began with
Hide
Type "PS1= && banner"
Enter
Show
Sleep 2500ms
