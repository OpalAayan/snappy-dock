#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/inotify.h>
#include <limits.h>

#include "config_watcher.h"
#include "config.h"
#include "log.h"
#include "protocol.h"

static int watch_fd = -1;
static int watch_wd = -1;
static char *watched_path = NULL;

int config_watcher_init(const char *config_path)
{
    watch_fd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (watch_fd < 0) {
        LOG_ERR("Failed to init inotify: %s", strerror(errno));
        return -1;
    }

    /* We watch for close_write to avoid triggering on partial writes. */
    watch_wd = inotify_add_watch(watch_fd, config_path, IN_CLOSE_WRITE);
    if (watch_wd < 0) {
        LOG_WRN("Could not watch config %s (may not exist yet)", config_path);
        /* We could watch the directory instead, but for simplicity we rely on the file existing. */
    } else {
        LOG_INF("Watching config file: %s", config_path);
        watched_path = strdup(config_path);
    }

    return watch_fd;
}

void config_watcher_handle(int fd)
{
    char buf[4096]
        __attribute__ ((aligned(__alignof__(struct inotify_event))));
    const struct inotify_event *event;
    ssize_t len;
    char *ptr;

    /* Loop while events can be read from inotify file descriptor. */
    for (;;) {
        len = read(fd, buf, sizeof(buf));
        if (len == -1 && errno != EAGAIN) {
            LOG_ERR("inotify read error: %s", strerror(errno));
            break;
        }

        /* If the nonblocking read() found no events to read, then
           it returns -1 with errno set to EAGAIN. */
        if (len <= 0) break;

        /* Loop over all events in the buffer. */
        for (ptr = buf; ptr < buf + len;
             ptr += sizeof(struct inotify_event) + event->len) {
            event = (const struct inotify_event *) ptr;

            if (event->mask & IN_CLOSE_WRITE) {
                LOG_INF("Config file changed, reloading...");

                /* Reload config */
                if (watched_path) {
                    config_free();
                    config_parse(NULL, NULL);

                    /* Broadcast new config to frontend */
                    protocol_emit_config(config_get());
                }
            }
        }
    }
}

void config_watcher_cleanup(int fd)
{
    if (watch_wd >= 0 && fd >= 0) {
        inotify_rm_watch(fd, watch_wd);
    }
    if (fd >= 0) {
        close(fd);
    }
    free(watched_path);
}
