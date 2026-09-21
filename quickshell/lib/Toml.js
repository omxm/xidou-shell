.pragma library

// Minimal TOML-subset parser, covering exactly what config.example.toml uses:
// comments, [table] / [dotted.table] headers, string/number/bool values, and
// flat arrays of those. Not spec-complete (no multi-line strings, inline
// tables, dates, or array-of-tables) — extend here if the schema grows.

function parse(input) {
    var root = {};
    var current = root;
    var lines = input.split(/\r\n|\n|\r/);

    for (var i = 0; i < lines.length; i++) {
        var line = stripComment(lines[i]).trim();
        if (line.length === 0)
            continue;

        if (line[0] === "[") {
            var end = line.indexOf("]");
            if (end === -1)
                continue;
            var header = line.slice(1, end).trim();
            current = tableFor(root, header);
            continue;
        }

        var eq = topLevelIndexOf(line, "=");
        if (eq === -1)
            continue;

        var key = line.slice(0, eq).trim();
        var rawValue = line.slice(eq + 1).trim();
        if (key.length === 0 || rawValue.length === 0)
            continue;

        current[key] = parseValue(rawValue);
    }

    return root;
}

function tableFor(root, header) {
    var parts = header.split(".");
    var node = root;
    for (var i = 0; i < parts.length; i++) {
        var key = parts[i].trim();
        if (typeof node[key] !== "object" || node[key] === null || Array.isArray(node[key]))
            node[key] = {};
        node = node[key];
    }
    return node;
}

function stripComment(line) {
    var inSingle = false, inDouble = false;
    for (var i = 0; i < line.length; i++) {
        var c = line[i];
        if (c === "'" && !inDouble)
            inSingle = !inSingle;
        else if (c === "\"" && !inSingle && line[i - 1] !== "\\")
            inDouble = !inDouble;
        else if (c === "#" && !inSingle && !inDouble)
            return line.slice(0, i);
    }
    return line;
}

function topLevelIndexOf(line, ch) {
    var inSingle = false, inDouble = false;
    for (var i = 0; i < line.length; i++) {
        var c = line[i];
        if (c === "'" && !inDouble)
            inSingle = !inSingle;
        else if (c === "\"" && !inSingle && line[i - 1] !== "\\")
            inDouble = !inDouble;
        else if (c === ch && !inSingle && !inDouble)
            return i;
    }
    return -1;
}

function splitTopLevel(text, sep) {
    var parts = [];
    var depth = 0, inSingle = false, inDouble = false, start = 0;
    for (var i = 0; i < text.length; i++) {
        var c = text[i];
        if (c === "'" && !inDouble)
            inSingle = !inSingle;
        else if (c === "\"" && !inSingle && text[i - 1] !== "\\")
            inDouble = !inDouble;
        else if (!inSingle && !inDouble) {
            if (c === "[")
                depth++;
            else if (c === "]")
                depth--;
            else if (c === sep && depth === 0) {
                parts.push(text.slice(start, i));
                start = i + 1;
            }
        }
    }
    var last = text.slice(start);
    if (last.trim().length > 0)
        parts.push(last);
    return parts;
}

function parseValue(raw) {
    raw = raw.trim();

    if (raw[0] === "\"" || raw[0] === "'")
        return parseString(raw);

    if (raw[0] === "[") {
        var inner = raw.slice(1, raw.lastIndexOf("]"));
        return splitTopLevel(inner, ",").map(function (part) {
            return parseValue(part.trim());
        });
    }

    if (raw === "true")
        return true;
    if (raw === "false")
        return false;

    if (/^-?\d+(\.\d+)?$/.test(raw))
        return raw.indexOf(".") === -1 ? parseInt(raw, 10) : parseFloat(raw);

    // Bare/unquoted fallback — forgiving rather than spec-strict.
    return raw;
}

function parseString(raw) {
    var quote = raw[0];
    var end = raw.lastIndexOf(quote);
    var body = end > 0 ? raw.slice(1, end) : raw.slice(1);

    if (quote === "'")
        return body; // TOML literal strings: no escape processing.

    return body
        .replace(/\\n/g, "\n")
        .replace(/\\t/g, "\t")
        .replace(/\\r/g, "\r")
        .replace(/\\"/g, "\"")
        .replace(/\\\\/g, "\\");
}

