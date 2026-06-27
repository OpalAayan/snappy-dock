/* snappydock-d  —  hypr_ipc.h
 *
 * Synchronous Hyprland Socket1 IPC.
 *
 * Each call opens a fresh Unix-domain connection, writes the command,
 * reads the full response, and closes the socket.  The module caches
 * the socket path and the Lua-vs-legacy dispatch syntax detected at
 * init time.
 *
 * Thread safety:  NOT thread-safe.  Call from the main thread only.
 */
#ifndef SNAPPY_HYPR_IPC_H
#define SNAPPY_HYPR_IPC_H

#include <json-c/json.h>

/* ── Lifecycle ───────────────────────────────────────────────────────── */

/*
 * Resolve the Hyprland socket path and probe the compositor version.
 * Returns  0 on success.
 * Returns -1 if not running inside a Hyprland session.
 */
int  hypr_ipc_init(void);
void hypr_ipc_cleanup(void);

/* ── JSON queries (caller must json_object_put the result) ───────────── */

struct json_object *hypr_ipc_query_clients(void);
struct json_object *hypr_ipc_query_activewindow(void);
struct json_object *hypr_ipc_query_monitors(void);

/* ── Dispatch commands ───────────────────────────────────────────────── */

void hypr_ipc_focus_window(const char *addr);
void hypr_ipc_close_window(const char *addr);
void hypr_ipc_move_to_workspace(const char *addr, int ws);
void hypr_ipc_toggle_floating(const char *addr);
void hypr_ipc_toggle_fullscreen(const char *addr);
void hypr_ipc_exec(const char *cmd);

#endif /* SNAPPY_HYPR_IPC_H */
