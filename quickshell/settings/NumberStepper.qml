import QtQuick
import "../config"

// A "− value +" numeric stepper, clamped to [minValue, maxValue] --
// factored out from Font Size and Corner Radius, the first two controls
// that needed it, once a second near-identical copy made the duplication
// obvious. Clamping happens here so callers just react to `stepped`.
Row {
    id: root

    property int value: 0
    property int minValue: 0
    property int maxValue: 100
    property string suffix: ""

    signal stepped(int newValue)

    height: Theme.fontSize * 1.8
    spacing: Theme.fontSize / 3

    Rectangle {
        width: height
        height: parent.height
        radius: Theme.radius / 2
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border
        opacity: root.value <= root.minValue ? 0.5 : 1

        Text {
            anchors.centerIn: parent
            text: "−"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.value > root.minValue
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stepped(Math.max(root.minValue, root.value - 1))
        }
    }

    Rectangle {
        width: Theme.fontSize * 3
        height: parent.height
        radius: Theme.radius / 2
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.centerIn: parent
            text: root.value + root.suffix
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.85
        }
    }

    Rectangle {
        width: height
        height: parent.height
        radius: Theme.radius / 2
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border
        opacity: root.value >= root.maxValue ? 0.5 : 1

        Text {
            anchors.centerIn: parent
            text: "+"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.value < root.maxValue
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stepped(Math.min(root.maxValue, root.value + 1))
        }
    }
}
