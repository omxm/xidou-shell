# Xidou Shell

A from-scratch X11 desktop shell being built on a ThinkPad X230, as a spiritual X11
counterpart to Noctalia v5 (which the owner already runs on their Wayland main desktop).

This file is the handoff brief for Claude Code. Read it fully before doing anything.
It captures every decision made during the planning conversation that preceded this repo.

## Naming

**Xidou** = X11's "X" + 軌道 (*kidou*, Japanese for "orbit").

The name is intentionally tied to the architecture, not borrowed from any other project:
dwm (the tiling engine) acts as the gravitational core, and the independent Quickshell
panels (bar, launcher, control-center, wallpaper picker, etc.) orbit around it — each one
an independent window, but all governed by the same theme/config "gravity." The name also
nods to giving the X230 (a 2012 laptop, long retired from daily use) a new orbit to run in.

Do NOT reference `ilyamiro/serpantinum` (a real, unrelated Wayland shell project) as
inspiration for the name or logo anywhere in this repo, README, or commit history. Its
visual style (atomic/orbital motif, purple gradient) was liked aesthetically, but the name,
logo, and any direct asset must be original.

## Philosophy — read this before writing any code

The owner tried building an X11 desktop once before with a loose stack of dotfiles
(separate bar, launcher, notification daemon, color-generation tool, etc. all glued
together with scripts) and gave up specifically at the bar. The stated reason: "if one
piece breaks, you can't tell which piece broke." That failure is why this project exists.

Rules that follow from that:
- **One cohesive shell**, not a pile of glued-together standalone tools.
- **Build in phases, smallest first.** Do not attempt to build every panel at once. See
  "Feature roadmap" below for the required order. Phase 0 (config + theme plumbing) must
  exist and work before Phase 1 (bar) begins.
- **Full customizability** via a single TOML config file — bar position, module order,
  colors, fonts, panel keybinds should all be config-driven, not hardcoded.
- **Unified theming**: every panel must read colors/fonts from one shared theme token
  source. Never hardcode a color or font directly in a panel's QML.
- **All repo file/folder names, code comments, README text, and commit messages: English.**
  (Conversation with the owner, はる, happens in Japanese elsewhere, but this repo's
  artifacts are English-only per her explicit instruction.)

## Hardware target

- ThinkPad X230, 2306CTO config
- i7-3520M, DDR3L 8GB (4GB x2 kit)
- 1366x768 IPS panel (modded from stock TN)
- 256GB SSD (modded)
- 9-cell battery (modded)
- Mpe-AXE3000H / AX210 wifi card (modded)
- Repasted with Thermal Grizzly SMZ-01R
- Runs Artix Linux (runit init, no systemd)
- Currently dual-purposed: an existing Artix + MangoWM (Wayland) + Noctalia v5 session
  stays installed and must keep working. Xidou Shell is added as a **separate X11 session**,
  not a replacement.

## Architecture

### Window manager: dwm (X11)

- Base: vanilla suckless dwm, patched.
- Layout: **dwindle** (binary space partition, Hyprland-like feel). A "scroller" /
  PaperWM-style layout was considered and explicitly rejected — not worth the implementation
  cost. dwm here is a pure tiling engine; it is emphatically **not** the main deliverable of
  this project (the shell is).
