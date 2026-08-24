/*  Theme.qml  —  Self-contained theming singleton.
 *
 *  ALL visual constants live here.  No Qt theme, no system theme.
 *  QuickShell's IgnoreSystemSettings pragma in shell.qml ensures
 *  nothing leaks in from the desktop environment.
 *
 *  The daemon sends a "config" JSON on startup which can override
 *  iconSize and other layout values via DaemonBridge.
 */
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    /* ── Colors (defaults to Catppuccin Mocha inspired) ──────────── */
    property color bgColor:        Qt.rgba(0.07, 0.07, 0.11, 0.78)
    property color bgBorder:       Qt.rgba(1, 1, 1, 0.08)
    property int   bgBorderWidth:  1
    property color itemHover:      Qt.rgba(1, 1, 1, 0.10)
    property color itemActive:     Qt.rgba(1, 1, 1, 0.18)
    property color accentColor:    "#cba6f7"
    property color dotActive:      "#cba6f7"
    property color dotRunning:     Qt.rgba(1, 1, 1, 0.55)
    property color dotSmall:       Qt.rgba(1, 1, 1, 0.25)
    property color textColor:      "#cdd6f4"
    property color menuBg:         Qt.rgba(0.08, 0.08, 0.13, 0.92)
    property color menuBorder:     Qt.rgba(1, 1, 1, 0.10)
    property color menuHover:      Qt.rgba(1, 1, 1, 0.08)
    property color menuAccent:     Qt.rgba(0.80, 0.65, 0.97, 0.12)
    property color menuActiveBar:  "#cba6f7"
    property color separatorColor: Qt.rgba(1, 1, 1, 0.06)

    /* ── Sizes ───────────────────────────────────────────────────── */
    property int iconSize:       48
    property string iconTheme:   ""
    property string iconFallback: "application-x-executable"
    property string fontFamily:   "Sans"
    property int fontWeight:      Font.Bold
    property int dockRadius:     16
    property int dockPadding:    6
    property int itemPadding:    5
    property int itemSpacing:    2
    readonly property int dotSize:        4
    readonly property int dotActiveWidth: 14
    readonly property int dotSpacing:     3
    readonly property int menuWidth:      260
    readonly property int menuItemHeight: 30
    readonly property int menuSeparatorHeight: 9
    readonly property int menuRadius:     12
    readonly property int menuPadding:    6
    readonly property int menuSpacing:    2

    /* ── Animation ───────────────────────────────────────────────── */
    readonly property int animDuration:   150
    readonly property int hideAnimMs:     180
    readonly property int hideDelayMs:    300
}
