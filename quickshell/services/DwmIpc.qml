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
                        byNum[parsed[i].num] = parsed[i];
                        if (parsed[i].is_selected)
                            root.focusedMonitor = parsed[i].num;
                    }
                    root.monitorsByNum = byNum;
                    root.connected = true;
                } catch (e) {
                    console.warn("[xidou] dwm-msg get_monitors: failed to parse output: " + e);
                }
            }
        }
    }

    Process {
        id: runCommand
    }

    // Long-lived subscription: one line of JSON per dwm-ipc event. Restarted
    // on exit (e.g. dwm restarting) so the shell recovers without a manual
    // reload.
    Process {
        id: subscribe
        command: [root.dwmMsg, "--ignore-reply", "subscribe", "tag_change_event", "monitor_focus_change_event"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleEvent(data)
        }

        onExited: {
            root.connected = false;
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: subscribe.running = true
    }

    function handleEvent(line) {
        if (!line)
            return;
        var event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            console.warn("[xidou] dwm-msg subscribe: failed to parse event: " + line);
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
        }
    }

    Component.onCompleted: {
        getTags.running = true;
        getMonitors.running = true;
    }
}
