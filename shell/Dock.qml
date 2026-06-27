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

            /* ── Layout metrics ──────────────────────────────────────── */
            readonly property int visibleItemCount: DaemonBridge.dockItems.length
                                                    + (showLauncher ? 1 : 0)
                                                    + (showLauncher && DaemonBridge.dockItems.length > 0 ? 1 : 0)
            readonly property int itemExtent:    Theme.iconSize + Theme.itemPadding * 2
            readonly property int marginTop:     numberOrDefault(DaemonBridge.config.margin_top,    0)
            readonly property int marginBottom:  numberOrDefault(DaemonBridge.config.margin_bottom,  5)
            readonly property int marginLeft:    numberOrDefault(DaemonBridge.config.margin_left,    0)
            readonly property int marginRight:   numberOrDefault(DaemonBridge.config.margin_right,   0)
            readonly property int configuredExclusiveZone: exclusiveZoneFromConfig(DaemonBridge.config.exclusive_zone)
            readonly property bool wantsFullCrossAxis: Boolean(DaemonBridge.config.full_width) || alignStart || alignEnd

            /* ── Dock content dimensions ─────────────────────────────── */
            readonly property real dockContentWidth:  dockLayout.implicitWidth  + Theme.dockPadding * 2
            readonly property real dockContentHeight: dockLayout.implicitHeight + Theme.dockPadding * 2
            readonly property real panelWidth:  isHorizontal
                                                ? (wantsFullCrossAxis ? modelData.width : dockContentWidth)
                                                : dockContentWidth
            readonly property real panelHeight: isVertical
                                                ? (wantsFullCrossAxis ? modelData.height : dockContentHeight)
                                                : dockContentHeight

            /* ── AutoHide metrics ────────────────────────────────────── */

            /* Pixels of the dock that remain visible at the screen edge
               when hidden.  Acts as the hover hotspot to trigger reveal. */
            readonly property int edgeStripSize: 2

            /* The margin value for the dock's edge when fully hidden.
               Negative, pushing the panel offscreen except edgeStripSize px. */
            readonly property real hiddenEdgeMargin: edgeStripSize
                                                     - (isVertical ? panelWidth : panelHeight)

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

                    Rectangle {
                        width:  screenScope.itemExtent
                        height: screenScope.itemExtent
                        color:  launcherMouse.containsMouse ? Theme.itemHover : "transparent"
                        radius: 12

                        Behavior on color { ColorAnimation { duration: 120 } }
                        scale: launcherMouse.containsMouse ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Grid {
                            anchors.centerIn: parent
                            columns: 3
                            spacing: 4

                            Repeater {
                                model: 9
                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: launcherMouse.containsMouse
                                           ? Theme.accentColor : Theme.textColor
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }
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

                /* ── Inline component: separator ─────────────────────── */
                Component {
                    id: separatorComponent

                    Item {
                        width:  screenScope.isVertical ? screenScope.itemExtent : 12
                        height: screenScope.isVertical ? 12 : screenScope.itemExtent

                        Rectangle {
                            width:  screenScope.isVertical ? parent.width * 0.4 : 2
                            height: screenScope.isVertical ? 2 : parent.height * 0.4
                            anchors.centerIn: parent
                            color: Theme.bgBorder
                            radius: 1
                        }
                    }
                }

                /* ── Dock container (background + layout) ────────────── */
                Rectangle {
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

                    width:  screenScope.dockContentWidth
                    height: screenScope.dockContentHeight

                    radius: Theme.dockRadius
                    color:  Theme.bgColor
                    border.color: Theme.bgBorder
                    border.width: 1

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Grid {
                        id: dockLayout
                        anchors.centerIn: parent
                        columns: screenScope.isVertical ? 1 : Math.max(1, screenScope.visibleItemCount)
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
