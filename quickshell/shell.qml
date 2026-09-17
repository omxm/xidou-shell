import QtQuick
import Quickshell
import "config"

// Phase 0 entry point: loads Config + Theme and proves the pipeline works.
// No panels yet — those start in Phase 1. Run with:
//   quickshell -p /path/to/xidou-shell/quickshell
// and check the log output below to verify config.toml was read correctly.
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
}
