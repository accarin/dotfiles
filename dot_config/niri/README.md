# Niri Configuration

Personal niri config built on top of [noctalia-shell](https://docs.noctalia.dev/).
Config is split into `cfg/` partials and included from `config.kdl`.

---

## Keybinding changes from niri defaults

### Applications

| Bind | Action | Default |
|---|---|---|
| `Mod+Space` | Open app launcher | *(not bound)* |
| `Mod+Return` | Open terminal (Alacritty) | `Mod+T` |
| `Mod+B` | Open browser (Firefox) | *(not bound)* |
| `Mod+E` | Open file manager (Nautilus) | *(not bound)* |
| `Mod+Alt+L` | Lock screen | *(not bound)* |
| `Mod+Shift+Q` | Session menu | *(not bound)* |

### Layout

| Bind | Action | Default |
|---|---|---|
| `Mod+F` | Expand column to available width | `Mod+Ctrl+F` |
| `Mod+Shift+F` | Toggle fullscreen | `Mod+F` |
| `Mod+W` | Toggle column tabbed display | *(not bound)* |
| `Mod+T` | Toggle floating | *(not bound)* |
| `Mod+C` | Center column | *(not bound)* |
| `Mod+Ctrl+C` | Center visible columns | *(not bound)* |

### Focus & Movement

Vim keys (`H/J/K/L`) are provided as aliases for all arrow-key binds.

| Bind | Action | Notes |
|---|---|---|
| `Mod+H/J/K/L` or `Mod+←/↓/↑/→` | Focus column/window | Vim + arrow aliases |
| `Mod+Ctrl+H/J/K/L` or `Mod+Ctrl+Arrows` | Move column/window | Vim + arrow aliases |
| `Mod+Shift+H/J/K/L` | Focus monitor | Replaces default `Mod+Shift+Arrows` |
| `Mod+Shift+Arrows` | Move column to monitor | Default was focus monitor |
| `Mod+Shift+Ctrl+Arrows` | Focus monitor (arrow fallback) | Replaces default move-to-monitor |

### UI

| Bind | Action | Default |
|---|---|---|
| `Mod+F1` | Show hotkey overlay | `Mod+Shift+?` / `Mod+Shift+Escape` |
| `Mod+O` | Toggle overview | *(not bound)* |
| `Mod+Escape` | Toggle keyboard shortcut inhibit | *(not bound)* |

### Screenshots

| Bind | Action |
|---|---|
| `Ctrl+Shift+1` | Region screenshot |
| `Ctrl+Shift+2` | Full screen screenshot |
| `Ctrl+Shift+3` | Window screenshot |

---

## Layout tweaks

- `border` is **off** — active window indicated by `focus-ring` (2px, default blue)
- `gaps` set to `4`
- `geometry-corner-radius 8` on all windows
- `background-color transparent` (wallpaper handled by noctalia-shell)
