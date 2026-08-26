import QtQuick
import ".."

Item {
    id: root

    property var flickable: null
    property color thumbColor: M3Theme.outline
    property color thumbHoverColor: M3Theme.primary
    property int normalWidth: 6
    property int hoverWidth: 10
    property int minThumbHeight: 36

    width: (trackMa.containsMouse || isDragging) ? hoverWidth + 4 : normalWidth + 4
    visible: flickable ? (flickable.contentHeight > flickable.height) : false

    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    readonly property bool isDragging: thumbMa.pressed

    /* ── Track Area ───────────────────────────────────────────────── */
    Rectangle {
        id: track
        anchors.fill: parent
        color: trackMa.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        radius: M3Theme.radiusFull

        Behavior on color { ColorAnimation { duration: 120 } }

        MouseArea {
            id: trackMa
            anchors.fill: parent
            hoverEnabled: true

            onPressed: function(mouse) {
                if (!root.flickable) return;
                var maxThumbY = root.height - thumb.height;
                if (maxThumbY <= 0) return;
                var targetThumbY = mouse.y - thumb.height / 2;
                var ratio = Math.max(0, Math.min(1.0, targetThumbY / maxThumbY));
                root.flickable.contentY = ratio * (root.flickable.contentHeight - root.flickable.height);
            }
        }

        /* ── Draggable Thumb ──────────────────────────────────────── */
        Rectangle {
            id: thumb
            x: (parent.width - width) / 2
            width: (trackMa.containsMouse || root.isDragging) ? root.hoverWidth : root.normalWidth
            radius: M3Theme.radiusFull

            height: {
                if (!root.flickable || root.flickable.contentHeight <= 0) return root.minThumbHeight;
                var viewRatio = root.flickable.height / root.flickable.contentHeight;
                return Math.max(root.minThumbHeight, root.height * viewRatio);
            }

            y: {
                if (!root.flickable || root.flickable.contentHeight <= root.flickable.height) return 0;
                var maxScroll = root.flickable.contentHeight - root.flickable.height;
                var maxThumbY = root.height - height;
                var scrollProgress = Math.max(0, Math.min(1.0, root.flickable.contentY / maxScroll));
                return scrollProgress * maxThumbY;
            }

            color: {
                if (root.isDragging || thumbMa.containsMouse)
                    return root.thumbHoverColor;
                if (trackMa.containsMouse)
                    return M3Theme.textSecondary;
                return root.thumbColor;
            }

            opacity: (trackMa.containsMouse || root.isDragging || (root.flickable && root.flickable.moving)) ? 0.9 : 0.45

            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }

            MouseArea {
                id: thumbMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                property real grabOffsetY: 0

                onPressed: function(mouse) {
                    grabOffsetY = mouse.y;
                }

                onPositionChanged: function(mouse) {
                    if (!pressed || !root.flickable) return;
                    var maxThumbY = root.height - thumb.height;
                    if (maxThumbY <= 0) return;

                    var currentThumbY = thumb.y + (mouse.y - grabOffsetY);
                    var ratio = Math.max(0, Math.min(1.0, currentThumbY / maxThumbY));
                    var maxScroll = root.flickable.contentHeight - root.flickable.height;
                    root.flickable.contentY = ratio * maxScroll;
                }
            }
        }
    }
}
