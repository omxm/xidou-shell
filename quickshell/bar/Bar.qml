import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import "../config"
import "../services"
import "modules" as Modules

// The bar panel: a single PanelWindow reserving strut space, top or bottom
// per config.toml [bar].position. Left/center/right module lists are read
// from config and resolved against `moduleComponents` below — an unknown
// module name is skipped with a warning rather than rendered broken, so a
// typo in modules_left/center/right degrades gracefully instead of crashing
// the bar.
PanelWindow {
    id: bar

    property int monitorNum: 0

    readonly property var barConfig: Config.data.bar
    readonly property var layoutCfg: barConfig.layout
    readonly property var shapeCfg: barConfig.shape
    readonly property var effectsCfg: barConfig.effects
    readonly property var widgetsCfg: barConfig.widgets
    readonly property bool onTop: barConfig.position !== "bottom"

    // -1 means "inherit corner_radius" (0 is a real, different, selectable
    // state: explicitly square). Each is further clamped to half of the
    // bar's *current* (width, height) at render time, same reasoning as the
    // capsule radius clamp -- crucially using bar.effectiveHeight (declared
    // below), not barConfig.height, so the Auto-Hide sliver state (as low
    // as 3px) never renders a distorted over-rounded corner just because
    // the configured radius assumed the bar's full thickness.
    function effectiveCornerRadius(perCorner) {
        var raw = perCorner >= 0 ? perCorner : bar.shapeCfg.corner_radius;
        return Math.min(raw, bar.effectiveHeight / 2);
    }
    readonly property real topLeftRadius: bar.effectiveCornerRadius(bar.shapeCfg.top_left_radius)
    readonly property real topRightRadius: bar.effectiveCornerRadius(bar.shapeCfg.top_right_radius)
    readonly property real bottomLeftRadius: bar.effectiveCornerRadius(bar.shapeCfg.bottom_left_radius)
    readonly property real bottomRightRadius: bar.effectiveCornerRadius(bar.shapeCfg.bottom_right_radius)

    // Corner Flow only means anything when the bar is flush against the
    // screen -- with any Ends/Edge Margin, the bar's corner isn't AT the
    // screen's true corner at all, so there's no edge for it to flow into.
    readonly property bool cornerFlowActive: bar.shapeCfg.corner_flow
        && bar.layoutCfg.edge_margin === 0
        && bar.layoutCfg.ends_margin === 0

    readonly property var capsuleCfg: barConfig.capsules
    // Fill is a Theme role name (config.example.toml's own comment lists
    // the valid values), never a literal hex -- same "no color literals
    // outside Theme.qml" rule as every other panel. Falls back to
    // surfaceAlt on an unrecognized/typo'd role rather than rendering an
    // undefined color.
    readonly property var capsuleFillRoles: ({
        "surface": Theme.surface,
        "surface_alt": Theme.surfaceAlt,
        "accent": Theme.accent,
        "background": Theme.background
    })
    readonly property color capsuleFillColor: bar.capsuleFillRoles[bar.capsuleCfg.fill] || Theme.surfaceAlt

    // Auto-Hide: "on" always auto-hides; "smart" only auto-hides while the
    // currently-viewed tag on this bar's own monitor actually has a client
    // on it (empty tag -> behaves like "off", bar stays fully shown).
    // tag_state's selected/occupied are both bitmasks (xidouwm/yajl_dumps.c) --
    // a nonzero AND means the selected tag is one of the occupied ones.
    readonly property var monitorState: DwmIpc.monitorsByNum[bar.monitorNum]
    readonly property bool tagOccupied: {
        var ts = bar.monitorState ? bar.monitorState.tag_state : null;
        return !!(ts && (ts.occupied & ts.selected));
    }
    readonly property bool autoHideActive: barConfig.auto_hide !== "off"
    readonly property bool shouldAutoHideNow: barConfig.auto_hide === "on"
        || (barConfig.auto_hide === "smart" && bar.tagOccupied)

    // True the instant the pointer enters the bar's own screen area (which,
    // collapsed, is just the thin sliver -- exactly the intended hover
    // target) -- hideTimer below adds a short grace period before actually
    // collapsing back so moving the pointer across a widget near the sliver
    // boundary doesn't flicker.
    property bool hovered: false
    readonly property bool revealed: !bar.shouldAutoHideNow || bar.hovered

    readonly property int sliverHeight: 3
    readonly property int effectiveHeight: bar.autoHideActive
        ? (bar.revealed ? barConfig.height : bar.sliverHeight)
        : barConfig.height

    implicitHeight: bar.effectiveHeight
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Motion.normal
            easing.type: Motion.standard
        }
    }

    // A bar that's mostly hidden can't sensibly reserve permanent strut
    // space -- forced to 0 regardless of reserve_space while auto-hiding is
    // active at all (not just while actually collapsed), so windows don't
    // resize every time the bar reveals/hides. When it does reserve space,
    // the reservation covers edge_margin + the bar's own thickness +
    // opposite_edge_margin (the full span between the screen edge and where
    // windows may start), minus panel_overlap (Advanced -- lets windows
    // tile up under the bar's edge by that many px instead).
    exclusiveZone: (bar.autoHideActive || !barConfig.reserve_space)
        ? 0
        : Math.max(0, bar.layoutCfg.edge_margin + barConfig.height + bar.layoutCfg.opposite_edge_margin - bar.layoutCfg.panel_overlap)
    visible: barConfig.enabled
    // The PanelWindow itself paints nothing -- Window.color has no radius
    // property (that's Rectangle-only), so real corner rounding means the
    // window is transparent and an inner Rectangle does the actual
    // painting instead, same pattern Osd.qml already established for a
    // rounded floating panel. Real ARGB transparency here already depends
    // on picom, an existing hard session dependency (CLAUDE.md's daemon
    // list), not a new one this introduces.
    color: "transparent"

    anchors.left: true
    anchors.right: true
    anchors.top: onTop
    anchors.bottom: !onTop
    // Ends Margin (shortens the bar from both horizontal ends) + Edge
    // Margin (lifts it off the screen edge it's anchored to) together are
    // what makes a "floating bar" -- both apply unconditionally regardless
    // of position; only whichever vertical margin corresponds to the
    // actually-anchored edge (top or bottom) has any visible effect, so
    // setting both is harmless.
    margins.left: bar.layoutCfg.ends_margin
    margins.right: bar.layoutCfg.ends_margin
    margins.top: bar.layoutCfg.edge_margin
    margins.bottom: bar.layoutCfg.edge_margin

    readonly property var moduleComponents: ({
        logo: logoComponent,
        workspaces: workspacesComponent,
        clock: clockComponent,
        media: mediaComponent,
        weather: weatherComponent,
        tray: trayComponent,
        mem: memComponent,
        cpu: cpuComponent,
        bluetooth: bluetoothComponent,
        volume: volumeComponent,
        dnd: dndComponent,
        power: powerComponent
    })

    function resolveModules(names) {
        var out = [];
        for (var i = 0; i < names.length; i++) {
            var name = names[i];
            if (moduleComponents[name]) {
                out.push({ name: name, component: moduleComponents[name] });
            } else {
                console.warn("[xidou] bar: module '" + name + "' is not implemented yet, skipping");
            }
        }
        return out;
    }

    Component {
        id: logoComponent
        Modules.Logo {}
    }

    Component {
        id: workspacesComponent
        Modules.Workspaces { monitorNum: bar.monitorNum }
    }

    Component {
        id: clockComponent
        Modules.Clock {}
    }

    Component {
        id: mediaComponent
        Modules.Media {}
    }

    Component {
        id: weatherComponent
        Modules.Weather {}
    }

    Component {
        id: trayComponent
        Modules.Tray {}
    }

    Component {
        id: memComponent
        Modules.Mem {}
    }

    Component {
        id: cpuComponent
        Modules.Cpu {}
    }

    Component {
        id: bluetoothComponent
        Modules.Bluetooth {}
    }

    Component {
        id: volumeComponent
        Modules.Volume {}
    }

    Component {
        id: dndComponent
        Modules.Dnd {}
    }

    Component {
        id: powerComponent
        Modules.Power {}
    }

    // Shared by all three lane Repeaters below -- wraps a module's Loader in
    // a capsule background Rectangle when bar.capsules.enabled, otherwise
    // renders identically to the plain Loader this replaced (innerHeight
    // falls back to the full bar height and the Rectangle is invisible, so
    // disabled capsules cost nothing visually or in layout).
    Component {
        id: capsuleModuleComponent

        Item {
            id: wrapper
            required property var modelData

            readonly property real innerHeight: bar.capsuleCfg.enabled
                ? Math.round(bar.barConfig.height * bar.capsuleCfg.thickness)
                : parent.height

            // Media/Tray (and any future module) collapse their own
            // implicitWidth to 0 when they have nothing to show (no MPRIS
            // player, no tray icons) rather than rendering an empty label --
            // loader.width mirrors that since this Loader sets no explicit
            // width of its own. Without this check the capsule Rectangle
            // below still drew a padding-only pill floating where a
            // currently-empty widget would go.
            readonly property bool hasContent: loader.width > 0

            // Content Scale is a real `scale:` transform on the Loader
            // (below), which is paint-only -- it doesn't change the
            // Loader's own reported width, so Row's spacing between
            // widgets would otherwise ignore the zoom entirely and
            // neighbors would visually overlap once scale != 1. Computing
            // the *scaled* footprint here and using it for both this
            // wrapper's width and the capsule background's width keeps
            // layout and paint in sync.
            readonly property real scaledContentWidth: loader.width * bar.layoutCfg.content_scale

            // Hover Highlight reuses the exact same padding/thickness the
            // capsule uses when capsules are on, so the two visually agree
            // instead of the highlight box mismatching a visible capsule's
            // own size; falls back to a sensible standalone size when
            // capsules are off, since there's no capsule geometry to match.
            readonly property real highlightPadding: bar.capsuleCfg.enabled ? bar.capsuleCfg.padding : Theme.fontSize * 0.4
            readonly property real highlightHeight: bar.capsuleCfg.enabled ? wrapper.innerHeight : parent.height * 0.8

            height: parent.height
            width: wrapper.hasContent ? (wrapper.scaledContentWidth + (bar.capsuleCfg.enabled ? bar.capsuleCfg.padding * 2 : 0)) : 0

            // Hover Highlight: the shell's first hover feedback anywhere on
            // the bar -- confirmed zero hoverEnabled/containsMouse/onEntered
            // anywhere in bar code before this. A HoverHandler here (not a
            // MouseArea) so it never intercepts clicks meant for the actual
            // module beneath it.
            HoverHandler {
                id: widgetHover
                onHoveredChanged: {
                    if (hovered && wrapper.hasContent)
                        SoundFx.play("bar_hover");
                }
            }

            // Press sound (off by default). PointHandler only ever takes a
            // passive grab, so the module's own MouseArea still gets the
            // click.
            PointHandler {
                acceptedButtons: Qt.AllButtons
                onActiveChanged: {
                    if (active && wrapper.hasContent)
                        SoundFx.play("bar_press");
                }
            }

            Rectangle {
                visible: bar.widgetsCfg.hover_highlight && widgetHover.hovered && wrapper.hasContent
                anchors.centerIn: parent
                width: wrapper.scaledContentWidth + wrapper.highlightPadding * 2
                height: wrapper.highlightHeight
                radius: Math.min(bar.capsuleCfg.enabled ? bar.capsuleCfg.radius : Theme.radius, Math.min(width, height) / 2)
                color: Theme.surfaceAlt
                opacity: 0.6
            }

            Rectangle {
                id: capsuleBg
                visible: bar.capsuleCfg.enabled && wrapper.hasContent
                anchors.centerIn: parent
                width: wrapper.scaledContentWidth + bar.capsuleCfg.padding * 2
                height: wrapper.innerHeight
                // Rectangle.radius isn't clamped by Qt the way CSS
                // border-radius is -- a configured radius bigger than half
                // the capsule's own smaller dimension doesn't just cap at a
                // clean pill, it visibly distorts into an over-rounded
                // blob. Clamped here explicitly so any configured value
                // (including the "always full pill" 999 default) is safe.
                radius: Math.min(bar.capsuleCfg.radius, Math.min(capsuleBg.width, capsuleBg.height) / 2)
                color: bar.capsuleFillColor
                opacity: bar.capsuleCfg.opacity
                border.width: bar.capsuleCfg.border_width
                border.color: Theme.border
            }

            // Click and scroll slots (ROADMAP F5). A module declares what it
            // does by defining any of leftClicked(), rightClicked(),
            // middleClicked() and scrolled(steps) (steps > 0 = wheel up);
            // this MouseArea calls them. It only accepts the buttons the
            // module declares, so anything else falls through to the bar's
            // dead-zone handler underneath (right-click opens Home). It sits
            // under the module, so a module's own per-item MouseAreas
            // (Workspaces' tags, Tray's icons) still come first.
            readonly property var module: loader.item
            readonly property bool hasLeft: !!wrapper.module && typeof wrapper.module.leftClicked === "function"
            readonly property bool hasRight: !!wrapper.module && typeof wrapper.module.rightClicked === "function"
            readonly property bool hasMiddle: !!wrapper.module && typeof wrapper.module.middleClicked === "function"
            readonly property bool hasScroll: !!wrapper.module && typeof wrapper.module.scrolled === "function"

            MouseArea {
                anchors.fill: parent
                enabled: wrapper.hasContent && (wrapper.hasLeft || wrapper.hasRight || wrapper.hasMiddle)
                acceptedButtons: (wrapper.hasLeft ? Qt.LeftButton : 0)
                    | (wrapper.hasRight ? Qt.RightButton : 0)
                    | (wrapper.hasMiddle ? Qt.MiddleButton : 0)
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        wrapper.module.leftClicked();
                    else if (mouse.button === Qt.RightButton)
                        wrapper.module.rightClicked();
                    else if (mouse.button === Qt.MiddleButton)
                        wrapper.module.middleClicked();
                }
            }

            // One step per notch: touchpads send many small pixel deltas,
            // so they are summed until a full notch (120) builds up.
            property real wheelAccum: 0
            WheelHandler {
                enabled: wrapper.hasContent && wrapper.hasScroll
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    wrapper.wheelAccum += event.angleDelta.y;
                    while (Math.abs(wrapper.wheelAccum) >= 120) {
                        var step = wrapper.wheelAccum > 0 ? 1 : -1;
                        wrapper.wheelAccum -= step * 120;
                        wrapper.module.scrolled(step);
                    }
                }
            }

            // Tooltip slot (ROADMAP F5): a module with a non-empty
            // `tooltip` property gets it shown in the bar's shared popup
            // after hovering for a moment.
            readonly property string tooltipText: (wrapper.module && wrapper.module.tooltip) ? String(wrapper.module.tooltip) : ""
            Timer {
                id: tooltipDelay
                interval: 600
                running: widgetHover.hovered && wrapper.hasContent && wrapper.tooltipText.length > 0
                onTriggered: bar.showTooltip(wrapper, wrapper.tooltipText)
            }
            Connections {
                target: widgetHover
                function onHoveredChanged() {
                    if (!widgetHover.hovered)
                        bar.hideTooltip(wrapper);
                }
            }
            onTooltipTextChanged: {
                if (bar.tooltipTarget === wrapper)
                    bar.tooltipText = wrapper.tooltipText;
            }

            Loader {
                id: loader
                anchors.centerIn: parent
                height: wrapper.innerHeight
                scale: bar.layoutCfg.content_scale
                transformOrigin: Item.Center
                sourceComponent: wrapper.modelData.component
            }
        }
    }

    // The bar's one tooltip popup, shared by every module (ROADMAP F5).
    property Item tooltipTarget: null
    property string tooltipText: ""

    function showTooltip(target, text) {
        bar.tooltipTarget = target;
        bar.tooltipText = text;
    }

    function hideTooltip(target) {
        if (bar.tooltipTarget === target) {
            bar.tooltipTarget = null;
            bar.tooltipText = "";
        }
    }

    PopupWindow {
        id: tooltipPopup
        visible: bar.tooltipTarget !== null && bar.tooltipText.length > 0
        anchor.item: bar.tooltipTarget
        // Below a top bar, above a bottom one, centered on the widget.
        anchor.edges: bar.barConfig.position === "bottom" ? Edges.Top : Edges.Bottom
        anchor.gravity: bar.barConfig.position === "bottom" ? Edges.Top : Edges.Bottom
        anchor.margins.top: bar.barConfig.position === "bottom" ? 0 : Theme.fontSize / 3
        anchor.margins.bottom: bar.barConfig.position === "bottom" ? Theme.fontSize / 3 : 0
        implicitWidth: tooltipLabel.implicitWidth + Theme.fontSize
        implicitHeight: tooltipLabel.implicitHeight + Theme.fontSize * 0.6
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius / 2
            color: Theme.surface
            border.width: 1
            border.color: Theme.border

            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: bar.tooltipText
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.85
            }
        }
    }

    // Right-click on empty bar space opens Home — deliberately isolated into
    // its own named function (not inlined in onClicked) so a future settings
    // panel's dead-zone tab can reassign what any click here does without
    // touching this MouseArea's own logic.
    function handleDeadZoneClick() {
        PanelManager.toggle("control-center");
    }

    // Shadow lives on this wrapper, one level up from `background` itself --
    // `layer.enabled` + `clip: true` on the SAME item constrains the
    // layer's own render texture to that item's bounds, which silently
    // clips the shadow off at exactly the edge it's supposed to extend
    // past (confirmed empirically: with both on `background` directly, the
    // shadow simply never appeared, no matter the blur/offset values).
    // Keeping `background`'s own `clip: true` (for the Contact Shadow child
    // below) on the INNER item and the shadow layer on this unclipped
    // outer one keeps the two concerns from fighting each other.
    Item {
        id: shadowWrapper
        anchors.fill: parent

        // Shadow: MultiEffect (QtQuick.Effects, Qt 6.5+) applied as a layer
        // effect -- no Qt5Compat.GraphicalEffects needed at this project's
        // Qt 6.11.2, and layer.effect handles both rendering the shadow AND
        // this wrapper's own content in one pass, so there's no separate
        // shadow item or manual z-ordering to manage. This is the first
        // shadow anywhere in the shell -- confirmed nothing else in the
        // codebase already does this.
        layer.enabled: bar.effectsCfg.shadow_enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.5
            shadowBlur: 0.4
            shadowVerticalOffset: 3
        }

        // The bar's actual painted background -- PanelWindow.color above is
        // transparent specifically so this can have real per-corner
        // rounding (Window has no radius property; Rectangle does). Qt
        // 6.7+'s per-corner radius properties are used directly rather than
        // a custom Shape/Canvas -- this project's Qt (6.11.2) is well past
        // that.
        Rectangle {
            id: background
            anchors.fill: parent
            // Cropped to this Rectangle's own rounded silhouette -- lets the
            // Contact Shadow strip below be a plain rectangle child instead
            // of needing its own corner-radius/mask logic; it's clipped to
            // match Shape's rounding for free.
            clip: true
            color: Theme.background
            opacity: bar.effectsCfg.background_opacity
            topLeftRadius: bar.topLeftRadius
            topRightRadius: bar.topRightRadius
            bottomLeftRadius: bar.bottomLeftRadius
            bottomRightRadius: bar.bottomRightRadius
            border.width: bar.shapeCfg.border_enabled ? bar.shapeCfg.border_width : 0
            border.color: Theme.border

            // Contact Shadow: purely aesthetic -- no "a panel is docked
            // against the bar" concept exists anywhere in the shell (see
            // Bar.qml's own effectsCfg comment in Config.qml), so this is
            // just a fixed gradient at whichever edge faces the screen's
            // interior, regardless of what's actually beneath it. A child
            // of `background` specifically so its own clip:true crops this
            // to the same rounded corners Shape already established,
            // instead of a square strip poking out past a rounded edge.
            Rectangle {
                visible: bar.effectsCfg.contact_shadow_enabled
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: bar.onTop ? undefined : parent.top
                anchors.bottom: bar.onTop ? parent.bottom : undefined
                height: Math.min(parent.height, Theme.fontSize * 0.6)
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: bar.onTop ? 0.0 : 1.0; color: "transparent" }
                    GradientStop { position: bar.onTop ? 1.0 : 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                }
            }
        }
    }

    // Corner Flow: a normal rounded corner is a disk centered at the point
    // INSET by the radius (e.g. (R,R) for top-left), which leaves the small
    // sliver nearest the true screen corner unfilled. A "flowing" concave
    // corner is the opposite construction -- a disk of the SAME radius
    // centered AT the true corner itself is cut OUT of an otherwise fully
    // square corner, via even-odd fill (square XOR circle). This still
    // leaves the true corner point unfilled (so it reads as a curve, not a
    // hard edge), but the notch reaches much further into the corner than
    // normal rounding's sliver does, and -- critically -- meets the bar's
    // straight edges at the exact same two tangent points normal rounding
    // would, so there's no gap or visible seam either way. A plain additive
    // disk (no subtraction) was tried first and rejected: layered on top of
    // the corner's existing rounding it just fully refills the square with
    // no visible curve at all, since there's nothing left unfilled for a
    // new boundary to show against -- the effect genuinely requires cutting
    // a hole, not adding a piece, which is exactly why Rectangle's radius
    // alone (additive-only) can't produce it and Shapes' odd-even fill is
    // needed. Only the two corners along the anchored edge apply -- the
    // other two are the far edge of the bar's own thickness, not a screen
    // edge at all.
    Component {
        id: cornerFlowComponent

        Shape {
            id: flowPiece
            // Not `required` -- set imperatively from each Loader's
            // onLoaded below, since Loader.sourceComponent has no built-in
            // way to forward initial property values the way Repeater's
            // modelData binding does.
            property real flowRadius: 0
            property real cornerX: 0 // the TRUE corner's local x within this radius x radius square (0 or flowRadius)
            property real cornerY: 0 // the TRUE corner's local y within this radius x radius square (0 or flowRadius)

            width: flowRadius
            height: flowRadius

            ShapePath {
                fillRule: ShapePath.OddEvenFill
                fillColor: Theme.background
                strokeWidth: -1

                startX: 0; startY: 0
                PathLine { x: flowPiece.flowRadius; y: 0 }
                PathLine { x: flowPiece.flowRadius; y: flowPiece.flowRadius }
                PathLine { x: 0; y: flowPiece.flowRadius }
                PathLine { x: 0; y: 0 }

                PathMove { x: flowPiece.cornerX + flowPiece.flowRadius; y: flowPiece.cornerY }
                PathAngleArc {
                    centerX: flowPiece.cornerX
                    centerY: flowPiece.cornerY
                    radiusX: flowPiece.flowRadius
                    radiusY: flowPiece.flowRadius
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }

    Loader {
        active: bar.cornerFlowActive && bar.onTop && bar.topLeftRadius > 0
        x: 0
        y: 0
        sourceComponent: cornerFlowComponent
        onLoaded: { item.flowRadius = bar.topLeftRadius; item.cornerX = 0; item.cornerY = 0; }
    }

    Loader {
        active: bar.cornerFlowActive && bar.onTop && bar.topRightRadius > 0
        x: bar.width - bar.topRightRadius
        y: 0
        sourceComponent: cornerFlowComponent
        onLoaded: { item.flowRadius = bar.topRightRadius; item.cornerX = bar.topRightRadius; item.cornerY = 0; }
    }

    Loader {
        active: bar.cornerFlowActive && !bar.onTop && bar.bottomLeftRadius > 0
        x: 0
        y: bar.height - bar.bottomLeftRadius
        sourceComponent: cornerFlowComponent
        onLoaded: { item.flowRadius = bar.bottomLeftRadius; item.cornerX = 0; item.cornerY = bar.bottomLeftRadius; }
    }

    Loader {
        active: bar.cornerFlowActive && !bar.onTop && bar.bottomRightRadius > 0
        x: bar.width - bar.bottomRightRadius
        y: bar.height - bar.bottomRightRadius
        sourceComponent: cornerFlowComponent
        onLoaded: { item.flowRadius = bar.bottomRightRadius; item.cornerX = bar.bottomRightRadius; item.cornerY = bar.bottomRightRadius; }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: bar.layoutCfg.content_padding
        anchors.rightMargin: bar.layoutCfg.content_padding

        // Reveals the bar on hover while auto-hidden -- this Item's own
        // bounds are the whole bar area, which collapsed is just the thin
        // sliver sitting at the screen edge, exactly the intended hover
        // target. hideTimer adds a short grace period before actually
        // collapsing back so moving the pointer across a widget near the
        // sliver boundary doesn't flicker the bar in and out.
        HoverHandler {
            id: hoverHandler
        }

        Connections {
            target: hoverHandler
            function onHoveredChanged() {
                if (hoverHandler.hovered) {
                    hideTimer.stop();
                    bar.hovered = true;
                } else {
                    hideTimer.start();
                }
            }
        }

        Timer {
            id: hideTimer
            interval: 300
            onTriggered: bar.hovered = false
        }

        // Placed before the module Rows below so their own per-module
        // MouseAreas still take precedence: Rows are only as wide as their
        // content, not anchors.fill, so genuinely empty space (including the
        // gaps between modules) falls through to this one.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    bar.handleDeadZoneClick();
            }
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: bar.widgetsCfg.spacing
            height: parent.height

            Repeater {
                model: bar.resolveModules(bar.barConfig.modules_left)
                delegate: capsuleModuleComponent
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: bar.widgetsCfg.spacing
            height: parent.height

            Repeater {
                model: bar.resolveModules(bar.barConfig.modules_center)
                delegate: capsuleModuleComponent
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: bar.widgetsCfg.spacing
            height: parent.height

            Repeater {
                model: bar.resolveModules(bar.barConfig.modules_right)
                delegate: capsuleModuleComponent
            }
        }
    }
}
