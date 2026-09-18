import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "config"
import "services"
import "bar"
import "launcher"

// Shell entry point. Run with:
//   quickshell -p /path/to/xidou-shell/quickshell
//
// Phase 0 (config + theme) loads first; Phase 1 (the bar) instantiates one
// Bar per screen, mapping screen order to dwm monitor number — fine for the
// X230's single 1366x768 panel, and a reasonable default for multi-monitor
// until dwm-ipc's per-monitor identity is threaded through explicitly.
ShellRoot {
    settings.watchFiles: true

    Component.onCompleted: logTheme()

    Connections {
        target: Config
        function onReloaded() {
            logTheme();
        }
    }

    function logTheme() {
        console.log("[xidou] shell " + Config.data.shell.name + " v" + Config.data.shell.version);
        console.log("[xidou] theme mode=" + Theme.mode
            + " accent=" + Theme.accent
            + " background=" + Theme.background
            + " font=" + Theme.fontFamily + "@" + Theme.fontSize
            + " radius=" + Theme.radius);
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            monitorNum: Quickshell.screens.indexOf(modelData)
        }
    }

    Launcher {}

    // Shell-side IPC target for dwm's spawned commands (see bin/xidou and
    // dwm/config.h's super+d bind) — this is shell UI state (panel
    // visibility), not window-manager state, so it goes through Quickshell's
    // own IPC rather than dwm-ipc.
    IpcHandler {
        target: "panels"

        function toggle(name: string): void {
            PanelState.toggle(name);
        }
    }

    // ctrl+<arrow> media keys (dwm/config.h) go here rather than a
    // playerctl-style external CLI — the bar's Media module already holds
    // a live MprisPlayer, this just drives the same one.
    IpcHandler {
        target: "mpris"

        function next(): void {
            var p = Mpris.players.length > 0 ? Mpris.players[0] : null;
            if (p && p.canGoNext)
                p.next();
        }

        function previous(): void {
            var p = Mpris.players.length > 0 ? Mpris.players[0] : null;
            if (p && p.canGoPrevious)
                p.previous();
        }

        function playPause(): void {
            var p = Mpris.players.length > 0 ? Mpris.players[0] : null;
            if (p && p.canTogglePlaying)
                p.togglePlaying();
        }
    }
}
