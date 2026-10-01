import QtQuick
import "../config"
import "../services"

// A row of equal-width pill buttons, one active (Theme.accent) at a time --
// the shape Theme Mode/Palette Source/Bar Position each built ad hoc first;
// factored out once a 4th and 5th copy (Screenshot's boolean toggles) made
// the duplication obvious rather than speculative. Caller sets `width`
// (typically `parent.width` from within a SettingRow's control slot).
Row {
    id: root

    property var options: [] // [{value, label, disabled?}] -- a disabled option is dimmed and can't be picked
    property var currentValue: undefined
    // Override when a row packs enough options (or long enough labels) that
    // the default size would clip against the fixed-width equal split below
    // -- e.g. Bar > Capsules' 4-option Capsule Fill row ("Surface Alt"/
    // "Background" don't fit at the default size in a standard SettingRow's
    // 40%-width control slot). Left at the default everywhere else.
    property real labelFontSize: Theme.fontSize * 0.85

    // Sounds for picking true / false (lib/SoundMap.js operations). A row
    // whose On/Off means something other than a toggle overrides them, e.g.
    // a bar module's On/Off is adding/removing it.
    property string onSound: "toggle_on"
    property string offSound: "toggle_off"

    signal optionSelected(var value)

    height: Theme.fontSize * 1.8
    spacing: Theme.fontSize / 3

    Repeater {
        model: root.options
        delegate: Rectangle {
            id: optionDelegate
            required property var modelData

            width: (root.width - (root.options.length - 1) * root.spacing) / root.options.length
            height: parent.height
            radius: Theme.radius / 2
            color: root.currentValue === optionDelegate.modelData.value ? Theme.accent : Theme.surfaceAlt
            border.width: 1
            border.color: Theme.border
            opacity: optionDelegate.modelData.disabled ? 0.4 : 1

            Text {
                anchors.centerIn: parent
                width: parent.width - 4
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: optionDelegate.modelData.label
                color: root.currentValue === optionDelegate.modelData.value ? Theme.background : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: root.labelFontSize
            }

            MouseArea {
                anchors.fill: parent
                enabled: !optionDelegate.modelData.disabled
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var v = optionDelegate.modelData.value;
                    if (v !== root.currentValue)
                        SoundFx.play(v === true ? root.onSound : v === false ? root.offSound : "option_select");
                    root.optionSelected(v);
                }
            }
        }
    }
}
