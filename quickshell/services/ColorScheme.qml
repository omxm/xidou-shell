pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper-driven color generation via matugen, shelled out to exactly the
// way Noctalia itself does (not a reimplementation of its color-science
// logic in QML/JS) — see CLAUDE.md's Phase 6 note and lesson #2.
//
// matugen's own `-j hex` mode only writes JSON to its stdout, not to a file
// directly, so regenerate() pipes that stdout to a fixed path via a plain
// shell redirection rather than fighting FileView's write API for
// something this simple. A separate read-only FileView (same reactive
// pattern as Config.qml) watches that fixed path and reacts to it changing
// on disk, decoupled from whatever process last wrote it.
//
// CRITICAL: matugen hangs forever waiting on an interactive TTY color
// picker unless invoked with --source-color-index 0 -- every invocation
// here must keep that flag. Confirmed against matugen 4.2.0's own --help
// (not assumed): this is exactly what disables the picker prompt.
Singleton {
    id: root

    readonly property string colorsPath: Quickshell.env("HOME") + "/.cache/xidou/colors.json"

    // Null until the first successful regenerate()+reload, so Theme.qml can
    // tell "not generated yet" apart from "generated, but somehow empty".
    property var colors: null
    property bool generating: false
    property string lastError: ""

    function get(key) {
        if (!root.colors || !root.colors.colors || !root.colors.colors[key])
            return null;
        var entry = root.colors.colors[key];
        return (entry.default && entry.default.color) || null;
    }

    // Quotes a single argument for embedding in the `sh -c` string below --
    // needed because the eventual wallpaper path comes from user files
    // (spaces, etc. are realistic), not just this phase's hardcoded test path.
    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    FileView {
        id: colorsFile
        path: root.colorsPath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: function (error) {
            // Expected on a fresh install before the first regenerate() —
            // not an error worth surfacing, just "no wallpaper palette yet".
            root.colors = null;
        }
    }

    function applyText(text) {
        try {
            root.colors = JSON.parse(text);
            root.lastError = "";
        } catch (e) {
            root.lastError = "failed to parse " + root.colorsPath + ": " + e;
            console.warn("[xidou] ColorScheme: " + root.lastError);
        }
    }

    Process {
        id: matugenProc
        // No stdout collector: the shell command below redirects matugen's
        // own stdout straight to colorsPath, so nothing reaches this
        // process's stdout to collect.
        stderr: StdioCollector {
            id: stderrCollector
        }
        // exitCode is a parameter of this signal, not a readable property on
        // Process itself -- confirmed against Quickshell.Io's own qmltypes
        // rather than assumed.
        onExited: function (exitCode, exitStatus) {
            root.generating = false;
            if (exitCode !== 0) {
                root.lastError = "matugen exited " + exitCode + ": " + stderrCollector.text;
                console.warn("[xidou] ColorScheme: " + root.lastError);
            } else {
                colorsFile.reload();
            }
        }
    }

    // mode: "dark" | "light" | "smart" (matugen's own values -- config.toml's
    // theme.mode "auto" should be mapped to "smart" by the caller).
    // schemeType: one of matugen's real --type values (default handled by
    // matugen itself if omitted) -- see CLAUDE.md's Phase 6 note; there is
    // no literal "soft" value, that's Noctalia's own preset naming.
    function regenerate(imagePath, mode, schemeType) {
        if (!imagePath) {
            console.warn("[xidou] ColorScheme.regenerate: no image path given");
            return;
        }
        root.generating = true;
        root.lastError = "";
        var cacheDir = Quickshell.env("HOME") + "/.cache/xidou";
        var typeArg = schemeType ? ("-t " + shQuote(schemeType) + " ") : "";
        var cmd = "mkdir -p " + shQuote(cacheDir) + " && matugen image " + shQuote(imagePath)
            + " --source-color-index 0 -j hex --mode " + shQuote(mode || "dark") + " "
            + typeArg + "> " + shQuote(root.colorsPath);
        matugenProc.command = ["sh", "-c", cmd];
        matugenProc.running = false;
        matugenProc.running = true;
    }
}
