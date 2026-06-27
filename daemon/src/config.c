/* snappydock-d  —  config.c
 *
 * Minimal INI parser + CLI argument handler.
 *
 * INI format supported:
 *   [Section]
 *   Key=Value
 *   # comment
 *
 * No multiline values, no escaping, no quoting.  This is intentional —
 * dock config is simple key-value pairs, nothing more.
 */
#define _POSIX_C_SOURCE 200809L

#include "config.h"
#include "log.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

/* ── Global config ───────────────────────────────────────────────────── */

static DockConfig s_cfg;

/* ── Helpers ─────────────────────────────────────────────────────────── */

static char *str_dup(const char *s)
{
    return s ? strdup(s) : NULL;
}

static char *str_trim(char *s)
{
    while (isspace((unsigned char)*s)) s++;
    char *end = s + strlen(s) - 1;
    while (end > s && isspace((unsigned char)*end)) *end-- = '\0';
    return s;
}

static bool str_eq_ci(const char *a, const char *b)
{
    return strcasecmp(a, b) == 0;
}

static bool parse_bool(const char *val)
{
    return str_eq_ci(val, "true") || str_eq_ci(val, "yes") || strcmp(val, "1") == 0;
}

static const char *normal_icon_fallback(const char *val)
{
    if (!val || !*val || str_eq_ci(val, "default"))
        return "application-x-executable";
    return val;
}

/* ── Defaults ────────────────────────────────────────────────────────── */

static void config_set_defaults(DockConfig *cfg)
{
    memset(cfg, 0, sizeof(*cfg));
    cfg->position       = str_dup("bottom");
    cfg->alignment      = str_dup("center");
    cfg->icon_size      = 48;
    cfg->icon_theme     = str_dup("");
    cfg->icon_fallback  = str_dup("application-x-executable");
    cfg->layer          = str_dup("overlay");
    cfg->full_width     = false;
    cfg->exclusive_zone = 0;
    cfg->margin_top     = 0;
    cfg->margin_bottom  = 5;
    cfg->margin_left    = 0;
    cfg->margin_right   = 0;
    cfg->autohide       = false;
    cfg->launcher_cmd   = str_dup("fuzzel");
    cfg->launcher_pos   = str_dup("start");
    cfg->workspace_count = 5;
    cfg->hotspot_delay  = 50;
}

/* ── INI parser ──────────────────────────────────────────────────────── */

static void config_apply_ini_key(DockConfig *cfg, const char *section,
                                 const char *key, const char *val)
{
    if (str_eq_ci(section, "Dock")) {
        if (str_eq_ci(key, "Position")) {
            free(cfg->position);
            cfg->position = str_dup(val);
        } else if (str_eq_ci(key, "Alignment")) {
            free(cfg->alignment);
            cfg->alignment = str_dup(val);
        } else if (str_eq_ci(key, "IconSize")) {
            cfg->icon_size = atoi(val);
        } else if (str_eq_ci(key, "Layer")) {
            free(cfg->layer);
            cfg->layer = str_dup(val);
        } else if (str_eq_ci(key, "FullWidth")) {
            cfg->full_width = parse_bool(val);
        } else if (str_eq_ci(key, "ExclusiveZone")) {
            if (str_eq_ci(val, "auto"))
                cfg->exclusive_zone = -1;
            else if (str_eq_ci(val, "false") || str_eq_ci(val, "off"))
                cfg->exclusive_zone = 0;
            else
                cfg->exclusive_zone = atoi(val);
        } else if (str_eq_ci(key, "AutoHide")) {
            cfg->autohide = parse_bool(val);
        } else if (str_eq_ci(key, "LauncherCmd")) {
            free(cfg->launcher_cmd);
            cfg->launcher_cmd = str_dup(val);
        } else if (str_eq_ci(key, "LauncherPos")) {
            free(cfg->launcher_pos);
            cfg->launcher_pos = str_dup(val);
        } else if (str_eq_ci(key, "WorkspaceCount")) {
            cfg->workspace_count = atoi(val);
        } else if (str_eq_ci(key, "HotspotDelay")) {
            cfg->hotspot_delay = atoi(val);
        }
    } else if (str_eq_ci(section, "Margins")) {
        if (str_eq_ci(key, "Top"))         cfg->margin_top    = atoi(val);
        else if (str_eq_ci(key, "Bottom")) cfg->margin_bottom = atoi(val);
        else if (str_eq_ci(key, "Left"))   cfg->margin_left   = atoi(val);
        else if (str_eq_ci(key, "Right"))  cfg->margin_right  = atoi(val);
    } else if (str_eq_ci(section, "Icons")) {
        if (str_eq_ci(key, "IconSize")) {
            cfg->icon_size = atoi(val);
        } else if (str_eq_ci(key, "Theme") || str_eq_ci(key, "IconTheme")) {
            free(cfg->icon_theme);
            cfg->icon_theme = str_dup(val);
        } else if (str_eq_ci(key, "Fallback") || str_eq_ci(key, "FallbackIcon")) {
            free(cfg->icon_fallback);
            cfg->icon_fallback = str_dup(normal_icon_fallback(val));
        }
    }
}

