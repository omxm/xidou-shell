import QtQuick
import Quickshell.Io
import "../../config"

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

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.warning ? Theme.warning : Theme.textMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize * Config.data.bar.layout.font_scale
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.usedPercent + "%"
            color: root.warning ? Theme.warning : Theme.textMuted
            font.family: (Config.data.bar.widgets.font_family || Theme.fontFamily)
            font.weight: Config.data.bar.widgets.font_weight === "bold" ? Font.Bold : (Config.data.bar.widgets.font_weight === "medium" ? Font.Medium : Font.Normal)
            font.pixelSize: Theme.fontSize * Config.data.bar.layout.font_scale
        }
    }
}
