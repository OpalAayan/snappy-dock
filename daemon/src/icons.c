/* snappydock-d  —  icons.c
 *
 * XDG icon name resolver.  Searches .desktop files across standard
 * directories to map window class names → icon names.
 *
 * The cache is a flat array of (class, icon) pairs.  For a dock with
 * ~20 entries, linear scan is faster than any hash table due to cache
 * locality.
 */
#define _POSIX_C_SOURCE 200809L

#include "icons.h"
#include "log.h"

#include <ctype.h>
#include <dirent.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

/* ── Constants ───────────────────────────────────────────────────────── */

#define FALLBACK_ICON   "application-x-executable"
#define MAX_DIRS        16
#define MAX_CACHE       128

/* ── Internal data ───────────────────────────────────────────────────── */

typedef struct {
    char *class_name;
    char *icon_name;
} CacheEntry;

static char       *s_dirs[MAX_DIRS];
static int         s_dir_count = 0;

static CacheEntry  s_cache[MAX_CACHE];
static int         s_cache_count = 0;

/* ── Helpers ─────────────────────────────────────────────────────────── */

static void str_lower(char *s)
{
    for (; *s; s++) *s = (char)tolower((unsigned char)*s);
}

/*
 * Extract a key's value from a .desktop file.
 * Only reads lines in the [Desktop Entry] section.
 * Returns strdup'd value, or NULL.  Caller frees.
 */
static char *desktop_get_key(const char *path, const char *key)
{
    FILE *f = fopen(path, "r");
    if (!f) return NULL;

    char line[1024];
    bool in_section = false;
    size_t klen = strlen(key);

    while (fgets(line, sizeof(line), f)) {
        /* Trim trailing whitespace/newline */
        size_t len = strlen(line);
        while (len > 0 && (line[len-1] == '\n' || line[len-1] == '\r' ||
                           line[len-1] == ' '  || line[len-1] == '\t'))
            line[--len] = '\0';

        if (line[0] == '[') {
            in_section = (strncmp(line, "[Desktop Entry]", 15) == 0);
            continue;
        }
        if (!in_section) continue;

        if (strncmp(line, key, klen) == 0 && line[klen] == '=') {
            fclose(f);
            return strdup(line + klen + 1);
        }
    }

    fclose(f);
    return NULL;
}

/*
 * Try to find a .desktop file at path and extract Icon=.
 * Returns strdup'd icon name, or NULL.
 */
static char *try_desktop_icon(const char *path)
{
    char *icon = desktop_get_key(path, "Icon");
    if (icon && icon[0] != '\0') return icon;
    free(icon);
    return NULL;
}

/* ── Search strategies ───────────────────────────────────────────────── */

/* Strategy 1: Exact filename match  <class>.desktop */
static char *search_exact(const char *class_name)
{
    char path[512];
    for (int i = 0; i < s_dir_count; i++) {
        snprintf(path, sizeof(path), "%s/%s.desktop", s_dirs[i], class_name);
        char *icon = try_desktop_icon(path);
        if (icon) return icon;
    }
    return NULL;
}

/* Strategy 2: Lowercase  <lower(class)>.desktop */
static char *search_lower(const char *class_name)
{
    char lower[256];
    snprintf(lower, sizeof(lower), "%s", class_name);
    str_lower(lower);

    char path[512];
    for (int i = 0; i < s_dir_count; i++) {
        snprintf(path, sizeof(path), "%s/%s.desktop", s_dirs[i], lower);
        char *icon = try_desktop_icon(path);
        if (icon) return icon;
    }
    return NULL;
}

/* Strategy 3: Reverse-domain  org.foo.Bar → bar.desktop */
static char *search_reverse_domain(const char *class_name)
{
    const char *last_dot = strrchr(class_name, '.');
    if (!last_dot) return NULL;

    char tail[256];
    snprintf(tail, sizeof(tail), "%s", last_dot + 1);
    str_lower(tail);

    char path[512];
    for (int i = 0; i < s_dir_count; i++) {
        snprintf(path, sizeof(path), "%s/%s.desktop", s_dirs[i], tail);
        char *icon = try_desktop_icon(path);
        if (icon) return icon;

        /* Also try the full reverse-domain as filename */
        char lower[256];
        snprintf(lower, sizeof(lower), "%s", class_name);
        str_lower(lower);
        snprintf(path, sizeof(path), "%s/%s.desktop", s_dirs[i], lower);
        icon = try_desktop_icon(path);
        if (icon) return icon;
    }
    return NULL;
}

