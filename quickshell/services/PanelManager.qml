pragma Singleton

import QtQuick
import Quickshell
import "../config"

// Central visibility + mutual exclusivity for every dock panel (Launcher,
// control-center, wallpaper, clipboard, session, settings). Exactly one
// dock panel is ever open at a time -- opening one
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
        "session": false,
        "clipboard": false,
        "settings": false
    })

    function isOpen(name) {
        return !!root.openPanels[name];
    }

    // Opens `name`, closing whatever else was open. Toggling an
    // already-open panel closes it instead (same as the old PanelState
    // behavior), so a bind's second press still just dismisses the panel.
    function toggle(name) {
        // Every panel-opening path (the "panels"/"settings" IPC targets,
        // dwm keybinds through them, Launcher's requestToggle, bar clicks)
        // funnels through here, so this one check keeps the lock screen
        // from having anything opened over or behind it.
        if (SessionActions.locked) {
            console.warn("[xidou] PanelManager.toggle: ignoring '" + name + "' while locked");
            return;
        }
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
        SoundFx.play(wasOpen ? "panel_close" : "panel_open");
    }

    // `silent` skips the close sound, for a close that is part of an
    // action with its own sound (launching an app, picking an emoji).
    // panel name -> section it should show, set by open(name, section) and
    // read by that panel (ControlCenter.qml) when it opens. `sectionRequested`
    // covers a panel that is already open, so it switches in place.
    property var requestedSections: ({})
    signal sectionRequested(string name, string section)

    // Opens `name` (closing whatever else is open, like toggle()) without
    // toggling: a panel that is already open stays open. `section` (optional)
    // asks the panel to show that section instead of its default
    // (ROADMAP F2, e.g. `xidou msg control-center open Audio`).
    function open(name, section) {
        if (SessionActions.locked) {
            console.warn("[xidou] PanelManager.open: ignoring '" + name + "' while locked");
            return;
        }
        if (!(name in root.openPanels)) {
            console.warn("[xidou] PanelManager.open: unknown panel '" + name + "'");
            return;
        }
        var wasOpen = root.openPanels[name];
        var req = Object.assign({}, root.requestedSections);
        req[name] = section || "";
        root.requestedSections = req;
        if (wasOpen) {
            if (section)
                root.sectionRequested(name, section);
            return;
        }
        var next = {};
        for (var key in root.openPanels)
            next[key] = false;
        next[name] = true;
        root.openPanels = next;
        SoundFx.play("panel_open");
    }

    // Returns the section requested for `name` and clears it, so a later
    // plain toggle() opens the panel at its default again.
    function takeRequestedSection(name) {
        var section = root.requestedSections[name] || "";
        if (section) {
            var req = Object.assign({}, root.requestedSections);
            delete req[name];
            root.requestedSections = req;
        }
        return section;
    }

    function close(name, silent) {
        if (!root.openPanels[name])
            return;
        var next = Object.assign({}, root.openPanels);
        next[name] = false;
        root.openPanels = next;
        if (!silent)
            SoundFx.play("panel_close");
    }

    // For SessionActions.lock()/logout()/reboot()/shutdown() -- these need
    // every dock panel gone (nothing left interactive behind/through the
    // lock screen, nothing left open across a session that's about to end)
    // without opening a replacement the way toggle(name) would. `silent`
    // skips the close sound, for callers that play their own (lock,
    // session end).
    function closeAll(silent) {
        var hadOpen = root.anyOpen();
        var next = {};
        for (var key in root.openPanels)
            next[key] = false;
        root.openPanels = next;
        if (hadOpen && !silent)
            SoundFx.play("panel_close");
    }

    function anyOpen() {
        for (var key in root.openPanels)
            if (root.openPanels[key])
                return true;
        return false;
    }

    // Closes every panel, then runs `fn` once they are gone from the screen:
    // after picom's close animation ([motion] duration) plus a margin for
    // the unmap itself. Runs `fn` right away if nothing was open. Used by
    // screenshots, so a panel that was open when Print was pressed doesn't
    // end up in the picture. Time-based: neither the unmap nor the
    // compositor's animation reports back when it's done.
    property var pendingAfterClose: null

    function closeAllThen(fn) {
        if (!root.anyOpen()) {
            fn();
            return;
        }
        root.closeAll();
        root.pendingAfterClose = fn;
        var motion = Config.data.motion;
        settleTimer.interval = (motion.enabled ? Math.round(motion.duration * 1000) : 0) + 150;
        settleTimer.restart();
    }

    Timer {
        id: settleTimer
        onTriggered: {
            var fn = root.pendingAfterClose;
            root.pendingAfterClose = null;
            if (fn)
                fn();
        }
    }
}
