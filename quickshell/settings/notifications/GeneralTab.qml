import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Notifications > General: Position and Margin (notification.position/
// notification.margin), real config.toml keys since Phase 4 -- shared by
// lib/Position.js's resolve() with Osd.qml, same lighter-lift pattern as
// OSD's own settings tab (pure UI wiring, no new config table). Width/
// spacing/timeout_ms deliberately left alone -- scoped to position+margin
// only, matching OSD.
//
// Position is composed from two stacked OptionRows exactly like OSD's --
// same two-axis (vertical/horizontal) shape, same reason a flat 6-option
// row doesn't fit this panel width well.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        positionRow.reset();
        marginRow.reset();
    }

    function verticalOf(position) {
        return ((position || "top-right").split("-")[0] === "bottom") ? "bottom" : "top";
    }

    function horizontalOf(position) {
        var parts = (position || "top-right").split("-");
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
            tableHeader: "notification"
            settingKey: "position"
            defaultValue: Config.defaults.notification.position
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
                    currentValue: root.verticalOf(Config.data.notification.position)
                    onOptionSelected: (value) => Config.setValue("notification", "position", value + "-" + root.horizontalOf(Config.data.notification.position))
                }

                Settings.OptionRow {
                    width: parent.width
                    options: [
                        { value: "left", label: "Left" },
                        { value: "center", label: "Center" },
                        { value: "right", label: "Right" }
                    ]
                    currentValue: root.horizontalOf(Config.data.notification.position)
                    onOptionSelected: (value) => Config.setValue("notification", "position", root.verticalOf(Config.data.notification.position) + "-" + value)
                }
            }
        }

        Settings.SettingRow {
            id: marginRow
            label: "Margin"
            tableHeader: "notification"
            settingKey: "margin"
            defaultValue: Config.defaults.notification.margin
            showOverriddenOnly: root.showOverriddenOnly

            Settings.NumberStepper {
                value: Config.data.notification.margin
                minValue: root.minMargin
                maxValue: root.maxMargin
                suffix: "px"
                onStepped: (newValue) => Config.setValue("notification", "margin", newValue)
            }
        }
    }
}
