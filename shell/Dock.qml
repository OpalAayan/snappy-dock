/*  Dock.qml  – Main dock bar.
 *
 *  PanelWindow rendered by QuickShell/wlr-layer-shell.
 *  The daemon reads config.ini and sends the parsed values through
 *  DaemonBridge.config; this file applies those values to the shell.
 *
 *  AutoHide architecture:
 *    The dock window stays mapped at all times.  Hiding is achieved by
 *    animating the PanelWindow margins to negative values, which
 *    pushes the actual Wayland surface off-screen via the layer-shell
 *    protocol.  A thin edge strip (edgeStripSize px) remains visible
 *    at the screen edge as a hover hotspot.
 *
 *    This guarantees that:
 *      1. The Wayland input region always matches the visual position
 *         (margins move real geometry, not just a render transform).
 *      2. No surface is ever unmapped/remapped under the cursor,
 *         so pointer focus is never lost.
 */
import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: dockScope

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            property var modelData

            /* ── Position & alignment ────────────────────────────────── */
            readonly property string dockPosition:  normalizedPosition(DaemonBridge.config.position)
            readonly property string dockAlignment: normalizedAlignment(DaemonBridge.config.alignment)
            readonly property bool isTop:        dockPosition === "top"
            readonly property bool isBottom:     dockPosition === "bottom"
            readonly property bool isLeft:       dockPosition === "left"
            readonly property bool isRight:      dockPosition === "right"
            readonly property bool isVertical:   isLeft || isRight
            readonly property bool isHorizontal: !isVertical
            readonly property bool alignStart:   dockAlignment === "start"
            readonly property bool alignEnd:     dockAlignment === "end"
            readonly property bool alignCenter:  dockAlignment === "center"

            /* ── Feature flags ───────────────────────────────────────── */
            readonly property bool autohide:      Boolean(DaemonBridge.config.autohide)
            readonly property bool snappyMode:     DaemonBridge.config.mode === "snappy"

            /* ── Unified display list (includes launcher as a native dock item) ── */
            readonly property var displayItems: {
                var rawList = DaemonBridge.dockItems || [];
                var items = new Array(rawList.length);
                for (var i = 0; i < rawList.length; i++)
                    items[i] = rawList[i];

                var pos = normalizedLauncherPos(DaemonBridge.config.launcher_pos);
                if (pos === "none")
                    return items;

                var launcherObj = {
                    className: "_launcher",
                    icon: DaemonBridge.config.launcher_icon || "dots",
                    addr: "",
                    title: "Applications",
                    instanceCount: 0,
                    isActive: false,
                    isPinned: false,
                    instances: [],
                    isLauncher: true
                };

                /* LauncherPos controls order. Alignment only controls position on screen.
                   start → [Launcher, App1, App2, ...]
                   end   → [App1, App2, ..., Launcher] */
                if (pos === "end")
                    items.push(launcherObj);
                else
                    items.unshift(launcherObj);
                return items;
            }

            /* ── Layout metrics ──────────────────────────────────────── */
            readonly property int visibleItemCount: displayItems.length
            readonly property int itemExtent:    Theme.iconSize + Theme.itemPadding * 2
            readonly property int indicatorGap: 4
            readonly property int sideIndicatorWidth: Theme.dotSize
            readonly property int dockItemWidth: {
                switch (dockPosition) {
                    case "left":
                    case "right":
                        return itemExtent + sideIndicatorWidth + indicatorGap;
                    case "top":
                    case "bottom":
                    default:
                        return itemExtent;
                }
            }
            readonly property int dockItemHeight: {
                switch (dockPosition) {
                    case "left":
                    case "right":
                        return itemExtent;
                    case "top":
                    case "bottom":
                    default:
                        return itemExtent + Theme.dotSize + indicatorGap;
                }
            }
            readonly property int marginTop:     numberOrDefault(DaemonBridge.config.margin_top,    0)
            readonly property int marginBottom:  numberOrDefault(DaemonBridge.config.margin_bottom,  5)
            readonly property int marginLeft:    numberOrDefault(DaemonBridge.config.margin_left,    0)
            readonly property int marginRight:   numberOrDefault(DaemonBridge.config.margin_right,   0)
            readonly property int configuredExclusiveZone: exclusiveZoneFromConfig(DaemonBridge.config.exclusive_zone)
            readonly property bool fullWidth: Boolean(DaemonBridge.config.full_width)

            /* ── Dock content dimensions ─────────────────────────────── */
            /* The dock background (dockBackground) stays at base size.
               The PanelWindow is taller/wider by snappyHeadroom so the
               compositor does not clip magnified icons.  The extra space
               is transparent and sits on the "away from edge" side.
               In static mode headroom is 0, so panel == background.    */
            readonly property real snappyMagnification: snappyMode
                                                       ? Math.max(0.0, Math.min(2.0, DaemonBridge.config.magnification || 0.78))
                                                       : 0.0
            /* Cross-axis headroom: the magnified icon grows AND lifts away
               from the dock edge.  We need room for both.
               growth = (maxScale-1) * extent/2   (half the size increase)
               lift   = (maxScale-1) * iconSize * 0.85
               Total  = growth + lift + safety margin                       */
            readonly property real _snappyExtent: Theme.iconSize + Theme.itemPadding * 2
            readonly property real _snappyMaxScale: 1.0 + snappyMagnification
            readonly property real snappyHeadroom: snappyMode
                ? Math.ceil((_snappyMaxScale - 1.0) * _snappyExtent * 0.5
                          + (_snappyMaxScale - 1.0) * Theme.iconSize * 0.85
                          + 8)
                : 0

            /* ── Snappy rise displacement ────────────────────────── */
            /* RiseSpacing scales how much magnified icons push
               neighbors apart on the main axis (0=off, 1=full).    */
            readonly property real _snappyRiseSpacing: {
                if (!snappyMode) return 0;
                var rs = DaemonBridge.config.rise_spacing;
                return (rs !== undefined && rs !== null) ? Math.max(0, Math.min(2, rs)) : 0.5;
            }
            /* Static worst-case rise growth for panel/container sizing
               (computed as if cursor is at the center of the dock).   */
            readonly property real _snappyMaxRiseGrowth: {
                if (_snappyRiseSpacing <= 0) return 0;
                var n = displayItems.length;
                if (n === 0) return 0;
                var cell = _snappyExtent, sp = Theme.itemSpacing;
                var peak = _snappyMaxScale;
                var sig = Math.max(cell * (DaemonBridge.config.spread || 3) * 0.42, 40);
                var ir = sig * 2.8;
                var mid = (n * (cell + sp) - sp) * 0.5;
                var total = 0;
                for (var i = 0; i < n; i++) {
                    var d = Math.abs(i * (cell + sp) + cell * 0.5 - mid);
                    if (d < ir) total += (peak - 1.0) * Math.exp(-(d * d) / (2.0 * sig * sig)) * cell;
                }
                return total * _snappyRiseSpacing;
            }

            /* Main-axis overflow: edge icons grow wider/taller when magnified
               and get clipped at the panel surface boundary.  Add symmetric
               padding so they have room.  _snappyMaxRiseGrowth/2 accounts
               for the outermost icon being displaced outward.              */
            readonly property real snappyMainOverflow: snappyMode
                ? Math.ceil((_snappyMaxScale - 1.0) * _snappyExtent * 0.5 + 8 + _snappyMaxRiseGrowth * 0.5) * 2
                : 0

            /* Per-frame displacement: recomputed at ~60fps when pointer is
               on the dock.  Each icon's displacement equals where its center
               WOULD be if all icons occupied their scaled sizes, minus where
               it actually is in the fixed Grid — centered so the dock
               expands symmetrically.                                        */
            property var _snappyDisplacementData: {
                var empty = { displacements: [], totalGrowth: 0 };
                if (_snappyRiseSpacing <= 0) return empty;
                var n = displayItems.length;
                if (n === 0) return empty;
                var mouseAxis = isVertical ? snappyMouseY : snappyMouseX;
                if (mouseAxis === pointerUnset) return empty;
                var cell = _snappyExtent, sp = Theme.itemSpacing;
                var peak = _snappyMaxScale;
                var sig = Math.max(cell * (DaemonBridge.config.spread || 3) * 0.42, 40);
                var ir = sig * 2.8;
                var rs = _snappyRiseSpacing;
                /* Compute Gaussian scales (mirrors DockItem.gaussianScale) */
                var scales = new Array(n);
                for (var i = 0; i < n; i++) {
                    var d = Math.abs(i * (cell + sp) + cell * 0.5 - mouseAxis);
                    scales[i] = (d >= ir) ? 1.0
                        : 1.0 + (peak - 1.0) * Math.exp(-(d * d) / (2.0 * sig * sig));
                }
                /* Layout as if each icon occupied its scaled size */
                var pos = 0, nc = new Array(n);
                for (var j = 0; j < n; j++) {
                    var ew = scales[j] * cell;
                    nc[j] = pos + ew * 0.5;
                    pos += ew + sp;
                }
                var totalOrig = n * cell + (n - 1) * sp;
                var totalGrowth = pos - sp - totalOrig;
                var growth = totalGrowth * rs;
                var shift;
                if (fullWidth && alignStart) {
                    shift = 0;
                } else if (fullWidth && alignEnd) {
                    shift = totalGrowth;
                } else {
                    shift = totalGrowth * 0.5;
                }
                var disps = new Array(n);
                for (var k = 0; k < n; k++)
                    disps[k] = (nc[k] - (k * (cell + sp) + cell * 0.5) - shift) * rs;
                return { displacements: disps, totalGrowth: growth };
            }
            readonly property var snappyDisplacements: _snappyDisplacementData.displacements || []
            readonly property real snappyRiseGrowth: _snappyDisplacementData.totalGrowth || 0
            readonly property real dockBaseWidth:   dockLayout.implicitWidth  + Theme.dockPadding * 2
            readonly property real dockBaseHeight:  dockLayout.implicitHeight + Theme.dockPadding * 2
            readonly property real panelWidth: isVertical
                ? dockBaseWidth + snappyHeadroom + edgePadding
                : dockBaseWidth + snappyMainOverflow
            readonly property real panelHeight: isHorizontal
                ? dockBaseHeight + snappyHeadroom + edgePadding
                : dockBaseHeight + snappyMainOverflow

            /* ── AutoHide metrics ────────────────────────────────────── */

            /* Pixels of the dock that remain visible at the screen edge
               when hidden.  Acts as the hover hotspot to trigger reveal. */
            readonly property int edgeStripSize: 4

            /* The margin value for the dock's edge when fully hidden.
               Negative, pushing the panel offscreen except edgeStripSize px. */
            readonly property real hiddenEdgeMargin: {
                switch (dockPosition) {
                    case "left":
                    case "right":
                        return edgeStripSize - panelWidth;
                    case "top":
                    case "bottom":
                    default:
                        return edgeStripSize - panelHeight;
                }
            }

            /* When autohide is enabled then the margin would normally mean
               theres a gap between the dock and the edge of the screen but the
               place it opens the dock is at the edge, meaning if you open the dock
               then keep the cursor still then its gonna hide. So then you 
               change the margin to padding then it stops hiding and it only
               applies to the edge that is automatically hidden and stuff
               And then add these variables to the places you gotta you know...
               */
            readonly property real edgePadding: {
                if (!autohide) return 0;
                switch (dockPosition) {
                    case "top":    return marginTop;
                    case "bottom": return marginBottom;
                    case "left":   return marginLeft;
                    case "right":  return marginRight;
                    default:       return 0;
                }
            }

            readonly property int effectiveMarginTop:    autohide && isTop    ? 0 : marginTop
            readonly property int effectiveMarginBottom: autohide && isBottom ? 0 : marginBottom
            readonly property int effectiveMarginLeft:   autohide && isLeft   ? 0 : marginLeft
            readonly property int effectiveMarginRight:  autohide && isRight  ? 0 : marginRight

            /* ── Snappy mode mouse tracking ──────────────────────────── */
            readonly property real pointerUnset: -100000
            readonly property real snappyAxisMargin: Theme.iconSize * 0.75
            property real snappyMouseX: pointerUnset
            property real snappyMouseY: pointerUnset

            /* ── AutoHide state ──────────────────────────────────────── */
            property bool dockRevealed: true
            property bool mouseInDock:  false

            /* Animated progress: 0.0 = fully visible, 1.0 = hidden.
               All margin changes derive from this single value so only
               one Behavior is needed to drive the entire animation. */
            property real _hideProgress: (autohide && !dockRevealed) ? 1.0 : 0.0

            Behavior on _hideProgress {
                NumberAnimation {
                    duration: Theme.hideAnimMs
                    easing.type: Easing.OutCubic
                }
            }

            /* ── Computed animated margin for a given edge ───────────── */
            /* Interpolates between the configured margin (visible) and
               the hidden margin (offscreen).  Only the dock's primary
               edge is animated; all other edges pass through unchanged.
               Math.round() prevents sub-pixel jitter on integer margin
               boundaries which can cause 1px gaps in the compositor.   */
            function animatedMargin(isActiveEdge, configuredMargin) {
                if (!isActiveEdge)
                    return configuredMargin;
                return Math.round(configuredMargin
                       + _hideProgress * (hiddenEdgeMargin - configuredMargin));
            }

            function clearSnappyPointer() {
                _pendingX = pointerUnset;
                _pendingY = pointerUnset;
                snappyMouseX = pointerUnset;
                snappyMouseY = pointerUnset;
                _snappyThrottle.stop();
            }

            /* Raw mouse coords are buffered here; a 16ms timer flushes them
               to the actual properties, capping re-evaluation to ~60fps. */
            property real _pendingX: pointerUnset
            property real _pendingY: pointerUnset

            Timer {
                id: _snappyThrottle
                interval: 16          /* ~60 fps */
                repeat: false
                onTriggered: {
                    screenScope.snappyMouseX = screenScope._pendingX;
                    screenScope.snappyMouseY = screenScope._pendingY;
                }
            }

            function updateSnappyPointerFromContainer(x, y) {
                if (!snappyMode) {
                    clearSnappyPointer();
                    return;
                }

                var mapped = dockContainer.mapToItem(dockLayout, x, y);
                var axisValue, axisSize;
                switch (dockPosition) {
                    case "left":
                    case "right":
                        axisValue = mapped.y;
                        axisSize = dockLayout.implicitHeight > 0 ? dockLayout.implicitHeight : dockLayout.height;
                        break;
                    case "top":
                    case "bottom":
                    default:
                        axisValue = mapped.x;
                        axisSize = dockLayout.implicitWidth > 0 ? dockLayout.implicitWidth : dockLayout.width;
                        break;
                }
                if (axisSize <= 0
                    || axisValue < -snappyAxisMargin
                    || axisValue > axisSize + snappyAxisMargin) {
                    clearSnappyPointer();
                    return;
                }

                _pendingX = mapped.x;
                _pendingY = mapped.y;
                if (!_snappyThrottle.running)
                    _snappyThrottle.start();
            }

            /* ── Utility functions ───────────────────────────────────── */

            function normalizedPosition(value) {
                var pos = String(value || "bottom").toLowerCase();
                if (pos === "top" || pos === "bottom" || pos === "left" || pos === "right")
                    return pos;
                return "bottom";
            }

            function normalizedAlignment(value) {
                var alignment = String(value || "center").toLowerCase();
                if (alignment === "start" || alignment === "end" || alignment === "center")
                    return alignment;
                return "center";
            }

            function normalizedLauncherPos(value) {
                var pos = String(value || "start").toLowerCase();
                if (pos === "start" || pos === "end" || pos === "none")
                    return pos;
                return "start";
            }

            function numberOrDefault(value, fallback) {
                var numberValue = Number(value);
                return isNaN(numberValue) ? fallback : numberValue;
            }

            function layerFromConfig(value) {
                var layer = String(value || "overlay").toLowerCase();
                if (layer === "background") return WlrLayer.Background;
                if (layer === "bottom")     return WlrLayer.Bottom;
                if (layer === "top")        return WlrLayer.Top;
                return WlrLayer.Overlay;
            }

            function exclusiveZoneFromConfig(value) {
                if (value === undefined || value === null)
                    return 0;
                if (String(value).toLowerCase() === "auto")
                    return -1;
                return Number(value) || 0;
            }

            /* ── AutoHide control ────────────────────────────────────── */

            /* Immediately reveal the dock and cancel any pending hide. */
            function showDock() {
                hideTimer.stop();
                dockRevealed = true;
            }

            /* Begin the hide animation if conditions allow. */
            function startHideAnimation() {
                if (!autohide || DaemonBridge.activeMenuId !== "" || mouseInDock)
                    return;
                dockRevealed = false;
            }

            /* Schedule a delayed hide (gives the user time to re-enter). */
            function scheduleHide() {
                if (!autohide || DaemonBridge.activeMenuId !== "" || mouseInDock)
                    return;
                hideTimer.restart();
            }

            /* Reset all autohide state to a known-good starting point.
               Called on init and whenever the config changes. */
            function resetAutohideState() {
                hideTimer.stop();
                initialHideTimer.stop();
                mouseInDock = false;
                clearSnappyPointer();
                dockRevealed = true;

                if (autohide)
                    initialHideTimer.restart();
            }

            Component.onCompleted: resetAutohideState()

            /* ═══════════════════════════════════════════════════════════
             *  Dock Window
             * ═══════════════════════════════════════════════════════════ */
            PanelWindow {
                id: dockWindow
                screen: screenScope.modelData

                /* Always mapped — hiding is done via margin animation,
                   never by unmapping the surface.  This prevents the
                   Wayland focus-loss that occurs when a surface unmaps
                   directly under the cursor. */
                visible: true

                anchors {
                    top:    screenScope.isTop    || (screenScope.isVertical   && (screenScope.fullWidth || screenScope.alignStart))
                    bottom: screenScope.isBottom || (screenScope.isVertical   && (screenScope.fullWidth || screenScope.alignEnd))
                    left:   screenScope.isLeft   || (screenScope.isHorizontal && (screenScope.fullWidth || screenScope.alignStart))
                    right:  screenScope.isRight  || (screenScope.isHorizontal && (screenScope.fullWidth || screenScope.alignEnd))
                }

                /* Margins are animated to push the surface offscreen.
                   Only the dock's primary edge margin changes; the other
                   edges keep their configured values.
                   Hyprland passes int32_t margins straight into the
                   geometry calculation, so negative values work natively. */
                margins {
                    top:    screenScope.isTop
                            ? screenScope.animatedMargin(true, screenScope.effectiveMarginTop)
                            : (!screenScope.fullWidth && screenScope.isVertical && screenScope.alignStart ? screenScope.marginTop : 0)
                    bottom: screenScope.isBottom
                            ? screenScope.animatedMargin(true, screenScope.effectiveMarginBottom)
                            : (!screenScope.fullWidth && screenScope.isVertical && screenScope.alignEnd ? screenScope.marginBottom : 0)
                    left:   screenScope.isLeft
                            ? screenScope.animatedMargin(true, screenScope.effectiveMarginLeft)
                            : (!screenScope.fullWidth && screenScope.isHorizontal && screenScope.alignStart ? screenScope.marginLeft : 0)
                    right:  screenScope.isRight
                            ? screenScope.animatedMargin(true, screenScope.effectiveMarginRight)
                            : (!screenScope.fullWidth && screenScope.isHorizontal && screenScope.alignEnd ? screenScope.marginRight : 0)
                }

                WlrLayershell.layer: screenScope.layerFromConfig(DaemonBridge.config.layer)
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                WlrLayershell.exclusiveZone: screenScope.configuredExclusiveZone > 0
                                             ? screenScope.configuredExclusiveZone
                                             : 0

                exclusionMode: screenScope.configuredExclusiveZone === 0
                               ? ExclusionMode.Ignore
                               : (screenScope.configuredExclusiveZone < 0
                                  ? ExclusionMode.Auto
                                  : ExclusionMode.Normal)

                implicitWidth:  (screenScope.fullWidth && screenScope.isHorizontal)
                                ? (screenScope.modelData ? screenScope.modelData.width : 1920)
                                : screenScope.panelWidth
                implicitHeight: (screenScope.fullWidth && screenScope.isVertical)
                                ? (screenScope.modelData ? screenScope.modelData.height : 1080)
                                : screenScope.panelHeight
                color: "transparent"

                /* ── Precise input surface: follows dockLayout geometry ─ */
                Item {
                    id: iconHitArea
                    /* Track the Grid's position + overflow margin for snappy mode */
                    x: screenScope.isHorizontal
                       ? (dockLayout.x - (screenScope.snappyMainOverflow / 2) - 8)
                       : (screenScope.isRight ? (parent.width - width) : 0)
                    y: screenScope.isVertical
                       ? (dockLayout.y - (screenScope.snappyMainOverflow / 2) - 8)
                       : (screenScope.isBottom ? (parent.height - height) : 0)
                    width:  screenScope.isHorizontal
                            ? (dockLayout.implicitWidth + screenScope.snappyMainOverflow + 16)
                            : parent.width
                    height: screenScope.isVertical
                            ? (dockLayout.implicitHeight + screenScope.snappyMainOverflow + 16)
                            : parent.height
                }

                mask: Region {
                    Region { item: dockBackground }
                    Region { item: iconHitArea }
                }

                /* ── Dock container (input region, full panel size) ──── */
                Rectangle {
                    id: dockContainer
                    color: "transparent"
                    anchors.fill: parent
                    clip: false

                    /* ── Visual dock background ────── */
                    Rectangle {
                        id: dockBackground

                        property real _riseW: (!screenScope.fullWidth && screenScope.isHorizontal) ? screenScope.snappyRiseGrowth : 0
                        property real _riseH: (!screenScope.fullWidth && screenScope.isVertical)   ? screenScope.snappyRiseGrowth : 0
                        Behavior on _riseW {
                            enabled: screenScope.snappyMode && screenScope.snappyMouseX === screenScope.pointerUnset
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                        Behavior on _riseH {
                            enabled: screenScope.snappyMode && screenScope.snappyMouseX === screenScope.pointerUnset
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        /* Size */
                        width:  screenScope.isVertical
                                ? screenScope.dockBaseWidth
                                : (screenScope.fullWidth ? parent.width : screenScope.dockBaseWidth + _riseW)
                        height: screenScope.isHorizontal
                                ? screenScope.dockBaseHeight
                                : (screenScope.fullWidth ? parent.height : screenScope.dockBaseHeight + _riseH)

                        /* Position: pure x/y, no anchors to avoid conflicts */
                        x: {
                            var pw = parent ? parent.width : 0;
                            var edgePad = screenScope.edgePadding;
                            if (screenScope.isLeft)   return edgePad;
                            if (screenScope.isRight)  return pw - width - edgePad;
                            if (screenScope.fullWidth) return 0;
                            return (pw - width) / 2;
                        }
                        y: {
                            var ph = parent ? parent.height : 0;
                            var edgePad = screenScope.edgePadding;
                            if (screenScope.isTop)    return edgePad;
                            if (screenScope.isBottom) return ph - height - edgePad;
                            if (screenScope.fullWidth) return 0;
                            return (ph - height) / 2;
                        }

                        radius: screenScope.fullWidth ? 0 : Theme.dockRadius
                        color:  Theme.bgColor
                        border.color: Theme.bgBorder
                        border.width: 1
                    }

                    Grid {
                        id: dockLayout
                        clip: false
                        width:  implicitWidth
                        height: implicitHeight

                        /* ── Position: pure x/y bindings, no anchors ─────── */
                        /* QML anchor conflicts silently break manual positioning.
                           Use explicit math for both axes on all 4 positions.
                           Cross-axis = dock edge side. Main-axis = along the bar. */
                        x: {
                            var pw = parent ? parent.width : 0;
                            var gw = implicitWidth;
                            var edgePad = Theme.dockPadding + screenScope.edgePadding;
                            var alignPad = Theme.dockPadding + 16;
                            /* Cross-axis for left/right docks */
                            if (screenScope.isLeft)   return edgePad;
                            if (screenScope.isRight)  return pw - gw - edgePad;
                            /* Main-axis for top/bottom docks */
                            if (screenScope.fullWidth) {
                                if (screenScope.alignStart)
                                    return Math.max(screenScope.marginLeft, 0) + alignPad;
                                if (screenScope.alignEnd)
                                    return pw - gw - Math.max(screenScope.marginRight, 0) - alignPad;
                            }
                            return (pw - gw) / 2;
                        }
                        y: {
                            var ph = parent ? parent.height : 0;
                            var gh = implicitHeight;
                            var edgePad = Theme.dockPadding + screenScope.edgePadding;
                            var alignPad = Theme.dockPadding + 16;
                            /* Cross-axis for top/bottom docks */
                            if (screenScope.isBottom) return ph - gh - edgePad;
                            if (screenScope.isTop)    return edgePad;
                            /* Main-axis for left/right docks */
                            if (screenScope.fullWidth) {
                                if (screenScope.alignStart)
                                    return Math.max(screenScope.marginTop, 0) + alignPad;
                                if (screenScope.alignEnd)
                                    return ph - gh - Math.max(screenScope.marginBottom, 0) - alignPad;
                            }
                            return (ph - gh) / 2;
                        }

                        columns: screenScope.isVertical ? 1 : Math.max(1, screenScope.displayItems.length)
                        spacing: Theme.itemSpacing

                        add: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "scale"; from: 0.5; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                            }
                        }
                        move: Transition {
                            NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutCubic }
                        }

                        Repeater {
                            model: screenScope.displayItems.length

                            DockItem {
                                required property int index
                                readonly property var modelData: screenScope.displayItems[index] || ({})

                                isLauncher:    Boolean(modelData.isLauncher)
                                className:     modelData.className     || ""
                                icon:          modelData.icon          || ""
                                addr:          modelData.addr          || ""
                                title:         modelData.title         || ""
                                instanceCount: modelData.instanceCount || 0
                                isActive:      modelData.isActive      || false
                                isPinned:      modelData.isPinned      || false
                                instances:     modelData.instances     || []
                                size:          Theme.iconSize
                                screenName:    screenScope.modelData.name || ""
                                dockMouseX:    screenScope.snappyMouseX
                                dockMouseY:    screenScope.snappyMouseY
                                dockPointerUnset: screenScope.pointerUnset
                                magnification: DaemonBridge.config.magnification || 0.78
                                spread:        DaemonBridge.config.spread || 3
                                snappyMainDisplacement: {
                                    var d = screenScope.snappyDisplacements;
                                    return (d && index >= 0 && index < d.length) ? d[index] : 0;
                                }
                            }
                        }
                    }

                    /* ── Snappy mode: passive pointer tracker ──────────── */
                    HoverHandler {
                        id: snappyPointerTracker
                        enabled: screenScope.snappyMode
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        target: null

                        onPointChanged: {
                            screenScope.updateSnappyPointerFromContainer(point.position.x, point.position.y);
                        }

                        onHoveredChanged: {
                            if (hovered)
                                screenScope.updateSnappyPointerFromContainer(point.position.x, point.position.y);
                            else
                                screenScope.clearSnappyPointer();
                        }
                    }

                    /* ── Autohide hover detection ───────────────────────── */
                    HoverHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onHoveredChanged: {
                            if (hovered) {
                                screenScope.mouseInDock = true;
                                screenScope.showDock();
                            } else {
                                screenScope.mouseInDock = false;
                                screenScope.clearSnappyPointer();
                                screenScope.scheduleHide();
                            }
                        }
                    }
                }
            }

            /* ── Daemon connections ──────────────────────────────────── */
            Connections {
                target: DaemonBridge

                function onConfigChanged() {
                    screenScope.resetAutohideState();
                }

                function onActiveMenuIdChanged() {
                    if (DaemonBridge.activeMenuId !== "") {
                        screenScope.showDock();
                    } else {
                        screenScope.scheduleHide();
                    }
                }
            }

            /* ── Timers ─────────────────────────────────────────────── */

            /* Delay before hiding after the cursor leaves the dock.
               Uses the daemon's HotspotDelay config (ms) if set,
               otherwise falls back to Theme.hideDelayMs.              */
            Timer {
                id: hideTimer
                interval: {
                    var cfgDelay = DaemonBridge.config.hotspot_delay;
                    return (cfgDelay !== undefined && cfgDelay > 0)
                           ? cfgDelay
                           : Theme.hideDelayMs;
                }
                onTriggered: screenScope.startHideAnimation()
            }

            /* Brief delay on startup before the first auto-hide. */
            Timer {
                id: initialHideTimer
                interval: 500
                onTriggered: screenScope.startHideAnimation()
            }
        }
    }
}
