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

**Xidou** = X11's "X" + 軌道 (*kidou*, Japanese for "orbit"). XidouWM (the tiling engine, a dwm
derivative) is the gravitational core; the independent Quickshell panels (bar, launcher, control-center,
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
  order, colors and fonts are config-driven. Keybinds are not yet. The
  `[panels.*].keybind` keys are documentation only, and say so in
  `config.example.toml` and `Config.qml`. Nothing reads them: every bind is hardcoded
  in XidouWM's `config.h` (see "What's still open").
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
(see `e2e7233`, 2026-09-20). The X230-era hardware facts (i7-3520M, 1366x768,
9-cell battery, etc.) no longer apply.

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

### X1CG5 inventory (ROADMAP T0-3, read on the machine 2026-10-01)

Read-only survey; nothing was changed to collect it.

- **Machine:** 20HR0005JP, BIOS N1MET77W (1.62), EC 1.22. Kernel 7.2.6-artix2-1.
  Intel Core i5-7200U (2C/4T, max 3.1 GHz), 7.5 GiB RAM. Suspend modes:
  `s2idle [deep]` (deep is the default).
- **GPU:** Intel HD Graphics 620 (Kaby Lake GT2, `8086:5916`). Xorg uses the
  `modesetting` driver with glamor on an OpenGL 4.6 context. DRI2 and DRI3 are
  up, and AIGLX loaded Mesa's `iris` driver (Mesa 26.2.3). Quickshell is on
  hardware GL (`libgallium` + `libGLX_mesa`). The `intel` DDX isn't installed;
  Xorg logs a harmless "Failed to load module intel".
  - **picom `glx`:** very likely fine. Every prerequisite is in the Xorg log
    (hardware GLX via iris). Not tried: `glxinfo` (mesa-utils) isn't installed, and
    `session/picom.conf` is still `backend = "xrender"` with a stale X230 comment.
    Switching is a separate change (M25/D20).
- **Display:** built-in `eDP-1`, 1920x1080 at 60.05 Hz, 309x174 mm, so about
  158 DPI physically. No `Xft.dpi` in xrdb, so X/Qt use the default 96 DPI. The
  other outputs are DP-1, DP-2 and HDMI-1 (an external monitor for H5 would use
  one of these).
- **Backlight:** `/sys/class/backlight/intel_backlight` (raw, max 1060).
  `brightness` is `root:video` mode 664, and the user is in `video`.
- **Battery:** `BAT0`, SANYO 01AV430 Li-ion, 54.15 Wh design / 45.85 Wh full
  (about 85%), 87 cycles.
  - Both threshold APIs exist: `charge_control_{start,end}_threshold` and the
    legacy `charge_{start,stop}_threshold`, plus `charge_behaviour`
    (`[auto] inhibit-charge force-discharge`). The files are `root:root` 644.
  - They currently read 75/80. TLP isn't what set them: `START/STOP_CHARGE_THRESH_BAT0`
    are commented out in `/etc/tlp.conf`, and `/etc/tlp.d/` holds only the template.
    Probably the EC kept an earlier setting (a guess, not verified).
- **Power management:** TLP 1.10.2 (runit service `tlp`, enabled; `tlp-stat` labels
  the init "sysvinit"). TLP's own profiles work (`tlp performance | balanced |
  power-saver`; currently `performance/AC`). `tlp-pd` (TLP's PPD-compatible daemon)
  isn't installed, `power-profiles-daemon` isn't installed either, and there is no
  ACPI `platform_profile`. An `undervolt` runit service also runs (-100 mV core,
  cache and GPU, reapplied every 30 s).
- **Touchpad:** "Synaptics TM3289-002", RMI4 over SMBus (`rmi4-00`, i2c-6),
  `event12`. Input properties `0x5` = pointer + buttonpad, so it is a **clickpad**
  (no physical buttons). Also a "TPPS/2 ALPS TrackPoint" on its pass-through
  (`event13`). Driven by `xf86-input-libinput` 1.5.0 / libinput 1.32.0
  (`xf86-input-synaptics` isn't installed), configured by
  `/etc/X11/xorg.conf.d/90-xidou-touchpad.conf`.
  - Click method is libinput's default **button areas** (`libinput Click Method
    Enabled` = `1, 0`, read 2026-10-02), so pressing in the pad's lower-right
    area is a right click. Tapping is off. Nothing in the repo sets either.
- **Input group:** the user is **not** in `input` (groups: haru, sys, video, lp,
  wheel). `/dev/input/event*` is `root:input` 660, so gesture tools that read
  evdev (libinput-gestures, `libinput debug-events`) can't run as the user yet.
  This matters for M23/L16.
- **Audio:** one card, HDA Intel PCH (`8086:9d71`), with a Conexant CX8200 codec
  plus Kaby Lake HDMI. PipeWire 1.6.9 (pipewire-pulse). Default sink
  `alsa_output.pci-0000_00_1f.3.analog-stereo`.
- **Other:** Wi-Fi Intel AX200 (`8086:2723`), Bluetooth AX200 (USB `8087:0029`),
  Ethernet I219-V, fingerprint reader Validity `138a:0097` (`open-fprintd` and
  `python3-validity` services run), and ThinkPad LEDs under
  `/sys/class/leds/tpacpi::*` (kbd_backlight, mute and micmute LEDs).

## Architecture

### Window manager: XidouWM (X11)

- **XidouWM** is the project's fork of suckless dwm, in `xidouwm/` (renamed from
  `dwm/`, ROADMAP H8 change 1). Binaries: `xidouwm` (exec'd by
  `session/xidou-xinitrc` straight from the repo) and `xidouwm-msg` (the dwm-ipc
  CLI, installed into PATH by `make install`; the shell calls it by name). The man
  page is `xidouwm.1`. `xidouwm/LICENSE` keeps every dwm MIT/X notice.
  - The source files keep their upstream names (`dwm.c`, `dwm-msg.c`, `dwm.png`),
    and so do the dwm-ipc protocol names (`DWM-IPC` magic, `get_dwm_client`) and
    the QML types built on them (`DwmIpc`, `DwmRole`).
  - In prose, in this file and in code comments, "dwm" still means this WM.
- Base: vanilla suckless dwm, patched. Layout: **dwindle** (fibonacci.c — BSP,
  Hyprland-like feel). `showbar=0`; the bar is entirely a Quickshell panel reserving
  space via `_NET_WM_STRUT_PARTIAL`/`_NET_WM_STRUT` (implemented in dwm itself,
  `37c9415`).
- **dwm-ipc** patch adds the Unix socket JSON-RPC bridge (`xidouwm/ipc.c`,
  `IPCClient.*`, `yajl_dumps.*`) — querying/controlling dwm and subscribing to tag/focus/layout-change
  events.
  - Xidou additions (ROADMAP F1, confirmed on the X1CG5, no problems):
    client objects carry `class`, `instance`, `pid` and `visible`, and
    `get_clients` (message type 7) lists every client.
  - Also `wm_action_event` (see "Sound effects").
  - **Socket path** (H8 change 2): resolved at run time by `xidouwm/sockpath.h`,
    which xidouwm and xidouwm-msg share. In order:
    1. `$XIDOU_WM_SOCKET` (test isolation);
    2. `$XDG_RUNTIME_DIR/xidouwm.sock` (the session, `/run/user/1000/xidouwm.sock`);
    3. `/tmp/xidouwm-<uid>.sock`, with a warning, when `XDG_RUNTIME_DIR` is unset.
  - `xidouwm-msg --socket-path` prints the result. Nothing else hardcodes the path:
    `config.h` has no `ipcsockpath` any more, and xinitrc's gap block polls
    `xidouwm-msg get_tags`.
  - A path longer than 107 bytes (`sun_path`) is an error, never a fallback to the
    next rule: xidouwm keeps running without IPC and xidouwm-msg exits 1. So a test
    never touches the live socket. Before this rule, both fell back to it silently,
    and a test instance would take it over.
  - **Socket lifecycle** (L15): xidouwm deletes its socket file on a clean exit
    (quit/logout), but only if the file is still the one it bound (dev/inode). That
    way it never deletes a socket a later instance bound at the same path. On a
    crash the file stays behind, and the next start unlinks and rebinds it.
- **dwm owns all keybindings.** Keypresses spawn `xidou msg <command>` (see `bin/xidou`),
  mirroring the MangoWM/Noctalia convention. Keybind migration from MangoWM/Noctalia
  muscle memory is done (`ec597a4`), including directional focus/swap
  (`super+<arrow>` / `super+shift+<arrow>`, `2112a35`).
- dwm itself also grew: rounded borders via X Shape, dock-window stacking,
  tag-follow-on-move, window gaps (IPC-settable). It remains a tiling engine, not the
  project's main deliverable — the shell is.
- **dwm has no animation code at all.**
  - Window open/close animations are entirely picom's: the `animations` block in
    `session/picom.conf`, regenerated from `[motion]` by `services/MotionSync.qml`.
  - The directional tag slide (ROADMAP H3 step 2, confirmed on the X1CG5) is picom's
    too. dwm writes an `_XIDOU_MOTION` property on each client right before a
    tag-switch move (`setmotion()` / `tagswitchdir()` in `dwm.c`), and
    `session/picom.conf`'s `rules` animate on it. The value contract lives in
    `picom.conf`'s comments.
- **picom rules on a property dwm or Quickshell sets need c2's `@` suffix**
  (`_XIDOU_MOTION@ = '...'`, not `_XIDOU_MOTION = '...'`). Without it, picom v13
  (upstream HEAD too) caches the value once, when it first sees the window, and never
  refreshes it on this non-reparenting WM. The rule then silently evaluates stale data.
  Root cause and A/B evidence: ROADMAP H3, "Root cause found".

### Shell: Quickshell (Qt/QML) on X11

- Panels are independent top-level `PanelWindow`s (bar, launcher, control-center,
  settings, wallpaper, clipboard, session, screenshot, notifications, OSD, and
  the tray item menu `bar/TrayMenu.qml`) toggled via
  `PanelManager` (mutual-exclusion-with-every-other-dock-panel) and IPC (`xidou msg
  panel-toggle <name>` / dedicated `IpcHandler`s per panel in `shell.qml`).
  - `PanelManager.open(name, section)` opens without toggling and can ask for a
    section (ROADMAP F2, confirmed on the X1CG5): `xidou msg control-center open Audio`, or generically
    `xidou msg panels open <panel> <section>`.
- All panels import `quickshell/config/Theme.qml` and `quickshell/config/Config.qml` —
  no per-panel color/font literals.
- Bar modules (ROADMAP F5):
  - Text goes through `bar/widgets/BarLabel.qml` / `BarIcon.qml`, never
    repeated font/color expressions; set `stateColor` for state colors.
  - Clicks and scrolling are declared as `leftClicked()` / `rightClicked()`
    / `middleClicked()` / `scrolled(steps)` functions. Bar.qml's wrapper
    calls them, and undeclared buttons fall through to the dead zone.
  - A `tooltip` property gets the bar's shared popup.
  - Clicks (ROADMAP M8, D6) come from `[bar_widgets.<module>]`
    `left_click`/`right_click`/`middle_click`, each an action registry id,
    set in Settings > Bar > Modules > gear. Defaults: left opens the module's
    control-center section, right runs its quick action (mute, DND,
    play/pause). A module's own F5 slot is only the fallback.
- **Quick actions live in `services/Actions.qml`** (ROADMAP M12). Switchboard,
  Home's toggle grid, the bar and the IPC targets dwm's keybinds call all run
  `Actions.run(id)`; never re-implement an action at a call site. Add an entry
  only when something uses it. `xidou msg actions list` / `actions run <id>`.
- Animation durations and easing come from `quickshell/config/Motion.qml`
  (ROADMAP F4: `Motion.fast/normal/slow`, `Motion.standard/enter/exit/emphasized`,
  all derived from `[motion]`, 0 ms when motion is off). Never write a duration
  or easing literal in a panel either.
- X11-specific quirk: `PanelWindow.focusable` does nothing on this backend. dwm now
  gives panels focus itself (see below). The older `xidou-focus-window` helper
  (`bin/`), which forces focus by matching window size, is still called by every
  panel as a fallback. control-center and wallpaper are both 820x560, which is
  harmless only because just one panel is ever mapped at a time.

### Window roles between dwm and the shell (`_NET_WM_NAME`)

Every Quickshell window is `_NET_WM_WINDOW_TYPE_DOCK` and named "quickshell", and
dwm never manages docks as clients. So a window tells dwm what it is by setting a
title via QtQuick's `Window.window.setTitle()` (`quickshell/lib/DwmRole.qml`;
LockScreen.qml does the same inline). dwm caches the role per dock (`DockWin`,
refreshed on `_NET_WM_NAME` changes) and derives every mode from the *currently
mapped* docks, never a flag. If the shell dies, the mode goes away with its
windows.

- **`xidou-lock`** (`LOCKWINNAME`) — lock mode. See the lock screen item in
  "What's still open".
- **`xidou-panel`** (`PANELWINNAME`) — keyboard-driven panels: launcher,
  control-center, settings, session, wallpaper, clipboard, screenshot confirm.
  Not OSD, notifications or the bar. While one is mapped:
  - dwm focuses it on map, or when the title arrives late.
  - enternotify/motionnotify don't move focus, so the pointer crossing a client
    no longer steals it.
  - When the last panel unmaps, `focus(NULL)` returns focus to the selected
    client. It used to fall to PointerRoot.
  - **Anything done outside the panel closes it.** Any keybinding not listed in
    `panelsafecmds` (`xidouwm/config.h`) closes it first. So does a click on a client
    or the desktop; the click still goes through, replayed via XAllowEvents.
    - `panelsafecmds` is currently volume, brightness, media keys, DND, panel
      toggles, lock and screenshot. It's the one place to change what keeps a
      panel open.
    - While a panel is open, the selected clients get the same sync AnyButton
      grab as unfocused ones, so dwm sees clicks on them too.
    - Clicks on the bar, panels or lock screen go to Quickshell, never dwm, so
      they don't close anything.
  - dwm closes panels with `xidou msg panels closeAll`, which also cancels a
    pending screenshot confirm. Print/Ctrl+Print close panels themselves via
    `PanelManager.closeAllThen()` and wait out the `[motion]` close duration
    +150ms, so the panel isn't in the picture.
  - `xidouwm/config.h` is gitignored. Copy `config.def.h` over it after pulling
    changes to either.
- **Quickshell's 1x1 resize, dropped by dwm.** Whenever any panel hides,
  Quickshell 0.3.1 re-lays out every remaining panel window, the bar included
  (`XPanelStack::removePanel` → `updateDimensions`, `src/x11/panel_window.cpp`).
  Each re-layout ends with an AwesomeWM workaround: `setGeometry(0,0,0,0)` then
  `setGeometry(real)`, and Qt sends the first as a 1x1 resize. picom discards a
  window's contents on a size change, so the bar vanished for one frame every
  time a panel closed. dwm's `configurerequest()` now drops any request that
  would shrink a tracked dock to 1x1 or smaller (`isdegeneratedockconfig()`).
  Found by bar-strip recording on real hardware. Unmapping non-Quickshell
  windows, focus changes, picom's close animation, `xrender-sync-fence` and
  `QSG_RENDER_LOOP=basic` were each ruled out. If a future Quickshell upgrade
  changes that workaround, revisit this.

### Sound effects (ROADMAP F6 + M22)

- **Assets:** the uisfx "zen" pack (CC0), 59 cues converted once from .ogg to
  16-bit WAV, in `quickshell/assets/sounds/zen/` with `LICENSE-AUDIO`, a `NOTICE`
  and `cues.json` (per-cue default volume, loop flag). Qt's `SoundEffect` plays
  WAV only.
  - Every WAV carries the same +9.5 dB gain over the pack (loudest peak -1.08
    dBFS). Every volume is upstream's / 0.26, so the loudest cue is at 1.0
    (SoundEffect's maximum) when category and master are both 100%. That is
    +21.2 dB over the pack in all, with the balance between cues unchanged;
    `NOTICE` has the details.
  - So 100% on the Sound page is the loudest the shell can play. Louder means
    the system volume, or another gain on the WAVs. Never spawn a process per sound.
- **`lib/SoundMap.js`** is ROADMAP section 7 in code: operation id -> cue,
  category, on/off by default, `incoming` (the only sounds DND silences). Callers
  name operations (`SoundFx.play("panel_open")`), never cues or files.
  `SoundMap.gain()` is the pure volume rule: cue default x category x master, 0
  when anything is off.
- **`services/SoundFx.qml`**: one preloaded `SoundEffect` per cue. It also does:
  - per-cue cooldowns (hover, focus, progress-step, volume-change);
  - a 60 ms dedupe, so one action seen from two places sounds once;
  - loops (`startLoop`/`stopLoop`);
  - `playThen()` for log out/restart/shut down: run when the cue ends or after
    0.4 s, immediately if it can't play.
  - `XIDOU_SOUND_LOG=1` logs every operation (played, volume, or why it was
    silent).
  - `xidou msg sound play|gain|status <op>` is the IPC side.
- **Where sounds come from:**
  - explicit `play()` calls at UI actions (PanelManager, the shared settings
    controls, launcher, media, capture);
  - `services/SoundEvents.qml` (instantiated in shell.qml), which watches state
    changing from anywhere: Wi-Fi/BT, sink volume/mute, DND, caffeine, night
    light, battery, theme mode, palette, and xidouwm's events. It plays nothing
    for 3 s after startup, while bindings settle.
- **xidouwm events:** tags, layout and floating/fullscreen come from the
  existing dwm-ipc events. Window close, send, swap, directional focus and mouse
  move/resize come from Xidou's own `wm_action_event` (`ipc_wm_action_event()`).
  - It is written to the socket immediately, because `movemouse()` blocks the
    main loop.
  - DwmIpc subscribes to it in a separate `IpcEventStream`, so an older xidouwm
    rejecting it can't break the workspace widget.
- **Testing without touching the real audio:** run a private PipeWire in a short
  test `XDG_RUNTIME_DIR`, with a null sink and `wireplumber -p policy` (no
  hardware monitors), and record the sink monitor to measure levels. See the
  auto-memory note.

### Icons & font

- **Google Material Symbols** (Outlined, variable font), sourced directly from
  `google/material-design-icons` upstream, never copied out of Noctalia's repo. Icon
  codepoints are PUA — extract them via fontTools, never hand-type (see auto-memory:
  `material_symbols_glyph_typing`).
- UI text: **Inter** (Variable).

### External daemon dependencies

Settings > System > Health (`bin/xidou-health`, ROADMAP M16) checks every one
of these, and can restart the audio daemons, picom and xidou-clipd (D23: never
a system service). xidou-clipd is a shell script, so match its command line
(`pgrep -f '/xidou-clipd$'`), never `pgrep -x`.

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
    Layout, Shape, Effects, Widgets, Capsules. Widget List is lane tabs + add-picker +
    multi-select remove + up/down (ROADMAP M9, see Modules below); Dead Zone is its
    own tab (ROADMAP M10): `[bar.dead_zone]` left/right/middle click and scroll
    up/down, each an action registry id, default right click =
    `control_center.toggle`; a widget's click or scroll with no action of its own
    lands there too.), and Modules (per-module list with a gear icon opening a
    per-widget detail panel — Workspaces, Clock, Weather, Media, Volume, Bluetooth,
    Tray, Mem, CPU, and Power all have real Widget sections built out; Logo and DND
    are the two modules still falling back to `PlaceholderTab` inside that per-widget
    panel). The Modules list (ROADMAP M9) shows one lane per Start/Center/End tab:
    checkboxes + "Remove (n)", a "+" picker of the modules that are off the bar
    (most often added first, UsageStats' `widgets` namespace), and up/down to
    reorder within the lane. The gear panel's Start/Center/End buttons move a
    module *between* lanes. Capsules (`[bar.capsules]`, bar-wide): Widget Capsules on/off, Thickness,
    Radius, Fill (Theme role), Padding, Border, Opacity — wraps every module's
    background in a pill shape via `Bar.qml`'s shared `capsuleModuleComponent`. Bar-wide
    only; a per-widget Presentation override layer (letting one module opt out of or
    override these) is separate, larger deferred work. Capsule Foreground (recoloring
    each widget's text/icon to contrast the fill) is deferred too — it would touch
    every module file's `Text.color`, real cross-cutting scope not bundled here.
  - **System**: Sound, Screenshot, Input, Weather.
    - Sound: Master plus nine category rows, each with On/Off, volume and a
      preview, and a read-only "What plays here" per category.
    - Screenshot: moved here from its own top-level category, plus L3's Save to
      File / Copy to Clipboard (at least one stays on).
    - Input: L16's Disable While Typing, applied with xinput by
      `services/InputSettings.qml` to every device with libinput's DWT property.
      Default off.
    - Weather lives here, not as its own category, since location/units/
      auto_locate are shared across the bar module, Home tab's card, and
      control-center's Weather section.
  - **Wallpaper**: General (Directories).
- Toggles wired to real backing: Wi-Fi and Night Light (Home tab), Caffeine.
- Window-open/close animations (picom's, not dwm's); session-lifecycle bugs around
  panel open/close fixed.

## What's still open

Full backlog, cross-referenced against the code (last updated 2026-09-30, against
`808c76a`), with effort tiers, dependencies, and open decisions: `docs/ROADMAP.md`.
Items below are the headline ones; the roadmap is the complete list.

- **Presentation/Behavior per-widget override layer** — the bar Modules tab's
  per-widget gear panel now has real Widget-specific sections for every module
  except Logo and DND; a generic Presentation/Behavior override layer for those two
  is not built.
- **Bar widget scroll actions (M8)**: clicks are configurable, scroll isn't
  (it falls through to Bar > Dead Zone's scroll actions). A right click with no
  action set falls through to the dead zone too, which by default toggles
  control-center at Home. Before M8 that was the only way a bar
  click reached control-center, and most likely what はる reported on
  2026-10-02 ("control-center opens, but not the module's section").
- **Tray icons named from an icon theme can draw as a checkerboard.**
  Quickshell has no icon theme set, so only hicolor names resolve.
  `//@ pragma IconTheme breeze-dark` in shell.qml would fix it, but also
  swaps some launcher app icons for breeze ones. Waiting on はる (ROADMAP M7).
- **Quickshell log flood, cause unknown.** On 2026-10-02 one live instance
  (10:13–10:14:54) wrote `QSocketNotifier: Socket notifiers cannot be enabled
  or disabled from another thread`, then `Invalid socket 78 and type 'Read',
  disabling...` 1.3 million times in under two minutes (127 MB of text log in
  `/run/user/1000`, which is RAM). It began right after the theme mode was
  cycled three times; はる logged out and back in. Rapid and concurrent config
  writes under Xvfb didn't reproduce it. The instance's `log.qslog` is kept
  in `/run/user/1000/quickshell/by-id/lsjb2a9mt/` (until reboot).
- **Window gaps have no Settings UI**: `[layout] gap_inner/gap_outer` + dwm's
  `setgappih`/`setgappoh` IPC exist (`a941b03`), but they're only pushed once at
  session start by an `awk` block in `session/xidou-xinitrc`.
- **`[panels.*].keybind` config keys are documentation only** (ROADMAP T0-2, D1).
  They are marked that way in `config.example.toml` and `Config.qml`. XidouWM's
  `config.h` hardcodes every bind, and H4 will make the keys real.
- **Settings panel placeholders**: Appearance > Accessibility/Motion/Effects (Motion's
  backend, `services/MotionSync.qml`, already exists — only the tab is missing).
- **Control-center placeholder**: Screen Time section.
- **Lock screen has no X keyboard/pointer grab.** It now covers every screen
  (per-screen `Variants`, `exclusionMode: Ignore`), dwm keeps it above every
  other dock (`LOCKWINNAME`, matched on the `_NET_WM_NAME` LockScreen.qml sets via
  QtQuick's `Window.window.setTitle()`), and `PanelManager.toggle()`/screenshot
  IPC refuse while locked. dwm also has a lock mode (`locked()`, true while any
  `xidou-lock` dock is mapped): `keypress()` runs no binds and `focus()`/
  `unfocus()`/`focusin()`/`clientmessage()` hold X focus on a lock window, so a
  client spawned or activated under the lock never gets keystrokes. Still not a
  real grab: any X client can take its own `XGrabKeyboard`, and the lock is
  fail-open (killing Quickshell unmaps it and dwm hands focus back). QML cannot grab:
  `QWindow::setKeyboardGrabEnabled`/`setMouseGrabEnabled` aren't slots/invokable
  (TypeError from QML, checked on Quickshell 0.3.1 / Qt 6.11), `_backingWindow`
  is `undefined` on PanelWindow, and `PopupWindow.grabFocus` takes no X grab on
  this backend. Needs a small C++ QML plugin or an external locker.
- **Implemented, not confirmed on the real machine.** はる doesn't check these
  one by one; anything that misbehaves in daily use gets reported then.
  Confirmed on the X1CG5 are only: sound loudness, the XidouWM rename, the
  socket move, panels keeping/returning focus, the directional tag slide,
  `super+Return` not stealing input under the lock, F1 (client metadata over
  IPC), F2 (opening control-center at a section), the Health tab (M16)
  opening and showing its checks, M8's default bar clicks (はる tried them
  and said "いい感じで完璧" on 2026-10-02, with no per-item results), and M12's
  action registry through Switchboard DND/Mute, the ctrl+<arrow> media keys
  and Volume's clicks (はる: "完璧です。確認/テスト済み", 2026-10-02).
  M8's click settings in the gear panel are confirmed too (2026-10-02).
  - F5's bar widget wrapper (shared label/icon components, click slots,
    tooltips). Under Xvfb the bar is pixel-identical to master and every
    module click does the same as on master.
  - M12's other Switchboard tiles (Wi-Fi, Bluetooth, Caffeine, Night Light,
    Lock) and region screenshot, now run through the registry.
  - M9's widget list (lane tabs, "+" picker, multi-select remove).
  - M10's Dead Zone tab settings (the default right click and the tag
    actions were checked on the machine).
  - M7's tray drawer and gear-panel states; the tray menu was checked on the
    machine only with a test AppIndicator item, not real apps.
  - Sound effects (every individual sound, including Wi-Fi/Bluetooth, charger,
    battery and lock sounds) and the log out/restart/shut down sound wait.
  - Screenshot's Save to File / Copy to Clipboard toggles (L3).
  - Touchpad Disable While Typing on the real touchpad (L16).
  - The socket file being removed when xidouwm exits (L15).
  - Panels closing on outside actions, Print waiting for panels, the bar not
    blinking on panel close.
  - Panel keybinds opening nothing while locked.
  - Health's Fix buttons (M16).
  - With motion off, the OSD and launcher animations snapping (F4).
