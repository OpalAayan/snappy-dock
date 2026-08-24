import QtQuick
import ".."

Item {
    id: m3switch

    property bool checked: false
    signal toggled(bool val)

    property string label: ""
    property string description: ""

    implicitWidth: parent ? parent.width : 500
    implicitHeight: Math.max(34, textCol.implicitHeight)

    Row {
        anchors.left: parent.left
        anchors.right: switchTrack.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter

        Column {
            id: textCol
            width: parent.width
            spacing: 2

            Text {
                text: m3switch.label
                color: M3Theme.textPrimary
                font.family: M3Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                text: m3switch.description
                color: M3Theme.textTertiary
                font.family: M3Theme.fontFamily
                font.pixelSize: 12
                visible: m3switch.description.length > 0
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }
    }

    Rectangle {
        id: switchTrack
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 28
        radius: 14
        color: m3switch.checked ? M3Theme.primary : M3Theme.surfaceContainerHighest
        border.color: m3switch.checked ? M3Theme.primary : M3Theme.outline
        border.width: 2

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        Rectangle {
            id: switchThumb
            width: m3switch.checked ? 20 : 16
            height: width
            radius: width / 2
            color: m3switch.checked ? M3Theme.textOnPrimary : M3Theme.outline
            x: m3switch.checked ? (switchTrack.width - width - 4) : 4
            anchors.verticalCenter: parent.verticalCenter

            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                m3switch.checked = !m3switch.checked;
                m3switch.toggled(m3switch.checked);
            }
        }
    }
}
