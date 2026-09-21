pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Read-only view onto bin/xidou-clipd's manifest (started from
// session/xidou-xinitrc, like pipewire/picom) -- this singleton never
// touches clipnotify itself, and only shells out to xclip for copy() below.
// Each history entry lives as its own file on disk (never embedded as a JS
// string), so arbitrary clipboard content round-trips with no
// shell-escaping anywhere -- see bin/xidou-clipd's own header comment for
// why.
Singleton {
    id: root

    readonly property string clipDir: Quickshell.env("HOME") + "/.cache/xidou/clipboard"
    readonly property string manifestPath: root.clipDir + "/index"

    property var entries: [] // [{type: "text"|"image", ts, path}], newest first

    FileView {
        id: manifestFile
        path: root.manifestPath
        watchChanges: true
        printErrors: false

        onLoaded: root.parse(manifestFile.text())
        // fileChanged only means the manifest changed on disk, not that
        // it's been re-read yet -- text() right after it fires can still
        // return pre-change content. reload() forces the read; its
        // completion re-fires onLoaded above. See the project memory on
        // this exact FileView gotcha (found while building Config.setValue()).
        onFileChanged: manifestFile.reload()
        onLoadFailed: root.entries = []
    }

    function parse(text) {
        var lines = text.split("\n");
        var out = [];
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line)
                continue;
            var parts = line.split(" ");
            if (parts.length !== 2)
                continue;
            var ext = parts[0];
            var ts = parts[1];
            out.push({
                type: ext === "png" ? "image" : "text",
                ts: ts,
                path: root.clipDir + "/" + ts + "." + ext
            });
        }
        root.entries = out;
    }

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    Process {
        id: copyProc
    }

    // Re-asserts entries[index] as the live CLIPBOARD selection so the next
    // Ctrl+V anywhere picks it back up -- doesn't paste by itself, same as
    // clipmenu/CopyQ. xclip reads the content straight off disk, so this
    // never interpolates arbitrary clipboard content into a shell string.
    function copy(index) {
        if (index < 0 || index >= root.entries.length)
            return;
        var entry = root.entries[index];
        var cmd = entry.type === "image"
            ? "xclip -selection clipboard -t image/png -i < " + shQuote(entry.path)
            : "xclip -selection clipboard -i < " + shQuote(entry.path);
        copyProc.command = ["sh", "-c", cmd];
        copyProc.running = false;
        copyProc.running = true;
    }
}
