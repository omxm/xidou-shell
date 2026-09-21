import QtQuick
import "../config"

// A row of equal-width pill buttons, one active (Theme.accent) at a time --
// the shape Theme Mode/Palette Source/Bar Position each built ad hoc first;
// factored out once a 4th and 5th copy (Screenshot's boolean toggles) made
// the duplication obvious rather than speculative. Caller sets `width`
// (typically `parent.width` from within a SettingRow's control slot).
Row {
    id: root

    property var options: [] // [{value, label}]
    property var currentValue: undefined

    signal optionSelected(var value)

    height: Theme.fontSize * 1.8
    spacing: Theme.fontSize / 3

    Repeater {
        model: root.options
        delegate: Rectangle {
            id: optionDelegate
            required property var modelData

            width: (root.width - (root.options.length - 1) * root.spacing) / root.options.length
            height: parent.height
            radius: Theme.radius / 2
            color: root.currentValue === optionDelegate.modelData.value ? Theme.accent : Theme.surfaceAlt
            border.width: 1
            border.color: Theme.border

            Text {
                anchors.centerIn: parent
                text: optionDelegate.modelData.label
                color: root.currentValue === optionDelegate.modelData.value ? Theme.background : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.85
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.optionSelected(optionDelegate.modelData.value)
            }
        }
    }
}
