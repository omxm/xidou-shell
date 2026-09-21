import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Appearance > Interface: font settings (theme.font_family/font_size, used
// throughout every panel via Theme.qml). Bar Position moved out to the
// dedicated Bar category's General tab (alongside Bar Height and the
// module toggles) once Bar settings grew enough surface area to warrant
// their own category -- keeping the same setting editable from two places
// would just be confusing, so it lives in exactly one now.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        fontFamilyRow.reset();
        fontSizeRow.reset();
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
    }
}
