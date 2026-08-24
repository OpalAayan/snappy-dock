/* snappydock-d  —  protocol.c
 *
 * JSON-lines protocol encoding (stdout) and command parsing (stdin).
 *
 * Outbound:  Each message is a single JSON object on one line,
 *            terminated by '\n'.  stdout is set to line-buffered
 *            in main.c so each printf+\n flushes immediately.
 *
 * Inbound:   Non-blocking read from stdin, one JSON object per line.
 */
#define _POSIX_C_SOURCE 200809L

#include "protocol.h"
#include "log.h"

#include <json-c/json.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* ── Stdin line buffer ───────────────────────────────────────────────── */

static char s_stdin_buf[4096];
static int  s_stdin_len = 0;

/* ── Outbound: config ────────────────────────────────────────────────── */

void protocol_emit_config(const DockConfig *cfg)
{
    struct json_object *obj = json_object_new_object();

    json_object_object_add(obj, "type",
        json_object_new_string("config"));
    json_object_object_add(obj, "position",
        json_object_new_string(cfg->position ? cfg->position : "bottom"));
    json_object_object_add(obj, "alignment",
        json_object_new_string(cfg->alignment ? cfg->alignment : "center"));
    json_object_object_add(obj, "icon_size",
        json_object_new_int(cfg->icon_size));
    json_object_object_add(obj, "icon_theme",
        json_object_new_string(cfg->icon_theme ? cfg->icon_theme : ""));
    json_object_object_add(obj, "icon_fallback",
        json_object_new_string(cfg->icon_fallback ? cfg->icon_fallback : "application-x-executable"));
    json_object_object_add(obj, "layer",
        json_object_new_string(cfg->layer ? cfg->layer : "top"));
    json_object_object_add(obj, "full_width",
        json_object_new_boolean(cfg->full_width));
    json_object_object_add(obj, "exclusive_zone",
        json_object_new_int(cfg->exclusive_zone));
    json_object_object_add(obj, "autohide",
        json_object_new_boolean(cfg->autohide));
    json_object_object_add(obj, "launcher_cmd",
        json_object_new_string(cfg->launcher_cmd ? cfg->launcher_cmd : ""));
    json_object_object_add(obj, "launcher_pos",
        json_object_new_string(cfg->launcher_pos ? cfg->launcher_pos : "start"));
    json_object_object_add(obj, "launcher_icon",
        json_object_new_string(cfg->launcher_icon ? cfg->launcher_icon : "dots"));
    json_object_object_add(obj, "launcher_icon_size",
        json_object_new_int(cfg->launcher_icon_size));
    json_object_object_add(obj, "launcher_hover_bg",
        json_object_new_boolean(cfg->launcher_hover_bg));
    json_object_object_add(obj, "launcher_hover_bg_size",
        json_object_new_int(cfg->launcher_hover_bg_size));
    json_object_object_add(obj, "icon_hover_bg",
        json_object_new_boolean(cfg->icon_hover_bg));
    json_object_object_add(obj, "font_family",
        json_object_new_string(cfg->font_family ? cfg->font_family : "FiraCode Nerd Font"));
    json_object_object_add(obj, "font_weight",
        json_object_new_string(cfg->font_weight ? cfg->font_weight : "Bold"));
    json_object_object_add(obj, "workspace_count",
        json_object_new_int(cfg->workspace_count));
    json_object_object_add(obj, "margin_top",
        json_object_new_int(cfg->margin_top));
    json_object_object_add(obj, "margin_bottom",
        json_object_new_int(cfg->margin_bottom));
    json_object_object_add(obj, "margin_left",
        json_object_new_int(cfg->margin_left));
    json_object_object_add(obj, "margin_right",
        json_object_new_int(cfg->margin_right));
    json_object_object_add(obj, "hotspot_delay",
        json_object_new_int(cfg->hotspot_delay));
    json_object_object_add(obj, "mode",
        json_object_new_string(cfg->mode ? cfg->mode : "static"));
    json_object_object_add(obj, "spread",
        json_object_new_int(cfg->spread));
    json_object_object_add(obj, "icon_spacing",
        json_object_new_int(cfg->icon_spacing));
    json_object_object_add(obj, "magnification",
        json_object_new_double(cfg->magnification));
    json_object_object_add(obj, "rise_spacing",
        json_object_new_double(cfg->rise_spacing));
    json_object_object_add(obj, "theme_bg",
        json_object_new_string(cfg->theme_bg ? cfg->theme_bg : ""));
    json_object_object_add(obj, "theme_border_color",
        json_object_new_string(cfg->theme_border_color ? cfg->theme_border_color : ""));
    json_object_object_add(obj, "theme_border_width",
        json_object_new_int(cfg->theme_border_width));
    json_object_object_add(obj, "theme_radius",
        json_object_new_int(cfg->theme_radius));
    json_object_object_add(obj, "theme_dot_running",
        json_object_new_string(cfg->theme_dot_running ? cfg->theme_dot_running : ""));
    json_object_object_add(obj, "theme_dot_active",
        json_object_new_string(cfg->theme_dot_active ? cfg->theme_dot_active : ""));
    json_object_object_add(obj, "theme_accent",
        json_object_new_string(cfg->theme_accent ? cfg->theme_accent : ""));
    json_object_object_add(obj, "theme_text_color",
        json_object_new_string(cfg->theme_text_color ? cfg->theme_text_color : ""));
    json_object_object_add(obj, "theme_icon_hover_bg",
        json_object_new_string(cfg->theme_icon_hover_bg ? cfg->theme_icon_hover_bg : ""));
    json_object_object_add(obj, "theme_launcher_hover_bg",
        json_object_new_string(cfg->theme_launcher_hover_bg ? cfg->theme_launcher_hover_bg : ""));
    json_object_object_add(obj, "theme_menu_bg",
        json_object_new_string(cfg->theme_menu_bg ? cfg->theme_menu_bg : ""));
    json_object_object_add(obj, "theme_menu_border",
        json_object_new_string(cfg->theme_menu_border ? cfg->theme_menu_border : ""));
    json_object_object_add(obj, "theme_menu_hover_bg",
        json_object_new_string(cfg->theme_menu_hover_bg ? cfg->theme_menu_hover_bg : ""));
    json_object_object_add(obj, "theme_menu_text_color",
        json_object_new_string(cfg->theme_menu_text_color ? cfg->theme_menu_text_color : ""));
    json_object_object_add(obj, "theme_menu_accent",
        json_object_new_string(cfg->theme_menu_accent ? cfg->theme_menu_accent : ""));
    json_object_object_add(obj, "theme_menu_separator",
        json_object_new_string(cfg->theme_menu_separator ? cfg->theme_menu_separator : ""));

    const char *str = json_object_to_json_string_ext(obj,
        JSON_C_TO_STRING_PLAIN);
    printf("%s\n", str);
    fflush(stdout);
    json_object_put(obj);
}

