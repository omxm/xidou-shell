import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../config"

// StatusNotifierItem tray icons, via Quickshell's built-in SystemTray
// service (owns the org.kde.StatusNotifierWatcher registration itself —
// no separate tray daemon needed).
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.fontSize / 2

        Repeater {
            model: SystemTray.items

            IconImage {
                id: trayIcon
                required property var modelData

                implicitSize: Theme.fontSize + 4
                source: modelData.icon

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton)
                            trayIcon.modelData.activate();
                        else if (mouse.button === Qt.RightButton)
                            trayIcon.modelData.secondaryActivate();
                    }
                }
            }
        }
    }
}
