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

    implicitWidth:  size + Theme.itemPadding * 2
    implicitHeight: size + Theme.itemPadding * 2 + dotRow.height + 4

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
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
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
        anchors.top: iconBg.bottom
        anchors.topMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
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
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.bottom: 8
        
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
