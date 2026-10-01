import QtQuick
import "../../config"
import "../../services"
import "../../lib/SoundMap.js" as SoundMap
import "../../controlcenter" as ControlCenter
import ".." as Settings

// System > Sound (ROADMAP M22): one flat page. A Master row plus one row
// per category from lib/SoundMap.js, each with On/Off, a volume slider and
// a preview button that plays that category's most typical sound. Clicking
// a category's name opens a read-only "What plays here" list. Each row
// holds two values (enabled, volume), so it uses SettingRow's
// customOverridden/customReset instead of two rows per category.
//
// Volume is written on release, not on every drag step, and the preview
// plays at the new level.
Item {
    id: root

    property bool showOverriddenOnly: false

    readonly property var sound: Config.data.sound
    readonly property var soundDefaults: Config.defaults.sound
    readonly property var categories: SoundMap.CATEGORIES

    // Category id -> expanded, for the "What plays here" lists.
    property var expanded: ({})

    function toggleExpanded(id) {
        var next = Object.assign({}, root.expanded);
        next[id] = !next[id];
        root.expanded = next;
    }

    function roundVolume(v) {
        return Math.round(v * 100) / 100;
    }

    function isOverridden(table, current, defaults) {
        return current.enabled !== defaults.enabled
            || roundVolume(current.volume) !== roundVolume(defaults.volume)
            || (table !== "sound" && JSON.stringify(current.extra || []) !== JSON.stringify(defaults.extra || []));
    }

    function resetTable(table, defaults) {
        Config.setValue(table, "enabled", defaults.enabled);
        Config.setValue(table, "volume", defaults.volume);
        if (table !== "sound")
            Config.setValue(table, "extra", defaults.extra);
    }

    function resetAll() {
        root.resetTable("sound", root.soundDefaults);
        for (var i = 0; i < root.categories.length; i++) {
            var id = root.categories[i].id;
            if (root.isOverridden("sound." + id, root.sound[id], root.soundDefaults[id]))
                root.resetTable("sound." + id, root.soundDefaults[id]);
        }
    }

    readonly property var onOffOptions: [
        { value: true, label: "On" },
        { value: false, label: "Off" }
    ]

    // On/Off + volume slider + percent + preview, shared by every row.
    component SoundControls: Row {
        id: controls

        property string table: ""
        property var values: ({})
        property string previewOp: ""

        spacing: Theme.fontSize / 3

        Settings.OptionRow {
            id: onOff
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fontSize * 5.4
            labelFontSize: Theme.fontSize * 0.75
            options: root.onOffOptions
            currentValue: !!controls.values.enabled
            onOptionSelected: (value) => Config.setValue(controls.table, "enabled", value)
        }

        ControlCenter.VolumeSlider {
            id: slider
            anchors.verticalCenter: parent.verticalCenter
            width: controls.width - onOff.width - percent.width - preview.width - controls.spacing * 3
            enabled: !!controls.values.enabled
            step: 0.05
            value: Number(controls.values.volume)
            onReleased: (v) => {
                Config.setValue(controls.table, "volume", root.roundVolume(v));
                SoundFx.play(controls.previewOp);
            }
        }

        Text {
            id: percent
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fontSize * 2.6
            horizontalAlignment: Text.AlignRight
            text: Math.round(slider.shownValue * 100) + "%"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.8
        }

        Rectangle {
            id: preview
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fontSize * 1.6
            height: Theme.fontSize * 1.6
            radius: Theme.radius / 2
            color: Theme.surfaceAlt
            border.width: 1
            border.color: Theme.border
            opacity: controls.values.enabled ? 1 : 0.4

            Text {
                anchors.centerIn: parent
                text: "" // play_arrow (verified via fontTools)
                color: Theme.text
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSize
            }

            MouseArea {
                anchors.fill: parent
                enabled: !!controls.values.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: SoundFx.play(controls.previewOp)
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width
            spacing: Theme.fontSize / 4

            Settings.SettingRow {
                label: "Master"
                rowHeight: Theme.fontSize * 2.4
                showOverriddenOnly: root.showOverriddenOnly
                customOverridden: root.isOverridden("sound", root.sound, root.soundDefaults)
                customReset: function () {
                    root.resetTable("sound", root.soundDefaults);
                }

                SoundControls {
                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    table: "sound"
                    values: root.sound
                    previewOp: "panel_open"
                }
            }

            Repeater {
                model: root.categories

                delegate: Column {
                    id: categoryBlock
                    required property var modelData
                    readonly property string table: "sound." + modelData.id
                    readonly property var values: root.sound[modelData.id]
                    readonly property bool isOpen: !!root.expanded[modelData.id]

                    width: column.width
                    enabled: root.sound.enabled
                    opacity: enabled ? 1 : 0.5
                    visible: categoryRow.visible

                    Settings.SettingRow {
                        id: categoryRow
                        label: (categoryBlock.isOpen ? "▾ " : "▸ ") + categoryBlock.modelData.label
                        labelClickable: true
                        onLabelClicked: root.toggleExpanded(categoryBlock.modelData.id)
                        rowHeight: Theme.fontSize * 2.4
                        showOverriddenOnly: root.showOverriddenOnly
                        customOverridden: root.isOverridden(categoryBlock.table, categoryBlock.values, root.soundDefaults[categoryBlock.modelData.id])
                        customReset: function () {
                            root.resetTable(categoryBlock.table, root.soundDefaults[categoryBlock.modelData.id]);
                        }

                        SoundControls {
                            width: parent.width
                            anchors.verticalCenter: parent.verticalCenter
                            table: categoryBlock.table
                            values: categoryBlock.values
                            previewOp: categoryBlock.modelData.preview
                        }
                    }

                    // "What plays here": read-only. Operations that are
                    // off by default say so; they are turned on by adding
                    // their id to this category's `extra` in config.toml.
                    Column {
                        visible: categoryBlock.isOpen
                        width: parent.width
                        leftPadding: Theme.fontSize * 1.4
                        bottomPadding: Theme.fontSize / 3

                        Repeater {
                            model: SoundMap.opsIn(categoryBlock.modelData.id)

                            delegate: Text {
                                required property var modelData
                                readonly property bool extraOn: (categoryBlock.values.extra || []).indexOf(modelData.id) !== -1
                                text: "· " + modelData.label
                                    + (modelData.on ? "" : (extraOn ? "  (on via extra: " + modelData.id + ")" : "  (off by default; extra: " + modelData.id + ")"))
                                color: modelData.on || extraOn ? Theme.text : Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.8
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                topPadding: Theme.fontSize / 3
                text: "Do Not Disturb silences notification sounds only"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.8
            }
        }
    }
}
