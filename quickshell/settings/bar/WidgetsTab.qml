import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Bar > Widgets: [bar.widgets] -- the bar-wide DEFAULT layer a future
// per-widget Presentation override layer (deferred separately) is meant to
// sit on top of. Font Family/Weight/Spacing are straightforward. Color/Icon
// Color only replace the "normal/active-state" Theme.text leaf each
// module's own color expression has -- Weather/Cpu/Mem/Dnd/Workspaces/Logo
// keep their own textMuted/warning/accent/brand colors untouched (see
// Config.qml's own comment on [bar.widgets] for why: a blanket override
// would erase real state feedback). Hover Highlight is the shell's first
// hover feedback anywhere on the bar.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        fontFamilyRow.reset();
        fontWeightRow.reset();
        spacingRow.reset();
        colorRow.reset();
        iconColorRow.reset();
        hoverHighlightRow.reset();
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
                id: fontFamilyRow
                width: parent.width
                label: "Font Family"
                tableHeader: "bar.widgets"
                settingKey: "font_family"
                defaultValue: Config.defaults.bar.widgets.font_family
                showOverriddenOnly: root.showOverriddenOnly

                Settings.TextCommitField {
                    width: parent.width
                    value: Config.data.bar.widgets.font_family
                    placeholder: "Theme default (" + Theme.fontFamily + ")"
                    onCommitted: (text) => Config.setValue("bar.widgets", "font_family", text)
                }
            }

            Settings.SettingRow {
                id: fontWeightRow
                width: parent.width
                label: "Font Weight"
                tableHeader: "bar.widgets"
                settingKey: "font_weight"
                defaultValue: Config.defaults.bar.widgets.font_weight
                showOverriddenOnly: root.showOverriddenOnly

                Settings.OptionRow {
                    width: parent.width
                    options: [
                        { value: "normal", label: "Normal" },
                        { value: "medium", label: "Medium" },
                        { value: "bold", label: "Bold" }
                    ]
                    currentValue: Config.data.bar.widgets.font_weight
                    onOptionSelected: (value) => Config.setValue("bar.widgets", "font_weight", value)
                }
            }

            Settings.SettingRow {
                id: spacingRow
                width: parent.width
                label: "Widget Spacing"
                tableHeader: "bar.widgets"
                settingKey: "spacing"
                defaultValue: Config.defaults.bar.widgets.spacing
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.widgets.spacing
                    minValue: 0
                    maxValue: 32
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.widgets", "spacing", newValue)
                }
            }

            Settings.SettingRow {
                id: colorRow
                width: parent.width
                label: "Widget Color"
                tableHeader: "bar.widgets"
                settingKey: "color"
                defaultValue: Config.defaults.bar.widgets.color
                showOverriddenOnly: root.showOverriddenOnly

                Settings.TextCommitField {
                    width: parent.width
                    value: Config.data.bar.widgets.color
                    placeholder: "Theme default"
                    onCommitted: (text) => Config.setValue("bar.widgets", "color", text)
                }
            }

            Settings.SettingRow {
                id: iconColorRow
                width: parent.width
                label: "Widget Icon Color"
                tableHeader: "bar.widgets"
                settingKey: "icon_color"
                defaultValue: Config.defaults.bar.widgets.icon_color
                showOverriddenOnly: root.showOverriddenOnly

                Settings.TextCommitField {
                    width: parent.width
                    value: Config.data.bar.widgets.icon_color
                    placeholder: "Theme default"
                    onCommitted: (text) => Config.setValue("bar.widgets", "icon_color", text)
                }
            }

            Settings.SettingRow {
                id: hoverHighlightRow
                width: parent.width
                label: "Hover Highlight"
                tableHeader: "bar.widgets"
                settingKey: "hover_highlight"
                defaultValue: Config.defaults.bar.widgets.hover_highlight
                showOverriddenOnly: root.showOverriddenOnly

                Settings.OptionRow {
                    width: parent.width
                    options: [
                        { value: true, label: "On" },
                        { value: false, label: "Off" }
                    ]
                    currentValue: Config.data.bar.widgets.hover_highlight
                    onOptionSelected: (value) => Config.setValue("bar.widgets", "hover_highlight", value)
                }
            }
        }
    }
}
