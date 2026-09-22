pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bridges to dwm's IPC socket by shelling out to `dwm-msg`, the CLI helper
// built alongside dwm (see ../../dwm/dwm-msg.c), instead of re-implementing
// dwm-ipc's binary framing (magic header + length + yajl payload) in QML —
// dwm-msg already speaks that protocol correctly and is the tool the dwm-ipc
// patch itself ships for this purpose.
//
// Every module that needs tag/monitor state reads it from here rather than
// spawning its own dwm-msg process, so there is exactly one subscription and
// one source of truth for dwm state across the whole shell.
Singleton {
    id: root

    readonly property string dwmMsg: "dwm-msg"

    // [{ name, bitMask }], in tag order as reported by dwm.
    property var tags: []

    // Raw dwm-ipc monitor objects (see dwm/yajl_dumps.c: dump_monitor),
    // keyed by monitor number.
    property var monitorsByNum: ({})

    property int focusedMonitor: 0
    property bool connected: false

    // The currently-focused client window id per monitor -- seeded from
    // get_monitors' clients.selected at startup, then kept live by
    // client_focus_change_event (a subscription this file didn't use
    // before Workspaces' Focus Hint style needed it). Distinct from
    // monitorsByNum[n].clients.selected, which is only ever as fresh as
    // the last full get_monitors call and goes stale the moment focus
    // moves without a tag switch.
    property var focusedWinIdByMonitor: ({})

    function tagStateFor(monNum) {
        var mon = monitorsByNum[monNum];
        return mon ? mon.tag_state : null;
    }

    function viewTag(bitMask) {
        runCommand.command = [root.dwmMsg, "--ignore-reply", "run_command", "view", String(bitMask)];
        runCommand.running = false;
        runCommand.running = true;
    }

    Process {
        id: getTags
        command: [root.dwmMsg, "get_tags"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    root.tags = parsed.map(function (t) {
                        return { name: t.name, bitMask: t.bit_mask };
                    });
                } catch (e) {
                    console.warn("[xidou] dwm-msg get_tags: failed to parse output: " + e);
                }
            }
        }
    }

    Process {
        id: getMonitors
        command: [root.dwmMsg, "get_monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    var byNum = {};
                    for (var i = 0; i < parsed.length; i++) {
                        var mon = parsed[i];
                        // dwm only populates tag_state (selected/occupied/urgent)
                        // once the first tag-changing event fires after startup;
                        // until then it's all zero even though a tag is actually
                        // active. Seed "selected" from tagset.current so the bar
                        // highlights the right tag before any switch happens.
                        if (mon.tag_state && mon.tag_state.selected === 0 && mon.tagset)
                            mon.tag_state.selected = mon.tagset.current;
                        byNum[mon.num] = mon;
                        if (mon.is_selected)
                            root.focusedMonitor = mon.num;
                    }
                    root.monitorsByNum = byNum;
                    root.connected = true;

                    // One-time seed (get_monitors only ever runs once, at
                    // startup) -- client_focus_change_event keeps this
                    // live from here on.
                    var focusedByNum = {};
                    for (var j = 0; j < parsed.length; j++)
                        focusedByNum[parsed[j].num] = parsed[j].clients ? parsed[j].clients.selected : 0;
                    root.focusedWinIdByMonitor = focusedByNum;
                } catch (e) {
                    console.warn("[xidou] dwm-msg get_monitors: failed to parse output: " + e);
                }
            }
        }
    }

    Process {
        id: runCommand
    }

    // Long-lived subscription. dwm-msg pretty-prints each event as
    // multi-line JSON (not one line per event), so SplitParser's
    // newline-delimited chunks are JSON *fragments*, not whole documents —
    // accumulate them here, tracking brace depth (string/escape-aware, so
    // braces inside a quoted value like a window title don't miscount),
    // and only hand a chunk to JSON.parse once it closes its top-level
    // object. Restarted on exit (e.g. dwm restarting) so the shell
    // recovers without a manual reload.
    property string eventBuffer: ""
    property int eventBraceDepth: 0
    property bool eventInString: false
    property bool eventEscapeNext: false

    Process {
        id: subscribe
        command: [root.dwmMsg, "--ignore-reply", "subscribe", "tag_change_event", "monitor_focus_change_event", "client_focus_change_event"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.bufferEventChunk(data)
        }

        onExited: {
            root.connected = false;
            root.eventBuffer = "";
            root.eventBraceDepth = 0;
            root.eventInString = false;
            root.eventEscapeNext = false;
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: subscribe.running = true
    }

    // Called once per newline-delimited chunk from the subscribe stream;
    // appends to eventBuffer and dispatches to handleEvent() only once a
    // complete top-level JSON object has been accumulated.
    function bufferEventChunk(chunk) {
        if (!chunk)
            return;
        // SplitParser strips the newline; put it back so the reassembled
        // text is valid whitespace-separated JSON, matching the original
        // pretty-printed output.
        var text = chunk + "\n";
        for (var i = 0; i < text.length; i++) {
            var ch = text[i];
            root.eventBuffer += ch;

            if (root.eventEscapeNext) {
                root.eventEscapeNext = false;
                continue;
            }
            if (root.eventInString) {
                if (ch === "\\")
                    root.eventEscapeNext = true;
                else if (ch === "\"")
                    root.eventInString = false;
                continue;
            }
            if (ch === "\"") {
                root.eventInString = true;
            } else if (ch === "{") {
                root.eventBraceDepth++;
            } else if (ch === "}") {
                root.eventBraceDepth--;
                if (root.eventBraceDepth === 0) {
                    root.handleEvent(root.eventBuffer);
                    root.eventBuffer = "";
                }
            }
        }
    }

    function handleEvent(text) {
        var trimmed = text.trim();
        if (!trimmed)
            return;
        var event;
        try {
            event = JSON.parse(trimmed);
        } catch (e) {
            console.warn("[xidou] dwm-msg subscribe: failed to parse event: " + trimmed);
            return;
        }

        if (event.tag_change_event) {
            var e = event.tag_change_event;
            var mon = root.monitorsByNum[e.monitor_number];
            if (mon) {
                var updated = Object.assign({}, mon, { tag_state: e.new_state });
                var byNum = Object.assign({}, root.monitorsByNum);
                byNum[e.monitor_number] = updated;
                root.monitorsByNum = byNum;
            }
        } else if (event.monitor_focus_change_event) {
            root.focusedMonitor = event.monitor_focus_change_event.new_monitor_number;
        } else if (event.client_focus_change_event) {
            var c = event.client_focus_change_event;
            var focusedByNum2 = Object.assign({}, root.focusedWinIdByMonitor);
            focusedByNum2[c.monitor_number] = c.new_win_id || 0;
            root.focusedWinIdByMonitor = focusedByNum2;
        }
    }

    Component.onCompleted: {
        getTags.running = true;
        getMonitors.running = true;
    }
}
