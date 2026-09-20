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

    readonly property string configPath: Quickshell.env("HOME") + "/.config/xidou/config.toml"

    readonly property var defaults: ({
        shell: {
            name: "Xidou",
            version: "0.1.0"
        },
        theme: {
            mode: "dark",
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
            font_size: 14
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
        panels: {
            control_center: { enabled: true, keybind: "super+s" },
            launcher: { enabled: true, keybind: "super+d" },
            wallpaper: { enabled: true, keybind: "super+y", directories: ["~/Pictures/Wallpapers"] },
            clipboard: { enabled: true, keybind: "super+v" },
            notification: { enabled: true, dnd_keybind: "super+n" },
            session: { enabled: true, keybind: "super+escape", lock_keybind: "super+l" }
        },
        startup: {
            enabled: true,
            logo: "~/.config/xidou/assets/logo.svg"
        }
    })

    property var data: defaults

    signal reloaded()

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        printErrors: false

        onLoaded: root.applyText(configFile.text())
        onLoadFailed: function (error) {
            console.warn("[xidou] no readable config at " + root.configPath + " — using built-in defaults");
            root.data = root.defaults;
            root.reloaded();
        }
        onFileChanged: root.applyText(configFile.text())
    }

    function applyText(text) {
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
