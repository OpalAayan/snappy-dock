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
                var raw = DaemonBridge.dockItems || [];
                var pos = normalizedLauncherPos(DaemonBridge.config.launcher_pos);
                if (pos === "none")
                    return raw;
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
                if (pos === "end")
                    return raw.concat([launcherObj]);
                return [launcherObj].concat(raw);
            }

            /* ── Layout metrics ──────────────────────────────────────── */
            readonly property int visibleItemCount: displayItems.length
            readonly property int itemExtent:    Theme.iconSize + Theme.itemPadding * 2
            readonly property int indicatorGap: 4
            readonly property int sideIndicatorWidth: Math.max(Theme.dotSize * 2, Theme.dotActiveWidth - 4)
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
            readonly property bool wantsFullCrossAxis: {
                switch (dockPosition) {
                    case "left":
                    case "right":
                        return false;
                    case "top":
                    case "bottom":
                    default:
                        return Boolean(DaemonBridge.config.full_width) || alignStart || alignEnd;
                }
            }

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
                var growth = (pos - sp - totalOrig) * rs;
                var shift = (pos - sp - totalOrig) * 0.5;
                var disps = new Array(n);
                for (var k = 0; k < n; k++)
                    disps[k] = (nc[k] - (k * (cell + sp) + cell * 0.5) - shift) * rs;
                return { displacements: disps, totalGrowth: growth };
            }
            readonly property var snappyDisplacements: _snappyDisplacementData.displacements || []
            readonly property real snappyRiseGrowth: _snappyDisplacementData.totalGrowth || 0
            readonly property real dockBaseWidth:   dockLayout.implicitWidth  + Theme.dockPadding * 2
            readonly property real dockBaseHeight:  dockLayout.implicitHeight + Theme.dockPadding * 2
            readonly property real panelWidth: {
                switch (dockPosition) {
                    case "left":
                    case "right":
                        return dockBaseWidth + snappyHeadroom + edgePadding;
                    case "top":
                    case "bottom":
                    default:
                        return wantsFullCrossAxis ? modelData.width : dockBaseWidth + snappyMainOverflow;
                }
            }
            readonly property real panelHeight: {
                switch (dockPosition) {
                    case "left":
                    case "right":
                        return dockBaseHeight + snappyMainOverflow;
                    case "top":
                    case "bottom":
                    default:
                        return dockBaseHeight + snappyHeadroom + edgePadding;
                }
            }

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
                        axisSize = dockLayout.height;
                        break;
                    case "top":
                    case "bottom":
                    default:
                        axisValue = mapped.x;
                        axisSize = dockLayout.width;
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
                    top:    screenScope.dockPosition === "top"
                    bottom: screenScope.dockPosition === "bottom"
                    left:   screenScope.dockPosition === "left"
                            || ((screenScope.dockPosition === "top" || screenScope.dockPosition === "bottom") && screenScope.wantsFullCrossAxis)
                    right:  screenScope.dockPosition === "right"
                            || ((screenScope.dockPosition === "top" || screenScope.dockPosition === "bottom") && screenScope.wantsFullCrossAxis)
                }

                /* Margins are animated to push the surface offscreen.
                   Only the dock's primary edge margin changes; the other
                   edges keep their configured values.
                   Hyprland passes int32_t margins straight into the
                   geometry calculation, so negative values work natively. */
                margins {
                    top:    screenScope.animatedMargin(screenScope.isTop,    screenScope.effectiveMarginTop)
                    bottom: screenScope.animatedMargin(screenScope.isBottom, screenScope.effectiveMarginBottom)
                    left:   screenScope.animatedMargin(screenScope.isLeft,   screenScope.effectiveMarginLeft)
                    right:  screenScope.animatedMargin(screenScope.isRight,  screenScope.effectiveMarginRight)
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

                implicitWidth:  screenScope.panelWidth
                implicitHeight: screenScope.panelHeight
                color: "transparent"

                /* ── Full-panel hover surface for autohide ────────────── */
                /* inputSurface fills the entire PanelWindow so the Wayland
                   input region always spans the full panel geometry.
                   When the panel is pushed offscreen by negative margins,
                   the compositor clips the input region to whatever sliver
                   of surface remains visible (the edge strip).  This
                   guarantees hover detection works for ALL positions —
                   the old approach (mask = dockContainer) failed because
                   dockContainer is smaller than the panel and offset
                   from the edge, leaving the strip with no input region
                   on non-bottom edges.                                    */
                Item {
                    id: inputSurface
                    anchors.fill: parent
                }

                /* Input region tracks inputSurface (the full panel surface)
                   so the compositor can clip it to the visible area.
                   This replaces the old dockContainer-based region which
                   did not cover the edge strip on non-bottom positions. */
                mask: Region {
                    item: inputSurface
                }

                /* ── Dock container (input region, full panel size) ──── */
                /* dockContainer is the full panel size so hover/click
                   detection works in the magnification overflow zone.
                   The visual background is a child Rectangle.           */
                Rectangle {
                    id: dockContainer
                    color: "transparent"

                    /* Screen-edge anchor — explicit per position */
                    anchors.left: screenScope.dockPosition === "left"
                                  || ((screenScope.dockPosition === "top" || screenScope.dockPosition === "bottom") && screenScope.alignStart)
                                  ? parent.left : undefined
                    anchors.right: screenScope.dockPosition === "right"
                                   || ((screenScope.dockPosition === "top" || screenScope.dockPosition === "bottom") && screenScope.alignEnd)
                                   ? parent.right : undefined
                    anchors.top: screenScope.dockPosition === "top"
                                 || ((screenScope.dockPosition === "left" || screenScope.dockPosition === "right") && screenScope.alignStart)
                                 ? parent.top : undefined
                    anchors.bottom: screenScope.dockPosition === "bottom"
                                    || ((screenScope.dockPosition === "left" || screenScope.dockPosition === "right") && screenScope.alignEnd)
                                    ? parent.bottom : undefined
                    anchors.horizontalCenter: (screenScope.dockPosition === "top" || screenScope.dockPosition === "bottom") && screenScope.alignCenter
                                              ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: (screenScope.dockPosition === "left" || screenScope.dockPosition === "right") && screenScope.alignCenter
                                            ? parent.verticalCenter : undefined

                    width: {
                        switch (screenScope.dockPosition) {
                            case "left":
                            case "right":
                                return screenScope.dockBaseWidth + screenScope.snappyHeadroom + screenScope.edgePadding;
                            case "top":
                            case "bottom":
                            default:
                                return screenScope.dockBaseWidth + screenScope.snappyMainOverflow;
                        }
                    }
                    height: {
                        switch (screenScope.dockPosition) {
                            case "left":
                            case "right":
                                return screenScope.dockBaseHeight + screenScope.snappyMainOverflow;
                            case "top":
                            case "bottom":
                            default:
                                return screenScope.dockBaseHeight + screenScope.snappyHeadroom + screenScope.edgePadding;
                        }
                    }

                    clip: false

                    /* ── Visual dock background (fixed base size) ────── */
                    Rectangle {
                        id: dockBackground

                        /* Rise-growth properties — kept separate from width/height
                           so their Behaviors don't interfere with item-add resizes. */
                        property real _riseW: screenScope.isHorizontal ? screenScope.snappyRiseGrowth : 0
                        property real _riseH: screenScope.isVertical   ? screenScope.snappyRiseGrowth : 0
                        Behavior on _riseW {
                            enabled: screenScope.snappyMode && screenScope.snappyMouseX === screenScope.pointerUnset
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                        Behavior on _riseH {
                            enabled: screenScope.snappyMode && screenScope.snappyMouseX === screenScope.pointerUnset
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        width:  screenScope.dockBaseWidth  + _riseW
                        height: screenScope.dockBaseHeight + _riseH

                        /* Anchor to the screen edge within the container. */
                        anchors.bottom:       screenScope.dockPosition === "bottom" ? parent.bottom : undefined
                        anchors.bottomMargin: screenScope.dockPosition === "bottom" ? screenScope.edgePadding : 0
                        anchors.top:          screenScope.dockPosition === "top"    ? parent.top    : undefined
                        anchors.topMargin:    screenScope.dockPosition === "top"    ? screenScope.edgePadding : 0
                        anchors.left:         screenScope.dockPosition === "left"   ? parent.left   : undefined
                        anchors.leftMargin:   screenScope.dockPosition === "left"   ? screenScope.edgePadding : 0
                        anchors.right:        screenScope.dockPosition === "right"  ? parent.right  : undefined
                        anchors.rightMargin:  screenScope.dockPosition === "right"  ? screenScope.edgePadding : 0
                        /* Center on the main axis */
                        anchors.horizontalCenter: (screenScope.dockPosition === "top" || screenScope.dockPosition === "bottom")
                                                  ? parent.horizontalCenter : undefined
                        anchors.verticalCenter:   (screenScope.dockPosition === "left" || screenScope.dockPosition === "right")
                                                  ? parent.verticalCenter   : undefined

                        radius: Theme.dockRadius
                        color:  Theme.bgColor
                        border.color: Theme.bgBorder
                        border.width: 1
                    }

                    Grid {
                        id: dockLayout
                        clip: false

                        /* Anchor to the screen edge so icons overflow
                           away from the edge into the headroom space.   */
                        anchors.bottom:       screenScope.dockPosition === "bottom" ? parent.bottom : undefined
                        anchors.bottomMargin: screenScope.dockPosition === "bottom" ? Theme.dockPadding + screenScope.edgePadding : 0
                        anchors.top:          screenScope.dockPosition === "top"    ? parent.top    : undefined
                        anchors.topMargin:    screenScope.dockPosition === "top"    ? Theme.dockPadding + screenScope.edgePadding : 0
                        anchors.left:         screenScope.dockPosition === "left"   ? parent.left   : undefined
                        anchors.leftMargin:   screenScope.dockPosition === "left"   ? Theme.dockPadding + screenScope.edgePadding : 0
                        anchors.right:        screenScope.dockPosition === "right"  ? parent.right  : undefined
                        anchors.rightMargin:  screenScope.dockPosition === "right"  ? Theme.dockPadding + screenScope.edgePadding : 0

                        anchors.horizontalCenter: (screenScope.dockPosition === "top" || screenScope.dockPosition === "bottom")
                                                  ? parent.horizontalCenter : undefined
                        anchors.verticalCenter:   (screenScope.dockPosition === "left" || screenScope.dockPosition === "right")
                                                  ? parent.verticalCenter   : undefined

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
