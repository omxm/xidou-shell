import QtQuick
import Quickshell
import Quickshell.Io
import "config"
import "services"
import "bar"
import "launcher"
import "controlcenter"
import "wallpaper"
import "session"
import "screenshot"
import "clipboard"
import "settings"
import "osd"
import "notification"

// Shell entry point. Run with:
//   quickshell -p /path/to/xidou-shell/quickshell
//
// Phase 0 (config + theme) loads first; Phase 1 (the bar) instantiates one
// Bar per screen, mapping screen order to dwm monitor number — fine for the
// X230's single 1366x768 panel, and a reasonable default for multi-monitor
// until dwm-ipc's per-monitor identity is threaded through explicitly.
ShellRoot {
    settings.watchFiles: true

    // The MotionSync reference forces its instantiation at shell boot --
    // unlike Weather's singletons, nothing else always-loaded reads from it,
    // so without this the config.toml -> picom.conf bridge would silently
    // never exist until something else happened to touch MotionSync first.
    // SoundFx is touched for the same reason: its sounds load
    // asynchronously, and the first sound shouldn't be the one that
    // triggers loading (and is lost to it).
    Component.onCompleted: {
        logTheme();
        MotionSync.picomConfPath;
        SoundFx.soundDir;
        InputSettings.disableWhileTyping;
    }

    SoundEvents {}

    Connections {
        target: Config
        function onReloaded() {
            logTheme();
        }
    }

    function logTheme() {
        console.log("[xidou] shell " + Config.data.shell.name + " v" + Config.data.shell.version);
        console.log("[xidou] theme mode=" + Theme.mode
            + " accent=" + Theme.accent
            + " background=" + Theme.background
            + " font=" + Theme.fontFamily + "@" + Theme.fontSize
            + " radius=" + Theme.radius);
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            monitorNum: Quickshell.screens.indexOf(modelData)
        }
    }

    Launcher {
        id: launcherPanel
    }

    ControlCenter {}

    Wallpaper {}

    Session {}

    LockScreen {}

    ScreenshotBackdrop {}

    ScreenshotConfirm {}

    Clipboard {}

    Settings {}

    Osd {}

    NotificationPopups {}

    // Shell-side IPC target for dwm's spawned commands (see bin/xidou and
    // xidouwm/config.h's super+d bind) — this is shell UI state (panel
    // visibility), not window-manager state, so it goes through Quickshell's
    // own IPC rather than dwm-ipc.
    IpcHandler {
        target: "panels"

        function toggle(name: string): void {
            // launcher gets its own path: Launcher.qml's Stage B mode
            // scaffolding needs a second trigger (dwm's super+d) to step
            // back to App Search rather than close outright when a
            // non-default mode is active -- plain PanelManager.toggle()
            // (open<->close, identical for every other panel) has no way
            // to know about that.
            if (name === "launcher")
                launcherPanel.requestToggle();
            else
                PanelManager.toggle(name);
        }

        // Opens a panel without toggling, optionally at a section
        // (ROADMAP F2): `xidou msg panels open control-center Audio`.
        function open(name: string, section: string): void {
            PanelManager.open(name, section);
        }

        // dwm runs this (panelclosecmd in xidouwm/config.h) when something is
        // done outside an open panel: a click on a client or the desktop, or
        // a keybinding not in its panelsafecmds list.
        function closeAll(): void {
            PanelManager.closeAll();
            if (Screenshot.confirmVisible)
                Screenshot.confirmCancel();
        }
    }

    // `xidou msg control-center open <Section>` (ROADMAP F2): opens
    // control-center at that section, case-insensitive ("audio" works).
    // Already open: switches to it. `open ""` opens at Home, like super+e.
    IpcHandler {
        target: "control-center"

        function open(section: string): void {
            PanelManager.open("control-center", section);
        }
    }

    // The action registry (services/Actions.qml, ROADMAP M12):
    // `xidou msg actions list` prints "id<TAB>label" per action,
    // `xidou msg actions run <id>` runs one.
    IpcHandler {
        target: "actions"

        function list(): string {
            return Actions.actions.map(function (action) {
                return action.id + "\t" + Actions.labelOf(action.id);
            }).join("\n");
        }

        function run(id: string): string {
            return Actions.run(id) ? "ok" : "unknown action: " + id;
        }
    }

    // ctrl+<arrow> media keys (xidouwm/config.h) go here rather than a
    // playerctl-style external CLI. The media actions drive the same first
    // MPRIS player the bar's Media module shows.
    IpcHandler {
        target: "mpris"

        function next(): void {
            Actions.run("media.next");
        }

        function previous(): void {
            Actions.run("media.previous");
        }

        function playPause(): void {
            Actions.run("media.play_pause");
        }
    }

    // Nudged by bin/xidou-brightness (xidouwm/config.h's MonBrightness keybinds)
    // after it writes the new sysfs value — brightness has no live signal
    // to watch passively the way Osd.qml watches Pipewire for volume, so it
    // has to be told explicitly. See services/Brightness.qml.
    IpcHandler {
        target: "osd"

        function brightness(): void {
            Brightness.refreshAndShow();
            SoundFx.play("brightness");
        }
    }

    // dwm's super+n keybind (xidouwm/config.h's notificationdndcmd) lands here.
    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            Actions.run("dnd.toggle");
        }
    }

    // No dwm keybind for any of these three yet (Home tab's toggle grid is
    // the only entry point right now) -- exposed anyway for the same
    // reason every other quick-toggle here is: consistent with
    // notifications.toggleDnd(), and it's what let each be tested
    // end-to-end via `quickshell ipc` instead of only through the panel UI.
    IpcHandler {
        target: "wifi"

        function toggle(): void {
            Actions.run("wifi.toggle");
        }
    }

    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            Actions.run("night_light.toggle");
        }
    }

    IpcHandler {
        target: "caffeine"

        function toggle(): void {
            Actions.run("caffeine.toggle");
        }
    }

    // dwm's super+l bind (xidouwm/config.h's sessionlockcmd) -- locks directly,
    // bypassing the session menu entirely.
    IpcHandler {
        target: "session"

        function lock(): void {
            Actions.run("session.lock");
        }
    }

    // dwm's super+comma bind (xidouwm/config.h's settingstogglecmd) -- its own
    // dedicated target rather than going through "panels" above, same as
    // screenshot/theme/notifications each get their own; still bridges
    // straight into the shared PanelManager so it keeps the same
    // mutual-exclusion-with-every-other-panel behavior as everything else.
    IpcHandler {
        target: "settings"

        function toggle(): void {
            PanelManager.toggle("settings");
        }
    }

    // dwm's Print / Ctrl+Print binds (xidouwm/config.h's screenshotfullcmd /
    // screenshotregioncmd) land here.
    IpcHandler {
        target: "screenshot"

        // Refused while locked, and any open panel is closed first; see
        // the screenshot actions in services/Actions.qml.
        function fullscreen(): void {
            Actions.run("screenshot.fullscreen");
        }

        function region(): void {
            Actions.run("screenshot.region");
        }
    }

    // Manual "regenerate theme" trigger (`xidou msg theme regenerate <path>`)
    // ahead of the wallpaper-picker UI that will eventually call the same
    // thing on wallpaper selection (Phase 6). Maps config.toml's theme.mode
    // ("auto") onto matugen's own mode name ("smart") -- they're not spelled
    // the same even though they mean the same thing.
    IpcHandler {
        target: "theme"

        function regenerate(imagePath: string): void {
            var mode = Config.data.theme.mode === "auto" ? "smart" : Config.data.theme.mode;
            ColorScheme.regenerate(imagePath, mode, "scheme-tonal-spot");
        }
    }

    // Settings panel's "Refresh Now" (Weather category) and
    // `xidou msg weather refresh` both land here -- see
    // services/WeatherRefresh.qml for why this is a trigger the three
    // weather displays each listen to, not a service that fetches anything
    // itself.
    IpcHandler {
        target: "weather"

        function refresh(): void {
            WeatherRefresh.trigger();
        }
    }

    // `xidou msg sound play <operation>` plays one operation from
    // lib/SoundMap.js through the normal volume rules; `gain` prints the
    // volume it would play at (0 = silent), `status` how many cues loaded.
    IpcHandler {
        target: "sound"

        function play(op: string): string {
            return SoundFx.play(op) ? "played" : "silent";
        }

        function gain(op: string): string {
            return String(SoundFx.gainFor(op));
        }

        function status(): string {
            return SoundFx.statusSummary();
        }
    }
}
