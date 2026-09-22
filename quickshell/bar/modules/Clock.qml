import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"

// Time display + [bar_widgets.clock] overrides (time_format, timezone) --
// distinct from any shared [clock]-style table since nothing else in the
// shell shows a clock that would need to agree with this one (unlike
// Weather's location, which control-center's own cards also consume).
//
// Two entirely different code paths depending on whether a timezone
// override is set, since SystemClock (Quickshell's own reactive clock
// primitive) has no timezone concept at all -- confirmed against its real
// qmltypes (only enabled/precision/date/hours/minutes/seconds, no
// timeZone property) -- and QML's JS engine here has no Intl support
// either, confirmed empirically (`new Intl.DateTimeFormat(...)` throws
// "Intl is not defined" when actually run against this Qt build, not
// assumed from general JS availability). So an arbitrary IANA zone can
// only be resolved by shelling out to the real `date` binary with TZ set
// via Process.environment -- the same "shell out to a real tool instead of
// reimplementing it" convention as matugen/maim/xclip elsewhere in this
// codebase. The system-local case (the common one) stays on SystemClock,
// zero extra process overhead, since it doesn't need any of that.
Item {
    id: root

    readonly property var cfg: Config.data.bar_widgets.clock
    readonly property bool useSystemTz: cfg.timezone === ""
    readonly property string dateFormatFlag: cfg.time_format === "12h" ? "%I:%M %p" : "%H:%M"
    readonly property string localFormatString: cfg.time_format === "12h" ? "hh:mm AP" : "HH:mm"

    property string tzLabel: ""

    implicitWidth: label.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    SystemClock {
        id: clock
        enabled: root.useSystemTz
        precision: SystemClock.Minutes
    }

    Process {
        id: tzDate
        environment: ({ "TZ": root.cfg.timezone })
        command: ["date", "+" + root.dateFormatFlag]
        stdout: StdioCollector {
            onStreamFinished: root.tzLabel = text.trim()
        }
    }

    // 15s poll rather than trying to align to the exact minute boundary --
    // this is a display convenience, not a precision timer, and the extra
    // complexity of computing "ms until next minute" isn't worth it for a
    // clock that only ever shows minute resolution anyway.
    Timer {
        running: !root.useSystemTz
        triggeredOnStart: true
        interval: 15000
        repeat: true
        onTriggered: {
            tzDate.running = false;
            tzDate.running = true;
        }
    }

    // Changing the timezone string or format while already in override
    // mode has no false->true `running` transition on the Timer above to
    // hang an immediate refresh off of (per this codebase's own
    // Timer.start()-is-a-no-op-when-already-running lesson -- see
    // Weather.qml's triggerForecastFetch), so force one directly instead
    // of waiting up to 15s for the next poll to pick up the new value.
    Connections {
        target: Config
        function onReloaded() {
            if (!root.useSystemTz) {
                tzDate.running = false;
                tzDate.running = true;
            }
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.useSystemTz ? clock.date.toLocaleTimeString(Qt.locale(), root.localFormatString) : root.tzLabel
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
