import QtQuick
import Quickshell
import "config"
import "bar"

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
            required property int index

            screen: modelData
            monitorNum: index
        }
    }
}
