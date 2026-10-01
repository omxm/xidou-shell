import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// System > Input (ROADMAP L16). Backed by services/InputSettings.qml, which
// applies the value with xinput at shell start and on every change.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        dwtRow.reset();
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: dwtRow
            label: "Disable While Typing"
            tableHeader: "input.touchpad"
            settingKey: "disable_while_typing"
            defaultValue: Config.defaults.input.touchpad.disable_while_typing
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: true, label: "On" },
                    { value: false, label: "Off" }
                ]
                currentValue: Config.data.input.touchpad.disable_while_typing
                onOptionSelected: (value) => Config.setValue("input.touchpad", "disable_while_typing", value)
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Off: the touchpad keeps working while you type, so a resting palm may move the pointer. libinput's other palm detection still applies."
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.8
        }
    }
}
