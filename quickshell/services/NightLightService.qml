pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night Light toggle backing (Home tab quick-toggle) -- redshift's one-shot
// manual mode (`-O TEMP` / `-x`), not its continuous daemon mode. Checked
// what's actually available on this system before assuming a tool: neither
// redshift nor gammastep was installed (installed redshift here -- both
// are in the extra/world repos); wlsunset was already installed but is a
// Wayland-only tool (wlr-gamma-control-unstable-v1), unusable on this X11
// session -- same class of platform mismatch as CLAUDE.md's "waybar
// doesn't run on X11" lesson.
//
// `-O`/`-x` apply/reset a display gamma ramp directly via RandR and exit
// immediately -- there is no long-lived process to hold or signal (unlike
// CaffeineService's inhibitor), and no schedule/location logic here on
// purpose: this pass is on/off only at a single fixed temperature, per
// explicit scope (a real temperature-picker/schedule UI is later work).
// A fresh X session always starts with a neutral gamma ramp regardless of
// what a previous session left it at, so there's nothing to restore or
// reset on shell exit the way Caffeine's held lock needed -- the ramp is
// scoped to this X server's lifetime already.
//
// Verified the real effect directly against xrandr's own gamma readback
// (`xrandr --verbose`), not a screenshot: a standard X11 screenshot tool
// (maim, confirmed) captures the raw framebuffer *before* RandR's gamma
// LUT is applied, so before/after screenshots of a redshift-only change
// come back byte-identical even though the actual display output is
// genuinely different -- a real limitation of screenshot-based
// verification for gamma-ramp effects, not a sign the effect isn't real.
Singleton {
    id: root

    property bool active: false
    readonly property int temperature: 4500 // redshift's own documented default "night" value

    // What `active` should become if the in-flight command succeeds --
    // only committed to `active` itself on confirmed exit 0, not
    // optimistically on click, so a failed redshift invocation can't leave
    // the tile claiming an effect that isn't actually applied.
    property bool pendingActive: false

    function toggle() {
        root.pendingActive = !root.active;
        proc.command = root.pendingActive ? ["redshift", "-O", String(root.temperature)] : ["redshift", "-x"];
        proc.running = false;
        proc.running = true;
    }

    Process {
        id: proc
        stderr: StdioCollector {
            id: procStderr
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                root.active = root.pendingActive;
            } else {
                console.warn("[xidou] NightLightService: redshift exited " + exitCode + (procStderr.text.length > 0 ? ": " + procStderr.text.trim() : ""));
            }
        }
    }
}
