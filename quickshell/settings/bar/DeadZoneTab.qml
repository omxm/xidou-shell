import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Bar > Dead Zone (ROADMAP M10): what a click or scroll on empty bar space
// runs, one action registry id per [bar.dead_zone] key, picked with the same
// "‹ action ›" picker as a widget's clicks (M8). A widget's click or scroll
// with no action of its own lands here too (Bar.qml).
Item {
    id: root

    property bool showOverriddenOnly: false

    readonly property var slots: [
        { key: "left_click", label: "Left Click" },
        { key: "right_click", label: "Right Click" },
        { key: "middle_click", label: "Middle Click" },
        { key: "scroll_up", label: "Scroll Up" },
        { key: "scroll_down", label: "Scroll Down" }
    ]

    function resetAll() {
        for (var i = 0; i < slotRepeater.count; i++)
            slotRepeater.itemAt(i).reset();
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Repeater {
            id: slotRepeater
            model: root.slots

            delegate: Settings.SettingRow {
                id: slotRow
                required property var modelData

                width: parent.width
                label: modelData.label
                tableHeader: "bar.dead_zone"
                settingKey: modelData.key
                defaultValue: Config.defaults.bar.dead_zone[modelData.key]
                showOverriddenOnly: root.showOverriddenOnly

                Settings.ActionPicker {
                    width: parent.width
                    currentValue: Config.data.bar.dead_zone[slotRow.modelData.key] || ""
                    onActionSelected: (value) => Config.setValue("bar.dead_zone", slotRow.modelData.key, value)
                }
            }
        }
    }
}
