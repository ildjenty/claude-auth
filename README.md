# claude-auth

Switch Claude Code accounts per terminal session, and pick which account each folder uses. zsh only.

## How it works

Claude Code keeps its login state in a config directory (`CLAUDE_CONFIG_DIR`, default `~/.claude`).
On macOS the Keychain entry is also scoped to that directory.
This tool gives each account its own directory under `~/.claude-accounts/<name>/` and switches accounts by changing `CLAUDE_CONFIG_DIR`.

```
~/.claude-accounts/
├── claude-auth.zsh   # the tool
├── personal/         # an account created with add-account
│   ├── settings.json -> ~/.claude/settings.json   # shared settings are symlinked
│   ├── keybindings.json -> ~/.claude/keybindings.json
│   ├── skills -> ~/.claude/skills
│   └── ...           # history, sessions and memory are per account
├── work/             # another account
├── dirs              # folder -> account mapping
└── .cache/           # cached email addresses
```

`~/.claude` itself is not touched. It is only used as the source of shared settings, and it is what Claude Code falls back to when no account is selected.

## Setup

```sh
sh install.sh          # copy into ~/.claude-accounts
sh install.sh --link   # symlink to the file in this repo instead (follows updates)
```

`install.sh` does the following:

- creates `~/.claude-accounts/`
- places `claude-auth.zsh` there
- appends `source ~/.claude-accounts/claude-auth.zsh` to `.zshrc` (skipped if already present)

Open a new terminal or re-source `.zshrc` afterwards.

## Usage

```
claude-auth                      pick an account from a numbered list
claude-auth <name>               switch to the given account
claude-auth add-account <name>   register an account (creates the directory, then logs in via browser)
claude-auth add-dir <name>       use the given account in the current folder
claude-auth status               show the current account
claude-auth help                 show help
```

`<name>` is a short label you choose (letters, digits, hyphen, underscore).

### Typical flow

```sh
claude-auth add-account personal # register your existing account under a name (logs in again once)
claude-auth add-account work     # register a second account
cd ~ && claude-auth add-dir personal        # use personal everywhere under your home folder...
cd ~/projects/acme && claude-auth add-dir work   # ...except here, where work is used
claude                           # starts with the account mapped to the current folder
```

Every account, including the one you already use, is registered with `add-account`. The existing login in `~/.claude` cannot be reused because the Keychain entry is tied to the config directory, so you log in once more when registering it.

## Switching rules

- **Folder mapping**: on every `cd`, the longest matching entry in `~/.claude-accounts/dirs` is applied. This also runs once when the shell starts.
- **No match**: `CLAUDE_CONFIG_DIR` is unset and Claude Code behaves as if this tool were not installed, using `~/.claude`. To avoid this, map your home folder to an account as shown above.
- **Manual selection**: `claude-auth` or `claude-auth <name>` pins the account for that terminal, so `cd` no longer changes it. Open a new terminal to go back to folder mapping.
- The current account name is exported as `CLAUDE_AUTH_NAME`, in case you want it in your prompt.

## Mapping file format

`~/.claude-accounts/dirs` is tab separated, one `folder<TAB>account` pair per line. `~` expands to `$HOME`. Lines starting with `#` are comments.

```
~	personal
~/projects/acme	work
```

## Notes

- A running Claude Code session is not affected. Restart `claude` after switching.
- `settings.json` and friends are shared via symlinks. If Claude Code or another tool replaces the file wholesale, the symlink becomes a regular file and sharing silently stops. Recreate the symlink if that happens.
- `skills/` is shared, so skills synced by one account are visible to the others. To keep them separate, replace the `~/.claude-accounts/<name>/skills` symlink with a real directory.
- Email addresses shown in the list are cached in `.cache/`. Delete the cache file if you log in as a different user.
- On Linux the auth token is stored in plain text at `<config dir>/.credentials.json`. Do not put `~/.claude-accounts/` in a synced folder or under version control.

## License

MIT. See [LICENSE](LICENSE).
