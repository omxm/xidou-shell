import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../config"

// StatusNotifierItem tray icons, via Quickshell's built-in SystemTray
// service (owns the org.kde.StatusNotifierWatcher registration itself —
// no separate tray daemon needed).
Item {
    id: root

    readonly property var cfg: Config.data.bar_widgets.tray
    readonly property int iconSize: root.cfg.icon_size > 0 ? root.cfg.icon_size : (Theme.fontSize + 4)

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

                implicitSize: root.iconSize
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
