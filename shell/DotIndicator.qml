/*  DotIndicator.qml  —  Running-instance dot row.
 *
 *  Pattern (from snappy-dock-gtk):
 *    0 instances → no dots
 *    1 instance  → 1 dot
 *    2 instances → 2 dots
 *    3+ instances → 2 dots + 1 smaller dot
 *
 *  Active dots are wider with a subtle glow.
 */
import QtQuick

Row {
    id: root

    required property int count
    required property bool active

    spacing: Theme.dotSpacing
    visible: count > 0

    /* Centre horizontally under the icon */
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

    Repeater {
        model: root.count === 0 ? 0
             : root.count === 1 ? 1
             : root.count === 2 ? 2
             : 3

        Rectangle {
            required property int index

            /* The 3rd dot (index=2 when count>=3) is the "overflow" dot */
            property bool isSmall: (root.count >= 3 && index === 2)

            width:  root.active && !isSmall ? Theme.dotActiveWidth : Theme.dotSize
            height: Theme.dotSize
            radius: height / 2

            color: isSmall ? Theme.dotSmall
                 : root.active ? Theme.dotActive
                 : Theme.dotRunning

            opacity: isSmall ? 0.6 : 1.0

            Behavior on width {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }
}
