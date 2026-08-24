import QtQuick
import ".."

Rectangle {
    id: badge

    property string text: ""
    property string type: "info" // "info", "warning", "caution"

    readonly property color badgeColor: {
        if (type === "warning" || type === "caution")
            return M3Theme.warningContainer;
        return M3Theme.secondaryContainer;
    }

    readonly property color textColor: {
        if (type === "warning" || type === "caution")
            return M3Theme.warning;
        return M3Theme.textOnSecondaryContainer;
    }

    implicitWidth: badgeRow.implicitWidth + 16
    implicitHeight: badgeRow.implicitHeight + 8
    radius: M3Theme.radiusFull
    color: badgeColor
    border.color: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.3)
    border.width: 1

    Row {
        id: badgeRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: badge.type === "warning" || badge.type === "caution" ? "󰀦" : "󰋽"
            color: badge.textColor
            font.family: M3Theme.fontFamily
            font.pixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: badge.text
            color: badge.textColor
            font.family: M3Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }
}
