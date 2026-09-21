pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Caffeine toggle backing (Home tab quick-toggle) -- holds a real elogind
// sleep/idle/lid-switch inhibitor for as long as it's active, via
// elogind-inhibit. Confirmed against the actual system, not assumed:
// `systemd-inhibit` does not exist here (runit init, no systemd, per
// CLAUDE.md); `elogind-inhibit` does, and is elogind's own drop-in
// equivalent (same CLI shape, points at the systemd-inhibit(1) man page
// itself).
//
// elogind-inhibit's lock lasts exactly as long as the child process it
// wraps ("execute a process while inhibiting..."), so the pattern here is:
// hold the lock by running a long-lived no-op child for as long as
// Caffeine is on, and release it by sending that child SIGTERM directly
// via Process.signal() -- not by toggling `running`. This is the first
// long-lived, externally-terminated Process in this codebase; every other
// Process here (SessionActions.qml, ColorScheme.qml) is a short one-shot
// command that has already exited on its own by the time it's restarted
// via the running=false/true toggle, so that pattern is untested for
// actually killing something still alive. signal() is the one QML API
// documented (Quickshell.Io's own qmltypes) for explicitly signalling a
// running child, so it's used here rather than assumed equivalence.
//
// Not persisted to config.toml: this is transient session state ("keep
// the machine awake right now"), not a preference -- a fresh shell
// instance starting with a remembered "on" state but no actual child
// process backing it would be worse than just always defaulting to off.
Singleton {
    id: root

    property bool active: false

    function toggle() {
        if (root.active) {
            inhibitProc.signal(15); // SIGTERM -- releases the elogind lock
        } else {
            inhibitProc.command = ["elogind-inhibit", "--what=sleep:idle:handle-lid-switch", "--who=xidou", "--why=Caffeine mode (Home > Caffeine toggle)", "--mode=block", "sh", "-c", "while :; do sleep 3600; done"];
            inhibitProc.running = true;
            root.active = true;
        }
    }

    Process {
        id: inhibitProc
        stderr: StdioCollector {
            id: inhibitStderr
        }
        // Fires on our own SIGTERM release just as much as on a real crash
        // -- either way, `active` should stop claiming a lock that's gone.
        // exitCode is nonzero (and inhibitStderr has real content) when
        // elogind-inhibit itself refused to start -- e.g. polkit requiring
        // interactive auth because the calling process isn't recognized as
        // part of an active, seat-attached logind session. Surfacing that
        // here is the only way to tell "toggled off" apart from "silently
        // never actually held a lock".
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && inhibitStderr.text.length > 0)
                console.warn("[xidou] CaffeineService: elogind-inhibit exited " + exitCode + ": " + inhibitStderr.text.trim());
            root.active = false;
        }
    }

    // Covers the normal shell-exit path (X session ending tears down the
    // QML engine, firing this) so the lock doesn't outlive the shell.
    // Does NOT cover an unclean `kill -9` of quickshell itself -- accepted
    // as a known edge case, same as every other Process in this codebase.
    Component.onDestruction: {
        if (root.active)
            inhibitProc.signal(15);
    }
}
