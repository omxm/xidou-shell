import QtQuick
import "../../config"
import ".." as ControlCenter

// Generic "not built yet" stub, reused for every sidebar section besides
// Home and Audio — same incremental-rollout spirit as the bar's own
// resolveModules() gracefully skipping unimplemented modules.
ControlCenter.Card {
    id: root

    property string sectionName: ""

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
            text: root.sectionName + " isn't built yet"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
