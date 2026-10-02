pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../config"

// The action registry (ROADMAP M12): every quick action the shell can run
// from more than one place, defined once and addressed by id. Switchboard,
// Home's toggle grid, the bar's widget clicks and dead zone, and the IPC
// targets dwm's keybinds call all go through run(id), so an action can't
// drift between them. `xidou msg actions list` prints every id, `xidou msg actions run
// <id>` runs one.
//
// An entry: id, label, icon, keywords (for a future search), run(), and
// optionally active() for an on/off state. label and icon may be functions
// when they depend on state; read them through labelOf()/iconOf()/
// activeOf() inside a binding and it updates like any other binding.
// Only actions something actually uses belong here (CLAUDE.md: don't
// scaffold ahead of need). Icons are Material Symbols codepoints, verified
// via fontTools.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    // Mpris.players is an UntypedObjectModel: .values is the real list
    // (see bar/modules/Media.qml). The same first player the bar shows.
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    // Theme Mode's three values, in ThemeTab.qml's order; Theme.qml reacts
    // to Config.data.theme.mode live.
    readonly property var themeModeOrder: ["dark", "light", "auto"]

    readonly property var actions: [
        {
            id: "wifi.toggle",
            label: "Wi-Fi",
            icon: "",
            keywords: ["network", "wireless"],
            active: function () { return Networking.wifiEnabled; },
            run: function () { Networking.wifiEnabled = !Networking.wifiEnabled; }
        },
        {
            id: "bluetooth.toggle",
            label: "Bluetooth",
            icon: function () { return Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "" : ""; },
            keywords: ["bt"],
            active: function () { return Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false; },
            run: function () {
                if (Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
            }
        },
        {
            id: "caffeine.toggle",
            label: "Caffeine",
            icon: "",
            keywords: ["inhibit", "sleep", "idle"],
            active: function () { return CaffeineService.active; },
            run: function () { CaffeineService.toggle(); }
        },
        {
            id: "night_light.toggle",
            label: "Night Light",
            icon: "",
            keywords: ["redshift", "warm"],
            active: function () { return NightLightService.active; },
            run: function () { NightLightService.toggle(); }
        },
        {
            id: "dnd.toggle",
            label: "DND",
            icon: function () { return Notifications.dnd ? "" : ""; },
            keywords: ["do not disturb", "notifications"],
            active: function () { return Notifications.dnd; },
            run: function () { Notifications.toggleDnd(); }
        },
        {
            id: "audio.mute_toggle",
            label: "Mute",
            icon: function () { return (root.sink && root.sink.audio && root.sink.audio.muted) ? "" : ""; },
            keywords: ["volume", "sound", "output"],
            active: function () { return root.sink && root.sink.audio ? root.sink.audio.muted : false; },
            run: function () {
                if (root.sink && root.sink.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            }
        },
        {
            id: "brightness.down",
            label: "Dimmer",
            icon: "",
            keywords: ["brightness", "backlight"],
            run: function () { root.adjustBrightness("down"); }
        },
        {
            id: "brightness.up",
            label: "Brighter",
            icon: "",
            keywords: ["brightness", "backlight"],
            run: function () { root.adjustBrightness("up"); }
        },
        {
            id: "theme.cycle_mode",
            label: function () {
                var mode = Config.data.theme.mode;
                return "Theme: " + mode.charAt(0).toUpperCase() + mode.slice(1);
            },
            icon: function () {
                return ({
                    "dark": "",
                    "light": "",
                    "auto": ""
                })[Config.data.theme.mode] || "";
            },
            keywords: ["dark", "light", "auto"],
            run: function () {
                var idx = root.themeModeOrder.indexOf(Config.data.theme.mode);
                Config.setValue("theme", "mode", root.themeModeOrder[(idx + 1) % root.themeModeOrder.length]);
            }
        },
        {
            id: "wallpaper.open",
            label: "Wallpaper",
            icon: "",
            keywords: ["background", "picker"],
            run: function () { PanelManager.toggle("wallpaper"); }
        },
        // Screenshots close any open panel first and wait until it's off
        // the screen (PanelManager.closeAllThen()), so it isn't in the
        // picture. Refused while locked: region select maps a full-screen
        // backdrop and a pointer-grabbing slop, and either capture would
        // just be a picture of the lock screen.
        {
            id: "screenshot.fullscreen",
            label: "Screenshot",
            icon: "",
            keywords: ["capture", "print"],
            run: function () {
                if (!SessionActions.locked)
                    PanelManager.closeAllThen(function () {
                        Screenshot.fullscreen();
                    });
            }
        },
        {
            id: "screenshot.region",
            label: "Screenshot Region",
            icon: "",
            keywords: ["capture", "print", "select"],
            run: function () {
                if (!SessionActions.locked)
                    PanelManager.closeAllThen(function () {
                        Screenshot.region();
                    });
            }
        },
        {
            // SessionActions.lock() closes every panel itself.
            id: "session.lock",
            label: "Lock",
            icon: "",
            keywords: ["screen", "lock"],
            run: function () { SessionActions.lock(); }
        },
        {
            id: "media.play_pause",
            label: "Play/Pause",
            icon: "" /* play_pause */,
            keywords: ["media", "mpris", "music"],
            run: function () {
                var p = root.player;
                if (p && p.canTogglePlaying) {
                    SoundFx.play(p.isPlaying ? "media_pause" : "media_play");
                    p.togglePlaying();
                }
            }
        },
        {
            id: "media.next",
            label: "Next Track",
            icon: "" /* skip_next */,
            keywords: ["media", "mpris", "music"],
            run: function () {
                var p = root.player;
                if (p && p.canGoNext) {
                    p.next();
                    SoundFx.play("media_next");
                }
            }
        },
        {
            id: "media.previous",
            label: "Previous Track",
            icon: "" /* skip_previous */,
            keywords: ["media", "mpris", "music"],
            run: function () {
                var p = root.player;
                if (p && p.canGoPrevious) {
                    p.previous();
                    SoundFx.play("media_previous");
                }
            }
        },
        // Panel toggles, for the bar's dead zone (M10) and widget clicks.
        // Same as their keybinds: a second trigger closes the panel.
        {
            id: "control_center.toggle",
            label: "Control Center (toggle)",
            icon: "" /* dashboard */,
            keywords: ["control center", "home", "panel"],
            run: function () { PanelManager.toggle("control-center"); }
        },
        {
            // Plain toggle: unlike super+d (shell.qml's launcherPanel.
            // requestToggle()), it doesn't step back to App Search first.
            id: "launcher.toggle",
            label: "Launcher (toggle)",
            icon: "" /* apps */,
            keywords: ["apps", "search", "panel"],
            run: function () { PanelManager.toggle("launcher"); }
        },
        {
            id: "session.toggle",
            label: "Session Menu (toggle)",
            icon: "" /* power_settings_new */,
            keywords: ["logout", "reboot", "shutdown", "panel"],
            run: function () { PanelManager.toggle("session"); }
        },
        {
            id: "settings.toggle",
            label: "Settings (toggle)",
            icon: "" /* settings */,
            keywords: ["preferences", "panel"],
            run: function () { PanelManager.toggle("settings"); }
        },
        // The tag before/after the focused monitor's current one, by
        // explicit tag number (CLAUDE.md lesson 6), wrapping at the ends.
        // Same rule as dwm's cycleview(): with several tags selected the
        // lowest counts as current.
        {
            id: "tag.previous",
            label: "Previous Tag",
            icon: "" /* keyboard_arrow_left */,
            keywords: ["workspace", "tag"],
            run: function () { root.viewAdjacentTag(-1); }
        },
        {
            id: "tag.next",
            label: "Next Tag",
            icon: "" /* keyboard_arrow_right */,
            keywords: ["workspace", "tag"],
            run: function () { root.viewAdjacentTag(1); }
        }
    ].concat(root.controlCenterActions)

    // control-center at a section (F2), one action per section a bar
    // module opens (M8). Labels match ControlCenter.qml's section names.
    readonly property var controlCenterActions: ["Audio", "Media", "Calendar", "Weather", "Bluetooth", "Power", "System", "Notifications"].map(function (section) {
        return {
            id: "control_center." + section.toLowerCase(),
            label: "Control Center: " + section,
            icon: "",
            keywords: ["control center", section.toLowerCase()],
            run: function () { PanelManager.open("control-center", section); }
        };
    })

    readonly property var byId: {
        var map = {};
        for (var i = 0; i < root.actions.length; i++)
            map[root.actions[i].id] = root.actions[i];
        return map;
    }

    function get(id) {
        return root.byId[id] || null;
    }

    // Returns false (and warns) for an unknown id, so a typo in a caller
    // shows up in the log instead of a silent no-op.
    function run(id) {
        var action = root.get(id);
        if (!action) {
            console.warn("[xidou] actions: unknown action '" + id + "'");
            return false;
        }
        action.run();
        return true;
    }

    function labelOf(id) {
        var action = root.get(id);
        if (!action)
            return "";
        return typeof action.label === "function" ? action.label() : action.label;
    }

    function iconOf(id) {
        var action = root.get(id);
        if (!action)
            return "";
        return typeof action.icon === "function" ? action.icon() : action.icon;
    }

    function activeOf(id) {
        var action = root.get(id);
        return !!(action && action.active && action.active());
    }

    function viewAdjacentTag(delta) {
        var tags = DwmIpc.tags;
        var state = DwmIpc.tagStateFor(DwmIpc.focusedMonitor);
        if (!tags.length || !state)
            return;
        var current = 0;
        while (current < tags.length - 1 && !(state.selected & tags[current].bitMask))
            current++;
        var target = ((current + delta) % tags.length + tags.length) % tags.length;
        DwmIpc.viewTag(tags[target].bitMask);
    }

    // bin/xidou-brightness writes sysfs and nudges the OSD, same as dwm's
    // brightness keys.
    function adjustBrightness(direction) {
        brightnessProc.command = ["xidou-brightness", direction];
        brightnessProc.running = false;
        brightnessProc.running = true;
    }

    Process {
        id: brightnessProc
    }
}
