import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../config"
import "../services"
import "../controlcenter" as ControlCenter
import "../lib/EmojiData.js" as EmojiData

// App launcher: toggled by `xidou msg panel-toggle launcher` (see
// dwm/config.h's super+d bind and bin/xidou), via PanelManager.isOpen()
// rather than dwm-ipc — this is shell UI state, not window-manager state.
// PanelManager also enforces that opening this closes any other dock panel
// (control-center, etc.) instead of leaving both stacked.
// Not anchored to any screen edge (unlike Bar, which reserves strut space):
// PanelWindow has no native "centered floating window" concept since it's
// modeled on layer-shell's edge-anchoring, so centering is done by anchoring
// top+left with margins computed from the screen size.
//
// Quickshell positions anchored panels the same way a Wayland compositor
// positions layer-shell surfaces: margins are measured from the edge of the
// *available* area, not the raw screen — confirmed empirically (a
// margins.top of 204 on a 768px screen landed the window at y=236, exactly
// the bar's 32px exclusiveZone added on top). So centering has to subtract
// the bar's own reservation before halving, not the raw screen size, or
// Quickshell's automatic offset double-counts it. Only accounts for a
// top-positioned bar for now — CLAUDE.md's bar.position: "bottom" option
// would need the same treatment against the bottom anchor.
PanelWindow {
    id: root

    readonly property var cfg: Config.data.panels.launcher
    readonly property int panelWidth: 480
    readonly property int panelHeight: 360
    readonly property int barReservedHeight: (Config.data.bar.position !== "bottom") ? Config.data.bar.height : 0

    visible: PanelManager.isOpen("launcher") && root.cfg.enabled
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

    // PanelWindow.focusable (the documented, intended lever for asking the
    // platform for real X input focus) is set, but empirically does nothing
    // on this system's X11 backend — verified via XGetInputFocus staying on
    // the root window after showing the panel, with neither
    // Window.requestActivate() nor ProxyWindowBase's _backingWindow
    // producing any different result either. dwm itself is uninvolved: this
    // window is unmanaged (see the _NET_WM_WINDOW_TYPE_DOCK handling in
    // manage()), so dwm's focus()/setfocus()/unfocus() never target it
    // regardless. Falls back to explicitly forcing focus via a small
    // external helper (bin/xidou-focus-window) that does exactly what a
    // direct XSetInputFocus was confirmed to do reliably — find this
    // window by its size (PanelWindow has no title/id exposed to QML) and
    // force focus onto it.
    focusable: true

    Process {
        id: focusHelper
        command: ["xidou-focus-window", String(root.panelWidth), String(root.panelHeight)]
    }

    anchors.top: true
    anchors.left: true
    margins.top: Math.round((screen.height - barReservedHeight - panelHeight) / 2)
    margins.left: Math.round((screen.width - panelWidth) / 2)

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // DesktopEntries only needs filtering, not re-fetching, so the model is
    // computed once here rather than re-queried per keystroke. Sorted by
    // UsageStats' recorded use count (most-used first), falling back to
    // alphabetical for anything with zero uses -- DesktopEntry.id (the
    // .desktop file's own stable id, e.g. "discord.desktop") is the count
    // key, not .name, since name isn't guaranteed unique.
    readonly property var allApps: {
        var apps = [];
        var list = DesktopEntries.applications.values;
        for (var i = 0; i < list.length; i++) {
            if (!list[i].noDisplay)
                apps.push(list[i]);
        }
        apps.sort(function (a, b) {
            var ca = UsageStats.getCount("apps", a.id);
            var cb = UsageStats.getCount("apps", b.id);
            if (ca !== cb)
                return cb - ca;
            return a.name.localeCompare(b.name);
        });
        return apps;
    }

    readonly property var filteredApps: {
        var q = searchField.text.trim().toLowerCase();
        if (!q)
            return root.allApps;
        var out = [];
        for (var i = 0; i < root.allApps.length; i++) {
            if (root.allApps[i].name.toLowerCase().indexOf(q) !== -1)
                out.push(root.allApps[i]);
        }
        return out;
    }

    property int selectedIndex: 0

    // 3-mode Tab-cycle scaffolding (Stage B). Switchboard and Emoji Picker
    // are empty stubs for now -- Switchboard's real content (only
    // already-backed toggles: DND, Wi-Fi, Bluetooth, brightness, volume,
    // Night Light, theme mode, wallpaper, screenshot, lock) and the Emoji
    // Picker (needs font research first -- Material Symbols/Nerd Fonts
    // can't render color emoji, per the lessons doc) are separate
    // follow-ups once this scaffolding itself is confirmed working.
    property string mode: "appSearch" // appSearch | switchboard | emoji
    readonly property var modeOrder: ["appSearch", "switchboard", "emoji"]
    readonly property var modeLabels: ({
        appSearch: "App Search",
        switchboard: "Switchboard",
        emoji: "Emoji Picker"
    })

    function cycleMode() {
        var idx = root.modeOrder.indexOf(root.mode);
        root.mode = root.modeOrder[(idx + 1) % root.modeOrder.length];
    }

    // Escape from a non-default mode, or a second press of the launcher's
    // own toggle keybind while one is active, steps back to App Search
    // instead of closing the whole panel -- see requestToggle() below and
    // Keys.onEscapePressed on both focus points further down.
    function resetToAppSearch() {
        root.mode = "appSearch";
        searchField.text = "";
        root.selectedIndex = 0;
        emojiSearchField.text = "";
        root.emojiSelectedIndex = 0;
        root.switchboardSelectedIndex = 0;
        searchField.forceActiveFocus();
    }

    // The panels IpcHandler (shell.qml, dwm's super+d bind) calls this
    // instead of PanelManager.toggle("launcher") directly -- a second
    // trigger while a non-default mode is active should reset to App
    // Search rather than actually closing, which plain toggle()
    // (open->close, used identically by every other panel) has no way to
    // know about.
    function requestToggle() {
        if (PanelManager.isOpen("launcher") && root.mode !== "appSearch")
            root.resetToAppSearch();
        else
            PanelManager.toggle("launcher");
    }

    onModeChanged: {
        if (root.mode === "appSearch")
            searchField.forceActiveFocus();
        else if (root.mode === "emoji")
            emojiSearchField.forceActiveFocus();
        else
            switchboardContent.forceActiveFocus();
    }

    onFilteredAppsChanged: selectedIndex = 0
    onVisibleChanged: {
        if (visible) {
            root.mode = "appSearch";
            searchField.text = "";
            selectedIndex = 0;
            emojiSearchField.text = "";
            emojiSelectedIndex = 0;
            switchboardSelectedIndex = 0;
            searchField.forceActiveFocus();
            // Give the window a moment to actually map before trying to
            // focus it by title — xidou-focus-window can't find a window
            // that isn't on screen yet.
            focusHelperTimer.start();
        }
    }

    Timer {
        id: focusHelperTimer
        interval: 50
        onTriggered: {
            focusHelper.running = false;
            focusHelper.running = true;
        }
    }

    function launchSelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            var app = filteredApps[selectedIndex];
            UsageStats.recordUse("apps", app.id);
            app.execute();
            PanelManager.close("launcher");
        }
    }

    // Emoji Picker (Stage: replaces the earlier stub). Parses the real
    // system emoji-test.txt (package: unicode-emoji) via lib/EmojiData.js
    // rather than a bundled JSON list -- see EmojiData.js's own header for
    // why. A plain, non-watched FileView is enough since this is static
    // system data, not something that changes at runtime.
    readonly property var allEmoji: EmojiData.parse(emojiDataFile.text())

    FileView {
        id: emojiDataFile
        path: "/usr/share/unicode/emoji/emoji-test.txt"
        printErrors: false
    }

    property string emojiQuery: ""
    property int emojiSelectedIndex: 0

    // Same usage-frequency sort as allApps, keyed by the emoji character
    // itself rather than an id (there's no separate identifier). Ties fall
    // back to EmojiData's own `order` field -- the file's real CLDR display
    // order -- not a second alphabetical sort, since emoji names are often
    // not what a browsing (non-searching) picker should be ordered by.
    readonly property var sortedEmoji: {
        var list = root.allEmoji.slice();
        list.sort(function (a, b) {
            var ca = UsageStats.getCount("emoji", a.char);
            var cb = UsageStats.getCount("emoji", b.char);
            if (ca !== cb)
                return cb - ca;
            return a.order - b.order;
        });
        return list;
    }

    readonly property var filteredEmoji: {
        var q = root.emojiQuery.trim().toLowerCase();
        if (!q)
            return root.sortedEmoji;
        var out = [];
        for (var i = 0; i < root.sortedEmoji.length; i++) {
            if (root.sortedEmoji[i].name.indexOf(q) !== -1)
                out.push(root.sortedEmoji[i]);
        }
        return out;
    }

    onFilteredEmojiChanged: emojiSelectedIndex = 0

    Process {
        id: emojiCopyProc
    }

    // Reuses ClipboardHistory.copy()'s exact write pattern: content goes
    // through a file, never interpolated into the shell command string.
    // Not xidou-clipd itself (that's the read-side history tracker) -- just
    // the same xclip write mechanism it also uses. Since xidou-clipd
    // watches clipnotify system-wide, this still shows up in clipboard
    // history as a side effect, for free.
    function copySelectedEmoji() {
        if (root.emojiSelectedIndex < 0 || root.emojiSelectedIndex >= root.filteredEmoji.length)
            return;
        var entry = root.filteredEmoji[root.emojiSelectedIndex];
        UsageStats.recordUse("emoji", entry.char);
        var path = Quickshell.env("HOME") + "/.cache/xidou/emoji-clip";
        var dir = Quickshell.env("HOME") + "/.cache/xidou";
        var cmd = "mkdir -p " + root.shQuote(dir) + " && printf '%s' " + root.shQuote(entry.char) + " > " + root.shQuote(path) + " && xclip -selection clipboard -i < " + root.shQuote(path);
        emojiCopyProc.command = ["sh", "-c", cmd];
        emojiCopyProc.running = false;
        emojiCopyProc.running = true;
        PanelManager.close("launcher");
    }

    // Switchboard: a fixed 4x3 grid of quick actions, every one of them
    // reusing a service that already has real backing elsewhere (Home tab's
    // toggle grid, the bar's Volume module, Screenshot/SessionActions) --
    // no new backend logic except brightness (Brightness.qml is read-only
    // telemetry, so up/down here shells out to bin/xidou-brightness
    // directly, same as dwm's own brightness keybinds do).
    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    property int switchboardSelectedIndex: 0
    readonly property int switchboardColumns: 4

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleBluetooth() {
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
    }

    function toggleMute() {
        if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function adjustBrightness(direction) {
        brightnessProc.command = ["xidou-brightness", direction];
        brightnessProc.running = false;
        brightnessProc.running = true;
    }

    // Cycles the same three values ThemeTab.qml's OptionRow offers, through
    // the same Config.setValue() call -- Theme.qml already reacts to
    // Config.data.theme.mode live, so there's nothing else to trigger.
    readonly property var themeModeOrder: ["dark", "light", "auto"]

    function cycleThemeMode() {
        var idx = root.themeModeOrder.indexOf(Config.data.theme.mode);
        var next = root.themeModeOrder[(idx + 1) % root.themeModeOrder.length];
        Config.setValue("theme", "mode", next);
    }

    function openWallpaperPanel() {
        PanelManager.toggle("wallpaper");
    }

    // Closes the launcher first and waits for picom's real "disappear"
    // animation (session/picom.conf's motion block, driven by
    // Config.data.motion.duration/enabled) to actually finish before
    // capturing -- confirmed empirically (a fixed 100ms guess landed a
    // half-faded launcher in the capture, since that preset's default
    // duration alone is already 150ms). Reacts to the same config the
    // Settings > Appearance > Motion tab writes, so this stays correct if
    // that duration changes instead of drifting from a hardcoded guess.
    function takeScreenshot() {
        PanelManager.close("launcher");
        screenshotDelayTimer.start();
    }

    Timer {
        id: screenshotDelayTimer
        interval: (Config.data.motion.enabled ? Config.data.motion.duration * 1000 : 0) + 60
        onTriggered: Screenshot.fullscreen()
    }

    // SessionActions.lock() already closes every panel itself.
    function lockSession() {
        SessionActions.lock();
    }

    readonly property var switchboardActions: [toggleWifi, toggleBluetooth, CaffeineService.toggle, NightLightService.toggle, Notifications.toggleDnd, toggleMute, function () {
            adjustBrightness("down");
        }, function () {
            adjustBrightness("up");
        }, cycleThemeMode, openWallpaperPanel, takeScreenshot, lockSession]

    function triggerSwitchboardTile(index) {
        if (index >= 0 && index < root.switchboardActions.length)
            root.switchboardActions[index]();
    }

    Process {
        id: brightnessProc
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize / 2

            Text {
                id: modeLabel
                width: parent.width
                text: root.modeLabels[root.mode] + "  ·  Tab to cycle"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.8
                font.bold: true
            }

            Item {
                id: contentArea
                width: parent.width
                height: parent.height - modeLabel.height - parent.spacing

                Column {
                    id: appSearchContent
                    anchors.fill: parent
                    spacing: Theme.fontSize / 2
                    visible: root.mode === "appSearch"

                    Rectangle {
                        width: parent.width
                        height: Theme.fontSize * 2.2
                        radius: Theme.radius / 2
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.margins: Theme.fontSize / 2
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            clip: true

                            Keys.onTabPressed: root.cycleMode()
                            Keys.onEscapePressed: PanelManager.close("launcher")
                            Keys.onReturnPressed: root.launchSelected()
                            Keys.onEnterPressed: root.launchSelected()
                            Keys.onDownPressed: {
                                if (root.selectedIndex < root.filteredApps.length - 1)
                                    root.selectedIndex++;
                            }
                            Keys.onUpPressed: {
                                if (root.selectedIndex > 0)
                                    root.selectedIndex--;
                            }
                        }
                    }

                    ListView {
                        id: resultsList
                        width: parent.width
                        height: parent.height - parent.spacing - (Theme.fontSize * 2.2)
                        clip: true
                        model: root.filteredApps
                        currentIndex: root.selectedIndex

                        readonly property real rowHeight: Theme.fontSize * 2.2

                        // Not highlightRangeMode/StrictlyEnforceRange -- tried
                        // that twice and confirmed empirically (via real
                        // screenshots, pixel-measured, not eyeballed) that it
                        // does NOT clamp contentY to the list's actual
                        // scrollable bounds the way its name implies. For
                        // currentIndex 0 in a long list it still centers item
                        // 0 in the preferred band and leaves a large blank
                        // gap above it, because contentY genuinely goes
                        // negative and nothing renders for a negative offset
                        // -- there's no automatic edge-pinning at all, only
                        // "always keep the current item in this exact band."
                        //
                        // So this computes the target scroll position
                        // directly and clamps it to [0, contentHeight -
                        // height] by hand: center the current row when
                        // there's room to, but never scroll past either end
                        // of the actual content. interactive: false below is
                        // required for this -- a real mouse-drag/flick would
                        // otherwise sever this binding (QML drops a property
                        // binding on any external imperative write to it),
                        // and nothing currently drives this list by dragging
                        // anyway (keyboard Up/Down and click-to-launch only).
                        interactive: false
                        boundsBehavior: Flickable.StopAtBounds
                        contentY: {
                            if (root.filteredApps.length === 0)
                                return 0;
                            var itemY = root.selectedIndex * rowHeight;
                            var desired = itemY - (height - rowHeight) / 2;
                            var maxY = Math.max(0, contentHeight - height);
                            return Math.max(0, Math.min(desired, maxY));
                        }

                        Behavior on contentY {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }

                        delegate: Rectangle {
                            id: delegateRoot
                            required property var modelData
                            required property int index

                            width: resultsList.width
                            height: resultsList.rowHeight
                            radius: Theme.radius / 2
                            color: index === root.selectedIndex ? Theme.accent : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.fontSize / 2
                                anchors.rightMargin: Theme.fontSize / 2
                                spacing: Theme.fontSize / 2

                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: Theme.fontSize * 1.4
                                    // DesktopEntry.icon is the raw, unresolved
                                    // Icon= value from the .desktop file (a
                                    // bare icon-theme name like "blueman", not
                                    // a usable path) -- unlike
                                    // SystemTrayItem.icon (used as-is in
                                    // bar/modules/Tray.qml), which the
                                    // StatusNotifierItem protocol already
                                    // hands over pre-resolved. Confirmed
                                    // empirically (printed the raw values)
                                    // rather than assumed the two .icon
                                    // properties meant the same kind of
                                    // string. Quickshell.iconPath() is the
                                    // actual theme-lookup step Tray.qml never
                                    // needed.
                                    source: Quickshell.iconPath(delegateRoot.modelData.icon)
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Theme.fontSize * 1.4 - parent.spacing
                                    elide: Text.ElideRight
                                    text: delegateRoot.modelData.name
                                    color: index === root.selectedIndex ? Theme.background : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedIndex = delegateRoot.index;
                                    root.launchSelected();
                                }
                            }
                        }
                    }
                }

                // Switchboard: a 4x3 grid of already-backed quick
                // actions/toggles, reusing ControlCenter.ToggleTile (the
                // same component Home tab's grid uses) so it looks and
                // behaves identically rather than being a second,
                // differently-styled toggle widget. Keyboard nav mirrors
                // the emoji grid below (index math by column count), with
                // Return/click both routed through triggerSwitchboardTile()
                // so there's exactly one place each action actually runs.
                Item {
                    id: switchboardContent
                    anchors.fill: parent
                    visible: root.mode === "switchboard"
                    focus: root.mode === "switchboard"

                    Keys.onTabPressed: root.cycleMode()
                    Keys.onEscapePressed: root.resetToAppSearch()
                    Keys.onReturnPressed: root.triggerSwitchboardTile(root.switchboardSelectedIndex)
                    Keys.onEnterPressed: root.triggerSwitchboardTile(root.switchboardSelectedIndex)
                    Keys.onLeftPressed: {
                        if (root.switchboardSelectedIndex > 0)
                            root.switchboardSelectedIndex--;
                    }
                    Keys.onRightPressed: {
                        if (root.switchboardSelectedIndex < switchboardGrid.children.length - 1)
                            root.switchboardSelectedIndex++;
                    }
                    Keys.onUpPressed: {
                        var prev = root.switchboardSelectedIndex - root.switchboardColumns;
                        if (prev >= 0)
                            root.switchboardSelectedIndex = prev;
                    }
                    Keys.onDownPressed: {
                        var next = root.switchboardSelectedIndex + root.switchboardColumns;
                        if (next < switchboardGrid.children.length)
                            root.switchboardSelectedIndex = next;
                    }

                    GridLayout {
                        id: switchboardGrid
                        anchors.fill: parent
                        columns: root.switchboardColumns
                        rowSpacing: Theme.fontSize / 2
                        columnSpacing: Theme.fontSize / 2

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: ""
                            label: "Wi-Fi"
                            active: Networking.wifiEnabled
                            keyboardFocused: root.switchboardSelectedIndex === 0
                            onTriggered: root.triggerSwitchboardTile(0)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "" : ""
                            label: "Bluetooth"
                            active: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                            keyboardFocused: root.switchboardSelectedIndex === 1
                            onTriggered: root.triggerSwitchboardTile(1)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: ""
                            label: "Caffeine"
                            active: CaffeineService.active
                            keyboardFocused: root.switchboardSelectedIndex === 2
                            onTriggered: root.triggerSwitchboardTile(2)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: ""
                            label: "Night Light"
                            active: NightLightService.active
                            keyboardFocused: root.switchboardSelectedIndex === 3
                            onTriggered: root.triggerSwitchboardTile(3)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: Notifications.dnd ? "" : ""
                            label: "DND"
                            active: Notifications.dnd
                            keyboardFocused: root.switchboardSelectedIndex === 4
                            onTriggered: root.triggerSwitchboardTile(4)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: (root.sink && root.sink.audio && root.sink.audio.muted) ? "" : ""
                            label: "Mute"
                            active: root.sink && root.sink.audio ? root.sink.audio.muted : false
                            keyboardFocused: root.switchboardSelectedIndex === 5
                            onTriggered: root.triggerSwitchboardTile(5)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: ""
                            label: "Dimmer"
                            keyboardFocused: root.switchboardSelectedIndex === 6
                            onTriggered: root.triggerSwitchboardTile(6)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: ""
                            label: "Brighter"
                            keyboardFocused: root.switchboardSelectedIndex === 7
                            onTriggered: root.triggerSwitchboardTile(7)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: ({
                                "dark": "",
                                "light": "",
                                "auto": ""
                            })[Config.data.theme.mode] || ""
                            label: "Theme: " + Config.data.theme.mode.charAt(0).toUpperCase() + Config.data.theme.mode.slice(1)
                            keyboardFocused: root.switchboardSelectedIndex === 8
                            onTriggered: root.triggerSwitchboardTile(8)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: ""
                            label: "Wallpaper"
                            keyboardFocused: root.switchboardSelectedIndex === 9
                            onTriggered: root.triggerSwitchboardTile(9)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: ""
                            label: "Screenshot"
                            keyboardFocused: root.switchboardSelectedIndex === 10
                            onTriggered: root.triggerSwitchboardTile(10)
                        }

                        ControlCenter.ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: ""
                            label: "Lock"
                            keyboardFocused: root.switchboardSelectedIndex === 11
                            onTriggered: root.triggerSwitchboardTile(11)
                        }
                    }
                }

                Column {
                    id: emojiPickerContent
                    anchors.fill: parent
                    spacing: Theme.fontSize / 2
                    visible: root.mode === "emoji"

                    Rectangle {
                        width: parent.width
                        height: Theme.fontSize * 2.2
                        radius: Theme.radius / 2
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        TextInput {
                            id: emojiSearchField
                            anchors.fill: parent
                            anchors.margins: Theme.fontSize / 2
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            clip: true

                            onTextChanged: root.emojiQuery = text

                            Keys.onTabPressed: root.cycleMode()
                            Keys.onEscapePressed: root.resetToAppSearch()
                            Keys.onReturnPressed: root.copySelectedEmoji()
                            Keys.onEnterPressed: root.copySelectedEmoji()
                            Keys.onLeftPressed: {
                                if (root.emojiSelectedIndex > 0)
                                    root.emojiSelectedIndex--;
                            }
                            Keys.onRightPressed: {
                                if (root.emojiSelectedIndex < root.filteredEmoji.length - 1)
                                    root.emojiSelectedIndex++;
                            }
                            Keys.onDownPressed: {
                                var next = root.emojiSelectedIndex + emojiGrid.columns;
                                if (next < root.filteredEmoji.length)
                                    root.emojiSelectedIndex = next;
                            }
                            Keys.onUpPressed: {
                                var prev = root.emojiSelectedIndex - emojiGrid.columns;
                                if (prev >= 0)
                                    root.emojiSelectedIndex = prev;
                            }
                        }
                    }

                    GridView {
                        id: emojiGrid
                        width: parent.width
                        height: parent.height - parent.spacing - (Theme.fontSize * 2.2)
                        clip: true
                        model: root.filteredEmoji
                        currentIndex: root.emojiSelectedIndex

                        readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
                        cellWidth: Theme.fontSize * 2.6
                        cellHeight: cellWidth

                        // Same manually-clamped contentY as resultsList
                        // above (see its comment for why highlightRangeMode
                        // isn't used), just row-based instead of item-based:
                        // the target row is floor(index / columns), not the
                        // index itself.
                        interactive: false
                        boundsBehavior: Flickable.StopAtBounds
                        contentY: {
                            if (root.filteredEmoji.length === 0 || columns === 0)
                                return 0;
                            var row = Math.floor(root.emojiSelectedIndex / columns);
                            var itemY = row * cellHeight;
                            var desired = itemY - (height - cellHeight) / 2;
                            var maxY = Math.max(0, contentHeight - height);
                            return Math.max(0, Math.min(desired, maxY));
                        }

                        Behavior on contentY {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }

                        delegate: Rectangle {
                            id: emojiDelegateRoot
                            required property var modelData
                            required property int index

                            width: emojiGrid.cellWidth
                            height: emojiGrid.cellHeight
                            radius: Theme.radius / 2
                            color: index === root.emojiSelectedIndex ? Theme.accent : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: emojiDelegateRoot.modelData.char
                                // Explicitly Noto Color Emoji, not
                                // Theme.fontFamily (Inter has no emoji
                                // glyphs at all) and not left to font
                                // fallback -- confirmed installed via
                                // fc-list rather than assumed.
                                font.family: "Noto Color Emoji"
                                font.pixelSize: Theme.fontSize * 1.4
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.emojiSelectedIndex = emojiDelegateRoot.index;
                                    root.copySelectedEmoji();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
