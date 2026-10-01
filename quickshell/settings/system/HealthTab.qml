import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../../services"
import ".." as Settings

// System > Health (ROADMAP M16): which piece of the session is broken, if
// any. Most checks come from bin/xidou-health (run by its repo path, so
// nothing needs installing); the config and sound rows come from the shell
// itself. "Fix" appears only where D23 allows one: restarting the
// user-level daemons the session starts (pipewire family, picom,
// xidou-clipd). Nothing here touches a system service.
//
// Runs when the tab opens, after a fix, and on Refresh. Read-only
// otherwise, so there is nothing to reset.
Item {
    id: root

    property bool showOverriddenOnly: false

    // Qt.resolvedUrl() can't reach outside the shell directory (Quickshell
    // turns that into qrc:/qs-blackhole), so build the path from shellDir.
    readonly property string scriptPath: Quickshell.shellDir.replace(/\/$/, "") + "/../bin/xidou-health"

    property var scriptRows: []
    property bool running: checkProc.running || fixProc.running
    property string fixing: ""

    readonly property var shellRows: [
        Config.parseError
            ? { id: "config", label: "Config file", status: "fail", detail: "doesn't parse, using defaults: " + Config.parseError, fix: false }
            : Config.fileMissing
                ? { id: "config", label: "Config file", status: "info", detail: "no " + Config.configPath + ", using defaults", fix: false }
                : { id: "config", label: "Config file", status: "ok", detail: Config.configPath, fix: false },
        root.soundRow()
    ]

    // Bumped by refresh(): statusSummary() is a function call, not a
    // binding, so the sound row re-reads it when this changes.
    property int tick: 0

    function soundRow() {
        root.tick;
        var summary = SoundFx.statusSummary();
        var m = summary.match(/^(\d+)\/(\d+)/);
        var ok = m && m[1] === m[2] && m[2] !== "0";
        return { id: "sound", label: "Sound effects", status: ok ? "ok" : "warn", detail: summary, fix: false };
    }

    readonly property var rows: root.scriptRows.concat(root.shellRows)

    function refresh() {
        root.tick++;
        checkProc.running = false;
        checkProc.running = true;
    }

    function fix(id) {
        root.fixing = id;
        fixProc.command = ["sh", root.scriptPath, "fix", id];
        fixProc.running = false;
        fixProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: checkProc
        command: ["sh", root.scriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i].trim())
                        continue;
                    try {
                        out.push(JSON.parse(lines[i]));
                    } catch (e) {
                        console.warn("[xidou] Health: bad line from xidou-health: " + lines[i]);
                    }
                }
                root.scriptRows = out;
            }
        }
    }

    Process {
        id: fixProc
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                console.warn("[xidou] Health: fix " + root.fixing + " exited " + exitCode);
            root.fixing = "";
            // Give a restarted daemon a moment to come up before checking.
            recheckTimer.restart();
        }
    }

    Timer {
        id: recheckTimer
        interval: 800
        onTriggered: root.refresh()
    }

    function statusColor(status) {
        if (status === "ok")
            return Theme.accent;
        if (status === "fail" || status === "warn")
            return Theme.warning;
        return Theme.textMuted;
    }

    function statusText(status) {
        return status === "ok" ? "OK" : status === "warn" ? "Check" : status === "fail" ? "Failed" : "Info";
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 3

        Row {
            width: parent.width
            spacing: Theme.fontSize / 2

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - refreshButton.width - parent.spacing
                text: root.running ? "Checking…" : "Every piece the session depends on"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.85
            }

            Rectangle {
                id: refreshButton
                width: refreshLabel.implicitWidth + Theme.fontSize * 1.5
                height: Theme.fontSize * 1.8
                radius: Theme.radius / 2
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border
                opacity: root.running ? 0.5 : 1

                Text {
                    id: refreshLabel
                    anchors.centerIn: parent
                    text: "Refresh"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.85
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.running
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refresh()
                }
            }
        }

        Flickable {
            width: parent.width
            height: parent.height - y
            contentHeight: list.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list
                width: parent.width
                spacing: Theme.fontSize / 4

                Repeater {
                    model: root.rows

                    delegate: Item {
                        id: rowItem
                        required property var modelData
                        width: list.width
                        height: Theme.fontSize * 2.4

                        Row {
                            anchors.fill: parent
                            spacing: Theme.fontSize / 2

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.fontSize * 4.2
                                height: Theme.fontSize * 1.5
                                radius: height / 2
                                color: root.statusColor(rowItem.modelData.status)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.statusText(rowItem.modelData.status)
                                    color: Theme.background
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize * 0.75
                                    font.bold: true
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.fontSize * 9
                                text: rowItem.modelData.label
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.9
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - (fixButton.visible ? fixButton.width + parent.spacing : 0)
                                text: rowItem.modelData.detail
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.8
                                elide: Text.ElideMiddle
                            }

                            Rectangle {
                                id: fixButton
                                visible: rowItem.modelData.fix
                                anchors.verticalCenter: parent.verticalCenter
                                width: fixLabel.implicitWidth + Theme.fontSize * 1.4
                                height: Theme.fontSize * 1.6
                                radius: Theme.radius / 2
                                color: Theme.accent
                                opacity: root.running ? 0.5 : 1

                                Text {
                                    id: fixLabel
                                    anchors.centerIn: parent
                                    text: root.fixing === rowItem.modelData.id ? "Fixing…" : "Fix"
                                    color: Theme.background
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize * 0.8
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.running
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.fix(rowItem.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
