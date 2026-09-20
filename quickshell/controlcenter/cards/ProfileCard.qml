import QtQuick
import Quickshell.Io
import "../../config"
import ".." as ControlCenter

// Avatar (a generic person glyph — no real avatar image plumbed in yet),
// hostname, uptime, and shell version.
ControlCenter.Card {
    id: root

    property string hostname: ""
    property string uptime: ""

    // No `hostname` binary exists on this system (confirmed: `which hostname`
    // fails) — /etc/hostname is set on every Linux system regardless, and
    // reading it directly needs no external process at all.
    FileView {
        path: "/etc/hostname"
        onLoaded: root.hostname = text().trim()
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            // uptime -p prints "up 3 hours, 12 minutes" — the "up " prefix
            // is redundant next to this card's own "Uptime" label.
            onStreamFinished: root.uptime = text.trim().replace(/^up /, "")
        }
    }

    Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: true
        onTriggered: {
            uptimeProc.running = false;
            uptimeProc.running = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.fontSize
        spacing: Theme.fontSize / 2

        Rectangle {
            width: Theme.fontSize * 3
            height: Theme.fontSize * 3
            radius: width / 2
            color: Theme.surfaceAlt
            border.width: 1
            border.color: Theme.border

            Text {
                anchors.centerIn: parent
                text: "" // Material Symbols Outlined "person"
                color: Theme.textMuted
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSize * 1.8
            }
        }

        Text {
            text: root.hostname || "—"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 1.1
            font.bold: true
        }

        Text {
            text: Config.data.shell.name + " v" + Config.data.shell.version
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.85
        }

        Text {
            text: root.uptime ? ("Uptime: " + root.uptime) : ""
            visible: text.length > 0
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.85
        }
    }
}
