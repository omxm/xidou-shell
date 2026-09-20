import QtQuick
import "../config"

// Left tab list — click selects a section directly; Tab-key cycling (see
// ControlCenter.qml) also drives the same selectedIndex property.
Column {
    id: root

    property var sections: []
    property int selectedIndex: 0

    signal sectionClicked(int index)

    spacing: Theme.fontSize / 4

    Repeater {
        model: root.sections
        delegate: Rectangle {
            id: delegateRoot
            required property var modelData
            required property int index

            width: parent.width
            height: Theme.fontSize * 2.2
            radius: Theme.radius / 2
            color: index === root.selectedIndex ? Theme.accent : "transparent"

            Text {
                anchors.fill: parent
                anchors.leftMargin: Theme.fontSize / 2
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: delegateRoot.modelData
                color: index === root.selectedIndex ? Theme.background : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.9
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sectionClicked(delegateRoot.index)
            }
        }
    }
}
