pragma Singleton
import Quickshell
import QtQuick

/*  IconResolver – robust icon name resolution for the config‑gui.
 *
 *  QuickShell's Quickshell.iconPath(name) looks up the current icon theme
 *  (set via QS_ICON_THEME env‑var) and returns a file:// URL, or empty
 *  if nothing matched.  Many desktop‑class names need case‑folding or
 *  reverse‑DNS segment extraction before a match can be found.
 *
 *  Usage:   source: IconResolver.resolve("org.gnome.Nautilus")
 */
Singleton {
    id: root

    /* ── Primary API ─────────────────────────────────────────────── */

    /// Resolve an icon name to a URL suitable for Image.source.
    /// Tries: exact → lowercase → last reverse‑DNS segment → fallback.
    function resolve(name) {
        if (!name || name.length === 0)
            return _fallbackPath();

        // 1. Exact
        var p = Quickshell.iconPath(name);
        if (p && p.length > 0) return p;

        // 2. Lowercase
        var lower = name.toLowerCase();
        if (lower !== name) {
            p = Quickshell.iconPath(lower);
            if (p && p.length > 0) return p;
        }

        // 3. Last segment of reverse‑DNS (org.gnome.Nautilus → Nautilus)
        var parts = name.split(".");
        if (parts.length > 1) {
            var last = parts[parts.length - 1];
            p = Quickshell.iconPath(last);
            if (p && p.length > 0) return p;
            var lastLower = last.toLowerCase();
            if (lastLower !== last) {
                p = Quickshell.iconPath(lastLower);
                if (p && p.length > 0) return p;
            }
        }

        // 4. Hyphen‑separated variation (GpuScreenRecorder → gpu-screen-recorder)
        var hyphenated = name.replace(/([a-z])([A-Z])/g, "$1-$2").toLowerCase();
        if (hyphenated !== lower) {
            p = Quickshell.iconPath(hyphenated);
            if (p && p.length > 0) return p;
        }

        return _fallbackPath();
    }

    /* ── Internals ───────────────────────────────────────────────── */

    function _fallbackPath() {
        var p = Quickshell.iconPath("application-x-executable");
        return (p && p.length > 0) ? p : "";
    }
}
