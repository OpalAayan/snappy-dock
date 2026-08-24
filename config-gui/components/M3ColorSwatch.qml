import QtQuick
import ".."

Rectangle {
    id: swatch

    property string name: ""
    property color previewBg: "#1E1E2E"
    property color previewAccent: "#CBA6F7"
    property bool isSelected: false
    signal clicked()

    width: 105
    height: 64
    radius: M3Theme.radiusMedium
    color: M3Theme.surfaceContainerHighest
    border.color: swatch.isSelected ? M3Theme.primary : (mouse.containsMouse ? M3Theme.outline : M3Theme.outlineVariant)
    border.width: swatch.isSelected ? 2 : 1

    Behavior on border.color { ColorAnimation { duration: 120 } }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Rectangle {
                width: 22
                height: 22
                radius: 11
                color: swatch.previewBg
                border.color: Qt.rgba(1, 1, 1, 0.2)
                border.width: 1
            }

            Rectangle {
                width: 22
                height: 22
                radius: 11
                color: swatch.previewAccent
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: swatch.name
            color: swatch.isSelected ? M3Theme.primary : M3Theme.textSecondary
            font.family: M3Theme.fontFamily
            font.pixelSize: 11
            font.weight: swatch.isSelected ? Font.DemiBold : Font.Normal
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: swatch.clicked()
    }
}
