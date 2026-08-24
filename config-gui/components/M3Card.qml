import QtQuick
import ".."

Rectangle {
    id: card

    default property alias contentData: contentColumn.data
    property string title: ""
    property string description: ""

    implicitWidth: parent ? parent.width : 700
    implicitHeight: mainLayout.implicitHeight + 32

    radius: M3Theme.radiusLarge
    color: M3Theme.surfaceContainer
    border.color: M3Theme.outlineVariant
    border.width: 1

    Column {
        id: mainLayout
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
        }
        spacing: 14

        Column {
            width: parent.width
            spacing: 3
            visible: card.title.length > 0

            Text {
                text: card.title
                color: M3Theme.textPrimary
                font.family: M3Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                text: card.description
                color: M3Theme.textSecondary
                font.family: M3Theme.fontFamily
                font.pixelSize: 12
                visible: card.description.length > 0
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: 12
        }
    }
}
