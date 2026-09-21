import QtQuick
import "../config"
import "../controlcenter" as ControlCenter

// Generic "not built yet" stub for a sub-tab under a settings category --
// same incremental-rollout convention as control-center's own
// PlaceholderSection.qml (reused directly rather than duplicating the
// near-identical card+icon+label composition here).
ControlCenter.Card {
    id: root

    property string tabName: ""

    Column {
        anchors.centerIn: parent
        spacing: Theme.fontSize / 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "" // construction
            color: Theme.textMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize * 2
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.tabName + " isn't built yet"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
