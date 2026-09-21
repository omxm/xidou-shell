import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// OSD > General: Position and Margin (osd.position/osd.margin), both real
// config.toml keys since Phase 3 -- shared by lib/Position.js's resolve()
// with NotificationPopups.qml, so this is a lighter lift than Screenshot
// was (wiring up existing values, not adding a new config table). Width/
// height aren't included -- はる scoped this to position+margin only.
//
// Position has no existing widget shape to reuse: it's two independent
// axes (vertical: top/bottom, horizontal: left/center/right) combined into
// one "top-center"-style string, not a flat set of options an OptionRow
// fits directly. Composed from two stacked OptionRows instead of a new
// 6-option single row, which would either need tiny abbreviated labels
// ("TL"/"TC"/"TR"/...) to fit the panel width or overflow it -- two rows of
// full-word options reads clearer at this panel's size. SettingRow's
// rowHeight override exists specifically for this taller control.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        positionRow.reset();
        marginRow.reset();
    }

    function verticalOf(position) {
        return ((position || "top-center").split("-")[0] === "bottom") ? "bottom" : "top";
    }

    function horizontalOf(position) {
        var parts = (position || "top-center").split("-");
        return parts[1] || "center";
    }

    readonly property int minMargin: 0
    readonly property int maxMargin: 64

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: positionRow
            label: "Position"
            tableHeader: "osd"
            settingKey: "position"
            defaultValue: Config.defaults.osd.position
            showOverriddenOnly: root.showOverriddenOnly
            rowHeight: Theme.fontSize * 2.6 + Theme.fontSize * 1.8 + Theme.fontSize / 4

            Column {
                width: parent.width
                spacing: Theme.fontSize / 4

                Settings.OptionRow {
                    width: parent.width
                    options: [
                        { value: "top", label: "Top" },
                        { value: "bottom", label: "Bottom" }
                    ]
                    currentValue: root.verticalOf(Config.data.osd.position)
                    onOptionSelected: (value) => Config.setValue("osd", "position", value + "-" + root.horizontalOf(Config.data.osd.position))
                }

                Settings.OptionRow {
                    width: parent.width
                    options: [
                        { value: "left", label: "Left" },
                        { value: "center", label: "Center" },
                        { value: "right", label: "Right" }
                    ]
                    currentValue: root.horizontalOf(Config.data.osd.position)
                    onOptionSelected: (value) => Config.setValue("osd", "position", root.verticalOf(Config.data.osd.position) + "-" + value)
                }
            }
        }

        Settings.SettingRow {
            id: marginRow
            label: "Margin"
            tableHeader: "osd"
            settingKey: "margin"
            defaultValue: Config.defaults.osd.margin
            showOverriddenOnly: root.showOverriddenOnly

            Settings.NumberStepper {
                value: Config.data.osd.margin
                minValue: root.minMargin
                maxValue: root.maxMargin
                suffix: "px"
                onStepped: (newValue) => Config.setValue("osd", "margin", newValue)
            }
        }
    }
}
