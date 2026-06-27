/* snappydock-d  —  state.c
 *
 * Central dock state model.  Owns all client and pinned data.
 *
 * Memory contract:
 *   - Every string in DockClient/PinnedEntry is strdup'd.
 *   - state_free() releases everything.
 *   - Borrowed pointers from state_first_instance() become
 *     invalid after any state mutation.
 */
#define _POSIX_C_SOURCE 200809L

#include "state.h"
#include "hypr_ipc.h"
#include "icons.h"
#include "log.h"

#include <json-c/json.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

/* ── Helpers ─────────────────────────────────────────────────────────── */

static void client_clear(DockClient *c)
{
    free(c->addr);
    free(c->class_name);
    free(c->title);
    free(c->icon);
    memset(c, 0, sizeof(*c));
}

static void pinned_clear(PinnedEntry *p)
{
    free(p->class_name);
    free(p->icon);
    memset(p, 0, sizeof(*p));
}

static void ensure_client_cap(DockState *s, int need)
{
    if (s->client_cap >= need) return;
    int new_cap = s->client_cap ? s->client_cap * 2 : 16;
    if (new_cap < need) new_cap = need;
    s->clients = realloc(s->clients, (size_t)new_cap * sizeof(DockClient));
    s->client_cap = new_cap;
}

static void ensure_pinned_cap(DockState *s, int need)
{
    if (s->pinned_cap >= need) return;
    int new_cap = s->pinned_cap ? s->pinned_cap * 2 : 8;
    if (new_cap < need) new_cap = need;
    s->pinned = realloc(s->pinned, (size_t)new_cap * sizeof(PinnedEntry));
    s->pinned_cap = new_cap;
}

/* ── Pinned file path ────────────────────────────────────────────────── */

static void pinned_file_path(char *buf, size_t buflen)
{
    const char *xdg = getenv("XDG_CONFIG_HOME");
    const char *home = getenv("HOME");

    if (xdg && *xdg)
        snprintf(buf, buflen, "%s/snappy-dock/pinned", xdg);
    else if (home)
        snprintf(buf, buflen, "%s/.config/snappy-dock/pinned", home);
    else
        snprintf(buf, buflen, "/tmp/snappy-dock-pinned");
}

/* ── Lifecycle ───────────────────────────────────────────────────────── */

void state_init(DockState *s)
{
    memset(s, 0, sizeof(*s));
}

void state_free(DockState *s)
{
    for (int i = 0; i < s->client_count; i++)
        client_clear(&s->clients[i]);
    free(s->clients);

    for (int i = 0; i < s->pinned_count; i++)
        pinned_clear(&s->pinned[i]);
    free(s->pinned);

    free(s->active_addr);
    free(s->active_mon);
    memset(s, 0, sizeof(*s));
}

/* ── Pinned file I/O ─────────────────────────────────────────────────── */

void state_load_pinned(DockState *s)
{
    /* Clear existing pinned list */
    for (int i = 0; i < s->pinned_count; i++)
        pinned_clear(&s->pinned[i]);
    s->pinned_count = 0;

    char path[512];
    pinned_file_path(path, sizeof(path));

    FILE *f = fopen(path, "r");
    if (!f) {
        LOG_DBG("No pinned file at %s", path);
        return;
    }

    char line[256];
    while (fgets(line, sizeof(line), f)) {
        /* Trim */
        size_t len = strlen(line);
        while (len > 0 && (line[len-1] == '\n' || line[len-1] == '\r' ||
                           line[len-1] == ' '))
            line[--len] = '\0';
        if (len == 0) continue;

        ensure_pinned_cap(s, s->pinned_count + 1);
        PinnedEntry *p = &s->pinned[s->pinned_count];
        p->class_name = strdup(line);
        p->icon = icons_get_name(line);
        s->pinned_count++;
    }

    fclose(f);
    LOG_INF("Loaded %d pinned apps", s->pinned_count);
}

