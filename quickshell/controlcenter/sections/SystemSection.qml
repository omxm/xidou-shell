import QtQuick
import Quickshell.Io
import "../../config"
import ".." as ControlCenter

// CPU/memory/disk usage, on the same /proc-reading approach bar/modules/
// Cpu.qml and Mem.qml already use (no daemon needed for numbers this
// simple) plus `df` for disk, which /proc doesn't expose directly.
Item {
    id: root

    property int cpuPercent: 0
    property real lastTotal: -1
    property real lastIdle: 0
    property string cpuModel: ""

    property int memPercent: 0
    property real memUsedGb: 0
    property real memTotalGb: 0

    property int diskPercent: 0
    property string diskUsed: ""
    property string diskTotal: ""

    property string kernel: ""

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root.parseCpu(text())
    }

    FileView {
        id: cpuinfoFile
        path: "/proc/cpuinfo"
        onLoaded: {
            var m = text().match(/model name\s*:\s*(.+)/);
            if (m) root.cpuModel = m[1].trim();
        }
    }

    FileView {
        id: meminfoFile
        path: "/proc/meminfo"
        onLoaded: root.parseMem(text())
    }

    Process {
        id: dfProc
        command: ["df", "-h", "--output=used,size,pcent", "/"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDisk(text)
        }
    }

    Process {
        id: unameProc
        command: ["uname", "-sr"]
        stdout: StdioCollector {
            onStreamFinished: root.kernel = text.trim()
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statFile.reload()
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: meminfoFile.reload()
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { dfProc.running = false; dfProc.running = true; }
    }

    Component.onCompleted: unameProc.running = true

    function parseCpu(text) {
        var line = text.split("\n")[0];
        var fields = line.trim().split(/\s+/).slice(1).map(Number);
        var idle = fields[3] + (fields[4] || 0);
        var total = fields.reduce(function (a, b) { return a + b; }, 0);
        if (root.lastTotal >= 0) {
            var totalDelta = total - root.lastTotal;
            var idleDelta = idle - root.lastIdle;
            if (totalDelta > 0)
                root.cpuPercent = Math.round((1 - idleDelta / totalDelta) * 100);
        }
        root.lastTotal = total;
        root.lastIdle = idle;
    }

    function parseMem(text) {
        var total = 0, avail = 0;
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.indexOf("MemTotal:") === 0)
                total = parseInt(line.replace(/\D/g, ""), 10);
            else if (line.indexOf("MemAvailable:") === 0)
                avail = parseInt(line.replace(/\D/g, ""), 10);
        }
        if (total > 0) {
            root.memPercent = Math.round((total - avail) / total * 100);
            root.memTotalGb = Math.round(total / 1024 / 1024 * 10) / 10;
            root.memUsedGb = Math.round((total - avail) / 1024 / 1024 * 10) / 10;
        }
    }

    function parseDisk(text) {
        var lines = text.trim().split("\n");
        if (lines.length < 2) return;
        var fields = lines[1].trim().split(/\s+/);
        root.diskUsed = fields[0];
        root.diskTotal = fields[1];
        root.diskPercent = parseInt(fields[2], 10) || 0;
    }

    ControlCenter.Card {
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize

            Text {
                text: root.cpuModel
                visible: text.length > 0
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            Text {
                text: root.kernel
                visible: text.length > 0
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.85
            }

            Repeater {
                model: [
                    { label: "CPU", percent: root.cpuPercent, detail: root.cpuPercent + "%" },
                    { label: "Memory", percent: root.memPercent, detail: root.memUsedGb + " / " + root.memTotalGb + " GB" },
                    { label: "Disk", percent: root.diskPercent, detail: root.diskUsed + " / " + root.diskTotal }
                ]
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: Theme.fontSize / 4

                    Item {
                        width: parent.width
                        height: Math.max(labelText.implicitHeight, detailText.implicitHeight)

                        Text {
                            id: labelText
                            anchors.left: parent.left
                            text: modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.9
                        }

                        Text {
                            id: detailText
                            anchors.right: parent.right
                            text: modelData.detail
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.85
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Theme.fontSize / 3
                        radius: height / 2
                        color: Theme.surfaceAlt

                        Rectangle {
                            width: parent.width * Math.min(1, modelData.percent / 100)
                            height: parent.height
                            radius: height / 2
                            color: Theme.accent
                        }
                    }
                }
            }
        }
    }
}
