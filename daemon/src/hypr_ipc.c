/* snappydock-d  —  hypr_ipc.c
 *
 * Synchronous Hyprland Socket1 IPC with Lua vs Legacy detection.
 */
#define _POSIX_C_SOURCE 200809L

#include "hypr_ipc.h"
#include "log.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <time.h>
#include <stdbool.h>

static char s_socket_path[108] = "";
static bool use_lua_dispatch = false;

/* ── Socket helpers ──────────────────────────────────────────────────── */

static int resolve_socket_path(char *buf, size_t buflen)
{
    const char *his = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!his || !*his) {
        LOG_ERR("HYPRLAND_INSTANCE_SIGNATURE not set");
        return -1;
    }

    const char *xrd = getenv("XDG_RUNTIME_DIR");

    if (xrd && *xrd) {
        snprintf(buf, buflen, "%s/hypr/%s/.socket.sock", xrd, his);
        if (access(buf, F_OK) == 0) return 0;
    }

    snprintf(buf, buflen, "/tmp/hypr/%s/.socket.sock", his);
    if (access(buf, F_OK) == 0) return 0;

    LOG_ERR("Cannot find Hyprland socket for HIS=%s", his);
    return -1;
}

static char *ipc_request(const char *cmd)
{
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        LOG_ERR("socket(): %s", strerror(errno));
        return NULL;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", s_socket_path);

    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        LOG_ERR("connect(%s): %s", s_socket_path, strerror(errno));
        close(fd);
        return NULL;
    }

    size_t cmd_len = strlen(cmd);
    ssize_t written = write(fd, cmd, cmd_len);
    if (written < 0 || (size_t)written != cmd_len) {
        LOG_ERR("write(): %s", strerror(errno));
        close(fd);
        return NULL;
    }

    size_t cap = 4096;
    size_t len = 0;
    char  *buf = malloc(cap);
    if (!buf) {
        close(fd);
        return NULL;
    }

    for (;;) {
        if (len + 1024 > cap) {
            cap *= 2;
            char *nb = realloc(buf, cap);
            if (!nb) { free(buf); close(fd); return NULL; }
            buf = nb;
        }

        ssize_t n = read(fd, buf + len, cap - len - 1);
        if (n < 0) {
            LOG_ERR("read(): %s", strerror(errno));
            free(buf);
            close(fd);
            return NULL;
        }
        if (n == 0) break;
        len += (size_t)n;
    }

    buf[len] = '\0';
    close(fd);
    return buf;
}

/* ── Dispatch Syntax Detection ───────────────────────────────────────── */

static void detect_dispatch_syntax(void)
{
    use_lua_dispatch = false;

    char *ver_resp = ipc_request("version");
    if (!ver_resp) return;

    int major = -1, minor = -1;
    const char *v = strstr(ver_resp, "v");
    while (v) {
        if (sscanf(v, "v%d.%d", &major, &minor) == 2)
            break;
        v = strstr(v + 1, "v");
    }

    free(ver_resp);

    if (major < 0 || minor < 0) return;

    if (major == 0 && minor < 55) return;

    char *info_resp = ipc_request("systeminfo");
    if (!info_resp) return;

    if (strstr(info_resp, "configProvider: lua")) {
        use_lua_dispatch = true;
    }

    free(info_resp);
}

/* ── Lifecycle ───────────────────────────────────────────────────────── */

int hypr_ipc_init(void)
{
    if (resolve_socket_path(s_socket_path, sizeof(s_socket_path)) != 0)
        return -1;

    LOG_INF("Hyprland socket: %s", s_socket_path);
    
    detect_dispatch_syntax();
    LOG_INF("Hyprland dispatch syntax: %s", use_lua_dispatch ? "Lua" : "Legacy");
    
    return 0;
}

void hypr_ipc_cleanup(void)
{
    s_socket_path[0] = '\0';
}

/* ── JSON queries ────────────────────────────────────────────────────── */