/* Strategy 4: Directory scan — case-insensitive substring */
static char *search_scan(const char *class_name)
{
    char lower_class[256];
    snprintf(lower_class, sizeof(lower_class), "%s", class_name);
    str_lower(lower_class);

    char path[512];
    for (int i = 0; i < s_dir_count; i++) {
        DIR *d = opendir(s_dirs[i]);
        if (!d) continue;

        struct dirent *ent;
        while ((ent = readdir(d)) != NULL) {
            size_t nlen = strlen(ent->d_name);
            if (nlen < 9) continue; /* minimum: "x.desktop" */
            if (strcasecmp(ent->d_name + nlen - 8, ".desktop") != 0)
                continue;

            char lower_name[256];
            snprintf(lower_name, sizeof(lower_name), "%s", ent->d_name);
            str_lower(lower_name);

            if (strstr(lower_name, lower_class)) {
                snprintf(path, sizeof(path), "%s/%s", s_dirs[i], ent->d_name);
                char *icon = try_desktop_icon(path);
                if (icon) { closedir(d); return icon; }
            }
        }
        closedir(d);
    }
    return NULL;
}

/* Strategy 5: StartupWMClass= match */
static char *search_wmclass(const char *class_name)
{
    char path[512];
    for (int i = 0; i < s_dir_count; i++) {
        DIR *d = opendir(s_dirs[i]);
        if (!d) continue;

        struct dirent *ent;
        while ((ent = readdir(d)) != NULL) {
            size_t nlen = strlen(ent->d_name);
            if (nlen < 9) continue;
            if (strcasecmp(ent->d_name + nlen - 8, ".desktop") != 0)
                continue;

            snprintf(path, sizeof(path), "%s/%s", s_dirs[i], ent->d_name);
            char *wmc = desktop_get_key(path, "StartupWMClass");
            if (wmc && strcasecmp(wmc, class_name) == 0) {
                free(wmc);
                char *icon = try_desktop_icon(path);
                if (icon) { closedir(d); return icon; }
            }
            free(wmc);
        }
        closedir(d);
    }
    return NULL;
}

/* ── Full-path .desktop search (for launcher module) ─────────────────── */

char *icons_find_desktop(const char *class_name)
{
    if (!class_name || !class_name[0]) return NULL;

    char path[512];

    /* Strategy 1: exact */
    for (int i = 0; i < s_dir_count; i++) {
        snprintf(path, sizeof(path), "%s/%s.desktop", s_dirs[i], class_name);
        if (access(path, F_OK) == 0) return strdup(path);
    }

    /* Strategy 2: lowercase */
    char lower[256];
    snprintf(lower, sizeof(lower), "%s", class_name);
    str_lower(lower);
    for (int i = 0; i < s_dir_count; i++) {
        snprintf(path, sizeof(path), "%s/%s.desktop", s_dirs[i], lower);
        if (access(path, F_OK) == 0) return strdup(path);
    }

    /* Strategy 4: scan for substring */
    char lower_class[256];
    snprintf(lower_class, sizeof(lower_class), "%s", class_name);
    str_lower(lower_class);
    for (int i = 0; i < s_dir_count; i++) {
        DIR *d = opendir(s_dirs[i]);
        if (!d) continue;
        struct dirent *ent;
        while ((ent = readdir(d)) != NULL) {
            char lower_name[256];
            snprintf(lower_name, sizeof(lower_name), "%s", ent->d_name);
            str_lower(lower_name);
            if (strstr(lower_name, lower_class) &&
                strstr(lower_name, ".desktop")) {
                snprintf(path, sizeof(path), "%s/%s", s_dirs[i], ent->d_name);
                closedir(d);
                return strdup(path);
            }
        }
        closedir(d);
    }

    /* Strategy 5: StartupWMClass */
    for (int i = 0; i < s_dir_count; i++) {
        DIR *d = opendir(s_dirs[i]);
        if (!d) continue;
        struct dirent *ent;
        while ((ent = readdir(d)) != NULL) {
            size_t nlen = strlen(ent->d_name);
            if (nlen < 9) continue;
            if (strcasecmp(ent->d_name + nlen - 8, ".desktop") != 0)
                continue;
            snprintf(path, sizeof(path), "%s/%s", s_dirs[i], ent->d_name);
            char *wmc = desktop_get_key(path, "StartupWMClass");
            if (wmc && strcasecmp(wmc, class_name) == 0) {
                free(wmc);
                closedir(d);
                return strdup(path);
            }
            free(wmc);
        }
        closedir(d);
    }

    return NULL;
}

