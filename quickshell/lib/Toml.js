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
