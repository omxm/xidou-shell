// Operation -> sound cue table for services/SoundFx.qml. This is
// docs/ROADMAP.md section 7 ("Sound map") in code form, one entry per row
// whose feature exists today. Rows marked "(planned)" there get an entry
// when their feature lands. Callers name the operation, never the cue, so
// remapping a sound means editing this file only.
//
// Each entry: cue (a file in assets/sounds/zen/), category (a [sound.<id>]
// table), on (false = off by default; add the operation's id to that
// category's `extra` list in config.toml to hear it), and, for incoming
// notifications only, incoming: true (the only sounds Do Not Disturb
// silences). loop: true entries are started with SoundFx.startLoop().

.pragma library

var CATEGORIES = [
    { id: "panels", label: "Panels & Navigation", preview: "panel_open" },
    { id: "controls", label: "Controls", preview: "toggle_on" },
    { id: "windows", label: "Windows & Workspaces", preview: "tag_forward" },
    { id: "media", label: "Media & Volume", preview: "volume_change" },
    { id: "notifications", label: "Notifications", preview: "notify" },
    { id: "capture", label: "Capture & Clipboard", preview: "screenshot" },
    { id: "devices", label: "Devices & Network", preview: "net_connected" },
    { id: "session", label: "Power & Session", preview: "lock" },
    { id: "system", label: "Theme & System", preview: "wallpaper_changed" }
];

