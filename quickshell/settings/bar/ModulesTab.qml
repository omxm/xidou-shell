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
//
// Each row also gets a gear icon opening a per-widget detail panel
// (Stage 2 of the Bar overhaul, structure only -- real per-widget content
// like Weather's max length/show-condition is Stage 3, once this
// scaffolding exists). The panel's Start/Center/End buttons ARE real
// already, unlike the rest of its body: moving a module between sections
// is just the same modules_left/center/right array surgery enableModule/
// disableModule already do, so there's no reason to fake that part.
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
    readonly property var sectionLabels: ({
        "modules_left": "Start",
        "modules_center": "Center",
        "modules_right": "End"
    })

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

    // Unlike defaultSectionOf, this is the module's real, current section
    // -- null when it's off (in none of the three arrays), since "which
    // section" has no meaning for a hidden module.
    function currentSectionOf(name) {
        for (var i = 0; i < root.sectionKeys.length; i++) {
            if (Config.data.bar[root.sectionKeys[i]].indexOf(name) !== -1)
                return root.sectionKeys[i];
        }
        return null;
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

    // Moves (and, as a side effect, enables) a module straight into
    // targetKey's array, appended at the end -- removing it from wherever
    // it currently sits first. "Put this widget at Start" is a reasonable
    // thing to ask for a currently-off widget too, so this doesn't require
    // isEnabled() first the way the plain On/Off toggle's semantics do.
    function moveModuleToSection(name, targetKey) {
        root.sectionKeys.forEach(function (key) {
            var arr = Config.data.bar[key];
            if (arr.indexOf(name) !== -1)
                Config.setValue("bar", key, arr.filter(function (n) { return n !== name; }));
        });
        Config.setValue("bar", targetKey, Config.data.bar[targetKey].concat([name]));
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

    // Which module's detail panel is open, by name -- "" means the plain
    // list is showing. Deliberately not wired to resetAll(): Reset Page
    // has no reason to also back out of an open detail panel.
    property string editingModule: ""

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: moduleColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: root.editingModule === ""

        Column {
            id: moduleColumn
            width: parent.width
            spacing: Theme.fontSize / 2

            Repeater {
                id: moduleRepeater
                model: root.moduleList

                delegate: Row {
                    id: moduleRowWrapper
                    required property var modelData

                    width: moduleColumn.width
                    height: moduleRow.height
                    spacing: Theme.fontSize / 2

                    Settings.SettingRow {
                        id: moduleRow
                        width: parent.width - gearButton.width - parent.spacing
                        label: moduleRowWrapper.modelData.label
                        showOverriddenOnly: root.showOverriddenOnly
                        customOverridden: !root.isEnabled(moduleRowWrapper.modelData.name)
                        customReset: function () {
                            root.enableModule(moduleRowWrapper.modelData.name);
                        }

                        Settings.OptionRow {
                            width: parent.width
                            options: [
                                { value: true, label: "On" },
                                { value: false, label: "Off" }
                            ]
                            currentValue: root.isEnabled(moduleRowWrapper.modelData.name)
                            onOptionSelected: (value) => {
                                if (value)
                                    root.enableModule(moduleRowWrapper.modelData.name);
                                else
                                    root.disableModule(moduleRowWrapper.modelData.name);
                            }
                        }
                    }

                    Rectangle {
                        id: gearButton
                        width: Theme.fontSize * 1.8
                        height: Theme.fontSize * 1.8
                        anchors.verticalCenter: moduleRow.verticalCenter
                        visible: moduleRow.visible
                        radius: Theme.radius / 2
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: Theme.textMuted
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editingModule = moduleRowWrapper.modelData.name
                        }
                    }
                }
            }
        }
    }

    // Per-widget detail panel -- structure only for now (header + real
    // Start/Center/End controls). Real per-widget content (Weather's max
    // length, show-condition, etc.) is Stage 3, gated on which values
    // already have backing to control, same rule as every category so far.
    Column {
        anchors.fill: parent
        spacing: Theme.fontSize
        visible: root.editingModule !== ""

        readonly property var moduleEntry: root.moduleList.find(function (m) {
            return m.name === root.editingModule;
        }) || { name: "", label: "" }

        Row {
            width: parent.width
            height: Theme.fontSize * 1.8
            spacing: Theme.fontSize / 2

            Rectangle {
                width: Theme.fontSize * 1.8
                height: Theme.fontSize * 1.8
                radius: Theme.radius / 2
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Theme.text
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editingModule = ""
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.moduleEntry.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 1.1
                font.bold: true
            }
        }

        Settings.SettingRow {
            id: positionRow
            width: parent.width
            label: "Position"
            customOverridden: root.currentSectionOf(parent.moduleEntry.name) !== root.defaultSectionOf[parent.moduleEntry.name]
            customReset: function () {
                var section = root.defaultSectionOf[parent.moduleEntry.name];
                if (section)
                    root.moveModuleToSection(parent.moduleEntry.name, section);
            }

            Row {
                width: parent.width
                spacing: Theme.fontSize / 2

                Repeater {
                    model: root.sectionKeys

                    delegate: Rectangle {
                        id: sectionButton
                        required property string modelData

                        readonly property bool current: root.currentSectionOf(positionRow.parent.moduleEntry.name) === modelData

                        width: Theme.fontSize * 6
                        height: Theme.fontSize * 1.8
                        radius: Theme.radius / 2
                        color: current ? Theme.accent : Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.fontSize / 3

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: sectionButton.modelData === "modules_left" ? "" : sectionButton.modelData === "modules_center" ? "" : ""
                                color: sectionButton.current ? Theme.background : Theme.textMuted
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fontSize * 0.9
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.sectionLabels[sectionButton.modelData]
                                color: sectionButton.current ? Theme.background : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.9
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.moveModuleToSection(positionRow.parent.moduleEntry.name, sectionButton.modelData)
                        }
                    }
                }
            }
        }

        // Widget-specific content -- real controls where the underlying
        // value already has backing, a PlaceholderTab fallback for every
        // other widget, same "fail soft to placeholder" convention as
        // Settings.qml's own tabComponents lookup. Map (not a growing
        // ternary chain) since this list only grows as more widgets get
        // real Stage-3 sections.
        readonly property var widgetComponentsByName: ({
            "weather": weatherWidgetComponent,
            "clock": clockWidgetComponent,
            "workspaces": workspacesWidgetComponent,
            "media": mediaWidgetComponent
        })

        Loader {
            width: parent.width
            height: parent.height - (Theme.fontSize * 1.8) - (Theme.fontSize * 2.6) - (parent.spacing * 2)
            sourceComponent: parent.widgetComponentsByName[root.editingModule] || placeholderWidgetComponent
        }

        Component {
            id: placeholderWidgetComponent
            Settings.PlaceholderTab {
                // Falls back to {label: ""} for editingModule === "" -- the
                // Loader above is unconditionally live even while this
                // Column is invisible (visible:false only hides rendering,
                // it doesn't stop a sibling Loader's sourceComponent from
                // being instantiated and its bindings evaluated), so this
                // binding runs continuously whenever the plain widget list
                // is showing, not just while a real placeholder is visible.
                tabName: (root.moduleList.find(function (m) {
                    return m.name === root.editingModule;
                }) || { label: "" }).label + " widget settings"
            }
        }

        // Weather's real "Widget" section (Stage 3): max_length/
        // show_condition/show_temperature under [bar_widgets.weather] --
        // distinct from [weather] (location/units), since these only
        // affect how the *bar's* copy renders, per bar/modules/Weather.qml's
        // own "self-contained per-module" convention. show_condition wires
        // up a value (conditionText) that bar module already computed but
        // never displayed; the other two are genuinely new.
        Component {
            id: weatherWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    id: showTempRow
                    width: parent.width
                    label: "Show Temperature"
                    tableHeader: "bar_widgets.weather"
                    settingKey: "show_temperature"
                    defaultValue: Config.defaults.bar_widgets.weather.show_temperature
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.weather.show_temperature
                        onOptionSelected: (value) => Config.setValue("bar_widgets.weather", "show_temperature", value)
                    }
                }

                Settings.SettingRow {
                    id: showConditionRow
                    width: parent.width
                    label: "Show Condition"
                    tableHeader: "bar_widgets.weather"
                    settingKey: "show_condition"
                    defaultValue: Config.defaults.bar_widgets.weather.show_condition
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.weather.show_condition
                        onOptionSelected: (value) => Config.setValue("bar_widgets.weather", "show_condition", value)
                    }
                }

                Settings.SettingRow {
                    id: maxLengthRow
                    width: parent.width
                    label: "Max Length"
                    tableHeader: "bar_widgets.weather"
                    settingKey: "max_length"
                    defaultValue: Config.defaults.bar_widgets.weather.max_length
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.NumberStepper {
                        value: Config.data.bar_widgets.weather.max_length
                        minValue: 0
                        maxValue: 60
                        onStepped: (newValue) => Config.setValue("bar_widgets.weather", "max_length", newValue)
                    }
                }
            }
        }

        // Clock's real "Widget" section: time_format/timezone under
        // [bar_widgets.clock] -- both genuinely new (bar/modules/Clock.qml
        // previously hardcoded "HH:mm" with no timezone concept at all).
        // Timezone is free text (an IANA zone name, e.g. "America/
        // New_York"), same "no upfront validation against a real list"
        // precedent as Weather's City field -- an invalid zone just makes
        // the real `date` binary silently fall back to UTC (confirmed
        // empirically), which is an acceptable failure mode for a free-text
        // field, not something worth building zone-name validation for.
        Component {
            id: clockWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    id: timeFormatRow
                    width: parent.width
                    label: "Time Format"
                    tableHeader: "bar_widgets.clock"
                    settingKey: "time_format"
                    defaultValue: Config.defaults.bar_widgets.clock.time_format
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: "24h", label: "24-Hour" },
                            { value: "12h", label: "12-Hour" }
                        ]
                        currentValue: Config.data.bar_widgets.clock.time_format
                        onOptionSelected: (value) => Config.setValue("bar_widgets.clock", "time_format", value)
                    }
                }

                Settings.SettingRow {
                    id: timezoneRow
                    width: parent.width
                    label: "Timezone"
                    tableHeader: "bar_widgets.clock"
                    settingKey: "timezone"
                    defaultValue: Config.defaults.bar_widgets.clock.timezone
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.TextCommitField {
                        width: parent.width
                        value: Config.data.bar_widgets.clock.timezone
                        placeholder: "System default (e.g. America/New_York)"
                        onCommitted: (text) => Config.setValue("bar_widgets.clock", "timezone", text)
                    }
                }
            }
        }

        // Workspaces' real "Widget" section: hide_when_empty/style/
        // show_icons under [bar_widgets.workspaces]. Max Label Characters
        // (from the same Noctalia reference screenshots) is deliberately
        // NOT here -- confirmed against dwm/config.h that tags are always
        // plain numbers 1-9 with no naming concept in this repo, so there
        // is no "custom tag name" for a length cap to apply to.
        Component {
            id: workspacesWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    id: hideEmptyRow
                    width: parent.width
                    label: "Hide When Empty"
                    tableHeader: "bar_widgets.workspaces"
                    settingKey: "hide_when_empty"
                    defaultValue: Config.defaults.bar_widgets.workspaces.hide_when_empty
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.workspaces.hide_when_empty
                        onOptionSelected: (value) => Config.setValue("bar_widgets.workspaces", "hide_when_empty", value)
                    }
                }

                Settings.SettingRow {
                    id: styleRow
                    width: parent.width
                    label: "Style"
                    tableHeader: "bar_widgets.workspaces"
                    settingKey: "style"
                    defaultValue: Config.defaults.bar_widgets.workspaces.style
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: "regular", label: "Regular" },
                            { value: "minimal", label: "Minimal" },
                            { value: "focus_hint", label: "Focus Hint" }
                        ]
                        currentValue: Config.data.bar_widgets.workspaces.style
                        onOptionSelected: (value) => Config.setValue("bar_widgets.workspaces", "style", value)
                    }
                }

                Settings.SettingRow {
                    id: showIconsRow
                    width: parent.width
                    label: "Show Icons"
                    tableHeader: "bar_widgets.workspaces"
                    settingKey: "show_icons"
                    defaultValue: Config.defaults.bar_widgets.workspaces.show_icons
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.workspaces.show_icons
                        onOptionSelected: (value) => Config.setValue("bar_widgets.workspaces", "show_icons", value)
                    }
                }
            }
        }

        // Media's real "Widget" section: album_art_only/hide_artist/
        // artist_first under [bar_widgets.media] -- all three reuse MPRIS
        // data (trackArtUrl/trackTitle/trackArtist) bar/modules/Media.qml
        // already has access to, same as control-center's MediaSection.qml
        // independently does for its own art thumbnail.
        Component {
            id: mediaWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    id: albumArtOnlyRow
                    width: parent.width
                    label: "Album Art Only"
                    tableHeader: "bar_widgets.media"
                    settingKey: "album_art_only"
                    defaultValue: Config.defaults.bar_widgets.media.album_art_only
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.media.album_art_only
                        onOptionSelected: (value) => Config.setValue("bar_widgets.media", "album_art_only", value)
                    }
                }

                Settings.SettingRow {
                    id: hideArtistRow
                    width: parent.width
                    label: "Hide Artist"
                    tableHeader: "bar_widgets.media"
                    settingKey: "hide_artist"
                    defaultValue: Config.defaults.bar_widgets.media.hide_artist
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.media.hide_artist
                        onOptionSelected: (value) => Config.setValue("bar_widgets.media", "hide_artist", value)
                    }
                }

                Settings.SettingRow {
                    id: artistFirstRow
                    width: parent.width
                    label: "Artist First"
                    tableHeader: "bar_widgets.media"
                    settingKey: "artist_first"
                    defaultValue: Config.defaults.bar_widgets.media.artist_first
                    showOverriddenOnly: root.showOverriddenOnly

                    // Reordering has nothing to reorder once the artist is
                    // hidden -- dimmed and disabled rather than left
                    // editable with no visible effect, same
                    // "don't let the user edit a value that currently does
                    // nothing" call ThemeTab.qml made for Wallpaper
                    // Generation Scheme.
                    Settings.OptionRow {
                        width: parent.width
                        enabled: !Config.data.bar_widgets.media.hide_artist
                        opacity: enabled ? 1 : 0.5
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.media.artist_first
                        onOptionSelected: (value) => Config.setValue("bar_widgets.media", "artist_first", value)
                    }
                }
            }
        }
    }
}