// --- writing ------------------------------------------------------------
//
// setValue() edits config.toml in place: it finds the target table/key by
// re-walking the raw text with the same comment/quote-aware scanning parse()
// uses, replaces only the value substring of the matching line (or inserts
// a new "key = value" line/table when one doesn't exist yet), and leaves
// every other byte -- comments, spacing, unrelated sections, key order --
// untouched. Never regenerate the whole file from the parsed JS object: that
// would nuke comments and any manual edits, which is the entire reason this
// exists instead of just `JSON.stringify`-ing a new file. Settings-panel
// writes are the only intended caller.

function serializeValue(value) {
    if (typeof value === "string")
        return serializeString(value);
    if (typeof value === "boolean")
        return value ? "true" : "false";
    if (typeof value === "number")
        return String(value);
    if (Array.isArray(value))
        return "[" + value.map(serializeValue).join(", ") + "]";
    // Fallback: coerce to a string rather than emit invalid TOML.
    return serializeString(String(value));
}

function serializeString(s) {
    return "\"" + s
        .replace(/\\/g, "\\\\")
        .replace(/"/g, "\\\"")
        .replace(/\n/g, "\\n")
        .replace(/\t/g, "\\t")
        .replace(/\r/g, "\\r") + "\"";
}

// Index of the last non-whitespace character in `s`, or -1 if `s` is empty
// or all whitespace.
function lastNonSpaceIndex(s) {
    var i = s.length - 1;
    while (i >= 0 && /\s/.test(s[i]))
        i--;
    return i;
}

// Returns the [start, end) line range of `tableHeader`'s body within
// `lines` (exclusive of the header line itself, and of the next header),
// or null if that table doesn't appear at all. `tableHeader` is the exact
// dotted string that appears inside the brackets, e.g. "panels.clipboard".
function findTableRange(lines, tableHeader) {
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
        var stripped = stripComment(lines[i]).trim();
        if (stripped.length === 0 || stripped[0] !== "[")
            continue;
        var end = stripped.indexOf("]");
        if (end === -1)
            continue;
        var header = stripped.slice(1, end).trim();
        if (start !== -1)
            return {
                start: start,
                end: i
            }; // next header found -- previous table's body ends here
        if (header === tableHeader)
            start = i + 1;
    }
    if (start === -1)
        return null;
    return {
        start: start,
        end: lines.length
    };
}

// Sets `key` to `value` inside `[tableHeader]` within TOML text `text`,
// preserving every other line byte-for-byte. Updates the key in place if it
// already has a line in that table (keeping indentation, spacing around
// "=", and any trailing inline comment); otherwise inserts a new
// "key = value" line right after the header. If the table itself doesn't
// exist yet, appends a new "[tableHeader]" section at the end of the file.
function setValue(text, tableHeader, key, value) {
    var newline = text.indexOf("\r\n") !== -1 ? "\r\n" : "\n";
    var lines = text.split(/\r\n|\n|\r/);
    var serialized = serializeValue(value);

    var range = findTableRange(lines, tableHeader);
    if (range === null) {
        var out = lines.slice();
        if (out.length > 0 && out[out.length - 1].trim().length > 0)
            out.push("");
        out.push("[" + tableHeader + "]");
        out.push(key + " = " + serialized);
        return out.join(newline);
    }

    for (var j = range.start; j < range.end; j++) {
        var strippedLine = stripComment(lines[j]);
        if (strippedLine.trim().length === 0)
            continue;
        var eq = topLevelIndexOf(strippedLine, "=");
        if (eq === -1)
            continue;
        if (strippedLine.slice(0, eq).trim() !== key)
            continue;

        var valueRegion = strippedLine.slice(eq + 1);
        var firstNonSpace = valueRegion.search(/\S/);
        if (firstNonSpace === -1)
            continue; // malformed ("key =" with no value) -- leave it alone

        var lastNonSpaceRel = lastNonSpaceIndex(valueRegion);
        var valueEndAbs = (eq + 1) + lastNonSpaceRel; // inclusive, indexes into lines[j] too (strippedLine is a prefix of it)

        var keyPart = lines[j].slice(0, eq + 1);
        var leadingSpace = valueRegion.slice(0, firstNonSpace);
        var trailingPart = lines[j].slice(valueEndAbs + 1); // trailing whitespace + any inline comment, verbatim

        lines[j] = keyPart + leadingSpace + serialized + trailingPart;
        return lines.join(newline);
    }

    // Table exists but this key doesn't have a line yet -- add one right
    // after the header rather than leaving it silently unset.
    lines.splice(range.start, 0, key + " = " + serialized);
    return lines.join(newline);
}
