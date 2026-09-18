pragma Singleton

import QtQuick
import Quickshell

// Transient panel visibility state — not persisted, not config-driven (that
// lives in Config.qml). One property per independent top-level panel, per
// CLAUDE.md's architecture: panels are separate windows toggled
// independently, not sections of one master window.
Singleton {
    id: root

    property bool launcherVisible: false

    function toggle(name) {
        if (name === "launcher")
            root.launcherVisible = !root.launcherVisible;
        else
            console.warn("[xidou] PanelState.toggle: unknown panel '" + name + "'");
    }
}
