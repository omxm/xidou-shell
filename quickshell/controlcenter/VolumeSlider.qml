import QtQuick
import "../config"

// A plain drag-to-set slider built from Rectangle + MouseArea, matching this
// codebase's existing convention (no QtQuick.Controls anywhere else in the
// repo, and Controls' own native styles would fight Theme.qml's "zero
// hardcoded styling" rule rather than just reading its tokens).
Item {
    id: root

    property real value: 0 // 0.0 - 1.0
    signal moved(real newValue)

    implicitHeight: Theme.fontSize / 2

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.fontSize / 3
        radius: height / 2
        color: Theme.surfaceAlt

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.value))
            height: track.height
            radius: height / 2
            color: Theme.accent
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Theme.fontSize / 4 // easier to grab than the thin track itself
        cursorShape: Qt.PointingHandCursor

        function updateFromX(x) {
            root.moved(Math.max(0, Math.min(1, x / root.width)));
        }

        onPressed: (mouse) => updateFromX(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x); }
    }
}
