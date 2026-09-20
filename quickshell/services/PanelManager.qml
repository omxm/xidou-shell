pragma Singleton

import QtQuick
import Quickshell

// Central visibility + mutual exclusivity for every dock panel (Launcher,
// control-center, and whatever Phase 6/7 add: wallpaper, clipboard,
// session). Exactly one dock panel is ever open at a time -- opening one
// closes whatever else was open instead of stacking, which is what left
// Launcher and control-center both visible/stacked before this existed.
//
// A panel plugs in by adding its name to `openPanels` below (default
// false) and binding `visible: PanelManager.isOpen("name") && ...` instead
// of a bespoke bool property — new panels don't need any other panel's
// code touched. Not persisted, not config-driven (that lives in
// Config.qml) — pure transient UI state.
Singleton {
    id: root

    property var openPanels: ({
        "launcher": false,
        "control-center": false,
        "wallpaper": false,
        "session": false
    })

    function isOpen(name) {
        return !!root.openPanels[name];
    }

    // Opens `name`, closing whatever else was open. Toggling an
    // already-open panel closes it instead (same as the old PanelState
    // behavior), so a bind's second press still just dismisses the panel.
    function toggle(name) {
        if (!(name in root.openPanels)) {
            console.warn("[xidou] PanelManager.toggle: unknown panel '" + name + "'");
            return;
        }
        var wasOpen = root.openPanels[name];
        var next = {};
        for (var key in root.openPanels)
            next[key] = false;
        if (!wasOpen)
            next[name] = true;
        root.openPanels = next;
    }

    function close(name) {
        if (!root.openPanels[name])
            return;
        var next = Object.assign({}, root.openPanels);
        next[name] = false;
        root.openPanels = next;
    }

    // For SessionActions.lock()/logout()/reboot()/shutdown() -- these need
    // every dock panel gone (nothing left interactive behind/through the
    // lock screen, nothing left open across a session that's about to end)
    // without opening a replacement the way toggle(name) would.
    function closeAll() {
        var next = {};
        for (var key in root.openPanels)
            next[key] = false;
        root.openPanels = next;
    }
}
