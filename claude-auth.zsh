# claude-auth.zsh
# zsh functions to switch Claude Code accounts per terminal session, plus a
# chpwd hook that applies the account mapped to the current folder.
# Load it from .zshrc: source ~/.claude-accounts/claude-auth.zsh
#
# How it works:
#   - each account uses $CLAUDE_ACCOUNTS_DIR/<name>/ as its CLAUDE_CONFIG_DIR
#   - $CLAUDE_ACCOUNTS_DIR/dirs maps folders to accounts (tab separated)
#   - when no folder matches and nothing is pinned, CLAUDE_CONFIG_DIR is unset
#     and Claude Code behaves as if this tool were not installed (~/.claude)
#   - claude-auth <name> pins the account for this shell; cd no longer changes it

: ${CLAUDE_ACCOUNTS_DIR:=$HOME/.claude-accounts}

# ---------------------------------------------------------------- internals

_claude_auth_apply() {
  local name=$1
  if [[ -z $name ]]; then
    unset CLAUDE_CONFIG_DIR CLAUDE_AUTH_NAME
  else
    export CLAUDE_CONFIG_DIR="$CLAUDE_ACCOUNTS_DIR/$name"
    export CLAUDE_AUTH_NAME=$name
  fi
}

_claude_auth_exists() {
  [[ -n $1 && -d $CLAUDE_ACCOUNTS_DIR/$1 ]]
}

_claude_auth_names() {
  local d
  for d in "$CLAUDE_ACCOUNTS_DIR"/*(N/); do
    print -r -- "${d:t}"
  done
}

# Account mapped to the current folder (longest match, empty if none).
_claude_auth_dir_account() {
  local file=$CLAUDE_ACCOUNTS_DIR/dirs
  local best= bestlen=0 p name
  if [[ -r $file ]]; then
    while IFS=$'\t' read -r p name; do
      [[ -z $p || $p == \#* || -z $name ]] && continue
      p=${p/#\~/$HOME}
      p=${p%/}
      if [[ $PWD == "$p" || ${PWD:0:$((${#p}+1))} == "$p/" ]] && (( ${#p} > bestlen )); then
        best=$name
        bestlen=${#p}
      fi
    done < "$file"
  fi
  print -r -- "$best"
}

# Email address of an account (cached; fetched via `claude auth status` otherwise).
_claude_auth_email() {
  local name=$1
  local cache=$CLAUDE_ACCOUNTS_DIR/.cache/$name.email
  if [[ -r $cache ]]; then
    cat "$cache"
    return
  fi
  local email
  email=$(CLAUDE_CONFIG_DIR="$CLAUDE_ACCOUNTS_DIR/$name" claude auth status 2>/dev/null \
    | sed -n 's/.*"email": *"\([^"]*\)".*/\1/p' | head -1)
  if [[ -n $email ]]; then
    mkdir -p "$CLAUDE_ACCOUNTS_DIR/.cache"
    print -r -- "$email" > "$cache"
  fi
  print -r -- "$email"
}

_claude_auth_chpwd() {
  emulate -L zsh
  [[ -n $CLAUDE_AUTH_PINNED ]] && return
  _claude_auth_apply "$(_claude_auth_dir_account)"
}

# ---------------------------------------------------------------- subcommands