/* ── Cache ───────────────────────────────────────────────────────────── */

static char *cache_lookup(const char *class_name)
{
    for (int i = 0; i < s_cache_count; i++) {
        if (strcasecmp(s_cache[i].class_name, class_name) == 0)
            return strdup(s_cache[i].icon_name);
    }
    return NULL;
}

static void cache_insert(const char *class_name, const char *icon_name)
{
    if (s_cache_count >= MAX_CACHE) {
        LOG_WRN("Icon cache full, discarding oldest entry");
        free(s_cache[0].class_name);
        free(s_cache[0].icon_name);
        memmove(&s_cache[0], &s_cache[1],
                (size_t)(s_cache_count - 1) * sizeof(CacheEntry));
        s_cache_count--;
    }
    s_cache[s_cache_count].class_name = strdup(class_name);
    s_cache[s_cache_count].icon_name  = strdup(icon_name);
    s_cache_count++;
}

/* ── Public API ──────────────────────────────────────────────────────── */

static void add_dir(const char *path)
{
    if (s_dir_count >= MAX_DIRS) return;
    if (access(path, R_OK) != 0) return;
    s_dirs[s_dir_count++] = strdup(path);
}

void icons_init(void)
{
    s_dir_count = 0;
    s_cache_count = 0;

    /* XDG_DATA_HOME/applications */
    const char *xdh = getenv("XDG_DATA_HOME");
    const char *home = getenv("HOME");
    char buf[512];

    if (xdh && *xdh) {
        snprintf(buf, sizeof(buf), "%s/applications", xdh);
        add_dir(buf);
    } else if (home) {
        snprintf(buf, sizeof(buf), "%s/.local/share/applications", home);
        add_dir(buf);
    }

    /* XDG_DATA_DIRS/applications */
    const char *xdd = getenv("XDG_DATA_DIRS");
    if (!xdd || !*xdd) xdd = "/usr/local/share:/usr/share";

    char dirs_copy[2048];
    snprintf(dirs_copy, sizeof(dirs_copy), "%s", xdd);
    char *tok = strtok(dirs_copy, ":");
    while (tok) {
        snprintf(buf, sizeof(buf), "%s/applications", tok);
        add_dir(buf);
        tok = strtok(NULL, ":");
    }

    /* Flatpak directories */
    add_dir("/var/lib/flatpak/exports/share/applications");
    if (home) {
        snprintf(buf, sizeof(buf),
                 "%s/.local/share/flatpak/exports/share/applications", home);
        add_dir(buf);
    }

    LOG_INF("Icon search: %d directories", s_dir_count);
}

void icons_cleanup(void)
{
    for (int i = 0; i < s_dir_count; i++) free(s_dirs[i]);
    s_dir_count = 0;

    for (int i = 0; i < s_cache_count; i++) {
        free(s_cache[i].class_name);
        free(s_cache[i].icon_name);
    }
    s_cache_count = 0;
}

char *icons_get_name(const char *class_name)
{
    if (!class_name || !class_name[0])
        return strdup(FALLBACK_ICON);

    /* 1. Cache hit */
    char *cached = cache_lookup(class_name);
    if (cached) return cached;

    /* 2. Multi-strategy search */
    char *icon = search_exact(class_name);
    if (!icon) icon = search_lower(class_name);
    if (!icon) icon = search_reverse_domain(class_name);
    if (!icon) icon = search_scan(class_name);
    if (!icon) icon = search_wmclass(class_name);

    /* 3. Fallback */
    if (!icon) {
        LOG_DBG("No icon for class '%s', using fallback", class_name);
        icon = strdup(FALLBACK_ICON);
    }

    /* 4. Cache and return */
    cache_insert(class_name, icon);
    return icon;
}
