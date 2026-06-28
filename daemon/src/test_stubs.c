/*  test_stubs.c  –  Stub implementations for unit testing.
 *
 *  Provides no-op or minimal implementations of functions from modules
 *  that require Hyprland or filesystem access (hypr_ipc, icons, launcher).
 *  This allows state.c and protocol.c to link without the real IPC.
 */
#define _POSIX_C_SOURCE 200809L

#include <stdlib.h>
#include <string.h>
#include <json-c/json.h>

/* ── hypr_ipc stubs ──────────────────────────────────────────────────── */

int hypr_ipc_init(void)                    { return -1; }
void hypr_ipc_cleanup(void)                {}

struct json_object *hypr_ipc_query_clients(void)      { return json_object_new_array(); }
struct json_object *hypr_ipc_query_activewindow(void)  { return NULL; }
struct json_object *hypr_ipc_query_monitors(void)      { return json_object_new_array(); }

void hypr_ipc_focus_window(const char *addr)          { (void)addr; }
void hypr_ipc_close_window(const char *addr)          { (void)addr; }
void hypr_ipc_move_to_workspace(const char *addr, int ws) { (void)addr; (void)ws; }
void hypr_ipc_toggle_floating(const char *addr)       { (void)addr; }
void hypr_ipc_toggle_fullscreen(const char *addr)     { (void)addr; }
void hypr_ipc_exec(const char *cmd)                   { (void)cmd; }

/* ── icons stubs ─────────────────────────────────────────────────────── */

void  icons_init(void)              {}
void  icons_cleanup(void)           {}
char *icons_get_name(const char *class_name) {
    return strdup(class_name ? class_name : "application-x-executable");
}
char *icons_find_desktop(const char *class_name) {
    (void)class_name;
    return NULL;
}

/* ── launcher stubs ──────────────────────────────────────────────────── */

#include <stdbool.h>
bool launcher_exec_class(const char *class_name) { (void)class_name; return false; }
bool launcher_exec_cmd(const char *cmd)          { (void)cmd; return false; }
