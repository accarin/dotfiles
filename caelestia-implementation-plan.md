# Caelestia + chezmoi Implementation Plan

Status: **IMPLEMENTED (2026-08-12)** on `deep-thought` only. Fully
automated end-to-end (install-or-update, no manual step) — see §7. Rollout
to other machines: add `[machines.<hostname>.caelestia] enabled = true`.

## 1. Blocker question: is caelestia compatible with the current setup?

**Yes**, with two important caveats below. Caelestia is a Hyprland-based
desktop rice (a compiled QuickShell shell + a "dots" repo of app configs),
installed/updated by its own `caelestia` CLI. Like `niri`, plain `hyprland`,
and `gamescope-session-cachyos`, it's just another Wayland session selectable
at the greeter/TTY — only one compositor runs per login, so there's no
runtime conflict with niri or anything gaming-related.

The real risk isn't runtime compatibility, it's **file ownership**: the
`caelestia install`/`caelestia update` commands *unconditionally overwrite*
(delete + copy, no merge, no symlink — confirmed in
[`deployer.py`](https://github.com/caelestia-dots/cli/blob/main/src/caelestia/utils/dots/deployer.py))
whatever already lives at each component's destination path. Two of
caelestia's **default-enabled** components collide directly with files this
repo already manages via chezmoi:

| Caelestia component | Default? | Deploys to | Conflicts with |
|---|---|---|---|
| `fish` | on | `$XDG_CONFIG_HOME/fish` | [dot_config/fish/config.fish.tmpl](dot_config/fish/config.fish.tmpl), functions/ |
| `starship` | on | `$XDG_CONFIG_HOME/starship.toml` | [dot_config/starship/starship.toml.tmpl](dot_config/starship/starship.toml.tmpl) |
| `vscode` | **off** (opt-in) | `$XDG_CONFIG_HOME/Code/User/{settings,keybindings}.json` | [dot_config/Code/User/modify_settings.json](dot_config/Code/User/modify_settings.json) |
| `hypr` | on | `$XDG_CONFIG_HOME/hypr` | none today (no chezmoi-managed hypr config exists yet) — but claims this path permanently, see §3.3 |

Source: [manifest.toml](https://github.com/caelestia-dots/caelestia/blob/main/manifest.toml) (component list + dests).

**Conclusion:** caelestia is compatible *only if* we (a) disable the `fish`
and `starship` components on install/update, (b) never enable the
`vscode`/`vscodium` components, and (c) treat `~/.config/hypr` as fully
owned by caelestia from the moment `caelestia install` first runs.

## 2. What caelestia actually is (3 moving parts)

1. **`caelestia-shell`** (AUR) — the compiled QuickShell UI itself (bar,
   launcher, notifications, etc.).
2. **`caelestia-cli`** (AUR, already added to this repo's `AUR_PKGS`) — the
   `caelestia` command: controls the running shell (IPC), and also contains
   the `install`/`update` subcommands that manage the "dots" layer below.
3. **The "dots" repo** ([caelestia-dots/caelestia](https://github.com/caelestia-dots/caelestia))
   — a collection of app configs (hypr, fish, foot, btop, starship, thunar,
   firefox, etc.), each an opt-in/opt-out "component" in `manifest.toml`.
   `caelestia install` clones this repo and copies the enabled components'
   files into place; `caelestia update` pulls the latest revision and
   redeploys. Both are driven entirely by the AUR helper already configured
   in this repo (`paru` is even the upstream default —
   [`DEFAULT_AUR_HELPER = "paru"`](https://github.com/caelestia-dots/cli/blob/main/src/caelestia/utils/dots/packages.py)).

## 3. What's actually safe/designed to be hand-edited

Caelestia documents a small, **stable customization surface** that lives
under `$XDG_CONFIG_HOME/caelestia/` — a *different* directory from any
component's `dest`, so it is never touched by `install`/`update`'s deploy
step:

- `~/.config/caelestia/shell.json` — the shell's main config (wallpaper
  path, bar options, per-feature toggles, appearance scale, etc.). Not
  created by default; you write only the keys you want to override.
- `~/.config/caelestia/shell-tokens.json` — advanced design tokens
  (spacing/rounding/animation), rarely needed.
- `~/.config/caelestia/monitors/<name>/shell.json` (+ `shell-tokens.json`)
  — per-monitor overrides of the above.
- `~/.config/caelestia/cli.json` — CLI behavior (screenshot/record args,
  theming toggles, toggle-workspace app definitions, and even which dots
  repo URL/branch to track).
- `~/.config/caelestia/hypr-vars.lua` / `hypr-user.lua` — the officially
  documented hook points for your own Hyprland tweaks (monitor layout,
  default apps, extra binds), explicitly *not* overwritten by updates
  (unlike everything under `~/.config/hypr` itself).
- `~/.config/caelestia/templates/*` — user-defined output templates for the
  generated colour scheme.

**This directly answers the "does the JSON suffice" question: yes.** These
files are exactly the layer caelestia itself guarantees stays put across
`caelestia update` runs, and they're small/plain JSON+Lua — a great fit for
chezmoi templating (per-machine wallpaper paths, monitor names, etc.),
without chezmoi ever needing to know about (or fight over) the bulk of the
generated rice under `~/.config/hypr`, `~/.config/foot`, `~/.config/btop`,
etc.

### 3.1 What chezmoi should manage
- `~/.config/caelestia/shell.json`
- `~/.config/caelestia/cli.json`
- `~/.config/caelestia/hypr-vars.lua`
- `~/.config/caelestia/hypr-user.lua`
- (optionally, later) per-monitor overrides / templates, if/when needed

### 3.2 What caelestia-cli should manage (hands off in chezmoi)
- Everything under component `dest`s: `~/.config/hypr`, `~/.config/foot`,
  `~/.config/btop`, `~/.config/fastfetch`, `~/.config/Thunar`,
  `~/.config/uwsm`, firefox profile files, etc.
- All packages listed in `manifest.toml` for enabled components.

### 3.3 Consequence for `~/.config/hypr`
Once `caelestia install` runs with the (default-on) `hypr` component
enabled, that directory is fully regenerated on every `caelestia update`.
**Do not** create a separate chezmoi-managed `dot_config/hypr/` in this repo
— any hand-edits there would be silently clobbered on the next update, and
would fight with chezmoi's own state tracking (chezmoi would see "drift"
and could try to revert caelestia's copy back to its own on the next
`chezmoi apply`). Use `hypr-vars.lua` / `hypr-user.lua` instead.

## 4. Options to discuss

### 4.1 Package installation ownership

| Option | Description | Pros | Cons |
|---|---|---|---|
| **A — Let `caelestia install`/`update` own all dots-related packages** (recommended) | Our `AUR_PKGS` only ever needs `caelestia-cli` (already added). `manifest.toml` (upstream-versioned) drives what else gets installed, per enabled component. | Zero drift vs. upstream; no manual package-list maintenance as caelestia adds/removes deps over time. | Package installs happen outside chezmoi's own pacman/paru calls — less "everything in one script" purity. |
| B — Mirror manifest packages into our own `PACMAN_PKGS`/`AUR_PKGS` | Hand-copy today's package list for the components we want. | Everything visible in one script. | Silently drifts the moment upstream adds/renames/removes a dependency; we'd have to enable *zero* components in `caelestia install` to avoid double-deploying config files, defeating the point of using the CLI at all. |

**Recommendation: Option A.**

**I accept 4.1 Option A as the recommended approach.** It ensures that package management remains consistent with upstream changes and reduces the maintenance burden on our side.

### 4.2 First-time install vs. ongoing updates

**Revised (corrected 2026-08-12; originally recommended manual-only, see
§7 correction note).** `caelestia install` looked like a heavyweight,
semi-interactive wizard (component picker, full `~/.config` backup prompt,
legacy-migration prompt) — but reading caelestia-cli's own source
([`io.py`](https://github.com/caelestia-dots/cli/blob/main/src/caelestia/utils/io.py),
[`install.py`](https://github.com/caelestia-dots/cli/blob/main/src/caelestia/subcommands/install.py))
shows `--noconfirm` calls `disable_input()`, which makes every `confirm()`/
`pause()` call short-circuit to its default instead of blocking, and the
component-picker prompt is skipped entirely whenever `--enable-components`
or `--disable-components` is explicitly passed (which we always do). So
`caelestia install --aur-helper paru --disable-components fish,starship
--noconfirm` is just as deterministic and non-interactive as `caelestia
update` — there's no real technical reason to keep it manual.

**Recommendation:** automate both. The onchange script checks whether
`${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/dots-state.json` exists
(created by `caelestia install` on first success): if missing, run
`install`; otherwise run `update`. Same flags either way
(`--aur-helper paru`, `--noconfirm`; `install` additionally gets
`--disable-components fish,starship`).

### 4.3 Update automation strategy ("reliably, but only when needed")

| Option | Description | Pros | Cons |
|---|---|---|---|
| A — Fully manual | Never automate; run `caelestia update` yourself whenever you feel like it. | Zero risk of surprise breakage. | Easy to forget; not "managed" like everything else in this repo. |
| **B — Version-pinned `run_onchange_` script (recommended)** | Add `[caelestia] pinned_rev = "..."` to `.chezmoidata.toml` (same opt-in-per-machine pattern as `u2f`/`ssh_agent`/`dot`). A `run_onchange_update-caelestia.sh.tmpl` embeds `{{ .caelestia.pinned_rev }}` in a comment, so chezmoi's content-hash (and thus the re-run trigger) only changes when *you* bump that value in a commit. The script body just runs `caelestia update --aur-helper paru --noconfirm`. | Fits this repo's existing conventions exactly (see `run_onchange_install-packages.sh.tmpl`'s own "re-runs only when this file's content changes" pattern). Deterministic: update happens exactly once per deliberate version bump, reviewable in a git diff, and reproducible across machines running `chezmoi apply`. | You do have to remember to bump the pin occasionally (but that's the point — "only when needed"). |
| C — systemd timer / cron, unconditional periodic `caelestia update` | e.g. weekly timer. | Always fresh without thinking about it. | Can rewrite your running Hyprland session's config/shell out from under you at a random moment (mid-use); no controlled rollout; not reviewable via git like everything else here. |

**Recommendation: Option B.** It mirrors the exact mechanism this repo
already uses for its main package-install script (re-run only on content
change) and for opt-in features (`u2f`, `ssh_agent`, `dot`'s per-machine
`enabled` flag + override table).

**I accept 4.3 Option B as the recommended approach.** It provides a good balance between automation and control, ensuring that updates are applied in a predictable manner without risking unexpected changes during active sessions.

## 5. Recommended overall design (pending your sign-off)

1. `.chezmoidata.toml`: add
   ```toml
   [caelestia]
   enabled    = false      # opt-in per machine, like u2f/ssh_agent/dot
   pinned_rev = ""         # bump to trigger `caelestia update` on next apply
   aur_helper = "paru"
   ```
   plus `[machines.<hostname>.caelestia] enabled = true` overrides on the
   machines that actually run caelestia.
2. `dot_config/caelestia/`: chezmoi-managed templates for exactly the 4
   files in §3.1 (`shell.json.tmpl`, `cli.json.tmpl`, `hypr-vars.lua.tmpl`,
   `hypr-user.lua.tmpl`), gated in `.chezmoiignore` the same way as
   `.config/hypr` today (ignored on `server`, and additionally ignored
   when `caelestia.enabled` resolves false for the current machine).
3. `.chezmoiscripts/run_onchange_setup-caelestia.sh.tmpl`: resolves
   `caelestia.enabled` the same way `run_onchange_setup-ssh-agent.sh.tmpl`
   resolves `ssh_agent.enabled`; if enabled, embeds `pinned_rev` in a
   comment, then checks for `dots-state.json` to decide `caelestia install
   --disable-components fish,starship` (first run) vs. `caelestia update`
   (every run after) — both `--aur-helper {{ .caelestia.aur_helper }}
   --noconfirm`. Fully automated, no manual step (see §4.2 correction).
4. Document the automated behaviour (and the `--disable-components
   fish,starship` rationale) in this repo's README, so it isn't forgotten
   on a freshly-provisioned machine.

## 6. Open questions for you

- Which machine(s) should get `caelestia.enabled = true` first? **Answer:** deep-thought only for now, until I've verified the install/update process works as expected. Then we can roll it out to other machines.
- Are you fine with permanently ceding `~/.config/hypr` to caelestia's
  installer (§3.3), or did you want a hand-written Hyprland config
  independent of caelestia on some machine? **Answer:** Works for me. I don't want to maintain a separate Hypr config, and I like caelestia's default layout.
- Any objection to disabling `fish`/`starship` components specifically (vs.
  e.g. instead migrating our fish/starship config *into* caelestia's dots
  fork)? Disabling is the low-effort, low-risk default; forking/upstreaming
  is more work but would consolidate everything under caelestia's own
  update mechanism. **Answer:** Disabling is fine for now. BUT, I want you to research what we'd lose by disabling starship/fish. And replicate it to the best of our abilities in our own shell/starship config. It must not match 1:1, but let's try to be as close as possible.

## References

- https://github.com/caelestia-dots/shell (shell README: install, configuring, FAQ)
- https://github.com/caelestia-dots/cli (CLI README: usage, `cli.json`, dependencies)
- https://github.com/caelestia-dots/caelestia (dots meta-repo README, `manifest.toml`)
- https://github.com/caelestia-dots/cli/blob/main/src/caelestia/subcommands/install.py
- https://github.com/caelestia-dots/cli/blob/main/src/caelestia/utils/dots/deployer.py
- https://github.com/caelestia-dots/cli/blob/main/src/caelestia/parser.py
- https://github.com/caelestia-dots/cli/blob/main/src/caelestia/utils/dots/packages.py

## 7. Implementation notes (what actually landed)

- `.chezmoidata.toml`: `[caelestia]` (enabled=false, pinned_rev="0",
  aur_helper="paru") + `[machines.deep-thought.caelestia] enabled = true`.
- `.chezmoiignore`: `.config/caelestia` gated on `machine_type=="server"` OR
  `caelestia.enabled` resolving false for the current machine (same
  hasKey-chain pattern as `ssh_agent`/`dot`).
- `dot_config/caelestia/{shell,cli}.json.tmpl` and `hypr-{vars,user}.lua.tmpl`
  added as minimal valid placeholders (`{}` / `return {}`) rather than
  guessing real values — fill these in for real once `caelestia install` has
  run on deep-thought and the generated examples can be inspected.
- `.chezmoiscripts/run_onchange_setup-caelestia.sh.tmpl` added; branches on
  `${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/dots-state.json`:
  missing → `caelestia install --disable-components fish,starship
  --noconfirm` (first run), present → `caelestia update --noconfirm`
  (every run after). Re-triggers only when `pinned_rev` is bumped.
  **Correction (same day):** originally shipped as
  `run_onchange_update-caelestia.sh.tmpl`, always running `update` and
  documenting `install` as a manual step — this broke on the very first
  real `chezmoi apply` (`caelestia update` fatally errors when dots were
  never installed, since `dots-state.json` didn't exist yet), which is
  what prompted re-reading caelestia-cli's source and finding `--noconfirm`
  already makes `install` fully non-interactive too. Renamed + rewritten
  to the install-or-update branch described above; see §4.2.
- **fish/starship replication** (researched from caelestia's actual dots
  repo, github.com/caelestia-dots/caelestia/blob/main/fish/config.fish +
  starship.toml) — added to this repo's own `dot_config/fish/config.fish.tmpl`
  and `dot_config/starship/starship.toml.tmpl` rather than caelestia's:
  - fish: `direnv hook fish` (added `direnv` package to `install-packages`
    script), full set of caelestia's git `abbr`s (replacing the previous
    plain `gs`/`gp`/`gl` aliases — **note: `gl` now means `git log`, not
    `git pull`; use the new `gpl` abbr for pull**), `eza --icons
    --group-directories-first` on `ls`/`ll`/`la`, an OSC 133 prompt-marking
    function (kitty/foot "jump between prompts"), and an optional
    `fastfetch` call in the greeting (guarded, only fires if installed).
  - starship: adopted caelestia's character/directory/git/cmd_duration/
    username/sudo symbols and styling, plus a new `battery` module on the
    notebook branch — deliberately NOT the ~50 per-language version modules
    from upstream's `right_format` (not relevant here, wrong direction of
    "closeness" for this repo's minimalist style).
  - **Accepted gap**: caelestia's dynamic OSC-sequence colour theming
    (`cat ~/.local/state/caelestia/sequences.txt`, driven by its live
    Material-You wallpaper-based scheme engine) is NOT replicated —
    inherently tied to the running caelestia shell, no meaningful way to
    replicate outside it.

### 7.1 Bug: `caelestia install`'s own backup crashes on special files

First real `caelestia install` run crashed: its `create_backup()` does
`shutil.copytree(config_dir, config_backup_dir, symlinks=True)`, and
Python's `copytree` cannot copy special files (sockets/FIFOs) — it hit a
live Proton Pass IPC socket under `~/.config` and raised `shutil.Error`,
uncaught, killing the whole `caelestia install` (and thus the whole
`chezmoi apply`) with exit 1. This isn't Proton-Pass-specific: *any* app
with an IPC socket under `~/.config` at install time (gpg-agent, keyring
daemons, etc.) triggers the identical crash — structurally fragile against
any live desktop, not a one-off edge case.

**Considered and rejected: btrfs/snapper as a second line of defense.**
Checked this machine's actual snapper setup: only a `root` config exists
(`snapper list-configs`), and `/home` is a separate btrfs subvolume
(`@home`) — deliberately not covered by the root config (so a system
rollback doesn't also revert personal files). So the pre/post-pacman-
transaction snapshots already visible in `chezmoi apply` output do **NOT**
cover `~/.config` at all today. Using snapper here for real would need (a)
a brand new `home` snapper config, and (b) our own explicit pre/post
snapshot calls around this script (snap-pac's hook only wraps pacman
transactions, and `deploy_configs()` — the step that actually touches
`~/.config` — runs after packages, outside any pacman transaction/hook).
Decided this is out of scope: a legitimate general disaster-recovery
feature worth having eventually, but a standalone infra decision, not
something to bolt on narrowly just for this one script.

**Fix chosen (matches §6's original "Option A — skip the backup"):**
pre-create `~/.config.bak` (`mkdir -p`, idempotent) immediately before
calling `caelestia install`. Under `--noconfirm`, `create_backup()`'s first
confirm ("Back up?", default=True) still fires, but since the backup dir
now already exists, the SECOND confirm ("already exists, overwrite?",
default=**False**) takes over and short-circuits to "Not creating backup."
— `shutil.copytree` is never called, no crash, and everything worth
protecting (fish/starship/vscode) is untouched/chezmoi-managed anyway.

**Rejected alternative: drop `--noconfirm` and pipe answers
(`printf '\nn\n' | caelestia install ...`) to explicitly answer "no" to just
the backup prompt.** Looked plausible at first (only 2 blocking prompts in
a non-legacy install: `pause()`'s Enter + the backup `confirm()`) but
rejected after reading `install.py`/`packages.py` more closely: the single
`--noconfirm` CLI flag is threaded into `PackageInstaller.get(helper,
self.args.noconfirm)`, which sets `self.flags = ["--noconfirm"] if
noconfirm else []` on the underlying `paru -S ...` call — i.e. dropping
`--noconfirm` to get interactive backup answers would ALSO make every
package install interactive (unpredictable prompt count, unsafe for an
unattended script). The two behaviours share one flag; you can't get
non-interactive packages with an interactive backup prompt via CLI flags
alone. The `mkdir -p ~/.config.bak` pre-seed avoids this coupling entirely.

**Side note:** despite the crash, this machine's `~/.config.bak` turned out
to be a genuinely complete-ish backup, not partial junk —
`shutil.copytree` collects per-file errors into a list and only raises at
the very end, so every file except the one unreadable socket was actually
copied. Left in place (harmless, arguably useful) rather than deleted.

### 7.2 Package conflict: `pipewire` component vs. CachyOS's own PipeWire build

After fixing §7.1, the very next `caelestia install` attempt failed during
package installation: caelestia's default-on `pipewire` component wants
`pipewire-jack`, which conflicts with the already-installed `jack2` (both
`Provide: jack`). Removing `jack2` (`sudo pacman -Rdd jack2`) "succeeded"
but then `pipewire-jack` *still* couldn't install:

```
warning: pipewire: local (1:1.6.8-1.2) is newer than extra (1:1.6.8-1)
```

Root cause: this machine's entire PipeWire stack (`pipewire`,
`libpipewire`, `pipewire-audio`, `pipewire-alsa`, `pipewire-pulse`) is a
CachyOS-specific rebuild (`1:1.6.8-1.2`, from `cachyos-extra-znver4`) that
CachyOS has **not** rebuilt `pipewire-jack` to match — the only
`pipewire-jack` available is vanilla Arch's older `extra` build
(`1:1.6.8-1`). Installing it would mean downgrading the whole
CachyOS-optimized PipeWire stack to vanilla Arch's, purely to satisfy
caelestia's manifest. Not worth it — this machine's PipeWire setup already
works and is ahead of what caelestia would install anyway.

Side effect requiring cleanup: `pacman -Rdd jack2` skips dependency
checks, so it left real hard dependencies broken (`pacman -Dk` showed
`missing 'jack'/'libjack.so=0-64' dependency` for `ffmpeg`, `fluidsynth`,
`mpv`, `portaudio`, `vlc-plugin-jack`) — reinstalling `jack2` was required
to restore them, independent of the caelestia question.

**Fix:** added `pipewire` to the `--disable-components` list (now
`fish,starship,pipewire`) — same treatment as fish/starship: this
machine's PipeWire stack is already complete and chezmoi/pacman-managed
outside caelestia, so caelestia should never touch it. This is a
per-machine consideration (a machine *without* a pre-existing PipeWire
setup, or one where CachyOS's rebuild happens to match, wouldn't hit this)
— re-evaluate `--disable-components` per machine when rolling out beyond
deep-thought.

### 7.3 caelestia-shell wouldn't render: `noctalia-qs` vs. mainline Quickshell

After install succeeded, Hyprland/caelestia's compositor worked but no bar
ever appeared. `caelestia shell -d` failed silently; running `qs -c
caelestia log` directly showed the real error:

```
ERROR: Unrecognized pragma "DefaultEnv QS_NO_RELOAD_POPUP=1"
```

Root cause: `qs` on this machine was **`noctalia-qs`** — a fork of
Quickshell that this repo's *existing* niri setup depended on (via the old,
[GitHub-archived (2026-07-15) v4 `noctalia-shell`](https://github.com/noctalia-dev/noctalia-shell)).
`noctalia-qs` `Provides`/`Conflicts With` `quickshell`/`quickshell-git`, so
only one of `{noctalia-qs, quickshell, quickshell-git}` can ever be
installed — and it's 52 commits behind mainline Quickshell, so it will
never support the pragma caelestia-shell's QML needs.

**Real fix (not a workaround): migrate niri off the archived v4 to the new
native Noctalia v5** ([`noctalia`](https://docs.noctalia.dev/), official
Arch `extra` package) — a from-scratch shell with **zero Quickshell
dependency**. This eliminates the conflict at the root instead of trading
one shell off against the other:
- `noctalia` (v5) for niri — no Quickshell dependency, no conflict.
- `quickshell-git` (AUR, mainline) for caelestia-shell.

Migration performed:
- `dot_config/niri/cfg/autostart.kdl.tmpl`: `spawn-sh-at-startup "qs -c
  noctalia-shell"` → `spawn-at-startup "noctalia"`.
- `dot_config/niri/cfg/keybinds.kdl.tmpl`: all `qs -c noctalia-shell ipc
  call <x> <y>` rewritten to v5's `noctalia msg <command>` IPC (mapped
  from [docs.noctalia.dev/noctalia/ipc/](https://docs.noctalia.dev/noctalia/ipc/):
  `panel-toggle launcher`, `session lock`, `panel-toggle session`,
  `volume-up/down/mute`, `mic-mute`, `media next/previous/toggle`,
  `brightness-up/down`).
- `dot_config/niri/cfg/layout.kdl.tmpl`, `dot_config/niri/README.md`:
  comment/description updates only.
- `.chezmoiscripts/run_onchange_install-packages.sh.tmpl`: added
  `noctalia` (PACMAN_PKGS, official `extra` repo) and `aur/quickshell-git`
  (AUR_PKGS) — the `aur/` prefix is mandatory, see the gotcha below.
- Layer-shell rule `layer-rule { match namespace="^noctalia-wallpaper*" }`
  in `rules.kdl.tmpl` needed no change — v5 kept the same `noctalia-`
  namespace prefix convention.

**Live package migration gotcha (important for future machines):**
`noctalia-qs` (from the `cachyos` repo) declares `Provides:
quickshell-git`, so `paru -S quickshell-git` (or bundled with other
packages) silently resolves to **reinstalling noctalia-qs** — it never
even considers the real AUR `quickshell-git` package, since pacman treats
the dependency name as already satisfied. Plain removal-then-reinstall
didn't help either, for the same reason. The only way to force the real
AUR package: explicitly qualify the repo with `paru -S aur/quickshell-git`
(prompts to pick between AUR providers `quickshell-git` /
`mainstream-quickshell-git` — choose `quickshell-git`), after removing
`noctalia-qs` first (`sudo pacman -Rdd noctalia-qs` — safe once `noctalia`
v5 and `caelestia-shell` no longer need it; verify with `pacman -Qi
noctalia-qs | grep Required` first).
- After install, restart the shell: `caelestia shell -k; caelestia shell -d`.
- Old archived v4 `noctalia-shell` package (`4.7.7-3`) was left installed
  but orphaned (`Required By: None`) — safe to `pacman -Rns` later,
  not urgent.

**Correction (same day, caught by user review):** the fix above was first
applied only interactively in the terminal — `run_onchange_install-
packages.sh.tmpl`'s `AUR_PKGS` array still had plain `quickshell-git`,
which would silently reinstall `noctalia-qs` again on a fresh `chezmoi
apply` (confirmed via `paru -Sp quickshell-git` resolving to noctalia-qs's
cached `.pkg.tar.zst` even with noctalia-qs already removed). Fixed the
array entry itself to `aur/quickshell-git`, and verified `paru -S --needed
--noconfirm aur/quickshell-git` resolves correctly non-interactively (at
least when the package is already installed/up to date — the interactive
"pick a provider" prompt that appears on a truly first-ever install wasn't
re-tested cold, since that would've meant uninstalling the working
quickshell-git; `--noconfirm` is expected to auto-pick the stated default
provider the same way it does for other numbered/Y-n prompts, consistent
with AUR helper convention, but flag this as the one part of this fix not
empirically re-verified end-to-end — worth a quick sanity check the first
time this script runs on a brand new machine).

### 7.4 Reproducing niri's keybinds + app defaults on Hyprland

Per user request: niri is the leading/authoritative keybind config; made
Hyprland (via `hypr-vars.lua`/`hypr-user.lua`) match it as closely as
possible, remapping any of caelestia's own conflicting defaults (documented
inline in both files) rather than dropping niri's key choice. Also set
`terminal = "kitty"` and `browser = "brave"` in `hypr-vars.lua` to match
niri's own app choices (previously caelestia defaults: foot, firefox).

Conflicts found and resolved (caelestia default moved, niri's key wins):
`kbWindowFullscreen` (SUPER+F → SUPER+SHIFT+F), `kbTerminal` (SUPER+T →
SUPER+Return), `kbBrowser` (SUPER+W → SUPER+B), `kbEditor` (SUPER+C →
SUPER+ALT+C), `kbShowPanels` (SUPER+K → CTRL+SUPER+K), `kbRestoreLock`
(SUPER+ALT+L → CTRL+SUPER+ALT+L), `kbLock` (SUPER+L → SUPER+ALT+L, now
matching niri's own lock key), `kbGoToWsGroup` (CTRL+SUPER →
CTRL+SUPER+SHIFT prefix). A few kept their old key *and* gained niri's as
an alternate (`kbToggleGroup`, `kbCenterWindow`, `kbSession`,
`kbLauncher`).

New bindings added directly in `hypr-user.lua` (things with no existing
caelestia var to extend): vim-style SUPER+H/J/K/L focus aliases,
CTRL+SUPER+arrows/HJKL → window move (dwindle has no separate
"column reorder" concept like niri's scrolling layout, so this reuses the
same dispatcher as SUPER+SHIFT+arrows), CTRL+SUPER+1-9/0 → move window to
workspace N (freed by the `kbGoToWsGroup` remap), SUPER+F → pseudotile
toggle (closest dwindle analog to niri's column-width-preset cycling, not
a true 1:1 match), SUPER+SHIFT+P → power-off-monitors, CTRL+SHIFT+1/2 →
caelestia screenshot commands.

Deliberately not reproduced (documented inline): `Mod+F1`/`Mod+Escape`/
`Mod+O` (niri-specific features, no Hyprland equivalent); column
first/last and wheel-scroll bindings (scrolling-layout-specific, no
dwindle equivalent); monitor-move/monitor-focus bindings (this machine has
one monitor — SUPER+SHIFT+H/J/K/L deliberately left unbound to reserve
them if a second monitor is added later); `Mod+Tab` (no clean equivalent
found); `Ctrl+Alt+Delete` (niri hard-quits/logs out on this key; kept
caelestia's safer confirmable session-menu instead, reproduced niri's
*separate* session-menu key, Mod+Shift+Q, alongside it).

