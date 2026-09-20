import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "config"
import "services"
import "bar"
import "launcher"
import "controlcenter"
import "osd"
import "notification"

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

    ControlCenter {}

    Osd {}

    NotificationPopups {}

    // Shell-side IPC target for dwm's spawned commands (see bin/xidou and
    // dwm/config.h's super+d bind) — this is shell UI state (panel
    // visibility), not window-manager state, so it goes through Quickshell's
    // own IPC rather than dwm-ipc.
    IpcHandler {
        target: "panels"

        function toggle(name: string): void {
            PanelManager.toggle(name);
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

    // Nudged by bin/xidou-brightness (dwm/config.h's MonBrightness keybinds)
    // after it writes the new sysfs value — brightness has no live signal
    // to watch passively the way Osd.qml watches Pipewire for volume, so it
    // has to be told explicitly. See services/Brightness.qml.
    IpcHandler {
        target: "osd"

        function brightness(): void {
            Brightness.refreshAndShow();
        }
    }

    // dwm's super+n keybind (dwm/config.h's notificationdndcmd) lands here.
    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            Notifications.toggleDnd();
        }
    }

    // Manual "regenerate theme" trigger (`xidou msg theme regenerate <path>`)
    // ahead of the wallpaper-picker UI that will eventually call the same
    // thing on wallpaper selection (Phase 6). Maps config.toml's theme.mode
    // ("auto") onto matugen's own mode name ("smart") -- they're not spelled
    // the same even though they mean the same thing.
    IpcHandler {
        target: "theme"

        function regenerate(imagePath: string): void {
            var mode = Config.data.theme.mode === "auto" ? "smart" : Config.data.theme.mode;
            ColorScheme.regenerate(imagePath, mode, "scheme-tonal-spot");
        }
    }
}
