import QtQuick
import Quickshell
import ".."

Rectangle {
    id: root

    property string appName: ""
    property int itemIndex: 0
    property int totalCount: 0
    property bool isFirst: itemIndex === 0
    property bool isLast: itemIndex >= totalCount - 1

    signal moveUp()
    signal moveDown()
    signal remove()

    width: parent ? parent.width : 500
    height: 54
    radius: 12
    color: hoverArea.containsMouse ? M3Theme.surfaceContainerHigh : M3Theme.surfaceContainer
    border.color: hoverArea.containsMouse ? M3Theme.primary : M3Theme.outlineVariant
    border.width: 1

    scale: hoverArea.containsMouse ? 1.006 : 1.0
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }

    /* Friendly display title extraction */
    readonly property string displayTitle: {
        if (!appName) return "Application";
        var s = appName;
        // If reverse-DNS format (e.g. org.gnome.Nautilus, com.github.flxzt.rnote)
        var parts = s.split(".");
        var last = parts[parts.length - 1];
        if (last && last.length > 0) {
            // Capitalize first letter if lowercase
            return last.charAt(0).toUpperCase() + last.slice(1);
        }
        return s;
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: actionRow.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        /* Drag Handle Icon */
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰇡"
            color: hoverArea.containsMouse ? M3Theme.textSecondary : M3Theme.textTertiary
            font.family: M3Theme.fontFamily
            font.pixelSize: 18
        }

        /* Order Index Badge */
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 22
            radius: M3Theme.radiusFull
            color: M3Theme.secondaryContainer

            Text {
                anchors.centerIn: parent
                text: "#" + (root.itemIndex + 1)
                color: M3Theme.textOnSecondaryContainer
                font.family: M3Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        /* App Icon */
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 8
            color: M3Theme.surfaceContainerHighest

            Image {
                id: appIconImg
                anchors.centerIn: parent
                width: 28
                height: 28
                sourceSize: Qt.size(28, 28)
                source: IconResolver.resolve(root.appName)
                smooth: true
                mipmap: true
                asynchronous: true
            }

            /* Fallback letter when icon fails to load */
            Text {
                anchors.centerIn: parent
                visible: appIconImg.status === Image.Error || appIconImg.status === Image.Null
                text: root.displayTitle.charAt(0).toUpperCase()
                color: M3Theme.primary
                font.family: M3Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.Bold
            }
        }

        /* App Name & Class details */
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: parent.width - 130
            clip: true

            Text {
                text: root.displayTitle
                color: M3Theme.textPrimary
                font.family: M3Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: root.appName
                color: M3Theme.textTertiary
                font.family: M3Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    /* ── Action Buttons ───────────────────────────────────────────── */
    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        /* Move Up Button */
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: upMouse.containsMouse ? M3Theme.surfaceContainerHighest : "transparent"
            opacity: root.isFirst ? 0.25 : 1.0
            scale: upMouse.pressed ? 0.88 : (upMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: "󰁝"
                color: M3Theme.textPrimary
                font.family: M3Theme.fontFamily
                font.pixelSize: 16
            }

            MouseArea {
                id: upMouse
                anchors.fill: parent
                cursorShape: root.isFirst ? Qt.ArrowCursor : Qt.PointingHandCursor
                enabled: !root.isFirst
                onClicked: root.moveUp()
            }
        }

        /* Move Down Button */
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: downMouse.containsMouse ? M3Theme.surfaceContainerHighest : "transparent"
            opacity: root.isLast ? 0.25 : 1.0
            scale: downMouse.pressed ? 0.88 : (downMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: "󰁅"
                color: M3Theme.textPrimary
                font.family: M3Theme.fontFamily
                font.pixelSize: 16
            }

            MouseArea {
                id: downMouse
                anchors.fill: parent
                cursorShape: root.isLast ? Qt.ArrowCursor : Qt.PointingHandCursor
                enabled: !root.isLast
                onClicked: root.moveDown()
            }
        }

        /* Separator */
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 18
            color: M3Theme.outlineVariant
        }

        /* Unpin / Delete Button */
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: delMouse.containsMouse ? Qt.rgba(0.95, 0.25, 0.25, 0.15) : "transparent"
            scale: delMouse.pressed ? 0.88 : (delMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: "󰆴"
                color: delMouse.containsMouse ? "#FF5555" : M3Theme.textSecondary
                font.family: M3Theme.fontFamily
                font.pixelSize: 15
            }

            MouseArea {
                id: delMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.remove()
            }
        }
    }
}
