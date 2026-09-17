import QtQuick
import "../../config"
import "../../services"

// Tag/workspace switcher, driven by real dwm state over DwmIpc (dwm-ipc via
// dwm-msg) rather than mock data. Tags are switched by explicit bit mask
// (dwm's `view` ipc command), never by a next/prev abstraction — see the
// dwm tag-cycling lesson in CLAUDE.md.
Item {
    id: root

    property int monitorNum: 0

    readonly property var tagState: DwmIpc.tagStateFor(monitorNum)
    readonly property int selectedMask: tagState ? tagState.selected : 0
    readonly property int occupiedMask: tagState ? tagState.occupied : 0
    readonly property int urgentMask: tagState ? tagState.urgent : 0

    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: DwmIpc.tags

            Rectangle {
                required property var modelData

                readonly property bool isSelected: (root.selectedMask & modelData.bitMask) !== 0
                readonly property bool isOccupied: (root.occupiedMask & modelData.bitMask) !== 0
                readonly property bool isUrgent: (root.urgentMask & modelData.bitMask) !== 0

                width: label.implicitWidth + Theme.fontSize
                height: root.height > 0 ? root.height : Theme.fontSize * 1.8
                radius: Theme.radius / 2
                color: isSelected ? Theme.accent : (isUrgent ? Theme.accent : "transparent")
                border.width: isOccupied && !isSelected ? 1 : 0
                border.color: Theme.border

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.name
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: isSelected ? Theme.background : (isUrgent ? Theme.background : Theme.textMuted)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DwmIpc.viewTag(modelData.bitMask)
                }
            }
        }
    }
}
