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
    // touching the real one -- same convention as dwm's $XIDOU_DWM_SOCKET
    // override (dwm/dwm.c) for the same reason: a test instance shouldn't
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
            position: "top",
            height: 32,
            modules_left: ["logo", "workspaces"],
            modules_center: ["media", "clock", "weather"],
            modules_right: ["tray", "mem", "cpu", "bluetooth", "volume", "dnd", "power"]
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
            save_directory: "~/Pictures/Screenshots"
        },
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