- Patch: **dwm-ipc** (https://dwm.suckless.org/patches/ipc/) — adds a Unix socket with
  JSON-RPC for querying/controlling dwm and subscribing to tag/focus/layout-change events.
  This is the bridge between dwm and the Quickshell panels.
- Keybind ownership: **dwm owns all keybindings.** A keypress in dwm spawns a command that
  talks to the shell over IPC — mirroring the existing MangoWM config on the main desktop,
  where e.g. `bind=super, d, spawn, noctalia msg panel-toggle launcher` triggers the shell.
  Xidou Shell should expose an equivalent `xidou msg <command>` style CLI/IPC surface.
- `showbar=0`: dwm's built-in status bar is disabled. The bar is entirely a Quickshell panel
  reserving its space via strut-style geometry, the way an external bar (e.g. polybar) is
  commonly run alongside dwm.

### Shell: Quickshell (Qt/QML) on X11

- Quickshell (the QtQuick-based shell toolkit that also powers Noctalia v4) supports X11.
  Confirmed via the `noctalia-dev/noctalia-qs` fork ("for Wayland and X11") and a small
  community project, `naranyala/x11-focused-shell`, actually running Quickshell on Artix
  X11. Note: Noctalia **v5** itself dropped Qt entirely and is Wayland-only — there is no
  v5-style X11 shell to reference; Quickshell is the X11-capable tool, not Noctalia v5's
  own renderer.
- **Panels are independent top-level windows**, not one monolithic "Home" window. This
  mirrors how Noctalia v5 itself works: `launcher`, `wallpaper`, `clipboard`, `session`,
  and `control-center` are each toggled independently via IPC commands
  (`noctalia msg panel-toggle <name>`), not nested inside one master window. The
  control-center ("Home") panel itself contains its own internal sidebar of sections —
  see the confirmed layout under Phase 5 below.
- All panels must import from one shared theme/config QML singleton — no per-panel color
  literals.

### Icons

- **Google Material Symbols** (variable font), Apache 2.0 licensed.
- Source it directly from `google/material-design-icons` upstream — do **not** copy the
  font file or codepoint map out of Noctalia's repo, even though Noctalia bundles the same
  font (package metadata: `material-symbols-variable`).
- Default style: **Outlined**. Confirm exact weight/fill/grade defaults when the theme
  token system (Phase 0) is built.
- This avoids the Nerd Font pitfall documented below (codepoint remapping between font
  versions) since Material Symbols is a single, centrally-maintained Google project rather
  than a patchwork of merged unrelated icon sets.

### Font

- UI text: **Inter** (Variable), SIL Open Font License. Matches Noctalia's own choice
  (its package requires `inter-fonts` + `inter-variable-fonts`).

## Config system

- Path: `~/.config/xidou/config.toml`
- snake_case keys throughout, matching the conventions already established for MangoWM /
  Noctalia configs the owner is used to.
- Draft schema (starting point — refine as Phase 0 is implemented):

```toml
# ~/.config/xidou/config.toml

[shell]
name = "Xidou"
version = "0.1.0"

[theme]
mode = "dark"              # dark | light | auto
accent = "#c9b890"
background = "#1a1a1a"
surface = "#242424"
surface_alt = "#2e2e2e"
text = "#eaeaea"
text_muted = "#9a9a9a"
border = "#3a3a3a"
radius = 10
font_family = "Inter"
icon_font_family = "Material Symbols Outlined"
font_size = 14

[bar]
position = "top"           # top | bottom
height = 32
modules_left = ["logo", "workspaces"]
modules_center = ["media", "clock", "weather"]
modules_right = ["tray", "mem", "cpu", "bluetooth", "volume", "power"]

[panels.control_center]
enabled = true
keybind = "super+e"

[panels.launcher]
enabled = true
keybind = "super+d"

[panels.wallpaper]
enabled = true
keybind = "super+y"
directories = ["~/Pictures/Wallpapers"]

[panels.clipboard]
enabled = true
keybind = "super+v"

[panels.notification]
enabled = true
dnd_keybind = "super+n"

[panels.session]
enabled = true
keybind = "super+escape"
lock_keybind = "super+l"

[startup]
enabled = true
logo = "~/.config/xidou/assets/logo.svg"
```

Open question not yet resolved: exact granularity of `modules_left/center/right` entries
(one string per discrete widget vs. grouping e.g. tray+mem+cpu+bluetooth+volume into a
single opaque module). Decide this while implementing Phase 0/1, not before.

## Feature roadmap — build in this order, do not skip ahead

**Phase 0 — foundation (build first, before any panel):**
Config file loader + a shared theme-token QML singleton that every later panel imports.
Nothing else should be started until this works.

**Phase 1 — bar**
Left/center/right modules per the config schema above.

**Phase 2 — launcher**

**Phase 3 — OSD**
Volume/brightness pop-ups.

**Phase 4 — notifications**
Including do-not-disturb toggle.

**Phase 5 — control-center ("Home" panel)**
Confirmed sidebar sections (from real Noctalia v5 screenshots the owner supplied):
`Home / Media / Audio / System / Power / Network / Bluetooth / Weather / Calendar /
Notifications / Screen Time`.
The Home section itself contains: a profile card (avatar, hostname, uptime, shell version),
a now-playing media card, a clock+weather card, and a grid of quick-toggle buttons
(Wi-Fi, Bluetooth, Caffeine, Night Light, DND, Power).
The Audio section additionally needs **per-application volume mixer** (Output/Input device
selectors plus a list of running apps each with their own volume slider) — confirmed from a
real screenshot (apps shown: media player, the shell's own sound events, a browser/game).

**Phase 6 — wallpaper selector + color matching**
Confirmed UI (from a real Noctalia v5 screenshot): tabs for `Built-in / Wallpaper /
Community`, a style preset dropdown (e.g. "Soft"), Dark/Light/Auto color-mode toggle,
per-wallpaper favorite (star) toggle, filter/search box, thumbnail grid.

**Phase 7 — clipboard / screenshot / session (lock, power menu)**

**Final phase — startup/splash screen**
Same design language as every other panel. Logo + the shell's wordmark + a "Start" button
underneath. Shown by default on shell launch; toggleable (dismissible) rather than modal-only.

## Lessons from the previous X11/i3 attempt — do not repeat these

The owner uploaded a lessons-learned doc from an earlier, abandoned X11 + i3wm build
(Artix, NVIDIA RTX 4060, 1920x1080@180Hz). Key points, condensed:

1. **waybar does not run on X11** (Wayland-only despite old claims of an XCB backend). Not
   directly relevant here since the bar is a native Quickshell panel, but the underlying
   lesson — verify a tool's platform support against current docs, not old blog posts —
   applies broadly.
2. **matugen** (if used anywhere for wallpaper-driven color generation) hangs forever when
   invoked headless (no TTY) unless called with `--source-color-index 0`, which skips its
   interactive color picker.
3. **Never relay a wallpaper file with a bare `cp`** if the extension might not match the
   real format — convert through ImageMagick (`convert src dst.png`) so the decoder always
   gets a real PNG. A `.png` copied to a `.jpg` filename crashed matugen's decoder silently
   in the earlier attempt.
4. **Verify a script's actual deployed variable values after every edit** — a stale hardcoded
   path silently kept working from the wrong directory in the earlier attempt because the
   edit "worked" in one place but the deployed copy elsewhere was never checked. Use
   `grep VAR path/to/script` to confirm.
5. **X11 and Wayland tooling do not overlap.** Do not reach for `wl-paste`, `swaybg`, `grim`,
   etc. out of habit — X11 equivalents (`xclip`/`clipnotify`, `feh`/`nitrogen`, `maim`/`scrot`)
   are different tools entirely.
6. **dwm tag-cycling**: do not rely on any "next/prev workspace" abstraction — the earlier
   i3 attempt hit a bug where unvisited workspaces got skipped by `workspace next/prev`.
   Drive tag switches by explicit tag number via dwm-ipc instead.
7. **Nerd Font icon codepoints shift between font versions** and glyphs can silently vanish
   with no visible error. This project sidesteps the issue entirely by using Material
   Symbols (a single, centrally-maintained font) instead of a Nerd Font patchwork — but stay
   alert for the same class of problem with any other bundled icon font.

## Workflow / environment

- Primary development happens via SSH from the main desktop (Ryzen 7 5700X + RTX 4060,
  Artix + MangoWM + Noctalia v5) into the X230.
- Claude Code's **Remote Control** feature (`claude remote-control`, run inside `tmux` so it
  survives SSH disconnects) is the preferred way to drive Claude Code on the X230 from the
  main desktop's browser or phone without keeping an SSH terminal open the whole time.
- GitHub account: `omxm` (SSH key already registered, commit email `h4ruxx@proton.me`).
  Repository: `omxm/xidou-shell`, **public**.
