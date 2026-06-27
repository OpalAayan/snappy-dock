/*  MenuSep.qml  —  A horizontal separator line for menus.
 */
import QtQuick

Item {
    width: parent ? parent.width : 200
    height: Theme.menuSeparatorHeight

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 24
        height: 1
        color: Theme.separatorColor
    }
}
