import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Appearance > Theme: the first settings tab with real, persisted controls.
// Each row writes straight through Config.setValue() (Step 1) rather than
// touching config.toml itself, and tracks "Overridden" by comparing the
// live value against Config.defaults -- the same built-in defaults
// config.example.toml ships, not a value this file invents itself.
//
// Palette Source deliberately only offers Built-in/Wallpaper: those are the
// only two values Theme.qml's useWallpaperColors actually implements.
// "Community"/"Custom" (mentioned in original planning) have no backing
// logic or design anywhere yet, so they're left out entirely rather than
// shown disabled -- a placeholder for an undesigned feature would just be
// guessing at its future shape.
//
// The scheme-preset control stays click-to-cycle (a single button showing
// the current preset, click advances to the next) rather than becoming a
// dropdown here -- same widget, same underlying value, as the wallpaper
// picker's own cycleSchemePreset(); building a second, differently-shaped
// control for the same setting would just be visual inconsistency for no
// reason. It's dimmed when Palette Source is "builtin", since scheme_type
// only has any effect when source is "wallpaper" (config.example.toml's own
// comment on scheme_type says as much).
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        modeRow.reset();
        sourceRow.reset();
        schemeRow.reset();
    }

    readonly property var schemePresetNames: Object.keys(Config.data.theme.scheme_presets)
    readonly property string schemePresetLabel: {
        var names = root.schemePresetNames;
        for (var i = 0; i < names.length; i++)
            if (Config.data.theme.scheme_presets[names[i]] === Config.data.theme.scheme_type)
                return names[i];
        return names.length > 0 ? names[0] : "";
    }

    function cycleSchemePreset() {
        var names = root.schemePresetNames;
        if (names.length === 0)
            return;
        var currentIndex = names.indexOf(root.schemePresetLabel);
        var next = names[(currentIndex + 1) % names.length];
        Config.setValue("theme", "scheme_type", Config.data.theme.scheme_presets[next]);
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: modeRow
            label: "Theme Mode"
            tableHeader: "theme"
            settingKey: "mode"
            defaultValue: Config.defaults.theme.mode
            showOverriddenOnly: root.showOverriddenOnly

            Row {
                width: parent.width
                height: Theme.fontSize * 1.8
                spacing: Theme.fontSize / 3

                Repeater {
                    model: [
                        { value: "dark", label: "Dark" },
                        { value: "light", label: "Light" },
                        { value: "auto", label: "Auto" }
                    ]
                    delegate: Rectangle {
                        id: modeOption
                        required property var modelData

                        width: (parent.width - 2 * (Theme.fontSize / 3)) / 3
                        height: parent.height
                        radius: Theme.radius / 2
                        color: Config.data.theme.mode === modelData.value ? Theme.accent : Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: modeOption.modelData.label
                            color: Config.data.theme.mode === modeOption.modelData.value ? Theme.background : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.85
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.setValue("theme", "mode", modeOption.modelData.value)
                        }
                    }
                }
            }
        }

        Settings.SettingRow {
            id: sourceRow
            label: "Palette Source"
            tableHeader: "theme"
            settingKey: "source"
            defaultValue: Config.defaults.theme.source
            showOverriddenOnly: root.showOverriddenOnly

            Row {
                width: parent.width
                height: Theme.fontSize * 1.8
                spacing: Theme.fontSize / 3

                Repeater {
                    model: [
                        { value: "builtin", label: "Built-in" },
                        { value: "wallpaper", label: "Wallpaper" }
                    ]
                    delegate: Rectangle {
                        id: sourceOption
                        required property var modelData

                        width: (parent.width - (Theme.fontSize / 3)) / 2
                        height: parent.height
                        radius: Theme.radius / 2
                        color: Config.data.theme.source === modelData.value ? Theme.accent : Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: sourceOption.modelData.label
                            color: Config.data.theme.source === sourceOption.modelData.value ? Theme.background : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.85
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.setValue("theme", "source", sourceOption.modelData.value)
                        }
                    }
                }
            }
        }

        Settings.SettingRow {
            id: schemeRow
            label: "Wallpaper Generation Scheme"
            tableHeader: "theme"
            settingKey: "scheme_type"
            defaultValue: Config.defaults.theme.scheme_type
            showOverriddenOnly: root.showOverriddenOnly

            Rectangle {
                width: Theme.fontSize * 10
                height: Theme.fontSize * 1.8
                radius: Theme.radius / 2
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border
                opacity: Config.data.theme.source === "wallpaper" ? 1 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: root.schemePresetLabel
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.85
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: Config.data.theme.source === "wallpaper"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleSchemePreset()
                }
            }
        }
    }
}
