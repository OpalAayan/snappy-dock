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
#include "config_internal.h"
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

static double parse_double(const char *val, double fallback)
{
    if (!val || !*val) return fallback;
    char *end;
    double d = strtod(val, &end);
    return (end != val) ? d : fallback;
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
    cfg->launcher_icon  = str_dup("dots");
    cfg->launcher_icon_size = 0;
    cfg->launcher_hover_bg = true;
    cfg->launcher_hover_bg_size = 0;
    cfg->icon_hover_bg = true;
    cfg->font_family = str_dup("Sans");
    cfg->font_weight = str_dup("Bold");
    cfg->workspace_count = 5;
    cfg->hotspot_delay  = 300;
    cfg->mode           = str_dup("static");
    cfg->spread         = 3;
    cfg->icon_spacing   = 2;
    cfg->magnification  = 0.78;
    cfg->rise_spacing    = 0.5;
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
        } else if (str_eq_ci(key, "LauncherIcon")) {
            free(cfg->launcher_icon);
            cfg->launcher_icon = str_dup(val);
        } else if (str_eq_ci(key, "LauncherIconSize")) {
            cfg->launcher_icon_size = atoi(val);
        } else if (str_eq_ci(key, "LauncherHoverBg")) {
            cfg->launcher_hover_bg = parse_bool(val);
        } else if (str_eq_ci(key, "LauncherHoverBgSize")) {
            cfg->launcher_hover_bg_size = atoi(val);
        } else if (str_eq_ci(key, "IconHoverBg")) {
            cfg->icon_hover_bg = parse_bool(val);
        } else if (str_eq_ci(key, "WorkspaceCount")) {
            cfg->workspace_count = atoi(val);
        } else if (str_eq_ci(key, "HotspotDelay")) {
            cfg->hotspot_delay = atoi(val);
        } else if (str_eq_ci(key, "Mode")) {
            free(cfg->mode);
            cfg->mode = str_dup(val);
        } else if (str_eq_ci(key, "Spread")) {
            cfg->spread = atoi(val);
            if (cfg->spread < 1) cfg->spread = 1;
            if (cfg->spread > 6) cfg->spread = 6;
        } else if (str_eq_ci(key, "IconSpacing")) {
            cfg->icon_spacing = atoi(val);
            if (cfg->icon_spacing < 0) cfg->icon_spacing = 0;
        } else if (str_eq_ci(key, "Magnification")) {
            cfg->magnification = parse_double(val, 0.78);
            if (cfg->magnification < 0.0) cfg->magnification = 0.0;
            if (cfg->magnification > 2.0) cfg->magnification = 2.0;
        } else if (str_eq_ci(key, "RiseSpacing")) {
            cfg->rise_spacing = parse_double(val, 0.5);
            if (cfg->rise_spacing < 0.0) cfg->rise_spacing = 0.0;
            if (cfg->rise_spacing > 2.0) cfg->rise_spacing = 2.0;
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
    } else if (str_eq_ci(section, "Font")) {
        if (str_eq_ci(key, "Family")) {
            free(cfg->font_family);
            cfg->font_family = str_dup(val);
        } else if (str_eq_ci(key, "Weight")) {
            free(cfg->font_weight);
            cfg->font_weight = str_dup(val);
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

/* ── CLI argument parser (reserved for future use) ───────────────────── */

static void config_parse_cli(DockConfig *cfg, int *argc, char ***argv)
{
    (void)cfg;
    (void)argc;
    (void)argv;
    /* All configuration is handled via config.ini.
     * This function is retained for potential future CLI flags. */
}

/* ── Validation ──────────────────────────────────────────────────────── */

/*
 * Generic enum-string validator.
 * Lowercases `*field` in-place, checks against a NULL-terminated
 * list of allowed values.  On mismatch → warn + replace with fallback.
 */
static void validate_enum(char **field, const char *key,
                          const char *const *allowed, const char *fallback)
{
    if (!*field || !(*field)[0]) {
        free(*field);
        *field = strdup(fallback);
        return;
    }

    /* Lowercase in-place */
    for (char *p = *field; *p; p++)
        *p = (char)tolower((unsigned char)*p);

    for (const char *const *a = allowed; *a; a++) {
        if (strcmp(*field, *a) == 0)
            return;   /* valid */
    }

    /* Build "val1, val2, val3" string for the warning */
    char expected[256] = "";
    for (const char *const *a = allowed; *a; a++) {
        if (expected[0]) strncat(expected, ", ", sizeof(expected) - strlen(expected) - 1);
        strncat(expected, *a, sizeof(expected) - strlen(expected) - 1);
    }

    LOG_WRN("Invalid %s='%s' (expected: %s), falling back to '%s'",
            key, *field, expected, fallback);
    free(*field);
    *field = strdup(fallback);
}

/*
 * Validate and clamp a numeric field to [lo, hi].
 */
static void validate_int_range(int *field, const char *key, int lo, int hi, int fallback)
{
    if (*field < lo || *field > hi) {
        LOG_WRN("Invalid %s=%d (expected: %d–%d), falling back to %d",
                key, *field, lo, hi, fallback);
        *field = fallback;
    }
}

static void config_validate(DockConfig *cfg)
{
    static const char *const positions[]   = {"bottom", "top", "left", "right", NULL};
    static const char *const alignments[]  = {"center", "start", "end", NULL};
    static const char *const layers[]      = {"background", "bottom", "top", "overlay", NULL};
    static const char *const launcher_pos[]= {"start", "end", "none", NULL};
    static const char *const modes[]       = {"static", "snappy", NULL};

    validate_enum(&cfg->position,     "Position",    positions,    "bottom");
    validate_enum(&cfg->alignment,    "Alignment",   alignments,   "center");
    validate_enum(&cfg->layer,        "Layer",       layers,       "top");
    validate_enum(&cfg->launcher_pos, "LauncherPos", launcher_pos, "start");
    validate_enum(&cfg->mode,         "Mode",        modes,        "static");

    validate_int_range(&cfg->icon_size,        "IconSize",       8, 256, 48);
    validate_int_range(&cfg->workspace_count,  "WorkspaceCount", 1, 20,  5);
    validate_int_range(&cfg->hotspot_delay,    "HotspotDelay",   0, 5000, 300);
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

    /* Post-parse validation */
    config_validate(&s_cfg);
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
    free(s_cfg.launcher_icon);
    free(s_cfg.font_family);
    free(s_cfg.font_weight);
    free(s_cfg.mode);
    memset(&s_cfg, 0, sizeof(s_cfg));
}

/* ── Test-facing wrappers (see config_internal.h) ────────────────────── */

void config_free_fields(DockConfig *cfg)
{
    free(cfg->position);
    free(cfg->alignment);
    free(cfg->icon_theme);
    free(cfg->icon_fallback);
    free(cfg->layer);
    free(cfg->launcher_cmd);
    free(cfg->launcher_pos);
    free(cfg->launcher_icon);
    free(cfg->font_family);
    free(cfg->font_weight);
    free(cfg->mode);
    memset(cfg, 0, sizeof(*cfg));
}

void config_set_defaults_for_test(DockConfig *cfg)
{
    config_set_defaults(cfg);
}

void config_apply_ini_key_for_test(DockConfig *cfg, const char *section,
                                   const char *key, const char *val)
{
    config_apply_ini_key(cfg, section, key, val);
}

void config_validate_mode_for_test(DockConfig *cfg)
{
    config_validate(cfg);
}
