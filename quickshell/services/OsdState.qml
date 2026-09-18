pragma Singleton

import QtQuick
import Quickshell

// Transient OSD visibility/kind state — mirrors PanelState's pattern (not
// persisted, not config-driven). One shared timer so a second trigger while
// the OSD is already showing (e.g. holding a volume key) restarts the
// dismiss countdown instead of racing an earlier one.
Singleton {
    id: root

    // 1.8s: no OSD timing is documented upstream for Noctalia to match
    // against, so this uses a sensible default in the 1.5-2s range CLAUDE.md
    // calls out.
    readonly property int dismissMs: 1800

    property bool visible: false
    property string kind: "" // "volume" | "brightness"

    function show(k) {
        root.kind = k;
        root.visible = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: root.dismissMs
        onTriggered: root.visible = false
    }
}
