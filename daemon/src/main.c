/* snappydock-d  —  main.c
 *
 * Entry point for the Snappy Dock daemon.
 *
 * Startup:
 *   1. config_parse()          — load INI + CLI overrides
 *   2. hypr_ipc_init()         — resolve Hyprland socket path
 *   3. icons_init()            — build XDG directory list
 *   4. state_init() + refresh  — full IPC snapshot
 *   5. state_load_pinned()     — load pinned apps
 *   6. protocol_emit_config()  — send config to QML (once)
 *   7. protocol_emit_state()   — send initial state to QML
 *   8. Enter poll() loop
 *
 * Event loop (poll on 2 fds):
 *   - Socket2 → parse events → update state → emit state
 *   - stdin   → parse commands → dispatch
 *
 * Shutdown:
 *   Reverse order cleanup on SIGINT/SIGTERM or stdin EOF.
 */
#define _POSIX_C_SOURCE 200809L

#include "config.h"
#include "config_watcher.h"
#include "hypr_events.h"
#include "hypr_ipc.h"
#include "icons.h"
#include "launcher.h"
#include "log.h"
#include "protocol.h"
#include "state.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <limits.h>

/* ── Global verbosity (see log.h) ────────────────────────────────────── */

int g_verbose = 0;

/* ── Signal handling ─────────────────────────────────────────────────── */

static volatile sig_atomic_t s_running = 1;

static void on_signal(int sig)
{
    (void)sig;
    s_running = 0;
}

/* ── Command dispatch ────────────────────────────────────────────────── */

static bool handle_command(DockState *state, const ProtocolCmd *cmd)
{
    bool changed = false;

    if (strcmp(cmd->cmd, "focus") == 0) {
        hypr_ipc_focus_window(cmd->addr);
        /* State will update via Socket2 activewindowv2 event */
    }
    else if (strcmp(cmd->cmd, "launch") == 0) {
        launcher_exec_class(cmd->class_name);
    }
    else if (strcmp(cmd->cmd, "launch_cmd") == 0) {
        launcher_exec_cmd(cmd->arg);
    }
    else if (strcmp(cmd->cmd, "close") == 0) {
        hypr_ipc_close_window(cmd->addr);
    }
    else if (strcmp(cmd->cmd, "close_all") == 0) {
        /* Close all instances of a class.  Walk backwards to avoid
         * invalidating indices during removal. */
        for (int i = state->client_count - 1; i >= 0; i--) {
            if (strcasecmp(state->clients[i].class_name,
                           cmd->class_name) == 0) {
                hypr_ipc_close_window(state->clients[i].addr);
            }
        }
    }
    else if (strcmp(cmd->cmd, "pin") == 0) {
        state_pin(state, cmd->class_name);
        changed = true;
    }
    else if (strcmp(cmd->cmd, "unpin") == 0) {
        state_unpin(state, cmd->class_name);
        changed = true;
    }
    else if (strcmp(cmd->cmd, "toggle_float") == 0) {
        hypr_ipc_toggle_floating(cmd->addr);
    }
    else if (strcmp(cmd->cmd, "toggle_fullscreen") == 0) {
        hypr_ipc_toggle_fullscreen(cmd->addr);
    }
    else if (strcmp(cmd->cmd, "move_to_ws") == 0) {
        hypr_ipc_move_to_workspace(cmd->addr, cmd->ws);
    }
    else {
        LOG_WRN("Unknown command: %s", cmd->cmd);
    }

    return changed;
}

/* ── Event dispatch ──────────────────────────────────────────────────── */

static bool handle_event(DockState *state, const HyprEvent *ev)
{
    switch (ev->type) {
    case HYPR_EV_OPEN_WINDOW:      return state_on_openwindow(state, ev->data);
    case HYPR_EV_CLOSE_WINDOW:     return state_on_closewindow(state, ev->data);
    case HYPR_EV_ACTIVE_WINDOW:    return state_on_activewindow(state, ev->data);
    case HYPR_EV_MOVE_WINDOW:      return state_on_movewindow(state, ev->data);
    case HYPR_EV_WORKSPACE:        return state_on_workspace(state, ev->data);
    case HYPR_EV_FLOATING:         return state_on_floating(state, ev->data);
    case HYPR_EV_FULLSCREEN:       return state_on_fullscreen(state, ev->data);
    case HYPR_EV_FOCUSED_MON:      return state_on_focusedmon(state, ev->data);
    case HYPR_EV_CONFIG_RELOADED:
        hypr_ipc_init(); /* re-probe socket path */
        return state_refresh(state);
    case HYPR_EV_URGENT:
    case HYPR_EV_UNKNOWN:
        break;
    }
    return false;
}

/* ── Main ────────────────────────────────────────────────────────────── */

