/* snappydock-d  —  launcher.c
 *
 * Detached process spawning via POSIX double-fork.
 *
 * The child process is fully detached from the daemon's process tree:
 *   fork() → child: setsid() → execl("/bin/sh", "sh", "-c", cmd)
 *
 * Environment cleanup:
 *   - Unsets HL_INITIAL_WORKSPACE_TOKEN to prevent Hyprland from
 *     forcing the child onto the dock's workspace.
 *   - Unsets XDG_ACTIVATION_TOKEN for the same reason.
 */
#define _POSIX_C_SOURCE 200809L

#include "launcher.h"
#include "icons.h"
#include "log.h"

#include <ctype.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

/* ── Helpers ─────────────────────────────────────────────────────────── */

/*
 * Extract Exec= from a .desktop file.
 * Returns strdup'd string or NULL.  Caller frees.
 */
static char *desktop_get_exec(const char *path)
{
    FILE *f = fopen(path, "r");
    if (!f) return NULL;

    char line[1024];
    bool in_section = false;

    while (fgets(line, sizeof(line), f)) {
        size_t len = strlen(line);
        while (len > 0 && (line[len-1] == '\n' || line[len-1] == '\r'))
            line[--len] = '\0';

        if (line[0] == '[') {
            in_section = (strncmp(line, "[Desktop Entry]", 15) == 0);
            continue;
        }
        if (!in_section) continue;

        if (strncmp(line, "Exec=", 5) == 0) {
            fclose(f);
            return strdup(line + 5);
        }
    }

    fclose(f);
    return NULL;
}

/*
 * Strip desktop field codes (%f %F %u %U %c %k %i %d %D %n %N %v %m)
 * from an Exec= string in place.
 */
static void strip_field_codes(char *s)
{
    char *r = s, *w = s;
    while (*r) {
        if (*r == '%' && r[1] && strchr("fFuUcCkidDnNvm", r[1])) {
            r += 2;
            /* Also skip a trailing space */
            if (*r == ' ') r++;
        } else {
            *w++ = *r++;
        }
    }
    *w = '\0';
}

/*
 * Fork a detached child that runs @cmd via /bin/sh.
 */
static bool spawn_detached(const char *cmd)
{
    if (!cmd || !cmd[0]) return false;

    pid_t pid = fork();
    if (pid < 0) {
        LOG_ERR("fork() failed");
        return false;
    }

    if (pid == 0) {
        /* ── Child process ─────────────────────────────────────────── */
        setsid();

        /* Prevent workspace inheritance */
        unsetenv("HL_INITIAL_WORKSPACE_TOKEN");
        unsetenv("XDG_ACTIVATION_TOKEN");

        /* Start in user's home directory so new terminals etc.
         * don't inherit the daemon's (or caller's) cwd. */
        const char *home = getenv("HOME");
        if (home && home[0])
            (void)chdir(home);

        /* Reset signal handlers */
        signal(SIGCHLD, SIG_DFL);

        execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
        _exit(127); /* exec failed */
    }

    /* ── Parent — reap the immediate child ─────────────────────────── */
    LOG_INF("Launched: %s (pid %d)", cmd, (int)pid);

    /* Non-blocking reap.  The child calls setsid() so it won't become
     * a zombie — it's adopted by init/systemd.  We still call waitpid
     * with WNOHANG to clean up the initial fork's entry. */
    int status;
    waitpid(pid, &status, WNOHANG);
    return true;
}

/* ── Public API ──────────────────────────────────────────────────────── */

bool launcher_exec_class(const char *class_name)
{
    if (!class_name || !class_name[0]) return false;

    char *desktop_path = icons_find_desktop(class_name);
    if (!desktop_path) {
        LOG_WRN("No .desktop file for class '%s'", class_name);
        return false;
    }

    char *exec = desktop_get_exec(desktop_path);
    free(desktop_path);
    if (!exec) {
        LOG_WRN("No Exec= in .desktop for class '%s'", class_name);
        return false;
    }

    strip_field_codes(exec);

    /* Trim trailing whitespace */
    size_t len = strlen(exec);
    while (len > 0 && isspace((unsigned char)exec[len-1]))
        exec[--len] = '\0';

    bool ok = spawn_detached(exec);
    free(exec);
    return ok;
}

bool launcher_exec_cmd(const char *cmd)
{
    return spawn_detached(cmd);
}
