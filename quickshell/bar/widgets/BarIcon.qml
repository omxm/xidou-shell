import QtQuick
import "../../config"

// A bar module's Material Symbols glyph (ROADMAP F5). Same size rule as
// BarLabel; the color falls back to Bar > Widgets > Icon Color, then
// Theme.text. Icon glyphs never take the widgets font family or weight.
// stateColor works as in BarLabel.
Text {
    property var stateColor: undefined

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: stateColor !== undefined ? stateColor : (Config.data.bar.widgets.icon_color || Theme.text)
    font.family: Theme.iconFontFamily
    font.pixelSize: Theme.fontSize * Config.data.bar.layout.font_scale
}
