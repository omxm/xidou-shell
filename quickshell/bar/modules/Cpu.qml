import QtQuick
import Quickshell.Io
import "../../config"
import "../widgets"
import "../../services"

// CPU usage from /proc/stat's aggregate "cpu" line, as a percentage over the
// interval since the last poll (a single snapshot of /proc/stat's counters
// is cumulative since boot, not a point-in-time load — needs a delta).
Item {
    id: root

    readonly property var cfg: Config.data.bar_widgets.cpu
    property int usagePercent: 0
    readonly property bool warning: root.usagePercent >= root.cfg.warning_threshold
    property real lastTotal: -1
    property real lastIdle: 0

    // Material Symbols Outlined codepoint for "developer_board", from
    // Google's upstream codepoints file.
    readonly property string icon: ""

    implicitWidth: row.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root.parse(text())
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statFile.reload()
    }

    function parse(text) {
        var line = text.split("\n")[0]; // "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
        var fields = line.trim().split(/\s+/).slice(1).map(Number);
        var idle = fields[3] + (fields[4] || 0);
        var total = fields.reduce(function (a, b) { return a + b; }, 0);

        if (root.lastTotal >= 0) {
            var totalDelta = total - root.lastTotal;
            var idleDelta = idle - root.lastIdle;
            if (totalDelta > 0)
                root.usagePercent = Math.round((1 - idleDelta / totalDelta) * 100);
        }
        root.lastTotal = total;
        root.lastIdle = idle;
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
            text: root.usagePercent + "%"
            stateColor: root.warning ? Theme.warning : Theme.textMuted
        }
    }

    // Click slot for Bar.qml's widget wrapper (ROADMAP F5): left opens
    // control-center at System (M8, D6). Right click isn't declared, so it
    // falls through to the bar's dead zone.
    function leftClicked() {
        Actions.run("control_center.system");
    }
}
