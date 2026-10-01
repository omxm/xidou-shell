import QtQuick
import "../../config"
import "../widgets"

// Left-most bar module: a simple wordmark placeholder. Real logo/startup
// splash asset work happens in the final phase (see CLAUDE.md roadmap);
// this just proves modules_left wiring and gives the bar a fixed anchor.
Item {
    implicitWidth: label.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    BarLabel {
        id: label
        anchors.centerIn: parent
        text: "軌"
        font.bold: true
        anchors.verticalCenter: undefined
        extraPixels: 2
        stateColor: Theme.accent
    }
}
