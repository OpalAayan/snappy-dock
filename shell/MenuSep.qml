/*  MenuSep.qml  —  A horizontal separator with subtle gradient fade.
 */
import QtQuick

Item {
    width: parent ? parent.width : 200
    height: Theme.menuSeparatorHeight

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 24
        height: 1

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.2; color: Theme.separatorColor }
            GradientStop { position: 0.8; color: Theme.separatorColor }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
