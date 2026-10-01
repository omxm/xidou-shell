import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../config"

// Sounds for state that changes outside any one UI action: Wi-Fi and
// Bluetooth, the default sink's volume and mute, DND, Caffeine, Night
// Light, the battery, theme mode, palette generation, and xidouwm's own
// window/tag events. Each maps to an operation in lib/SoundMap.js.
// Clicks in the shell's own UI play their sounds where they happen
// instead; when both see the same action (a Home tile turning Wi-Fi on),
// SoundFx's dedupe keeps it to one sound.
//
// Instantiated once, in shell.qml.
Scope {
    id: root

    // Values are bound once at startup (and again when the default sink
    // changes), which fires every on...Changed handler below once. Nothing
    // plays until things have settled.
    property bool settled: false

    Timer {
        id: settleTimer
        interval: 3000
        running: true
        onTriggered: root.settled = true
    }

    function play(op) {
        if (root.settled)
            SoundFx.play(op);
    }

    // --- xidouwm: tags, layout, floating/fullscreen, actions ------------

    // A send moves the window and then views its new tag; that view is
    // part of the send, so it doesn't get its own forward/back sound.
    property real lastSendAt: 0
    // Dragging a tiled window with the mouse floats it; that float is part
    // of the drag, so it doesn't get a sound of its own either.
    property real lastDragEndAt: 0

    // Lowest selected tag number, so direction comes from explicit tag
    // numbers, never next/prev (CLAUDE.md lesson #6).
    function lowestTag(mask) {
        for (var i = 0; i < 32; i++)
            if (mask & (1 << i))
                return i;
        return -1;
    }

    Connections {
        target: DwmIpc
        function onTagViewChanged(monitor, oldSelected, newSelected) {
            if (Date.now() - root.lastSendAt < 300)
                return;
            var a = root.lowestTag(oldSelected), b = root.lowestTag(newSelected);
            if (a < 0 || b < 0 || a === b)
                return;
            root.play(b > a ? "tag_forward" : "tag_back");
        }
        function onLayoutChanged(monitor) {
            root.play("layout_change");
        }
        function onFocusedStateChanged(oldState, newState) {
            if (!oldState || !newState)
                return;
            if (oldState.is_fullscreen !== newState.is_fullscreen)
                root.play(newState.is_fullscreen ? "fullscreen_on" : "fullscreen_off");
            else if (oldState.is_floating !== newState.is_floating && Date.now() - root.lastDragEndAt > 300)
                root.play(newState.is_floating ? "float_on" : "float_off");
        }
        function onWmAction(action) {
            switch (action) {
            case "kill": root.play("window_close"); break;
            case "send": root.lastSendAt = Date.now(); root.play("window_send"); break;
            case "swap": root.play("window_swap"); break;
            case "focus": root.play("window_focus"); break;
            case "move_start": case "resize_start": root.play("drag_start"); break;
            case "move_end": case "resize_end": root.lastDragEndAt = Date.now(); root.play("drag_end"); break;
            }
        }
    }

    // --- volume and mute (the default sink, from any source) ------------

    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    readonly property real sinkVolume: root.sink && root.sink.audio ? root.sink.audio.volume : -1
    readonly property bool sinkMuted: root.sink && root.sink.audio ? root.sink.audio.muted : false

    onSinkChanged: {
        root.settled = false;
        settleTimer.interval = 1000;
        settleTimer.restart();
    }
    // Played at the new level, since it goes through the sink itself.
    onSinkVolumeChanged: root.play("volume_change")
    onSinkMutedChanged: root.play(root.sinkMuted ? "mute" : "unmute")

    // --- notifications, caffeine, night light, theme --------------------

    Connections {
        target: Notifications
        function onDndChanged() {
            root.play(Notifications.dnd ? "dnd_on" : "dnd_off");
        }
    }

    Connections {
        target: CaffeineService
        function onActiveChanged() {
            root.play(CaffeineService.active ? "caffeine_on" : "caffeine_off");
        }
    }

    Connections {
        target: NightLightService
        function onActiveChanged() {
            root.play(NightLightService.active ? "nightlight_on" : "nightlight_off");
        }
    }

    readonly property string themeMode: Config.data.theme.mode
    onThemeModeChanged: {
        if (root.themeMode === "dark")
            root.play("theme_dark");
        else if (root.themeMode === "light")
            root.play("theme_light");
    }

    Connections {
        target: ColorScheme
        function onGeneratingChanged() {
            if (ColorScheme.generating) {
                SoundFx.startLoop("palette_generating", "palette");
            } else {
                SoundFx.stopLoop("palette");
                root.play(ColorScheme.lastError ? "palette_failed" : "palette_done");
            }
        }
    }

    // --- Wi-Fi and Bluetooth ---------------------------------------------

    readonly property bool wifiEnabled: Networking.wifiEnabled
    onWifiEnabledChanged: root.play(root.wifiEnabled ? "wifi_on" : "wifi_off")

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: root.adapter ? root.adapter.enabled : false
    onBtEnabledChanged: root.play(root.btEnabled ? "bt_on" : "bt_off")

    readonly property bool btDiscovering: root.adapter ? root.adapter.discovering : false
    onBtDiscoveringChanged: {
        if (root.btDiscovering && root.settled)
            SoundFx.startLoop("bt_scanning", "bt-scan");
        else
            SoundFx.stopLoop("bt-scan");
    }

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                root.play(modelData.connected ? "net_connected" : "net_disconnected");
            }
        }
    }

    readonly property var wifiDevice: {
        var devices = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        return null;
    }

    Instantiator {
        model: root.wifiDevice ? root.wifiDevice.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                SoundFx.stopLoop("net-" + modelData.name);
                root.play(modelData.connected ? "net_connected" : "net_disconnected");
            }
            function onStateChangingChanged() {
                if (modelData.stateChanging && root.settled)
                    SoundFx.startLoop("net_connecting", "net-" + modelData.name);
                else
                    SoundFx.stopLoop("net-" + modelData.name);
            }
            function onConnectionFailed(reason) {
                SoundFx.stopLoop("net-" + modelData.name);
                root.play("net_failed");
            }
        }
    }

    // --- battery and charger --------------------------------------------

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: root.battery && root.battery.isLaptopBattery
    readonly property int batteryState: root.hasBattery ? root.battery.state : -1
    readonly property int percent: root.hasBattery ? Math.round(root.battery.percentage * 100) : -1
    readonly property int lowThreshold: Config.data.bar_widgets.power.low_battery_threshold
    readonly property int criticalThreshold: 5

    readonly property bool onAc: root.batteryState === UPowerDeviceState.Charging
        || root.batteryState === UPowerDeviceState.FullyCharged
        || root.batteryState === UPowerDeviceState.PendingCharge
    property int lastState: -1

    onOnAcChanged: {
        if (root.batteryState >= 0 && root.batteryState !== UPowerDeviceState.Unknown)
            root.play(root.onAc ? "charger_plugged" : "charger_unplugged");
    }
    onBatteryStateChanged: {
        // Charging stopped while still plugged in: the charge limit (TLP's
        // stop threshold) or full.
        if (root.lastState === UPowerDeviceState.Charging
                && (root.batteryState === UPowerDeviceState.FullyCharged
                    || root.batteryState === UPowerDeviceState.PendingCharge))
            root.play("charge_limit");
        root.lastState = root.batteryState;
    }

    property int lastPercent: -1
    onPercentChanged: {
        var prev = root.lastPercent;
        root.lastPercent = root.percent;
        if (prev < 0 || root.onAc)
            return;
        if (prev > root.criticalThreshold && root.percent <= root.criticalThreshold)
            root.play("battery_critical");
        else if (prev > root.lowThreshold && root.percent <= root.lowThreshold)
            root.play("battery_low");
    }
}
