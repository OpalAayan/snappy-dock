/*  DotIndicator.qml  —  Running-instance marker.
 *
 *  Pattern (from snappy-dock-gtk):
 *    0 instances → no dots
 *    1 instance  → 1 dot
 *    2 instances → 2 dots
 *    3+ instances → 2 dots + 1 smaller dot
 *
 *  Horizontal docks use a row under the icon.  Side docks use a compact
 *  stacked rail beside the icon so active indicators widen sideways
 *  instead of stretching along the dock column.
 */
import QtQuick

Item {
    id: root

    required property int count
    required property bool active

    /* position is preferred; isVertical keeps older call sites working. */
    property string position: isVertical ? "left" : "bottom"
    property bool isVertical: false

    readonly property string edge: normalizedPosition(position)
    readonly property bool sideDock: edge === "left" || edge === "right"
    readonly property int visibleDotCount: count <= 0 ? 0
                                       : count === 1 ? 1
                                       : count === 2 ? 2
                                       : 3
    readonly property real baseSize: Theme.dotSize
    readonly property real overflowSize: Math.max(2, Theme.dotSize - 1)
    readonly property real horizontalActiveLength: Theme.dotActiveWidth
    readonly property real sideActiveLength: Math.max(Theme.dotSize * 2, Theme.dotActiveWidth - 4)
    readonly property real sideSpacing: Math.max(2, Theme.dotSpacing - 1)

    implicitWidth: sideDock ? sideStack.implicitWidth : bottomRow.implicitWidth
    implicitHeight: sideDock ? sideStack.implicitHeight : bottomRow.implicitHeight
    width: implicitWidth
    height: implicitHeight
    visible: count > 0

    function normalizedPosition(value) {
        var pos = String(value || "bottom").toLowerCase();
        if (pos === "top" || pos === "bottom" || pos === "left" || pos === "right")
            return pos;
        return root.isVertical ? "left" : "bottom";
    }

    Row {
        id: bottomRow

        anchors.centerIn: parent
        visible: !root.sideDock
        spacing: Theme.dotSpacing

        Repeater {
            model: root.visibleDotCount

            Item {
                required property int index

                readonly property bool isSmall: root.count >= 3 && index === 2
                readonly property real markWidth: isSmall ? root.overflowSize
                                             : root.active ? root.horizontalActiveLength
                                             : root.baseSize
                readonly property real markHeight: isSmall ? root.overflowSize : root.baseSize

                width: markWidth
                height: root.baseSize

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.markWidth
                    height: parent.markHeight
                    radius: height / 2
                    color: parent.isSmall ? Theme.dotSmall
                         : root.active ? Theme.dotActive
                         : Theme.dotRunning
                    opacity: parent.isSmall ? 0.6 : 1.0

                    Behavior on width {
                        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDuration }
                    }
                }
            }
        }
    }

    Column {
        id: sideStack

        anchors.centerIn: parent
        visible: root.sideDock
        spacing: root.sideSpacing

        Repeater {
            model: root.visibleDotCount

            Item {
                required property int index

                readonly property bool isSmall: root.count >= 3 && index === 2
                readonly property real markWidth: isSmall ? root.overflowSize
                                             : root.active ? root.sideActiveLength
                                             : root.baseSize
                readonly property real markHeight: isSmall ? root.overflowSize : root.baseSize

                width: root.sideActiveLength
                height: root.baseSize

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: root.edge === "right" ? parent.left : undefined
                    anchors.right: root.edge === "left" ? parent.right : undefined
                    anchors.horizontalCenter: root.edge === "left" || root.edge === "right"
                                              ? undefined : parent.horizontalCenter
                    width: parent.markWidth
                    height: parent.markHeight
                    radius: height / 2
                    color: parent.isSmall ? Theme.dotSmall
                         : root.active ? Theme.dotActive
                         : Theme.dotRunning
                    opacity: parent.isSmall ? 0.6 : 1.0

                    Behavior on width {
                        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDuration }
                    }
                }
            }
        }
    }
}
