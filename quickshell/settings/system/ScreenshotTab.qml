import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// System > Screenshot (moved from the old top-level Screenshot category,
// ROADMAP M22): the four behavior toggles and the save directory
// that services/Screenshot.qml already implemented -- they were hardcoded
// sensible defaults before config.toml's [screenshot] table and
// Screenshot.qml's own Config.data.screenshot.* bindings existed (both
// added alongside this tab), not something invented here. Every one of
// these is read live by Screenshot.qml, so a change here takes effect on
// the very next screenshot, no restart needed.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        freezeRow.reset();
        confirmRow.reset();
        rememberRow.reset();
        cursorRow.reset();
        saveDirRow.reset();
        saveFileRow.reset();
        copyRow.reset();
    }

    // L3: at least one of Save to File / Copy to Clipboard stays on, so
    // the Off of whichever is the last one on is greyed out.
    readonly property bool saveOn: Config.data.screenshot.save_to_file
    readonly property bool copyOn: Config.data.screenshot.copy_to_clipboard

    readonly property var onOffOptions: [
        { value: true, label: "On" },
        { value: false, label: "Off" }
    ]

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: freezeRow
            label: "Freeze During Selection"
            tableHeader: "screenshot"
            settingKey: "freeze_during_selection"
            defaultValue: Config.defaults.screenshot.freeze_during_selection
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: root.onOffOptions
                currentValue: Config.data.screenshot.freeze_during_selection
                onOptionSelected: (value) => Config.setValue("screenshot", "freeze_during_selection", value)
            }
        }

        Settings.SettingRow {
            id: confirmRow
            label: "Confirm Selection"
            tableHeader: "screenshot"
            settingKey: "confirm_selection"
            defaultValue: Config.defaults.screenshot.confirm_selection
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: root.onOffOptions
                currentValue: Config.data.screenshot.confirm_selection
                onOptionSelected: (value) => Config.setValue("screenshot", "confirm_selection", value)
            }
        }

        Settings.SettingRow {
            id: rememberRow
            label: "Remember Last Region"
            tableHeader: "screenshot"
            settingKey: "remember_last_region"
            defaultValue: Config.defaults.screenshot.remember_last_region
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: root.onOffOptions
                currentValue: Config.data.screenshot.remember_last_region
                onOptionSelected: (value) => Config.setValue("screenshot", "remember_last_region", value)
            }
        }

        Settings.SettingRow {
            id: cursorRow
            label: "Include Mouse Pointer"
            tableHeader: "screenshot"
            settingKey: "include_cursor"
            defaultValue: Config.defaults.screenshot.include_cursor
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: root.onOffOptions
                currentValue: Config.data.screenshot.include_cursor
                onOptionSelected: (value) => Config.setValue("screenshot", "include_cursor", value)
            }
        }

        Settings.SettingRow {
            id: saveFileRow
            label: "Save to File"
            tableHeader: "screenshot"
            settingKey: "save_to_file"
            defaultValue: Config.defaults.screenshot.save_to_file
            showOverriddenOnly: root.showOverriddenOnly
            // Resetting turns it back on, which is always allowed.

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: true, label: "On" },
                    { value: false, label: "Off", disabled: !root.copyOn }
                ]
                currentValue: root.saveOn
                onOptionSelected: (value) => Config.setValue("screenshot", "save_to_file", value)
            }
        }

        Settings.SettingRow {
            id: copyRow
            label: "Copy to Clipboard"
            tableHeader: "screenshot"
            settingKey: "copy_to_clipboard"
            defaultValue: Config.defaults.screenshot.copy_to_clipboard
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: true, label: "On" },
                    { value: false, label: "Off", disabled: !root.saveOn }
                ]
                currentValue: root.copyOn
                onOptionSelected: (value) => Config.setValue("screenshot", "copy_to_clipboard", value)
            }
        }

        Settings.SettingRow {
            id: saveDirRow
            label: "Save Directory"
            tableHeader: "screenshot"
            settingKey: "save_directory"
            defaultValue: Config.defaults.screenshot.save_directory
            showOverriddenOnly: root.showOverriddenOnly

            Settings.TextCommitField {
                width: parent.width
                value: Config.data.screenshot.save_directory
                placeholder: "~/Pictures/Screenshots"
                onCommitted: (text) => Config.setValue("screenshot", "save_directory", text)
            }
        }
    }
}
