import QtQuick
import "../../config"

// Empty space between bar widgets (ROADMAP L8), [bar_widgets.spacer] width
// in px. `bare` tells Bar.qml's wrapper to draw no capsule or hover
// highlight around it.
Item {
    readonly property bool bare: true

    implicitWidth: Math.max(0, Config.data.bar_widgets.spacer.width)
    implicitHeight: parent ? parent.height : Theme.fontSize * 2
}
