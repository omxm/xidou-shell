import QtQuick
import "../../config"

// Left-most bar module: a simple wordmark placeholder. Real logo/startup
// splash asset work happens in the final phase (see CLAUDE.md roadmap);
// this just proves modules_left wiring and gives the bar a fixed anchor.
Item {
    implicitWidth: label.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Text {
        id: label
        anchors.centerIn: parent
        text: "軌"
        color: Theme.accent
        font.family: (Config.data.bar.widgets.font_family || Theme.fontFamily)
        font.weight: Config.data.bar.widgets.font_weight === "bold" ? Font.Bold : (Config.data.bar.widgets.font_weight === "medium" ? Font.Medium : Font.Normal)
        font.pixelSize: (Theme.fontSize + 2) * Config.data.bar.layout.font_scale
        font.bold: true
    }
}
