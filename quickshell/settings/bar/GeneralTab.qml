import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Bar > General: Position and Height (bar.position/bar.height), both read
// directly by Bar.qml (anchors.top/bottom and implicitHeight/exclusiveZone
// respectively) -- moved here from Appearance > Interface (Position) and
// newly wired (Height) now that Bar has enough real settings to warrant its
// own category rather than living under Interface.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        positionRow.reset();
        heightRow.reset();
    }

    // 24-48px: sane range for this hardware's 1366x768 panel -- tall enough
    // to stay usable, short enough not to eat too much vertical space.
    readonly property int minHeight: 24
    readonly property int maxHeight: 48

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: positionRow
            label: "Position"
            tableHeader: "bar"
            settingKey: "position"
            defaultValue: Config.defaults.bar.position
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: "top", label: "Top" },
                    { value: "bottom", label: "Bottom" }
                ]
                currentValue: Config.data.bar.position
                onOptionSelected: (value) => Config.setValue("bar", "position", value)
            }
        }

        Settings.SettingRow {
            id: heightRow
            label: "Height"
            tableHeader: "bar"
            settingKey: "height"
            defaultValue: Config.defaults.bar.height
            showOverriddenOnly: root.showOverriddenOnly

            Settings.NumberStepper {
                value: Config.data.bar.height
                minValue: root.minHeight
                maxValue: root.maxHeight
                suffix: "px"
                onStepped: (newValue) => Config.setValue("bar", "height", newValue)
            }
        }
    }
}
