/*  DockMenu.qml  —  Right-click context menu with stack-based navigation.
 *
 *  v2: Snappy-mode aware with scale-in animation, page slide transitions,
 *  app icon header, and state-aware active indicators.
 */
import QtQuick
import Quickshell

FocusScope {
    id: root

    required property string className
    required property bool   isPinned
    required property int    instanceCount
    required property var    instances

    /* New props for snappy-aware menu */
    property string appIcon: ""
    property bool   snappyMode: false
    property string dockPosition: "bottom"

    signal closeMenu()

    /* Navigation State */
    property int currentPage: 0 // 0 = Main, 1 = Instance, 2 = Workspace
    property int _prevPage: 0
    property string _activeAddr: ""

    /* Live lookup: always reflects the latest daemon state for this window */
    readonly property var activeInstance: {
        if (!_activeAddr || !root.instances) return null;
        for (var i = 0; i < root.instances.length; i++) {
            if (root.instances[i].addr === _activeAddr)
                return root.instances[i];
        }
        return null;
    }

    /* Dedicated reactive booleans — read directly from DaemonBridge.clients */
    readonly property bool _isFloating: {
        if (!_activeAddr) return false;
        var cl = DaemonBridge.clients;
        for (var i = 0; i < cl.length; i++) {
            if (cl[i].addr === _activeAddr)
                return !!cl[i].floating;
        }
        return false;
    }
    readonly property bool _isFullscreen: {
        if (!_activeAddr) return false;
        var cl = DaemonBridge.clients;
        for (var i = 0; i < cl.length; i++) {
            if (cl[i].addr === _activeAddr)
                return !!cl[i].fullscreen;
        }
        return false;
    }

    readonly property int workspaceCount: Math.max(1, DaemonBridge.config.workspace_count || 10)
    readonly property int menuContentWidth: Theme.menuWidth - Theme.menuPadding * 2

    /* Page height calculation */
    readonly property int mainRowCount: (root.instances ? root.instances.length : 0)
                                      + 2
                                      + (root.instanceCount > 0 ? 1 : 0)
    readonly property int mainSeparatorCount: root.instanceCount > 0 ? 1 : 0
    readonly property int instanceRowCount: 5
    readonly property int instanceSeparatorCount: 1
    readonly property int maxVisibleWorkspaces: 5
    readonly property int workspaceRowCount: Math.min(root.workspaceCount, maxVisibleWorkspaces) + 1
    readonly property int workspaceSeparatorCount: 1

    function pageHeight(rowCount, separatorCount) {
        var childCount = rowCount + separatorCount;
        if (childCount <= 0) return 0;
        return rowCount * Theme.menuItemHeight
            + separatorCount * Theme.menuSeparatorHeight
            + (childCount - 1) * Theme.menuSpacing;
    }

    /* Header height included in total */
    readonly property int headerHeight: 38
    readonly property int headerMargin: 4

    readonly property int activePageContentHeight: currentPage === 0
        ? pageHeight(mainRowCount, mainSeparatorCount)
        : currentPage === 1
            ? pageHeight(instanceRowCount, instanceSeparatorCount)
            : currentPage === 2
                ? pageHeight(workspaceRowCount, workspaceSeparatorCount)
                : 0

    implicitWidth: Theme.menuWidth
    implicitHeight: headerHeight + headerMargin + activePageContentHeight + Theme.menuPadding * 2
    width: implicitWidth
    height: implicitHeight

    /* ── Snappy open/close animation ──────────────────────────── */
    property bool _menuOpen: false

    transformOrigin: {
        if (dockPosition === "top") return Item.Top;
        if (dockPosition === "left") return Item.Left;
        if (dockPosition === "right") return Item.Right;
        return Item.Bottom;
    }

    scale: snappyMode ? (_menuOpen ? 1.0 : 0.82) : 1.0
    opacity: snappyMode ? (_menuOpen ? 1.0 : 0.0) : 1.0

    Behavior on scale {
        enabled: root.snappyMode
        NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }
    Behavior on opacity {
        enabled: root.snappyMode
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: _menuOpen = true

    /* Grab focus so we can handle Escape key */
    focus: true
    Keys.onEscapePressed: {
        root.closeMenu();
    }

    /* ── Page transition direction ───────────────────────────── */
    readonly property bool _goingForward: currentPage > _prevPage
    readonly property real _slideDistance: 30

    onCurrentPageChanged: {
        if (currentPage !== _prevPage)
            _prevPage = currentPage;
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent

        radius: Theme.menuRadius
        color: Theme.menuBg
        border.color: Theme.menuBorder
        border.width: 1

        /* Subtle inner glow on the border side */
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.menuRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.03)
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.menuPadding

            /* ── App icon header ─────────────────────────────────── */
            Item {
                width: root.menuContentWidth
                height: root.headerHeight

                Image {
                    id: headerIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    sourceSize: Qt.size(22, 22)
                    source: {
                        if (!root.appIcon) return "";
                        if (root.appIcon.charAt(0) === "/")
                            return "file://" + root.appIcon;
                        return Quickshell.iconPath(root.appIcon, Theme.iconFallback);
                    }
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    visible: root.appIcon !== ""
                }

                Text {
                    anchors.left: headerIcon.visible ? headerIcon.right : parent.left
                    anchors.leftMargin: headerIcon.visible ? 10 : 10
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.className
                    color: Theme.textColor
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "Inter, Roboto, sans-serif"
                    elide: Text.ElideRight
                }

                /* Subtle bottom border */
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.15; color: Theme.separatorColor }
                        GradientStop { position: 0.85; color: Theme.separatorColor }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            Item { width: 1; height: root.headerMargin }

            /* ── Page container (clips slide transitions) ──────── */
            Item {
                id: pageContainer
                width: root.menuContentWidth
                height: root.activePageContentHeight
                clip: true

                /* ── Page 0: Main Menu ──────────────────────────── */
                Column {
                    id: pageMain
                    width: root.menuContentWidth
                    spacing: Theme.menuSpacing
                    visible: root.currentPage === 0

                    /* Slide animation */
                    x: visible ? 0 : (root._goingForward ? -root._slideDistance : root._slideDistance)
                    opacity: visible ? 1.0 : 0.0
                    Behavior on x {
                        enabled: root.snappyMode
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        enabled: root.snappyMode
                        NumberAnimation { duration: 150 }
                    }

                    Repeater {
                        model: root.instances || []
                        MenuItem {
                            text: modelData.title || root.className
                            rightText: ">"
                            isBold: modelData.active
                            isActive: modelData.active
                            iconSource: root.appIcon
                            onClicked: {
                                root._activeAddr = modelData.addr;
                                root.currentPage = 1;
                            }
                        }
                    }

                    MenuSep { visible: root.instanceCount > 0 }

                    MenuItem {
                        text: "Launch New"
                        onClicked: {
                            DaemonBridge.launch(root.className);
                            root.closeMenu();
                        }
                    }
                    MenuItem {
                        text: root.isPinned ? "Unpin" : "Pin"
                        onClicked: {
                            if (root.isPinned) DaemonBridge.unpin(root.className);
                            else DaemonBridge.pin(root.className);
                            root.closeMenu();
                        }
                    }
                    MenuItem {
                        visible: root.instanceCount > 0
                        text: root.instanceCount > 1 ? "Close All" : "Close"
                        textColor: Qt.rgba(1, 0.6, 0.6, 0.9)
                        onClicked: {
                            if (root.instanceCount > 1) {
                                DaemonBridge.closeAll(root.className);
                            } else if (root.instances && root.instances.length > 0) {
                                DaemonBridge.closeWindow(root.instances[0].addr);
                            }
                            root.closeMenu();
                        }
                    }
                }

                /* ── Page 1: Instance Actions ───────────────────── */
                Column {
                    id: pageInstance
                    width: root.menuContentWidth
                    spacing: Theme.menuSpacing
                    visible: root.currentPage === 1

                    x: visible ? 0 : (root._goingForward ? root._slideDistance : -root._slideDistance)
                    opacity: visible ? 1.0 : 0.0
                    Behavior on x {
                        enabled: root.snappyMode
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        enabled: root.snappyMode
                        NumberAnimation { duration: 150 }
                    }

                    MenuItem {
                        text: root.activeInstance ? (root.activeInstance.title || root.className) : ""
                        isBold: true
                        isBack: true
                        iconSource: root.appIcon
                        onClicked: { root.currentPage = 0; }
                    }

                    MenuSep {}

                    MenuItem {
                        text: "Focus"
                        onClicked: {
                            DaemonBridge.focus(root.activeInstance.addr);
                            root.closeMenu();
                        }
                    }
                    MenuItem {
                        text: root._isFloating ? "Toggle Tiling" : "Toggle Floating"
                        onClicked: {
                            DaemonBridge.toggleFloat(root.activeInstance.addr);
                            root.closeMenu();
                        }
                    }
                    MenuItem {
                        text: root._isFullscreen ? "Restore" : "Maximize"
                        onClicked: {
                            DaemonBridge.toggleFullscreen(root.activeInstance.addr);
                            root.closeMenu();
                        }
                    }
                    MenuItem {
                        text: "Send to Workspace"
                        rightText: ">"
                        onClicked: { root.currentPage = 2; }
                    }
                }

                /* ── Page 2: Workspaces (scrollable) ──────────── */
                Column {
                    id: pageWorkspace
                    width: root.menuContentWidth
                    spacing: Theme.menuSpacing
                    visible: root.currentPage === 2

                    x: visible ? 0 : (root._goingForward ? root._slideDistance : -root._slideDistance)
                    opacity: visible ? 1.0 : 0.0
                    Behavior on x {
                        enabled: root.snappyMode
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        enabled: root.snappyMode
                        NumberAnimation { duration: 150 }
                    }

                    MenuItem {
                        text: "Send to Workspace"
                        isBold: true
                        isBack: true
                        onClicked: { root.currentPage = 1; }
                    }

                    MenuSep {}

                    /* Scrollable workspace list — shows max 5, rest via scroll */
                    Item {
                        id: workspaceScrollContainer
                        width: root.menuContentWidth
                        readonly property int visibleCount: Math.min(root.workspaceCount, root.maxVisibleWorkspaces)
                        readonly property real itemTotalHeight: Theme.menuItemHeight + Theme.menuSpacing
                        height: visibleCount * itemTotalHeight - (visibleCount > 0 ? Theme.menuSpacing : 0)
                        clip: true

                        Flickable {
                            id: wsFlickable
                            anchors.fill: parent
                            contentWidth: parent.width
                            contentHeight: wsColumn.implicitHeight
                            flickableDirection: Flickable.VerticalFlick
                            boundsBehavior: Flickable.StopAtBounds

                            /* Scroll with mouse wheel */
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function(event) {
                                    wsFlickable.contentY = Math.max(0,
                                        Math.min(wsFlickable.contentHeight - wsFlickable.height,
                                                 wsFlickable.contentY - event.angleDelta.y * 0.8));
                                }
                            }

                            Column {
                                id: wsColumn
                                width: root.menuContentWidth
                                spacing: Theme.menuSpacing

                                Repeater {
                                    model: root.workspaceCount
                                    MenuItem {
                                        text: "Workspace " + (index + 1)
                                        onClicked: {
                                            DaemonBridge.moveToWs(root.activeInstance.addr, index + 1);
                                            root.closeMenu();
                                        }
                                    }
                                }
                            }
                        }

                        /* Sleek compact scrollbar — only visible when needed */
                        Rectangle {
                            id: scrollTrack
                            visible: wsFlickable.contentHeight > wsFlickable.height
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            width: 3
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, 0.04)

                            Rectangle {
                                id: scrollThumb
                                width: parent.width
                                radius: parent.radius
                                color: Qt.rgba(1, 1, 1, wsFlickable.moving ? 0.35 : 0.15)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                readonly property real ratio: wsFlickable.height / Math.max(1, wsFlickable.contentHeight)
                                readonly property real trackH: scrollTrack.height
                                height: Math.max(16, trackH * ratio)
                                y: (trackH - height) * (wsFlickable.contentY / Math.max(1, wsFlickable.contentHeight - wsFlickable.height))
                            }
                        }
                    }
                }
            }
        }
    }
}
