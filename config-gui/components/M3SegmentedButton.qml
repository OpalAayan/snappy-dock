import QtQuick
import ".."

Item {
    id: seg

    property var options: [] // array of strings e.g. ["Bottom", "Top", "Left", "Right"]
    property var values: []  // array of values e.g. ["bottom", "top", "left", "right"]
    property string currentValue: ""
    signal selected(string val)

    property string label: ""
    property string description: ""

    implicitWidth: parent ? parent.width : 500
    implicitHeight: layout.implicitHeight

    Column {
        id: layout
        width: parent.width
        spacing: 6

        Row {
            width: parent.width
            spacing: 8
            visible: seg.label.length > 0

            Text {
                text: seg.label
                color: M3Theme.textPrimary
                font.family: M3Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                text: seg.description
                color: M3Theme.textTertiary
                font.family: M3Theme.fontFamily
                font.pixelSize: 12
                visible: seg.description.length > 0
            }
        }

        Rectangle {
            id: container
            width: parent.width
            height: 38
            radius: M3Theme.radiusFull
            color: M3Theme.surfaceContainerHighest
            border.color: M3Theme.outlineVariant
            border.width: 1

            Row {
                id: row
                anchors.fill: parent
                anchors.margins: 3
                spacing: 2

                Repeater {
                    model: seg.options.length

                    Item {
                        id: btn
                        width: (row.width - (seg.options.length - 1) * row.spacing) / Math.max(1, seg.options.length)
                        height: row.height

                        readonly property string optVal: (seg.values && seg.values.length > index)
                                                         ? seg.values[index]
                                                         : seg.options[index].toLowerCase()
                        readonly property bool isSelected: seg.currentValue.toLowerCase() === optVal.toLowerCase()

                        Rectangle {
                            anchors.fill: parent
                            radius: M3Theme.radiusFull
                            color: btn.isSelected ? M3Theme.primary : (mouseArea.containsMouse ? M3Theme.surfaceContainerHigh : "transparent")

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: seg.options[index]
                            color: btn.isSelected ? M3Theme.textOnPrimary : (mouseArea.containsMouse ? M3Theme.textPrimary : M3Theme.textSecondary)
                            font.family: M3Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: btn.isSelected ? Font.DemiBold : Font.Normal

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                seg.currentValue = btn.optVal;
                                seg.selected(btn.optVal);
                            }
                        }
                    }
                }
            }
        }
    }
}
