/* snappydock-d  —  protocol.h
 *
 * JSON-lines protocol over stdin/stdout.
 *
 * Daemon → QML (stdout):
 *   {"type":"config", ...}          — sent once at startup
 *   {"type":"state", "clients":[...], "pinned":[...], ...}
 *                                   — sent on every state change
 *
 * QML → Daemon (stdin):
 *   {"cmd":"focus",   "addr":"0x..."}
 *   {"cmd":"launch",  "class":"kitty"}
 *   {"cmd":"launch_cmd", "arg":"fuzzel"}
 *   {"cmd":"close",   "addr":"0x..."}
 *   {"cmd":"close_all","class":"kitty"}
 *   {"cmd":"pin",     "class":"kitty"}
 *   {"cmd":"unpin",   "class":"kitty"}
 *   {"cmd":"toggle_float","addr":"0x..."}
 *   {"cmd":"toggle_fullscreen","addr":"0x..."}
 *   {"cmd":"move_to_ws","addr":"0x...","ws":3}
 *
 * Thread safety:  NOT thread-safe.
 */
#ifndef SNAPPY_PROTOCOL_H
#define SNAPPY_PROTOCOL_H

#include "config.h"
#include "state.h"

#include <stdbool.h>

/* ── Outbound (daemon → QML via stdout) ──────────────────────────────── */

/*
 * Emit the daemon config as a JSON line on stdout.
 * Called once at startup.
 */
void protocol_emit_config(const DockConfig *cfg);

/*
 * Emit the full dock state as a JSON line on stdout.
 * Called on every state change.
 */
void protocol_emit_state(const DockState *s);

/* ── Inbound (QML → daemon via stdin) ────────────────────────────────── */

typedef struct {
    char cmd[32];           /* "focus","launch","close","pin", etc.  */
    char addr[64];          /* window address, if applicable         */
    char class_name[128];   /* class name, if applicable             */
    char arg[256];          /* generic argument (e.g. command string) */
    int  ws;                /* workspace number, if applicable       */
} ProtocolCmd;

/*
 * Try to read and parse one JSON command from stdin.
 * Non-blocking: returns false immediately if no data available.
 *
 * Returns true  if a complete command was parsed into @out.
 * Returns false if no data, partial read, or parse error.
 */
bool protocol_read_cmd(ProtocolCmd *out);

#endif /* SNAPPY_PROTOCOL_H */
