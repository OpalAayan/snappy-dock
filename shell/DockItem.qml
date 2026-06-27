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

    property int size: Theme.iconSize
    property string itemId: itemRoot.className + "_" + itemRoot.title
    property bool menuVisible: DaemonBridge.activeMenuId === itemRoot.itemId

    function iconSource() {
        var name = itemRoot.icon || Theme.iconFallback;
        if (!name)
            return "";
        if (name.charAt(0) === "/")
            return "file://" + name;
        return Quickshell.iconPath(name, Theme.iconFallback);
    }

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

    // Fixed implicit sizes keep the dock from shifting as dot count changes.
    implicitWidth:  size + Theme.itemPadding * 2 + (isVertical ? sideIndicatorWidth + indicatorGap : 0)
    implicitHeight: size + Theme.itemPadding * 2 + (isVertical ? 0 : Theme.dotSize + indicatorGap)

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

        anchors.top: (!isVertical && !isTop) ? parent.top : undefined
        anchors.bottom: (!isVertical && isTop) ? parent.bottom : undefined
        anchors.horizontalCenter: isVertical ? undefined : parent.horizontalCenter

        anchors.verticalCenter: isVertical ? parent.verticalCenter : undefined
        anchors.right: (isVertical && isLeft) ? parent.right : undefined
        anchors.left: (isVertical && isRight) ? parent.left : undefined

        width:  itemRoot.size + Theme.itemPadding * 2
        height: itemRoot.size + Theme.itemPadding * 2
        radius: 12
        color:  mouseArea.containsMouse
                    ? (itemRoot.isActive ? Theme.itemActive : Theme.itemHover)
                    : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        /* Hover scale effect */
        scale: mouseArea.containsMouse ? 1.08 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        /* Icon image via Qt icon engine */
        Image {
            id: iconImage
            anchors.centerIn: parent
            width:  itemRoot.size
            height: itemRoot.size
            sourceSize: Qt.size(itemRoot.size, itemRoot.size)
            source: itemRoot.iconSource()
            smooth: true
            asynchronous: true
        }

        /* Mouse handling */
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: function(mouse) {
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
        position: itemRoot.dockPosition
        isVertical: itemRoot.isVertical

        anchors.top: (!itemRoot.isVertical && !itemRoot.isTop) ? iconBg.bottom : undefined
        anchors.topMargin: (!itemRoot.isVertical && !itemRoot.isTop) ? 3 : 0
        anchors.bottom: (!itemRoot.isVertical && itemRoot.isTop) ? iconBg.top : undefined
        anchors.bottomMargin: (!itemRoot.isVertical && itemRoot.isTop) ? 3 : 0
        anchors.horizontalCenter: itemRoot.isVertical ? undefined : parent.horizontalCenter

        anchors.verticalCenter: itemRoot.isVertical ? iconBg.verticalCenter : undefined
        anchors.right: (itemRoot.isVertical && itemRoot.isLeft) ? iconBg.left : undefined
        anchors.rightMargin: (itemRoot.isVertical && itemRoot.isLeft) ? itemRoot.indicatorGap : 0
        anchors.left: (itemRoot.isVertical && itemRoot.isRight) ? iconBg.right : undefined
        anchors.leftMargin: (itemRoot.isVertical && itemRoot.isRight) ? itemRoot.indicatorGap : 0

        count: itemRoot.instanceCount
        active: itemRoot.isActive
    }

    /* ── Tooltip via PopupWindow ───────────────────────────── */
    PopupWindow {
        id: tooltipPopup
        visible: itemRoot.showTooltip && !itemRoot.menuVisible
        anchor.item: itemRoot
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
                text: itemRoot.title || itemRoot.className
                color: Theme.textColor
                font.pixelSize: 12
            }
        }
    }

    /* ── Context Menu via PopupWindow ───────────────────────────── */
    PopupWindow {
        id: calendarPopup
        visible: itemRoot.menuVisible
        grabFocus: true
        anchor.item: itemRoot
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
            width:         calendarPopup.implicitWidth
            height:        calendarPopup.implicitHeight
            
            onCloseMenu: DaemonBridge.activeMenuId = ""
        }
        
        /* ── Global click-away handler to close menu ──────────────── */
        onVisibleChanged: {
            if (visible) {
                itemRoot.showTooltip = false;
                contextMenu.currentPage = 0;
                contextMenu.forceActiveFocus();
            } else if (DaemonBridge.activeMenuId === itemRoot.itemId) {
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
