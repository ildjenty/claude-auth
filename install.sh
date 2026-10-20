#!/bin/sh
# Set up claude-auth.
#   sh install.sh          copy claude-auth.zsh into ~/.claude-accounts
#   sh install.sh --link   symlink to the file in this repo instead (follows updates)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
accounts_dir=${CLAUDE_ACCOUNTS_DIR:-$HOME/.claude-accounts}
zshrc=${ZDOTDIR:-$HOME}/.zshrc
mode=copy
[ "${1:-}" = "--link" ] && mode=link

mkdir -p "$accounts_dir" "$accounts_dir/.cache"

# the tool itself
target=$accounts_dir/claude-auth.zsh
if [ "$mode" = link ]; then
  ln -sfn "$here/claude-auth.zsh" "$target"
  echo "symlinked: $target -> $here/claude-auth.zsh"
else
  cp "$here/claude-auth.zsh" "$target"
  echo "copied: $target"
fi

# folder -> account mapping
[ -e "$accounts_dir/dirs" ] || : > "$accounts_dir/dirs"

# .zshrc
line="source \"$accounts_dir/claude-auth.zsh\""
if [ -f "$zshrc" ] && grep -qF "claude-auth.zsh" "$zshrc"; then
  echo "skipped: $zshrc already sources claude-auth.zsh"
else
  printf '\n# claude-auth: switch Claude Code accounts\n%s\n' "$line" >> "$zshrc"
  echo "appended: $zshrc"
fi

echo
echo "Done. Open a new terminal or run:"
echo "  $line"
echo "Then register an account: claude-auth add-account <name>"
