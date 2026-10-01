pragma Singleton

import QtQuick
import Quickshell

// Motion tokens (ROADMAP F4): the motion counterpart of Theme.qml. Nothing
// outside this file should write an animation duration or easing literal --
// bind to these instead, so retuning motion means editing [motion] in
// config.toml, not QML.
//
// Everything derives from [motion]:
// - `duration` (seconds, picom's open/close length) sets the scale.
// - `enabled` is the global "reduce motion" switch. `multiplier` is 0 when
//   motion is off, so every token becomes 0 ms and animations snap, the same
//   way picom's open/close animations stop (services/MotionSync.qml). M21's
//   accessibility settings are meant to extend this, not replace it.
//
// Durations are in milliseconds, ready for NumberAnimation.duration and
// Timer.interval.
Singleton {
    id: root

    readonly property var cfg: Config.data.motion
    readonly property real multiplier: cfg.enabled ? 1 : 0
    readonly property real baseMs: Math.max(0, Number(cfg.duration) || 0) * 1000

    // Small in-place changes: list scrolling, a bar growing.
    readonly property int fast: Math.round(baseMs * 0.8 * multiplier)
    // Matches picom's panel open/close, so QML that waits for a panel to
    // leave the screen (PanelManager.closeAllThen()) uses this.
    readonly property int normal: Math.round(baseMs * multiplier)
    // Larger moves across the screen.
    readonly property int slow: Math.round(baseMs * 2 * multiplier)

    // Easing roles. `standard` for things that move in place, `enter` for
    // something arriving or growing, `exit` for something leaving or
    // shrinking, `emphasized` for a move that should draw the eye.
    readonly property int standard: Easing.OutCubic
    readonly property int enter: Easing.OutCubic
    readonly property int exit: Easing.InCubic
    readonly property int emphasized: Easing.OutBack
}
