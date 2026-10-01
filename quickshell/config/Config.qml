pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Toml.js" as Toml

// Loads ~/.config/xidou/config.toml and exposes it as `Config.data`, deep-merged
// onto built-in defaults so the shell works before the user has written a config
// file, and so a partial config only needs to override the keys it cares about.
// Every panel reads layout/behavior settings from here; colors and fonts go
// through Theme.qml instead, which derives from Config.data.theme.
Singleton {
    id: root

    // Overridable via $XIDOU_CONFIG_PATH so a test instance (Xvfb runs, in
    // particular) can point at a throwaway config file instead of ever
    // touching the real one -- same convention as dwm's $XIDOU_WM_SOCKET
    // override (xidouwm/dwm.c) for the same reason: a test instance shouldn't
    // share live state with a real one. Falls back to the real path when
    // unset or empty.
    readonly property string configPath: {
        var override = Quickshell.env("XIDOU_CONFIG_PATH");
        return (override && override.length > 0) ? override : (Quickshell.env("HOME") + "/.config/xidou/config.toml");
    }

    readonly property var defaults: ({
        shell: {
            name: "Xidou",
            version: "0.1.0"
        },
        theme: {
            mode: "dark",
            // builtin: use the static colors below. wallpaper: use
            // services/ColorScheme.qml's matugen-derived palette instead
            // (falls back to builtin until the first regenerate() completes).
            source: "builtin", // builtin | wallpaper
            accent: "#c9b890",
            background: "#1a1a1a",
            surface: "#242424",
            surface_alt: "#2e2e2e",
            text: "#eaeaea",
            text_muted: "#9a9a9a",
            border: "#3a3a3a",
            warning: "#e06c75", // Mem/CPU widgets recolor to this at/above their configured usage threshold
            radius: 10,
            font_family: "Inter",
            icon_font_family: "Material Symbols Outlined",
            font_size: 14,
            // Active matugen --type for wallpaper-driven generation -- must
            // be one of scheme_presets' values below. Friendly display names
            // live in config (not hardcoded in QML) specifically so the
            // wallpaper-picker's preset dropdown can be renamed/reordered
            // without a code change; matugen's own real values (confirmed
            // against its --help, not guessed) have no "Soft"/"Vibrant"
            // naming of their own -- that's Noctalia's UI convention, borrowed
            // here as a naming style, not copied as literal flag values.
            scheme_type: "scheme-tonal-spot",
            scheme_presets: {
                "Soft": "scheme-tonal-spot",
                "Vibrant": "scheme-vibrant",
                "Expressive": "scheme-expressive",
                "Muted": "scheme-neutral",
                "Monochrome": "scheme-monochrome",
                "Playful": "scheme-fruit-salad",
                "Rainbow": "scheme-rainbow",
                "Faithful": "scheme-fidelity",
                "Natural": "scheme-content",
                "Smart": "scheme-smart"
            }
        },
        bar: {
            enabled: true,
            position: "top",
            height: 32,
            // off: always shown (current/original behavior). on: hidden
            // except a thin sliver at the screen edge, revealed on hover.
            // smart: same reveal mechanic, but only auto-hides while the
            // focused monitor's *currently viewed tag* actually has a
            // client on it (dwm-ipc's tag_state.occupied & .selected,
            // Bar.qml's own tagOccupied) -- an empty tag just shows the bar
            // normally, same as off.
            auto_hide: "off", // off | on | smart
            // Forced to behave as false (UI greys it out) whenever
            // auto_hide != "off" -- a bar that's hidden most of the time
            // can't sensibly reserve permanent strut space; Bar.qml's own
            // exclusiveZone binding hardcodes 0 in that case regardless of
            // this value, so the value itself is preserved (not silently
            // rewritten) for whenever auto_hide goes back to "off".
            reserve_space: true,
            // Bar > Layout. content_scale/font_scale are two independent
            // scaling axes: content_scale is a genuine uniform visual zoom
            // (Bar.qml's capsuleModuleComponent applies a real `scale:`
            // transform to each module and resizes its wrapper to match, so
            // Row spacing accounts for the zoomed footprint -- no overlap),
            // while font_scale only multiplies the font.pixelSize each bar
            // module already binds to Theme.fontSize, leaving padding/
            // spacing/capsule size alone. ends_margin + edge_margin together
            // are what makes a "floating bar" -- shortened from both
            // horizontal ends AND lifted off the screen edge it's anchored
            // to, at the same time.
            layout: {
                content_scale: 1.0,      // 0.5-1.5, uniform per-widget zoom
                font_scale: 1.0,          // 0.5-1.5, text/icon size only
                ends_margin: 0,           // px, shortens the bar from both horizontal ends
                edge_margin: 0,           // px, gap between the bar and the screen edge it's anchored to
                opposite_edge_margin: 0,  // px, extra reserved strut space beyond the bar's own thickness
                content_padding: 8,       // px, inner horizontal inset around all module content (was hardcoded Theme.fontSize/2)
                panel_overlap: 0          // px (Advanced) -- lets windows tile this many px under the bar's edge, reducing the reserved strut below the bar's own thickness
            },
            modules_left: ["logo", "workspaces"],
            modules_center: ["media", "clock", "weather"],
            modules_right: ["tray", "mem", "cpu", "bluetooth", "volume", "dnd", "power"],
            // Bar-wide capsule styling -- wraps every module's background in
            // a pill shape when enabled. Bar-wide only for now; a per-widget
            // Presentation override layer (letting one module opt out of or
            // override these) is real future work, not built here. Fill is
            // a Theme role name (Bar.qml's own capsuleFillColor maps it to
            // the real color), not a literal hex, same "no color literals
            // outside Theme.qml" rule as everywhere else.
            capsules: {
                enabled: false,
                thickness: 0.8,     // fraction of bar.height
                // Bar.qml's capsule Rectangle clamps this to half of its
                // own (width, height) at render time -- Qt does NOT do this
                // automatically (confirmed empirically: an unclamped radius
                // bigger than that renders as a distorted over-rounded
                // blob, not a clean capped pill). 20 already clamps down to
                // a full pill at every realistic bar height/thickness
                // combination, while staying a sane, human-readable number
                // in the settings UI instead of an arbitrary sentinel like
                // 999.
                radius: 20,
                fill: "surface_alt", // surface | surface_alt | accent | background
                padding: 10,        // horizontal inset each side, px
                border_width: 0,    // 0 = no border; color is always Theme.border, not independently configurable
                opacity: 1.0
            },
            // Bar > Shape: the bar's own outer silhouette. Bar.qml itself
            // has zero rounding capability before this -- its PanelWindow
            // painted `color: Theme.background` directly (a Window property,
            // not Rectangle's radius), so this isn't "unwired settings" over
            // an existing mechanism, it's genuinely new rendering (a
            // transparent PanelWindow + an inner Rectangle doing the actual
            // painting, same pattern Osd.qml already established). *_radius
            // default to -1 ("inherit corner_radius") rather than a real
            // pixel value -- 0 would be indistinguishable from "explicitly
            // square," which is a real, different, selectable state.
            shape: {
                corner_radius: 12,
                top_left_radius: -1,
                top_right_radius: -1,
                bottom_left_radius: -1,
                bottom_right_radius: -1,
                // "Corner Flow": the bar's outer corners (along whichever
                // edge it's anchored to) flare all the way out to the true
                // screen corner with a concave sweep, rather than receding
                // from it the way normal rounding does -- only meaningful
                // when the bar is flush against the screen (edge_margin AND
                // ends_margin both 0); Bar.qml's own cornerFlowActive
                // ignores this otherwise, and the settings UI greys the
                // control out to match, same "value currently does
                // nothing" convention as Reserve Space under Auto-Hide.
                corner_flow: false,
                border_enabled: false,
                border_width: 1
            },
            // Bar > Effects. Shadow is QtQuick.Effects' MultiEffect (Qt
            // 6.5+, native -- no Qt5Compat.GraphicalEffects needed at this
            // project's Qt 6.11.2), applied via layer.effect directly on
            // the background Rectangle. Contact Shadow is purely aesthetic
            // -- no "a panel is docked against the bar" concept exists
            // anywhere in the shell today (the floating panels that read
            // barReservedHeight only use it to center themselves in the
            // remaining screen space, never to attach flush against the
            // bar), so this just draws a fixed gradient at the bar's own
            // edge regardless of what's actually beneath it.
            effects: {
                background_opacity: 1.0,
                shadow_enabled: false,
                contact_shadow_enabled: false
            },
            // Bar > Widgets: the bar-wide DEFAULT layer a future per-widget
            // Presentation override layer is meant to sit on top of --
            // deferred separately, not built here, but this is its
            // foundation. color/icon_color only replace the "normal/
            // active-state" Theme.text leaf each of the 12 module files'
            // color expressions already has (confirmed via direct
            // inspection, not every module even has one -- Weather/Cpu/Mem/
            // Dnd/Workspaces/Logo intentionally keep their own textMuted/
            // warning/accent state colors and brand accent untouched, since
            // a blanket override would erase real state feedback, e.g.
            // making Bluetooth's on/off states indistinguishable). Icon and
            // label were always tied to the exact same color expression
            // before this -- letting them diverge is new. font_weight only
            // applies to label text, never icon glyphs (Material Symbols'
            // own variable-font weight axis is a separate, unrelated
            // concern this doesn't touch).
            widgets: {
                font_family: "",       // "" = inherit theme.font_family
                font_weight: "normal", // normal | medium | bold
                spacing: 7,             // px, between modules within a lane (was hardcoded Theme.fontSize/2 -- 7 matches that at the default font_size)
                color: "",              // "" = inherit Theme.text
                icon_color: "",         // "" = inherit Theme.text
                hover_highlight: false
            }
        },
        // Window gaps for the tiling layout -- a real dwm feature
        // (xidouwm/fibonacci.c), not a Quickshell-side cosmetic effect. Pushed
        // into dwm once at session start via session/xidou-xinitrc calling
        // its setgappih/setgappoh IPC commands once dwm's socket is up.
        // Read here only so a future settings-panel UI has a real
        // Config.data/Config.setValue path to plug into -- nothing in
        // Quickshell itself consumes this today.
        layout: {
            gap_inner: 5, // px between adjacent windows
            gap_outer: 5  // px between a window and the screen edge
        },
        weather: {
            enabled: true,
            // Resolution priority: auto_locate (IP geolocation) > city
            // (Open-Meteo geocoding) > latitude/longitude used as-is.
            auto_locate: true,
            city: "",
            latitude: 0.0,
            longitude: 0.0,
            units: "celsius" // celsius | fahrenheit
        },
        // Per-bar-widget display settings -- distinct from [weather] above
        // (location/units, shared across the bar module, Home tab's card,
        // and control-center's own Weather tab) since these three only
        // affect how the *bar's* copy of the widget renders, same
        // "self-contained per-module" convention bar/modules/Weather.qml's
        // own header comment already documents for the data-fetching side.
        // Namespaced by widget name (nested table, not a flat
        // bar_widgets_weather_max_length-style key) so future widgets with
        // their own real display settings land in the same table without
        // key collisions -- same shape as [panels] holding one sub-table
        // per panel.
        bar_widgets: {
            weather: {
                max_length: 0,          // 0 = unlimited; truncates the combined label to this many characters
                show_condition: false,  // append the WMO condition word (e.g. "Cloudy") after the temperature
                show_temperature: true  // false hides the temperature -- only meaningful combined with show_condition true, otherwise the widget just goes empty
            },
            clock: {
                time_format: "24h", // 24h | 12h
                timezone: ""         // IANA zone name (e.g. "America/New_York"); "" = system's local timezone
            },
            workspaces: {
                hide_when_empty: false,
                style: "regular",   // regular | minimal | focus_hint
                show_icons: false   // only visible in practice under focus_hint -- the other two styles have no icon slot to show it in
            },
            media: {
                album_art_only: false, // show only a small art thumbnail (or a fallback icon) instead of the title/artist text
                hide_artist: false,    // title only -- overrides artist_first below, since there's no artist left to reorder
                artist_first: false    // "Artist — Title" instead of the default "Title — Artist"
            },
            volume: {
                show_percentage: true // false hides the numeric label, icon only
            },
            bluetooth: {
                show_device_count: true // false hides the connected-device count, icon only
            },
            tray: {
                icon_size: 0 // 0 = default (Theme.fontSize + 4); otherwise an explicit pixel size
            },
            mem: {
                warning_threshold: 90 // usedPercent at/above this recolors the widget to Theme.warning; 100 = never
            },
            cpu: {
                warning_threshold: 90 // usagePercent at/above this recolors the widget to Theme.warning; 100 = never
            },
            power: {
                show_percentage: true,   // false hides the numeric label, icon only
                low_battery_threshold: 20 // percent at/below which the "battery_alert" icon shows instead of "battery_full"
            }
        },
        osd: {
            width: 220,
            height: 56,
            position: "top-center", // top-left | top-center | top-right | bottom-left | bottom-center | bottom-right
            margin: 8 // gap from the bar/screen edge the position anchors to
        },
        notification: {
            position: "top-right", // same values as [osd].position
            margin: 12,
            width: 320,
            spacing: 8,       // gap between stacked notification cards
            timeout_ms: 5000  // default auto-dismiss; overridden per-notification when the sender sets its own expire timeout
        },
        motion: {
            enabled: true,
            duration: 0.15, // seconds; drives both open/show and close/hide legs
            // Intensity, not an easing curve -- picom's own "appear"/
            // "disappear" preset only exposes scale+duration, no curve
            // param (confirmed against its manpage); real easing control
            // would mean hand-writing hand Advanced-syntax animation
            // scripts instead of using the preset at all. Explicit call:
            // stay on the preset, ship intensity levels only. Real values
            // live in lib/PicomSync.js's PRESET_SCALES, not duplicated here.
            preset: "normal" // subtle | normal | pronounced
        },
        screenshot: {
            freeze_during_selection: true,  // freeze the desktop behind a static backdrop during region-select, rather than re-capturing live
            confirm_selection: true,        // show the Save/Cancel preview dialog after a capture, rather than saving instantly
            remember_last_region: false,    // off by default: with no second keybind for "reselect", turning this on leaves no way back to a fresh selection short of restarting the shell
            include_cursor: false,          // include the mouse pointer in the captured image
            save_directory: "~/Pictures/Screenshots",
            // L3: what happens to a finished capture. At least one stays on;
            // Settings greys out the Off that would leave neither, and
            // Screenshot.qml saves the file anyway if both end up false.
            save_to_file: true,
            copy_to_clipboard: true
        },
        // Sound effects (ROADMAP F6/M22; operations and cues in
        // lib/SoundMap.js). Volume = cue default x category volume x master
        // volume. Each category's `extra` lists operations that are off by
        // default (hover, typing, focus moves...) to turn on anyway.
        sound: {
            enabled: true,
            volume: 1.0,
            pack: "zen", // not in the UI yet; assets/sounds/<pack>/
            panels: { enabled: true, volume: 1.0, extra: [] },
            controls: { enabled: true, volume: 1.0, extra: [] },
            windows: { enabled: true, volume: 1.0, extra: [] },
            media: { enabled: true, volume: 1.0, extra: [] },
            notifications: { enabled: true, volume: 1.0, extra: [] },
            capture: { enabled: true, volume: 1.0, extra: [] },
            devices: { enabled: true, volume: 1.0, extra: [] },
            session: { enabled: true, volume: 1.0, extra: [] },
            system: { enabled: true, volume: 1.0, extra: [] }
        },
        // L16. Applied with `xinput set-prop` to every device that has
        // libinput's DWT property (services/InputSettings.qml).
        input: {
            touchpad: {
                disable_while_typing: false
            }
        },
        // keybind / dnd_keybind / lock_keybind are documentation only for
        // now: nothing reads them, and every key binding lives in xidouwm's
        // config.h (xidouwm/config.def.h). They become real with ROADMAP H4.
        panels: {
            control_center: { enabled: true, keybind: "super+e" },
            launcher: { enabled: true, keybind: "super+d" },
            wallpaper: { enabled: true, keybind: "super+y", directories: ["~/Pictures/Wallpapers"] },
            clipboard: { enabled: true, keybind: "super+v" },
            notification: { enabled: true, dnd_keybind: "super+n" },
            session: { enabled: true, keybind: "super+escape", lock_keybind: "super+l" },
            settings: { enabled: true, keybind: "super+comma" }
        },
        startup: {
            enabled: true,
            logo: "~/.config/xidou/assets/logo.svg"
        }
    })

    property var data: defaults

    // The exact text `data` was last parsed from -- setValue() below reads
    // this instead of configFile.text() as its base, so that chaining
    // several setValue() calls back-to-back (e.g. a settings page's "reset
    // all" resetting three keys in one go) doesn't race: confirmed
    // empirically that configFile.text(), read again immediately after a
    // setText() call, doesn't reliably reflect that write yet, so a second
    // setValue() call built on top of it can silently discard the first
    // call's change when it computes its own new text and writes it back.
    // applyText() below keeps this in sync on every load AND every write.
    property string cachedText: ""

    // True once the initial read has actually completed (loaded OR
    // load-failed) -- guards setValue() below. Before this, configFile.text()
    // can read back empty even though a real file exists on disk (the async
    // read just hasn't finished yet), and writing from that empty text would
    // silently blow away the real file's content instead of editing it.
    property bool ready: false

    signal reloaded()

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        printErrors: false

        onLoaded: {
            // ready must flip before applyText() emits reloaded() -- a
            // listener reacting to that signal (e.g. a settings panel)
            // should already see a trustworthy `ready`.
            root.ready = true;
            root.applyText(configFile.text());
        }
        onLoadFailed: function (error) {
            console.warn("[xidou] no readable config at " + root.configPath + " — using built-in defaults");
            root.data = root.defaults;
            root.ready = true;
            root.reloaded();
        }
        // fileChanged is only a notification that the file changed on disk
        // -- confirmed empirically that configFile.text() right after it
        // fires can still return the pre-change content, because nothing
        // has actually re-read the file yet. reload() does that; its
        // completion re-fires onLoaded above, which is what actually calls
        // applyText().
        onFileChanged: configFile.reload()
    }

    function applyText(text) {
        root.cachedText = text;
        try {
            var parsed = Toml.parse(text);
            root.data = deepMerge(root.defaults, parsed);
            console.log("[xidou] config loaded from " + root.configPath);
        } catch (e) {
            console.warn("[xidou] failed to parse " + root.configPath + ": " + e + " — using built-in defaults");
            root.data = root.defaults;
        }
        root.reloaded();
    }

    // Single write entry point for the whole shell (the settings panel is
    // the only intended caller) -- edits config.toml in place via
    // Toml.setValue() rather than regenerating it from `data`, so comments
    // and any manual edits survive. `tableHeader` is the exact dotted string
    // that would appear inside the brackets, e.g. "theme" or
    // "panels.clipboard". `data` is applied directly from the exact text
    // just written for immediate feedback -- watchChanges' own
    // reload()-based round-trip (above) will also pick this same write up
    // and re-apply it a moment later, redundantly but harmlessly.
    function setValue(tableHeader, key, value) {
        if (!root.ready) {
            console.warn("[xidou] Config.setValue: ignoring write to " + tableHeader + "." + key + " — config hasn't finished its initial load yet");
            return;
        }
        var newText = Toml.setValue(root.cachedText, tableHeader, key, value);
        configFile.setText(newText);
        root.applyText(newText);
    }

    function isPlainObject(value) {
        return typeof value === "object" && value !== null && !Array.isArray(value);
    }

    // Recursively overlays `overrides` onto `base`; arrays and scalars are
    // replaced wholesale rather than merged element-by-element.
    function deepMerge(base, overrides) {
        var result = {};
        for (var key in base)
            result[key] = base[key];
        for (var key2 in overrides) {
            if (isPlainObject(overrides[key2]) && isPlainObject(result[key2]))
                result[key2] = deepMerge(result[key2], overrides[key2]);
            else
                result[key2] = overrides[key2];
        }
        return result;
    }
}