int main(int argc, char **argv)
{
    /* ── Line-buffer stdout for JSON protocol ────────────────────────── */
    setvbuf(stdout, NULL, _IOLBF, 0);

    /* ── Parse verbosity flags before anything else ──────────────────── */
    /* Check env var first (set by snappy-dock wrapper script) */
    const char *verbose_env = getenv("SNAPPY_DOCK_VERBOSE");
    if (verbose_env && *verbose_env)
        g_verbose = atoi(verbose_env);
    /* CLI flags can further increase verbosity */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--verbose") == 0 || strcmp(argv[i], "-V") == 0) {
            g_verbose++;
        } else if (strcmp(argv[i], "-VV") == 0) {
            g_verbose = 2;
        }
    }

    /* ── Signal handlers ─────────────────────────────────────────────── */
    signal(SIGINT,  on_signal);
    signal(SIGTERM, on_signal);
    signal(SIGPIPE, SIG_IGN);  /* don't crash if QML closes the pipe */

    LOG_INF("snappydock-d v0.1.0");

    /* ── 1. Config ───────────────────────────────────────────────────── */
    config_parse(&argc, &argv);
    const DockConfig *cfg = config_get();

    /* ── 2. Hyprland IPC ─────────────────────────────────────────────── */
    if (hypr_ipc_init() != 0) {
        LOG_ERR("Cannot connect to Hyprland. Is it running?");
        return 1;
    }

    /* ── 3. Icon resolver ────────────────────────────────────────────── */
    icons_init();

    /* ── 4. Dock state ───────────────────────────────────────────────── */
    DockState state;
    state_init(&state);
    state_refresh(&state);
    state_load_pinned(&state);

    /* ── 5. Socket2 event listener ───────────────────────────────────── */
    int ev_fd = hypr_events_init();
    if (ev_fd < 0) {
        LOG_ERR("Cannot connect to Hyprland Socket2");
        /* Non-fatal: we can still serve pinned state */
    }

    /* ── 6. Config file watcher ──────────────────────────────────────── */
    char config_path[PATH_MAX];
    if (getenv("XDG_CONFIG_HOME")) {
        snprintf(config_path, sizeof(config_path), "%s/snappy-dock/config.ini", getenv("XDG_CONFIG_HOME"));
    } else {
        snprintf(config_path, sizeof(config_path), "%s/.config/snappy-dock/config.ini", getenv("HOME"));
    }
    int watch_fd = config_watcher_init(config_path);

    /* ── 7. Emit initial data ────────────────────────────────────────── */
    protocol_emit_config(cfg);
    protocol_emit_state(&state);

    /* ── 8. Set stdin to non-blocking ────────────────────────────────── */
    int stdin_flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, stdin_flags | O_NONBLOCK);

    /* ── 9. Event loop ───────────────────────────────────────────────── */
    LOG_INF("Entering event loop");

    while (s_running) {
        struct pollfd fds[3];
        int nfds = 0;

        /* stdin — commands from QML */
        fds[nfds].fd = STDIN_FILENO;
        fds[nfds].events = POLLIN;
        int idx_stdin = nfds++;

        /* Socket2 — Hyprland events */
        ev_fd = hypr_events_fd();
        int idx_ev = -1;
        if (ev_fd >= 0) {
            fds[nfds].fd = ev_fd;
            fds[nfds].events = POLLIN;
            idx_ev = nfds++;
        }

        /* Inotify — config watcher */
        int idx_watch = -1;
        if (watch_fd >= 0) {
            fds[nfds].fd = watch_fd;
            fds[nfds].events = POLLIN;
            idx_watch = nfds++;
        }

        int ret = poll(fds, (nfds_t)nfds, ev_fd >= 0 ? -1 : 1000);
        if (ret < 0) {
            if (errno == EINTR) continue;
            LOG_ERR("poll(): %s", strerror(errno));
            break;
        }

        bool state_changed = false;

        /* Handle Socket2 events */
        if (idx_ev >= 0 && (fds[idx_ev].revents & POLLIN)) {
            HyprEvent events[32];
            int n = hypr_events_read(events, 32);
            if (n < 0) {
                /* Disconnected — try to reconnect after a pause */
                LOG_WRN("Socket2 disconnected, reconnecting in 1s...");
                sleep(1);
                ev_fd = hypr_events_init();
                if (ev_fd >= 0) {
                    state_refresh(&state);
                    state_changed = true;
                }
            } else {
                for (int i = 0; i < n; i++) {
                    if (handle_event(&state, &events[i]))
                        state_changed = true;
                }
            }
        }

        /* Handle inotify events */
        if (idx_watch >= 0 && (fds[idx_watch].revents & POLLIN)) {
            config_watcher_handle(watch_fd);
        }

        /* Handle stdin commands */
        if (fds[idx_stdin].revents & (POLLIN | POLLHUP)) {
            ProtocolCmd cmd;
            while (protocol_read_cmd(&cmd)) {
                if (handle_command(&state, &cmd))
                    state_changed = true;
            }

            /* If stdin got POLLHUP (QML exited), shut down gracefully */
            if (fds[0].revents & POLLHUP) {
                LOG_INF("stdin closed, shutting down");
                s_running = 0;
            }
        }

        /* Emit state if anything changed */
        if (state_changed) {
            protocol_emit_state(&state);
        }

        /* If Socket2 is disconnected and not yet reconnected, retry */
        if (ev_fd < 0 && ret == 0) {
            ev_fd = hypr_events_init();
            if (ev_fd >= 0) {
                state_refresh(&state);
                protocol_emit_state(&state);
            }
        }
    }

    /* ── Cleanup (reverse init order) ────────────────────────────────── */
    config_watcher_cleanup(watch_fd);
    hypr_events_cleanup();
    state_free(&state);
    icons_cleanup();
    hypr_ipc_cleanup();
    config_free();

    LOG_INF("Clean shutdown");
    return 0;
}
