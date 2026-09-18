pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

/*  IconResolver – robust icon name resolution for the config‑gui.
 *
 *  Resolution pipeline:
 *    1. User override (from ConfigStore.iconOverrides)
 *    2. Quickshell.iconPath() — searches the current icon theme + hicolor
 *    3. Async script lookup — runs icon-lookup.sh which searches .desktop
 *       files, flatpak exports, pixmaps, etc.
 *
 *  Usage:
 *    source: IconResolver.resolve("org.gnome.Nautilus")
 *
 *  When the async script finds a better icon, `revision` increments.
 *  Bind your Image.source to include `IconResolver.revision` so it
 *  re‑evaluates automatically:
 *    source: IconResolver.resolve(appName) + (IconResolver.revision ? "" : "")
 */
Singleton {
    id: root

    /* Incremented whenever an async lookup completes — forces re-evaluation
     * of any binding that reads it. */
    property int revision: 0

    /* Path to the helper script (relative to this file's directory) */
    readonly property string _scriptDir: {
        // QuickShell resolves the config-gui directory; script is in scripts/ subdir
        var home = Quickshell.env("HOME") || "/home";
        // Try installed location first, then dev location
        var candidates = [
            "/usr/local/share/snappy-dock/config-gui/scripts/icon-lookup.sh",
            "/usr/share/snappy-dock/config-gui/scripts/icon-lookup.sh",
            home + "/.local/share/snappy-dock/config-gui/scripts/icon-lookup.sh",
            // Dev: script dir relative to the snappy-dock repo
        ];
        // We'll just use the first that the Process can find; bash will error if missing
        for (var i = 0; i < candidates.length; i++) {
            return candidates[i];
        }
        return candidates[0];
    }

    /* ── Caches ─────────────────────────────────────────────────────── */

    /* theme-based cache: results from Quickshell.iconPath() */
    property var _themeCache: ({})

    /* async cache: results from the icon-lookup.sh script */
    property var _asyncCache: ({})

    /* set of names currently being looked up (prevent duplicate runs) */
    property var _pending: ({})

    /* ── Primary API ─────────────────────────────────────────────── */

    /// Resolve an icon name to a URL suitable for Image.source.
    /// Returns the best‑known value immediately (override → theme → async cache → fallback).
    /// Triggers async lookup if not yet cached.
    function resolve(name) {
        // Accessing revision registers a reactive dependency in Qt's property engine,
        // so whenever revision increments, any binding calling resolve() will re-evaluate.
        var _depRev = root.revision;

        if (!name || name.length === 0)
            return _fallbackPath();

        // 1. User override
        var override = ConfigStore.getIconOverride(name);
        if (override && override.length > 0) {
            // Prefix file:// if it's an absolute path without scheme
            if (override.charAt(0) === '/')
                return "file://" + override;
            return override;
        }

        // 2. Theme cache hit
        if (_themeCache[name] !== undefined)
            return _themeCache[name];

        // 3. Try Quickshell.iconPath() variants (synchronous)
        var themePath = _resolveViaTheme(name);
        if (themePath && themePath.length > 0) {
            _themeCache[name] = themePath;
            return themePath;
        }

        // 4. Async cache hit (from previous script run)
        if (_asyncCache[name] !== undefined && _asyncCache[name].length > 0) {
            return _asyncCache[name];
        }

        // 5. Trigger async lookup if not already pending
        if (!_pending[name]) {
            _pending[name] = true;
            _launchLookup(name);
        }

        // 6. Return fallback for now
        return _fallbackPath();
    }

    /* ── Theme resolution (synchronous) ─────────────────────────── */

    function _resolveViaTheme(name) {
        // Exact
        var p = Quickshell.iconPath(name);
        if (p && p.length > 0) return p;

        // Lowercase
        var lower = name.toLowerCase();
        if (lower !== name) {
            p = Quickshell.iconPath(lower);
            if (p && p.length > 0) return p;
        }

        // Last segment of reverse‑DNS (org.gnome.Nautilus → Nautilus)
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

        // Hyphen‑separated variation (GpuScreenRecorder → gpu-screen-recorder)
        var hyphenated = name.replace(/([a-z])([A-Z])/g, "$1-$2").toLowerCase();
        if (hyphenated !== lower) {
            p = Quickshell.iconPath(hyphenated);
            if (p && p.length > 0) return p;
        }

        return "";
    }

    /* ── Async script lookup ────────────────────────────────────── */

    function _launchLookup(name) {
        var proc = _lookupComponent.createObject(root, { "_appName": name });
        if (proc) {
            proc.running = true;
        }
    }

    /* Dynamic Process component for async icon lookups */
    Component {
        id: _lookupComponent

        Process {
            id: lookupProc
            property string _appName: ""
            property string _result: ""

            command: [
                "bash", "-c",
                'for s in "$SNAPPY_DOCK_CONFIG_GUI_DIR/scripts/icon-lookup.sh" \
                          "/usr/local/share/snappy-dock/config-gui/scripts/icon-lookup.sh" \
                          "/usr/share/snappy-dock/config-gui/scripts/icon-lookup.sh" \
                          "$HOME/.local/share/snappy-dock/config-gui/scripts/icon-lookup.sh" \
                          "$PWD/config-gui/scripts/icon-lookup.sh" \
                          "$PWD/scripts/icon-lookup.sh"; do \
                     if [ -f "$s" ]; then exec bash "$s" "$1"; fi; \
                 done',
                "_",
                _appName
            ]

            stdout: SplitParser {
                onRead: data => {
                    if (data && data.trim().length > 0) {
                        lookupProc._result = data.trim();
                    }
                }
            }

            onRunningChanged: {
                if (!running) {
                    // Process finished
                    delete root._pending[lookupProc._appName];

                    if (lookupProc._result.length > 0) {
                        var path = lookupProc._result;
                        // Prefix file:// for absolute paths
                        if (path.charAt(0) === '/')
                            path = "file://" + path;

                        root._asyncCache[lookupProc._appName] = path;
                        root.revision++;
                    }

                    // Clean up the dynamic object
                    lookupProc.destroy();
                }
            }
        }
    }

    /* ── Internals ───────────────────────────────────────────────── */

    function _fallbackPath() {
        var p = Quickshell.iconPath("application-x-executable");
        return (p && p.length > 0) ? p : "";
    }

    /* Clear all caches (useful after icon override changes) */
    function invalidate(name) {
        if (name) {
            delete _themeCache[name];
            delete _asyncCache[name];
            delete _pending[name];
        } else {
            _themeCache = {};
            _asyncCache = {};
            _pending = {};
        }
        revision++;
    }
}
