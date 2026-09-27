import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Bar > Shape: [bar.shape]. Before this tab, Bar.qml had zero rounding
// capability at all -- its PanelWindow painted `color: Theme.background`
// directly (a Window property; Rectangle's radius doesn't exist on Window),
// so this wired up real new rendering (a transparent PanelWindow + an inner
// Rectangle doing the actual painting, same pattern Osd.qml already
// established), not just settings over an existing mechanism. Per-corner
// radius uses Qt 6.7+'s topLeftRadius/etc. Rectangle properties directly --
// this project's Qt (6.11.2) is well past that, no custom Shape/Canvas
// needed for the rounding itself (Corner Flow below is a separate matter).
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        cornerRadiusRow.reset();
        topLeftRow.reset();
        topRightRow.reset();
        bottomLeftRow.reset();
        bottomRightRow.reset();
        cornerFlowRow.reset();
        borderEnabledRow.reset();
        borderWidthRow.reset();
    }

    // -1 reads as "Auto" (inherit the uniform Corner Radius above) --
    // NumberStepper's formatText override, not a special value the config
    // itself needs to know how to print.
    function formatCornerOverride(value) {
        return value < 0 ? "Auto" : (value + "px");
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width
            spacing: Theme.fontSize / 2

            Settings.SettingRow {
                id: cornerRadiusRow
                width: parent.width
                label: "Corner Radius"
                tableHeader: "bar.shape"
                settingKey: "corner_radius"
                defaultValue: Config.defaults.bar.shape.corner_radius
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.shape.corner_radius
                    minValue: 0
                    maxValue: 32
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.shape", "corner_radius", newValue)
                }
            }

            Settings.SettingRow {
                id: topLeftRow
                width: parent.width
                label: "Top Left Radius"
                tableHeader: "bar.shape"
                settingKey: "top_left_radius"
                defaultValue: Config.defaults.bar.shape.top_left_radius
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.shape.top_left_radius
                    minValue: -1
                    maxValue: 32
                    formatText: root.formatCornerOverride
                    onStepped: (newValue) => Config.setValue("bar.shape", "top_left_radius", newValue)
                }
            }

            Settings.SettingRow {
                id: topRightRow
                width: parent.width
                label: "Top Right Radius"
                tableHeader: "bar.shape"
                settingKey: "top_right_radius"
                defaultValue: Config.defaults.bar.shape.top_right_radius
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.shape.top_right_radius
                    minValue: -1
                    maxValue: 32
                    formatText: root.formatCornerOverride
                    onStepped: (newValue) => Config.setValue("bar.shape", "top_right_radius", newValue)
                }
            }

            Settings.SettingRow {
                id: bottomLeftRow
                width: parent.width
                label: "Bottom Left Radius"
                tableHeader: "bar.shape"
                settingKey: "bottom_left_radius"
                defaultValue: Config.defaults.bar.shape.bottom_left_radius
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.shape.bottom_left_radius
                    minValue: -1
                    maxValue: 32
                    formatText: root.formatCornerOverride
                    onStepped: (newValue) => Config.setValue("bar.shape", "bottom_left_radius", newValue)
                }
            }

            Settings.SettingRow {
                id: bottomRightRow
                width: parent.width
                label: "Bottom Right Radius"
                tableHeader: "bar.shape"
                settingKey: "bottom_right_radius"
                defaultValue: Config.defaults.bar.shape.bottom_right_radius
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.shape.bottom_right_radius
                    minValue: -1
                    maxValue: 32
                    formatText: root.formatCornerOverride
                    onStepped: (newValue) => Config.setValue("bar.shape", "bottom_right_radius", newValue)
                }
            }

            Settings.SettingRow {
                id: cornerFlowRow
                width: parent.width
                label: "Corner Flow"
                tableHeader: "bar.shape"
                settingKey: "corner_flow"
                defaultValue: Config.defaults.bar.shape.corner_flow
                showOverriddenOnly: root.showOverriddenOnly

                // Only means anything when the bar is flush against the
                // screen (Layout's Ends Margin AND Edge Margin both 0) --
                // Bar.qml's own cornerFlowActive ignores it otherwise,
                // dimmed and disabled here to match, same convention as
                // Reserve Space under Auto-Hide.
                Settings.OptionRow {
                    width: parent.width
                    enabled: Config.data.bar.layout.edge_margin === 0 && Config.data.bar.layout.ends_margin === 0
                    opacity: enabled ? 1 : 0.5
                    options: [
                        { value: true, label: "On" },
                        { value: false, label: "Off" }
                    ]
                    currentValue: Config.data.bar.shape.corner_flow
                    onOptionSelected: (value) => Config.setValue("bar.shape", "corner_flow", value)
                }
            }

            Settings.SettingRow {
                id: borderEnabledRow
                width: parent.width
                label: "Border"
                tableHeader: "bar.shape"
                settingKey: "border_enabled"
                defaultValue: Config.defaults.bar.shape.border_enabled
                showOverriddenOnly: root.showOverriddenOnly

                Settings.OptionRow {
                    width: parent.width
                    options: [
                        { value: true, label: "On" },
                        { value: false, label: "Off" }
                    ]
                    currentValue: Config.data.bar.shape.border_enabled
                    onOptionSelected: (value) => Config.setValue("bar.shape", "border_enabled", value)
                }
            }

            Settings.SettingRow {
                id: borderWidthRow
                width: parent.width
                label: "Border Width"
                tableHeader: "bar.shape"
                settingKey: "border_width"
                defaultValue: Config.defaults.bar.shape.border_width
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    enabled: Config.data.bar.shape.border_enabled
                    opacity: enabled ? 1 : 0.5
                    value: Config.data.bar.shape.border_width
                    minValue: 1
                    maxValue: 6
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.shape", "border_width", newValue)
                }
            }
        }
    }
}
