import QtQuick
import "../../config"
import "../widgets"
import "../../services"

// A one-icon bar button (ROADMAP L8): launcher, settings, session,
// screenshot, wallpaper, control-center, caffeine, night light, theme mode
// and notifications all use this, each named after the action registry id
// it stands for (`actionId`). The icon and on/off state come from that
// action; what a click does comes from [bar_widgets.<widgetName>]'s
// left_click/right_click/middle_click (M8), whose defaults run the same
// action. show_label adds `label` next to the icon; `badge` > 0 draws a
// count on the icon (notifications' unread count).
Item {
    id: root

    property string widgetName: ""
    property string actionId: ""
    property string label: ""
    property string iconOverride: ""
    property int badge: 0

    readonly property var cfg: Config.data.bar_widgets[root.widgetName] || ({})
    readonly property bool active: Actions.activeOf(root.actionId)

    // Tooltip slot for Bar.qml's widget wrapper (ROADMAP F5).
    readonly property string tooltip: root.cfg.show_label ? "" : root.label

    implicitWidth: row.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.fontSize / 4

        BarIcon {
            id: icon
            text: root.iconOverride || Actions.iconOf(root.actionId)
            stateColor: root.active ? Theme.accent : undefined

            Rectangle {
                visible: root.badge > 0
                anchors.horizontalCenter: parent.right
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: parent.height * 0.2
                width: Math.max(height, badgeText.implicitWidth + Theme.fontSize * 0.4)
                height: Theme.fontSize * 0.85
                radius: height / 2
                color: Theme.accent

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.badge > 9 ? "9+" : String(root.badge)
                    color: Theme.background
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.6
                    font.bold: true
                }
            }
        }

        BarLabel {
            visible: !!root.cfg.show_label
            text: root.label
        }
    }
}
