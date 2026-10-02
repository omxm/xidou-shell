import QtQuick
import "../config"
import "../services"

// A "‹ action ›" picker over the action registry (services/Actions.qml),
// for bar widget clicks (ROADMAP M8). Same look as NumberStepper. The
// arrows (or the wheel over the label) step through "None" plus every
// registered action, wrapping around. An id that isn't registered (a typo
// in config.toml) shows as the raw id until another one is picked.
Row {
    id: root

    property string currentValue: ""

    signal actionSelected(string value)

    readonly property var options: [""].concat(Actions.actions.map(function (action) {
        return action.id;
    }))
    readonly property int currentIndex: root.options.indexOf(root.currentValue)

    function step(delta) {
        var count = root.options.length;
        var from = root.currentIndex < 0 ? 0 : root.currentIndex;
        SoundFx.play("stepper");
        root.actionSelected(root.options[(from + delta + count) % count]);
    }

    height: Theme.fontSize * 1.8
    spacing: Theme.fontSize / 3

    Rectangle {
        width: height
        height: parent.height
        radius: Theme.radius / 2
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.centerIn: parent
            text: "‹"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.step(-1)
        }
    }

    Rectangle {
        width: root.width - 2 * (root.height + root.spacing)
        height: parent.height
        radius: Theme.radius / 2
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.centerIn: parent
            width: parent.width - Theme.fontSize / 2
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.currentValue === "" ? "None" : (Actions.labelOf(root.currentValue) || root.currentValue)
            color: root.currentValue === "" ? Theme.textMuted : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.85
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real accum: 0
            onWheel: (event) => {
                accum += event.angleDelta.y;
                while (Math.abs(accum) >= 120) {
                    var delta = accum > 0 ? -1 : 1;
                    accum += delta * 120;
                    root.step(delta);
                }
            }
        }
    }

    Rectangle {
        width: height
        height: parent.height
        radius: Theme.radius / 2
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.centerIn: parent
            text: "›"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.step(1)
        }
    }
}
