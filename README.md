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

**Debian/Ubuntu** — works, but the package can be outdated. Use the curl method below instead:
```sh
apt install chezmoi
```

**curl** — always installs the latest binary, recommended for Debian/Ubuntu and anything else:
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
```

### 2. Apply this repo

```sh
chezmoi init --apply accarin
```

Or combine install + init in one shot (curl only):
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
| apt | `apt upgrade chezmoi` |

---

## Cheat sheet

| Command | What it does |
|---|---|
| `chezmoi apply` | Apply all pending changes to `~` |
| `chezmoi apply --dry-run --verbose` | Dry run — show exactly what would change without touching anything |
| `chezmoi diff` | Preview what `apply` would change |
| `chezmoi add ~/.config/foo` | Track a new file |
| `chezmoi edit ~/.zshrc` | Edit the source file and apply on save |
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
├── .chezmoi.toml.tmpl          # Bootstraps chezmoi config, prompts for machine_type etc.
├── .chezmoiignore              # Conditionally ignores files per machine type
├── .chezmoiscripts/            # Scripts that run on apply (e.g. package installs)
├── dot_gitconfig.tmpl          # → ~/.gitconfig
├── dot_zshrc.tmpl              # → ~/.zshrc
└── dot_config/
    ├── fish/config.fish.tmpl   # → ~/.config/fish/config.fish
    ├── kitty/                  # → ~/.config/kitty/
    ├── niri/                   # → ~/.config/niri/ (skipped on servers)
    └── starship/               # → ~/.config/starship/
```

**Naming conventions** chezmoi uses to map source → target:

| Source name | Target name |
|---|---|
| `dot_foo` | `.foo` |
| `foo.tmpl` | `foo` (rendered as a [Go template](https://pkg.go.dev/text/template)) |
| `run_onchange_*.sh` | Script that runs when its content changes |

### Adding a new config file

```sh
# 1. Track the file
chezmoi add ~/.config/something/config

# 2. Optionally turn it into a template (adds .tmpl suffix)
chezmoi chattr +template ~/.config/something/config

# 3. Edit it
chezmoi edit ~/.config/something/config

# 4. Apply and verify
chezmoi apply && chezmoi diff
```

Inside templates, `{{ .machine_type }}` and other variables from `.chezmoi.toml.tmpl` are available. Use `chezmoi data` to see everything that's in scope.

To conditionally deploy a file only on certain machine types, add a rule to `.chezmoiignore`:

```
{{- if eq .machine_type "server" }}
.config/niri
{{- end }}
```
