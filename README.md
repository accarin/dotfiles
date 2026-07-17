# dotfiles

This is just my little dotfiles configuration. But if you wanna know more: I use dotfiles because I got tired of setting up machines from scratch and watching my carefully tuned shell prompt vanish into the void. [chezmoi](https://www.chezmoi.io/) makes the whole thing actually manageable: it handles templates, machine-specific logic, and keeps everything version-controlled. Feel free to **fork or clone this** and make it your own.

---

## What's chezmoi?

[chezmoi](https://www.chezmoi.io/) is a dotfile manager that lives in `~/.local/share/chezmoi/`, tracks your configs as a Git repo, and deploys them to your home directory — with templating, secrets support, and per-machine logic baked in. [Read the full docs here.](https://www.chezmoi.io/user-guide/command-overview/)

---

## Onboarding a new machine

### 1. Install chezmoi

chezmoi is available in a lot of package managers ([full list](https://www.chezmoi.io/install/)). Pick your poison. A short summary for distros I actually use:

**Arch-based** — preferred, always up to date:
```sh
pacman -S chezmoi
```

**Debian/Ubuntu** — always installs the latest binary, required for Debian/Ubuntu and anything else without a native package:
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
```

### 2. Apply this repo

> [!IMPORTANT]
> If you just installed via curl, `~/.local/bin` isn't on `PATH` yet in the current shell (it only gets added once this repo's shell config is applied). Use the full path for this first call:
> ```sh
> ~/.local/bin/chezmoi init --apply accarin
> ```
> New shells will have `chezmoi` on `PATH` automatically from then on.

```sh
chezmoi init --apply accarin
```

Or combine install + init in one shot (curl only) — no PATH issue since it's called directly:
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply accarin
```

chezmoi will prompt you for a few things:

| Prompt | Options |
|---|---|
| `machine_type` | `workstation` · `gaming` · `notebook` · `server` · `wsl` |
| `git_name` | Your full name for Git |
| `git_email` | Your Git email |

That's it. chezmoi applies all files, runs the package-install script, and pushes the state back to Git automatically.

### Keeping chezmoi itself up to date

| Method | Update command |
|---|---|
| pacman | `pacman -Syu` |
| curl / binary | `chezmoi upgrade` |

---

## Cheat sheet

| Command | What it does |
|---|---|
| `chezmoi apply` | Apply all pending changes to `~` |
| `chezmoi apply --dry-run --verbose` | Dry run — show exactly what would change without touching anything |
| `chezmoi diff` | Preview what `apply` would change |
| `chezmoi add ~/.config/foo` | Track a new file |
| `chezmoi edit ~/.bashrc` | Edit the source file and apply on save |
| `chezmoi re-add` | Sync source with changes made directly in `~` |
| `chezmoi update` | Pull latest from Git and apply |
| `chezmoi cd` | Jump into the source repo |
| `chezmoi status` | Show which files are out of sync |
| `chezmoi data` | Inspect template variables (machine type, etc.) |
| `chezmoi execute-template < file.tmpl` | Debug a template |
| `chezmoi doctor` | Check for common config issues |
| `chezmoi init --apply <repo>` | Bootstrap a new machine from a repo |
| `chezmoi unmanage ~/.config/foo` | Stop tracking a file |

### Shell aliases

Both fish and zsh ship with these shortcuts out of the box:

| Alias | Expands to |
|---|---|
| `cm` | `chezmoi` |
| `cmu` | `chezmoi update -v` |
| `cmt` | `chezmoi apply --dry-run --verbose` |
| `cma` | `chezmoi apply -v` |
| `cmd` | `chezmoi diff` |

---

## How this repo works

```
~/.local/share/chezmoi/
├── .chezmoi.toml.tmpl        # Init prompts (machine_type, git identity); git autoCommit/autoPush
├── .chezmoidata.toml         # Static data: FIDO2 key pool, ssh-agent flags, SSH host entries
├── .chezmoiignore            # Gates files per machine_type (see below)
├── .chezmoiremove            # Deletes retired targets (e.g. legacy ~/.zshrc)
├── .chezmoiscripts/          # run_onchange_ scripts (see below)
├── dot_bashrc.tmpl           # → ~/.bashrc (server + wsl only)
├── dot_gitconfig.tmpl        # → ~/.gitconfig
├── dot_face                  # → ~/.face (avatar)
├── dot_config/
│   ├── fish/                 # → ~/.config/fish/ (desktops only; eza/bat/rg/fd aliases, functions)
│   ├── kitty/                # → ~/.config/kitty/
│   ├── niri/                 # → ~/.config/niri/ (desktops only; modular cfg/*.kdl, own README)
│   └── starship/             # → ~/.config/starship/ (desktops only)
└── private_dot_ssh/
    ├── modify_private_config # Generates the managed part of ~/.ssh/config
    └── private_sockets/      # Keeps ~/.ssh/sockets/ around (ControlMaster)
```

**Naming conventions** chezmoi uses to map source → target:

| Source name | Meaning |
|---|---|
| `dot_foo` | `.foo` |
| `foo.tmpl` | Rendered as a [Go template](https://pkg.go.dev/text/template) |
| `private_foo` | Mode 0600/0700 |
| `modify_foo` | Template that rewrites only part of an existing target file |
| `empty_foo` | Deploy even if empty (used as a `.keep`) |
| `run_onchange_*.sh` | Script that re-runs whenever its content changes |

### Per-machine logic

Two mechanisms, both driven by data:

- **`machine_type`** (asked once at init) gates whole files via `.chezmoiignore`: desktops (`workstation`/`gaming`/`notebook`) get fish + starship + niri; `server`/`wsl` get bash instead.
- **Per-hostname overrides** in `.chezmoidata.toml`: a `[machines.<hostname>.…]` table replaces the global value of the same key. Used to enable U2F/ssh-agent or add SSH hosts on specific boxes only.

### Scripts (`.chezmoiscripts/`)

| Script | Does |
|---|---|
| `install-packages` | pacman on Arch desktops, apt on Debian servers/wsl; sets login shell |
| `setup-pam-fido2` | Deploys pam-u2f keys for sudo/login (machines with `u2f.enabled`) |
| `setup-ssh-agent` | Enables the systemd user `ssh-agent.socket` (machines with `ssh_agent.enabled`) |

### SSH config generation

`private_dot_ssh/modify_private_config` rebuilds the managed section of `~/.ssh/config` from the `ssh_hosts` entries in `.chezmoidata.toml` (keyed by the OS username chezmoi runs as), adds `AddKeysToAgent yes` where the agent is enabled, and never touches anything below the `### MANUAL OVERRIDE BLOCK ###` marker.

### Adding a new config file

```sh
chezmoi add ~/.config/something/config       # 1. Track it
chezmoi chattr +template ~/.config/something/config  # 2. Optional: make it a template
chezmoi edit ~/.config/something/config      # 3. Edit the source
chezmoi apply && chezmoi diff                # 4. Apply and verify
```

Inside templates, `{{ .machine_type }}` and everything from `.chezmoi.toml.tmpl` / `.chezmoidata.toml` is in scope — inspect with `chezmoi data`. To gate a file per machine type, add a rule to `.chezmoiignore`:

```
{{- if eq .machine_type "server" }}
.config/niri
{{- end }}
```
