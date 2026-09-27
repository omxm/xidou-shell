# Xidou Shell

A from-scratch X11 desktop shell, spiritual X11 counterpart to Noctalia v5 (which the
owner also runs on their Wayland main desktop). This file is the handoff brief for
Claude Code — read it fully before doing anything.

**This file is a living document, not a write-once brief.** Update it at the end of any
significant piece of work: new phase completed, a category/section that moves from
placeholder to real, a hardware/environment change, a bug class fixed that's worth
remembering here (vs. in auto-memory). Treat git log and the actual repo state as ground
truth over this file's own prior claims whenever the two disagree.

## Naming

**Xidou** = X11's "X" + 軌道 (*kidou*, Japanese for "orbit"). dwm (the tiling engine) is
the gravitational core; the independent Quickshell panels (bar, launcher, control-center,
wallpaper picker, etc.) orbit around it — each an independent window, governed by one
shared theme/config "gravity."

Do NOT reference `ilyamiro/serpantinum` (a real, unrelated Wayland shell project) as
inspiration for the name or logo anywhere in this repo, README, or commit history.

## Philosophy

The owner's prior X11 attempt (loose dotfiles: separate bar, launcher, notification
daemon, color-gen tool, glued together with scripts) died specifically at the bar,
because "if one piece breaks, you can't tell which piece broke." Rules that follow:

- **One cohesive shell**, not a pile of glued-together standalone tools.
- **Full customizability** via `~/.config/xidou/config.toml` — bar position, module
  order, colors, fonts, panel keybinds are config-driven.
- **Unified theming**: every panel reads colors/fonts from `quickshell/config/Theme.qml`.
  Never hardcode a color or font literal in a panel's QML.
- **All repo file/folder names, code comments, README text, and commit messages: English.**
  (Conversation with the owner, はる, happens in Japanese elsewhere; this repo's
  artifacts are English-only per her explicit instruction.)
- **Don't stub 15 empty categories at once.** Settings categories/sub-tabs and
  control-center sections are added one at a time, backed by a real feature, not
  scaffolded ahead of need. A `PlaceholderTab`/`PlaceholderSection` fallback exists so an
  unwired name fails soft instead of erroring — that's infrastructure, not an invitation
  to pre-declare tabs nothing backs yet.

## Hardware target

Currently a **ThinkPad X1 Carbon (X1CG5)** — migrated from the original X230 target
(see `e2e7233`, 2026-09-20). The X230-era hardware section (i7-3520M, 1366x768,
9-cell battery, etc.) no longer applies; specifics of the X1CG5 config haven't been
inventoried into this file yet.

- Runs Artix Linux (runit init, no systemd)
- Currently dual-purposed: an existing Artix + MangoWM (Wayland) + Noctalia v5 session
  stays installed and must keep working. Xidou Shell is a **separate X11 session**,
  not a replacement.
- Migration surfaced and fixed 4 real bugs (`e2e7233`): dock windows (bar/launcher/
  OSD/notifications) not raised above tiled clients on restack, native X borders
  rounded via the X Shape extension (picom has no real `round-borders` option),
  `tag()` not following focus to the target view, and no Xidou-specific libinput
  touchpad config (natural scroll now pinned via an xorg.conf.d InputClass matching
  any touchpad, not a hardcoded device name).

## Architecture

### Window manager: dwm (X11)

- Base: vanilla suckless dwm, patched. Layout: **dwindle** (fibonacci.c — BSP,
  Hyprland-like feel). `showbar=0`; the bar is entirely a Quickshell panel reserving
  space via `_NET_WM_STRUT_PARTIAL`/`_NET_WM_STRUT` (implemented in dwm itself,
  `37c9415`).
- **dwm-ipc** patch adds the Unix socket JSON-RPC bridge (`dwm/ipc.c`, `IPCClient.*`,
  `yajl_dumps.*`) — querying/controlling dwm and subscribing to tag/focus/layout-change
  events. Socket path overridable via `$XIDOU_DWM_SOCKET` for test isolation.
