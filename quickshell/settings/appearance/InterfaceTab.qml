import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Appearance > Interface: font settings (theme.font_family/font_size, used
// throughout every panel via Theme.qml) and Bar Position (bar.position,
// which Bar.qml reads reactively -- flips the bar between top/bottom
// live). These are the most pervasively-used real config values available
// for an "Interface" tab; bar module reordering (modules_left/center/right)
// is left for a dedicated future pass -- rearranging an array is a bigger
// feature (drag-reorder or add/remove chips) than wiring up an existing
// scalar value, the same "build what's functional now" call already made
// for Theme's Palette Source.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        fontFamilyRow.reset();
        fontSizeRow.reset();
        barPositionRow.reset();
    }

    // Font size is stepped rather than freely typed, so no manual-edit vs.
    // reactive-binding conflict exists here the way it does for the font
    // family text field below -- clamped to a range wide enough for this
    // hardware's 1366x768 panel without letting the UI become unusably
    // large or unreadably small.
    readonly property int minFontSize: 8
    readonly property int maxFontSize: 32

    function stepFontSize(delta) {
        var next = Config.data.theme.font_size + delta;
        next = Math.max(root.minFontSize, Math.min(root.maxFontSize, next));
        Config.setValue("theme", "font_size", next);
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: fontFamilyRow
            label: "Font Family"
            tableHeader: "theme"
            settingKey: "font_family"
            defaultValue: Config.defaults.theme.font_family
            showOverriddenOnly: root.showOverriddenOnly

            Rectangle {
                width: parent.width
                height: Theme.fontSize * 1.8
                radius: Theme.radius / 2
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                TextInput {
                    id: fontFamilyInput
                    anchors.fill: parent
                    anchors.margins: Theme.fontSize / 2
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.85
                    clip: true

                    // Explicit resync rather than a live `text:` binding to
                    // Config.data -- QML would silently sever that binding
                    // the moment the user types a single character (a
                    // TextInput's own edits always win over its property
                    // binding), so it wouldn't pick up an external Reset
                    // or reload afterward. This re-reads on every Config
                    // reload instead, leaving free typing alone in between.
                    function syncFromConfig() {
                        if (!fontFamilyInput.activeFocus)
                            fontFamilyInput.text = Config.data.theme.font_family;
                    }

                    Component.onCompleted: syncFromConfig()

                    Connections {
                        target: Config
                        function onReloaded() {
                            fontFamilyInput.syncFromConfig();
                        }
                    }

                    Keys.onReturnPressed: fontFamilyInput.focus = false
                    Keys.onEnterPressed: fontFamilyInput.focus = false
                    onEditingFinished: Config.setValue("theme", "font_family", fontFamilyInput.text)
                }
            }
        }

        Settings.SettingRow {
            id: fontSizeRow
            label: "Font Size"
            tableHeader: "theme"
            settingKey: "font_size"
            defaultValue: Config.defaults.theme.font_size
            showOverriddenOnly: root.showOverriddenOnly

            Row {
                height: Theme.fontSize * 1.8
                spacing: Theme.fontSize / 3

                Rectangle {
                    width: height
                    height: parent.height
                    radius: Theme.radius / 2
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border
                    opacity: Config.data.theme.font_size <= root.minFontSize ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: Config.data.theme.font_size > root.minFontSize
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepFontSize(-1)
                    }
                }

                Rectangle {
                    width: Theme.fontSize * 3
                    height: parent.height
                    radius: Theme.radius / 2
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: Config.data.theme.font_size + "px"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                    }
                }

                Rectangle {
                    width: height
                    height: parent.height
                    radius: Theme.radius / 2
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border
                    opacity: Config.data.theme.font_size >= root.maxFontSize ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: Config.data.theme.font_size < root.maxFontSize
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepFontSize(1)
                    }
                }
            }
        }

        Settings.SettingRow {
            id: barPositionRow
            label: "Bar Position"
            tableHeader: "bar"
            settingKey: "position"
            defaultValue: Config.defaults.bar.position
            showOverriddenOnly: root.showOverriddenOnly

            Row {
                width: parent.width
                height: Theme.fontSize * 1.8
                spacing: Theme.fontSize / 3

                Repeater {
                    model: [
                        { value: "top", label: "Top" },
                        { value: "bottom", label: "Bottom" }
                    ]
                    delegate: Rectangle {
                        id: barPositionOption
                        required property var modelData

                        width: (parent.width - (Theme.fontSize / 3)) / 2
                        height: parent.height
                        radius: Theme.radius / 2
                        color: Config.data.bar.position === modelData.value ? Theme.accent : Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: barPositionOption.modelData.label
                            color: Config.data.bar.position === barPositionOption.modelData.value ? Theme.background : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.85
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.setValue("bar", "position", barPositionOption.modelData.value)
                        }
                    }
                }
            }
        }
    }
}
