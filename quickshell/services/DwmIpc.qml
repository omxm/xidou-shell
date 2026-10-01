pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bridges to dwm's IPC socket by shelling out to `xidouwm-msg`, the CLI helper
// built alongside dwm (see ../../xidouwm/dwm-msg.c), instead of re-implementing
// dwm-ipc's binary framing (magic header + length + yajl payload) in QML —
// xidouwm-msg already speaks that protocol correctly and is the tool the dwm-ipc
// patch itself ships for this purpose.
//
// Every module that needs tag/monitor state reads it from here rather than
// spawning its own xidouwm-msg process, so there is exactly one subscription and
// one source of truth for dwm state across the whole shell.
Singleton {
    id: root

    readonly property string dwmMsg: "xidouwm-msg"

    // [{ name, bitMask }], in tag order as reported by dwm.
    property var tags: []

    // Raw dwm-ipc monitor objects (see xidouwm/yajl_dumps.c: dump_monitor),
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
                    console.warn("[xidou] xidouwm-msg get_tags: failed to parse output: " + e);
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
                    console.warn("[xidou] xidouwm-msg get_monitors: failed to parse output: " + e);
                }
            }
        }
    }

    Process {
        id: runCommand
    }

    // Emitted from the event streams below, for services/SoundEvents.qml.
    // tagViewChanged only fires when the *viewed* tags change, not on
    // occupied/urgent changes. wmAction carries xidouwm's wm_action_event
    // ("kill", "send", "swap", "focus", "move_start", "move_end",
    // "resize_start", "resize_end").
    signal tagViewChanged(int monitor, int oldSelected, int newSelected)
    signal layoutChanged(int monitor)
    signal focusedStateChanged(var oldState, var newState)
    signal wmAction(string action)

    // The workspace widget's events, plus layout/state changes for sounds.
    // Every xidouwm supports these, so this stream never depends on a
    // newer binary.
    IpcEventStream {
        command: [root.dwmMsg, "--ignore-reply", "subscribe", "tag_change_event", "monitor_focus_change_event", "client_focus_change_event", "layout_change_event", "focused_state_change_event"]
        onEvent: obj => root.handleEvent(obj)
        onExited: root.connected = false
    }

    // wm_action_event is newer than the stream above. An older xidouwm
    // rejects the subscription; keeping it in its own stream means that
    // only costs the sounds of those actions, never the workspace widget.
    IpcEventStream {
        command: [root.dwmMsg, "--ignore-reply", "subscribe", "wm_action_event"]
        onEvent: obj => {
            if (obj.wm_action_event)
                root.wmAction(obj.wm_action_event.action);
        }
    }

    function handleEvent(event) {
        if (event.tag_change_event) {
            var e = event.tag_change_event;
            var mon = root.monitorsByNum[e.monitor_number];
            if (mon) {
                var updated = Object.assign({}, mon, { tag_state: e.new_state });
                var byNum = Object.assign({}, root.monitorsByNum);
                byNum[e.monitor_number] = updated;
                root.monitorsByNum = byNum;
            }
            if (e.old_state && e.new_state && e.old_state.selected !== e.new_state.selected)
                root.tagViewChanged(e.monitor_number, e.old_state.selected, e.new_state.selected);
        } else if (event.monitor_focus_change_event) {
            root.focusedMonitor = event.monitor_focus_change_event.new_monitor_number;
        } else if (event.client_focus_change_event) {
            var c = event.client_focus_change_event;
            var focusedByNum2 = Object.assign({}, root.focusedWinIdByMonitor);
            focusedByNum2[c.monitor_number] = c.new_win_id || 0;
            root.focusedWinIdByMonitor = focusedByNum2;
        } else if (event.layout_change_event) {
            root.layoutChanged(event.layout_change_event.monitor_number);
        } else if (event.focused_state_change_event) {
            var f = event.focused_state_change_event;
            root.focusedStateChanged(f.old_state, f.new_state);
        }
    }

    Component.onCompleted: {
        getTags.running = true;
        getMonitors.running = true;
    }
}
