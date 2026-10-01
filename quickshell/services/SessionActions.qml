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
        PanelManager.closeAll(true);
        if (!root.locked)
            SoundFx.play("lock");
        root.locked = true;
    }

    function unlock() {
        if (root.locked)
            SoundFx.play("unlock");
        root.locked = false;
    }

    // Log out, restart and shut down start the "stop" cue and run once it
    // ends, or after 0.4 s at most (SoundFx.playThen(), ROADMAP M22). If
    // the cue can't play, they run immediately.
    function logout() {
        // dwm is the session's exec'd process (session/xidou-xinitrc) --
        // quitting it ends the X session, same as dwm's own super+shift+e
        // bind. This is window-manager lifecycle, not shell UI state, so it
        // goes through dwm-ipc (xidouwm-msg) rather than Quickshell's own IPC.
        PanelManager.closeAll(true);
        SoundFx.playThen("session_end", function () {
            logoutProc.running = false;
            logoutProc.running = true;
        });
    }

    function reboot() {
        PanelManager.closeAll(true);
        SoundFx.playThen("session_end", function () {
            rebootProc.running = false;
            rebootProc.running = true;
        });
    }

    function shutdown() {
        PanelManager.closeAll(true);
        SoundFx.playThen("session_end", function () {
            shutdownProc.running = false;
            shutdownProc.running = true;
        });
    }

    Process {
        id: logoutProc
        command: ["xidouwm-msg", "run_command", "quit"]
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
