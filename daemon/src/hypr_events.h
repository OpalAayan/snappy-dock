/* snappydock-d  —  hypr_events.h
 *
 * Asynchronous Hyprland Socket2 event listener.
 *
 * Connects to Socket2, reads compositor events as newline-delimited
 * lines (EVENT>>DATA\n), and yields parsed HyprEvent structs to the
 * caller.  The module owns a line buffer to handle partial reads and
 * multi-event batches in a single read().
 *
 * Integration:  The caller uses hypr_events_fd() with poll() and
 * calls hypr_events_read() when data is available.
 *
 * Thread safety:  NOT thread-safe.
 */
#ifndef SNAPPY_HYPR_EVENTS_H
#define SNAPPY_HYPR_EVENTS_H

/* ── Event types ─────────────────────────────────────────────────────── */

typedef enum {
    HYPR_EV_ACTIVE_WINDOW,     /* activewindowv2>>ADDR              */
    HYPR_EV_OPEN_WINDOW,       /* openwindow>>ADDR,WS,CLASS,TITLE   */
    HYPR_EV_CLOSE_WINDOW,      /* closewindow>>ADDR                 */
    HYPR_EV_MOVE_WINDOW,       /* movewindowv2>>ADDR,WSID,WSNAME    */
    HYPR_EV_WORKSPACE,         /* workspacev2>>WSID,WSNAME           */
    HYPR_EV_FLOATING,          /* changefloatingmode>>ADDR,0/1      */
    HYPR_EV_FULLSCREEN,        /* fullscreen>>0/1                    */
    HYPR_EV_FOCUSED_MON,       /* focusedmon>>MONITOR,WS            */
    HYPR_EV_CONFIG_RELOADED,   /* configreloaded                    */
    HYPR_EV_URGENT,            /* urgent>>ADDR                      */
    HYPR_EV_UNKNOWN,
} HyprEventType;

/* ── Parsed event ────────────────────────────────────────────────────── */

#define HYPR_EVENT_DATA_MAX 1024

typedef struct {
    HyprEventType type;
    char          data[HYPR_EVENT_DATA_MAX]; /* payload after ">>"  */
} HyprEvent;

/* ── API ─────────────────────────────────────────────────────────────── */

/*
 * Connect to Socket2.
 * Returns the file descriptor for use with poll(), or -1 on failure.
 */
int hypr_events_init(void);

/*
 * Return the current Socket2 fd, or -1 if disconnected.
 */
int hypr_events_fd(void);

/*
 * Read available data and parse complete events.
 * Call this when poll() indicates the fd is readable.
 *
 * Writes up to @max_events parsed events into @out.
 * Returns the number of events parsed (≥ 0).
 * Returns -1 on socket disconnect (caller should reconnect).
 */
int hypr_events_read(HyprEvent *out, int max_events);

/*
 * Close the socket and free internal buffers.
 */
void hypr_events_cleanup(void);

#endif /* SNAPPY_HYPR_EVENTS_H */
