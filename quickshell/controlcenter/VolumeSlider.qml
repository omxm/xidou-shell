import QtQuick
import "../config"

// A plain drag-to-set slider built from Rectangle + MouseArea, matching this
// codebase's existing convention (no QtQuick.Controls anywhere else in the
// repo, and Controls' own native styles would fight Theme.qml's "zero
// hardcoded styling" rule rather than just reading its tokens).
//
// Shared by control-center (volume, seek) and Settings (sound volumes).
// moved() fires continuously while dragging; released() fires once with
// the final value, for callers that should act once per drag (writing
// config.toml, a seek sound). While dragging, the fill follows the
// pointer even if `value` isn't written back until release.
Item {
    id: root

    property real value: 0 // 0.0 - 1.0
    property real step: 0 // > 0 snaps to multiples of this
    signal moved(real newValue)
    signal released(real newValue)

    property real dragValue: 0
    readonly property real shownValue: dragArea.pressed ? root.dragValue : root.value

    implicitHeight: Theme.fontSize / 2
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.fontSize / 3
        radius: height / 2
        color: Theme.surfaceAlt

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.shownValue))
            height: track.height
            radius: height / 2
            color: Theme.accent
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.margins: -Theme.fontSize / 4 // easier to grab than the thin track itself
        cursorShape: Qt.PointingHandCursor

        function valueAt(x) {
            var v = Math.max(0, Math.min(1, x / root.width));
            if (root.step > 0)
                v = Math.round(v / root.step) * root.step;
            return v;
        }

        function updateFromX(x) {
            root.dragValue = valueAt(x);
            root.moved(root.dragValue);
        }

        onPressed: (mouse) => updateFromX(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x); }
        onReleased: (mouse) => root.released(valueAt(mouse.x))
    }
}
