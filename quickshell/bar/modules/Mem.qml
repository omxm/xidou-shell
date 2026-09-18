import QtQuick
import Quickshell.Io
import "../../config"

// Memory usage, read straight from /proc/meminfo and polled — no daemon or
// service needed for a number this simple.
Item {
    id: root

    property int usedPercent: 0

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
            text: root.icon
            color: Theme.textMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
        }

        Text {
            text: root.usedPercent + "%"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
