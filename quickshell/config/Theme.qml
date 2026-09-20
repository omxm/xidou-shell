pragma Singleton

import QtQuick
import Quickshell
import "../services"

// The single source of colors and fonts for every panel. Nothing outside this
// file should ever write a color or font literal — import Theme and bind to
// these properties instead, so re-theming means editing config.toml, not QML.
//
// theme.source: "wallpaper" switches the color properties (font/radius are
// unaffected -- matugen has no opinion on those) to ColorScheme's
// matugen-derived palette instead of the static hex values below, falling
// back to builtin until the first regenerate() actually completes so there's
// never a flash of undefined colors on a fresh install.
Singleton {
    id: root

    readonly property var tokens: Config.data.theme
    readonly property bool useWallpaperColors: tokens.source === "wallpaper" && ColorScheme.colors !== null

    property string mode: tokens.mode

    property color accent: useWallpaperColors ? (ColorScheme.get("primary") || tokens.accent) : tokens.accent
    property color background: useWallpaperColors ? (ColorScheme.get("background") || tokens.background) : tokens.background
    property color surface: useWallpaperColors ? (ColorScheme.get("surface") || tokens.surface) : tokens.surface
    property color surfaceAlt: useWallpaperColors ? (ColorScheme.get("surface_container_high") || tokens.surface_alt) : tokens.surface_alt
    property color text: useWallpaperColors ? (ColorScheme.get("on_surface") || tokens.text) : tokens.text
    property color textMuted: useWallpaperColors ? (ColorScheme.get("on_surface_variant") || tokens.text_muted) : tokens.text_muted
    property color border: useWallpaperColors ? (ColorScheme.get("outline") || tokens.border) : tokens.border

    property int radius: tokens.radius

    property string fontFamily: tokens.font_family
    property string iconFontFamily: tokens.icon_font_family
    property int fontSize: tokens.font_size
}