- **dwm owns all keybindings.** Keypresses spawn `xidou msg <command>` (see `bin/xidou`),
  mirroring the MangoWM/Noctalia convention. Keybind migration from MangoWM/Noctalia
  muscle memory is done (`ec597a4`), including directional focus/swap
  (`super+<arrow>` / `super+shift+<arrow>`, `2112a35`).
- dwm itself also grew: rounded borders via X Shape, dock-window stacking,
  tag-follow-on-move, window gaps (IPC-settable). It remains a tiling engine, not the
  project's main deliverable — the shell is.
- **dwm has no animation code at all.** Window open/close animations are entirely
  picom's (`animations` block in `session/picom.conf`, regenerated from `[motion]` by
  `services/MotionSync.qml`). A tag switch is not animated: dwm hides clients by
  `XMoveWindow` to `-2 * WIDTH(c)` off-screen (`showhide()`), which none of the
  configured picom triggers react to. See `docs/ROADMAP.md` H3 for what it would
  take to animate that.
- **picom rules on a property dwm or Quickshell sets need c2's `@` suffix**
  (`_XIDOU_MOTION@ = '...'`, not `_XIDOU_MOTION = '...'`). Without it, picom v13
  (upstream HEAD too) caches the value once, when it first sees the window, and never
  refreshes it on this non-reparenting WM. The rule then silently evaluates stale data.
  Root cause and A/B evidence: ROADMAP H3, "Root cause found".

### Shell: Quickshell (Qt/QML) on X11

- Panels are independent top-level `PanelWindow`s (bar, launcher, control-center,
  settings, wallpaper, clipboard, session, screenshot, notifications, OSD) toggled via
  `PanelManager` (mutual-exclusion-with-every-other-dock-panel) and IPC (`xidou msg
  panel-toggle <name>` / dedicated `IpcHandler`s per panel in `shell.qml`).
- All panels import `quickshell/config/Theme.qml` and `quickshell/config/Config.qml` —
  no per-panel color/font literals.
- X11-specific quirk: `PanelWindow.focusable` does nothing on this backend, so real X
  input focus is requested via the `xidou-focus-window` helper (`bin/`), matched by
  window size — used by Launcher, control-center, settings.

### Icons & font

- **Google Material Symbols** (Outlined, variable font), sourced directly from
  `google/material-design-icons` upstream, never copied out of Noctalia's repo. Icon
  codepoints are PUA — extract them via fontTools, never hand-type (see auto-memory:
  `material_symbols_glyph_typing`).
- UI text: **Inter** (Variable).

### External daemon dependencies

All handled in `session/xidou-xinitrc`'s single "check if running, start if not" block:
pipewire, wireplumber, pipewire-pulse (with stale-daemon reaping across session
restarts so a plain relogin doesn't leave orphaned instances from the previous dbus
session), plus picom (compositor, needed for rounded borders/animations) and the
`xidou-clipd` clipboard daemon. Any new external dependency a future phase introduces
goes in this same block.

## Config system

Path: `~/.config/xidou/config.toml`, snake_case keys. `quickshell/config/Config.qml` is
the loader (custom TOML parser in `quickshell/lib/Toml.js`), with a `$XIDOU_CONFIG_PATH`
env override for test isolation (`644d61a`) — **always use it for Xvfb/headless testing
instead of touching the real config file** (see auto-memory:
`xvfb_testing_shares_real_config`). `config.example.toml` at repo root is the
up-to-date reference schema — check it directly rather than trusting a schema dump in
this file, since it drifts with every settings-panel category that gains real backing.

The settings panel (`quickshell/settings/`, `super+,`) now provides live read/write
UI over this config — TOML write support (`6fc7efa`) plus per-category tabs (see
below). Editing `config.toml` by hand is no longer the only way to change settings.

## What's built

All of Phase 0 through Phase 7 from the original roadmap are done, plus a settings
panel that wasn't in the original plan:

- **Phase 0** — config loader + `Theme.qml` token singleton.
- **Phase 1** — bar (`quickshell/bar/`): all modules — logo, workspaces, media, clock,
  weather, tray, mem, cpu, bluetooth, volume, power, DND.