/* ── Outbound: state ─────────────────────────────────────────────────── */

void protocol_emit_state(const DockState *s)
{
    struct json_object *obj = json_object_new_object();
    json_object_object_add(obj, "type", json_object_new_string("state"));

    /* Clients array */
    struct json_object *clients = json_object_new_array();
    for (int i = 0; i < s->client_count; i++) {
        const DockClient *c = &s->clients[i];
        struct json_object *jc = json_object_new_object();

        json_object_object_add(jc, "addr",
            json_object_new_string(c->addr ? c->addr : ""));
        json_object_object_add(jc, "class",
            json_object_new_string(c->class_name ? c->class_name : ""));
        json_object_object_add(jc, "title",
            json_object_new_string(c->title ? c->title : ""));
        json_object_object_add(jc, "icon",
            json_object_new_string(c->icon ? c->icon : ""));
        json_object_object_add(jc, "ws",
            json_object_new_int(c->workspace_id));
        json_object_object_add(jc, "active",
            json_object_new_boolean(c->is_active));
        json_object_object_add(jc, "floating",
            json_object_new_boolean(c->is_floating));
        json_object_object_add(jc, "fullscreen",
            json_object_new_boolean(c->is_fullscreen));

        json_object_array_add(clients, jc);
    }
    json_object_object_add(obj, "clients", clients);

    /* Pinned array */
    struct json_object *pinned = json_object_new_array();
    for (int i = 0; i < s->pinned_count; i++) {
        struct json_object *jp = json_object_new_object();
        json_object_object_add(jp, "class",
            json_object_new_string(s->pinned[i].class_name ? s->pinned[i].class_name : ""));
        json_object_object_add(jp, "icon",
            json_object_new_string(s->pinned[i].icon ? s->pinned[i].icon : ""));
        json_object_array_add(pinned, jp);
    }
    json_object_object_add(obj, "pinned", pinned);

    /* Focus state */
    json_object_object_add(obj, "active_ws",
        json_object_new_int(s->active_ws));
    json_object_object_add(obj, "active_addr",
        json_object_new_string(s->active_addr ? s->active_addr : ""));
    json_object_object_add(obj, "active_mon",
        json_object_new_string(s->active_mon ? s->active_mon : ""));

    const char *str = json_object_to_json_string_ext(obj,
        JSON_C_TO_STRING_PLAIN);
    printf("%s\n", str);
    fflush(stdout);
    json_object_put(obj);
}