_claude_auth_cmd_list() {
  local -a names
  names=(${(f)"$(_claude_auth_names)"})
  if (( ${#names} == 0 )); then
    print -u2 "No accounts registered. Run: claude-auth add-account <name>"
    return 1
  fi

  local i=1 name email mark
  for name in $names; do
    email=$(_claude_auth_email "$name")
    mark=" "
    [[ $name == $CLAUDE_AUTH_NAME ]] && mark="*"
    printf '%s %2d) %-12s %s\n' "$mark" $i "$name" "${email:-(not logged in)}"
    (( i++ ))
  done

  local n
  read -r "n?Number (Enter to cancel): "
  [[ -z $n ]] && return 0
  if [[ $n != <1-> ]] || (( n > ${#names} )); then
    print -u2 "Invalid number: $n"
    return 1
  fi
  _claude_auth_cmd_use "${names[$n]}"
}

_claude_auth_cmd_use() {
  local name=$1
  if ! _claude_auth_exists "$name"; then
    print -u2 "Account '$name' is not registered. Run: claude-auth add-account $name"
    return 1
  fi
  _claude_auth_apply "$name"
  export CLAUDE_AUTH_PINNED=1
  print "Using '$name' in this terminal."
}

_claude_auth_cmd_add_account() {
  local name=$1
  if [[ -z $name ]]; then
    print -u2 "Usage: claude-auth add-account <name>"
    return 1
  fi
  if [[ ! $name =~ '^[A-Za-z0-9_-]+$' ]]; then
    print -u2 "Name may only contain letters, digits, hyphen and underscore: $name"
    return 1
  fi
  local dir=$CLAUDE_ACCOUNTS_DIR/$name
  if [[ -e $dir ]]; then
    print -u2 "'$name' already exists: $dir"
    return 1
  fi

  mkdir -p "$dir"
  # share settings from ~/.claude via symlinks
  local f
  for f in settings.json keybindings.json skills CLAUDE.md; do
    [[ -e $HOME/.claude/$f ]] && ln -s "$HOME/.claude/$f" "$dir/$f"
  done

  print "Log in via the browser..."
  if ! CLAUDE_CONFIG_DIR=$dir claude auth login; then
    print -u2 "Login failed. The directory was left in place: $dir"
    return 1
  fi

  rm -f "$CLAUDE_ACCOUNTS_DIR/.cache/$name.email"
  local email
  email=$(_claude_auth_email "$name")
  print "Registered account '$name'${email:+ ($email)}."
  print "Switch to it with: claude-auth $name"
}

_claude_auth_cmd_add_dir() {
  local name=$1
  if [[ -z $name ]]; then
    print -u2 "Usage: claude-auth add-dir <name>   (use this account in the current folder)"
    return 1
  fi
  if ! _claude_auth_exists "$name"; then
    print -u2 "Account '$name' is not registered."
    return 1
  fi
  local file=$CLAUDE_ACCOUNTS_DIR/dirs
  mkdir -p "$CLAUDE_ACCOUNTS_DIR"
  touch "$file"

  # replace an existing entry for the same folder
  local tmp=$file.tmp.$$ p n
  : > "$tmp"
  while IFS=$'\t' read -r p n; do
    [[ ${${p/#\~/$HOME}%/} == "$PWD" ]] && continue
    printf '%s\t%s\n' "$p" "$n" >> "$tmp"
  done < "$file"
  printf '%s\t%s\n' "$PWD" "$name" >> "$tmp"
  mv "$tmp" "$file"

  print "Folder $PWD now uses '$name'."
  _claude_auth_chpwd
}

_claude_auth_cmd_status() {
  if [[ -z $CLAUDE_AUTH_NAME ]]; then
    print "account    : (none, using ~/.claude as if claude-auth were not installed)"
    print "config dir : ${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    return
  fi
  local email
  email=$(_claude_auth_email "$CLAUDE_AUTH_NAME")
  print "account    : $CLAUDE_AUTH_NAME${email:+ ($email)}"
  print "config dir : $CLAUDE_CONFIG_DIR"
  if [[ -n $CLAUDE_AUTH_PINNED ]]; then
    print "selected by: manual (pinned for this terminal)"
  else
    print "selected by: folder mapping"
  fi
}

_claude_auth_cmd_help() {
  cat <<'HELP'
Usage:
  claude-auth                      pick an account from a list (pinned for this terminal)
  claude-auth <name>               switch to the given account (pinned for this terminal)
  claude-auth add-account <name>   register an account and log in
  claude-auth add-dir <name>       use the given account in the current folder
  claude-auth status               show the current account
  claude-auth help                 show this help

Data lives in $CLAUDE_ACCOUNTS_DIR (default ~/.claude-accounts):
  <name>/     CLAUDE_CONFIG_DIR of each account
  dirs        folder -> account mapping (tab separated, longest match wins)
  .cache/     cached email addresses (delete to refresh)
HELP
}

# ---------------------------------------------------------------- entry point

claude-auth() {
  emulate -L zsh
  local cmd=$1
  case $cmd in
    "")            _claude_auth_cmd_list ;;
    add-account)   _claude_auth_cmd_add_account "$2" ;;
    add-dir)       _claude_auth_cmd_add_dir "$2" ;;
    status)        _claude_auth_cmd_status ;;
    help|-h|--help) _claude_auth_cmd_help ;;
    *)             _claude_auth_cmd_use "$cmd" ;;
  esac
}

# ---------------------------------------------------------------- hook

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _claude_auth_chpwd
_claude_auth_chpwd
