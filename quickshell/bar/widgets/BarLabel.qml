import QtQuick
import "../../config"

// A bar module's text (ROADMAP F5). Owns the Bar > Widgets styling every
// module used to repeat: font family and weight, Layout's font scale, and
// the widgets text color with Theme.text as fallback.
//
// stateColor: set it when the text's color carries state (muted, warning,
// active, a fixed accent); leave it undefined for the normal color, which
// Bar > Widgets > Widget Color then controls. extraPixels adds to the base
// size before scaling (the logo is 2 px larger).
Text {
    property var stateColor: undefined
    property real extraPixels: 0

    readonly property var widgetsCfg: Config.data.bar.widgets

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: stateColor !== undefined ? stateColor : (widgetsCfg.color || Theme.text)
    font.family: widgetsCfg.font_family || Theme.fontFamily
    font.weight: widgetsCfg.font_weight === "bold" ? Font.Bold : (widgetsCfg.font_weight === "medium" ? Font.Medium : Font.Normal)
    font.pixelSize: (Theme.fontSize + extraPixels) * Config.data.bar.layout.font_scale
}