static void save_pinned(const DockState *s)
{
    char path[512];
    pinned_file_path(path, sizeof(path));

    /* Ensure directory exists */
    char dir[512];
    snprintf(dir, sizeof(dir), "%s", path);
    char *slash = strrchr(dir, '/');
    if (slash) {
        *slash = '\0';
        char cmd[600];
        snprintf(cmd, sizeof(cmd), "mkdir -p '%s'", dir);
        (void)system(cmd);
    }

    FILE *f = fopen(path, "w");
    if (!f) {
        LOG_ERR("Cannot write pinned file: %s", path);
        return;
    }
    for (int i = 0; i < s->pinned_count; i++)
        fprintf(f, "%s\n", s->pinned[i].class_name);
    fclose(f);
}

void state_pin(DockState *s, const char *class_name)
{
    if (!class_name || state_is_pinned(s, class_name)) return;

    ensure_pinned_cap(s, s->pinned_count + 1);
    PinnedEntry *p = &s->pinned[s->pinned_count];
    p->class_name = strdup(class_name);
    p->icon = icons_get_name(class_name);
    s->pinned_count++;
    save_pinned(s);
    LOG_INF("Pinned: %s", class_name);
}

void state_unpin(DockState *s, const char *class_name)
{
    if (!class_name) return;

    for (int i = 0; i < s->pinned_count; i++) {
        if (strcasecmp(s->pinned[i].class_name, class_name) == 0) {
            pinned_clear(&s->pinned[i]);
            /* Shift remaining entries down */
            memmove(&s->pinned[i], &s->pinned[i+1],
                    (size_t)(s->pinned_count - i - 1) * sizeof(PinnedEntry));
            s->pinned_count--;
            save_pinned(s);
            LOG_INF("Unpinned: %s", class_name);
            return;
        }
    }
}

bool state_is_pinned(const DockState *s, const char *class_name)
{
    if (!class_name) return false;
    for (int i = 0; i < s->pinned_count; i++) {
        if (strcasecmp(s->pinned[i].class_name, class_name) == 0)
            return true;
    }
    return false;
}

/* ── Full refresh from IPC ───────────────────────────────────────────── */

