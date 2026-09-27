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
// untouched. On: append to the end of its *default* section's array -- this
// never tries to restore an exact prior position, there being no memory of
// what that was once a module's been toggled off.
//
// Each row also gets a gear icon opening a per-widget detail panel, whose
// Start/Center/End buttons move a module BETWEEN lanes (modules_left/
// center/right array surgery, same as enableModule/disableModule). Real
// per-widget content (Weather's max length/show-condition, etc.) lives here
// too, gated per-widget on whether the underlying value has real backing.
//
// In-lane reordering (moveWithinLane/canMoveWithinLane below) is a separate
// axis from that Start/Center/End move: up/down arrow buttons per row, not
// drag-and-drop -- QML's Drag/DropArea combo is real work (drop-target
// hit-testing, autoscroll, a ghost/placeholder row) for a benefit this list
// doesn't need, since the flat catalog above isn't even displayed grouped by
// lane. A swap-with-neighbor button pair is a two-line Config.setValue and
// reuses the exact same array-surgery pattern moveModuleToSection already
// established.
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

    // Reordering WITHIN a lane -- distinct from moveModuleToSection above
    // (which moves a module BETWEEN lanes, always appending at the target
    // lane's end). This swaps a module with its immediate neighbor inside
    // its own current lane's array, which is the only thing that actually
    // controls render order (moduleList above is a fixed catalog, not
    // display order -- the flat list UI doesn't visually group by lane, so
    // these buttons operate on the underlying array directly rather than on
    // list-adjacent rows, which may belong to a different lane entirely).
    function canMoveWithinLane(name, delta) {
        var section = root.currentSectionOf(name);
        if (!section)
            return false;
        var arr = Config.data.bar[section];
        var idx = arr.indexOf(name);
        var newIdx = idx + delta;
        return newIdx >= 0 && newIdx < arr.length;
    }

    function moveWithinLane(name, delta) {
        var section = root.currentSectionOf(name);
        if (!section)
            return;
        var arr = Config.data.bar[section].slice();
        var idx = arr.indexOf(name);
        var newIdx = idx + delta;
        if (newIdx < 0 || newIdx >= arr.length)
            return;
        var tmp = arr[idx];
        arr[idx] = arr[newIdx];
        arr[newIdx] = tmp;
        Config.setValue("bar", section, arr);
    }

    // Deliberately not "call reset() on every row" -- a module's own
    // customOverridden only tracks enabled-vs-disabled, not its exact
    // position, so a module that was toggled off and back on again already
    // reads as "not overridden" (it's enabled) even though it's now at the
    // end of its section instead of its original slot. The up/down arrows
    // can fix a single module's position by hand, but Reset Page still
    // restores all three arrays to their exact defaults outright in one
    // shot, which is the simpler move when several modules have drifted.
    function resetAll() {
        root.sectionKeys.forEach(function (key) {
            Config.setValue("bar", key, Config.defaults.bar[key]);
        });
    }

    // Which module's detail panel is open, by name -- "" means the plain
    // list is showing. Deliberately not wired to resetAll(): Reset Page
    // has no reason to also back out of an open detail panel.
    property string editingModule: ""

    function labelFor(name) {
        var entry = root.moduleList.find(function (m) { return m.name === name; });
        return entry ? entry.label : name;
    }

    // Names not in any of the three lane arrays, in moduleList's fixed
    // catalog order -- shown in their own "Disabled" section below the
    // three lanes so a toggled-off widget doesn't just disappear with no
    // way back short of remembering its name.
    readonly property var disabledModules: root.moduleList
        .map(function (m) { return m.name; })
        .filter(function (name) { return !root.isEnabled(name); })

    // One row's markup, reused by both the three lane Repeaters and the
    // Disabled section's Repeater below -- modelData is the module's name
    // string either way (a lane's own Config.data.bar[key] array, or
    // root.disabledModules).
    Component {
        id: moduleRowComponent

        Row {
            id: moduleRowWrapper
            required property string modelData

            width: parent.width
            height: moduleRow.height
            spacing: Theme.fontSize / 2

            Settings.SettingRow {
                id: moduleRow
                width: parent.width - reorderButtons.width - gearButton.width - parent.spacing * 2
                label: root.labelFor(moduleRowWrapper.modelData)
                showOverriddenOnly: root.showOverriddenOnly
                customOverridden: !root.isEnabled(moduleRowWrapper.modelData)
                customReset: function () {
                    root.enableModule(moduleRowWrapper.modelData);
                }

                Settings.OptionRow {
                    width: parent.width
                    options: [
                        { value: true, label: "On" },
                        { value: false, label: "Off" }
                    ]
                    currentValue: root.isEnabled(moduleRowWrapper.modelData)
                    onOptionSelected: (value) => {
                        if (value)
                            root.enableModule(moduleRowWrapper.modelData);
                        else
                            root.disableModule(moduleRowWrapper.modelData);
                    }
                }
            }

            Column {
                id: reorderButtons
                anchors.verticalCenter: moduleRow.verticalCenter
                visible: moduleRow.visible
                spacing: 1

                Rectangle {
                    width: Theme.fontSize * 1.8
                    height: Theme.fontSize * 0.9
                    radius: Theme.radius / 3
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border
                    opacity: root.canMoveWithinLane(moduleRowWrapper.modelData, -1) ? 1 : 0.4

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Theme.textMuted
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fontSize * 0.8
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.canMoveWithinLane(moduleRowWrapper.modelData, -1)
                        onClicked: root.moveWithinLane(moduleRowWrapper.modelData, -1)
                    }
                }

                Rectangle {
                    width: Theme.fontSize * 1.8
                    height: Theme.fontSize * 0.9
                    radius: Theme.radius / 3
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border
                    opacity: root.canMoveWithinLane(moduleRowWrapper.modelData, 1) ? 1 : 0.4

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Theme.textMuted
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fontSize * 0.8
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.canMoveWithinLane(moduleRowWrapper.modelData, 1)
                        onClicked: root.moveWithinLane(moduleRowWrapper.modelData, 1)
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
                    onClicked: root.editingModule = moduleRowWrapper.modelData
                }
            }
        }
    }

    // One boxed header + its Repeater, reused per lane -- a separate
    // Rectangle per section (not one shared header row) so each lane reads
    // as its own visually distinct group, matching the boxed-per-lane shape
    // of the Noctalia reference screenshots はる pointed to, rather than the
    // single flat list this replaced (which gave no visual indication at
    // all of which lane a module was actually in).
    Component {
        id: laneSectionComponent

        Column {
            id: laneSection
            required property string modelData

            width: parent.width
            spacing: Theme.fontSize / 2

            Rectangle {
                width: parent.width
                height: Theme.fontSize * 1.8
                radius: Theme.radius / 2
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.fontSize / 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sectionLabels[laneSection.modelData]
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.95
                    font.bold: true
                }
            }

            Column {
                // Column.leftPadding shifts children's x without shrinking
                // the width they measure themselves against -- each row
                // below still computes its own width from *this* Column's
                // width, so padding alone pushed every row's right edge
                // (arrows + gear) past the lane box's border by leftPadding
                // pixels. An explicit x/width inset keeps rows' actual
                // available width in sync with where they're drawn.
                x: Theme.fontSize / 2
                width: parent.width - Theme.fontSize / 2
                spacing: Theme.fontSize / 2

                Repeater {
                    model: Config.data.bar[laneSection.modelData]
                    delegate: moduleRowComponent
                }

                Text {
                    visible: Config.data.bar[laneSection.modelData].length === 0
                    text: "No widgets in this lane"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.italic: true
                    font.pixelSize: Theme.fontSize * 0.9
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: outerColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: root.editingModule === ""

        Column {
            id: outerColumn
            width: parent.width
            spacing: Theme.fontSize

            Repeater {
                model: root.sectionKeys
                delegate: laneSectionComponent
            }

            Column {
                width: outerColumn.width
                spacing: Theme.fontSize / 2
                visible: root.disabledModules.length > 0

                Rectangle {
                    width: parent.width
                    height: Theme.fontSize * 1.8
                    radius: Theme.radius / 2
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.fontSize / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Disabled"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.95
                        font.bold: true
                    }
                }

                Column {
                    // Same x/width inset as the lane sections above, same
                    // reason -- leftPadding alone overflows the box.
                    x: Theme.fontSize / 2
                    width: parent.width - Theme.fontSize / 2
                    spacing: Theme.fontSize / 2

                    Repeater {
                        model: root.disabledModules
                        delegate: moduleRowComponent
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
            "media": mediaWidgetComponent,
            "volume": volumeWidgetComponent,
            "bluetooth": bluetoothWidgetComponent,
            "tray": trayWidgetComponent,
            "mem": memWidgetComponent,
            "cpu": cpuWidgetComponent,
            "power": powerWidgetComponent
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

        // Volume's real "Widget" section: show_percentage under
        // [bar_widgets.volume] -- toggles the numeric label next to the
        // mute-state icon bar/modules/Volume.qml already renders.
        Component {
            id: volumeWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    width: parent.width
                    label: "Show Percentage"
                    tableHeader: "bar_widgets.volume"
                    settingKey: "show_percentage"
                    defaultValue: Config.defaults.bar_widgets.volume.show_percentage
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.volume.show_percentage
                        onOptionSelected: (value) => Config.setValue("bar_widgets.volume", "show_percentage", value)
                    }
                }
            }
        }

        // Bluetooth's real "Widget" section: show_device_count under
        // [bar_widgets.bluetooth] -- same "icon only" pattern as Volume.
        Component {
            id: bluetoothWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    width: parent.width
                    label: "Show Device Count"
                    tableHeader: "bar_widgets.bluetooth"
                    settingKey: "show_device_count"
                    defaultValue: Config.defaults.bar_widgets.bluetooth.show_device_count
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.bluetooth.show_device_count
                        onOptionSelected: (value) => Config.setValue("bar_widgets.bluetooth", "show_device_count", value)
                    }
                }
            }
        }

        // Tray's real "Widget" section: icon_size under [bar_widgets.tray]
        // -- 0 keeps bar/modules/Tray.qml's existing Theme.fontSize + 4
        // default, any other value overrides it directly.
        Component {
            id: trayWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    width: parent.width
                    label: "Icon Size"
                    tableHeader: "bar_widgets.tray"
                    settingKey: "icon_size"
                    defaultValue: Config.defaults.bar_widgets.tray.icon_size
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.NumberStepper {
                        value: Config.data.bar_widgets.tray.icon_size
                        minValue: 0
                        maxValue: 48
                        onStepped: (newValue) => Config.setValue("bar_widgets.tray", "icon_size", newValue)
                    }
                }
            }
        }

        // Mem's real "Widget" section: warning_threshold under
        // [bar_widgets.mem] -- recolors the widget to Theme.warning once
        // usedPercent reaches this, a real behavior change bar/modules/
        // Mem.qml's own `warning` property now drives.
        Component {
            id: memWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    width: parent.width
                    label: "Warning Threshold"
                    tableHeader: "bar_widgets.mem"
                    settingKey: "warning_threshold"
                    defaultValue: Config.defaults.bar_widgets.mem.warning_threshold
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.NumberStepper {
                        value: Config.data.bar_widgets.mem.warning_threshold
                        minValue: 0
                        maxValue: 100
                        onStepped: (newValue) => Config.setValue("bar_widgets.mem", "warning_threshold", newValue)
                    }
                }
            }
        }

        // CPU's real "Widget" section: warning_threshold under
        // [bar_widgets.cpu] -- same pattern as Mem above.
        Component {
            id: cpuWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    width: parent.width
                    label: "Warning Threshold"
                    tableHeader: "bar_widgets.cpu"
                    settingKey: "warning_threshold"
                    defaultValue: Config.defaults.bar_widgets.cpu.warning_threshold
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.NumberStepper {
                        value: Config.data.bar_widgets.cpu.warning_threshold
                        minValue: 0
                        maxValue: 100
                        onStepped: (newValue) => Config.setValue("bar_widgets.cpu", "warning_threshold", newValue)
                    }
                }
            }
        }

        // Power's real "Widget" section: show_percentage/
        // low_battery_threshold under [bar_widgets.power] -- the threshold
        // exposes a value bar/modules/Power.qml already hardcoded (20),
        // same "make an existing hardcoded behavior configurable" precedent
        // as Clock's time_format.
        Component {
            id: powerWidgetComponent
            Column {
                spacing: Theme.fontSize / 2

                Settings.SettingRow {
                    width: parent.width
                    label: "Show Percentage"
                    tableHeader: "bar_widgets.power"
                    settingKey: "show_percentage"
                    defaultValue: Config.defaults.bar_widgets.power.show_percentage
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.OptionRow {
                        width: parent.width
                        options: [
                            { value: true, label: "On" },
                            { value: false, label: "Off" }
                        ]
                        currentValue: Config.data.bar_widgets.power.show_percentage
                        onOptionSelected: (value) => Config.setValue("bar_widgets.power", "show_percentage", value)
                    }
                }

                Settings.SettingRow {
                    width: parent.width
                    label: "Low Battery Threshold"
                    tableHeader: "bar_widgets.power"
                    settingKey: "low_battery_threshold"
                    defaultValue: Config.defaults.bar_widgets.power.low_battery_threshold
                    showOverriddenOnly: root.showOverriddenOnly

                    Settings.NumberStepper {
                        value: Config.data.bar_widgets.power.low_battery_threshold
                        minValue: 0
                        maxValue: 100
                        onStepped: (newValue) => Config.setValue("bar_widgets.power", "low_battery_threshold", newValue)
                    }
                }
            }
        }
    }
}
