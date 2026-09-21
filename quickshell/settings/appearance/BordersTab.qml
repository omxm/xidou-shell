import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Appearance > Borders: Corner Radius (theme.radius, used by every rounded
// panel/card/button in the shell -- 23+ call sites) and Border Color
// (theme.border, the border.color on most of those same elements -- 21+
// call sites). Both are real, pervasively-used values, unlike
// Accessibility/Motion/Effects (see InterfaceTab.qml's header comment for
// why those have nothing to wire up yet).
//
// Border Color needs an actual hex-input control -- unlike every other
// control built so far (Theme Mode, Palette Source, Bar Position: a fixed
// set of options; Font Size/Corner Radius: a numeric stepper), a color has
// no existing widget shape anywhere in this codebase to reuse, so this is
// a small new one: a text field validated against real hex syntax before
// it's ever written, plus a live swatch so a typo or a bad value is
// obviously wrong before it's committed rather than after.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        radiusRow.reset();
        borderColorRow.reset();
    }

    readonly property int minRadius: 0
    readonly property int maxRadius: 24

    function stepRadius(delta) {
        var next = Config.data.theme.radius + delta;
        next = Math.max(root.minRadius, Math.min(root.maxRadius, next));
        Config.setValue("theme", "radius", next);
    }

    readonly property var hexColorPattern: /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: radiusRow
            label: "Corner Radius"
            tableHeader: "theme"
            settingKey: "radius"
            defaultValue: Config.defaults.theme.radius
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
                    opacity: Config.data.theme.radius <= root.minRadius ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: Config.data.theme.radius > root.minRadius
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepRadius(-1)
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
                        text: Config.data.theme.radius + "px"
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
                    opacity: Config.data.theme.radius >= root.maxRadius ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: Config.data.theme.radius < root.maxRadius
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepRadius(1)
                    }
                }
            }
        }

        Settings.SettingRow {
            id: borderColorRow
            label: "Border Color"
            tableHeader: "theme"
            settingKey: "border"
            defaultValue: Config.defaults.theme.border
            showOverriddenOnly: root.showOverriddenOnly

            Row {
                width: parent.width
                height: Theme.fontSize * 1.8
                spacing: Theme.fontSize / 3

                Rectangle {
                    id: colorSwatch
                    width: height
                    height: parent.height
                    radius: Theme.radius / 2
                    color: Config.data.theme.border
                    border.width: 1
                    border.color: Theme.text
                }

                Rectangle {
                    width: Theme.fontSize * 8
                    height: parent.height
                    radius: Theme.radius / 2
                    color: Theme.surfaceAlt
                    // Red border signals invalid input before it's ever
                    // written -- Config.setValue() only ever gets called
                    // with syntax already confirmed valid below, so a typo
                    // is obviously wrong right where it was typed rather
                    // than silently ignored or corrupting the theme.
                    //
                    // Deliberately no `validator:` here -- QRegularExpression-
                    // Validator blocks a keystroke outright whenever it can
                    // never lead to a match, which for a pattern requiring a
                    // leading "#" means typing a plain "3a3a3a" (a very
                    // natural typo: forgetting the #) would silently reject
                    // every character with no feedback at all. Free typing
                    // plus this same regex used only for the border color
                    // and the commit-or-revert logic below gives the same
                    // safety without that dead-keystroke trap.
                    border.width: 1
                    border.color: root.hexColorPattern.test(borderColorInput.text) ? Theme.border : "#e05a5a"

                    TextInput {
                        id: borderColorInput
                        anchors.fill: parent
                        anchors.margins: Theme.fontSize / 2
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                        clip: true

                        // Same explicit-resync approach as InterfaceTab's
                        // Font Family field, for the same reason: a live
                        // `text:` binding would be severed by the user's
                        // first keystroke and never reflect an external
                        // Reset again.
                        function syncFromConfig() {
                            if (!borderColorInput.activeFocus)
                                borderColorInput.text = Config.data.theme.border;
                        }

                        Component.onCompleted: syncFromConfig()

                        Connections {
                            target: Config
                            function onReloaded() {
                                borderColorInput.syncFromConfig();
                            }
                        }

                        Keys.onReturnPressed: borderColorInput.focus = false
                        Keys.onEnterPressed: borderColorInput.focus = false
                        onEditingFinished: {
                            if (root.hexColorPattern.test(borderColorInput.text))
                                Config.setValue("theme", "border", borderColorInput.text);
                            else
                                borderColorInput.syncFromConfig(); // discard the bad input, revert to the real value
                        }
                    }
                }
            }
        }
    }
}
