.pragma library

// Parses the real system emoji-test.txt (package: unicode-emoji, installed
// via pacman) rather than bundling a hand-rolled JSON list -- see
// CLAUDE.md-adjacent project conventions (matugen for colors, DesktopEntries
// for app metadata): shell out to / read real system data, don't
// reimplement it. Format (one entry per line, comments start with #):
//
//   1F408                    ; fully-qualified     # 🐈 E0.7 cat
//   1F408 200D 2B1B          ; fully-qualified     # 🐈‍⬛ E13.0 black cat
//
// Only "fully-qualified" status is kept -- "minimally-qualified"/
// "unqualified" are display variants of the same emoji, and "component"
// (skin tone/hair modifiers) are never meaningful as standalone picks. The
// actual glyph is derived from the codepoints ourselves (String.fromCodePoint)
// rather than trusting the comment's embedded glyph, since only the
// codepoints are the actual data -- the comment is documentation.
//
// Entries come out in the file's own CLDR display order, which this parser
// preserves via an explicit `order` field (not just array position) so a
// caller can tiebreak on it even after re-sorting -- e.g. UsageStats.qml
// sorting by usage count first, falling back to CLDR order for untouched
// entries.

var LINE_RE = /^([0-9A-Fa-f ]+?)\s*;\s*(\S+)\s*#\s*\S+\s+E\d+(?:\.\d+)?\s+(.+)$/;

function parse(text) {
    var lines = text.split(/\r\n|\n|\r/);
    var out = [];
    var order = 0;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var m = line.match(LINE_RE);
        if (!m)
            continue;
        if (m[2] !== "fully-qualified")
            continue;
        var codepoints = m[1].trim().split(/\s+/);
        var chars = "";
        for (var j = 0; j < codepoints.length; j++)
            chars += String.fromCodePoint(parseInt(codepoints[j], 16));
        out.push({
            char: chars,
            name: m[3],
            order: order++
        });
    }
    return out;
}
