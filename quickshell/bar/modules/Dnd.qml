import QtQuick
import "../../config"
import "../widgets"
import "../../services"

// Do-not-disturb indicator (Phase 4) -- reflects Notifications.dnd, toggled
// by dwm's super+n keybind (xidou msg notifications toggleDnd) or by
// a bar click (right click by default, [bar_widgets.dnd]).
Item {
    id: root

    // Material Symbols Outlined codepoints for "notifications" /
    // "notifications_off", from Google's upstream codepoints file.
    readonly property string icon: Notifications.dnd ? "" : ""

    implicitWidth: row.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.fontSize / 4

        BarIcon {
            text: root.icon
            stateColor: Notifications.dnd ? Theme.accent : Theme.textMuted
        }
    }
}
