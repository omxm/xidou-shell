import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Bar > General: Enabled/Position/Auto-Hide/Reserve Space (bar.enabled/
// position/auto_hide/reserve_space). Height moved out to Bar > Layout as
// "Thickness" (real Noctalia terminology, and Layout is where the rest of
// the bar's sizing knobs -- Content Scale, Font Scale, margins, padding --
// now live) -- still the same bar.height config key underneath, just
// relabeled and relocated now that Layout exists as its own tab.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        enabledRow.reset();
        positionRow.reset();
        autoHideRow.reset();
        reserveSpaceRow.reset();
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: enabledRow
            label: "Enabled"
            tableHeader: "bar"
            settingKey: "enabled"
            defaultValue: Config.defaults.bar.enabled
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: true, label: "On" },
                    { value: false, label: "Off" }
                ]
                currentValue: Config.data.bar.enabled
                onOptionSelected: (value) => Config.setValue("bar", "enabled", value)
            }
        }

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
            id: autoHideRow
            label: "Auto-Hide"
            tableHeader: "bar"
            settingKey: "auto_hide"
            defaultValue: Config.defaults.bar.auto_hide
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: "off", label: "Off" },
                    { value: "on", label: "On" },
                    { value: "smart", label: "Smart" }
                ]
                currentValue: Config.data.bar.auto_hide
                onOptionSelected: (value) => Config.setValue("bar", "auto_hide", value)
            }
        }

        Settings.SettingRow {
            id: reserveSpaceRow
            label: "Reserve Space"
            tableHeader: "bar"
            settingKey: "reserve_space"
            defaultValue: Config.defaults.bar.reserve_space
            showOverriddenOnly: root.showOverriddenOnly

            // Bar.qml's own exclusiveZone binding already ignores this
            // value whenever Auto-Hide isn't Off (a bar that's hidden most
            // of the time can't sensibly reserve permanent strut space) --
            // dimmed and disabled here to match, same "value currently does
            // nothing" convention as Media's Artist First under Hide
            // Artist, rather than letting the toggle silently do nothing.
            Settings.OptionRow {
                width: parent.width
                enabled: Config.data.bar.auto_hide === "off"
                opacity: enabled ? 1 : 0.5
                options: [
                    { value: true, label: "On" },
                    { value: false, label: "Off" }
                ]
                currentValue: Config.data.bar.reserve_space
                onOptionSelected: (value) => Config.setValue("bar", "reserve_space", value)
            }
        }
    }
}
