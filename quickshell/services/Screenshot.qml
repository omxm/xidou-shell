pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screenshot capture: shells out to maim (capture), slop (region select),
// ImageMagick's `magick` (cropping a frozen backdrop), and xclip (clipboard)
// -- the same "shell out to a real tool" philosophy as ColorScheme.qml's
// matugen pipeline, not a reimplementation of any of this in QML/JS.
//
// dwm's Print / Ctrl+Print binds (dwm/config.h's screenshotfullcmd /
// screenshotregioncmd) land on `xidou msg screenshot fullscreen|region`,
// routed here via shell.qml's "screenshot" IpcHandler.
//
// No settings panel exists yet to expose these, so the four behavior
// toggles below are hardcoded sensible defaults for now (see CLAUDE.md's
// note on deferring TOML-write-backed settings) rather than config.toml
// keys nobody could actually change yet.
Singleton {
    id: root

    readonly property bool freezeDuringSelection: true
    readonly property bool confirmSelection: true
    // Off by default: with no second keybind for "reselect", turning this on
    // would leave no way back to a fresh selection short of restarting the
    // shell -- see the file-level note above about deferred settings.
    readonly property bool rememberLastRegion: false
    readonly property bool includeCursor: false
    readonly property string saveDirectory: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/xidou"

    property var lastRegion: null // {x, y, w, h} -- session-only, never persisted to disk

    // The two panel windows (ScreenshotBackdrop, ScreenshotConfirm) bind to
    // this UI state rather than owning any capture logic themselves.
    property bool backdropVisible: false
    property string backdropImagePath: ""
    property bool confirmVisible: false
    property string candidateImagePath: ""

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // Matches the naming convention already established in ~/Pictures/
    // Screenshots by whatever this machine used before Xidou existed
    // (screenshot_YYYYMMDD_HHMMSS[-region].png) rather than inventing a new
    // one -- confirmed by inspecting real files already in that directory.
    function timestamp() {
        var d = new Date();
        function pad(n) {
            return n < 10 ? "0" + n : "" + n;
        }
        return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + "_"
            + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds());
    }

    function finalPathFor(suffix) {
        return root.saveDirectory + "/screenshot_" + root.timestamp() + suffix + ".png";
    }

    // slop's own cancellation (right-click or a keystroke mid-drag) exits
    // non-zero with empty stdout -- confirmed directly against the real
    // binary (v7.7), not assumed from --help, so callers only need to check
    // exitCode rather than parsing a cancelled flag out of the format string.
    function parseSlop(text) {
        var parts = text.trim().split(/\s+/).map(Number);
        if (parts.length !== 4 || parts.some(isNaN))
            return null;
        return {
            x: parts[0],
            y: parts[1],
            w: parts[2],
            h: parts[3]
        };
    }

    function geometryString(region) {
        return region.w + "x" + region.h + "+" + region.x + "+" + region.y;
    }

    // --- fullscreen ---------------------------------------------------

    Process {
        id: fullscreenProc
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                console.warn("[xidou] Screenshot: fullscreen capture failed (exit " + exitCode + ")");
        }
    }

    function fullscreen() {
        var finalPath = root.finalPathFor("");
        var cursorFlag = root.includeCursor ? "" : "-u ";
        var cmd = "mkdir -p " + shQuote(root.saveDirectory) + " && maim " + cursorFlag
            + shQuote(finalPath) + " && xclip -selection clipboard -t image/png -i " + shQuote(finalPath);
        fullscreenProc.command = ["sh", "-c", cmd];
        fullscreenProc.running = false;
        fullscreenProc.running = true;
    }

    // --- region ---------------------------------------------------------

    function region() {
        if (root.rememberLastRegion && root.lastRegion) {
            captureRegionLive(root.lastRegion);
            return;
        }
        if (root.freezeDuringSelection)
            startFrozenSelection();
        else
            startLiveSelection();
    }

    // Live (no freeze): slop alone against the live desktop, then a fresh
    // maim -g capture of exactly the region it reports -- what the user saw
    // during selection was the live desktop, so what gets captured should
    // match. startFrozenSelection() below trades this for predictability.
    Process {
        id: liveSlopProc
        stdout: StdioCollector {
            id: liveSlopOut
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                return; // cancelled
            var reg = root.parseSlop(liveSlopOut.text);
            if (!reg)
                return;
            root.lastRegion = reg;
            root.captureRegionLive(reg);
        }
    }

    function startLiveSelection() {
        liveSlopProc.command = ["slop", "-f", "%x %y %w %h"];
        liveSlopProc.running = false;
        liveSlopProc.running = true;
    }

    Process {
        id: captureRegionProc
        property string targetPath: ""
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.warn("[xidou] Screenshot: region capture failed (exit " + exitCode + ")");
                return;
            }
            root.presentCandidate(captureRegionProc.targetPath);
        }
    }

    function captureRegionLive(reg) {
        var candidatePath = root.cacheDir + "/screenshot-candidate-" + Date.now() + ".png";
        var cursorFlag = root.includeCursor ? "" : "-u ";
        var cmd = "mkdir -p " + shQuote(root.cacheDir) + " && maim " + cursorFlag
            + "-g " + shQuote(root.geometryString(reg)) + " " + shQuote(candidatePath);
        captureRegionProc.targetPath = candidatePath;
        captureRegionProc.command = ["sh", "-c", cmd];
        captureRegionProc.running = false;
        captureRegionProc.running = true;
    }

    // Frozen selection: capture the full desktop first, show it as a static
    // backdrop (ScreenshotBackdrop.qml) so what the user drags over can't
    // change mid-selection, then crop THAT already-captured image rather
    // than re-capturing live -- what was seen and what gets saved are
    // always identical this way, even if the real desktop changes
    // underneath during selection.
    Process {
        id: backdropCaptureProc
        property string targetPath: ""
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.warn("[xidou] Screenshot: backdrop capture failed (exit " + exitCode + ")");
                return;
            }
            root.backdropImagePath = backdropCaptureProc.targetPath;
            root.backdropVisible = true;
            frozenSlopProc.command = ["slop", "-f", "%x %y %w %h"];
            frozenSlopProc.running = false;
            frozenSlopProc.running = true;
        }
    }

    function startFrozenSelection() {
        var backdropPath = root.cacheDir + "/screenshot-backdrop-" + Date.now() + ".png";
        var cursorFlag = root.includeCursor ? "" : "-u ";
        var cmd = "mkdir -p " + shQuote(root.cacheDir) + " && maim " + cursorFlag + shQuote(backdropPath);
        backdropCaptureProc.targetPath = backdropPath;
        backdropCaptureProc.command = ["sh", "-c", cmd];
        backdropCaptureProc.running = false;
        backdropCaptureProc.running = true;
    }

    Process {
        id: frozenSlopProc
        stdout: StdioCollector {
            id: frozenSlopOut
        }
        onExited: function (exitCode, exitStatus) {
            root.backdropVisible = false;
            if (exitCode !== 0) {
                root.discardTemp(root.backdropImagePath);
                return; // cancelled
            }
            var reg = root.parseSlop(frozenSlopOut.text);
            if (!reg) {
                root.discardTemp(root.backdropImagePath);
                return;
            }
            root.lastRegion = reg;
            root.cropBackdrop(reg);
        }
    }

    Process {
        id: cropProc
        property string targetPath: ""
        property string sourcePath: ""
        onExited: function (exitCode, exitStatus) {
            root.discardTemp(cropProc.sourcePath);
            if (exitCode !== 0) {
                console.warn("[xidou] Screenshot: crop failed (exit " + exitCode + ")");
                return;
            }
            root.presentCandidate(cropProc.targetPath);
        }
    }

    function cropBackdrop(reg) {
        var candidatePath = root.cacheDir + "/screenshot-candidate-" + Date.now() + ".png";
        var cmd = "magick " + shQuote(root.backdropImagePath) + " -crop " + shQuote(root.geometryString(reg))
            + " +repage " + shQuote(candidatePath);
        cropProc.sourcePath = root.backdropImagePath;
        cropProc.targetPath = candidatePath;
        cropProc.command = ["sh", "-c", cmd];
        cropProc.running = false;
        cropProc.running = true;
    }

    // --- confirm / finalize (shared by both selection paths) -----------

    function presentCandidate(candidatePath) {
        if (root.confirmSelection) {
            root.candidateImagePath = candidatePath;
            root.confirmVisible = true;
        } else {
            root.finalize(candidatePath);
        }
    }

    function confirmSave() {
        root.confirmVisible = false;
        root.finalize(root.candidateImagePath);
        root.candidateImagePath = "";
    }

    function confirmCancel() {
        root.confirmVisible = false;
        root.discardTemp(root.candidateImagePath);
        root.candidateImagePath = "";
    }

    Process {
        id: discardProc
    }

    function discardTemp(path) {
        if (!path)
            return;
        discardProc.command = ["rm", "-f", path];
        discardProc.running = false;
        discardProc.running = true;
    }

    Process {
        id: finalizeProc
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                console.warn("[xidou] Screenshot: save/clipboard failed (exit " + exitCode + ")");
        }
    }

    function finalize(candidatePath) {
        var finalPath = root.finalPathFor("-region");
        var cmd = "mkdir -p " + shQuote(root.saveDirectory) + " && mv " + shQuote(candidatePath) + " "
            + shQuote(finalPath) + " && xclip -selection clipboard -t image/png -i " + shQuote(finalPath);
        finalizeProc.command = ["sh", "-c", cmd];
        finalizeProc.running = false;
        finalizeProc.running = true;
    }
}