var OPS = {
    // 1. Panels & navigation
    panel_open: { cue: "open", category: "panels", on: true, label: "Open a panel" },
    panel_close: { cue: "close", category: "panels", on: true, label: "Close a panel" },
    launcher_mode: { cue: "forward", category: "panels", on: true, label: "Launcher mode switch (Tab)" },
    app_launch: { cue: "start", category: "panels", on: true, label: "Launch an app" },
    launcher_move: { cue: "hover", category: "panels", on: false, label: "Launcher selection move" },
    search_typing: { cue: "typing", category: "panels", on: false, label: "Typing in a search field" },
    tab_switch: { cue: "select", category: "panels", on: true, label: "Sidebar / sub-tab switch" },
    gear_open: { cue: "expand", category: "panels", on: true, label: "Open a widget's gear panel" },
    gear_close: { cue: "collapse", category: "panels", on: true, label: "Leave a widget's gear panel" },

    // 2. Controls
    toggle_on: { cue: "toggle-on", category: "controls", on: true, label: "Toggle switched on" },
    toggle_off: { cue: "toggle-off", category: "controls", on: true, label: "Toggle switched off" },
    option_select: { cue: "select", category: "controls", on: true, label: "Choose an option" },
    stepper: { cue: "progress-step", category: "controls", on: true, label: "Stepper / slider step" },
    text_commit: { cue: "check", category: "controls", on: true, label: "Commit a text field" },
    item_add: { cue: "select", category: "controls", on: true, label: "Add a list item, module on" },
    item_remove: { cue: "deselect", category: "controls", on: true, label: "Remove a list item, module off" },
    reorder: { cue: "reorder", category: "controls", on: true, label: "Reorder a module, move it between lanes" },
    reset: { cue: "undo", category: "controls", on: true, label: "Reset a setting" },
    reset_page: { cue: "undo", category: "controls", on: true, label: "Reset Page" },
    bar_hover: { cue: "hover", category: "controls", on: false, label: "Hover a bar widget" },
    bar_press: { cue: "press", category: "controls", on: false, label: "Click a bar widget" },

    // 3. Windows & workspaces
    tag_forward: { cue: "forward", category: "windows", on: true, label: "View a higher-numbered tag" },
    tag_back: { cue: "back", category: "windows", on: true, label: "View a lower-numbered tag" },
    window_send: { cue: "send", category: "windows", on: true, label: "Send a window to another tag" },
    window_close: { cue: "collapse", category: "windows", on: true, label: "Close a window" },
    float_on: { cue: "drag-start", category: "windows", on: true, label: "Floating on" },
    float_off: { cue: "snap", category: "windows", on: true, label: "Floating off" },
    fullscreen_on: { cue: "expand", category: "windows", on: true, label: "Fullscreen on" },
    fullscreen_off: { cue: "collapse", category: "windows", on: true, label: "Fullscreen off" },
    window_swap: { cue: "reorder", category: "windows", on: true, label: "Directional swap" },
    window_focus: { cue: "focus", category: "windows", on: false, label: "Directional focus" },
    layout_change: { cue: "select", category: "windows", on: true, label: "Layout change" },
    drag_start: { cue: "drag-start", category: "windows", on: true, label: "Mouse move/resize start" },
    drag_end: { cue: "drop", category: "windows", on: true, label: "Mouse move/resize end" },

    // 4. Media & volume
    volume_change: { cue: "volume-change", category: "media", on: true, label: "Volume up/down" },
    mute: { cue: "toggle-off", category: "media", on: true, label: "Mute" },
    unmute: { cue: "toggle-on", category: "media", on: true, label: "Unmute" },
    media_play: { cue: "play", category: "media", on: true, label: "Play" },
    media_pause: { cue: "pause", category: "media", on: true, label: "Pause" },
    media_next: { cue: "skip-next", category: "media", on: true, label: "Next track" },
    media_previous: { cue: "skip-previous", category: "media", on: true, label: "Previous track" },
    media_seek: { cue: "seek", category: "media", on: true, label: "Seek" },
    app_volume: { cue: "volume-change", category: "media", on: true, label: "Per-app volume" },
    audio_device: { cue: "select", category: "media", on: true, label: "Switch audio output/input" },
    brightness: { cue: "progress-step", category: "media", on: false, label: "Brightness up/down" },

    // 5. Notifications (incoming ones are the only sounds DND silences)
    notify: { cue: "notification", category: "notifications", on: true, incoming: true, label: "Normal notification" },
    notify_critical: { cue: "warning", category: "notifications", on: true, incoming: true, label: "Critical notification" },
    notify_message: { cue: "receive", category: "notifications", on: true, incoming: true, label: "Message (im.received)" },
    notify_low: { cue: "info", category: "notifications", on: false, incoming: true, label: "Low-urgency notification" },
    notify_dismiss: { cue: "close", category: "notifications", on: false, label: "Dismiss a notification" },
    notify_clear: { cue: "delete", category: "notifications", on: true, label: "Clear all" },
    dnd_on: { cue: "toggle-on", category: "notifications", on: true, label: "Do Not Disturb on" },
    dnd_off: { cue: "toggle-off", category: "notifications", on: true, label: "Do Not Disturb off" },

    // 6. Capture & clipboard
    screenshot: { cue: "snap", category: "capture", on: true, label: "Screenshot taken" },
    region_start: { cue: "start", category: "capture", on: true, label: "Region select start" },
    region_cancel: { cue: "cancel", category: "capture", on: true, label: "Region select cancel" },
    capture_save: { cue: "success", category: "capture", on: true, label: "Save a capture" },
    capture_copy: { cue: "copy", category: "capture", on: true, label: "Copy a capture only" },
    capture_delete: { cue: "delete", category: "capture", on: true, label: "Delete a capture" },
    clip_restore: { cue: "paste", category: "capture", on: true, label: "Restore from clipboard history" },
    clip_delete: { cue: "delete", category: "capture", on: true, label: "Delete a history entry" },
    emoji_pick: { cue: "reaction", category: "capture", on: true, label: "Pick an emoji" },
    clip_any: { cue: "copy", category: "capture", on: false, label: "Any copy in any app" },

    // 7. Devices & network
    wifi_on: { cue: "toggle-on", category: "devices", on: true, label: "Wi-Fi on" },
    wifi_off: { cue: "toggle-off", category: "devices", on: true, label: "Wi-Fi off" },
    bt_on: { cue: "toggle-on", category: "devices", on: true, label: "Bluetooth on" },
    bt_off: { cue: "toggle-off", category: "devices", on: true, label: "Bluetooth off" },
    net_connecting: { cue: "connecting", category: "devices", on: false, loop: true, label: "Connecting (loop)" },
    bt_scanning: { cue: "scanning", category: "devices", on: false, loop: true, label: "Bluetooth scanning (loop)" },
    net_connected: { cue: "connect", category: "devices", on: true, label: "Connected (Wi-Fi, Bluetooth device)" },
    net_disconnected: { cue: "disconnect", category: "devices", on: true, label: "Disconnected" },
    net_failed: { cue: "error", category: "devices", on: true, label: "Connection failed" },

    // 8. Power & session
    lock: { cue: "lock", category: "session", on: true, label: "Lock" },
    unlock: { cue: "unlock", category: "session", on: true, label: "Unlock" },
    wrong_password: { cue: "blocked", category: "session", on: true, label: "Wrong password" },
    session_end: { cue: "stop", category: "session", on: true, label: "Log out / restart / shut down" },
    charger_plugged: { cue: "connect", category: "session", on: true, label: "Charger plugged" },
    charger_unplugged: { cue: "disconnect", category: "session", on: true, label: "Charger unplugged" },
    battery_low: { cue: "warning", category: "session", on: true, label: "Battery low" },
    battery_critical: { cue: "error", category: "session", on: true, label: "Battery critical" },
    charge_limit: { cue: "complete", category: "session", on: true, label: "Reached charge limit" },
    caffeine_on: { cue: "toggle-on", category: "session", on: true, label: "Caffeine on" },
    caffeine_off: { cue: "toggle-off", category: "session", on: true, label: "Caffeine off" },
    nightlight_on: { cue: "toggle-on", category: "session", on: true, label: "Night Light on" },
    nightlight_off: { cue: "toggle-off", category: "session", on: true, label: "Night Light off" },

    // 9. Theme & system
    wallpaper_changed: { cue: "swipe", category: "system", on: true, label: "Wallpaper changed" },
    palette_generating: { cue: "processing", category: "system", on: false, loop: true, label: "Palette generating (loop)" },
    palette_done: { cue: "complete", category: "system", on: true, label: "Palette done" },
    palette_failed: { cue: "error", category: "system", on: true, label: "Palette failed" },
    theme_dark: { cue: "sleep", category: "system", on: true, label: "Switch to dark" },
    theme_light: { cue: "wake", category: "system", on: true, label: "Switch to light" }
};

