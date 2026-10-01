pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Applies [input.touchpad] (ROADMAP L16) to the X server with xinput, at
// shell start and whenever the setting changes.
//
// Devices are found by property, never by name -- same rule as
// session/xorg/90-xidou-touchpad.conf: every device listing libinput's
// "Disable While Typing Enabled" property gets the new value. On the X1CG5
// that is the Synaptics TM3289-002 clickpad. Natural scrolling stays in the
// xorg.conf.d file for now.
Singleton {
    id: root

    readonly property bool disableWhileTyping: Config.data.input.touchpad.disable_while_typing
    readonly property string dwtProperty: "libinput Disable While Typing Enabled"

    // The script, separate so it can be checked against a fake xinput
    // without touching a real device. $1 is 0 or 1. Prints one line per
    // device it set, "set <id> <value>".
    readonly property string applyScript: '
        prop="$2"
        for id in $(xinput list --id-only); do
            if xinput list-props "$id" 2>/dev/null | grep -q "^[[:space:]]*$prop ("; then
                xinput set-prop "$id" "$prop" "$1" && echo "set $id $1"
            fi
        done'

    function apply() {
        if (!Config.ready)
            return;
        applyProc.command = ["sh", "-c", root.applyScript, "xidou-input", root.disableWhileTyping ? "1" : "0", root.dwtProperty];
        applyProc.running = false;
        applyProc.running = true;
    }

    onDisableWhileTypingChanged: root.apply()

    Connections {
        target: Config
        function onReadyChanged() {
            root.apply();
        }
    }

    Component.onCompleted: root.apply()

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.log("[xidou] InputSettings: " + text.trim().split("\n").join(", "));
            }
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                console.warn("[xidou] InputSettings: xinput exited " + exitCode);
        }
    }
}
