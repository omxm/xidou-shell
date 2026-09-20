pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Favorited wallpaper paths, persisted as a small JSON array. Config.qml's
// directory is user preference data (which folders to scan), so this lives
// alongside it under ~/.config/xidou rather than ~/.cache -- it's not
// derived/regeneratable the way colors.json is.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/xidou/favorites.json"
    property var paths: []

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: function (error) {
            root.paths = [];
        }
    }

    function applyText(text) {
        try {
            var parsed = JSON.parse(text);
            root.paths = Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            console.warn("[xidou] Favorites: failed to parse " + root.path + ": " + e);
            root.paths = [];
        }
    }

    function isFavorite(wallpaperPath) {
        return root.paths.indexOf(wallpaperPath) !== -1;
    }

    function toggle(wallpaperPath) {
        var next = root.paths.slice();
        var idx = next.indexOf(wallpaperPath);
        if (idx === -1)
            next.push(wallpaperPath);
        else
            next.splice(idx, 1);
        root.paths = next;
        save();
    }

    Process {
        id: saveProc
    }

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function save() {
        var dir = Quickshell.env("HOME") + "/.config/xidou";
        var json = JSON.stringify(root.paths);
        var cmd = "mkdir -p " + shQuote(dir) + " && printf '%s' " + shQuote(json) + " > " + shQuote(root.path);
        saveProc.command = ["sh", "-c", cmd];
        saveProc.running = false;
        saveProc.running = true;
    }
}
