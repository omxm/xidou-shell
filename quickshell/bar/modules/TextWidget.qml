import QtQuick
import "../../config"
import "../widgets"

// Fixed text on the bar (ROADMAP L8), [bar_widgets.text] text. Empty text
// collapses the widget like an empty Media or Tray. Clicks come from the
// same left_click/right_click/middle_click keys as every widget (M8).
Item {
    readonly property string text: Config.data.bar_widgets.text.text

    implicitWidth: text.length > 0 ? label.implicitWidth + Theme.fontSize : 0
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    BarLabel {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenter: undefined
        text: parent.text
    }
}
