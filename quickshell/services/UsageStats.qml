pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Frequency-of-use tracking shared by App Search and Emoji Picker --
// one singleton rather than duplicating the same persistence boilerplate
// per feature, since "count usage, persist, sort by it" is one concern.
// Storage mirrors Favorites.qml exactly: a small JSON file under
// ~/.config/xidou, a FileView for read+watch, and a save() that shells out
// to printf rather than fighting FileView's write API for something this
// simple.
//
// Namespaced ({"apps": {...}, "emoji": {...}}) rather than two separate
// files, since both are the same shape (string key -> use count) and a
// single small file is simpler to reason about than two.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/xidou/usage_counts.json"
    property var counts: ({
        apps: {},
        emoji: {}
    })

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: function (error) {
            root.counts = {
                apps: {},
                emoji: {}
            };
        }
    }

    function applyText(text) {
        try {
            var parsed = JSON.parse(text);
            root.counts = {
                apps: (parsed && parsed.apps) || {},
                emoji: (parsed && parsed.emoji) || {}
            };
        } catch (e) {
            console.warn("[xidou] UsageStats: failed to parse " + root.path + ": " + e);
            root.counts = {
                apps: {},
                emoji: {}
            };
        }
    }

    function getCount(namespace, key) {
        var ns = root.counts[namespace];
        return (ns && ns[key]) || 0;
    }

    // Increments and persists in one call -- every caller wants both, and
    // splitting them invites the "changed the count, forgot to save" bug.
    function recordUse(namespace, key) {
        var next = {
            apps: Object.assign({}, root.counts.apps),
            emoji: Object.assign({}, root.counts.emoji)
        };
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
