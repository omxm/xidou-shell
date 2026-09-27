# Xidou Shell — Feature Backlog Roadmap

Working roadmap for はる and future Claude Code sessions. Planning only: nothing in this
document has been implemented as part of writing it.

- **Written:** 2026-09-27, against `master` at `32b5354`; **re-verified** the same day
  against `a941b03` (the bar overhaul commit — see 1.1).
- **Source:** はる's backlog "アイデア集&改善ポイント #1 / #2" plus the ChatGPT idea list
  (items marked [却下] are excluded; items marked [微妙] are listed at the end as parked).
- **Method:** every backlog item was cross-referenced against the actual code, not
  against CLAUDE.md alone. Where the two disagree, the code wins (per CLAUDE.md's own rule).
- **Written from a cloud container with no access to the real X11 session.** Every
  item below is tagged with how much of it can be trusted without real hardware.

This is a living document. When an item ships, move it to "Done" in the status table
(section 2) and update CLAUDE.md in the same commit. When a decision in section 4 is
made, write the answer inline next to the question, so the next session doesn't re-ask.

---

## 0. Legend

**Effort tiers**

| Tier | Meaning |
|---|---|
| **Light** | One or two files, existing patterns reused, roughly one session. |
| **Moderate** | New service/singleton or a cross-cutting change across several files; one to a few sessions. |
| **Heavy** | Architecture change, new C helper or dwm patch with real design risk, or multi-session work with a migration. |

**Verification tags** (what can be trusted without はる's real machine)

| Tag | Meaning |
|---|---|
| `[CLOUD]` | Logic and layout can be built and checked under Xvfb with `$XIDOU_CONFIG_PATH` (and `$XIDOU_DWM_SOCKET` for a test dwm). Screenshots are enough evidence. |
| `[SESSION]` | Needs the real X session to judge: compositor behavior (picom), focus/grab behavior, animation feel, scroll feel, sound. Buildable in the cloud, but "done" can only be declared after はる tries it. |
| `[HW]` | Depends on X1CG5 hardware facts (battery sysfs, backlight, touchpad, TLP, GPU, external monitor). Cannot even be designed with confidence until the hardware inventory (T0-3) exists. |

**Status words:** *Done* (built and in pushed code), *Partial* (some of it exists — the
remaining delta is what's planned), *Not started*.

---

## 1. Read this first — findings from the cross-reference

These came out of comparing the backlog, CLAUDE.md, and the code. Several of them change
the order things should be done in.

### 1.1 Bar overhaul: resolved, re-verified against `a941b03`

The first pass of this document (against `32b5354`) found that CLAUDE.md described a
finished bar overhaul the pushed code didn't contain. はる confirmed it was uncommitted
local work; it is now on `master` as `a941b03`, and this document was re-checked against
it. What the code now actually has:

- **Settings > Bar** tabs: General (Enabled, Position, Auto-Hide off/on/smart, Reserve
  Space), Layout, Shape, Effects, Widgets, Modules, Capsules — all real, matching
  CLAUDE.md.
- **Per-widget sections** (Modules > gear): Weather, Clock, Workspaces, Media, Volume
  (show %), Bluetooth (show count), Tray (icon size only), Mem/CPU (warning threshold),
  Power (show %, low threshold). Logo and DND still fall back to `PlaceholderTab`.
- **In-lane reordering**: up/down buttons. `ModulesTab.qml`'s header explicitly argues
  *against* drag-and-drop, because the list is one flat catalog, not grouped by lane.
  The backlog's Start/Center/End tabs would change that premise — see M9.
- **`capsuleModuleComponent`** in `Bar.qml` now wraps every module (capsule background,
  content scale, hover highlight via `HoverHandler`). It does *not* dispatch clicks:
  each module still owns its own `MouseArea`. That makes F5 smaller than planned.
- **New, not mentioned in CLAUDE.md:** window gaps. `[layout] gap_inner/gap_outer` in
  config, `setgappih`/`setgappoh` dwm IPC commands, and an `awk` block in
  `session/xidou-xinitrc` that pushes them once at session start. No Settings UI yet —
  see L14 and 1.7.

Two things from the first pass still hold after the re-check:

- **Dead Zone is not done.** CLAUDE.md says "Widget List and Dead Zone were already done
  beforehand", but Dead Zone is still one hardcoded right-click → control-center handler
  (`Bar.qml` `handleDeadZoneClick`) with no config key and no Settings UI. M10 stands,
  and CLAUDE.md has been corrected.
- **Widget styling is copy-pasted per module.** Each of the 12 module files now repeats
  the same expressions for `bar.widgets.font_family`, the `font_weight` string → `Font.*`
  mapping, `layout.font_scale`, and `color`/`icon_color` fallbacks. That's fine at 12
  modules; at the ~30 the backlog wants (L8, M11) it becomes the thing that drifts. F5
  now includes extracting shared `BarLabel`/`BarIcon` components.

### 1.2 The lock screen is probably not secure yet

`quickshell/session/LockScreen.qml` is a real PAM lock, but it is an ordinary
full-screen `PanelWindow`. Nothing takes an X keyboard/pointer grab (no `XGrabKeyboard`
anywhere in the repo), and dwm's own keybinds are passive grabs on the root window, so
they very likely still fire while "locked" — e.g. `super+Return` would spawn a terminal
behind the lock, and `super+q` would kill whatever client has focus. And if Quickshell
crashes or is restarted, the lock disappears and the desktop is exposed. Neither has been
tested on the real session, so this is an inference from the code, not a confirmed bug.

This matters for ordering: **idle-lock (M2) and lock-on-suspend must not be built on top
of the lock as it is today.** Hardening it (M1) comes first.

### 1.3 The `keybind` keys in config.toml don't do anything

`config.example.toml` has `keybind = "super+d"` etc. under every `[panels.*]` table, and
CLAUDE.md's philosophy says panel keybinds are config-driven. But nothing reads those
keys — dwm's `config.h` hardcodes every bind at compile time. Changing them in
config.toml silently does nothing. Either mark them as documentation-only in the example
file, or make them real (that is part of H4). Recorded as T0-2.

### 1.4 Things that turned out to be closer to done than the backlog assumes

- Color matching (matugen) and M3 scheme selection already work from **both** Settings >
  Appearance > Theme ("Palette Source", "Wallpaper Generation Scheme") and the wallpaper
  picker's preset cycler. No matugen fork is needed for anything in the backlog — see 1.5.
- The Motion *backend* already exists (`services/MotionSync.qml` + `lib/PicomSync.js`
  rewrite picom's animation block from `[motion]` and SIGUSR1 picom). Only the Settings
  tab is still a `PlaceholderTab`. That makes the Motion tab a Light item.
- The Power section in control-center already shows percentage, charging state, time to
  full/empty, battery health (when supported) and model.
- Workspaces already has hide-empty, three styles (regular / minimal / focus_hint with
  dots), and app icons.
- Screenshot already has every toggle from the backlog except "copy to clipboard" as
  its own switch (it currently always saves *and* copies).
- Session menu (`super+Escape`) with 1–5 number keys is done; slot 3 is "Reserved".
- Launcher already centers the selection with edge clamping (keyboard-driven) and shows
  real app icons. Mouse-wheel-moves-selection is the missing piece.

### 1.5 Where I disagree with the backlog's own reasoning

These are pushback, not refusals — each one has a decision entry in section 4.

1. **"Fork matugen" is unnecessary.** matugen already has a template system (per-app
   output files rendered from the palette) — that is exactly what a Templates tab needs
   — and `matugen color hex <#rrggbb>` generates an M3 scheme from a seed color, which
   covers "M3 color presets". Forking it would mean owning its color-science code forever
   for no feature gain.
2. **"GTK settings need dwm forked into XidouWM" doesn't hold.** On X11, GTK reads its
   theme/icons/cursor/font from `~/.config/gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`,
   `~/.gtkrc-2.0`, and live from an XSETTINGS daemon (`xsettingsd`). The cursor theme
   is `~/.icons/default/index.theme` + `Xcursor.theme`/`Xcursor.size` in X resources +
   `xsetroot -cursor_name left_ptr` for the root window. None of that touches the window
   manager. It's a nice idea; it just doesn't depend on a WM fork.
3. **dwm is already forked.** `dwm/` is a vendored, heavily patched dwm (IPC, dwindle,
   Shape corners, dock stacking, directional focus, strut support). "Forking to XidouWM"
   is mostly a rename. What *would* be new is making dwm read settings at runtime
   instead of compile time — that's the real work, and it's H4.
4. **Forking picom is a bad trade.** picom is a large C codebase with GL backends; a
   fork means rebasing upstream fixes forever, on one person's time. Its v12 animation
   scripts are already scriptable. Try H3's cheap experiment first (1.6) before
   considering this.
5. **TLP isn't required for charge thresholds.** thinkpad_acpi exposes
   `/sys/class/power_supply/BAT0/charge_control_{start,end}_threshold` directly, and the
   repo already has the udev-rule-for-sysfs-write pattern (`90-xidou-backlight.rules`).
   *But* `PowerSection.qml` says this machine already runs TLP, and TLP rewrites
   thresholds on boot and AC changes, so two owners would fight. One of them must own
   thresholds (decision D9).
6. **"custom_button" conflicts with はる's own rule.** The backlog says free-text command
   fields are unacceptable ("テキストフィールドがあって手動でコマンド追加するのは御免"),
   but a custom button is by definition a user-supplied command. Either it's the one
   explicit exception, or it's replaced by "pick an action from the Switchboard action
   registry" (recommended — see M12).
7. **Gestures and tag switching.** A 3-finger swipe to go to the next/previous tag is
   exactly the "next/prev workspace" abstraction lesson #6 warns about. It's safe only if
   the gesture handler computes an explicit target tag number from DwmIpc state and calls
   `view` with that mask.

### 1.6 A useful correction for the animation question

`session/picom.conf`'s comment says a dwm tag switch "is a plain unmap/map". This dwm
doesn't do that: `showhide()` (`dwm/dwm.c:2195`) hides clients by `XMoveWindow` to
`-2 * width` offscreen and shows them by moving them back. Two consequences:

- A tag switch is a **geometry change**, not a map/unmap. picom v12's animation system
  has a `geometry` trigger. **It's worth one real-session experiment** to see whether a
  `geometry`-triggered animation slides windows in on tag switch before planning a dwm
  patch or a picom fork (H3). `[SESSION]`
- Windows on hidden tags stay **mapped**, so their XComposite pixmaps stay valid. Live
  thumbnails for an overview (H2) are therefore possible from a small C helper, without
  needing Quickshell's screencopy support (which I believe is Wayland-only — verify).
- Follow-up investigation (2026-09-27): see H3 — the trigger should fire, but without a
  dwm change the result would look uncoordinated.

### 1.7 Window gaps: the first real "dwm setting from config" — and two rough edges

`a941b03` added window gaps the way H4 proposes doing all dwm settings: a runtime IPC
setter in dwm (`setgappih`/`setgappoh`) fed from config.toml. That's a good precedent.
Two things to tidy before it becomes the pattern:

- **Only applied once, at session start, by `awk` in xinitrc.** Changing `[layout]`
  does nothing until relogin, and the `awk` block is a second, hand-rolled TOML reader
  (it ignores `$XIDOU_CONFIG_PATH`, and it would misread a value written with a trailing
  comment containing digits). Once a Settings UI exists (L14), the natural home for
  "push to dwm" is the shell: on `Config.reloaded`, call `dwm-msg run_command
  setgappih …` — live, and the xinitrc block can then be deleted.
- **Naming:** top-level `[layout]` (window gaps) and `[bar.layout]` (bar geometry) are
  unrelated but read as siblings. Worth deciding before more dwm settings land in
  `[layout]` (decision D24).

---

## 2. Status of every backlog item

Sorted in backlog order. "Plan ID" points into sections 3–5.

### アイデア集 #1

| # | Item (short) | Status | Plan ID |
|---|---|---|---|
| 1 | All services started from xinitrc | **Done** (convention; `ensure_running` block). New daemons below must follow it. | — |
| 2 | Wallpaper color matching + M3 scheme choice in Settings *and* wallpaper picker | **Done** (matugen, both entry points). Fork not needed (1.5). | — |
| 3 | Templates / per-app theming tab (Settings only) | Not started | M4 |
| 4 | Animations (research + "I want animations") | **Partial**: picom open/close done; Motion backend done; tab placeholder; tag switch not animated | L1, M21, H3 |
| 5 | Wallpaper directories in Settings | **Done** (Wallpaper > General) | — |
| 6 | Everything (dwm config, resolution, scale) in Settings | **Partial**: window gaps are config-driven via dwm IPC (`a941b03`) but have no Settings UI and apply only at session start; everything else in dwm is still compile-time | L14, H4, H5 |
| 7 | Overridden / Reset UI, long-press or double-click reset | **Partial**: badge + one-click reset exist (right side of row) | L5 |
| 8 | Screenshot settings | **Mostly done**; missing separate "copy to clipboard" / "save to file" toggles | L3 |
| 9 | Lock screen | **Partial**: PAM lock exists; hardening needed (1.2) | M1 |
| 10 | Settings panel separate from control-center | **Done** | — |
| 11 | Bar customization (general … dead zone) | **Done** for General/Layout/Shape/Effects/Widgets/Capsules (`a941b03`). **Partial** for Widget List (on/off, lane moves, up/down reorder — no lane tabs, add-picker, multi-select, drag). Dead Zone UI **not started** (1.1). | M9, M10, section 6 |
| 12 | Battery widget (health, AC, profile, time, thresholds, laptop/desktop detect) | **Partial**: CC Power shows %, status, time, health; bar shows % + icon; `hasBattery` check exists | M3 |
| 13 | `super+Esc` session menu with 1–5 keys | **Done** except slot 3 | L2 |
| 14 | Idle settings with gradual dimming | Not started | M2 |
| 15 | Nicer UI icons | Not started (vague) | L13 |
| 16 | GTK settings (nwg-look) inside Settings | Not started | M6 |
| 17 | Screen Time in control-center | Placeholder only | M20 |
| 18 | System monitor in control-center | **Partial**: CPU/mem/disk exist | M13 |
| 19 | Widget overhaul | **Partial**: bar-wide styling layer, capsules, hover, per-widget sections done (`a941b03`); click model and shared widget components not | F5, M8, M9 |
| 20 | Overview / window switcher (`super+Tab`) | Not started (dwm bind reserved; no IpcHandler listens) | M14, H2 |
| 21 | Workspaces: only occupied/focused, styles, numbers vs dots | **Done** (hide_when_empty, regular/minimal/focus_hint, icons) | — |
| 22 | Tray drawer (collapsible), open/closed default | Not started (Tray's gear panel has icon size only); right-click still has no menu | M7 |
| 23 | Xidou icon and logo | Not started (Logo module is a placeholder wordmark) | M24 |
| 24 | Launcher Switchboard (chip, many actions, ←→ sliders) | **Partial**: 4×3 grid mode exists, Tab cycles 3 modes | M12 |
| 25 | Fork dwm → XidouWM, own animation patch, fork picom etc. | Decision | H8 |
| 26 | Make config easier to change | Mostly = Settings panel; concrete remainder | L10 |
| 27 | Big list of bar widgets | 12 exist (logo, workspaces, media, clock, weather, tray, mem, cpu, bluetooth, volume, dnd, power); the rest are new | L8, M11, section 6 |
| 28 | Left-click → CC page, right-click → configurable action | Not started | F2, M8 |
| 29 | Choose which CC sections are shown | Not started | L6 |
| 30 | Theme export/import | Not started | M17 |
| 31 | Unlimited bars, bar export/import/duplicate | Not started | H1 |
| 32 | Stack 3+ notifications, click → CC Notifications | Not started | L7 |
| 33 | Sound effects | Not started | F6, M22 |
| 34 | Tailscale status widget | Not started | M11 |
| 35 | M3 color presets like Noctalia | Not started | M5 |
| 36 | Trackpad gestures | Not started | M23 |

### アイデア集 #2

| # | Item | Status | Plan ID |
|---|---|---|---|
| 37 | Launcher: scroll moves selection, selection stays centered except at the ends; app icons | **Partial**: centering + clamping + icons done (`28b9a8c`); wheel does nothing (`interactive: false`) | L4 |

### ChatGPT list (non-rejected)

| Item | Status | Plan ID |
|---|---|---|
| Switchboard as searchable action palette | Not started | M12 (merged) |
| Xidou Health | Not started | M16 |
| Window Rules GUI | Not started | H4 |
| Scratchpad | Not started | M18 |
| Clipboard by type + pins + actions | Not started (no search either) | L9, M15 |
| Screenshot action bar | **Partial**: Save/Cancel preview exists | L11 |
| Screenshot editing | Not started | H6 |
| Display Profiles | Not started | H5 |
| Resource History | Not started | M13 |
| Keyboard Shortcut Visualizer | Not started | M19 (view), H4 (edit) |
| First-run Setup | Not started | M24 |
| Xidou Motion System | **Partial** (picom side only) | F4, M21 |
| Management console (Undo / Presets / Safe Mode) | **Partial** (the Settings panel is the console) | H7 |
| [微妙] Device Center | Parked — see section 8 | — |

### Still-open items from CLAUDE.md (not in the backlog, kept for completeness)

| Item | Plan ID |
|---|---|
| Appearance > Accessibility / Motion / Effects placeholders | L1 (Motion), M21 (Accessibility), M25 (Effects) |
| Per-widget panel for Logo and DND | L12 |
| Startup / splash screen | M24 |
| X1CG5 hardware inventory | T0-3 |

---

## 3. Tier 0 — housekeeping and foundations

Small things that unblock or de-risk everything else. Do these first.

### T0-1 Reconcile CLAUDE.md with the pushed code — **Done** (2026-09-27)
- はる pushed the bar overhaul as `a941b03`; re-verified in 1.1. CLAUDE.md's one
  remaining inaccuracy (Dead Zone described as done) was corrected in the same commit
  as this update. Nothing is blocked on this any more.

### T0-2 Make `[panels.*].keybind` honest — Light `[CLOUD]`
- **What:** mark them in `config.example.toml` and `Config.qml` as "documentation only,
  dwm's config.h is the real source" until H4 makes them real. Also fix the CLAUDE.md
  philosophy line saying keybinds are config-driven.
- **Alternative:** delete the keys. Decision D1.

### T0-3 X1CG5 hardware inventory — Light `[HW]`
- **What:** on the real machine, record in CLAUDE.md: CPU/GPU (`lspci`, `glxinfo -B`),
  panel resolution/DPI (`xrandr`), battery (`ls /sys/class/power_supply/BAT*/` —
  check `charge_control_*_threshold`), backlight device, touchpad name and whether it is
  a Synaptics/Elan clickpad, TLP version (`tlp-stat -s`), whether `power-profiles-daemon`
  or TLP's own profile support is available on Artix, audio card.
- **Also:** `session/picom.conf` still picks `xrender` because of "this 2012 Intel iGPU"
  (X230). On X1CG5 (Kaby Lake HD 620) `glx` is likely fine and required for blur and
  better animations. Re-evaluate there.
- **Blocks:** M3, M2 (dim path), M23, H5, M25, H3.

### F1 dwm-ipc: expose per-client metadata — Light/Moderate `[CLOUD]`
- **What:** add `class`, `instance`, `pid`, and on-screen geometry to `get_dwm_client`
  (`dwm/yajl_dumps.c`), and a "client list" query (all clients with tags + monitor).
  Today `Workspaces.qml` shells out to `xdotool getwindowclassname` once per focus
  change because IPC lacks WM_CLASS.
- **Unblocks:** window switcher (M14), overview (H2), Screen Time (M20), active_window
  and taskbar widgets (M11, section 6), Window Rules "add rule from focused window" (H4),
  and removes the xdotool dependency.
- **Verify:** testable with a test dwm on `$XIDOU_DWM_SOCKET` under Xvfb.

### F2 Open control-center at a given section — Light `[CLOUD]`
- **What:** `PanelManager` only has `toggle(name)`. Add an `open(name, section)` path and
  an IPC call such as `xidou msg control-center open Audio`. ControlCenter selects that
  section on open instead of resetting to Home.
- **Unblocks:** widget click model (M8), notification stack click (L7), Switchboard
  actions like "Audio output…" (M12).

### F3 TOML: arrays of tables (and probably inline tables) — Moderate `[CLOUD]`
- **What:** `lib/Toml.js` explicitly does not support `[[...]]`. Needed for: multiple
  bars (`[[bars]]`), window rules, and any list of structured things (custom actions,
  template entries). `Toml.setValue` must also *write* them without destroying
  comments.
- **Risk:** the writer is the delicate part — it edits text in place. Needs unit-style
  tests (a small `node` test script against fixture files works in the cloud).
- **Unblocks:** H1, H4, M4 (if templates are listed in config).

### F4 `Motion.qml` token singleton — Light `[CLOUD]` for code, `[SESSION]` for feel
- **What:** the QML-side equivalent of `Theme.qml` for motion: named durations and
  easing (`Motion.fast/normal/slow`, `Motion.enter/exit/emphasized`), all derived from
  `[motion]`, with a global "reduce motion" multiplier. Replace hardcoded durations
  (e.g. Launcher's `duration: 120` + `OutCubic`) with tokens.
- **Why before M21:** same reasoning as "never hardcode a color" — otherwise the
  Motion System ends up being a search-and-replace later.

### F5 Common bar widget wrapper — Moderate `[CLOUD]`
- **Already there** (`a941b03`): `Bar.qml`'s `capsuleModuleComponent` wraps every
  module with capsule background, content scale, and hover highlight.
- **What's left:** (1) move click/scroll handling out of each module's own `MouseArea`
  into the wrapper as left/right/middle/scroll slots that modules *declare* actions
  for; (2) tooltips; (3) extract shared `BarLabel`/`BarIcon` components so the
  font-family/weight/scale/color expressions now copy-pasted into all 12 module files
  (1.1) live in one place. Do (3) before adding new widgets, not after.
- **Unblocks:** M8 (click model), L8/M11 (new widgets reuse it for free).
- **Depends on:** nothing now. Could drop to Light once started — the wrapper exists.

### F6 Sound service — Light `[SESSION]`
- **What:** a `SoundFx` singleton with `play(eventName)`, global enable, volume, and
  "mute while DND". Backend choice: Qt Multimedia `SoundEffect` if the installed
  Quickshell/Qt has it, otherwise `pw-play` (PipeWire, already a dependency).
- **Unblocks:** M22, the reset-confirmation sound in L5.

### F7 dwm runtime settings channel — Heavy — see H4.

---

## 4. Decisions needed from はる

Grouped by what they block. Each has a recommendation, but these are genuinely yours to
make. Write the answer next to the question when decided.

| ID | Question | Options | Recommendation | Blocks |
|---|---|---|---|---|
| D1 | `[panels.*].keybind`: remove, document as decorative, or make real? | remove / document / real (H4) | Document now, make real later with H4 | T0-2 |
| D2 | Overridden/Reset position: left of the control (backlog) or right (today)? | left / right | Left, as specified — but it shifts every control horizontally when it appears. Reserve the space always so layout doesn't jump. | L5 |
| D3 | Reset gesture: long-press, double-click, or both? With sound? | long-press / double-click / both | Long-press with a fill animation (it's discoverable and hard to trigger by accident); double-click as a secondary path. Sound only once F6 exists. | L5 |
| D4 | Session menu slot 3 | Reload shell / Suspend / Reload config / Lock+Suspend | **Suspend.** It's the action a laptop needs most, and "Reload shell" can live in Switchboard. If you prefer Reload, say which (restart Quickshell vs re-read config). | L2 |
| D5 | Switchboard: keep the grid, or make it a searchable command list? What does Tab do now that Emoji mode exists? | grid / searchable list / both | Both: empty query shows the grid, typing filters a list of all actions. Keep Tab cycling App → Switchboard → Emoji, and show the mode chip ("\|Switchboard\|") left of the input. Your spec said Tab toggles back to Launcher — that conflicts with Emoji mode's existence; decide. | M12 |
| D6 | Widget click model: left-click → CC section for *every* widget that has one? | as backlog / per-widget default | As backlog, but configurable per widget in the gear panel (left/right/middle/scroll each pick from an action list). | M8 |
| D7 | `custom_button`: allow a raw command field as the one exception, or only pick from the action registry? | raw command / registry only | Registry only, plus an "Advanced: shell command" field hidden behind an Advanced toggle. | M11 |
| D8 | Templates: name and placement | "Templates" / "Theming" / "App Theming"; own category vs Appearance sub-tab | Call it **Templates** (same word as matugen and Noctalia, so docs line up) as a sub-tab of Appearance. Which apps first? Suggest kitty, GTK 3/4, Qt (qt6ct), Firefox (if you use pywalfox), dmenu/rofi if present. | M4 |
| D9 | Who owns battery charge thresholds: TLP or Xidou? | TLP config / direct sysfs / remove TLP | Let TLP own them and have Xidou edit TLP's config (or call `tlp setcharge`) — least conflict with what's already installed. Revisit after T0-3. | M3 |
| D10 | Idle stages and defaults | e.g. dim at 4 min, lock at 5, screen off at 6, suspend at 15 on battery | Separate AC/battery profiles; dim is a gradual fade over ~5–10 s, any input cancels it. Also: should media playback (MPRIS playing) block idle? (Recommend yes.) | M2 |
| D11 | Screen Time definition | per-app focused time / total active time / both; retention | Per-app focused time (from dwm focus + idle), daily totals, 30-day retention, stored locally only. | M20 |
| D12 | "Nicer icons" — what's wrong with the current ones? | Rounded style / filled for active states / different weight / different font | Stay on Material Symbols (one maintained font), but use the FILL axis for active/on states and possibly the Rounded variant. Needs your eye. | L13 |
| D13 | M3 presets: seed colors or full hand-made palettes? | seeds via matugen / named palettes (Catppuccin etc.) / both | Both: a row of seed colors (matugen does the rest) plus a few hand-made palettes, all selectable from Appearance > Theme. | M5 |
| D14 | Sound: where do the sound files come from? | freedesktop sound theme / self-made / licensed pack | Start with the freedesktop sound theme (license-clean) and let each event point to a file. | M22 |
| D15 | CC "Monitor" vs "System": your CC list has both | split / merge | Split: **Monitor** = live numbers + history; **System** = static system info (CPU model, kernel, uptime, packages). | M13 |
| D16 | Overview: full GNOME-style overview, or a window switcher first? | switcher first / overview first | Switcher first (M14), overview later (H2) — the switcher is most of the daily value at a fraction of the risk. | M14, H2 |
| D17 | Screenshot editor: build in QML or delegate to an existing X11 editor? | build / delegate (e.g. satty, flameshot's editor) | Delegate first behind an "Edit" button, build only if the delegated editor feels out of place. | H6 |
| D18 | Startup splash and first-run setup: one thing or two? | merge / separate | Merge: the splash's "Start" button leads into first-run setup the first time, and just dismisses afterwards. | M24 |
| D19 | XidouWM: rename the vendored dwm? Fork picom? | rename / keep "dwm" name; fork picom yes/no | Renaming is cheap and fine if you want the identity. Don't fork picom (1.5). | H8 |
| D20 | Appearance > Effects: what goes in it? | global blur / shadows / panel transparency / all | Decide after T0-3 (glx vs xrender). Probably: panel background opacity, global shadow, blur behind panels (needs glx). | M25 |
| D21 | Multiple bars: what differs per bar? | everything / subset | Position, monitor, modules, and the Layout/Shape/Effects/Widgets/Capsules tables; theme stays global. | H1 |
| D22 | Gestures: which gestures → which actions? | — | 3-finger swipe L/R → adjacent tag *by explicit number*; 3-finger up → switcher/overview; 3-finger down → close panels; 4-finger → your choice. | M23 |
| D23 | Health auto-fix: what may it do without asking? | restart user daemons only / anything | Only restart user-level daemons it itself started (pipewire family, picom, xidou-clipd). Never touch system services. | M16 |
| D24 | Top-level `[layout]` (window gaps) vs `[bar.layout]`: keep, or rename before more dwm settings join it? | keep / `[windows]` / `[wm]` | Rename to `[windows]` now, while only two keys and one reader exist; keep reading `[layout]` as a fallback for one release. | L14, H4 |
| D25 | Widget List: is drag-and-drop wanted, or are up/down buttons enough once lanes are separate tabs? | drag / buttons only | Buttons first (they exist), lane tabs + "+" picker + multi-select; add drag only if it still feels missing. | M9 |

---

## 5. The plan, by effort tier

Each entry: **what**, **current state / files**, **depends on**, **decisions**,
**verification**.

### 5.1 Light

**L1 — Appearance > Motion tab**
- What: real tab over `[motion]` (enabled, duration, preset). The backend
  (`MotionSync.qml`, `PicomSync.js`) already exists, and `picom.conf` already refers to
  this tab by name.
- Depends on: nothing. Nicer after F4 (the same tab can then drive QML motion too).
- Verify: `[CLOUD]` for the tab and the picom.conf rewrite; `[SESSION]` for the look.

**L2 — Session menu slot 3**
- What: fill `Session.qml` item 3 and the SessionActions function behind it.
- Decisions: D4. Verify: `[CLOUD]` for UI; `[HW]` if Suspend (lock-before-suspend
  depends on M1).

**L3 — Screenshot: separate "Save to file" and "Copy to clipboard" toggles**
- What: `Screenshot.qml` always does `mkdir -p && maim … && xclip …`. Split into two
  config keys (`save_to_file`, `copy_to_clipboard`, both default true); at least one must
  stay on (grey out the other's Off when it would leave neither).
- Verify: `[CLOUD]` (Xvfb + maim + xclip all work headless).

**L4 — Launcher: wheel moves the selection**
- What: keep the existing clamped-centering `contentY` binding, add a `WheelHandler` that
  changes `selectedIndex` instead of scrolling. Touchpads send many small `pixelDelta`
  events — accumulate until one row's worth before stepping, or two-finger scroll will
  race.
- Verify: `[CLOUD]` for mouse wheel logic; `[SESSION]` for how the X1CG5 touchpad
  feels (must be tuned there).

**L5 — Overridden/Reset polish**
- What: move the badge per D2, long-press/double-click per D3, fill animation during
  the long press. Check that ModulesTab's `customReset` rows get the same behavior.
- Depends on: F6 only if a sound is wanted.
- Verify: `[CLOUD]`.

**L6 — Choose which control-center sections are shown**
- What: `[panels.control_center].sections = [...]` (order = display order), a Settings
  page with toggles + up/down reorder. ControlCenter.qml's `sections` becomes
  config-driven. Home is always on.
- Settings placement: there is no control-center category in Settings yet — this would
  be the first real tab for one (fine under the "backed by a real feature" rule).
- Verify: `[CLOUD]`.

**L7 — Notification stacking**
- What: when more than N (default 3) popups are active, collapse them into one "N
  notifications" card; clicking it opens CC > Notifications. N is configurable.
- Depends on: F2. Verify: `[CLOUD]` (`notify-send` works under Xvfb with a dbus session).

**L8 — Simple action-button widgets**
- What: launcher, settings, session, screenshot, wallpaper, control-center, caffeine,
  nightlight, theme_mode, notifications (with unread badge), spacer, text. Each is an
  icon (and optional label) whose click calls something that already exists.
- Depends on: F5 (so they get click dispatch/hover/capsules and shared styling for free).
- Verify: `[CLOUD]`.

**L9 — Clipboard search**
- What: a filter field in `Clipboard.qml` (text entries only). First step before M15.
- Verify: `[CLOUD]`.

**L10 — "Make config easier to change" — concrete remainder**
- Surface config parse errors visibly (today a TOML typo silently falls back to all
  defaults with only a console warning — a notification saying "config.toml line 42:
  …, using defaults" would save real confusion).
- `xidou config reload` / `xidou config path` CLI helpers in `bin/xidou`.
- Keep `config.example.toml` in sync — a small check script that diffs its keys against
  `Config.qml`'s defaults would catch drift (it has already drifted: `bar_widgets` is in
  `Config.qml` but not in the example file).
- Verify: `[CLOUD]`.

**L11 — Screenshot action bar**
- What: extend `ScreenshotConfirm.qml` from Save/Cancel to Copy / Save / Open (in image
  viewer) / Edit (→ H6 or delegated editor) / Delete.
- Verify: `[CLOUD]`.

**L12 — Per-widget panel for Logo and DND**
- What: the two modules whose gear panel is still a `PlaceholderTab` (confirmed in
  `a941b03`). Logo: which image/wordmark, click action. DND: show when off or only when
  on.
- Depends on: nothing. Logo's image option pairs naturally with M24. Verify: `[CLOUD]`.

**L13 — Icon polish**
- What: per D12. Material Symbols' FILL axis (0→1) for on/active states is a
  `font.variableAxes` change, not a new font.
- Verify: `[SESSION]` (it's purely a matter of taste).

**L14 — Window gaps in Settings**
- What: a Settings page for `[layout] gap_inner/gap_outer` (backing already exists:
  config keys + dwm IPC). Apply live from the shell on change (`dwm-msg run_command
  setgappih/setgappoh`) and on shell startup, then delete xinitrc's `awk` block (1.7).
- Placement: there's no dwm/"Windows" category yet — this would be its first real tab,
  and where Window Rules (H4) and Scratchpad (M18) settings later go.
- Decisions: D24 (naming). Verify: `[CLOUD]` with a test dwm on `$XIDOU_DWM_SOCKET`;
  `[SESSION]` for look.

### 5.2 Moderate

**M1 — Lock screen hardening (high priority)**
- What:
  1. Take an active keyboard + pointer grab while locked (a small C helper in `bin/`
     like `xidou-focus-window`, or an X11 call if Quickshell exposes one), so dwm's
     root binds and other clients see nothing.
  2. Decide the crash behavior: if Quickshell dies while locked, the session must not
     end up unlocked. Options: a tiny separate locker process that owns the grab and is
     only told "unlock" by the shell after PAM succeeds; or have xinitrc start the
     locker, not the shell.
  3. Lock on suspend / lid close: listen to elogind's `PrepareForSleep`, or run
     `xss-lock` pointing at `xidou msg session lock`.
  4. Disable VT switching while locked is *not* possible from an X client without root
     — document it rather than pretend.
- Why first: M2 (auto-lock on idle) would make an insecure lock look trustworthy.
- Verify: grab logic `[CLOUD]` (Xvfb + xdotool key injection can prove dwm binds no
  longer fire); `[SESSION]` + `[HW]` for suspend/lid.

**M2 — Idle management with gradual dimming**
- What: an idle daemon (recommend a small C helper, `xidou-idled`, using the
  XScreenSaver extension's idle time — same pattern as `xidou-focus-window`) that runs
  staged timers: dim (fade backlight over several seconds via `bin/xidou-brightness`,
  restore on input) → lock (M1) → screen off (DPMS) → suspend. Settings > System >
  Idle with separate AC/battery values.
- Must respect: Caffeine (today it holds an `elogind-inhibit` lock, which an X idle
  daemon won't see on its own — check the inhibitor list or Caffeine's state directly),
  fullscreen video, and optionally MPRIS playback.
- Alternative to writing C: `xidlehook` (supports multiple timers and "not when
  fullscreen/audio"). Fine too — decide when implementing.
- Depends on: M1, T0-3. Decisions: D10.
- Verify: timer logic `[CLOUD]`; dimming and DPMS `[HW]`.

**M3 — Battery / power widget overhaul**
- What: bar widget shows AC-connected state; click → CC Power (via M8). CC Power gains:
  AC status, charge threshold slider (e.g. 60–100 % end threshold), power profile,
  battery-saver toggle. Laptop vs desktop: already half there (`hasBattery` /
  `isLaptopBattery`) — hide the widget and the section on desktops.
- Power profile backend: this machine uses TLP (per `PowerSection.qml`), so
  Quickshell's PowerProfiles API (power-profiles-daemon) would sit inert. Check what the
  installed TLP version offers for profile switching (newer TLP releases added
  profile commands — verify against the installed version's docs, not memory).
- Depends on: T0-3, D9. Verify: `[HW]` for all of it.

**M4 — Templates (per-app theming)**
- What: Settings > Appearance > Templates: a list of apps, each with an on/off switch;
  on = matugen renders that app's template when the palette regenerates; plus a "apply
  now" button. Ship templates in the repo (`templates/kitty.conf`, `gtk.css`, …) and
  generate matugen's config from the enabled list. Reload hooks per app (kitty: `kill
  -SIGUSR1`, GTK: via xsettingsd from M6).
- Depends on: nothing hard; M6 makes GTK reload clean. Decisions: D8.
- Verify: generation `[CLOUD]`; app reload behavior `[SESSION]`.

**M5 — M3 color presets**
- What: in Appearance > Theme: a row of preset seeds + named palettes (D13). Seed →
  `matugen color hex … --source-color-index 0` (lesson #2 — keep the flag even though
  it's not strictly about images) → same JSON pipeline `ColorScheme.qml` already reads.
  Adds `theme.source = "preset"` alongside builtin/wallpaper.
- Verify: `[CLOUD]` (matugen runs headless with the flag).

**M6 — GTK / icon / cursor / font settings (nwg-look inside Settings)**
- What: new Settings category (e.g. "Applications" or under Appearance): GTK theme,
  icon theme, cursor theme + size, font, dark preference. Writes gtk-3.0/gtk-4.0
  `settings.ini`, `~/.gtkrc-2.0`, `~/.icons/default/index.theme`, Xresources
  `Xcursor.*`, and xsettingsd's config; starts `xsettingsd` from the xinitrc
  `ensure_running` block so running GTK apps change live. Qt apps: qt6ct config.
- Lists of themes come from scanning `/usr/share/themes`, `~/.themes`, `/usr/share/icons`,
  `~/.local/share/icons`.
- Depends on: nothing (see 1.5 #2). Verify: file writing `[CLOUD]`; live GTK update
  `[SESSION]`.

**M7 — Tray drawer and menus**
- What: (a) Right-click on a tray item currently calls `secondaryActivate()`; apps like
  mozc and blueman expect a context menu. Use the item's menu (`hasMenu` / `menu`) with
  Quickshell's menu opener. (b) A collapsible drawer: pinned items shown, the rest behind
  a chevron; per-item "pinned/hidden" in the Tray gear panel; drawer default open/closed.
- Builds on: the Tray gear panel from `a941b03` (currently icon size only).
- Verify: `[SESSION]` (tray items and menus need real apps; menus as popups on X11 are
  exactly the kind of thing that behaves differently under Xvfb).

**M8 — Widget click model**
- What: every widget gets left/right/middle/scroll slots. Default per D6: left → its CC
  section, right → its quick action (e.g. Volume: right = mute, which is today's left).
  Each slot picks from an action registry (shared with Switchboard, M12).
- Depends on: F2, F5. Verify: `[CLOUD]`.

**M9 — Widget List UX (the backlog's "widget list" tab)**
- What: Start / Center / End sub-tabs; each lists its modules in order with drag handle,
  checkbox (multi-select delete), and gear. "+" at the top right of each tab opens an
  add-picker sorted by previously-added / frequency (reuse `UsageStats.qml`, as the
  backlog suggests).
- Drag-and-drop: QML `DragHandler` + `DropArea` in a `ListView`; keep the existing
  up/down buttons as the keyboard path.
- Note: `ModulesTab.qml`'s header deliberately rejected drag-and-drop *for a flat,
  ungrouped catalog*. Grouping by lane is what makes drag worth its cost, so this item
  revisits that call rather than contradicting it — but if はる is happy with up/down
  buttons, the lane tabs + "+" picker + multi-select are the real value and drag can be
  dropped (decision D25).
- Depends on: nothing now. Verify: `[CLOUD]` for logic; drag feel `[SESSION]`.

**M10 — Dead Zone tab**
- What: Bar > Dead Zone: left / right / middle click and scroll up/down on empty bar
  space each pick an action from the registry ("not set", toggle settings, toggle CC,
  launcher, next/prev tag *by explicit number*, …). `handleDeadZoneClick()` was already
  isolated for this.
- Depends on: M12's action registry (or a small one defined here first and moved there
  later). Verify: `[CLOUD]`.

**M11 — Data widgets**
- network (Wi-Fi/ethernet state, SSID), brightness (with scroll), keyboard_layout
  (`setxkbmap -query` / XKB), lock_keys (Caps/Num via XKB state), active_window (needs
  F1), privacy (mic/camera in use: PipeWire nodes with active streams), power_profile
  (after M3), tailscale (`tailscale status --json`; tailscaled is a system service,
  which on Artix means a runit service — not the xinitrc block), sysmon (combined
  CPU/mem/temp).
- Depends on: F5; F1 for active_window. Decisions: D7 for custom_button.
- Verify: mostly `[CLOUD]`; tailscale needs an account `[HW]`; privacy needs real mic
  `[SESSION]`.

**M12 — Switchboard v2 (searchable action palette)**
- What: an **action registry** (`services/Actions.qml`): id, label, icon, keywords,
  `run()`, optional `value`/`adjust(delta)` for sliders. Everything in the backlog list
  goes in: DND, Wi-Fi, Bluetooth, brightness and volume (←/→ adjust), mic mute, audio
  output/input switching, Night Light, dark/light, battery saver and power profile
  (after M3), VPN/Tailscale, wallpaper, display settings (after H5), screenshot, lock,
  reload Xidou, reload config, restart PipeWire.
- UI per D5: "|Switchboard|" chip left of the input, grid when empty, filtered list
  while typing.
- The same registry feeds M8 (widget click slots), M10 (dead zone), D7 (custom button),
  and gestures (M23) — build it once.
- Verify: `[CLOUD]`.

**M13 — Monitor section + resource history**
- What: per D15. Monitor: CPU (per-core), memory, network throughput (from
  `/proc/net/dev`), disk, temperatures (`/sys/class/hwmon`), GPU if meaningful (X1CG5
  has Intel graphics only; `intel_gpu_top` needs root — probably skip GPU and say so),
  each with a sparkline of the last N minutes. One sampling service shared by the bar's
  cpu/mem widgets and this section (today `Cpu.qml` and `SystemSection.qml` each parse
  `/proc/stat` separately). System: CPU model, kernel, uptime, distro, packages, shell
  version.
- Verify: logic `[CLOUD]`; real values `[HW]`.

**M14 — Window switcher (`super+Tab`)**
- What: a panel listing windows (icon + title + tag), most-recently-focused order,
  Tab/Shift+Tab to move, release to focus. dwm already binds `super+Tab` to `xidou msg
  windowswitcher toggle`; nothing listens yet.
- Needs: F1 (client list + class for icons) and an MRU order — either track focus events
  in the shell (DwmIpc already subscribes to focus changes) or add it to dwm. Focusing a
  window on another tag = `view` that tag by explicit mask, then focus the client.
- "Release super to confirm" needs key-release detection of the modifier, which is
  awkward on X11 when the panel doesn't own the grab; the simple alternative is
  Enter-to-confirm. Decide in implementation.
- Verify: `[CLOUD]` with a test dwm; `[SESSION]` for key-release behavior.

**M15 — Clipboard categories, pins, actions**
- What: tabs All / Text / Images / URLs / Code / Pinned (classification by simple
  heuristics); pinned entries survive `xidou-clipd`'s 50-entry pruning (daemon change:
  a separate pinned list it never prunes); actions per type (open URL, open path in file
  manager, copy as plain text).
- Depends on: L9. Verify: `[CLOUD]`.

**M16 — Xidou Health**
- What: a diagnostics page (Settings > System > Health, or a CC section): dwm-ipc socket
  reachable, Quickshell version, PipeWire/WirePlumber/pipewire-pulse alive *and* on the
  current D-Bus session (reuse xinitrc's stale-daemon check), picom running with the
  expected config, xidou-clipd alive, NetworkManager/bluez reachable, notification
  server owned by Xidou, config parse status (L10), matugen present. "Fix" buttons per
  D23.
- This directly serves the philosophy in CLAUDE.md ("if one piece breaks, you can't tell
  which piece broke") — worth more than its ChatGPT origin suggests. Recommend doing it
  early-ish.
- Verify: `[CLOUD]` for checks; fixes `[SESSION]`.

**M17 — Theme export / import**
- What: export `[theme]` (+ the `[bar.*]` look tables) to a standalone
  `.toml`; import merges it via `Config.setValue` chains (remember the
  `cachedText`/chaining lesson in `Config.qml`). A file picker needs an X11-friendly
  approach (Quickshell has no native file dialog on this setup — a simple in-shell
  directory browser or a fixed `~/.config/xidou/themes/` folder with a list).
- Verify: `[CLOUD]`.

**M18 — Scratchpad**
- What: dwm "named scratchpads" patch (a hidden tag per scratchpad, toggled by key),
  e.g. `super+grave` → kitty with a known class. Patch into the vendored dwm.
- Depends on: F1 is helpful for the class match. Verify: `[CLOUD]` with a test dwm;
  `[SESSION]` for feel.

**M19 — Keyboard shortcut viewer (read-only)**
- What: a Settings page listing every bind with a human label. Source of truth: generate
  a JSON from `dwm/config.h`'s `keys[]` at build time (a small script run by
  `dwm/Makefile`), or add an IPC command that dumps the table. Editing is H4.
- Verify: `[CLOUD]`.

**M20 — Screen Time**
- What: per D11. A logger (in the shell, via DwmIpc focus events + class from F1, with
  idle time from M2's helper subtracted) writing daily totals to
  `~/.local/share/xidou/screentime/`. CC section with today's per-app bars and a 7-day
  view.
- Depends on: F1, M2 (for idle), D11. Verify: `[CLOUD]` with synthetic focus events.

**M21 — Motion System + Accessibility tab**
- What: move every panel to F4 tokens; define shared transitions (open/close/expand/
  collapse/switch/hover/success/error). Accessibility tab: reduce motion (multiplier →
  0 disables), larger text, high-contrast toggle.
- Depends on: F4. Verify: `[SESSION]`.

**M22 — Sound effects**
- What: events per the list in section 7; each maps to a file with per-event on/off in
  Settings > Sound (a new category, allowed since it's backed). USB detection needs a
  `udevadm monitor --udev --subsystem-match=usb` listener process.
- Depends on: F6, D14. Verify: `[SESSION]`.

**M23 — Trackpad gestures**
- What: `touchegg` (supports X11) or `libinput-gestures` (needs the user in the `input`
  group), started from the xinitrc block, with actions calling `xidou msg …` from the
  action registry. Per D22 and 1.5 #7 (explicit tag numbers only).
- Depends on: T0-3, M12. Verify: `[HW]`.

**M24 — Logo, splash, first-run setup**
- Logo/icon: human design work; Claude can produce SVG drafts, but whether it's right is
  your call. Keep the "orbit" concept from the name; don't reference serpantinum
  (CLAUDE.md rule).
- Splash + first-run per D18: a full-screen panel shown on session start when
  `[startup].enabled`; first run walks through Theme, Wallpaper, Bar position, Keyboard
  layout, Power/Idle, Notifications — each step reuses existing Settings tabs rather than
  duplicating controls. "Skip" always available; a flag in
  `~/.local/state/xidou/` records completion.
- Depends on: most Settings tabs existing (so it's naturally late), logo for the splash.
- Verify: `[CLOUD]` for flow; `[SESSION]` for the finished look.

**M25 — Appearance > Effects tab**
- What: per D20. Probably picom-level (shadows, blur behind panels — needs `glx`) plus
  panel-level opacity. The bar's own Effects tab (`a941b03`) is a precedent for the QML
  side.
- Depends on: T0-3, D20. Verify: `[SESSION]` (and note CLAUDE.md's warning that picom
  GLX + `layer.effect` can render blank under Xvfb).

### 5.3 Heavy

**H1 — Multiple bars, duplicate, export/import**
- What: config moves from `[bar]` to `[[bars]]` (with a one-time migration that keeps an
  existing `[bar]` working), each bar with its own id, monitor, position, modules, and
  look tables. `shell.qml` instantiates one `Bar` per entry. Settings > Bar gets a bar
  picker (+ Add, Duplicate, Delete, Export, Import). Two bars on the same edge must
  stack struts correctly — the strut logic lives in dwm (`37c9415`), so check it handles
  multiple dock windows on one edge.
- Depends on: F3, D21. Note the bar's config is now much larger (`[bar.layout]`,
  `.shape`, `.effects`, `.widgets`, `.capsules`) — all of it moves under each
  `[[bars]]` entry, which makes the migration bigger than it looked before `a941b03`.
  Verify: logic `[CLOUD]`; strut stacking `[SESSION]`.

**H2 — Overview (GNOME-style)**
- What: full-screen panel showing every tag as a group of window thumbnails; click to
  go there; later drag between tags. Thumbnails: a C helper using XComposite
  (`XCompositeNameWindowPixmap`) to dump PNGs of each client — possible because this dwm
  keeps hidden clients mapped offscreen (1.6). Refresh on open, not continuously.
- Depends on: F1, M14 (reuse its model), D16. Verify: `[SESSION]` (compositor
  interaction with picom must be checked on the real GPU).

**H3 — Tag-switch and window-move animations ("Niri-style")**

Feasibility investigation, 2026-09-27. Source reading only: this repo's `dwm/dwm.c`
and picom upstream HEAD (`3502b29`, 2026-09-20). **Nothing has been observed on real
hardware yet**, and the installed picom version on the X1CG5 is unknown. Every picom
claim below is "true of upstream HEAD" until step 1 confirms it locally.

*What dwm does on a tag switch (confirmed from source)*
- `view()` → `focus(NULL)` → `arrange()` → `showhide(m->stack)` → `arrangemon()` →
  `restack()`.
- `showhide()` (`dwm.c:2195`) issues one `XMoveWindow` per client. Hide:
  `XMoveWindow(win, WIDTH(c) * -2, c->y)` — y kept, x set to minus twice the
  client's own width (border included). Show: `XMoveWindow(win, c->x, c->y)`. `c->x`
  is never overwritten on hide, so a shown client returns exactly where it was. No
  unmap, no resize to zero.
- The layout's `resize()` calls are no-ops when geometry is unchanged
  (`applysizehints()` returns false, `dwm.c:471`), so a plain tag switch sends pure
  position changes. The `showhide` moves are unsynced and flush together at
  `restack()`'s `XSync`.
- dwm contains no animation code; today's open/close animations are all picom's.
  `picom.conf` configures only `open`/`show`/`close`/`hide` — no position/size/
  geometry trigger is in use anywhere, so tag switches are currently instant.

*Would picom's `position` trigger fire? (upstream source)*
- Yes, by construction. `win_process_animation_and_state_change()` (`src/wm/win.c`)
  compares each window's previous-frame geometry with its current geometry once per
  frame. A mapped window that only moved gets `ANIMATION_TRIGGER_POSITION`. X events
  are drained before each frame, so dwm's single flush should start all windows'
  animations in the same frame (worst case one frame apart).
- Caveats: the `size`/`position` triggers and `saved-image-blend` are marked
  EXPERIMENTAL in the manpage. The trigger fires on every dwm-initiated move — relayout
  on open/close, mfact, directional swap, and every motion event of a mouse drag, which
  would restart the animation continuously. `size` has priority when both size and
  position change.

*Predicted look with no dwm change (to be confirmed in step 1)*
- Displacement differs per window: the hide target is `-2 × own width`, so windows of
  different widths travel different distances in the same duration, and relative
  positions distort mid-animation.
- Outgoing windows slide left, while incoming windows arrive from the left moving
  right, so the two sets cross. The direction is the same whichever tag you go to.
- picom animates windows independently, with no group concept. The previous "each
  window animates on its own" ceiling still applies, just through a different
  trigger.
- Key insight: per-window picom animations *read* as one cohesive slide only when
  every window's displacement vector is identical. Start frame, duration, and easing
  can already be aligned; displacement is what must be made uniform.

*Script-language limits (upstream)*
- Expressions support only `+ - * / ^`: no conditionals, no min/max. So one script
  cannot tell a tag-switch move from a relayout move.
- Context variables do include `window-x-before`/`-y-before` and `window-monitor-*`.
  Output variables include `offset-x/y` and `crop-*`.
- Curves: `linear`, `cubic-bezier`, `steps` — no spring.
- Window `rules` can match X properties and assign per-window `animations`.

*Steps (each needs はる's approval before it starts)*

1. **Real-hardware baseline — not done yet.** Needs the X1CG5; a cloud container has
   neither picom nor the real session. Exact procedure: "H3 step 1 handoff" below,
   written for はる's regular Claude Code session (Remote Control on the X1CG5).
2. **dwm marker patch + picom rules** (only if step 1 shows the trigger works).
   - Before every geometry change dwm makes, set `_XIDOU_MOTION` on the client:
     `tag-in-left`, `tag-out-right`, `layout`, `drag`, ... Direction comes from
     comparing old and new tag numbers — explicit numbers, never next/prev
     (lesson #6).
   - picom rules match the property. Tag scripts animate `offset-x` by exactly
     ±monitor width (incoming: `±window-monitor-width → 0`; outgoing: from
     `window-x-before - window-x` to that minus/plus monitor width), cropped to the
     monitor. This makes displacement uniform, so the slide reads as one surface.
   - `drag` gets no animation.
   - Optionally wrap `showhide` in `XGrabServer`/`XUngrabServer` so all changes reach
     picom in one batch.
   - First gate: confirm that the property change and the geometry change are
     evaluated in the same picom frame (plausible from source, unverified). If not,
     this path fails.
3. **Same mechanism for relayout moves** (open/close/swap), with a separate script.
4. **Alternatives, only if 2 fails:**
   - (a) dwm interpolates `XMoveWindow` itself on a timerfd. Coordinated and
     interruptible, but not vsync-aligned with picom, so judder is likely.
   - (b) A Quickshell overlay slides before/after snapshots. Perfectly rigid, and
     gesture-trackable in principle, but capture latency delays the start —
     needs measuring.
   - (c) A picom fork — not recommended (1.5 #4).

*H3 step 1 handoff — for the local Claude Code session on the X1CG5*

Goal: see what dwm's **current, unmodified** tag switch looks like under the most naive
picom `position` animation, and report it honestly. This is observation only: no
dwm/QML/config changes, and no fixes. The prediction to confirm or refute: windows
travel different distances, and outgoing/incoming windows cross in opposite
directions.

Ground rules
- Never edit `session/picom.conf`, `~/.config/xidou/config.toml`, or anything under
  `dwm/`. The test picom runs from `/tmp/xidou-h3/`.
- Use tags 8 and 9 for test windows (switch to 7 as the "empty" tag), after
  confirming with `dwm-msg get_tags` that they're empty. Close every test window at
  the end.
- はる watches the screen. Claude drives the commands and reads the logs and frames.
  How it *looks* is her call.
- If a step fails in a way not covered here, stop, restore the real picom (step H),
  and report — don't improvise fixes.
- Don't install anything (e.g. ffmpeg) without asking はる first.

A. Environment (the SSH/tmux shell has no display by default)
```sh
REPO=/home/haru/projects/xidou-shell
eval "$(tr '\0' '\n' < /proc/$(pgrep -x dwm)/environ | grep -E '^(DISPLAY|XAUTHORITY)=' | sed 's/^/export /')"
echo "DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY"   # DISPLAY must be set; empty XAUTHORITY means ~/.Xauthority is used
mkdir -p /tmp/xidou-h3 && cd /tmp/xidou-h3
picom --version | tee version.txt
pgrep -a picom | tee original-picom.txt          # expected: picom --config $REPO/session/picom.conf
xrandr | grep ' connected' | tee screen.txt
command -v ffmpeg xdotool maim | tee tools.txt
```
- `position`/`size`/`geometry` triggers need picom v12 or later. If the version is
  older, record it, skip to H, and report — the whole H3 premise changes.

B. Build the throwaway configs: the real `picom.conf` with only its
MotionSync-managed `animations` block replaced. Dry-run verified against the repo
copy: the only difference is the added `position` entry.
```sh
cat > anim.conf <<'CONF'
animations = (
    {
        triggers = [ "open", "show" ];
        preset = "appear";
        scale = 0.92;
        duration = 0.15;
    },
    {
        triggers = [ "close", "hide" ];
        preset = "disappear";
        scale = 0.92;
        duration = 0.15;
    },
    {
        # H3 step 1 probe: the naive position animation, on purpose.
        triggers = [ "position" ];
        offset-x = {
            curve = "linear";
            duration = 1.0;
            start = "window-x-before - window-x";
            end = 0;
        };
        offset-y = {
            curve = "linear";
            duration = 1.0;
            start = "window-y-before - window-y";
            end = 0;
        };
        shadow-offset-x = "offset-x";
        shadow-offset-y = "offset-y";
    }
);
CONF
REAL="$REPO/session/picom.conf"
[ "$(grep -c '^# >>> XIDOU MANAGED: motion\|^# <<< XIDOU MANAGED: motion' "$REAL")" = 2 ] || echo "MARKERS MISSING -- stop"
awk -v f=anim.conf '
/^# >>> XIDOU MANAGED: motion/ { print; while ((getline l < f) > 0) print l; skip = 1; next }
/^# <<< XIDOU MANAGED: motion/ { skip = 0 }
!skip' "$REAL" > test-xrender.conf
sed 's/^backend = "xrender";/backend = "glx";/' test-xrender.conf > test-glx.conf
diff "$REAL" test-xrender.conf; grep -n '^backend' test-*.conf
```
The 1.0 s linear duration is deliberately slow so the paths are easy to see. Step F
repeats at a realistic speed.

C. Swap picom (panels briefly lose transparency between kill and restart — expected)
```sh
pkill -x picom; sleep 0.5
setsid -f picom --config /tmp/xidou-h3/test-xrender.conf --log-level debug --log-file /tmp/xidou-h3/picom-xrender.log
sleep 1; pgrep -a picom; grep -iE 'error|warn|invalid' picom-xrender.log | head
```
- If picom exited or logged a config/trigger error, record it, go to H, and report.

D. Test windows. Four windows on tag 8 get two different widths under dwindle; one
window on tag 9.
```sh
dwm-msg get_tags   # confirm tags 7-9 are unoccupied first; if not, pick empty tags and adjust the masks below
dwm-msg --ignore-reply run_command view 128   # tag 8
for i in 1 2 3 4; do setsid -f kitty --class xidou-h3-test; sleep 0.7; done
dwm-msg --ignore-reply run_command view 256   # tag 9
setsid -f kitty --class xidou-h3-test; sleep 0.7
```

E. Observe (はる watching). Leave about 3 s between switches so each 1 s animation
finishes.
```sh
: > marks.txt
for m in 128 256 128 256; do date +%s.%N >> marks.txt; dwm-msg --ignore-reply run_command view $m; sleep 3; done
grep -c 'Starting animation position' picom-xrender.log   # >0 means the trigger fired
```
- Occupied ↔ empty: `view 128` ↔ `view 64`.
- Rapid switching: `for m in 128 256 128 256 128; do dwm-msg --ignore-reply run_command view $m; sleep 0.2; done`
  (tests interruption — the prediction is visible jumps).
- Relayout: close one tag-8 window with `super+q` while viewing tag 8 (the others
  re-tile).
- Drag: はる super+left-drags a window after toggling it floating (`super+f`)
  (prediction: laggy or jittery, since every motion event restarts the animation).
- Optional recording, only if ffmpeg is already installed:
  `ffmpeg -loglevel error -f x11grab -framerate 60 -video_size <WxH from screen.txt> -i "$DISPLAY" -t 8 rec-xrender.mkv &`
  then run the E loop. Extract frames around one switch with
  `ffmpeg -i rec-xrender.mkv -vf fps=10 -ss <t> -t 1.2 frame-%02d.png` and inspect
  them. If the frames show no motion while はる saw motion, note that `x11grab` may
  not capture the composited output, and trust her eyes.

F. Realistic speed: redo C→E with `duration = 0.25;` (both entries)
```sh
sed -i 's/duration = 1.0;/duration = 0.25;/' test-xrender.conf
```

G. Backend comparison: redo C→F with `test-glx.conf` (log to `picom-glx.log`; in F,
run the `sed` on `test-glx.conf`). Note
smoothness differences and anything rendered blank or broken.

H. Restore — always, even after a failure
```sh
pkill -f 'kitty --class xidou-h3-test'
pkill -x picom; sleep 0.5
setsid -f picom --config /home/haru/projects/xidou-shell/session/picom.conf
sleep 1; pgrep -a picom; cat /tmp/xidou-h3/original-picom.txt   # the two must match
cd /home/haru/projects/xidou-shell && git status --short   # expect no changes from this procedure
```

I. Report. Commit to the PR branch without disturbing はる's own checkout:
```sh
cd /home/haru/projects/xidou-shell
git fetch origin claude/feature-backlog-planning-30biw8
git worktree add ../xidou-h3-report claude/feature-backlog-planning-30biw8
```
Fill in "H3 step 1 results" below in `../xidou-h3-report/docs/ROADMAP.md`, commit,
push, then `git worktree remove ../xidou-h3-report`. Answer each question plainly —
"looks bad" is a valid result.

*H3 step 1 results* — not yet run

| Question | Result |
|---|---|
| picom version / backend(s) tested | |
| Did `position` fire on tag switch? (log count, and what はる saw) | |
| Did windows travel visibly different distances/speeds? | |
| Did outgoing and incoming windows cross? Same direction regardless of target tag? | |
| Occupied ↔ empty tag: how did it look? | |
| Rapid switching: jumps? stuck windows? | |
| Relayout on window close: animated? pleasant or distracting? | |
| Floating-window drag: laggy/jittery? | |
| 0.25 s: tolerable as a daily setting, or clearly worse than no animation? | |
| xrender vs glx: smoothness, artifacts | |
| はる's verdict: is step 2 (dwm marker patch) worth pursuing? | |
| Anything unexpected | |

*Out of reach via picom, even if step 2 succeeds*
- 1:1 touchpad tracking: animations are time-driven from a trigger, with no external
  progress input.
- Smooth retargeting on rapid switches: a new trigger restarts from the script's start
  values, and there's no "current animated offset" variable, so the window visibly
  jumps.
- Spring physics.
- Input during animation lands on final positions.
- Empty tags show motion on one side only.
- Niri's defining scrolling-column *layout* is a layout, not an animation. A scrolling
  dwm layout would, as a side effect, produce uniform displacements that picom's
  per-window animations render cohesively, but it's a new-layout-sized project.

- Depends on: T0-3 (backend, picom version), D19. Verify: `[SESSION]` + `[HW]` only.

**H4 — dwm runtime settings: gaps/borders/layout params, window rules, keybinds**
- What: dwm reads everything from `config.h` at compile time. To edit from Settings:
  (a) numeric settings (border width, corner radius, mfact, nmaster) via new IPC
  setters, following the gaps precedent from `a941b03` (1.7) — but pushed live from the
  shell, not from xinitrc;
  (b) window rules from a runtime list instead of `rules[]`; (c) keybinds from a runtime
  table — the largest part, since dwm grabs keys by keysym at startup and on mapping
  changes. Also unify the three independent corner radii (dwm `cornerradius`, picom
  `corner-radius`, `[theme].radius`) that the comments already flag as unshared.
- Window Rules GUI: list + "add rule from focused window" (class from F1).
- Depends on: F1, F3, D1, D19. Verify: `[CLOUD]` with a test dwm for most of it.

**H5 — Display settings and Display Profiles**
- What: Settings > Display: resolution, refresh rate, position, primary, scale. Scaling
  on X11 is not one knob: `Xft.dpi` (most toolkits, needs app restart), `QT_SCALE_FACTOR`
  / `GDK_SCALE` (session restart), or `xrandr --scale` (blurry). Be honest in the UI
  about which require a relogin. Profiles: save/restore layouts, auto-switch on hotplug
  (`autorandr` is the proven backend on X11).
- Depends on: T0-3. Verify: `[HW]` — needs an external monitor to test at all.

**H6 — Screenshot editor**
- What: per D17. If built: a QML canvas over the captured image — crop, pen, arrow,
  rectangle, blur/pixelate region, highlight — with export via ImageMagick (lesson #3:
  always write real PNGs through ImageMagick).
- Depends on: L11. Verify: `[CLOUD]` for export; `[SESSION]` for drawing feel.

**H7 — Management-console extras: Undo, Presets, Safe Mode**
- Undo: keep the last N `cachedText` snapshots of config.toml; Settings header gets an
  Undo button. Cheap once written — could be Moderate.
- Presets: = M17 + H1's bar export, surfaced together.
- Safe Mode: if Quickshell crashes K times within M seconds (xinitrc wrapper loop),
  restart it with `$XIDOU_CONFIG_PATH` pointed at an empty file (all defaults) and show
  a notification. Needs the xinitrc to supervise Quickshell instead of a single
  background `&`.
- Verify: `[CLOUD]` for Undo; Safe Mode `[SESSION]`.

**H8 — XidouWM identity / forks**
- Per D19 and 1.5. Rename is Light (binary name, desktop file, IPC socket default path,
  docs). A picom fork is not planned.

---

## 6. Additional bar ideas (you asked for more)

Not scheduled yet — pick what you like and it becomes an item.

- **Conditional visibility per widget:** media only while something plays, bluetooth
  only when powered on, battery only on battery power, tray only when non-empty.
- **Scroll actions per widget:** volume/brightness by wheel, workspaces by wheel (as
  explicit tag numbers), media seek.
- **Hover tooltips** with detail (e.g. CPU widget → top 3 processes; weather → today's
  range).
- **Urgent-tag highlight** on Workspaces — dwm-ipc already exports `urgent` in
  `tag_state`, so this is almost free.
- **Fullscreen behavior:** hide the bar, or make it opaque, while the focused client is
  fullscreen (`is_fullscreen` is already in IPC).
- **Per-monitor module lists** (becomes natural with H1).
- **Badges:** unread notification count on a control-center/notifications button.
- **Separator widget** with style (line / dot / gap).
- **Bar profiles** switchable from Switchboard ("Focus" = minimal bar, "Full").
- **Middle-click slot** on every widget (e.g. middle-click on volume = switch output
  device).
- **Widget entrance animation** when a conditionally visible widget appears (uses F4).

## 7. Sound effect ideas (for M22)

Default-on candidates: notification arrival (different for critical urgency), battery
low / critical, charger plugged / unplugged, screenshot shutter, lock and unlock (plus a
soft "denied" on a wrong password), USB device connected / removed, Bluetooth device
connected, wallpaper change (the paper-slide you described), volume change tick
(rate-limited so holding the key doesn't machine-gun).

Default-off candidates: launcher open, app launched, tag switch, panel open/close,
Settings reset (long-press completion), startup chime.

All of them: muted during DND, one global volume, one global off switch.

---

## 8. Parked

- **[微妙] Device Center** — mostly overlaps CC Audio/Bluetooth/Network and H5's Display
  settings. Revisit after those exist; if anything is missing then, it's probably just
  a "USB devices" list.
- **Community wallpapers tab** — stub in `Wallpaper.qml` ("no online source decided
  yet"); not in the backlog, left alone.

---

## 9. Dependency map

```mermaid
graph LR
  T03[T0-3 HW inventory] --> M3[M3 battery/power]
  T03 --> M2
  T03 --> M23[M23 gestures]
  T03 --> H5[H5 display]
  T03 --> H3[H3 tag animations]
  T03 --> M25[M25 effects tab]
  F1[F1 dwm-ipc client metadata] --> M14[M14 switcher]
  F1 --> H2[H2 overview]
  F1 --> M20[M20 screen time]
  F1 --> M11[M11 data widgets]
  F1 --> H4[H4 dwm runtime config / rules / keybinds]
  F2[F2 CC open-to-section] --> M8[M8 click model]
  F2 --> L7[L7 notif stacking]
  F3[F3 TOML arrays of tables] --> H1[H1 multiple bars]
  F3 --> H4
  F4[F4 Motion tokens] --> M21[M21 motion system + a11y]
  F4 --> L1[L1 Motion tab]
  F5[F5 widget wrapper] --> M8
  F5 --> L8[L8 button widgets]
  F5 --> M11
  F6[F6 sound service] --> M22[M22 sound effects]
  F6 -.optional.-> L5[L5 reset polish]
  M1[M1 lock hardening] --> M2[M2 idle + dimming]
  M2 --> M20
  M12[M12 action registry / Switchboard v2] --> M8
  M12 --> M10[M10 dead zone]
  M12 --> M23
  M14 --> H2
  L9[L9 clipboard search] --> M15[M15 clipboard categories]
  L11[L11 screenshot action bar] --> H6[H6 editor]
  L14[L14 gaps settings] -.pattern.-> H4
  M6[M6 GTK settings / xsettingsd] -.nicer.-> M4[M4 templates]
```

---

## 10. Suggested order

Priority is: safety first, then foundations that many items share, then things used
every day, then looks, then big bets. Within a milestone, order is flexible.

**Milestone 0 — housekeeping (needs はる at the machine for T0-3)**
~~T0-1~~ (done), T0-2, T0-3.

**Milestone A — safety and foundations**
M1 (lock hardening), F1, F2, F4, M16 (Health — cheap, and it's the philosophy).

**Milestone B — the bar, finished properly**
F5 (shared components first), M12's action registry (the list, before its UI), M8,
M9, M10, M7, L8, L12, L14, M3. The styling layer is done; this milestone is about
behavior and adding widgets.

**Milestone C — daily comfort**
L4, L2, L3, L7, M2, M12 (Switchboard UI), L9, L11, L6, L5, M14.

**Milestone D — look and feel**
L1, M21, M5, M4, M6, L13, F6 + M22, M25, M13.

**Milestone E — window management**
M18, M19, M20, M15, H2.

**Milestone F — big bets**
F3 + H1, H4, H5, H3, H6, H7, M24 (splash / first-run / logo — naturally last, as
CLAUDE.md already planned), H8.

---

## 11. Notes for whoever implements an item

- Re-read CLAUDE.md and the auto-memory file first; re-check this document's status
  table against `git log` — it will drift.
- Test under Xvfb with `$XIDOU_CONFIG_PATH` (and `$XIDOU_DWM_SOCKET` for a test dwm).
  Never touch the real config from a test run.
- Any new daemon goes in `session/xidou-xinitrc`'s `ensure_running` block; system-level
  services (tailscaled, TLP) do not — they are runit services.
- Every matugen call keeps `--source-color-index 0`.
- Material Symbols codepoints come from fontTools, never typed by hand.
- Items tagged `[SESSION]`/`[HW]` are not "done" until はる has tried them on the X1CG5.
  A cloud session should say so in its commit message and in CLAUDE.md rather than
  claim completion.
