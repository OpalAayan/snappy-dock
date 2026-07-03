/*  DaemonBridge.qml  —  The single point of contact with snappydock-d.
 *
 *  Responsibilities:
 *    1. Start snappydock-d as a child Process
 *    2. Parse JSON lines from stdout via SplitParser
 *    3. Maintain reactive QML properties for the entire dock state
 *    4. Compute the merged dockItems display list
 *    5. Expose functions to send commands to daemon stdin
 */
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: bridge

    /* ── Raw state from daemon ───────────────────────────────────── */
    property var clients: []
    property var pinned:  []
    property string activeAddr: ""
    property int    activeWs:   0
    property string activeMon:  ""
    property string activeMenuId: ""

    /* ── Config from daemon ──────────────────────────────────────── */
    property var config: ({
        position: "bottom",
        alignment: "center",
        icon_size: 48,
        icon_theme: "",
        icon_fallback: "application-x-executable",
        layer: "overlay",
        full_width: false,
        exclusive_zone: 0,
        autohide: false,
        launcher_cmd: "fuzzel",
        launcher_pos: "start",
        launcher_icon: "dots",
        launcher_icon_size: 0,
        launcher_hover_bg: true,
        launcher_hover_bg_size: 0,
        font_family: "Sans",
        font_weight: "Bold",
        workspace_count: 5,
        margin_top: 0,
        margin_bottom: 5,
        margin_left: 0,
        margin_right: 0,
        hotspot_delay: 300,
        mode: "static",
        spread: 3,
        icon_spacing: 2,
        magnification: 0.78
    })

    /* ── Computed display list ───────────────────────────────────── */
    /*
     * Merged list of dock items:  pinned first (with running info),
     * then unpinned running apps (deduplicated by class).
     *
     * Each item:
     *   { className, icon, addr, title, instanceCount,
     *     isActive, isPinned, instances[] }
     */
    property var dockItems: []

    function _recompute() {
        var items = [];
        var seen = {};

        // Pinned items first
        for (var pi = 0; pi < pinned.length; pi++) {
            var p = pinned[pi];
            var cls = p["class"] || "";
            var icon = p.icon || cls;
            var key = cls.toLowerCase();

            // Find running instances for this pinned class
            var instances = [];
            for (var ci = 0; ci < clients.length; ci++) {
                if (clients[ci]["class"].toLowerCase() === key) {
                    instances.push(clients[ci]);
                }
            }
            var isActive = false;
            for (var ai = 0; ai < instances.length; ai++) {
                if (instances[ai].active) { isActive = true; break; }
            }

            items.push({
                className: cls,
                icon: icon,
                addr: instances.length > 0 ? instances[0].addr : "",
                title: instances.length > 0 ? instances[0].title : cls,
                instanceCount: instances.length,
                isActive: isActive,
                isPinned: true,
                instances: instances
            });
            seen[key] = true;
        }

        // Unpinned running apps (deduplicated by class)
        var unpinned = {};
        for (var ui = 0; ui < clients.length; ui++) {
            var c = clients[ui];
            var ukey = (c["class"] || "").toLowerCase();
            if (!ukey || seen[ukey]) continue;
            if (!unpinned[ukey]) {
                unpinned[ukey] = { first: c, instances: [] };
            }
            unpinned[ukey].instances.push(c);
        }

        var ukeys = Object.keys(unpinned);
        for (var uki = 0; uki < ukeys.length; uki++) {
            var uk = ukeys[uki];
            var entry = unpinned[uk];
            var uActive = false;
            for (var uai = 0; uai < entry.instances.length; uai++) {
                if (entry.instances[uai].active) { uActive = true; break; }
            }
            items.push({
                className: entry.first["class"],
                icon: entry.first.icon || entry.first["class"],
                addr: entry.first.addr,
                title: entry.first.title,
                instanceCount: entry.instances.length,
                isActive: uActive,
                isPinned: false,
                instances: entry.instances
            });
        }

        dockItems = items;
    }

    /* ── Daemon process ──────────────────────────────────────────── */
    Process {
        id: daemon
        command: ["snappydock-d"]
        running: true

        stdout: SplitParser {
            onRead: data => bridge._onDaemonLine(data)
        }

        onRunningChanged: {
            if (!running) {
                console.warn("[DaemonBridge] snappydock-d exited, restarting in 2s");
                restartTimer.start();
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: daemon.running = true
    }

    /* ── Parse incoming JSON lines ───────────────────────────────── */
    function _onDaemonLine(line) {
        var obj;
        try {
            obj = JSON.parse(line);
        } catch (e) {
            console.warn("[DaemonBridge] Bad JSON:", line);
            return;
        }

        if (obj.type === "config") {
            config = obj;
            Theme.iconSize = obj.icon_size || 48;
            Theme.iconTheme = obj.icon_theme || "";
            Theme.iconFallback = obj.icon_fallback || "application-x-executable";
            Theme.fontFamily = obj.font_family || "Sans";
            var w = (obj.font_weight || "bold").toLowerCase();
            Theme.fontWeight = w === "light"    ? Font.Light
                             : w === "medium"   ? Font.Medium
                             : w === "semibold"  ? Font.DemiBold
                             : w === "bold"      ? Font.Bold
                             : Font.Normal;
            Theme.itemSpacing = (obj.icon_spacing !== undefined && obj.icon_spacing >= 0) ? obj.icon_spacing : 2;
        }
        else if (obj.type === "state") {
            clients   = obj.clients  || [];
            pinned    = obj.pinned   || [];
            activeAddr = obj.active_addr || "";
            activeWs   = obj.active_ws   || 0;
            activeMon  = obj.active_mon  || "";
            _recompute();
        }
    }

    /* ── Send commands to daemon stdin ────────────────────────────── */
    function _send(obj) {
        daemon.write(JSON.stringify(obj) + "\n");
    }

    function focus(addr) {
        _send({ cmd: "focus", addr: addr });
    }

    function launch(className) {
        _send({ cmd: "launch", "class": className });
    }

    function launchCmd(cmdStr) {
        _send({ cmd: "launch_cmd", arg: cmdStr });
    }

    function closeWindow(addr) {
        _send({ cmd: "close", addr: addr });
    }

    function closeAll(className) {
        _send({ cmd: "close_all", "class": className });
    }

    function pin(className) {
        _send({ cmd: "pin", "class": className });
    }

    function unpin(className) {
        _send({ cmd: "unpin", "class": className });
    }

    function toggleFloat(addr) {
        _send({ cmd: "toggle_float", addr: addr });
    }

    function toggleFullscreen(addr) {
        _send({ cmd: "toggle_fullscreen", addr: addr });
    }

    function moveToWs(addr, ws) {
        _send({ cmd: "move_to_ws", addr: addr, ws: ws });
    }
}
