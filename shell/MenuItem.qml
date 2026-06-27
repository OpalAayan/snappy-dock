/*  MenuItem.qml  —  A clickable menu entry.
 */
import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string rightText: ""
    property bool   isBold: false
    property color  textColor: Theme.textColor
    property color  hoverColor: Theme.itemHover

    signal clicked()

    width: parent ? parent.width : 220
    height: Theme.menuItemHeight
    radius: 6
    color: mouse.containsMouse ? hoverColor : "transparent"

    /* Smooth hover */
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: rightTextItem.visible ? rightTextItem.left : parent.right
        anchors.rightMargin: rightTextItem.visible ? 8 : 12
        anchors.verticalCenter: parent.verticalCenter
        
        text: root.text
        color: root.textColor
        font.pixelSize: 13
        font.bold: root.isBold
        font.family: "Inter, Roboto, sans-serif"
        
        elide: Text.ElideRight
        clip: true
    }

    Text {
        id: rightTextItem
        visible: root.rightText !== ""
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 12
        text: root.rightText
        color: root.textColor
        font.pixelSize: 13
        font.family: "Inter, Roboto, sans-serif"
        opacity: 0.6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
