/* snappydock-d  —  launcher.h
 *
 * Detached application spawning.  Launches processes fully detached
 * from the daemon so they survive if the dock exits or crashes.
 *
 * Thread safety:  NOT thread-safe (calls fork).
 */
#ifndef SNAPPY_LAUNCHER_H
#define SNAPPY_LAUNCHER_H

#include <stdbool.h>

/*
 * Launch the application identified by @class_name.
 *
 * Steps:
 *   1. Find .desktop file via icons_find_desktop().
 *   2. Extract the Exec= key.
 *   3. Strip desktop field codes (%f, %F, %u, %U, %c, %k, etc.).
 *   4. fork() → child: setsid() + execl("/bin/sh", "sh", "-c", ...).
 *
 * The child process unsets HL_INITIAL_WORKSPACE_TOKEN and
 * XDG_ACTIVATION_TOKEN to prevent compositor workspace conflicts.
 *
 * Returns true if fork succeeded, false on failure.
 */
bool launcher_exec_class(const char *class_name);

/*
 * Launch an arbitrary shell command string, fully detached.
 * Useful for launcher/drawer buttons.
 *
 * Returns true if fork succeeded, false on failure.
 */
bool launcher_exec_cmd(const char *cmd);

#endif /* SNAPPY_LAUNCHER_H */