// Per-cue minimum gap between two plays, in ms, for cues that repeat
// quickly (key repeat, wheel). Mirrors uisfx's own SEMANTIC_COOLDOWNS, with
// volume-change raised to M22's ~80 ms.
var COOLDOWN_MS = {
    "hover": 60,
    "focus": 80,
    "progress-step": 80,
    "volume-change": 80
};

// Any cue played again within this many ms is dropped, so one action that
// is seen from two places (a Home tile and the Wi-Fi state watcher) sounds
// once.
var DEDUPE_MS = 60;

// The operations of one category, for the Sound page's "What plays here".
function opsIn(category) {
    var out = [];
    for (var id in OPS)
        if (OPS[id].category === category)
            out.push({ id: id, label: OPS[id].label, on: OPS[id].on });
    return out;
}

// Gain for one operation: cue default x category volume x master volume,
// or 0 when anything on the way is off. Pure, so it can be checked without
// any audio. `sound` is Config.data.sound; `cueVolumes` maps cue -> default
// volume (assets/sounds/zen/cues.json); `dnd` is Do Not Disturb.
function gain(opId, sound, cueVolumes, dnd) {
    var op = OPS[opId];
    if (!op || !sound || !sound.enabled)
        return 0;
    var cat = sound[op.category];
    if (!cat || !cat.enabled)
        return 0;
    if (!op.on && (cat.extra || []).indexOf(opId) === -1)
        return 0;
    if (op.incoming && dnd)
        return 0;
    var base = cueVolumes[op.cue];
    if (base === undefined)
        return 0;
    return clamp01(base) * clamp01(cat.volume) * clamp01(sound.volume);
}

function clamp01(v) {
    var n = Number(v);
    if (isNaN(n))
        return 0;
    return Math.max(0, Math.min(1, n));
}
