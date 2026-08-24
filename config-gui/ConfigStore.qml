pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: store

    readonly property string configPath: {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (xdg && xdg.length > 0)
            return xdg + "/snappy-dock/config.ini";
        var home = Quickshell.env("HOME") || "/home";
        return home + "/.config/snappy-dock/config.ini";
    }

    /* ── Reactive Config State ────────────────────────────────────── */
    /* [Dock] */
    property string position: "bottom"
    property string alignment: "center"
    property string mode: "static"
    property string layer: "top"
    property bool fullWidth: false
    property int exclusiveZone: 0
    property bool autoHide: false
    property int hotspotDelay: 300
    property string launcherCmd: "fuzzel"
    property string launcherPos: "start"
    property string launcherIcon: "dots"
    property int launcherIconSize: 0
    property bool launcherHoverBg: true
    property int launcherHoverBgSize: 0
    property bool iconHoverBg: true
    property int workspaceCount: 5
    property real magnification: 0.78
    property int spread: 3
    property int iconSpacing: 2
    property real riseSpacing: 0.5

    /* [Icons] */
    property int iconSize: 48
    property string iconTheme: ""
    property string iconFallback: "application-x-executable"

    /* [Margins] */
    property int marginTop: 0
    property int marginBottom: 5
    property int marginLeft: 0
    property int marginRight: 0

    /* [Font] */
    property string fontFamily: "Sans"
    property string fontWeight: "Bold"

    /* [Theme] */
    property string themeBg: ""
    property string themeBorderColor: ""
    property int themeBorderWidth: 1
    property int themeRadius: 16
    property string themeDotRunning: ""
    property string themeDotActive: ""
    property string themeAccent: ""
    property string themeTextColor: ""
    property string themeIconHoverBg: ""
    property string themeLauncherHoverBg: ""

    property bool isLoaded: false
    property string saveStatus: ""

    FileView {
        id: fileView
        path: store.configPath
        preload: true
        watchChanges: false

        onLoaded: {
            store._parseIni(fileView.text());
            store.isLoaded = true;
        }

        onLoadFailed: {
            console.log("[ConfigStore] Config file not found, using defaults:", store.configPath);
            store.isLoaded = true;
        }
    }

    function reload() {
        fileView.reload();
    }

    function _parseBool(val) {
        var s = (val || "").toLowerCase();
        return s === "true" || s === "yes" || s === "1";
    }

    function _parseIni(content) {
        if (!content) return;
        var lines = content.split(/\r?\n/);
        var currentSection = "";

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0 || line.startsWith("#") || line.startsWith(";"))
                continue;

            if (line.startsWith("[") && line.endsWith("]")) {
                currentSection = line.substring(1, line.length - 1).trim().toLowerCase();
                continue;
            }

            var eqIdx = line.indexOf("=");
            if (eqIdx === -1) continue;

            var key = line.substring(0, eqIdx).trim().toLowerCase();
            var val = line.substring(eqIdx + 1).trim();

            if (currentSection === "dock") {
                if (key === "position")          store.position = val.toLowerCase();
                else if (key === "alignment")     store.alignment = val.toLowerCase();
                else if (key === "mode")          store.mode = val.toLowerCase();
                else if (key === "layer")         store.layer = val.toLowerCase();
                else if (key === "fullwidth")     store.fullWidth = store._parseBool(val);
                else if (key === "exclusivezone") {
                    if (val.toLowerCase() === "auto") store.exclusiveZone = -1;
                    else if (val.toLowerCase() === "false" || val.toLowerCase() === "off") store.exclusiveZone = 0;
                    else store.exclusiveZone = parseInt(val) || 0;
                }
                else if (key === "autohide")           store.autoHide = store._parseBool(val);
                else if (key === "hotspotdelay")       store.hotspotDelay = parseInt(val) || 300;
                else if (key === "launchercmd")        store.launcherCmd = val;
                else if (key === "launcherpos")        store.launcherPos = val.toLowerCase();
                else if (key === "launchericon")       store.launcherIcon = val;
                else if (key === "launchericonsize")   store.launcherIconSize = parseInt(val) || 0;
                else if (key === "launcherhoverbg")    store.launcherHoverBg = store._parseBool(val);
                else if (key === "launcherhoverbgsize") store.launcherHoverBgSize = parseInt(val) || 0;
                else if (key === "iconhoverbg")        store.iconHoverBg = store._parseBool(val);
                else if (key === "workspacecount")     store.workspaceCount = parseInt(val) || 5;
                else if (key === "magnification")      store.magnification = parseFloat(val) || 0.78;
                else if (key === "spread")             store.spread = parseInt(val) || 3;
                else if (key === "iconspacing")        store.iconSpacing = parseInt(val) || 2;
                else if (key === "risespacing")        store.riseSpacing = parseFloat(val) || 0.5;
            }
            else if (currentSection === "icons") {
                if (key === "iconsize")                store.iconSize = parseInt(val) || 48;
                else if (key === "theme" || key === "icontheme") store.iconTheme = val;
                else if (key === "fallback" || key === "fallbackicon") store.iconFallback = val;
            }
            else if (currentSection === "margins") {
                if (key === "top")       store.marginTop = parseInt(val) || 0;
                else if (key === "bottom") store.marginBottom = parseInt(val) || 0;
                else if (key === "left")   store.marginLeft = parseInt(val) || 0;
                else if (key === "right")  store.marginRight = parseInt(val) || 0;
            }
            else if (currentSection === "font") {
                if (key === "family")      store.fontFamily = val;
                else if (key === "weight") store.fontWeight = val;
            }
            else if (currentSection === "theme") {
                if (key === "background" || key === "bgcolor" || key === "dockbg") store.themeBg = val;
                else if (key === "bordercolor" || key === "dockoutline") store.themeBorderColor = val;
                else if (key === "borderwidth" || key === "outlineborderwidth") store.themeBorderWidth = parseInt(val) || 1;
                else if (key === "radius" || key === "dockradius") store.themeRadius = parseInt(val) || 16;
                else if (key === "dotrunning")   store.themeDotRunning = val;
                else if (key === "dotactive")    store.themeDotActive = val;
                else if (key === "accentcolor" || key === "accent") store.themeAccent = val;
                else if (key === "textcolor")    store.themeTextColor = val;
                else if (key === "iconhoverbg")  store.themeIconHoverBg = val;
                else if (key === "launcherhoverbg") store.themeLauncherHoverBg = val;
            }
        }
    }

    function generateIni() {
        var out = [];
        out.push("# Snappy Dock configuration file");
        out.push("# Generated by snappy-dock --config-gui");
        out.push("");
        out.push("[Dock]");
        out.push("Position=" + store.position);
        out.push("Alignment=" + store.alignment);
        out.push("Mode=" + store.mode);
        out.push("Layer=" + store.layer);
        out.push("FullWidth=" + (store.fullWidth ? "true" : "false"));
        out.push("ExclusiveZone=" + (store.exclusiveZone === -1 ? "auto" : store.exclusiveZone));
        out.push("AutoHide=" + (store.autoHide ? "true" : "false"));
        out.push("HotspotDelay=" + store.hotspotDelay);
        out.push("LauncherCmd=" + store.launcherCmd);
        out.push("LauncherPos=" + store.launcherPos);
        out.push("LauncherIcon=" + store.launcherIcon);
        out.push("LauncherIconSize=" + store.launcherIconSize);
        out.push("LauncherHoverBg=" + (store.launcherHoverBg ? "true" : "false"));
        out.push("LauncherHoverBgSize=" + store.launcherHoverBgSize);
        out.push("IconHoverBg=" + (store.iconHoverBg ? "true" : "false"));
        out.push("WorkspaceCount=" + store.workspaceCount);
        out.push("Magnification=" + store.magnification.toFixed(2));
        out.push("Spread=" + store.spread);
        out.push("IconSpacing=" + store.iconSpacing);
        out.push("RiseSpacing=" + store.riseSpacing.toFixed(2));
        out.push("");
        out.push("[Icons]");
        out.push("IconSize=" + store.iconSize);
        out.push("Theme=" + store.iconTheme);
        out.push("Fallback=" + store.iconFallback);
        out.push("");
        out.push("[Margins]");
        out.push("Top=" + store.marginTop);
        out.push("Bottom=" + store.marginBottom);
        out.push("Left=" + store.marginLeft);
        out.push("Right=" + store.marginRight);
        out.push("");
        out.push("[Font]");
        out.push("Family=" + store.fontFamily);
        out.push("Weight=" + store.fontWeight);
        out.push("");
        out.push("[Theme]");
        if (store.themeBg)              out.push("Background=" + store.themeBg);
        if (store.themeBorderColor)     out.push("BorderColor=" + store.themeBorderColor);
        if (store.themeBorderWidth >= 0) out.push("BorderWidth=" + store.themeBorderWidth);
        if (store.themeRadius > 0)      out.push("Radius=" + store.themeRadius);
        if (store.themeDotRunning)      out.push("DotRunning=" + store.themeDotRunning);
        if (store.themeDotActive)       out.push("DotActive=" + store.themeDotActive);
        if (store.themeAccent)          out.push("AccentColor=" + store.themeAccent);
        if (store.themeTextColor)       out.push("TextColor=" + store.themeTextColor);
        if (store.themeIconHoverBg)     out.push("IconHoverBg=" + store.themeIconHoverBg);
        if (store.themeLauncherHoverBg) out.push("LauncherHoverBg=" + store.themeLauncherHoverBg);
        out.push("");
        return out.join("\n");
    }

    function save() {
        var text = generateIni();
        fileView.setText(text);
        saveStatus = "Saved!";
    }

    function resetDefaults() {
        position = "bottom";
        alignment = "center";
        mode = "static";
        layer = "top";
        fullWidth = false;
        exclusiveZone = 0;
        autoHide = false;
        hotspotDelay = 300;
        launcherCmd = "fuzzel";
        launcherPos = "start";
        launcherIcon = "dots";
        launcherIconSize = 0;
        launcherHoverBg = true;
        launcherHoverBgSize = 0;
        iconHoverBg = true;
        workspaceCount = 5;
        magnification = 0.78;
        spread = 3;
        iconSpacing = 2;
        riseSpacing = 0.5;

        iconSize = 48;
        iconTheme = "";
        iconFallback = "application-x-executable";

        marginTop = 0;
        marginBottom = 5;
        marginLeft = 0;
        marginRight = 0;

        fontFamily = "Sans";
        fontWeight = "Bold";

        themeBg = "";
        themeBorderColor = "";
        themeBorderWidth = 1;
        themeRadius = 16;
        themeDotRunning = "";
        themeDotActive = "";
        themeAccent = "";
        themeTextColor = "";
        themeIconHoverBg = "";
        themeLauncherHoverBg = "";
    }

    function applyPreset(name) {
        if (name === "catppuccin-mocha") {
            // Catppuccin Mocha — Deep blue-black with icy blue accent
            // Ref: bg=#11111b, card=#1e1e2e, accent=#c1e6ff, text=#cdd6f4
            themeBg = "#1E1E2EE6";
            themeBorderColor = "#C1E6FF26";
            themeBorderWidth = 1;
            themeRadius = 16;
            themeDotRunning = "#A6ADC8AA";
            themeDotActive = "#9DC2F9";
            themeAccent = "#9DC2F9";
            themeTextColor = "#CDD6F4";
            themeIconHoverBg = "#9DC2F926";
            themeLauncherHoverBg = "#9DC2F933";
        } else if (name === "catppuccin-latte") {
            // Catppuccin Latte — Light cream with blackberry mauve accent
            // Ref: bg=#bcc0cc, card=#eff1f5, accent=#8839ef, text=#4c4f69
            themeBg = "#DCE0E8D9";
            themeBorderColor = "#8839EF33";
            themeBorderWidth = 1;
            themeRadius = 16;
            themeDotRunning = "#6C6F8599";
            themeDotActive = "#8839EF";
            themeAccent = "#8839EF";
            themeTextColor = "#4C4F69";
            themeIconHoverBg = "#8839EF1A";
            themeLauncherHoverBg = "#8839EF26";
        } else if (name === "dracula") {
            // Dracula — Charcoal slate with rich purple
            // Ref: bg=#282a36, card=#44475a, accent=#ab76f5, text=#f8f8f2
            themeBg = "#282A36E6";
            themeBorderColor = "#AB76F533";
            themeBorderWidth = 1;
            themeRadius = 14;
            themeDotRunning = "#6272A4CC";
            themeDotActive = "#AB76F5";
            themeAccent = "#AB76F5";
            themeTextColor = "#F8F8F2";
            themeIconHoverBg = "#AB76F526";
            themeLauncherHoverBg = "#AB76F533";
        } else if (name === "nord") {
            // Nord — Polar slate with frost blue
            // Ref: bg=#2e3440, card=#3b4252, accent=#5e81ac, text=#eceff4
            themeBg = "#2E3440E6";
            themeBorderColor = "#5E81AC26";
            themeBorderWidth = 1;
            themeRadius = 12;
            themeDotRunning = "#D8DEE999";
            themeDotActive = "#5E81AC";
            themeAccent = "#5E81AC";
            themeTextColor = "#ECEFF4";
            themeIconHoverBg = "#5E81AC26";
            themeLauncherHoverBg = "#5E81AC33";
        } else if (name === "tokyo-night") {
            // Tokyo Night — Deep indigo with neon pink
            // Ref: bg=#000000, card=#24283b, accent=#f7768e, text=#ffffff
            themeBg = "#24283BE6";
            themeBorderColor = "#F7768E26";
            themeBorderWidth = 1;
            themeRadius = 14;
            themeDotRunning = "#7AA2F7AA";
            themeDotActive = "#F7768E";
            themeAccent = "#F7768E";
            themeTextColor = "#FFFFFF";
            themeIconHoverBg = "#F7768E26";
            themeLauncherHoverBg = "#F7768E33";
        } else if (name === "rose-pine") {
            // Rose Pine — Warm twilight with rose gold
            // Ref: bg=#191724, card=#1f1d2e, accent=#ebbcba, text=#e0def4
            themeBg = "#1F1D2EE6";
            themeBorderColor = "#EBBCBA26";
            themeBorderWidth = 1;
            themeRadius = 16;
            themeDotRunning = "#908CAAAA";
            themeDotActive = "#EBBCBA";
            themeAccent = "#EBBCBA";
            themeTextColor = "#E0DEF4";
            themeIconHoverBg = "#EBBCBA26";
            themeLauncherHoverBg = "#EBBCBA33";
        } else if (name === "gruvbox") {
            // Gruvbox Dark — Earthy warm with orange
            // Ref: bg=#282828, card=#3c3836, accent=#fe8019, text=#ebdbb2
            themeBg = "#282828E6";
            themeBorderColor = "#FE801926";
            themeBorderWidth = 1;
            themeRadius = 12;
            themeDotRunning = "#A8998499";
            themeDotActive = "#FE8019";
            themeAccent = "#FE8019";
            themeTextColor = "#EBDBB2";
            themeIconHoverBg = "#FE801926";
            themeLauncherHoverBg = "#FE801933";
        } else if (name === "cyberpunk") {
            // Cyberpunk — Pure black void with neon cyan
            // Ref: bg=#000000, card=#0a0a12, accent=#00fff9, text=#ffffff
            themeBg = "#0A0A12E6";
            themeBorderColor = "#00FFF926";
            themeBorderWidth = 1;
            themeRadius = 8;
            themeDotRunning = "#FF00FF80";
            themeDotActive = "#00FFF9";
            themeAccent = "#00FFF9";
            themeTextColor = "#FFFFFF";
            themeIconHoverBg = "#00FFF91A";
            themeLauncherHoverBg = "#00FFF926";
        } else if (name === "macos") {
            // macOS — Dark frosted glass with subtle white border
            // Ref: liquid-glassB: bg=#00000033, border=#ffffff33
            themeBg = "#0000004D";
            themeBorderColor = "#FFFFFF33";
            themeBorderWidth = 1;
            themeRadius = 18;
            themeDotRunning = "#FFFFFF80";
            themeDotActive = "#FFFFFFCC";
            themeAccent = "#FFFFFF";
            themeTextColor = "#FFFFFF";
            themeIconHoverBg = "#FFFFFF1A";
            themeLauncherHoverBg = "#FFFFFF26";
        } else if (name === "stormlight") {
            // Stormlight Slate — Overcast slate with lightning yellow
            // Ref: bg=#292c3c, card=#303446, accent=#f7f36d, text=#ffffff
            themeBg = "#303446E6";
            themeBorderColor = "#F7F36D26";
            themeBorderWidth = 1;
            themeRadius = 14;
            themeDotRunning = "#838BA7AA";
            themeDotActive = "#F7F36D";
            themeAccent = "#F7F36D";
            themeTextColor = "#FFFFFF";
            themeIconHoverBg = "#F7F36D1A";
            themeLauncherHoverBg = "#F7F36D26";
        }
    }
}
