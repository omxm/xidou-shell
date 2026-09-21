import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../services"

// Preview shown after a region capture when Screenshot.confirmSelection is
// on -- Save writes the candidate to disk + clipboard (Screenshot.finalize),
// Cancel discards the temp file. Same centered-overlay window pattern as
// Session.qml (focus-helper Process/Timer, PanelWindow anchored top-left
// with computed margins).
PanelWindow {
    id: root

    readonly property int panelWidth: 480
    readonly property int panelHeight: 400
    readonly property int barReservedHeight: (Config.data.bar.position !== "bottom") ? Config.data.bar.height : 0

    visible: Screenshot.confirmVisible
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

    focusable: true

    Process {
        id: focusHelper
        command: ["xidou-focus-window", String(root.panelWidth), String(root.panelHeight)]
    }

    Timer {
        id: focusHelperTimer
        interval: 50
        onTriggered: {
            focusHelper.running = false;
            focusHelper.running = true;
        }
    }

    anchors.top: true
    anchors.left: true
    margins.top: Math.round((screen.height - barReservedHeight - panelHeight) / 2)
    margins.left: Math.round((screen.width - panelWidth) / 2)

    onVisibleChanged: {
        if (visible) {
            keyHandler.forceActiveFocus();
            focusHelperTimer.start();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: Screenshot.confirmCancel()
            Keys.onReturnPressed: Screenshot.confirmSave()
            Keys.onEnterPressed: Screenshot.confirmSave()

            Column {
                anchors.fill: parent
                anchors.margins: Theme.fontSize
                spacing: Theme.fontSize / 2

                Rectangle {
                    width: parent.width
                    height: parent.height - actionsRow.height - parent.spacing
                    radius: Theme.radius / 2
                    color: Theme.surfaceAlt
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 4
                        source: Screenshot.candidateImagePath ? "file://" + Screenshot.candidateImagePath : ""
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        asynchronous: true
                    }
                }

                Row {
                    id: actionsRow
                    width: parent.width
                    height: Theme.fontSize * 2.4
                    spacing: Theme.fontSize / 2

                    Rectangle {
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        radius: Theme.radius / 2
                        color: Theme.surfaceAlt

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.fontSize / 3
                            Text {
                                text: "" // close (verified via fontTools)
                                color: Theme.textMuted
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fontSize * 1.1
                            }
                            Text {
                                text: "Cancel"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Screenshot.confirmCancel()
                        }
                    }

                    Rectangle {
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        radius: Theme.radius / 2
                        color: Theme.accent

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.fontSize / 3
                            Text {
                                text: "" // check (verified via fontTools)
                                color: Theme.background
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fontSize * 1.1
                            }
                            Text {
                                text: "Save"
                                color: Theme.background
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Screenshot.confirmSave()
                        }
                    }
                }
            }
        }
    }
}
