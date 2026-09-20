import QtQuick
import "../config"

// One quick-toggle grid button (icon + label, Theme.accent when active) —
// follows the same glyph-color-reflects-state convention as the bar's
// Dnd.qml/Bluetooth.qml/Volume.qml, factored into a component since the
// Home toggle grid needs six of these.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    // Placeholder tiles have no real backing service yet (see plan) —
    // still visually correct, but clicking just warns instead of no-oping
    // silently, so it's obvious in the log rather than looking broken.
    property bool implemented: true

    signal triggered()

    radius: Theme.radius / 2
    color: active ? Theme.accent : Theme.surfaceAlt
    border.width: 1
    border.color: Theme.border

    Column {
        anchors.centerIn: parent
        spacing: Theme.fontSize / 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            color: root.active ? Theme.background : Theme.text
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize * 1.4
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.active ? Theme.background : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.8
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.implemented) {
                console.warn("[xidou] control-center: '" + root.label + "' toggle is not implemented yet");
                return;
            }
            root.triggered();
        }
    }
}
