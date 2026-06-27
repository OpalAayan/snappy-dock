/*  DockMenu.qml  —  Right-click context menu with stack-based navigation.
 *
 *  Uses one calculated popup surface and swaps pages in-place to avoid
 *  clipped submenu transitions on Wayland.
 */
import QtQuick
import Quickshell

FocusScope {
    id: root

    required property string className
    required property bool   isPinned
    required property int    instanceCount
    required property var    instances

    signal closeMenu()

    /* Navigation State */
    property int currentPage: 0 // 0 = Main, 1 = Instance, 2 = Workspace
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
    /* Dedicated reactive booleans — read directly from DaemonBridge.clients
       (the singleton) instead of root.instances, because PopupWindow children
       may not receive binding updates from their parent while hidden.
       DaemonBridge.clients is always live and always up-to-date. */
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
    readonly property int mainRowCount: (root.instances ? root.instances.length : 0)
                                      + 2
                                      + (root.instanceCount > 1 ? 1 : 0)
    readonly property int mainSeparatorCount: root.instanceCount > 0 ? 1 : 0
    readonly property int instanceRowCount: 6
    readonly property int instanceSeparatorCount: 1
    readonly property int workspaceRowCount: root.workspaceCount + 1
    readonly property int workspaceSeparatorCount: 1
    readonly property int activePageHeight: currentPage === 0
        ? pageHeight(mainRowCount, mainSeparatorCount)
        : currentPage === 1
            ? pageHeight(instanceRowCount, instanceSeparatorCount)
            : currentPage === 2
                ? pageHeight(workspaceRowCount, workspaceSeparatorCount)
                : 0

    implicitWidth: Theme.menuWidth
    implicitHeight: activePageHeight + Theme.menuPadding * 2
    width: implicitWidth
    height: implicitHeight

    function pageHeight(rowCount, separatorCount) {
        var childCount = rowCount + separatorCount;
        if (childCount <= 0) return 0;
        return rowCount * Theme.menuItemHeight
            + separatorCount * Theme.menuSeparatorHeight
            + (childCount - 1) * Theme.menuSpacing;
    }

    /* Grab focus so we can handle Escape key */
    focus: true
    Keys.onEscapePressed: {
        root.closeMenu();
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent

        radius: Theme.menuRadius
        color: Theme.menuBg
        border.color: Theme.menuBorder
        border.width: 1

        Item {
            anchors.fill: parent
            anchors.margins: Theme.menuPadding

            /* ── Page 0: Main Menu ───────────────────────────────────── */
            Column {
                id: pageMain
                width: root.menuContentWidth
                spacing: Theme.menuSpacing
                visible: root.currentPage === 0

                Repeater {
                    model: root.instances || []
                    MenuItem {
                        text: modelData.title || root.className
                        rightText: "" /* Chevron right */
                        isBold: modelData.active
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
                    visible: root.instanceCount > 1
                    text: "Close All"
                    onClicked: {
                        DaemonBridge.closeAll(root.className);
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
            }

            /* ── Page 1: Instance Actions ────────────────────────────── */
            Column {
                id: pageInstance
                width: root.menuContentWidth
                spacing: Theme.menuSpacing
                visible: root.currentPage === 1

                MenuItem {
                    text: "  " + (root.activeInstance ? (root.activeInstance.title || root.className) : "")
                    isBold: true
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
                    text: "Close"
                    onClicked: {
                        DaemonBridge.closeWindow(root.activeInstance.addr);
                        root.closeMenu();
                    }
                }
                MenuItem {
                    text: "Send to Workspace"
                    rightText: ""
                    onClicked: { root.currentPage = 2; }
                }
            }

            /* ── Page 2: Workspaces ──────────────────────────────────── */
            Column {
                id: pageWorkspace
                width: root.menuContentWidth
                spacing: Theme.menuSpacing
                visible: root.currentPage === 2

                MenuItem {
                    text: "  Send to Workspace"
                    isBold: true
                    onClicked: { root.currentPage = 1; }
                }

                MenuSep {}

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
    }
}
