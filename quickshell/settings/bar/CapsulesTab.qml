import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Bar > Capsules: bar-wide capsule styling under [bar.capsules] --
// Bar.qml's own capsuleModuleComponent wraps every module's Loader in a
// Rectangle background driven by these values. Bar-wide only for this pass
// -- a per-widget Presentation layer letting one module override/opt out of
// these is separate, larger deferred work, not built here.
//
// Thickness and Opacity are stored as 0-1 floats (Bar.qml reads them
// directly), but NumberStepper is int-only -- both are shown here as a 0-100
// percent stepper and converted at the write boundary, same "no new float
// stepper component" call as everywhere else so far that's needed a
// fractional value.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        enabledRow.reset();
        thicknessRow.reset();
        radiusRow.reset();
        fillRow.reset();
        paddingRow.reset();
        borderWidthRow.reset();
        opacityRow.reset();
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: enabledRow
            width: parent.width
            label: "Widget Capsules"
            tableHeader: "bar.capsules"
            settingKey: "enabled"
            defaultValue: Config.defaults.bar.capsules.enabled
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: true, label: "On" },
                    { value: false, label: "Off" }
                ]
                currentValue: Config.data.bar.capsules.enabled
                onOptionSelected: (value) => Config.setValue("bar.capsules", "enabled", value)
            }
        }

        // The rest only mean something once capsules are actually on --
        // dimmed and disabled rather than hidden, same "value currently does
        // nothing" treatment as Media's Artist First under Hide Artist.
        Column {
            width: parent.width
            spacing: Theme.fontSize / 2
            enabled: Config.data.bar.capsules.enabled
            opacity: enabled ? 1 : 0.5

            Settings.SettingRow {
                id: thicknessRow
                width: parent.width
                label: "Capsule Thickness"
                tableHeader: "bar.capsules"
                settingKey: "thickness"
                defaultValue: Config.defaults.bar.capsules.thickness
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Math.round(Config.data.bar.capsules.thickness * 100)
                    minValue: 10
                    maxValue: 100
                    suffix: "%"
                    onStepped: (newValue) => Config.setValue("bar.capsules", "thickness", newValue / 100)
                }
            }

            Settings.SettingRow {
                id: radiusRow
                width: parent.width
                label: "Capsule Radius"
                tableHeader: "bar.capsules"
                settingKey: "radius"
                defaultValue: Config.defaults.bar.capsules.radius
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    // 60px is already well past where Bar.qml's own
                    // render-time clamp (half the capsule's own smaller
                    // dimension) caps out at any realistic bar height, so
                    // there's no reason to let this run further -- the
                    // stepper only moves ±1 per click, but a much larger
                    // ceiling than the value can ever visibly do anything
                    // with just invites an accidental huge number from
                    // holding the button down.
                    value: Config.data.bar.capsules.radius
                    minValue: 0
                    maxValue: 60
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.capsules", "radius", newValue)
                }
            }

            Settings.SettingRow {
                id: fillRow
                width: parent.width
                label: "Capsule Fill"
                tableHeader: "bar.capsules"
                settingKey: "fill"
                defaultValue: Config.defaults.bar.capsules.fill
                showOverriddenOnly: root.showOverriddenOnly

                Settings.OptionRow {
                    width: parent.width
                    // Smaller than OptionRow's default -- 4 options with
                    // labels as long as "Surface Alt"/"Background" clip at
                    // the default size within a standard SettingRow's
                    // 40%-width control slot.
                    labelFontSize: Theme.fontSize * 0.7
                    options: [
                        { value: "surface", label: "Surface" },
                        { value: "surface_alt", label: "Surface Alt" },
                        { value: "accent", label: "Accent" },
                        { value: "background", label: "Background" }
                    ]
                    currentValue: Config.data.bar.capsules.fill
                    onOptionSelected: (value) => Config.setValue("bar.capsules", "fill", value)
                }
            }

            Settings.SettingRow {
                id: paddingRow
                width: parent.width
                label: "Capsule Padding"
                tableHeader: "bar.capsules"
                settingKey: "padding"
                defaultValue: Config.defaults.bar.capsules.padding
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.capsules.padding
                    minValue: 0
                    maxValue: 40
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.capsules", "padding", newValue)
                }
            }

            Settings.SettingRow {
                id: borderWidthRow
                width: parent.width
                label: "Capsule Border"
                tableHeader: "bar.capsules"
                settingKey: "border_width"
                defaultValue: Config.defaults.bar.capsules.border_width
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.capsules.border_width
                    minValue: 0
                    maxValue: 4
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.capsules", "border_width", newValue)
                }
            }

            Settings.SettingRow {
                id: opacityRow
                width: parent.width
                label: "Capsule Opacity"
                tableHeader: "bar.capsules"
                settingKey: "opacity"
                defaultValue: Config.defaults.bar.capsules.opacity
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Math.round(Config.data.bar.capsules.opacity * 100)
                    minValue: 10
                    maxValue: 100
                    suffix: "%"
                    onStepped: (newValue) => Config.setValue("bar.capsules", "opacity", newValue / 100)
                }
            }
        }
    }
}
