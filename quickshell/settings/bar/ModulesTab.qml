import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Bar > Modules: on/off per module, per はる's explicit scope call --
// membership in modules_left/modules_center/modules_right, nothing about
// order. Bar.qml has no per-module "enabled" flag; a module's visibility
// is purely "does its name string appear in one of the three arrays," so
// toggling isn't a plain Config.setValue(tableHeader, key, value) the way
// every other control so far has been -- SettingRow's customOverridden/
// customReset exist specifically for this.
//
// Off: remove the name from wherever it currently sits, whichever array
// that is, leaving everything else in that array (order included)
// untouched. On: append to the end of its *default* section's array --
// this never tries to restore an exact prior position, since reordering
// itself is explicitly out of scope this pass (drag-and-drop reordering
// is real future feature work, not something to fake here).
Item {
    id: root

    property bool showOverriddenOnly: false

    readonly property var moduleList: [
        { name: "logo", label: "Logo" },
        { name: "workspaces", label: "Workspaces" },
        { name: "media", label: "Media" },
        { name: "clock", label: "Clock" },
        { name: "weather", label: "Weather" },
        { name: "tray", label: "Tray" },
        { name: "mem", label: "Memory" },
        { name: "cpu", label: "CPU" },
        { name: "bluetooth", label: "Bluetooth" },
        { name: "volume", label: "Volume" },
        { name: "dnd", label: "Do Not Disturb" },
        { name: "power", label: "Power" }
    ]

    readonly property var sectionKeys: ["modules_left", "modules_center", "modules_right"]

    // Every module's own default section -- computed once from
    // Config.defaults.bar rather than hardcoded a second time here, so it
    // can never drift out of sync with the real defaults.
    readonly property var defaultSectionOf: {
        var map = {};
        root.sectionKeys.forEach(function (key) {
            (Config.defaults.bar[key] || []).forEach(function (name) {
                map[name] = key;
            });
        });
        return map;
    }

    function isEnabled(name) {
        return root.sectionKeys.some(function (key) {
            return Config.data.bar[key].indexOf(name) !== -1;
        });
    }

    function disableModule(name) {
        root.sectionKeys.forEach(function (key) {
            var arr = Config.data.bar[key];
            if (arr.indexOf(name) !== -1)
                Config.setValue("bar", key, arr.filter(function (n) { return n !== name; }));
        });
    }

    function enableModule(name) {
        if (root.isEnabled(name))
            return;
        var section = root.defaultSectionOf[name];
        if (!section)
            return;
        Config.setValue("bar", section, Config.data.bar[section].concat([name]));
    }

    // Deliberately not "call reset() on every row" -- a module's own
    // customOverridden only tracks enabled-vs-disabled, not its exact
    // position, so a module that was toggled off and back on again already
    // reads as "not overridden" (it's enabled) even though it's now at the
    // end of its section instead of its original slot. Reset Page instead
    // restores all three arrays to their exact defaults outright, the only
    // way to actually undo that positional drift without real reordering
    // UI to fix a single module's position in isolation.
    function resetAll() {
        root.sectionKeys.forEach(function (key) {
            Config.setValue("bar", key, Config.defaults.bar[key]);
        });
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: moduleColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: moduleColumn
            width: parent.width
            spacing: Theme.fontSize / 2

            Repeater {
                id: moduleRepeater
                model: root.moduleList

                delegate: Settings.SettingRow {
                    id: moduleRow
                    required property var modelData

                    width: moduleColumn.width
                    label: modelData.label
                    showOverriddenOnly: root.showOverriddenOnly
                    customOverridden: !root.isEnabled(modelData.name)
                    customReset: function () {
                        root.enableModule(modelData.name);
                    }

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: root.isEnabled(moduleRow.modelData.name)
                        onOptionSelected: (value) => {
                            if (value)
                                root.enableModule(moduleRow.modelData.name);
                            else
                                root.disableModule(moduleRow.modelData.name);
                        }
                    }
                }
            }
        }
    }
}
