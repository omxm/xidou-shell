.pragma library

// Resolves a config "position" string (e.g. "top-right") to PanelWindow
// anchor flags + margins, given a gap from whichever edge the panel sits
// against. Shared by Osd.qml and NotificationPopups.qml so the two panels'
// [osd]/[notification].position settings behave identically instead of
// drifting apart.
//
// Deliberately does NOT add the bar's reserved height to the margin itself:
// Quickshell auto-offsets any panel anchored to the same edge as another
// panel's exclusiveZone (confirmed empirically via Launcher.qml -- a
// margins.top of N on a top-anchored panel lands it at N + the bar's own
// exclusiveZone, not just N). Adding the bar height again here would
// double-count it and push the panel further down than intended.
function resolve(position, screenWidth, panelWidth, gap) {
    var parts = (position || "top-center").split("-");
    var vert = parts[0] === "bottom" ? "bottom" : "top";
    var horiz = parts[1] || "center";

    var result = {
        anchorTop: vert === "top",
        anchorBottom: vert === "bottom",
        anchorLeft: horiz !== "right",
        anchorRight: horiz === "right",
        marginTop: vert === "top" ? gap : 0,
        marginBottom: vert === "bottom" ? gap : 0,
        marginLeft: 0,
        marginRight: 0
    };

    if (horiz === "center")
        result.marginLeft = Math.round((screenWidth - panelWidth) / 2);
    else if (horiz === "left")
        result.marginLeft = gap;
    else if (horiz === "right")
        result.marginRight = gap;

    return result;
}
