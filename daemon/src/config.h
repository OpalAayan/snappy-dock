/* snappydock-d  —  config.h
 *
 * Runtime configuration.  Three-tier priority (lowest → highest):
 *   1. Compiled-in defaults
 *   2. INI file:  ~/.config/snappy-dock/config.ini
 *   3. CLI flags
 *
 * Thread safety:  config_parse() must be called once from main()
 * before any other thread.  config_get() is read-only thereafter.
 */
#ifndef SNAPPY_CONFIG_H
#define SNAPPY_CONFIG_H

#include <stdbool.h>

/* ── Configuration data ──────────────────────────────────────────────── */

typedef struct {
    /* Layout */
    char *position;         /* "bottom" | "top" | "left" | "right"       */
    char *alignment;        /* "center" | "start" | "end"                */
    int   icon_size;        /* px, default 48                            */
    char *icon_theme;       /* Qt icon theme name, empty = system default */
    char *icon_fallback;    /* fallback icon name                         */
    char *layer;            /* wlr-layer-shell layer, default "top"      */
    bool  full_width;       /* stretch dock to screen edge               */
    int   exclusive_zone;   /* 0=off, -1=auto, >0=fixed px               */

    /* Margins (px) */
    int   margin_top;
    int   margin_bottom;
    int   margin_left;
    int   margin_right;

    /* Behaviour */
    bool  autohide;
    char *launcher_cmd;     /* e.g. "fuzzel", "rofi -show drun"          */
    char *launcher_pos;     /* "start" | "end" | "none"                  */
    int   workspace_count;  /* right-click "Send to WS" submenu count    */
    int   hotspot_delay;    /* auto-hide velocity filter (ms), 0=instant */
} DockConfig;

/* ── API ─────────────────────────────────────────────────────────────── */

/*
 * Load config from INI file, then override with CLI flags.
 * Strips consumed flags from *argc / *argv.
 * Must be called exactly once, before any other module init.
 */
void config_parse(int *argc, char ***argv);

/*
 * Return a read-only pointer to the global config.
 * Valid for the process lifetime after config_parse().
 */
const DockConfig *config_get(void);

/*
 * Release all heap memory owned by the config.
 * Call once at shutdown.
 */
void config_free(void);

#endif /* SNAPPY_CONFIG_H */