bool state_refresh(DockState *s)
{
    /* Clear existing clients */
    for (int i = 0; i < s->client_count; i++)
        client_clear(&s->clients[i]);
    s->client_count = 0;

    /* Query clients */
    struct json_object *jarr = hypr_ipc_query_clients();
    if (!jarr) return false;

    int n = json_object_array_length(jarr);
    ensure_client_cap(s, n);

    for (int i = 0; i < n; i++) {
        struct json_object *jc = json_object_array_get_idx(jarr, i);
        if (!jc) continue;

        struct json_object *jaddr, *jclass, *jtitle, *jfloat, *jfs;
        json_object_object_get_ex(jc, "address",    &jaddr);
        json_object_object_get_ex(jc, "class",      &jclass);
        json_object_object_get_ex(jc, "title",      &jtitle);
        json_object_object_get_ex(jc, "floating",   &jfloat);
        json_object_object_get_ex(jc, "fullscreen", &jfs);

        /* Extract workspace ID from nested object */
        int ws_id = 0;
        struct json_object *jws_obj;
        if (json_object_object_get_ex(jc, "workspace", &jws_obj)) {
            struct json_object *jws_id;
            if (json_object_object_get_ex(jws_obj, "id", &jws_id))
                ws_id = json_object_get_int(jws_id);
        }

        /* Skip special workspaces (id < 0) */
        if (ws_id < 0) continue;

        const char *addr_str  = jaddr  ? json_object_get_string(jaddr)  : "";
        const char *class_str = jclass ? json_object_get_string(jclass) : "";
        const char *title_str = jtitle ? json_object_get_string(jtitle) : "";

        /* Skip clients with empty class */
        if (!class_str[0]) continue;

        DockClient *c = &s->clients[s->client_count];
        c->addr         = strdup(addr_str);
        c->class_name   = strdup(class_str);
        c->title        = strdup(title_str);
        c->icon         = icons_get_name(class_str);
        c->workspace_id = ws_id;
        c->is_active    = false;
        c->is_floating  = jfloat ? json_object_get_boolean(jfloat) : false;
        c->is_fullscreen = jfs   ? json_object_get_boolean(jfs)   : false;
        s->client_count++;
    }
    json_object_put(jarr);

    /* Query active window */
    struct json_object *jaw = hypr_ipc_query_activewindow();
    if (jaw) {
        struct json_object *jaddr;
        if (json_object_object_get_ex(jaw, "address", &jaddr)) {
            free(s->active_addr);
            s->active_addr = strdup(json_object_get_string(jaddr));
        }
        json_object_put(jaw);
    }

    /* Mark the active client */
    for (int i = 0; i < s->client_count; i++) {
        s->clients[i].is_active =
            (s->active_addr && strcasecmp(s->clients[i].addr, s->active_addr) == 0);
    }

    /* Query monitors for active workspace/monitor */
    struct json_object *jmons = hypr_ipc_query_monitors();
    if (jmons) {
        int nm = json_object_array_length(jmons);
        for (int i = 0; i < nm; i++) {
            struct json_object *jm = json_object_array_get_idx(jmons, i);
            struct json_object *jfoc;
            if (json_object_object_get_ex(jm, "focused", &jfoc) &&
                json_object_get_boolean(jfoc)) {

                struct json_object *jname;
                if (json_object_object_get_ex(jm, "name", &jname)) {
                    free(s->active_mon);
                    s->active_mon = strdup(json_object_get_string(jname));
                }

                struct json_object *jaws;
                if (json_object_object_get_ex(jm, "activeWorkspace", &jaws)) {
                    struct json_object *jid;
                    if (json_object_object_get_ex(jaws, "id", &jid))
                        s->active_ws = json_object_get_int(jid);
                }
                break;
            }
        }
        json_object_put(jmons);
    }

    LOG_INF("Refresh: %d clients, ws=%d, mon=%s",
            s->client_count, s->active_ws,
            s->active_mon ? s->active_mon : "(null)");
    return true;
}

/* ── Incremental event handlers ──────────────────────────────────────── */

bool state_on_openwindow(DockState *s, const char *data)
{
    /* openwindow>>ADDR,WSNAME,CLASS,TITLE — unreliable fields,
     * so do a full refresh.  This is the safest approach. */
    (void)data;
    return state_refresh(s);
}

bool state_on_closewindow(DockState *s, const char *data)
{
    if (!data || !data[0]) return false;

    /* data = ADDR (hex without 0x prefix sometimes) */
    for (int i = 0; i < s->client_count; i++) {
        /* Match end of address (Hyprland sometimes omits 0x prefix) */
        const char *a = s->clients[i].addr;
        if (strcasecmp(a, data) == 0 ||
            (strlen(a) > 2 && strcasecmp(a + 2, data) == 0)) {
            client_clear(&s->clients[i]);
            memmove(&s->clients[i], &s->clients[i+1],
                    (size_t)(s->client_count - i - 1) * sizeof(DockClient));
            s->client_count--;
            return true;
        }
    }
    return false;
}

bool state_on_activewindow(DockState *s, const char *data)
{
    if (!data) return false;

    /* activewindowv2>>ADDR */
    free(s->active_addr);
    if (data[0] == ',') {
        /* Empty active window (no focus) */
        s->active_addr = strdup("");
    } else {
        /* Normalise: ensure 0x prefix */
        if (data[0] != '0' || data[1] != 'x') {
            char buf[64];
            snprintf(buf, sizeof(buf), "0x%s", data);
            s->active_addr = strdup(buf);
        } else {
            s->active_addr = strdup(data);
        }
    }

    /* Update is_active flags */
    for (int i = 0; i < s->client_count; i++) {
        s->clients[i].is_active =
            (s->active_addr[0] &&
             strcasecmp(s->clients[i].addr, s->active_addr) == 0);
    }
    return true;
}

