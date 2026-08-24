pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property bool isDark: true

    /* ── M3 Charcoal + Purple / Material You Palette ──────────────── */
    readonly property color background:           isDark ? "#141218" : "#FEF7FF"
    readonly property color surface:              isDark ? "#1C1B1F" : "#F7F2FA"
    readonly property color surfaceContainer:     isDark ? "#211F26" : "#F3EDF7"
    readonly property color surfaceContainerHigh: isDark ? "#2B2930" : "#ECE6F0"
    readonly property color surfaceContainerHighest: isDark ? "#36343B" : "#E6E0E9"
    
    readonly property color primary:                  "#CFBCFE"
    readonly property color textOnPrimary:            "#1D192B"
    readonly property color primaryContainer:         isDark ? "#4F378B" : "#EADDFF"
    readonly property color textOnPrimaryContainer:   isDark ? "#EADDFF" : "#21005D"

    readonly property color secondaryContainer:       isDark ? "#4A4458" : "#E8DEF8"
    readonly property color textOnSecondaryContainer: isDark ? "#E8DEF8" : "#1D192B"

    readonly property color outline:              isDark ? "#49454F" : "#79747E"
    readonly property color outlineVariant:       isDark ? "#332F37" : "#CAC4D0"

    readonly property color textPrimary:          isDark ? "#E6E1E5" : "#1D1B20"
    readonly property color textSecondary:        isDark ? "#CAC4D0" : "#49454F"
    readonly property color textTertiary:         isDark ? "#938F99" : "#79747E"

    readonly property color warning:              isDark ? "#FFB74D" : "#E65100"
    readonly property color warningContainer:     isDark ? Qt.rgba(1.0, 0.72, 0.30, 0.15) : Qt.rgba(0.90, 0.32, 0.0, 0.12)
    readonly property color error:                isDark ? "#F2B8B5" : "#B3261E"
    readonly property color success:              isDark ? "#A5D6A7" : "#2E7D32"

    /* ── Typography ───────────────────────────────────────────────── */
    readonly property string fontFamily: "Rubik, Inter, 'JetBrainsMono Nerd Font', 'FiraCode Nerd Font', 'Symbols Nerd Font', Sans, sans-serif"

    /* ── Shape Radii ──────────────────────────────────────────────── */
    readonly property int radiusSmall:  8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge:  16
    readonly property int radiusFull:   999

    /* ── Animations ───────────────────────────────────────────────── */
    readonly property int animDuration: 180
}
