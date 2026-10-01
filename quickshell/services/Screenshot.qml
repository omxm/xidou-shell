pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Screenshot capture: shells out to maim (capture), slop (region select),
// ImageMagick's `magick` (cropping a frozen backdrop), and xclip (clipboard)
// -- the same "shell out to a real tool" philosophy as ColorScheme.qml's
// matugen pipeline, not a reimplementation of any of this in QML/JS.
//
// dwm's Print / Ctrl+Print binds (xidouwm/config.h's screenshotfullcmd /
// screenshotregioncmd) land on `xidou msg screenshot fullscreen|region`,
// routed here via shell.qml's "screenshot" IpcHandler.
//
// The four behavior toggles + save directory below are real config.toml
// keys under [screenshot] (Config.qml's defaults), wired up to the
// settings panel's System > Screenshot tab -- readonly properties bound
// reactively to Config.data, same pattern as every panel's own `cfg`.
Singleton {
    id: root

    readonly property bool freezeDuringSelection: Config.data.screenshot.freeze_during_selection
    readonly property bool confirmSelection: Config.data.screenshot.confirm_selection
    readonly property bool rememberLastRegion: Config.data.screenshot.remember_last_region
    readonly property bool includeCursor: Config.data.screenshot.include_cursor
    readonly property string saveDirectory: root.expandHome(Config.data.screenshot.save_directory)
    // L3. At least one of the two stays on: Settings won't turn the last
    // one off, and if config.toml has both false anyway, the file is still
    // saved rather than the capture silently going nowhere.
    readonly property bool copyToClipboard: Config.data.screenshot.copy_to_clipboard
    readonly property bool saveToFile: Config.data.screenshot.save_to_file || !root.copyToClipboard
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/xidou"

    function expandHome(p) {
        return p.indexOf("~") === 0 ? (Quickshell.env("HOME") + p.slice(1)) : p;
    }

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
        property string tempPath: ""
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.warn("[xidou] Screenshot: fullscreen capture failed (exit " + exitCode + ")");
                return;
            }
            SoundFx.play("screenshot");
            root.deliver(fullscreenProc.tempPath, "");
        }
    }

    function fullscreen() {
        var tempPath = root.cacheDir + "/screenshot-full-" + Date.now() + ".png";
        var cursorFlag = root.includeCursor ? "" : "-u ";
        fullscreenProc.tempPath = tempPath;
        fullscreenProc.command = ["sh", "-c", "mkdir -p " + shQuote(root.cacheDir) + " && maim " + cursorFlag + shQuote(tempPath)];
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
            if (exitCode !== 0) {
                SoundFx.play("region_cancel");
                return; // cancelled
            }
            var reg = root.parseSlop(liveSlopOut.text);
            if (!reg)
                return;
            root.lastRegion = reg;
            root.captureRegionLive(reg);
        }
    }

    function startLiveSelection() {
        SoundFx.play("region_start");
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
            SoundFx.play("region_start");
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
                SoundFx.play("region_cancel");
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
        SoundFx.play("screenshot");
        if (root.confirmSelection) {
            root.candidateImagePath = candidatePath;
            root.confirmVisible = true;
        } else {
            root.deliver(candidatePath, "-region");
        }
    }

    // The confirm dialog's Save. Its sound says where the capture went:
    // saved (with or without the clipboard), or copied only.
    function confirmSave() {
        root.confirmVisible = false;
        SoundFx.play(root.saveToFile ? "capture_save" : "capture_copy");
        root.deliver(root.candidateImagePath, "-region");
        root.candidateImagePath = "";
    }

    function confirmCancel() {
        root.confirmVisible = false;
        SoundFx.play("capture_delete");
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
        id: deliverProc
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                console.warn("[xidou] Screenshot: save/clipboard failed (exit " + exitCode + ")");
        }
    }

    // Sends a finished capture (a temp file in cacheDir) where L3's two
    // toggles say: moved into saveDirectory, copied to the clipboard, or
    // both. A copy-only capture's temp file is removed once xclip has read
    // it (xclip -i reads the whole file before it starts serving).
    function deliverCommand(tempPath, suffix) {
        var src = tempPath;
        var parts = [];
        if (root.saveToFile) {
            var finalPath = root.finalPathFor(suffix);
            parts.push("mkdir -p " + shQuote(root.saveDirectory));
            parts.push("mv " + shQuote(tempPath) + " " + shQuote(finalPath));
            src = finalPath;
        }
        if (root.copyToClipboard)
            parts.push("xclip -selection clipboard -t image/png -i " + shQuote(src));
        if (!root.saveToFile)
            parts.push("rm -f " + shQuote(tempPath));
        return parts.join(" && ");
    }

    function deliver(tempPath, suffix) {
        deliverProc.command = ["sh", "-c", root.deliverCommand(tempPath, suffix)];
        deliverProc.running = false;
        deliverProc.running = true;
    }
}
