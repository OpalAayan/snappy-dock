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
    char *launcher_icon;
    int   launcher_icon_size;
    bool  launcher_hover_bg;
    int   launcher_hover_bg_size;
    bool  icon_hover_bg;        /* show hover background on dock icons      */
    char *font_family;
    char *font_weight;
    int   workspace_count;  /* right-click "Send to WS" submenu count    */
    int   hotspot_delay;    /* auto-hide velocity filter (ms), 0=instant */
    char *mode;             /* "static" | "snappy"                        */

    /* Snappy mode tuning */
    int    spread;          /* neighbor influence radius (icon-widths) 1–6 */
    int    icon_spacing;    /* gap between dock items (px), default 2      */
    double magnification;   /* extra scale on hover (0.0–2.0), default 0.78*/
    double rise_spacing;    /* main-axis push factor, snappy only (0.0–2.0)*/

    /* Theme (styling & colors) */
    char *theme_bg;                 /* dock background color hex/rgba */
    char *theme_border_color;       /* dock border color hex/rgba */
    int   theme_border_width;       /* px, default 1 */
    int   theme_radius;             /* px, default 16 */
    char *theme_dot_running;        /* running app indicator color */
    char *theme_dot_active;         /* active app indicator color */
    char *theme_accent;             /* accent color */
    char *theme_text_color;         /* text color */
    char *theme_icon_hover_bg;      /* icon hover background color */
    char *theme_launcher_hover_bg;  /* launcher hover background color */
    char *theme_menu_bg;            /* context menu background */
    char *theme_menu_border;        /* context menu border color */
    char *theme_menu_hover_bg;      /* context menu item hover background */
    char *theme_menu_text_color;    /* context menu text color */
    char *theme_menu_accent;        /* context menu active bar / chevron accent */
    char *theme_menu_separator;     /* context menu separator line color */
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
