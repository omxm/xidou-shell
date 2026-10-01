pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import "../config"
import "../lib/SoundMap.js" as SoundMap

// UI sound effects (ROADMAP F6 + M22). Callers name an operation from
// lib/SoundMap.js (`SoundFx.play("panel_open")`), never a cue or a file.
//
// Playback is Qt Multimedia's SoundEffect, one preloaded instance per cue
// in assets/sounds/zen/: low latency and no process per sound. SoundEffect
// plays WAV only, which is why the pack's .ogg files were converted once
// (see that directory's NOTICE).
//
// Volume = cue default (cues.json) x category volume x master volume, per
// SoundMap.gain(). Do Not Disturb silences incoming notifications only.
Singleton {
    id: root

    readonly property var sound: Config.data.sound
    readonly property url soundDir: Qt.resolvedUrl("../assets/sounds/" + (root.sound.pack || "zen") + "/")

    // cue -> default volume, from cues.json.
    property var cueVolumes: ({})
    // cue -> SoundEffect, filled as the Instantiator creates them.
    property var effects: ({})
    // cue -> Date.now() of its last play, for cooldowns and dedupe.
    property var lastPlayed: ({})
    // loop key -> cue currently looping under that key.
    property var loops: ({})
    // XIDOU_SOUND_LOG=1 logs every operation: what played, at what volume,
    // or why it stayed silent.
    readonly property bool logEnabled: !!Quickshell.env("XIDOU_SOUND_LOG")

    function log(opId, msg) {
        if (root.logEnabled)
            console.log("[xidou] sound " + opId + ": " + msg);
    }

    FileView {
        id: cuesFile
        path: Qt.resolvedUrl("../assets/sounds/zen/cues.json").toString().replace("file://", "")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                var parsed = JSON.parse(cuesFile.text());
                var vols = {};
                for (var cue in parsed)
                    vols[cue] = parsed[cue].volume;
                root.cueVolumes = vols;
                root.createEffects();
            } catch (e) {
                console.warn("[xidou] SoundFx: cannot parse cues.json: " + e);
            }
        }
        onLoadFailed: console.warn("[xidou] SoundFx: cues.json not found; sounds disabled")
    }

    Component {
        id: effectComponent
        SoundEffect {
            property string cue: ""
            source: root.soundDir + cue + ".wav"
            onPlayingChanged: {
                if (!playing)
                    root.cueStopped(cue);
            }
        }
    }

    function createEffects() {
        var next = {};
        for (var cue in root.cueVolumes)
            next[cue] = root.effects[cue] || effectComponent.createObject(root, { cue: cue });
        root.effects = next;
    }

    function statusSummary() {
        var total = 0, ready = 0, bad = [];
        for (var cue in root.effects) {
            total++;
            if (root.effects[cue].status === SoundEffect.Ready)
                ready++;
            else if (root.effects[cue].status === SoundEffect.Error)
                bad.push(cue);
        }
        return ready + "/" + total + " ready" + (bad.length ? ", errors: " + bad.join(" ") : "");
    }

    function gainFor(opId) {
        return SoundMap.gain(opId, root.sound, root.cueVolumes, Notifications.dnd);
    }

    // Returns true when the sound actually started.
    function play(opId) {
        var op = SoundMap.OPS[opId];
        if (!op) {
            console.warn("[xidou] SoundFx: unknown operation '" + opId + "'");
            return false;
        }
        var g = root.gainFor(opId);
        if (g <= 0) {
            root.log(opId, "silent (off, muted or DND)");
            return false;
        }
        var fx = root.effects[op.cue];
        if (!fx || fx.status !== SoundEffect.Ready) {
            root.log(opId, "silent (" + op.cue + " not loaded)");
            return false;
        }
        var now = Date.now();
        var last = root.lastPlayed[op.cue] || 0;
        var gap = Math.max(SoundMap.DEDUPE_MS, SoundMap.COOLDOWN_MS[op.cue] || 0);
        if (now - last < gap) {
            root.log(opId, "dropped (" + op.cue + " played " + (now - last) + " ms ago)");
            return false;
        }
        root.lastPlayed[op.cue] = now;
        fx.loops = 1;
        fx.volume = g;
        fx.play();
        root.log(opId, op.cue + " at " + g.toFixed(4));
        return true;
    }

    // For the loop cues (connecting, scanning, processing). `key` names the
    // thing that loops, so stopLoop(key) stops the right one.
    function startLoop(opId, key) {
        var op = SoundMap.OPS[opId];
        if (!op || root.loops[key])
            return;
        var g = root.gainFor(opId);
        var fx = op ? root.effects[op.cue] : null;
        if (g <= 0 || !fx || fx.status !== SoundEffect.Ready)
            return;
        fx.loops = SoundEffect.Infinite;
        fx.volume = g;
        fx.play();
        var next = Object.assign({}, root.loops);
        next[key] = op.cue;
        root.loops = next;
    }

    function stopLoop(key) {
        var cue = root.loops[key];
        if (!cue)
            return;
        var next = Object.assign({}, root.loops);
        delete next[key];
        root.loops = next;
        if (root.effects[cue])
            root.effects[cue].stop();
    }

    // Session-ending actions (M22): start the cue, then run `action` when
    // it ends or after 0.4 s, whichever is first. If the cue doesn't start
    // (muted, off, not loaded), `action` runs right away. A sound never
    // delays leaving the session by more than 0.4 s.
    property var pendingAction: null
    property string pendingCue: ""

    function playThen(opId, action) {
        if (root.pendingAction) {
            // A second request while one is waiting: run both now.
            root.runPending();
            action();
            return;
        }
        if (!root.play(opId)) {
            action();
            return;
        }
        root.pendingAction = action;
        root.pendingCue = SoundMap.OPS[opId].cue;
        thenTimer.restart();
    }

    function cueStopped(cue) {
        if (root.pendingAction && cue === root.pendingCue)
            root.runPending();
    }

    function runPending() {
        var fn = root.pendingAction;
        root.pendingAction = null;
        root.pendingCue = "";
        thenTimer.stop();
        if (fn)
            fn();
    }

    Timer {
        id: thenTimer
        interval: 400
        onTriggered: root.runPending()
    }
}
