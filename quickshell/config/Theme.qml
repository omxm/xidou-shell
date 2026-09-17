pragma Singleton

import QtQuick
import Quickshell

// The single source of colors and fonts for every panel. Nothing outside this
// file should ever write a color or font literal — import Theme and bind to
// these properties instead, so re-theming means editing config.toml, not QML.
Singleton {
    id: root

    readonly property var tokens: Config.data.theme

    property string mode: tokens.mode

    property color accent: tokens.accent
    property color background: tokens.background
    property color surface: tokens.surface
    property color surfaceAlt: tokens.surface_alt
    property color text: tokens.text
    property color textMuted: tokens.text_muted
    property color border: tokens.border

    property int radius: tokens.radius

    property string fontFamily: tokens.font_family
    property string iconFontFamily: tokens.icon_font_family
    property int fontSize: tokens.font_size
}
