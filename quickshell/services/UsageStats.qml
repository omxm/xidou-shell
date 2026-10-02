pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Frequency-of-use tracking shared by App Search, Emoji Picker and the bar's
// widget add-picker (Settings > Bar > Modules, ROADMAP M9) --
// one singleton rather than duplicating the same persistence boilerplate
// per feature, since "count usage, persist, sort by it" is one concern.
// Storage mirrors Favorites.qml exactly: a small JSON file under
// ~/.config/xidou, a FileView for read+watch, and a save() that shells out
// to printf rather than fighting FileView's write API for something this
// simple.
//
// Namespaced ({"apps": {...}, "emoji": {...}, "widgets": {...}}) rather
// than one file each, since all are the same shape (string key -> use
// count) and a single small file is simpler to reason about.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/xidou/usage_counts.json"
    readonly property var namespaces: ["apps", "emoji", "widgets"]
    property var counts: root.emptyCounts()

    // A fresh {namespace: {}} for every namespace, filled from `parsed`
    // where it has one (a file written before a namespace existed just
    // lacks that key).
    function emptyCounts(parsed) {
        var result = {};
        root.namespaces.forEach(function (ns) {
            result[ns] = Object.assign({}, (parsed && parsed[ns]) || {});
        });
        return result;
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: function (error) {
            root.counts = root.emptyCounts();
        }
    }

    function applyText(text) {
        try {
            root.counts = root.emptyCounts(JSON.parse(text));
        } catch (e) {
            console.warn("[xidou] UsageStats: failed to parse " + root.path + ": " + e);
            root.counts = root.emptyCounts();
        }
    }

    function getCount(namespace, key) {
        var ns = root.counts[namespace];
        return (ns && ns[key]) || 0;
    }

    // Increments and persists in one call -- every caller wants both, and
    // splitting them invites the "changed the count, forgot to save" bug.
    function recordUse(namespace, key) {
        var next = root.emptyCounts(root.counts);
        if (!(namespace in next)) {
            console.warn("[xidou] UsageStats.recordUse: unknown namespace '" + namespace + "'");
            return;
        }
        next[namespace][key] = (next[namespace][key] || 0) + 1;
        root.counts = next;
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
        var json = JSON.stringify(root.counts);
        var cmd = "mkdir -p " + shQuote(dir) + " && printf '%s' " + shQuote(json) + " > " + shQuote(root.path);
        saveProc.command = ["sh", "-c", cmd];
        saveProc.running = false;
        saveProc.running = true;
    }
}