/* ── Inbound: command parsing ────────────────────────────────────────── */

bool protocol_read_cmd(ProtocolCmd *out)
{
    if (!out) return false;
    memset(out, 0, sizeof(*out));

    /* Non-blocking read from stdin */
    int space = (int)sizeof(s_stdin_buf) - s_stdin_len - 1;
    if (space <= 0) {
        LOG_WRN("Stdin buffer overflow, discarding");
        s_stdin_len = 0;
        space = (int)sizeof(s_stdin_buf) - 1;
    }

    ssize_t n = read(STDIN_FILENO, s_stdin_buf + s_stdin_len, (size_t)space);
    if (n > 0) {
        s_stdin_len += (int)n;
        s_stdin_buf[s_stdin_len] = '\0';
    } else if (n == 0) {
        /* EOF on stdin — QML closed the pipe */
        return false;
    } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
        return false;
    }

    /* Find a complete line */
    char *nl = memchr(s_stdin_buf, '\n', (size_t)s_stdin_len);
    if (!nl) return false;

    *nl = '\0';
    char *line = s_stdin_buf;

    /* Parse JSON */
    struct json_object *obj = json_tokener_parse(line);

    /* Compact buffer — move remaining data to front */
    int consumed = (int)(nl - s_stdin_buf) + 1;
    int remaining = s_stdin_len - consumed;
    if (remaining > 0)
        memmove(s_stdin_buf, nl + 1, (size_t)remaining);
    s_stdin_len = remaining;

    if (!obj) {
        LOG_WRN("Invalid JSON command: %.80s", line);
        return false;
    }

    /* Extract fields */
    struct json_object *jval;
    if (json_object_object_get_ex(obj, "cmd", &jval))
        snprintf(out->cmd, sizeof(out->cmd), "%s",
                 json_object_get_string(jval));
    if (json_object_object_get_ex(obj, "addr", &jval))
        snprintf(out->addr, sizeof(out->addr), "%s",
                 json_object_get_string(jval));
    if (json_object_object_get_ex(obj, "class", &jval))
        snprintf(out->class_name, sizeof(out->class_name), "%s",
                 json_object_get_string(jval));
    if (json_object_object_get_ex(obj, "arg", &jval))
        snprintf(out->arg, sizeof(out->arg), "%s",
                 json_object_get_string(jval));
    if (json_object_object_get_ex(obj, "ws", &jval))
        out->ws = json_object_get_int(jval);

    json_object_put(obj);
    return (out->cmd[0] != '\0');
}
