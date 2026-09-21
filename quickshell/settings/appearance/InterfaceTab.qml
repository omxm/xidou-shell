import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Appearance > Interface: font settings (theme.font_family/font_size, used
// throughout every panel via Theme.qml) and Bar Position (bar.position,
// which Bar.qml reads reactively -- flips the bar between top/bottom
// live). These are the most pervasively-used real config values available
// for an "Interface" tab; bar module reordering (modules_left/center/right)
// is left for a dedicated future pass -- rearranging an array is a bigger
// feature (drag-reorder or add/remove chips) than wiring up an existing
// scalar value, the same "build what's functional now" call already made
// for Theme's Palette Source.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        fontFamilyRow.reset();
        fontSizeRow.reset();
        barPositionRow.reset();
    }

    // Clamped to a range wide enough for this hardware's 1366x768 panel
    // without letting the UI become unusably large or unreadably small.
    readonly property int minFontSize: 8
    readonly property int maxFontSize: 32

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: fontFamilyRow
            label: "Font Family"
            tableHeader: "theme"
            settingKey: "font_family"
            defaultValue: Config.defaults.theme.font_family
            showOverriddenOnly: root.showOverriddenOnly

            Settings.TextCommitField {
                width: parent.width
                value: Config.data.theme.font_family
                onCommitted: (text) => Config.setValue("theme", "font_family", text)
            }
        }

        Settings.SettingRow {
            id: fontSizeRow
            label: "Font Size"
            tableHeader: "theme"
            settingKey: "font_size"
            defaultValue: Config.defaults.theme.font_size
            showOverriddenOnly: root.showOverriddenOnly

            Settings.NumberStepper {
                value: Config.data.theme.font_size
                minValue: root.minFontSize
                maxValue: root.maxFontSize
                suffix: "px"
                onStepped: (newValue) => Config.setValue("theme", "font_size", newValue)
            }
        }

        Settings.SettingRow {
            id: barPositionRow
            label: "Bar Position"
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
    }
}
