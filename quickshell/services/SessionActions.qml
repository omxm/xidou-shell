pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared session actions (lock/logout/reboot/shutdown) -- the one place
// both the "session" IpcHandler (`xidou msg session lock`, dwm's super+l)
// and the session menu panel's buttons/number-keys call into, so there's
// exactly one lock/logout/reboot/shutdown implementation, not two that can
// drift apart.
Singleton {
    id: root

    property bool locked: false

    function lock() {
        PanelManager.closeAll();
        root.locked = true;
    }

    function unlock() {
        root.locked = false;
    }

    function logout() {
        // dwm is the session's exec'd process (session/xidou-xinitrc) --
        // quitting it ends the X session, same as dwm's own super+shift+e
        // bind. This is window-manager lifecycle, not shell UI state, so it
        // goes through dwm-ipc (dwm-msg) rather than Quickshell's own IPC.
        PanelManager.closeAll();
        logoutProc.running = false;
        logoutProc.running = true;
    }

    function reboot() {
        PanelManager.closeAll();
        rebootProc.running = false;
        rebootProc.running = true;
    }

    function shutdown() {
        PanelManager.closeAll();
        shutdownProc.running = false;
        shutdownProc.running = true;
    }

    Process {
        id: logoutProc
        command: ["dwm-msg", "run_command", "quit"]
    }

    // loginctl (elogind) rather than a bare `reboot`/`poweroff` binary call --
    // goes through the session manager's own permission model for the
    // seated user instead of needing this session's sudo allowlist extended
    // for something this destructive.
    Process {
        id: rebootProc
        command: ["loginctl", "reboot"]
    }

    Process {
        id: shutdownProc
        command: ["loginctl", "poweroff"]
    }
}
