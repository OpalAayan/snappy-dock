/* snappydock-d  —  hypr_events.c
 *
 * Socket2 event listener with line-buffered parsing.
 *
 * Events arrive as newline-delimited lines:  EVENTNAME>>DATA\n
 * A single read() may return multiple lines or a partial line,
 * so we maintain a persistent line buffer across calls.
 */
#define _POSIX_C_SOURCE 200809L

#include "hypr_events.h"
#include "log.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

/* ── Internal state ──────────────────────────────────────────────────── */

static int  s_fd = -1;
static char s_buf[8192];    /* raw read buffer                       */
static int  s_buf_len = 0;  /* bytes currently in s_buf              */

/* ── Event name → type mapping ───────────────────────────────────────── */

static const struct {
    const char    *name;
    HyprEventType  type;
} EVENT_MAP[] = {
    { "activewindowv2",     HYPR_EV_ACTIVE_WINDOW   },
    { "openwindow",         HYPR_EV_OPEN_WINDOW     },
    { "closewindow",        HYPR_EV_CLOSE_WINDOW    },
    { "movewindowv2",       HYPR_EV_MOVE_WINDOW     },
    { "workspacev2",        HYPR_EV_WORKSPACE        },
    { "changefloatingmode", HYPR_EV_FLOATING         },
    { "fullscreen",         HYPR_EV_FULLSCREEN       },
    { "focusedmon",         HYPR_EV_FOCUSED_MON      },
    { "configreloaded",     HYPR_EV_CONFIG_RELOADED  },
    { "urgent",             HYPR_EV_URGENT           },
    { NULL, HYPR_EV_UNKNOWN }
};

static HyprEventType classify_event(const char *name, size_t len)
{
    for (int i = 0; EVENT_MAP[i].name; i++) {
        if (strlen(EVENT_MAP[i].name) == len &&
            strncmp(EVENT_MAP[i].name, name, len) == 0) {
            return EVENT_MAP[i].type;
        }
    }
    return HYPR_EV_UNKNOWN;
}

/* ── Parse one line into a HyprEvent ─────────────────────────────────── */

static void parse_line(const char *line, HyprEvent *ev)
{
    const char *sep = strstr(line, ">>");
    if (sep) {
        size_t name_len = (size_t)(sep - line);
        ev->type = classify_event(line, name_len);
        snprintf(ev->data, HYPR_EVENT_DATA_MAX, "%s", sep + 2);
    } else {
        /* Events without data (e.g. "configreloaded") */
        ev->type = classify_event(line, strlen(line));
        ev->data[0] = '\0';
    }
}

/* ── Connection ──────────────────────────────────────────────────────── */

int hypr_events_init(void)
{
    const char *his = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!his || !*his) {
        LOG_ERR("HYPRLAND_INSTANCE_SIGNATURE not set");
        return -1;
    }

    char path[108]; /* matches sizeof(sun_path) */
    const char *xrd = getenv("XDG_RUNTIME_DIR");

    if (xrd && *xrd) {
        snprintf(path, sizeof(path), "%s/hypr/%s/.socket2.sock", xrd, his);
        if (access(path, F_OK) != 0)
            snprintf(path, sizeof(path), "/tmp/hypr/%s/.socket2.sock", his);
    } else {
        snprintf(path, sizeof(path), "/tmp/hypr/%s/.socket2.sock", his);
    }

    s_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s_fd < 0) {
        LOG_ERR("socket(): %s", strerror(errno));
        return -1;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", path);

    if (connect(s_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        LOG_ERR("connect(Socket2): %s", strerror(errno));
        close(s_fd);
        s_fd = -1;
        return -1;
    }

    LOG_INF("Connected to Socket2: %s", path);
    s_buf_len = 0;
    return s_fd;
}

int hypr_events_fd(void)
{
    return s_fd;
}

/* ── Read + parse ────────────────────────────────────────────────────── */

int hypr_events_read(HyprEvent *out, int max_events)
{
    if (s_fd < 0 || !out || max_events <= 0) return -1;

    /* Read available data into the buffer */
    int space = (int)sizeof(s_buf) - s_buf_len - 1;
    if (space <= 0) {
        /* Buffer overflow — shouldn't happen with reasonable events.
         * Discard the buffer and try again. */
        LOG_WRN("Event buffer overflow, discarding %d bytes", s_buf_len);
        s_buf_len = 0;
        space = (int)sizeof(s_buf) - 1;
    }

    ssize_t n = read(s_fd, s_buf + s_buf_len, (size_t)space);
    if (n <= 0) {
        if (n == 0) {
            LOG_WRN("Socket2 EOF (Hyprland disconnected?)");
        } else {
            LOG_ERR("Socket2 read(): %s", strerror(errno));
        }
        close(s_fd);
        s_fd = -1;
        return -1;
    }
    s_buf_len += (int)n;
    s_buf[s_buf_len] = '\0';

    /* Extract complete lines (newline-delimited) */
    int count = 0;
    char *start = s_buf;

    for (;;) {
        if (count >= max_events) break;

        char *nl = strchr(start, '\n');
        if (!nl) break; /* no more complete lines */

        *nl = '\0';

        /* Skip empty lines */
        if (start[0] != '\0') {
            parse_line(start, &out[count]);
            count++;
        }

        start = nl + 1;
    }

    /* Compact: move any remaining partial line to the front */
    int remaining = s_buf_len - (int)(start - s_buf);
    if (remaining > 0) {
        memmove(s_buf, start, (size_t)remaining);
    }
    s_buf_len = remaining;

    return count;
}

void hypr_events_cleanup(void)
{
    if (s_fd >= 0) {
        close(s_fd);
        s_fd = -1;
    }
    s_buf_len = 0;
}
