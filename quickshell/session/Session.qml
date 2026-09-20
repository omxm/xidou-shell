import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../services"

// Session/power menu: toggled by `xidou msg panel-toggle session` (dwm's
// super+escape bind, dwm/config.h) via PanelManager.isOpen("session").
// super+l bypasses this entirely and locks directly (dwm's sessionlockcmd),
// same SessionActions.lock() this menu's own "1" calls.
//
// Number-key convention (already decided, not this file's call to change):
// 1=lock, 2=log out, 3=reserved/TBD, 4=restart, 5=shut down.
PanelWindow {
    id: root

    readonly property var cfg: Config.data.panels.session
    readonly property int panelWidth: 360
    readonly property int panelHeight: 320
    readonly property int barReservedHeight: (Config.data.bar.position !== "bottom") ? Config.data.bar.height : 0

    readonly property var items: [
        { key: "1", label: "Lock", icon: "", action: function () { SessionActions.lock(); } },
        { key: "2", label: "Log Out", icon: "", action: function () { SessionActions.logout(); } },
        { key: "3", label: "", icon: "", action: null },
        { key: "4", label: "Restart", icon: "", action: function () { SessionActions.reboot(); } },
        { key: "5", label: "Shut Down", icon: "", action: function () { SessionActions.shutdown(); } }
    ]

    visible: PanelManager.isOpen("session") && root.cfg.enabled
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

            Keys.onEscapePressed: PanelManager.close("session")
            Keys.onPressed: function (event) {
                for (var i = 0; i < root.items.length; i++) {
                    if (root.items[i].key === event.text && root.items[i].action) {
                        root.items[i].action();
                        event.accepted = true;
                        return;
                    }
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.fontSize
                spacing: Theme.fontSize / 3

                Repeater {
                    model: root.items
                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool implemented: modelData.action !== null

                        width: parent.width
                        height: Theme.fontSize * 2.6
                        radius: Theme.radius / 2
                        color: Theme.surfaceAlt
                        opacity: implemented ? 1 : 0.5

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.fontSize / 2
                            spacing: Theme.fontSize / 2

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                visible: text.length > 0
                                color: Theme.text
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fontSize * 1.2
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label.length > 0 ? modelData.label : "Reserved"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: Theme.fontSize / 2
                            text: modelData.key
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.85
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: parent.implemented ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData.action)
                                    modelData.action();
                                else
                                    console.warn("[xidou] session menu: item '" + modelData.key + "' is not implemented yet");
                            }
                        }
                    }
                }
            }
        }
    }
}
