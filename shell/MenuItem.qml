/*  MenuItem.qml  —  A clickable menu entry with active indicator & icon support.
 */
import QtQuick
import Quickshell

Rectangle {
    id: root

    property string text: ""
    property string rightText: ""
    property bool   isBold: false
    property bool   isActive: false
    property bool   isBack: false
    property string iconSource: ""
    property color  textColor: Theme.textColor
    property color  hoverColor: Theme.menuHover

    signal clicked()

    width: parent ? parent.width : 220
    height: Theme.menuItemHeight
    radius: 6
    color: mouse.containsMouse
           ? (root.isActive ? Theme.menuAccent : hoverColor)
           : "transparent"

    /* Smooth hover */
    Behavior on color { ColorAnimation { duration: 100 } }

    /* Active indicator bar — accent-colored left edge */
    Rectangle {
        id: activeBar
        visible: root.isActive
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 2.5
        height: parent.height - 10
        radius: 1.5
        color: Theme.menuActiveBar
        opacity: root.isActive ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    /* Back arrow for navigation rows */
    Text {
        id: backArrow
        visible: root.isBack
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "‹"
        color: Theme.accentColor
        font.pixelSize: 16
        font.family: "Inter, Roboto, sans-serif"
    }

    /* Optional app icon */
    Image {
        id: menuIcon
        visible: root.iconSource !== ""
        anchors.left: parent.left
        anchors.leftMargin: root.isActive ? 12 : 8
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        sourceSize: Qt.size(16, 16)
        source: {
            if (!root.iconSource) return "";
            if (root.iconSource.charAt(0) === "/")
                return "file://" + root.iconSource;
            return Quickshell.iconPath(root.iconSource, Theme.iconFallback);
        }
        smooth: true
        mipmap: true
        asynchronous: true
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.isBack ? 22
                          : (root.iconSource !== "" ? 32
                          : (root.isActive ? 14 : 12))
        anchors.right: rightTextItem.visible ? rightTextItem.left : parent.right
        anchors.rightMargin: rightTextItem.visible ? 4 : 12
        anchors.verticalCenter: parent.verticalCenter

        text: root.text
        color: root.isBold ? Theme.textColor : Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.9)
        font.pixelSize: 13
        font.bold: root.isBold
        font.family: "Inter, Roboto, sans-serif"

        elide: Text.ElideRight
        clip: true
    }

    /* Right-side text / chevron */
    Text {
        id: rightTextItem
        visible: root.rightText !== ""
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        readonly property bool isChevron: root.rightText === ">" || root.rightText === "<"
        text: root.rightText === ">" ? "›" : (root.rightText === "<" ? "‹" : root.rightText)
        color: isChevron ? Theme.accentColor : Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.45)
        font.pixelSize: isChevron ? 16 : 13
        font.family: "Inter, Roboto, sans-serif"
    }

    /* Hover scale micro-animation */
    scale: mouse.containsMouse ? 1.01 : 1.0
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