- **Phase 2** — launcher (`super+d`): App Search, Switchboard (4x3 toggle grid), and
  Emoji Picker modes, Tab-cycled, with shared usage-frequency tracking and real app
  icons.
- **Phase 3** — OSD (volume + brightness pop-ups), config-driven position/margin.
- **Phase 4** — notifications + do-not-disturb, config-driven OSD/notification
  positioning, picom wired in for animations/effects.
- **Phase 5** — control-center ("Home" panel, `super+e`). Sidebar sections: Home,
  Media, Audio, System, Power, Network, Bluetooth, Weather, Calendar, Notifications all
  have real content. **Screen Time is the one section still a `PlaceholderSection`.**
  Audio section has the per-app volume mixer per the original spec.
- **Phase 6** — wallpaper picker + color matching: matugen pipeline (manual trigger,
  `--source-color-index 0` always included per the headless-hang lesson), scheme-preset
  mapping.
- **Phase 7** — clipboard history panel, screenshot panel (fullscreen + frozen region
  select via slop), session panel (lock/logout/restart/shutdown).
- **Settings panel** (`super+,`, not in the original roadmap — added once enough
  panels existed to need central config UI): sidebar categories, each with its own
  sub-tabs, search bar, Overridden-only filter, per-page reset. Real (non-placeholder)
  today:
  - **Appearance**: Theme, Interface, Borders — real. **Accessibility, Motion, Effects
    are still `PlaceholderTab`.**
  - **Screenshot**: General — real.
  - **OSD**: General — real.
  - **Notifications**: General — real.
  - **Bar**: General (Enabled, Position, Auto-Hide off/on/smart, Reserve Space —
    Auto-Hide collapses the bar to a 3px hover-reveal sliver at the screen edge rather
    than a fully-invisible polled reveal; Smart mode only auto-hides while dwm-ipc's
    `tag_state.occupied & .selected` says the viewed tag actually has a client on it;
    Reserve Space is forced to behave as off, and greyed out in the UI, whenever
    Auto-Hide isn't Off), Layout (`[bar.layout]`: Thickness — relocated here from
    General, still `bar.height` underneath — Content Scale (a real `scale:` transform
    per widget, with the wrapper resized to the scaled footprint so Row spacing doesn't
    overlap neighbors), Font Scale (multiplies just `font.pixelSize` across all 12 bar
    module files, independent of Content Scale), Ends Margin + Edge Margin (together
    these make the "floating bar" look — shortened from both ends and lifted off the
    screen edge at once), Opposite Edge Margin, Content Padding, Panel Overlap
    (Advanced, lets windows tile under the bar's edge by reducing the reserved strut)),
    Shape (`[bar.shape]` — before this, the bar had zero corner-rounding capability at
    all; `PanelWindow.color` is now transparent with an inner `Rectangle` doing the real
    painting, same pattern `Osd.qml` already used, with Qt 6.7+'s per-corner radius
    properties directly since this project's Qt is 6.11.2. Corner Radius (uniform) plus
    four per-corner overrides, each defaulting to -1/"Auto" meaning "inherit the uniform
    value" — 0 is a real, different, selectable state (explicitly square). Corner Flow
    flares the anchored edge's two corners out to the true screen corner with a genuine
    concave cut (`QtQuick.Shapes` odd-even fill: a square XOR a full circle centered at
    the true corner — a plain additive quarter-disk was tried first and rejected, since
    layered on an already-rounded corner it just fully refills the square with no visible
    curve at all); only meaningful when Layout's Ends Margin AND Edge Margin are both 0,
    greyed out otherwise. Border/Border Width. All radii are clamped at render time to
    half of the bar's *current* height, using the live Auto-Hide-aware height, not the
    configured Thickness — so the 3px auto-hide sliver never renders a distorted corner),
    Effects (`[bar.effects]`: Background Opacity — a plain alpha multiplier on the
    background Rectangle from Shape's work; Shadow — the shell's first real shadow
    anywhere, `QtQuick.Effects.MultiEffect` (native since Qt 6.5, no
    Qt5Compat.GraphicalEffects needed at this project's Qt 6.11.2) applied via
    `layer.effect` on an unclipped wrapper `Item` one level above the background
    Rectangle — `layer.enabled` + `clip: true` on the *same* item silently clips the
    shadow to nothing, confirmed empirically; Contact Shadow — purely aesthetic, no
    "a panel is docked against the bar" concept exists anywhere in the shell, so it's
    a fixed gradient at the bar's own edge as a child of the background Rectangle so
    it's cropped to Shape's rounded corners for free. Note for future Xvfb/headless
    testing: picom's GLX backend compositing a window that itself uses `layer.effect`
    can render the whole window blank in a software-GL sandbox (confirmed by disabling
    picom, which restored correct rendering) — likely specific to non-accelerated
    Xvfb, not expected on real hardware, but worth knowing if a future shadow-adjacent
    effect appears to vanish under a test compositor.), Widgets (`[bar.widgets]` — the
    bar-wide DEFAULT layer a future per-widget Presentation override layer, still
    deferred, is meant to sit on top of: Font Family/Weight (label text only, never
    icon glyphs — Material Symbols' own variable-font weight axis is untouched),
    Widget Spacing (replaces 3 hardcoded `Theme.fontSize / 2` Row spacings), Widget
    Color/Icon Color (surgically replace only the "normal/active-state" `Theme.text`
    leaf across the ~9 affected lines in 5 module files — Weather/Cpu/Mem/Dnd/
    Workspaces/Logo intentionally keep their own textMuted/warning/accent/brand colors
    untouched, since a blanket override would erase real state feedback; icon and
    label were always tied to the identical color expression before this, so letting
    them diverge is new), and Hover Highlight (the shell's first hover feedback
    anywhere on the bar — a `HoverHandler` + highlight `Rectangle` added to the same
    `capsuleModuleComponent` wrapper Capsules already introduced, working whether
    Capsules are on or off). This completes all 8 of the original Bar tabs: General,
    Layout, Shape, Effects, Widgets, Capsules. Widget List is on/off + lane moves +
    up/down reorder (see Modules below); Dead Zone is NOT done — only a hardcoded
    right-click → control-center handler, `Bar.qml`'s `handleDeadZoneClick()`, with no
    config key or Settings UI.), and Modules (per-module list with a gear icon opening a
    per-widget detail panel — Workspaces, Clock, Weather, Media, Volume, Bluetooth,
    Tray, Mem, CPU, and Power all have real Widget sections built out; Logo and DND
    are the two modules still falling back to `PlaceholderTab` inside that per-widget
    panel). The Modules list also supports in-lane reordering (up/down arrow buttons
    per row, swapping with the adjacent module in the same lane's array) — distinct
    from the gear panel's Start/Center/End buttons, which move a module *between*
    lanes. Capsules (`[bar.capsules]`, bar-wide): Widget Capsules on/off, Thickness,
    Radius, Fill (Theme role), Padding, Border, Opacity — wraps every module's
    background in a pill shape via `Bar.qml`'s shared `capsuleModuleComponent`. Bar-wide
    only; a per-widget Presentation override layer (letting one module opt out of or
    override these) is separate, larger deferred work. Capsule Foreground (recoloring
    each widget's text/icon to contrast the fill) is deferred too — it would touch
    every module file's `Text.color`, real cross-cutting scope not bundled here.
  - **System**: Weather (deliberately lives here, not its own category, since
    location/units/auto_locate are shared across the bar module, Home tab's card, and
    control-center's Weather section).
  - **Wallpaper**: General (Directories).
- Toggles wired to real backing: Wi-Fi and Night Light (Home tab), Caffeine.
- Window-open/close animations (picom's, not dwm's); session-lifecycle bugs around
  panel open/close fixed.

## What's still open

Full backlog, cross-referenced against the code (last re-verified against `a941b03`),
with effort tiers, dependencies, and open decisions: `docs/ROADMAP.md`. Items below
are the headline ones; the roadmap is the complete list.

- **Presentation/Behavior per-widget override layer** — the bar Modules tab's
  per-widget gear panel now has real Widget-specific sections for every module
  except Logo and DND; a generic Presentation/Behavior override layer for those two
  is not built.
- **Bar Dead Zone settings**: click actions on empty bar space are hardcoded (right
  click → control-center); no config key or tab yet.
- **Bar widget click model**: each module still owns its own `MouseArea`; there's no
  shared left/right/middle/scroll dispatch in `capsuleModuleComponent` yet, and the
  bar-wide widget styling expressions are repeated in all 12 module files.
- **Window gaps have no Settings UI**: `[layout] gap_inner/gap_outer` + dwm's
  `setgappih`/`setgappoh` IPC exist (`a941b03`), but they're only pushed once at
  session start by an `awk` block in `session/xidou-xinitrc`.
- **Lock screen hardening**: the PAM lock takes no X keyboard/pointer grab, so dwm's
  root keybinds likely still fire while locked, and a Quickshell crash drops the lock.
  Must be fixed before any idle auto-lock is built (inferred from code, not yet
  confirmed on the real session).
- **`[panels.*].keybind` config keys are not read by anything** — dwm's `config.h`
  hardcodes every bind.
- **Settings panel placeholders**: Appearance > Accessibility/Motion/Effects (Motion's
  backend, `services/MotionSync.qml`, already exists — only the tab is missing).
- **Control-center placeholder**: Screen Time section.
- **Final phase — startup/splash screen**: logo + wordmark + dismissible "Start"
  button, same design language as every other panel. Not started.
- No inventory yet of X1CG5-specific hardware details (the X230 section above was
  removed as stale; nothing has replaced it beyond "it's an X1 Carbon Gen 5").

## Lessons from the previous X11/i3 attempt — still apply

1. **waybar does not run on X11** — not directly relevant (the bar is a native
   Quickshell panel), but the underlying lesson — verify a tool's platform support
   against current docs, not old blog posts — applies broadly.
2. **matugen hangs forever headless** without `--source-color-index 0` (skips its
   interactive color picker). Every invocation in this repo must include it.
3. **Never relay a wallpaper file with a bare `cp`** if the extension might not match
   the real format — convert through ImageMagick (`convert src dst.png`) so the decoder
   always gets a real PNG.
4. **Verify a script's actual deployed variable values after every edit** —
   `grep VAR path/to/script` to confirm, don't assume an edit propagated everywhere.
5. **X11 and Wayland tooling do not overlap.** Don't reach for `wl-paste`, `swaybg`,
   `grim`, etc. out of habit — this repo uses `xclip`/`xidou-clipd`, `feh`, `maim`/
   `scrot`/`slop`.
6. **dwm tag-cycling**: drive tag switches by explicit tag number via dwm-ipc, never a
   "next/prev workspace" abstraction (prior i3 bug: unvisited workspaces got skipped).
7. **Material Symbols icon codepoints are PUA** — extract via fontTools, never
   hand-type (this project sidesteps the general Nerd-Font codepoint-drift problem by
   using one centrally-maintained Google font, but stay alert for the same class of
   problem with any other bundled icon font).

See also `/home/haru/.claude/projects/-home-haru-projects-xidou-shell/memory/MEMORY.md`
(auto-memory) for finer-grained implementation gotchas (Quickshell `FileView` reload,
`Config.setValue` chaining, `Component.onCompleted`/`Config.ready` races, etc.) — this
file is for project-level state, that one is for recurring implementation traps.

## Workflow / environment

- Primary development happens via SSH from the main desktop (Ryzen 7 5700X + RTX 4060,
  Artix + MangoWM + Noctalia v5) into the shell's own machine.
- Claude Code's **Remote Control** feature (run inside `tmux` so it survives SSH
  disconnects) is the preferred way to drive Claude Code remotely without keeping an
  SSH terminal open the whole time.
- GitHub account: `omxm` (SSH key already registered, commit email `h4ruxx@proton.me`).
  Repository: `omxm/xidou-shell`, **public**.
