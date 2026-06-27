/* snappydock-d  —  icons.h
 *
 * XDG icon name resolver.  Locates the .desktop file for a given
 * Wayland window class and extracts the Icon= key.  Results are
 * cached so each class is resolved at most once.
 *
 * Search strategy (cheapest first):
 *   1. Exact:    <class>.desktop
 *   2. Lower:    <lower(class)>.desktop
 *   3. Reverse:  org.foo.Bar → bar.desktop
 *   4. Scan:     case-insensitive substring on filenames
 *   5. WMClass:  open every .desktop, compare StartupWMClass=
 *
 * Thread safety:  NOT thread-safe.
 */
#ifndef SNAPPY_ICONS_H
#define SNAPPY_ICONS_H

/*
 * Build the XDG desktop-file directory list and create the cache.
 * Must be called before icons_get_name().
 */
void icons_init(void);

/*
 * Free the cache and directory list.
 */
void icons_cleanup(void);

/*
 * Return the icon name for the given window class.
 *
 * On cache miss, searches XDG directories for a matching .desktop
 * file and extracts Icon=.  Caches the result.
 *
 * Returns a strdup'd string.  >>> Caller must free(). <<<
 * Falls back to "application-x-executable" if no match.
 */
char *icons_get_name(const char *class_name);

/*
 * Return the full filesystem path to the .desktop file matching
 * the given window class.
 *
 * Returns a strdup'd path.  >>> Caller must free(). <<<
 * Returns NULL if no match.
 */
char *icons_find_desktop(const char *class_name);

#endif /* SNAPPY_ICONS_H */
