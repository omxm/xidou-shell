import QtQuick
import Quickshell.Io
import "../../config"
import "../widgets"
import "../../services"

// Memory usage, read straight from /proc/meminfo and polled — no daemon or
// service needed for a number this simple.
Item {
    id: root

    readonly property var cfg: Config.data.bar_widgets.mem
    property int usedPercent: 0
    readonly property bool warning: root.usedPercent >= root.cfg.warning_threshold

    // Material Symbols Outlined codepoint for "memory", from Google's
    // upstream codepoints file (google/material-design-icons).
    readonly property string icon: ""

    implicitWidth: row.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: root.parse(text())
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: meminfo.reload()
    }

    function parse(text) {
        var total = 0, avail = 0;
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.indexOf("MemTotal:") === 0)
                total = parseInt(line.replace(/\D/g, ""), 10);
            else if (line.indexOf("MemAvailable:") === 0)
                avail = parseInt(line.replace(/\D/g, ""), 10);
        }
        if (total > 0)
            root.usedPercent = Math.round((total - avail) / total * 100);
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.fontSize / 4

        BarIcon {
            text: root.icon
            stateColor: root.warning ? Theme.warning : Theme.textMuted
        }

        BarLabel {
            text: root.usedPercent + "%"
            stateColor: root.warning ? Theme.warning : Theme.textMuted
        }
    }

    // Click slot for Bar.qml's widget wrapper (ROADMAP F5): left opens
    // control-center at System (M8, D6). Right click isn't declared, so it
    // falls through to the bar's dead zone.
    function leftClicked() {
        PanelManager.open("control-center", "System");
    }
}
