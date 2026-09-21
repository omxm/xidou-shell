.pragma library

// Regenerates the marker-bounded animations block inside session/picom.conf
// from config.toml's [motion] table. picom.conf is libconfig syntax, not
// TOML, so Toml.js's parser doesn't apply here -- this deliberately does NOT
// parse picom.conf at all. It just finds two sentinel comment lines and
// replaces the text between them verbatim, leaving everything else in the
// file (backend, corner-radius, round-borders, etc.) untouched byte-for-byte.

var START_MARKER = "# >>> XIDOU MANAGED: motion (Settings > Appearance > Motion) -- hand-edits here are overwritten on the next change >>>";
var END_MARKER = "# <<< XIDOU MANAGED: motion <<<";

// Intensity levels, not an easing curve -- picom's "appear"/"disappear"
// preset only exposes scale+duration (confirmed against its manpage's
// Presets section), no curve/timing-function param. Real easing control
// would mean replacing the preset with hand-written Advanced-syntax scripts;
// explicit call (asked and answered) was to stay on the preset and ship
// intensity levels only.
var PRESET_SCALES = {
    subtle: 0.97,
    normal: 0.92,
    pronounced: 0.85
};

// Returns just the block's inner text (no markers), or "" when disabled --
// an empty string means no `animations` key is emitted at all, i.e. picom
// behaves exactly as it did before Stage 1 existed.
function buildAnimationsBlock(motion) {
    if (!motion || !motion.enabled)
        return "";

    var scale = PRESET_SCALES[motion.preset];
    if (scale === undefined) {
        console.warn("[xidou] PicomSync: unknown motion.preset \"" + motion.preset + "\" -- falling back to \"normal\"");
        scale = PRESET_SCALES.normal;
    }
    var duration = motion.duration;

    return "animations = (\n" + "    {\n" + "        triggers = [ \"open\", \"show\" ];\n" + "        preset = \"appear\";\n" + "        scale = " + scale + ";\n" + "        duration = " + duration + ";\n" + "    },\n" + "    {\n" + "        triggers = [ \"close\", \"hide\" ];\n" + "        preset = \"disappear\";\n" + "        scale = " + scale + ";\n" + "        duration = " + duration + ";\n" + "    }\n" + ");";
}

// Replaces the text strictly between START_MARKER and END_MARKER (the marker
// lines themselves are preserved) with `blockText`. Returns null -- rather
// than guessing where to insert markers that aren't there -- if either
// marker is missing, so the caller can warn instead of corrupting the file.
function spliceBlock(fileText, blockText) {
    var startIdx = fileText.indexOf(START_MARKER);
    var endIdx = fileText.indexOf(END_MARKER);
    if (startIdx === -1 || endIdx === -1 || endIdx < startIdx)
        return null;

    var beforeAndMarker = fileText.slice(0, startIdx + START_MARKER.length);
    var afterMarker = fileText.slice(endIdx);

    var middle = blockText.length > 0 ? ("\n" + blockText + "\n") : "\n";
    return beforeAndMarker + middle + afterMarker;
}
