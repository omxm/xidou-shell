import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Bar > Effects: [bar.effects]. Background Opacity is a straightforward
// alpha multiplier on the background Rectangle Shape's work already
// introduced. Shadow/Contact Shadow are genuinely new -- the shell's first
// use of a real shadow effect anywhere (QtQuick.Effects' MultiEffect, native
// since Qt 6.5, no Qt5Compat.GraphicalEffects needed at this project's Qt
// 6.11.2). Contact Shadow has no "attached panel" concept to key off (none
// exists in the shell today), so it's a fixed gradient at the bar's own
// edge regardless of what's actually beneath it.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        backgroundOpacityRow.reset();
        shadowRow.reset();
        contactShadowRow.reset();
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        // Stored as a 0-1 float (Bar.qml reads it directly), shown as a
        // 0-100 percent stepper and converted at the write boundary -- same
        // "no new float stepper component" call as Capsules' Opacity.
        Settings.SettingRow {
            id: backgroundOpacityRow
            width: parent.width
            label: "Background Opacity"
            tableHeader: "bar.effects"
            settingKey: "background_opacity"
            defaultValue: Config.defaults.bar.effects.background_opacity
            showOverriddenOnly: root.showOverriddenOnly

            Settings.NumberStepper {
                value: Math.round(Config.data.bar.effects.background_opacity * 100)
                minValue: 0
                maxValue: 100
                suffix: "%"
                onStepped: (newValue) => Config.setValue("bar.effects", "background_opacity", newValue / 100)
            }
        }

        Settings.SettingRow {
            id: shadowRow
            width: parent.width
            label: "Shadow"
            tableHeader: "bar.effects"
            settingKey: "shadow_enabled"
            defaultValue: Config.defaults.bar.effects.shadow_enabled
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: true, label: "On" },
                    { value: false, label: "Off" }
                ]
                currentValue: Config.data.bar.effects.shadow_enabled
                onOptionSelected: (value) => Config.setValue("bar.effects", "shadow_enabled", value)
            }
        }

        Settings.SettingRow {
            id: contactShadowRow
            width: parent.width
            label: "Contact Shadow"
            tableHeader: "bar.effects"
            settingKey: "contact_shadow_enabled"
            defaultValue: Config.defaults.bar.effects.contact_shadow_enabled
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: true, label: "On" },
                    { value: false, label: "Off" }
                ]
                currentValue: Config.data.bar.effects.contact_shadow_enabled
                onOptionSelected: (value) => Config.setValue("bar.effects", "contact_shadow_enabled", value)
            }
        }
    }
}