static void config_load_ini(DockConfig *cfg, const char *path)
{
    FILE *f = fopen(path, "r");
    if (!f) return;

    LOG_INF("Loading config: %s", path);

    char line[512];
    char section[64] = "";

    while (fgets(line, sizeof(line), f)) {
        char *s = str_trim(line);

        /* Skip blanks and comments */
        if (*s == '\0' || *s == '#' || *s == ';') continue;

        /* Section header */
        if (*s == '[') {
            char *end = strchr(s, ']');
            if (end) {
                *end = '\0';
                snprintf(section, sizeof(section), "%s", s + 1);
            }
            continue;
        }

        /* Key=Value */
        char *eq = strchr(s, '=');
        if (!eq) continue;

        *eq = '\0';
        char *key = str_trim(s);
        char *val = str_trim(eq + 1);

        config_apply_ini_key(cfg, section, key, val);
    }

    fclose(f);
}

/* ── CLI argument parser ─────────────────────────────────────────────── */

static void config_parse_cli(DockConfig *cfg, int *argc, char ***argv)
{
    int out = 1; /* write index for surviving args */

    for (int i = 1; i < *argc; i++) {
        char *arg = (*argv)[i];
        char *next = (i + 1 < *argc) ? (*argv)[i + 1] : NULL;

        if (strcmp(arg, "-p") == 0 && next) {
            free(cfg->position);
            cfg->position = str_dup(next);
            i++;
        } else if (strcmp(arg, "-i") == 0 && next) {
            cfg->icon_size = atoi(next);
            i++;
        } else if (strcmp(arg, "-d") == 0) {
            cfg->autohide = true;
        } else if (strcmp(arg, "-l") == 0 && next) {
            free(cfg->layer);
            cfg->layer = str_dup(next);
            i++;
        } else if (strcmp(arg, "-c") == 0 && next) {
            free(cfg->launcher_cmd);
            cfg->launcher_cmd = str_dup(next);
            i++;
        } else {
            /* Keep unrecognised args */
            (*argv)[out++] = arg;
        }
    }

    *argc = out;
}

/* ── Public API ──────────────────────────────────────────────────────── */

void config_parse(int *argc, char ***argv)
{
    config_set_defaults(&s_cfg);

    /* Try user config, then system fallback */
    char path[512];
    const char *home = getenv("HOME");
    const char *xdg  = getenv("XDG_CONFIG_HOME");

    if (xdg && *xdg) {
        snprintf(path, sizeof(path), "%s/snappy-dock/config.ini", xdg);
    } else if (home) {
        snprintf(path, sizeof(path), "%s/.config/snappy-dock/config.ini", home);
    } else {
        path[0] = '\0';
    }

    if (path[0]) config_load_ini(&s_cfg, path);

    if (argc && argv)
        config_parse_cli(&s_cfg, argc, argv);
}

const DockConfig *config_get(void)
{
    return &s_cfg;
}

void config_free(void)
{
    free(s_cfg.position);
    free(s_cfg.alignment);
    free(s_cfg.icon_theme);
    free(s_cfg.icon_fallback);
    free(s_cfg.layer);
    free(s_cfg.launcher_cmd);
    free(s_cfg.launcher_pos);
    memset(&s_cfg, 0, sizeof(s_cfg));
}
