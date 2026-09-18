pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level for the X230's intel_backlight device, read straight from
// sysfs (see bin/xidou-brightness — no brightnessctl/light CLI is installed
// on this system). Unlike Volume.qml's Pipewire binding, plain sysfs writes
// don't push change notifications, so there is nothing to watch passively:
// refresh() is called explicitly by shell.qml's "osd" IpcHandler after
// bin/xidou-brightness has already written the new value.
Singleton {
    id: root

    readonly property string device: "/sys/class/backlight/intel_backlight"

    property int current: 0
    property int max: 1
    readonly property int percent: root.max > 0 ? Math.round(root.current * 100 / root.max) : 0

    // Set by refreshAndShow() so the OSD only appears once the freshly
    // written value has actually been read back, not the stale one.
    property bool pendingShow: false

    function refresh() {
        readProc.running = false;
        readProc.running = true;
    }

    function refreshAndShow() {
        root.pendingShow = true;
        root.refresh();
    }

    Process {
        id: readProc
        command: ["sh", "-c", "cat " + root.device + "/brightness " + root.device + "/max_brightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                if (lines.length >= 2) {
                    root.current = parseInt(lines[0], 10) || 0;
                    root.max = parseInt(lines[1], 10) || 1;
                }
                if (root.pendingShow) {
                    root.pendingShow = false;
                    OsdState.show("brightness");
                }
            }
        }
    }

    Component.onCompleted: refresh()
}
