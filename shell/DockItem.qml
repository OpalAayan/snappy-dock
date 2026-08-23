/*  DockItem.qml  —  Single dock icon with dot indicators + context menu.
 *
 *  Left-click:
 *    - Running → focus first instance
 *    - Pinned-only → launch the app
 *
 *  Right-click:
 *    - Opens DockMenu using PopupWindow (native Wayland surface).
 *
 *  Hover:
 *    - Subtle scale-up
 *    - Tooltip above icon
 *
 *  Snappy mode (DaemonBridge.config.mode === "snappy"):
 *    - Gaussian magnification: icons scale up based on mouse proximity.
 *    - Layout cells stay fixed so the dock does not jitter under the cursor.
 *    - Icons lift away from the screen edge as they grow.
 */
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: itemRoot

    required property string className
    required property string icon
    required property string addr
    required property string title
    required property int    instanceCount
    required property bool   isActive
    required property bool   isPinned
    required property var    instances

    property bool isLauncher: false
    readonly property string launcherIconStr: DaemonBridge.config.launcher_icon || "dots"
    readonly property bool useDots: launcherIconStr === "" || launcherIconStr === "0" || launcherIconStr === "none" || launcherIconStr === "auto" || launcherIconStr === "dots"

    property int size: Theme.iconSize
    property string screenName: ""
    property string itemId: itemRoot.screenName + "_" + itemRoot.className + "_" + itemRoot.title
    property bool menuVisible: DaemonBridge.activeMenuId === itemRoot.itemId

    property string dockPosition: {
        var pos = String(DaemonBridge.config.position || "bottom").toLowerCase();
        if (pos === "top" || pos === "bottom" || pos === "left" || pos === "right")
            return pos;
        return "bottom";
    }
    property bool isLeft: dockPosition === "left"
    property bool isRight: dockPosition === "right"
    property bool isTop: dockPosition === "top"
    property bool isVertical: isLeft || isRight
    readonly property int indicatorGap: 4
    readonly property int sideIndicatorWidth: Math.max(Theme.dotSize * 2, Theme.dotActiveWidth - 4)

    /* Fixed implicit sizes keep the dock from shifting while icons animate.
       Each position computes independently — no shared isVertical ternary. */
    readonly property real baseWidth: {
        switch (dockPosition) {
            case "left":
            case "right":
                return size + Theme.itemPadding * 2 + sideIndicatorWidth + indicatorGap;
            case "top":
            case "bottom":
            default:
                return size + Theme.itemPadding * 2;
        }
    }
    readonly property real baseHeight: {
        switch (dockPosition) {
            case "left":
            case "right":
                return size + Theme.itemPadding * 2;
            case "top":
            case "bottom":
            default:
                return size + Theme.itemPadding * 2 + Theme.dotSize + indicatorGap;
        }
    }

    /* ── Snappy mode input from Dock.qml ─────────────────────────── */
    property real dockMouseX: -100000
    property real dockMouseY: -100000
    property real dockPointerUnset: -100000

    /* Config-driven magnification tuning */
    property real magnification: 0.78
    property int  spread: 3

    /* Cumulative displacement from Dock.qml — pushes icons apart
       along the main axis when magnified (snappy mode only). */
    property real snappyMainDisplacement: 0

    readonly property bool snappyMode: DaemonBridge.config.mode === "snappy"
    readonly property bool hasDockPointer: dockMouseX !== dockPointerUnset
                                           && dockMouseY !== dockPointerUnset
    readonly property real snappyAxisMouse: {
        switch (dockPosition) {
            case "left":
            case "right":
                return dockMouseY;
            case "top":
            case "bottom":
            default:
                return dockMouseX;
        }
    }
    readonly property real snappyAxisCenter: {
        switch (dockPosition) {
            case "left":
            case "right":
                return itemRoot.y + baseHeight / 2.0;
            case "top":
            case "bottom":
            default:
                return itemRoot.x + baseWidth / 2.0;
        }
    }

    /* Gaussian bell curve: closest icon peaks, neighbors taper smoothly.
     * sigma derives from spread (how many icon-widths of falloff).
     * magnification controls the peak scale boost above 1.0.
     */
    readonly property real snappyMaxScale: 1.0 + Math.max(0.0, Math.min(2.0, magnification))
    readonly property real snappySigma: {
        var cellSize;
        switch (dockPosition) {
            case "left":
            case "right":
                cellSize = baseHeight; break;
            case "top":
            case "bottom":
            default:
                cellSize = baseWidth; break;
        }
        /* spread=3 means ~3 icon cells of visible influence */
        return Math.max(cellSize * spread * 0.42, 40);
    }
    readonly property real snappyInfluenceRadius: snappySigma * 2.8

    function gaussianScale(distance) {
        var d = Math.abs(distance);
        if (d >= snappyInfluenceRadius)
            return 1.0;

        var influence = Math.exp(-(d * d) / (2.0 * snappySigma * snappySigma));
        return 1.0 + (snappyMaxScale - 1.0) * influence;
    }

    /* When the context menu is open, freeze this icon at peak magnification
       so it stays lifted and visually connected to the menu popup.
       Otherwise compute normally from the Gaussian bell curve. */
    property real _frozenScale: snappyMaxScale
    property real snappyScale: {
        if (!snappyMode)
            return 1.0;
        if (menuVisible)
            return _frozenScale;
        if (!hasDockPointer)
            return 1.0;
        return gaussianScale(snappyAxisCenter - snappyAxisMouse);
    }

    /* Capture the scale at the moment the menu opens so the icon
       holds exactly where it was, not necessarily at max. */
    onMenuVisibleChanged: {
        if (menuVisible && snappyMode) {
            _frozenScale = Math.max(snappyScale, 1.15);
        }
    }

    /* Only animate scale when the pointer leaves (icons settle back).
       During active hover the Gaussian math drives scale directly —
       the mouse itself provides smooth 60Hz+ updates, so a Behavior
       animation is redundant and creates overlapping animation overhead. */
    Behavior on snappyScale {
        enabled: !itemRoot.hasDockPointer && !itemRoot.menuVisible
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Behavior on snappyMainDisplacement {
        enabled: !itemRoot.hasDockPointer && !itemRoot.menuVisible
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    readonly property real snappyLift: (snappyScale - 1.0) * size * 0.85
    readonly property real snappyTranslateX: {
        if (!snappyMode) return 0;
        switch (dockPosition) {
            case "left":  return snappyLift;
            case "right": return -snappyLift;
            default:      return 0;
        }
    }
    readonly property real snappyTranslateY: {
        if (!snappyMode) return 0;
        switch (dockPosition) {
            case "top":    return snappyLift;
            case "bottom": return -snappyLift;
            default:       return 0;
        }
    }

    z: snappyMode ? snappyScale : (mouseArea.containsMouse ? 1 : 0)

    function iconSource() {
        var name = itemRoot.icon || Theme.iconFallback;
        if (!name)
            return "";
        if (name.charAt(0) === "/")
            return "file://" + name;
        return Quickshell.iconPath(name, Theme.iconFallback);
    }

    implicitWidth:  baseWidth
    implicitHeight: baseHeight

    /* Main-axis displacement: shifts the entire DockItem (icon + dots)
       so magnified icons push neighbors apart without Grid reflow.
       Cross-axis lift stays on iconBg so dots remain at the edge. */
    transform: Translate {
        x: itemRoot.isVertical ? 0 : itemRoot.snappyMainDisplacement
        y: itemRoot.isVertical ? itemRoot.snappyMainDisplacement : 0
    }

    property bool showTooltip: false

    Timer {
        id: hoverTimer
        interval: 300
        running: mouseArea.containsMouse && !itemRoot.menuVisible
        onTriggered: itemRoot.showTooltip = true
    }

    Connections {
        target: mouseArea
        function onContainsMouseChanged() {
            if (!mouseArea.containsMouse) {
                itemRoot.showTooltip = false;
            }
        }
    }

    /* ── Icon container ──────────────────────────────────────────── */
    Rectangle {
        id: iconBg

        readonly property real iconBaseExtent: itemRoot.size + Theme.itemPadding * 2

        /* Position-specific anchoring — each edge is explicit. */
        anchors.top:    dockPosition === "bottom" ? parent.top    : undefined
        anchors.bottom: dockPosition === "top"    ? parent.bottom : undefined
        anchors.left:   dockPosition === "right"  ? parent.left   : undefined
        anchors.right:  dockPosition === "left"   ? parent.right  : undefined
        anchors.horizontalCenter: (dockPosition === "top" || dockPosition === "bottom")
                                  ? parent.horizontalCenter : undefined
        anchors.verticalCenter:   (dockPosition === "left" || dockPosition === "right")
                                  ? parent.verticalCenter : undefined

        width:  iconBaseExtent
        height: iconBaseExtent
        radius: Math.round(iconBaseExtent * 0.22)
        color:  itemRoot.isLauncher
                ? ((DaemonBridge.config.launcher_hover_bg !== false && mouseArea.containsMouse) ? Theme.itemHover : "transparent")
                : ((DaemonBridge.config.icon_hover_bg !== false && mouseArea.containsMouse)
                    ? (itemRoot.isActive ? Theme.itemActive : Theme.itemHover)
                    : "transparent")

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        scale: itemRoot.snappyMode ? itemRoot.snappyScale
                                   : (mouseArea.containsMouse ? 1.08 : 1.0)

        Behavior on scale {
            enabled: !itemRoot.snappyMode
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        transform: Translate {
            x: itemRoot.snappyTranslateX
            y: itemRoot.snappyTranslateY
        }

        /* Icon image via Qt icon engine (regular apps) */
        Image {
            id: iconImage
            visible: !itemRoot.isLauncher
            anchors.centerIn: parent
            width:  itemRoot.size
            height: itemRoot.size
            sourceSize: Qt.size(Math.ceil(itemRoot.size * itemRoot.snappyMaxScale),
                                Math.ceil(itemRoot.size * itemRoot.snappyMaxScale))
            source: itemRoot.isLauncher ? "" : itemRoot.iconSource()
            smooth: true
            mipmap: true
            asynchronous: true
        }

        /* 9-dot grid for default launcher */
        Grid {
            id: dotsGrid
            anchors.centerIn: parent
            columns: 3
            spacing: Math.max(1, Math.round(itemRoot.size / 8))
            visible: itemRoot.isLauncher && itemRoot.useDots

            Repeater {
                model: 9
                Rectangle {
                    readonly property real dSize: Math.max(2, Math.round(itemRoot.size / 5))
                    width: dSize
                    height: dSize
                    radius: dSize / 2
                    color: mouseArea.containsMouse ? Theme.accentColor : Theme.textColor
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
        }

        /* Text or Nerd Font symbol for custom launcher icon */
        Text {
            anchors.centerIn: parent
            visible: itemRoot.isLauncher && !itemRoot.useDots
            text: itemRoot.launcherIconStr
            font.family: Theme.fontFamily
            font.weight: Theme.fontWeight
            font.pixelSize: (DaemonBridge.config.launcher_icon_size > 0)
                            ? DaemonBridge.config.launcher_icon_size
                            : (itemRoot.size + 2)
            color: mouseArea.containsMouse ? Theme.accentColor : Theme.textColor
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        /* Mouse handling */
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: function(mouse) {
                if (itemRoot.isLauncher) {
                    DaemonBridge.launchCmd(DaemonBridge.config.launcher_cmd || "fuzzel");
                    return;
                }
                if (mouse.button === Qt.RightButton) {
                    if (DaemonBridge.activeMenuId === itemRoot.itemId) {
                        DaemonBridge.activeMenuId = "";
                    } else {
                        DaemonBridge.activeMenuId = itemRoot.itemId;
                    }
                } else {
                    if (itemRoot.instanceCount > 0 && itemRoot.addr) {
                        DaemonBridge.focus(itemRoot.addr);
                    } else {
                        DaemonBridge.launch(itemRoot.className);
                    }
                    DaemonBridge.activeMenuId = "";
                }
            }
        }
    }

    /* ── Dot indicators ──────────────────────────────────────────── */
    DotIndicator {
        id: dotRow
        visible: !itemRoot.isLauncher
        position: itemRoot.dockPosition
        isVertical: itemRoot.dockPosition === "left" || itemRoot.dockPosition === "right"

        /* Bottom: dots below icon */
        anchors.top:       itemRoot.dockPosition === "bottom" ? iconBg.bottom : undefined
        anchors.topMargin: itemRoot.dockPosition === "bottom" ? 3 : 0
        /* Top: dots above icon */
        anchors.bottom:       itemRoot.dockPosition === "top" ? iconBg.top : undefined
        anchors.bottomMargin: itemRoot.dockPosition === "top" ? 3 : 0
        /* Horizontal center for top/bottom */
        anchors.horizontalCenter: (itemRoot.dockPosition === "top" || itemRoot.dockPosition === "bottom")
                                  ? parent.horizontalCenter : undefined

        /* Left dock: dots on left (screen edge) of icon */
        anchors.right:       itemRoot.dockPosition === "left" ? iconBg.left : undefined
        anchors.rightMargin: itemRoot.dockPosition === "left" ? itemRoot.indicatorGap : 0
        /* Right dock: dots on right (screen edge) of icon */
        anchors.left:       itemRoot.dockPosition === "right" ? iconBg.right : undefined
        anchors.leftMargin: itemRoot.dockPosition === "right" ? itemRoot.indicatorGap : 0
        /* Vertical center for left/right */
        anchors.verticalCenter: (itemRoot.dockPosition === "left" || itemRoot.dockPosition === "right")
                                ? iconBg.verticalCenter : undefined

        count: itemRoot.isLauncher ? 0 : itemRoot.instanceCount
        active: itemRoot.isActive
    }

    /* ── Tooltip via PopupWindow ───────────────────────────── */
    PopupWindow {
        id: tooltipPopup
        visible: itemRoot.showTooltip && !itemRoot.menuVisible
        anchor.item: iconBg
        anchor.edges: {
            var pos = DaemonBridge.config.position || "bottom";
            if (pos === "top") return Edges.Bottom;
            if (pos === "left") return Edges.Right;
            if (pos === "right") return Edges.Left;
            return Edges.Top;
        }
        anchor.gravity: anchor.edges
        
        anchor.margins.top:    DaemonBridge.config.position === "top" ? 8 : 0
        anchor.margins.bottom: DaemonBridge.config.position === "bottom" || !DaemonBridge.config.position ? 8 : 0
        anchor.margins.left:   DaemonBridge.config.position === "left" ? 8 : 0
        anchor.margins.right:  DaemonBridge.config.position === "right" ? 8 : 0
        
        implicitWidth: tooltipRect.width
        implicitHeight: tooltipRect.height
        color: "transparent"

        Rectangle {
            id: tooltipRect
            width: tipText.implicitWidth + 16
            height: tipText.implicitHeight + 10
            radius: 8
            color: Theme.menuBg
            border.color: Theme.menuBorder
            border.width: 1

            Text {
                id: tipText
                anchors.centerIn: parent
                text: itemRoot.isLauncher ? "Applications" : (itemRoot.title || itemRoot.className)
                color: Theme.textColor
                font.pixelSize: 12
                font.family: Theme.fontFamily
            }
        }
    }

    /* ── Context Menu via PopupWindow ───────────────────────────── */
    PopupWindow {
        id: calendarPopup
        visible: !itemRoot.isLauncher && itemRoot.menuVisible
        grabFocus: true
        anchor.item: iconBg
        anchor.edges: {
            var pos = DaemonBridge.config.position || "bottom";
            if (pos === "top") return Edges.Bottom;
            if (pos === "left") return Edges.Right;
            if (pos === "right") return Edges.Left;
            return Edges.Top;
        }
        anchor.gravity: anchor.edges
        
        anchor.margins.top:    DaemonBridge.config.position === "top" ? 8 : 0
        anchor.margins.bottom: DaemonBridge.config.position === "bottom" || !DaemonBridge.config.position ? 8 : 0
        anchor.margins.left:   DaemonBridge.config.position === "left" ? 8 : 0
        anchor.margins.right:  DaemonBridge.config.position === "right" ? 8 : 0
        
        implicitWidth: contextMenu.implicitWidth
        implicitHeight: contextMenu.implicitHeight

        color: "transparent"

        DockMenu {
            id: contextMenu
            className:     itemRoot.className
            isPinned:      itemRoot.isPinned
            instanceCount: itemRoot.instanceCount
            instances:     itemRoot.instances
            appIcon:       itemRoot.icon || ""
            snappyMode:    itemRoot.snappyMode
            dockPosition:  DaemonBridge.config.position || "bottom"
            width:         calendarPopup.implicitWidth
            height:        calendarPopup.implicitHeight
            
            onCloseMenu: DaemonBridge.activeMenuId = ""
        }
        
        /* ── Global click-away handler to close menu ──────────────── */
        onVisibleChanged: {
            if (visible) {
                itemRoot.showTooltip = false;
                contextMenu.currentPage = 0;
                contextMenu._menuOpen = false;
                contextMenu._menuOpen = true;
                contextMenu.forceActiveFocus();
            } else if (DaemonBridge.activeMenuId === itemRoot.itemId) {
                contextMenu._menuOpen = false;
                DaemonBridge.activeMenuId = "";
            }
        }

        onImplicitWidthChanged: {
            // Reposition handled by anchors
        }

        onImplicitHeightChanged: {
            // Reposition handled by anchors
        }
    }
}
