import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Appearance > Borders: Corner Radius (theme.radius, used by every rounded
// panel/card/button in the shell -- 23+ call sites) and Border Color
// (theme.border, the border.color on most of those same elements -- 21+
// call sites). Both are real, pervasively-used values, unlike
// Accessibility/Motion/Effects (see InterfaceTab.qml's header comment for
// why those have nothing to wire up yet).
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        radiusRow.reset();
        borderColorRow.reset();
    }

    readonly property int minRadius: 0
    readonly property int maxRadius: 24
    readonly property var hexColorPattern: /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: radiusRow
            label: "Corner Radius"
            tableHeader: "theme"
            settingKey: "radius"
            defaultValue: Config.defaults.theme.radius
            showOverriddenOnly: root.showOverriddenOnly

            Settings.NumberStepper {
                value: Config.data.theme.radius
                minValue: root.minRadius
                maxValue: root.maxRadius
                suffix: "px"
                onStepped: (newValue) => Config.setValue("theme", "radius", newValue)
            }
        }

        Settings.SettingRow {
            id: borderColorRow
            label: "Border Color"
            tableHeader: "theme"
            settingKey: "border"
            defaultValue: Config.defaults.theme.border
            showOverriddenOnly: root.showOverriddenOnly

            Row {
                width: parent.width
                height: Theme.fontSize * 1.8
                spacing: Theme.fontSize / 3

                Rectangle {
                    width: height
                    height: parent.height
                    radius: Theme.radius / 2
                    color: Config.data.theme.border
                    border.width: 1
                    border.color: Theme.text
                }

                // Color needs a real hex-input control -- unlike every other
                // setting built so far, there's no existing widget shape in
                // this codebase to reuse for a color value. Deliberately no
                // TextInput `validator:` -- see the memory on why that
                // silently blocks keystrokes instead of flagging bad input
                // (a QRegularExpressionValidator rejects "3a3a3a" outright
                // since no string starting with a digit can ever match a
                // pattern requiring a leading "#", which for a very natural
                // typo -- forgetting the # -- means every keystroke is
                // silently eaten with zero feedback). isValid here only
                // reddens the border and gates the commit, via
                // TextCommitField.text.
                Settings.TextCommitField {
                    id: borderColorField
                    width: Theme.fontSize * 8
                    value: Config.data.theme.border
                    isValid: root.hexColorPattern.test(borderColorField.text)
                    onCommitted: (text) => Config.setValue("theme", "border", text)
                }
            }
        }
    }
}
