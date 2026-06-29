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
            readonly property bool showLauncher:   normalizedLauncherPos(DaemonBridge.config.launcher_pos) !== "none"
            readonly property bool launcherAtEnd:  normalizedLauncherPos(DaemonBridge.config.launcher_pos) === "end"
            readonly property bool snappyMode:     DaemonBridge.config.mode === "snappy"

            /* ── Layout metrics ──────────────────────────────────────── */
            readonly property int visibleItemCount: DaemonBridge.dockItems.length
                                                    + (showLauncher ? 1 : 0)
                                                    + (showLauncher && DaemonBridge.dockItems.length > 0 ? 1 : 0)
            readonly property int itemExtent:    Theme.iconSize + Theme.itemPadding * 2
            readonly property int indicatorGap: 4
            readonly property int sideIndicatorWidth: Math.max(Theme.dotSize * 2, Theme.dotActiveWidth - 4)
            readonly property int dockItemWidth:  itemExtent + (isVertical ? sideIndicatorWidth + indicatorGap : 0)
            readonly property int dockItemHeight: itemExtent + (isVertical ? 0 : Theme.dotSize + indicatorGap)
            readonly property int marginTop:     numberOrDefault(DaemonBridge.config.margin_top,    0)
            readonly property int marginBottom:  numberOrDefault(DaemonBridge.config.margin_bottom,  5)
            readonly property int marginLeft:    numberOrDefault(DaemonBridge.config.margin_left,    0)
            readonly property int marginRight:   numberOrDefault(DaemonBridge.config.margin_right,   0)
            readonly property int configuredExclusiveZone: exclusiveZoneFromConfig(DaemonBridge.config.exclusive_zone)
            readonly property bool wantsFullCrossAxis: Boolean(DaemonBridge.config.full_width) || alignStart || alignEnd

            /* ── Dock content dimensions ─────────────────────────────── */
            /* The dock background (dockBackground) stays at base size.
               The PanelWindow is taller/wider by snappyHeadroom so the
               compositor does not clip magnified icons.  The extra space
               is transparent and sits on the "away from edge" side.
               In static mode headroom is 0, so panel == background.    */
            readonly property real snappyMagnification: snappyMode
                                                       ? Math.max(0.0, Math.min(2.0, DaemonBridge.config.magnification || 0.78))
                                                       : 0.0
            readonly property real snappyHeadroom: snappyMode
                                                   ? Math.ceil(Theme.iconSize * snappyMagnification * 1.1)
                                                   : 0
            /* Main-axis overflow: edge icons grow wider/taller when magnified
               and get clipped at the panel surface boundary.  Add symmetric
               padding so they have room.  (cross-axis uses snappyHeadroom.) */
            readonly property real snappyMainOverflow: snappyMode
                                                      ? Math.ceil(Theme.iconSize * snappyMagnification * 0.55) * 2
                                                      : 0
            readonly property real dockBaseWidth:   mainLayout.implicitWidth  + Theme.dockPadding * 2
            readonly property real dockBaseHeight:  mainLayout.implicitHeight + Theme.dockPadding * 2
            readonly property real panelWidth:  isHorizontal
                                                ? (wantsFullCrossAxis ? modelData.width : dockBaseWidth + (isHorizontal ? snappyMainOverflow : 0))
                                                : dockBaseWidth + (isVertical ? snappyHeadroom : 0)
            readonly property real panelHeight: isVertical
                                                ? (wantsFullCrossAxis ? modelData.height : dockBaseHeight + (isVertical ? snappyMainOverflow : 0))
                                                : dockBaseHeight + (isHorizontal ? snappyHeadroom : 0)

            /* ── AutoHide metrics ────────────────────────────────────── */

            /* Pixels of the dock that remain visible at the screen edge
               when hidden.  Acts as the hover hotspot to trigger reveal. */
            readonly property int edgeStripSize: 2

            /* The margin value for the dock's edge when fully hidden.
               Negative, pushing the panel offscreen except edgeStripSize px. */
            readonly property real hiddenEdgeMargin: edgeStripSize
                                                     - (isVertical ? panelWidth : panelHeight)

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
               edge is animated; all other edges pass through. */
            function animatedMargin(isActiveEdge, configuredMargin) {
                if (!isActiveEdge)
                    return configuredMargin;
                return configuredMargin
                       + _hideProgress * (hiddenEdgeMargin - configuredMargin);
            }

            function clearSnappyPointer() {
                snappyMouseX = pointerUnset;
                snappyMouseY = pointerUnset;
            }

            function updateSnappyPointerFromContainer(x, y) {
                if (!snappyMode) {
                    clearSnappyPointer();
                    return;
                }

                var mapped = dockContainer.mapToItem(dockLayout, x, y);
                var axisValue = isVertical ? mapped.y : mapped.x;
                var axisSize = isVertical ? dockLayout.height : dockLayout.width;
                if (axisSize <= 0
                    || axisValue < -snappyAxisMargin
                    || axisValue > axisSize + snappyAxisMargin) {
                    clearSnappyPointer();
                    return;
                }

                snappyMouseX = mapped.x;
                snappyMouseY = mapped.y;
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
                    top:    screenScope.isTop    || (screenScope.isVertical   && screenScope.wantsFullCrossAxis)
                    bottom: screenScope.isBottom || (screenScope.isVertical   && screenScope.wantsFullCrossAxis)
                    left:   screenScope.isLeft   || (screenScope.isHorizontal && screenScope.wantsFullCrossAxis)
                    right:  screenScope.isRight  || (screenScope.isHorizontal && screenScope.wantsFullCrossAxis)
                }

                /* Margins are animated to push the surface offscreen.
                   Only the dock's primary edge margin changes; the other
                   edges keep their configured values.
                   Hyprland passes int32_t margins straight into the
                   geometry calculation, so negative values work natively. */
                margins {
                    top:    screenScope.animatedMargin(screenScope.isTop,    screenScope.marginTop)
                    bottom: screenScope.animatedMargin(screenScope.isBottom, screenScope.marginBottom)
                    left:   screenScope.animatedMargin(screenScope.isLeft,   screenScope.marginLeft)
                    right:  screenScope.animatedMargin(screenScope.isRight,  screenScope.marginRight)
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

                /* Input region tracks dockContainer's geometry.
                   Because margins move the whole surface (not a render
                   transform), this Region always matches the visual
                   position perfectly.  When hidden, the compositor
                   clips the region to the visible edge strip. */
                mask: Region {
                    item: dockContainer
                }

                /* ── Inline component: launcher button ───────────────── */
                Component {
                    id: launcherButtonComponent

                    Item {
                        id: launcherItem
                        width: screenScope.dockItemWidth
                        height: screenScope.dockItemHeight

                        readonly property string customIconStr: DaemonBridge.config.launcher_icon || "dots"
                        readonly property bool useDots: customIconStr === "" || customIconStr === "0" || customIconStr === "none" || customIconStr === "auto" || customIconStr === "dots"
                        
                        readonly property int hoverSizeParam: DaemonBridge.config.launcher_hover_bg_size || 0
                        readonly property int hoverBgSize: hoverSizeParam > 0 ? hoverSizeParam : screenScope.itemExtent
                        readonly property bool showHoverBg: DaemonBridge.config.launcher_hover_bg !== false

                        Rectangle {
                            id: launcherBg
                            anchors.centerIn: parent
                            width:  launcherItem.hoverBgSize
                            height: launcherItem.hoverBgSize
                            color:  (launcherItem.showHoverBg && launcherMouse.containsMouse) ? Theme.itemHover : "transparent"
                            radius: Math.min(width / 2, Math.max(4, Math.round(width * 0.25)))

                            readonly property real customSize: DaemonBridge.config.launcher_icon_size || 0
                            readonly property real baseSize: customSize > 0 ? customSize : Theme.iconSize + 2
                            readonly property real targetGridSize: baseSize
                            readonly property real dotSize: Math.max(2, Math.round(targetGridSize / 5))
                            readonly property real dotSpacing: Math.max(1, Math.round(targetGridSize / 8))

                            Behavior on color { ColorAnimation { duration: 120 } }
                            scale: launcherMouse.containsMouse ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Grid {
                                anchors.centerIn: parent
                                columns: 3
                                spacing: launcherBg.dotSpacing
                                visible: launcherItem.useDots

                                Repeater {
                                    model: 9
                                    Rectangle {
                                        width: launcherBg.dotSize; height: launcherBg.dotSize; radius: launcherBg.dotSize / 2
                                        color: launcherMouse.containsMouse
                                               ? Theme.accentColor : Theme.textColor
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !launcherItem.useDots
                                text: launcherItem.customIconStr
                                font.family: Theme.fontFamily
                                font.weight: Theme.fontWeight
                                font.pixelSize: launcherBg.baseSize
                                color: launcherMouse.containsMouse ? Theme.accentColor : Theme.textColor
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: launcherMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    DaemonBridge.launchCmd(DaemonBridge.config.launcher_cmd || "fuzzel");
                                }
                            }
                        }
                    }
                }

                /* ── Inline component: separator ─────────────────────── */
                Component {
                    id: separatorComponent

                    Item {
                        width:  screenScope.isVertical ? screenScope.dockItemWidth : 12
                        height: screenScope.isVertical ? 12 : screenScope.dockItemHeight

                        Rectangle {
                            width:  screenScope.isVertical ? screenScope.itemExtent * 0.4 : 2
                            height: screenScope.isVertical ? 2 : screenScope.itemExtent * 0.4
                            anchors.centerIn: parent
                            color: Theme.bgBorder
                            radius: 1
                        }
                    }
                }

                /* ── Dock container (input region, full panel size) ──── */
                /* dockContainer is the full panel size so hover/click
                   detection works in the magnification overflow zone.
                   The visual background is a child Rectangle.           */
                Item {
                    id: dockContainer

                    anchors.left: screenScope.isLeft || (screenScope.isHorizontal && screenScope.alignStart)
                                  ? parent.left : undefined
                    anchors.right: screenScope.isRight || (screenScope.isHorizontal && screenScope.alignEnd)
                                   ? parent.right : undefined
                    anchors.top: screenScope.isTop || (screenScope.isVertical && screenScope.alignStart)
                                 ? parent.top : undefined
                    anchors.bottom: screenScope.isBottom || (screenScope.isVertical && screenScope.alignEnd)
                                    ? parent.bottom : undefined
                    anchors.horizontalCenter: screenScope.isHorizontal && screenScope.alignCenter
                                              ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: screenScope.isVertical && screenScope.alignCenter
                                            ? parent.verticalCenter : undefined

                    width:  screenScope.isHorizontal ? screenScope.dockBaseWidth + screenScope.snappyMainOverflow
                                                    : screenScope.dockBaseWidth + screenScope.snappyHeadroom
                    height: screenScope.isHorizontal ? screenScope.dockBaseHeight + screenScope.snappyHeadroom
                                                    : screenScope.dockBaseHeight + screenScope.snappyMainOverflow

                    clip: false

                    /* ── Visual dock background (fixed base size) ────── */
                    Rectangle {
                        id: dockBackground

                        width:  screenScope.dockBaseWidth
                        height: screenScope.dockBaseHeight

                        /* Anchor to the screen edge within the container. */
                        anchors.bottom: screenScope.isBottom ? parent.bottom : undefined
                        anchors.top:    screenScope.isTop    ? parent.top    : undefined
                        anchors.left:   screenScope.isLeft   ? parent.left   : undefined
                        anchors.right:  screenScope.isRight  ? parent.right  : undefined
                        /* Center on the main axis */
                        anchors.horizontalCenter: screenScope.isHorizontal ? parent.horizontalCenter : undefined
                        anchors.verticalCenter:   screenScope.isVertical   ? parent.verticalCenter   : undefined

                        radius: Theme.dockRadius
                        color:  Theme.bgColor
                        border.color: Theme.bgBorder
                        border.width: 1
                    }

                    Grid {
                        id: mainLayout
                        clip: false

                        /* Anchor to the screen edge so icons overflow
                           away from the edge into the headroom space.   */
                        anchors.bottom: screenScope.isBottom ? parent.bottom : undefined
                        anchors.bottomMargin: screenScope.isBottom ? Theme.dockPadding : 0
                        anchors.top:    screenScope.isTop    ? parent.top    : undefined
                        anchors.topMargin: screenScope.isTop ? Theme.dockPadding : 0
                        anchors.left:   screenScope.isLeft   ? parent.left   : undefined
                        anchors.leftMargin: screenScope.isLeft ? Theme.dockPadding : 0
                        anchors.right:  screenScope.isRight  ? parent.right  : undefined
                        anchors.rightMargin: screenScope.isRight ? Theme.dockPadding : 0

                        anchors.horizontalCenter: screenScope.isHorizontal ? parent.horizontalCenter : undefined
                        anchors.verticalCenter:   screenScope.isVertical   ? parent.verticalCenter   : undefined

                        columns: screenScope.isVertical ? 1 : 5
                        spacing: Theme.itemSpacing

                        Loader {
                            active: screenScope.showLauncher && !screenScope.launcherAtEnd
                            visible: active
                            sourceComponent: launcherButtonComponent
                        }

                        Loader {
                            active: screenScope.showLauncher
                                    && !screenScope.launcherAtEnd
                                    && DaemonBridge.dockItems.length > 0
                            visible: active
                            sourceComponent: separatorComponent
                        }

                        Grid {
                            id: dockLayout
                            clip: false
                            columns: screenScope.isVertical ? 1 : Math.max(1, DaemonBridge.dockItems.length)
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
                                model: DaemonBridge.dockItems.length

                                DockItem {
                                    required property int index
                                    readonly property var modelData: DaemonBridge.dockItems[index] || ({})

                                    className:     modelData.className     || ""
                                    icon:          modelData.icon          || ""
                                    addr:          modelData.addr          || ""
                                    title:         modelData.title         || ""
                                    instanceCount: modelData.instanceCount || 0
                                    isActive:      modelData.isActive      || false
                                    isPinned:      modelData.isPinned      || false
                                    instances:     modelData.instances     || []
                                    size:          Theme.iconSize
                                    dockMouseX:    screenScope.snappyMouseX
                                    dockMouseY:    screenScope.snappyMouseY
                                    dockPointerUnset: screenScope.pointerUnset
                                    magnification: DaemonBridge.config.magnification || 0.78
                                    spread:        DaemonBridge.config.spread || 3
                                }
                            }
                        }

                        Loader {
                            active: screenScope.showLauncher
                                    && screenScope.launcherAtEnd
                                    && DaemonBridge.dockItems.length > 0
                            visible: active
                            sourceComponent: separatorComponent
                        }

                        Loader {
                            active: screenScope.showLauncher && screenScope.launcherAtEnd
                            visible: active
                            sourceComponent: launcherButtonComponent
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

                    /* Hover detection for the dock.
                       When hidden, the compositor clips dockContainer
                       to the visible edge strip — hovering those pixels
                       triggers this handler to reveal the dock.
                       When visible, it keeps the dock open while the
                       cursor is anywhere over dockContainer. */
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

            /* Delay before hiding after the cursor leaves the dock. */
            Timer {
                id: hideTimer
                interval: Theme.hideDelayMs
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
