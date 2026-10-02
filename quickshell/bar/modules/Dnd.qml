import QtQuick
import "../../config"
import "../widgets"
import "../../services"

// Do-not-disturb indicator (Phase 4) -- reflects Notifications.dnd, toggled
// by dwm's super+n keybind (xidou msg notifications toggleDnd) or by
// right-clicking here directly.
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

    // Click slots for Bar.qml's widget wrapper (ROADMAP F5). Left opens
    // control-center at Notifications, right toggles DND (M8, D6).
    function leftClicked() {
        PanelManager.open("control-center", "Notifications");
    }

    function rightClicked() {
        Notifications.toggleDnd();
    }
}