- **Lock screen: not yet verified on real hardware** (Xvfb with a stubbed
  PamContext only, since a wrong-password test against real PAM can trip
  faillock):
  - Multi-monitor coverage. Xvfb can't give Qt a second screen; dwm's
    multi-lock-window focus handling was only tested with a fake second lock
    window.
  - Unlocking through real PAM with the redesigned UI. The redesign changed
    how PAM messages are displayed. Real-PAM unlock was only confirmed on the
    pre-redesign UI. (ROADMAP 1.2 used to say this was confirmed; corrected.)
  - picom's open/close fade+scale animation also applies to the lock window,
    so the desktop may show for ~0.15s as the lock appears. It can be
    excluded with a picom rule matching `xidou-lock` if it does.
  - The wallpaper card's rounded corners (`MultiEffect` mask) under picom's
    GLX backend. See the Effects note above about `layer.effect` rendering
    blank under a software-GL compositor.
- **Final phase — startup/splash screen**: logo + wordmark + dismissible "Start"
  button, same design language as every other panel. Not started.

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

### Working agreement (since 2026-10-02)

- **No feature branches.** Commit straight to `master` and push. If something
  breaks, `git revert` it.
- **Claude runs every command**: all git operations and anything typed on the
  machine, including switching the working tree. はる never types commands.
  - `/home/haru/projects/xidou-shell` is the tree the live session runs:
    xinitrc execs `xidouwm/xidouwm` from it, and Quickshell runs
    `quickshell -p` on its `quickshell/`. Quickshell reloads as soon as a
    file there changes, so a QML edit is live on はる's screen immediately,
    before any commit (a broken edit breaks the live shell until it's fixed
    or reverted). xidouwm changes need a rebuild and a logout/login.
- **Ask はる only for**: checking something on screen, `sudo`, and logging
  out/in.
- **Reports are short**, with what はる has to decide or do at the top.
- **Testing on the real machine is fine.** Use Xvfb/Xephyr only for anything
  that restarts xidouwm, touches the lock screen or PAM, reboot/shutdown, or
  the audio daemons. Put anything a real-machine test changes (mute, DND,
  config values, and so on) back the way it was.

- Primary development happens via SSH from the main desktop (Ryzen 7 5700X + RTX 4060,
  Artix + MangoWM + Noctalia v5) into the shell's own machine.
- Claude Code's **Remote Control** feature (run inside `tmux` so it survives SSH
  disconnects) is the preferred way to drive Claude Code remotely without keeping an
  SSH terminal open the whole time.
- GitHub account: `omxm` (SSH key already registered, commit email `h4ruxx@proton.me`).
  Repository: `omxm/xidou-shell`, **public**.
