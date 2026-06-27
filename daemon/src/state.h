/* snappydock-d  —  state.h
 *
 * Central dock data model.  Owns the list of running Hyprland
 * clients, the pinned-app list, and compositor focus state.
 *
 * Memory contract:
 *   - All strings inside DockClient are strdup'd and owned by
 *     the DockState.  state_free() releases everything.
 *   - Pointers returned by state_first_instance() are borrowed
 *     into the state's array — do NOT free them.
 *   - Incremental handlers (state_on_*) parse the raw Socket2
 *     event payload, mutate the state, and return true if
 *     anything actually changed.
 *
 * Thread safety:  NOT thread-safe.
 */
#ifndef SNAPPY_STATE_H
#define SNAPPY_STATE_H

#include <stdbool.h>

/* ── Client (window) ─────────────────────────────────────────────────── */

typedef struct {
    char *addr;           /* "0x55a1b2c3d4e5" — strdup'd, owned       */
    char *class_name;     /* "kitty"          — strdup'd, owned       */
    char *title;          /* "~/code"         — strdup'd, owned       */
    char *icon;           /* resolved icon name — strdup'd, owned     */
    int   workspace_id;   /* ≥1 normal, <0 special                    */
    bool  is_active;      /* currently focused?                       */
    bool  is_floating;
    bool  is_fullscreen;
} DockClient;

/* ── Pinned entry ────────────────────────────────────────────────────── */

typedef struct {
    char *class_name;     /* strdup'd, owned                          */
    char *icon;           /* resolved icon name — strdup'd, owned     */
} PinnedEntry;

/* ── Dock state ──────────────────────────────────────────────────────── */

typedef struct {
    /* Running clients (dynamic array) */
    DockClient *clients;
    int         client_count;
    int         client_cap;

    /* Pinned apps (dynamic array, order = display order) */
    PinnedEntry *pinned;
    int          pinned_count;
    int          pinned_cap;

    /* Compositor focus state */
    char *active_addr;    /* strdup'd — currently focused address     */
    int   active_ws;      /* currently active workspace ID            */
    char *active_mon;     /* strdup'd — currently active monitor      */
} DockState;

/* ── Lifecycle ───────────────────────────────────────────────────────── */

void state_init(DockState *s);
void state_free(DockState *s);

/* ── Full refresh (IPC snapshot) ─────────────────────────────────────── */

/*
 * Query Hyprland for all clients, active window, and monitors.
 * Clears existing client list, repopulates from IPC response.
 * Returns true if state changed.
 */
bool state_refresh(DockState *s);

/* ── Incremental event handlers ──────────────────────────────────────── */

/*
 * Each function parses the raw Socket2 payload string (after ">>"),
 * mutates the state, and returns true if something changed.
 */
bool state_on_openwindow(DockState *s, const char *data);
bool state_on_closewindow(DockState *s, const char *data);
bool state_on_activewindow(DockState *s, const char *data);
bool state_on_movewindow(DockState *s, const char *data);
bool state_on_workspace(DockState *s, const char *data);
bool state_on_floating(DockState *s, const char *data);
bool state_on_fullscreen(DockState *s, const char *data);
bool state_on_focusedmon(DockState *s, const char *data);

/* ── Pinning ─────────────────────────────────────────────────────────── */

void state_load_pinned(DockState *s);
void state_pin(DockState *s, const char *class_name);
void state_unpin(DockState *s, const char *class_name);
bool state_is_pinned(const DockState *s, const char *class_name);

/* ── Queries ─────────────────────────────────────────────────────────── */

int         state_instance_count(const DockState *s, const char *cls);
bool        state_is_class_active(const DockState *s, const char *cls);
DockClient *state_first_instance(const DockState *s, const char *cls);

#endif /* SNAPPY_STATE_H */
