import QtQuick
import Quickshell
import Quickshell.Io

// One long-lived `xidouwm-msg subscribe ...` stream, emitting each event as
// a parsed object. xidouwm-msg pretty-prints each event as multi-line JSON
// (not one line per event), so SplitParser's newline-delimited chunks are
// JSON *fragments*, not whole documents -- accumulate them here, tracking
// brace depth (string/escape-aware, so braces inside a quoted value like a
// window title don't miscount), and only hand a chunk to JSON.parse once it
// closes its top-level object. Restarted on exit (e.g. dwm restarting) so
// the shell recovers without a manual reload.
Scope {
    id: root

    property var command: []
    readonly property alias running: proc.running

    signal event(var obj)
    signal exited()

    property string buffer: ""
    property int braceDepth: 0
    property bool inString: false
    property bool escapeNext: false

    Process {
        id: proc
        command: root.command
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.bufferChunk(data)
        }

        onExited: {
            root.buffer = "";
            root.braceDepth = 0;
            root.inString = false;
            root.escapeNext = false;
            root.exited();
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: proc.running = true
    }

    function bufferChunk(chunk) {
        if (!chunk)
            return;
        // SplitParser strips the newline; put it back so the reassembled
        // text is valid whitespace-separated JSON.
        var text = chunk + "\n";
        for (var i = 0; i < text.length; i++) {
            var ch = text[i];
            root.buffer += ch;

            if (root.escapeNext) {
                root.escapeNext = false;
                continue;
            }
            if (root.inString) {
                if (ch === "\\")
                    root.escapeNext = true;
                else if (ch === "\"")
                    root.inString = false;
                continue;
            }
            if (ch === "\"") {
                root.inString = true;
            } else if (ch === "{") {
                root.braceDepth++;
            } else if (ch === "}") {
                root.braceDepth--;
                if (root.braceDepth === 0) {
                    root.dispatch(root.buffer);
                    root.buffer = "";
                }
            }
        }
    }

    function dispatch(text) {
        var trimmed = text.trim();
        if (!trimmed)
            return;
        try {
            root.event(JSON.parse(trimmed));
        } catch (e) {
            console.warn("[xidou] xidouwm-msg subscribe: failed to parse event: " + trimmed);
        }
    }
}
