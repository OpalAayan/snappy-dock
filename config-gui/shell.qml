//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import "components"

FloatingWindow {
    id: window
    title: "Snappy Dock Settings"
    implicitWidth: 820
    implicitHeight: 680
    color: "transparent"
    visible: true

    Process {
        id: restartProc
        command: ["snappy-dock", "--restart-dock"]
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: M3Theme.radiusLarge
        color: M3Theme.background
        border.color: M3Theme.outlineVariant
        border.width: 1
        clip: true

        Behavior on color { ColorAnimation { duration: 180 } }

        /* ── Top Header Bar ───────────────────────────────────────── */
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 68
            color: M3Theme.surface
            border.color: M3Theme.outlineVariant
            border.width: 1
            z: 10

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: M3Theme.primary
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󱐋"
                        color: M3Theme.textOnPrimary
                        font.family: M3Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Snappy Dock Settings"
                        color: M3Theme.textPrimary
                        font.family: M3Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }

                    Text {
                        text: ConfigStore.configPath
                        color: M3Theme.textTertiary
                        font.family: M3Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                /* Dark / Light Toggle */
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: M3Theme.surfaceContainerHigh
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: M3Theme.isDark ? "󰖔" : "󰖨"
                        color: M3Theme.textPrimary
                        font.family: M3Theme.fontFamily
                        font.pixelSize: 16
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: M3Theme.isDark = !M3Theme.isDark
                    }
                }

                /* Reset Button */
                Rectangle {
                    width: 90
                    height: 36
                    radius: M3Theme.radiusFull
                    color: M3Theme.surfaceContainerHigh
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰑐"
                            color: M3Theme.textSecondary
                            font.family: M3Theme.fontFamily
                            font.pixelSize: 13
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Reset"
                            color: M3Theme.textSecondary
                            font.family: M3Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ConfigStore.resetDefaults()
                    }
                }

                /* Apply & Restart Button */
                Rectangle {
                    id: applyBtn
                    width: Math.max(140, applyText.implicitWidth + 32)
                    height: 36
                    radius: M3Theme.radiusFull
                    color: M3Theme.primary
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: applyText
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ConfigStore.saveStatus.length > 0 ? "✓" : "󰜉"
                            color: M3Theme.textOnPrimary
                            font.family: M3Theme.fontFamily
                            font.pixelSize: 14
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ConfigStore.saveStatus.length > 0 ? ConfigStore.saveStatus : "Apply & Restart"
                            color: M3Theme.textOnPrimary
                            font.family: M3Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ConfigStore.save();
                            restartProc.running = true;
                            ConfigStore.saveStatus = "Restarted!";
                            saveTimer.restart();
                        }
                    }

                    Timer {
                        id: saveTimer
                        interval: 2000
                        onTriggered: ConfigStore.saveStatus = ""
                    }
                }
            }
        }

        /* ── Tab Selector ─────────────────────────────────────────── */
        Rectangle {
            id: tabBar
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            color: M3Theme.surface
            z: 9

            property int currentTab: 0

            Row {
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: [
                        { name: "Layout & Position", icon: "󰕰" },
                        { name: "Snappy & Behavior", icon: "󱐋" },
                        { name: "Appearance & Theme", icon: "󰏘" }
                    ]

                    Rectangle {
                        width: 220
                        height: 34
                        radius: M3Theme.radiusFull
                        color: tabBar.currentTab === index ? M3Theme.secondaryContainer : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                color: tabBar.currentTab === index ? M3Theme.textOnSecondaryContainer : M3Theme.textSecondary
                                font.family: M3Theme.fontFamily
                                font.pixelSize: 14
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: tabBar.currentTab === index ? M3Theme.textOnSecondaryContainer : M3Theme.textSecondary
                                font.family: M3Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: tabBar.currentTab === index ? Font.DemiBold : Font.Normal
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tabBar.currentTab = index
                        }
                    }
                }
            }
        }

        /* ── Scrollable Tab Content ───────────────────────────────── */
        Flickable {
            id: flickable
            anchors.top: tabBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: contentCol.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 20
                anchors.top: parent.top
                anchors.topMargin: 16
                spacing: 16

                /* ══════════════════════════════════════════════════════
                   TAB 0: LAYOUT & POSITION
                   ══════════════════════════════════════════════════════ */
                Column {
                    width: parent.width
                    spacing: 16
                    visible: tabBar.currentTab === 0

                    M3Card {
                        title: "Screen Placement"
                        description: "Select which screen edge the dock attaches to and how it aligns along that edge."

                        M3SegmentedButton {
                            label: "Position"
                            description: "Screen edge"
                            options: ["Bottom", "Top", "Left", "Right"]
                            values: ["bottom", "top", "left", "right"]
                            currentValue: ConfigStore.position || "bottom"
                            onSelected: val => ConfigStore.position = val
                        }

                        M3SegmentedButton {
                            label: "Alignment"
                            description: "Main-axis alignment along the edge"
                            options: ["Center", "Start", "End"]
                            values: ["center", "start", "end"]
                            currentValue: ConfigStore.alignment || "center"
                            onSelected: val => ConfigStore.alignment = val
                        }

                        M3Switch {
                            label: "FullWidth Bar"
                            description: "Stretch the dock bar across the entire screen width / height"
                            checked: ConfigStore.fullWidth
                            onToggled: val => ConfigStore.fullWidth = val
                        }
                    }

                    M3Card {
                        title: "Visibility & Layer"
                        description: "Configure how the dock overlays windows and auto-hides."

                        M3SegmentedButton {
                            label: "Layer-Shell Layer"
                            description: "Higher layers sit above more windows"
                            options: ["Overlay", "Top", "Bottom", "Background"]
                            values: ["overlay", "top", "bottom", "background"]
                            currentValue: ConfigStore.layer || "top"
                            onSelected: val => ConfigStore.layer = val
                        }

                        M3Switch {
                            label: "AutoHide"
                            description: "Slide the dock off-screen when the pointer is not hovering"
                            checked: ConfigStore.autoHide
                            onToggled: val => ConfigStore.autoHide = val
                        }

                        M3Slider {
                            label: "Hotspot Delay"
                            description: "Delay before hiding after pointer leaves"
                            from: 0; to: 2000; stepSize: 50; unit: " ms"
                            value: Number(ConfigStore.hotspotDelay || 300)
                            enabled: ConfigStore.autoHide
                            onSliderMoved: val => ConfigStore.hotspotDelay = Math.round(val)
                        }

                        M3Switch {
                            label: "Exclusive Zone"
                            description: "Reserve screen space so tiled/maximized windows don't overlap the dock"
                            checked: ConfigStore.exclusiveZone
                            onToggled: val => ConfigStore.exclusiveZone = val
                        }

                        M3Slider {
                            label: "Exclusive Zone Size"
                            description: "0 = Auto (reserves exact dock extent), or set custom fixed pixels"
                            from: 0; to: 160; stepSize: 4; unit: " px"; zeroLabel: "Auto"
                            value: ConfigStore.exclusiveZoneValue
                            enabled: ConfigStore.exclusiveZone
                            visible: ConfigStore.exclusiveZone
                            onSliderMoved: val => ConfigStore.exclusiveZoneValue = Math.round(val)
                        }

                        /* Constraint warnings */
                        M3Badge {
                            type: "warning"
                            text: "ExclusiveZone is not recommended with Mode=snappy (can clip magnified icons)"
                            visible: ConfigStore.mode === "snappy" && ConfigStore.exclusiveZone
                        }

                        M3Badge {
                            type: "warning"
                            text: "AutoHide + ExclusiveZone leaves a reserved blank gap even when the dock is hidden"
                            visible: ConfigStore.autoHide && ConfigStore.exclusiveZone
                        }
                    }

                    M3Card {
                        title: "Edge Margins"
                        description: "Extra gap in pixels between the dock and screen edges."

                        M3Slider {
                            label: "Top Margin"
                            from: 0; to: 100; stepSize: 1; unit: " px"
                            value: Number(ConfigStore.marginTop || 0)
                            onSliderMoved: val => ConfigStore.marginTop = Math.round(val)
                        }

                        M3Slider {
                            label: "Bottom Margin"
                            from: 0; to: 100; stepSize: 1; unit: " px"
                            value: Number(ConfigStore.marginBottom || 0)
                            onSliderMoved: val => ConfigStore.marginBottom = Math.round(val)
                        }

                        M3Slider {
                            label: "Left Margin"
                            from: 0; to: 100; stepSize: 1; unit: " px"
                            value: Number(ConfigStore.marginLeft || 0)
                            onSliderMoved: val => ConfigStore.marginLeft = Math.round(val)
                        }

                        M3Slider {
                            label: "Right Margin"
                            from: 0; to: 100; stepSize: 1; unit: " px"
                            value: Number(ConfigStore.marginRight || 0)
                            onSliderMoved: val => ConfigStore.marginRight = Math.round(val)
                        }
                    }
                }

                /* ══════════════════════════════════════════════════════
                   TAB 1: SNAPPY & BEHAVIOR
                   ══════════════════════════════════════════════════════ */
                Column {
                    width: parent.width
                    spacing: 16
                    visible: tabBar.currentTab === 1

                    M3Card {
                        title: "Animation Mode"
                        description: "Choose between dynamic macOS-style magnification and static icons."

                        M3SegmentedButton {
                            label: "Mode"
                            options: ["Static", "Snappy"]
                            values: ["static", "snappy"]
                            currentValue: ConfigStore.mode || "static"
                            onSelected: val => ConfigStore.mode = val
                        }
                    }

                    M3Card {
                        title: "Snappy Mode Tuning"
                        description: "Fine-tune the Gaussian magnification curve and icon displacement."

                        M3Badge {
                            type: "info"
                            text: "These tuning sliders only apply when Mode=snappy"
                            visible: ConfigStore.mode !== "snappy"
                        }

                        M3Slider {
                            label: "Magnification Boost"
                            description: "Extra scale factor under cursor (0.78 = 1.78x, 1.0 = 2.0x)"
                            from: 0.0; to: 2.0; stepSize: 0.05; decimals: 2; unit: "x"
                            value: Number(ConfigStore.magnification || 0.78)
                            enabled: ConfigStore.mode === "snappy"
                            onSliderMoved: val => ConfigStore.magnification = val
                        }

                        M3Slider {
                            label: "Spread"
                            description: "Neighbor influence radius in icon widths (1 = narrow, 6 = wide)"
                            from: 1; to: 6; stepSize: 1; unit: " icons"
                            value: Number(ConfigStore.spread || 3)
                            enabled: ConfigStore.mode === "snappy"
                            onSliderMoved: val => ConfigStore.spread = Math.round(val)
                        }

                        M3Slider {
                            label: "Rise Spacing"
                            description: "Main-axis neighbor separation (0 = overlap, 1.0 = full space)"
                            from: 0.0; to: 2.0; stepSize: 0.05; decimals: 2
                            value: Number(ConfigStore.riseSpacing || 0.5)
                            enabled: ConfigStore.mode === "snappy"
                            onSliderMoved: val => ConfigStore.riseSpacing = val
                        }

                        M3Slider {
                            label: "Icon Spacing"
                            description: "Base gap between dock icon cells"
                            from: 0; to: 20; stepSize: 1; unit: " px"
                            value: Number(ConfigStore.iconSpacing || 2)
                            onSliderMoved: val => ConfigStore.iconSpacing = Math.round(val)
                        }
                    }

                    M3Card {
                        title: "Launcher Button"
                        description: "Configure the application launcher button on the dock."

                        M3SegmentedButton {
                            label: "Launcher Position"
                            options: ["Start", "End", "None"]
                            values: ["start", "end", "none"]
                            currentValue: ConfigStore.launcherPos || "start"
                            onSelected: val => ConfigStore.launcherPos = val
                        }

                        M3TextField {
                            label: "Launcher Command"
                            description: "Command to execute when clicked"
                            placeholder: "fuzzel"
                            text: ConfigStore.launcherCmd || ""
                            onTextEdited: val => ConfigStore.launcherCmd = val
                        }

                        M3TextField {
                            label: "Launcher Icon"
                            description: "Use 'dots' for 9-dot grid or enter a custom glyph / Nerd Font symbol"
                            placeholder: "dots"
                            text: ConfigStore.launcherIcon || ""
                            onTextEdited: val => ConfigStore.launcherIcon = val
                        }

                        M3Switch {
                            label: "Launcher Hover Highlight"
                            description: "Show background highlight when hovering over the launcher"
                            checked: ConfigStore.launcherHoverBg
                            onToggled: val => ConfigStore.launcherHoverBg = val
                        }

                        M3Switch {
                            label: "Dock Icon Hover Highlight"
                            description: "Show background highlight when hovering over application icons"
                            checked: ConfigStore.iconHoverBg
                            onToggled: val => ConfigStore.iconHoverBg = val
                        }

                        M3Slider {
                            label: "Workspace Count in Menu"
                            description: "Number of workspaces in right-click Move to Workspace menu"
                            from: 1; to: 20; stepSize: 1
                            value: Number(ConfigStore.workspaceCount || 5)
                            onSliderMoved: val => ConfigStore.workspaceCount = Math.round(val)
                        }
                    }
                }

                /* ══════════════════════════════════════════════════════
                   TAB 2: APPEARANCE & THEME
                   ══════════════════════════════════════════════════════ */
                Column {
                    width: parent.width
                    spacing: 16
                    visible: tabBar.currentTab === 2

                    M3Card {
                        title: "Icons & Typography"
                        description: "Adjust icon sizes, themes, and font families."

                        M3Slider {
                            label: "Icon Size"
                            description: "Base icon extent in pixels"
                            from: 16; to: 128; stepSize: 2; unit: " px"
                            value: Number(ConfigStore.iconSize || 48)
                            onSliderMoved: val => ConfigStore.iconSize = Math.round(val)
                        }

                        M3TextField {
                            label: "Icon Theme"
                            description: "Qt icon theme name (leave empty for system theme)"
                            placeholder: "Tela-dracula"
                            text: ConfigStore.iconTheme || ""
                            onTextEdited: val => ConfigStore.iconTheme = val
                        }

                        M3TextField {
                            label: "Fallback Icon"
                            description: "Default icon name for unresolved desktop entries"
                            placeholder: "application-x-executable"
                            text: ConfigStore.iconFallback || ""
                            onTextEdited: val => ConfigStore.iconFallback = val
                        }

                        M3TextField {
                            label: "Font Family"
                            description: "Font family for text and glyphs"
                            placeholder: "Rubik"
                            text: ConfigStore.fontFamily || ""
                            onTextEdited: val => ConfigStore.fontFamily = val
                        }

                        M3SegmentedButton {
                            label: "Font Weight"
                            options: ["Normal", "Bold", "Light", "Medium", "SemiBold"]
                            values: ["Normal", "Bold", "Light", "Medium", "SemiBold"]
                            currentValue: ConfigStore.fontWeight || "Bold"
                            onSelected: val => ConfigStore.fontWeight = val
                        }
                    }

                    M3Card {
                        title: "Theme Presets"
                        description: "Quickly apply popular color palettes to your dock bar with 1 click."

                        Flow {
                            width: parent.width
                            spacing: 10

                            M3ColorSwatch {
                                name: "Mocha"
                                previewBg: "#1E1E2E"
                                previewAccent: "#9DC2F9"
                                isSelected: (ConfigStore.themeAccent || "").toLowerCase() === "#9dc2f9"
                                onClicked: ConfigStore.applyPreset("catppuccin-mocha")
                            }

                            M3ColorSwatch {
                                name: "Latte"
                                previewBg: "#DCE0E8"
                                previewAccent: "#8839EF"
                                isSelected: (ConfigStore.themeAccent || "").toLowerCase() === "#8839ef"
                                onClicked: ConfigStore.applyPreset("catppuccin-latte")
                            }

                            M3ColorSwatch {
                                name: "Dracula"
                                previewBg: "#282A36"
                                previewAccent: "#AB76F5"
                                isSelected: (ConfigStore.themeAccent || "").toLowerCase() === "#ab76f5"
                                onClicked: ConfigStore.applyPreset("dracula")
                            }

                            M3ColorSwatch {
                                name: "Nord"
                                previewBg: "#2E3440"
                                previewAccent: "#5E81AC"
                                isSelected: (ConfigStore.themeAccent || "").toLowerCase() === "#5e81ac"
                                onClicked: ConfigStore.applyPreset("nord")
                            }

                            M3ColorSwatch {
                                name: "Tokyo Night"
                                previewBg: "#24283B"
                                previewAccent: "#F7768E"
                                isSelected: (ConfigStore.themeAccent || "").toLowerCase() === "#f7768e"
                                onClicked: ConfigStore.applyPreset("tokyo-night")
                            }

                            M3ColorSwatch {
                                name: "Rosé Pine"
                                previewBg: "#1F1D2E"
                                previewAccent: "#EBBCBA"
                                isSelected: (ConfigStore.themeAccent || "").toLowerCase() === "#ebbcba"
                                onClicked: ConfigStore.applyPreset("rose-pine")
                            }

                            M3ColorSwatch {
                                name: "Gruvbox"
                                previewBg: "#282828"
                                previewAccent: "#FE8019"
                                isSelected: (ConfigStore.themeAccent || "").toLowerCase() === "#fe8019"
                                onClicked: ConfigStore.applyPreset("gruvbox")
                            }

                            M3ColorSwatch {
                                name: "Cyberpunk"
                                previewBg: "#0A0A12"
                                previewAccent: "#00FFF9"
                                isSelected: (ConfigStore.themeAccent || "").toLowerCase() === "#00fff9"
                                onClicked: ConfigStore.applyPreset("cyberpunk")
                            }

                            M3ColorSwatch {
                                name: "macOS"
                                previewBg: "#1A1A1A"
                                previewAccent: "#FFFFFF"
                                isSelected: (ConfigStore.themeBg || "").toLowerCase() === "#0000004d"
                                onClicked: ConfigStore.applyPreset("macos")
                            }

                            M3ColorSwatch {
                                name: "Stormlight"
                                previewBg: "#303446"
                                previewAccent: "#F7F36D"
                                isSelected: (ConfigStore.themeAccent || "").toLowerCase() === "#f7f36d"
                                onClicked: ConfigStore.applyPreset("stormlight")
                            }
                        }
                    }

                    M3Card {
                        title: "Custom Dock Colors [Theme]"
                        description: "Customize exact Hex with alpha (#RRGGBBAA) or rgba() color codes."

                        M3TextField {
                            label: "Background Color"
                            description: "Dock pill / bar background"
                            placeholder: "#1E1E2EE6"
                            text: ConfigStore.themeBg || ""
                            onTextEdited: val => ConfigStore.themeBg = val
                        }

                        M3TextField {
                            label: "Border / Outline Color"
                            description: "Dock outline border"
                            placeholder: "#FFFFFF1A"
                            text: ConfigStore.themeBorderColor || ""
                            onTextEdited: val => ConfigStore.themeBorderColor = val
                        }

                        M3Slider {
                            label: "Border Width"
                            from: 0; to: 6; stepSize: 1; unit: " px"
                            value: Number(ConfigStore.themeBorderWidth !== undefined ? ConfigStore.themeBorderWidth : 1)
                            onSliderMoved: val => ConfigStore.themeBorderWidth = Math.round(val)
                        }

                        M3Slider {
                            label: "Dock Corner Radius"
                            from: 0; to: 32; stepSize: 2; unit: " px"
                            value: Number(ConfigStore.themeRadius !== undefined ? ConfigStore.themeRadius : 16)
                            onSliderMoved: val => ConfigStore.themeRadius = Math.round(val)
                        }

                        M3TextField {
                            label: "Active Dot Indicator Color"
                            placeholder: "#D0BCFF"
                            text: ConfigStore.themeDotActive || ""
                            onTextEdited: val => ConfigStore.themeDotActive = val
                        }

                        M3TextField {
                            label: "Running Dot Indicator Color"
                            placeholder: "#FFFFFF80"
                            text: ConfigStore.themeDotRunning || ""
                            onTextEdited: val => ConfigStore.themeDotRunning = val
                        }

                        M3TextField {
                            label: "Accent Color"
                            placeholder: "#D0BCFF"
                            text: ConfigStore.themeAccent || ""
                            onTextEdited: val => ConfigStore.themeAccent = val
                        }

                        M3TextField {
                            label: "Text Color"
                            placeholder: "#E6E1E5"
                            text: ConfigStore.themeTextColor || ""
                            onTextEdited: val => ConfigStore.themeTextColor = val
                        }
                    }

                    M3Card {
                        title: "Context Menu Colors [Theme]"
                        description: "Customize colors for the right-click app context menu."

                        M3TextField {
                            label: "Menu Background"
                            description: "Context menu card background (leave empty to follow dock)"
                            placeholder: "#1E1E2EFA"
                            text: ConfigStore.themeMenuBg || ""
                            onTextEdited: val => ConfigStore.themeMenuBg = val
                        }

                        M3TextField {
                            label: "Menu Border"
                            description: "Context menu border outline"
                            placeholder: "#FFFFFF1A"
                            text: ConfigStore.themeMenuBorder || ""
                            onTextEdited: val => ConfigStore.themeMenuBorder = val
                        }

                        M3TextField {
                            label: "Menu Item Hover Background"
                            description: "Highlight color when hovering menu rows"
                            placeholder: "#FFFFFF1A"
                            text: ConfigStore.themeMenuHoverBg || ""
                            onTextEdited: val => ConfigStore.themeMenuHoverBg = val
                        }

                        M3TextField {
                            label: "Menu Text Color"
                            description: "Menu title and item text (ensure high contrast with Menu Background)"
                            placeholder: "#FFFFFF"
                            text: ConfigStore.themeMenuTextColor || ""
                            onTextEdited: val => ConfigStore.themeMenuTextColor = val
                        }

                        M3TextField {
                            label: "Menu Accent"
                            description: "Active indicator bar and navigation arrow color"
                            placeholder: "#D0BCFF"
                            text: ConfigStore.themeMenuAccent || ""
                            onTextEdited: val => ConfigStore.themeMenuAccent = val
                        }
                    }
                }
            }
        }
    }
}
