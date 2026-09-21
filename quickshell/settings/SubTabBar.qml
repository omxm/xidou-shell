import QtQuick
import "../config"

// Horizontal sub-tab strip within a settings category (e.g. Appearance's
// Theme / Interface / Accessibility / Motion / Borders / Effects) -- same
// click-selects-index shape and active/inactive coloring as
// controlcenter/Sidebar.qml, just laid out as a Row instead of a Column
// since these sit across the top of the content pane rather than down the
// side.
Row {
    id: root

    property var tabs: []
    property int selectedIndex: 0

    signal tabClicked(int index)

    spacing: Theme.fontSize / 4

    Repeater {
        model: root.tabs
        delegate: Rectangle {
            id: delegateRoot
            required property var modelData
            required property int index

            width: label.implicitWidth + Theme.fontSize
            height: Theme.fontSize * 2.2
            radius: Theme.radius / 2
            color: index === root.selectedIndex ? Theme.accent : "transparent"

            Text {
                id: label
                anchors.centerIn: parent
                text: delegateRoot.modelData
                color: index === root.selectedIndex ? Theme.background : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.9
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.tabClicked(delegateRoot.index)
            }
        }
    }
}
