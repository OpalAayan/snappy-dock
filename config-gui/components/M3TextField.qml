import QtQuick
import ".."

Item {
    id: tf

    property string label: ""
    property string description: ""
    property string placeholder: ""
    property string text: ""
    signal textEdited(string val)

    implicitWidth: parent ? parent.width : 500
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 6

        Row {
            width: parent.width
            spacing: 8
            visible: tf.label.length > 0

            Text {
                text: tf.label
                color: M3Theme.textPrimary
                font.family: M3Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                text: tf.description
                color: M3Theme.textTertiary
                font.family: M3Theme.fontFamily
                font.pixelSize: 12
                visible: tf.description.length > 0
            }
        }

        Rectangle {
            width: parent.width
            height: 38
            radius: M3Theme.radiusMedium
            color: M3Theme.surfaceContainerHighest
            border.color: input.activeFocus ? M3Theme.primary : M3Theme.outlineVariant
            border.width: input.activeFocus ? 2 : 1

            Behavior on border.color { ColorAnimation { duration: 120 } }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: tf.text
                color: M3Theme.textPrimary
                font.family: M3Theme.fontFamily
                font.pixelSize: 13
                clip: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: tf.placeholder
                    color: M3Theme.textTertiary
                    font.family: M3Theme.fontFamily
                    font.pixelSize: 13
                    visible: !input.text && !input.activeFocus
                }

                onTextEdited: {
                    tf.text = input.text;
                    tf.textEdited(input.text);
                }
            }
        }
    }
}