static struct json_object *ipc_query_json(const char *endpoint)
{
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "j/%s", endpoint);

    char *resp = ipc_request(cmd);
    if (!resp) return NULL;

    struct json_object *obj = json_tokener_parse(resp);
    if (!obj) {
        LOG_ERR("JSON parse failed for %s: %.80s", endpoint, resp);
    }
    free(resp);
    return obj;
}

struct json_object *hypr_ipc_query_clients(void)
{
    return ipc_query_json("clients");
}

struct json_object *hypr_ipc_query_activewindow(void)
{
    return ipc_query_json("activewindow");
}

struct json_object *hypr_ipc_query_monitors(void)
{
    return ipc_query_json("monitors");
}

/* ── Dispatch helpers ────────────────────────────────────────────────── */

static void fire_and_forget(const char *cmd)
{
    LOG_INF("Dispatch: %s", cmd);
    char *resp = ipc_request(cmd);
    if (resp) {
        LOG_INF("Response: %s", resp);
        free(resp);
    }
}

static void settle(void)
{
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 5000000L };
    nanosleep(&ts, NULL);
}

/* ── Dispatch Functions ──────────────────────────────────────────────── */

void hypr_ipc_focus_window(const char *addr)
{
    if (!addr) return;
    char cmd[1024];

    if (use_lua_dispatch) {
        snprintf(cmd, sizeof(cmd), "dispatch hl.dsp.focus({ window = \"address:%s\" })", addr);
        fire_and_forget(cmd);

        snprintf(cmd, sizeof(cmd), "dispatch hl.dsp.window.alter_zorder({ mode = \"top\", window = \"address:%s\" })", addr);
        fire_and_forget(cmd);

        snprintf(cmd, sizeof(cmd), "dispatch hl.dsp.focus({ window = \"activewindow\" })");
        fire_and_forget(cmd);
    } else {
        snprintf(cmd, sizeof(cmd), "dispatch focuswindow address:%s", addr);
        fire_and_forget(cmd);

        settle();

        snprintf(cmd, sizeof(cmd), "dispatch alterzorder top");
        fire_and_forget(cmd);
    }
}

void hypr_ipc_close_window(const char *addr)
{
    if (!addr) return;
    char cmd[1024];

    if (use_lua_dispatch) {
        snprintf(cmd, sizeof(cmd), "dispatch hl.dsp.window.close({ window = \"address:%s\" })", addr);
    } else {
        snprintf(cmd, sizeof(cmd), "dispatch closewindow address:%s", addr);
    }
    fire_and_forget(cmd);
}

void hypr_ipc_move_to_workspace(const char *addr, int ws)
{
    if (!addr) return;
    char cmd[1024];

    if (use_lua_dispatch) {
        snprintf(cmd, sizeof(cmd), "dispatch hl.dsp.window.move({ workspace = \"%d\", window = \"address:%s\" })", ws, addr);
    } else {
        snprintf(cmd, sizeof(cmd), "dispatch movetoworkspace %d,address:%s", ws, addr);
    }
    fire_and_forget(cmd);
}

void hypr_ipc_toggle_floating(const char *addr)
{
    if (!addr) return;
    char cmd[1024];

    if (use_lua_dispatch) {
        snprintf(cmd, sizeof(cmd), "dispatch hl.dsp.window.float({ window = \"address:%s\", action = \"toggle\" })", addr);
    } else {
        snprintf(cmd, sizeof(cmd), "dispatch togglefloating address:%s", addr);
    }
    fire_and_forget(cmd);
}

void hypr_ipc_toggle_fullscreen(const char *addr)
{
    if (!addr) return;
    char cmd[1024];

    if (use_lua_dispatch) {
        snprintf(cmd, sizeof(cmd), "dispatch hl.dsp.window.fullscreen({ window = \"address:%s\", action = \"toggle\" })", addr);
    } else {
        hypr_ipc_focus_window(addr);
        settle();
        snprintf(cmd, sizeof(cmd), "dispatch fullscreen");
    }
    fire_and_forget(cmd);
}

void hypr_ipc_exec(const char *cmd)
{
    if (!cmd) return;
    char buf[1024];
    snprintf(buf, sizeof(buf), "dispatch exec [silent] %s", cmd);
    fire_and_forget(buf);
}
