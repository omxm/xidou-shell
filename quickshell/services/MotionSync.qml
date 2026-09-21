pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../lib/PicomSync.js" as PicomSync

// Bridges config.toml's [motion] table (Settings > Appearance > Motion) into
// session/picom.conf's marker-bounded animations block, then signals picom
// to pick it up. picom.conf is not TOML -- PicomSync.js does a marker-bounded
// text splice rather than parsing the file, and only the block between the
// markers is ever touched; everything else in picom.conf (backend,
// corner-radius, round-borders, etc.) is left byte-for-byte untouched.
//
// Reload mechanism: SIGUSR1 (confirmed against picom's own manpage -- "picom
// reinitializes itself upon receiving SIGUSR1" -- and empirically exercised
// twice against the real live process during Stage 1 testing). Dispatched
// via `pkill -USR1 -f -- "picom --config <exact path>"` rather than a bare
// `pkill -x picom`: a bare name match would also hit the real production
// picom process during an Xvfb test run against a throwaway config, which is
// exactly the kind of accidental real-session touch the $XIDOU_CONFIG_PATH
// convention exists to avoid elsewhere. Matching on the full command line
// (including the specific --config path this instance manages) keeps a test
// run's reload signal scoped to a test picom process, if one exists at all.
Singleton {
    id: root

    // Same override convention as Config.qml's $XIDOU_CONFIG_PATH -- an
    // Xvfb/test run should point this at a throwaway copy of picom.conf and
    // never touch the real session's file.
    readonly property string picomConfPath: {
        var override = Quickshell.env("XIDOU_PICOM_CONF");
        return (override && override.length > 0) ? override : (Quickshell.env("HOME") + "/projects/xidou-shell/session/picom.conf");
    }

    property string cachedText: ""
    property bool ready: false
    property string lastError: ""

    FileView {
        id: picomFile
        path: root.picomConfPath
        watchChanges: true
        printErrors: false

        onLoaded: {
            root.cachedText = picomFile.text();
            root.ready = true;
            root.sync();
        }
        onLoadFailed: function (error) {
            root.lastError = "no readable picom.conf at " + root.picomConfPath;
            console.warn("[xidou] MotionSync: " + root.lastError);
        }
        // Same reload()-not-text() fix already applied in Config.qml and
        // ClipboardHistory.qml -- onFileChanged fires before the content is
        // actually re-read, so text() here can still return stale bytes.
        onFileChanged: picomFile.reload()
    }

    Connections {
        target: Config
        function onReloaded() {
            root.sync();
        }
    }

    Process {
        id: reloadProc
        stderr: StdioCollector {
            id: reloadStderr
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                // pkill exits 1 when no process matched -- expected and
                // harmless under Xvfb when no test picom is running with
                // this exact --config path; only surface real stderr output.
                if (reloadStderr.text.length > 0)
                    console.warn("[xidou] MotionSync: picom reload signal exited " + exitCode + ": " + reloadStderr.text);
            }
        }
    }

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // Recomputes the animations block from Config.data.motion and writes it
    // back only if it actually differs from what's on disk -- an unrelated
    // settings change elsewhere (Config.reloaded() fires on every write, not
    // just motion.*) shouldn't cause a redundant picom reinit.
    function sync() {
        if (!root.ready || !Config.ready)
            return;

        var blockText = PicomSync.buildAnimationsBlock(Config.data.motion);
        var newText = PicomSync.spliceBlock(root.cachedText, blockText);
        if (newText === null) {
            root.lastError = "motion markers not found in " + root.picomConfPath + " -- refusing to guess where to insert them";
            console.warn("[xidou] MotionSync: " + root.lastError);
            return;
        }
        if (newText === root.cachedText)
            return;

        root.cachedText = newText;
        picomFile.setText(newText);

        var cmd = "pkill -USR1 -f -- " + shQuote("picom --config " + root.picomConfPath);
        reloadProc.command = ["sh", "-c", cmd];
        reloadProc.running = false;
        reloadProc.running = true;
    }
}
