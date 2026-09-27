import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Bar > Layout: Thickness (bar.height, relocated here from General -- real
// Noctalia terminology, and this is where the bar's other sizing knobs now
// live too), Content Scale, Font Scale, Ends Margin, Edge Margin, Opposite
// Edge Margin, Content Padding, and Panel Overlap (Advanced), all under
// [bar.layout] except Thickness itself.
//
// Ends Margin + Edge Margin together are what makes a "floating bar" --
// shortened from both horizontal ends (Ends Margin) AND lifted off the
// screen edge it's anchored to (Edge Margin) at the same time. They're two
// independent margins.qml bindings on Bar.qml's own PanelWindow, not a
// single composite control, but setting both together is exactly the
// combination that produces the floating look.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        thicknessRow.reset();
        contentScaleRow.reset();
        fontScaleRow.reset();
        endsMarginRow.reset();
        edgeMarginRow.reset();
        oppositeEdgeMarginRow.reset();
        contentPaddingRow.reset();
        panelOverlapRow.reset();
    }

    // 24-48px: sane range for this hardware's 1366x768 panel -- tall enough
    // to stay usable, short enough not to eat too much vertical space.
    readonly property int minThickness: 24
    readonly property int maxThickness: 48

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
                id: thicknessRow
                width: parent.width
                label: "Thickness"
                tableHeader: "bar"
                settingKey: "height"
                defaultValue: Config.defaults.bar.height
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.height
                    minValue: root.minThickness
                    maxValue: root.maxThickness
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar", "height", newValue)
                }
            }

            // Content Scale and Font Scale are both stored as 0-1.5 floats
            // (Bar.qml reads them directly), shown here as a 50-150 percent
            // stepper and converted at the write boundary -- same "no new
            // float stepper component" call as Capsules' Thickness/Opacity.
            Settings.SettingRow {
                id: contentScaleRow
                width: parent.width
                label: "Content Scale"
                tableHeader: "bar.layout"
                settingKey: "content_scale"
                defaultValue: Config.defaults.bar.layout.content_scale
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Math.round(Config.data.bar.layout.content_scale * 100)
                    minValue: 50
                    maxValue: 150
                    suffix: "%"
                    onStepped: (newValue) => Config.setValue("bar.layout", "content_scale", newValue / 100)
                }
            }

            Settings.SettingRow {
                id: fontScaleRow
                width: parent.width
                label: "Font Scale"
                tableHeader: "bar.layout"
                settingKey: "font_scale"
                defaultValue: Config.defaults.bar.layout.font_scale
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Math.round(Config.data.bar.layout.font_scale * 100)
                    minValue: 50
                    maxValue: 150
                    suffix: "%"
                    onStepped: (newValue) => Config.setValue("bar.layout", "font_scale", newValue / 100)
                }
            }

            Settings.SettingRow {
                id: endsMarginRow
                width: parent.width
                label: "Ends Margin"
                tableHeader: "bar.layout"
                settingKey: "ends_margin"
                defaultValue: Config.defaults.bar.layout.ends_margin
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.layout.ends_margin
                    minValue: 0
                    maxValue: 200
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.layout", "ends_margin", newValue)
                }
            }

            Settings.SettingRow {
                id: edgeMarginRow
                width: parent.width
                label: "Edge Margin"
                tableHeader: "bar.layout"
                settingKey: "edge_margin"
                defaultValue: Config.defaults.bar.layout.edge_margin
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.layout.edge_margin
                    minValue: 0
                    maxValue: 60
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.layout", "edge_margin", newValue)
                }
            }

            Settings.SettingRow {
                id: oppositeEdgeMarginRow
                width: parent.width
                label: "Opposite Edge Margin"
                tableHeader: "bar.layout"
                settingKey: "opposite_edge_margin"
                defaultValue: Config.defaults.bar.layout.opposite_edge_margin
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.layout.opposite_edge_margin
                    minValue: 0
                    maxValue: 60
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.layout", "opposite_edge_margin", newValue)
                }
            }

            Settings.SettingRow {
                id: contentPaddingRow
                width: parent.width
                label: "Content Padding"
                tableHeader: "bar.layout"
                settingKey: "content_padding"
                defaultValue: Config.defaults.bar.layout.content_padding
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.layout.content_padding
                    minValue: 0
                    maxValue: 40
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.layout", "content_padding", newValue)
                }
            }

            Settings.SettingRow {
                id: panelOverlapRow
                width: parent.width
                label: "Panel Overlap (Advanced)"
                tableHeader: "bar.layout"
                settingKey: "panel_overlap"
                defaultValue: Config.defaults.bar.layout.panel_overlap
                showOverriddenOnly: root.showOverriddenOnly

                Settings.NumberStepper {
                    value: Config.data.bar.layout.panel_overlap
                    minValue: 0
                    maxValue: Config.data.bar.height
                    suffix: "px"
                    onStepped: (newValue) => Config.setValue("bar.layout", "panel_overlap", newValue)
                }
            }
        }
    }
}