bool state_on_movewindow(DockState *s, const char *data)
{
    /* movewindowv2>>ADDR,WSID,WSNAME */
    if (!data) return false;

    char addr[64] = "";
    int ws_id = 0;

    const char *c1 = strchr(data, ',');
    if (!c1) return false;

    size_t alen = (size_t)(c1 - data);
    if (alen >= sizeof(addr)) alen = sizeof(addr) - 1;
    memcpy(addr, data, alen);
    addr[alen] = '\0';

    ws_id = atoi(c1 + 1);

    for (int i = 0; i < s->client_count; i++) {
        if (strcasecmp(s->clients[i].addr, addr) == 0 ||
            (strlen(s->clients[i].addr) > 2 &&
             strcasecmp(s->clients[i].addr + 2, addr) == 0)) {
            s->clients[i].workspace_id = ws_id;
            return true;
        }
    }
    return false;
}

bool state_on_workspace(DockState *s, const char *data)
{
    /* workspacev2>>WSID,WSNAME */
    if (!data) return false;
    int ws = atoi(data);
    if (ws == s->active_ws) return false;
    s->active_ws = ws;
    return true;
}

bool state_on_floating(DockState *s, const char *data)
{
    /* changefloatingmode>>ADDR,0/1 */
    if (!data) return false;

    const char *comma = strchr(data, ',');
    if (!comma) return false;

    char addr[64];
    size_t alen = (size_t)(comma - data);
    if (alen >= sizeof(addr)) alen = sizeof(addr) - 1;
    memcpy(addr, data, alen);
    addr[alen] = '\0';

    bool floating = (comma[1] == '1');

    for (int i = 0; i < s->client_count; i++) {
        if (strcasecmp(s->clients[i].addr, addr) == 0 ||
            (strlen(s->clients[i].addr) > 2 &&
             strcasecmp(s->clients[i].addr + 2, addr) == 0)) {
            s->clients[i].is_floating = floating;
            return true;
        }
    }
    return false;
}

bool state_on_fullscreen(DockState *s, const char *data)
{
    /* fullscreen>>0/1 — applies to the currently active window */
    (void)data;
    return state_refresh(s); /* safest: full refresh */
}

bool state_on_focusedmon(DockState *s, const char *data)
{
    /* focusedmon>>MONITOR,WSNAME */
    if (!data) return false;

    const char *comma = strchr(data, ',');
    size_t mlen;
    if (comma)
        mlen = (size_t)(comma - data);
    else
        mlen = strlen(data);

    char mon[64];
    if (mlen >= sizeof(mon)) mlen = sizeof(mon) - 1;
    memcpy(mon, data, mlen);
    mon[mlen] = '\0';

    if (s->active_mon && strcmp(s->active_mon, mon) == 0) return false;

    free(s->active_mon);
    s->active_mon = strdup(mon);
    return true;
}

/* ── Query helpers ───────────────────────────────────────────────────── */

int state_instance_count(const DockState *s, const char *cls)
{
    if (!cls) return 0;
    int n = 0;
    for (int i = 0; i < s->client_count; i++) {
        if (strcasecmp(s->clients[i].class_name, cls) == 0) n++;
    }
    return n;
}

bool state_is_class_active(const DockState *s, const char *cls)
{
    if (!cls) return false;
    for (int i = 0; i < s->client_count; i++) {
        if (s->clients[i].is_active &&
            strcasecmp(s->clients[i].class_name, cls) == 0)
            return true;
    }
    return false;
}

DockClient *state_first_instance(const DockState *s, const char *cls)
{
    if (!cls) return NULL;
    for (int i = 0; i < s->client_count; i++) {
        if (strcasecmp(s->clients[i].class_name, cls) == 0)
            return &s->clients[i];
    }
    return NULL;
}
