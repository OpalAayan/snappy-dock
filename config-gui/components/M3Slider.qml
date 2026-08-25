import QtQuick
import ".."

Item {
    id: slider

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string unit: ""
    property int decimals: 0
    property bool enabled: true
    property int tickCount: 0 // if 0, auto-calculated

    signal sliderMoved(real val)

    property string label: ""
    property string description: ""
    property string zeroLabel: ""

    implicitWidth: parent ? parent.width : 500
    implicitHeight: col.implicitHeight

    opacity: slider.enabled ? 1.0 : 0.4
    Behavior on opacity { NumberAnimation { duration: 150 } }

    /* Number of tick marks along the track */
    readonly property int computedTicks: {
        if (slider.tickCount > 0) return slider.tickCount;
        var steps = (slider.to - slider.from) / Math.max(0.001, slider.stepSize);
        if (steps >= 2 && steps <= 12) return Math.round(steps) + 1;
        if (steps > 12) return 7; // standard 6 segments / 7 ticks
        return 5;
    }

    Column {
        id: col
        width: parent.width
        spacing: 4

        /* ── Title & Description ──────────────────────────────────── */
        Column {
            width: parent.width
            spacing: 2
            visible: slider.label.length > 0

            Text {
                text: slider.label
                color: M3Theme.textPrimary
                font.family: M3Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                text: slider.description
                color: M3Theme.textTertiary
                font.family: M3Theme.fontFamily
                font.pixelSize: 11
                visible: slider.description.length > 0
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }

        /* ── Slider Interactive Area with Floating Bubble & Min/Max ─ */
        Item {
            id: sliderArea
            width: parent.width
            height: 56

            /* Min Label */
            Text {
                id: minLabel
                anchors.left: parent.left
                anchors.bottom: trackBox.bottom
                anchors.bottomMargin: (trackBox.height - height) / 2
                text: (slider.from === 0 && slider.zeroLabel.length > 0)
                      ? slider.zeroLabel
                      : ((slider.decimals > 0 ? Number(slider.from).toFixed(slider.decimals) : Math.round(Number(slider.from))) + slider.unit)
                color: M3Theme.textTertiary
                font.family: M3Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            /* Max Label */
            Text {
                id: maxLabel
                anchors.right: parent.right
                anchors.bottom: trackBox.bottom
                anchors.bottomMargin: (trackBox.height - height) / 2
                text: (slider.decimals > 0 ? Number(slider.to).toFixed(slider.decimals) : Math.round(Number(slider.to))) + slider.unit
                color: M3Theme.textTertiary
                font.family: M3Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            /* Track Container Box */
            Item {
                id: trackBox
                anchors.left: minLabel.right
                anchors.leftMargin: 12
                anchors.right: maxLabel.left
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                height: 28

                /* Inactive Track Pill (Google M3 Thick Track) */
                Rectangle {
                    id: trackBg
                    anchors.centerIn: parent
                    width: parent.width
                    height: 14
                    radius: 7
                    color: M3Theme.surfaceContainerHighest
                    border.color: M3Theme.outlineVariant
                    border.width: 1

                    /* Tick Dots on inactive track */
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        Repeater {
                            model: Math.max(2, slider.computedTicks)

                            Item {
                                width: (trackBg.width - 16) / Math.max(1, slider.computedTicks - 1)
                                height: trackBg.height

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    color: M3Theme.outline
                                }
                            }
                        }
                    }
                }

                /* Active Track Fill Pill */
                Rectangle {
                    id: trackFill
                    anchors.left: trackBg.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: (slider.to > slider.from)
                           ? Math.max(0, Math.min(trackBg.width, (slider.value - slider.from) / (slider.to - slider.from) * trackBg.width))
                           : 0
                    height: 14
                    radius: 7
                    color: M3Theme.primary
                    clip: true

                    /* Tick Dots on active track */
                    Row {
                        width: trackBg.width
                        height: parent.height
                        anchors.left: parent.left
                        anchors.leftMargin: 8

                        Repeater {
                            model: Math.max(2, slider.computedTicks)

                            Item {
                                width: (trackBg.width - 16) / Math.max(1, slider.computedTicks - 1)
                                height: trackFill.height

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    color: M3Theme.textOnPrimary
                                    opacity: 0.6
                                }
                            }
                        }
                    }
                }

                /* Vertical Pill Divider Thumb (Material 3 Style) */
                Rectangle {
                    id: thumb
                    x: Math.max(0, Math.min(trackBox.width - width, trackFill.width - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 24
                    radius: 2
                    color: M3Theme.primary
                    border.color: M3Theme.textOnPrimary
                    border.width: 1

                    Behavior on x {
                        enabled: !mouseArea.pressed
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                }

                /* Tick Marks beneath the track */
                Item {
                    anchors.top: trackBg.bottom
                    anchors.topMargin: 3
                    anchors.left: trackBg.left
                    anchors.right: trackBg.right
                    height: 4

                    Row {
                        anchors.fill: parent

                        Repeater {
                            model: Math.max(2, slider.computedTicks)

                            Item {
                                width: (trackBg.width) / Math.max(1, slider.computedTicks - 1)
                                height: 4

                                Rectangle {
                                    anchors.horizontalCenter: parent.left
                                    anchors.top: parent.top
                                    width: 1
                                    height: 3
                                    color: M3Theme.outline
                                    opacity: 0.7
                                }
                            }
                        }
                    }
                }

                /* Floating Value Bubble (lives directly above the thumb) */
                Rectangle {
                    id: floatingBubble
                    anchors.bottom: thumb.top
                    anchors.bottomMargin: 4
                    x: Math.max(-trackBox.x, Math.min(sliderArea.width - width - trackBox.x, thumb.x + thumb.width / 2 - width / 2))
                    width: Math.max(36, bubbleText.implicitWidth + 16)
                    height: 22
                    radius: M3Theme.radiusFull
                    color: M3Theme.primary
                    border.color: Qt.rgba(0, 0, 0, 0.18)
                    border.width: 1
                    z: 10

                    Text {
                        id: bubbleText
                        anchors.centerIn: parent
                        text: (slider.value === 0 && slider.zeroLabel.length > 0)
                              ? slider.zeroLabel
                              : ((slider.decimals > 0 ? Number(slider.value).toFixed(slider.decimals) : Math.round(Number(slider.value))) + slider.unit)
                        color: M3Theme.textOnPrimary
                        font.family: M3Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    Behavior on x {
                        enabled: !mouseArea.pressed
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                }

                /* Mouse Interaction */
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    anchors.margins: -10
                    enabled: slider.enabled
                    cursorShape: slider.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                    function updateVal(mouseX) {
                        var trackX = mouseX - 10; // offset for margins
                        var ratio = Math.max(0, Math.min(1.0, trackX / trackBox.width));
                        var raw = slider.from + ratio * (slider.to - slider.from);
                        if (slider.stepSize > 0) {
                            raw = Math.round(raw / slider.stepSize) * slider.stepSize;
                        }
                        var clamped = Math.max(slider.from, Math.min(slider.to, raw));
                        slider.value = clamped;
                        slider.sliderMoved(clamped);
                    }

                    onPressed: mouse => updateVal(mouse.x)
                    onPositionChanged: mouse => {
                        if (pressed) updateVal(mouse.x);
                    }
                }
            }
        }
    }
}
