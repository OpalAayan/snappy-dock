/* snappydock-d  —  log.h
 *
 * Header-only leveled logging.  All output goes to stderr so stdout
 * remains clean for the JSON protocol.
 *
 * Levels:  ERR > WRN > INF > DBG
 *
 * Verbosity (runtime, set via --verbose / -V):
 *   0 (default) — only ERR and WRN are printed.
 *   1 (-V)      — ERR, WRN, and INF are printed.
 *   2 (-VV)     — all levels including DBG are printed.
 */
#ifndef SNAPPY_LOG_H
#define SNAPPY_LOG_H

#include <stdio.h>

/* Global verbosity level — defined in main.c */
extern int g_verbose;

#define LOG_ERR(...) \
    fprintf(stderr, "[snappydock-d] ERROR: " __VA_ARGS__), \
    fprintf(stderr, "\n")

#define LOG_WRN(...) \
    fprintf(stderr, "[snappydock-d] WARN:  " __VA_ARGS__), \
    fprintf(stderr, "\n")

#define LOG_INF(...) do { \
    if (g_verbose >= 1) { \
        fprintf(stderr, "[snappydock-d] INFO:  " __VA_ARGS__); \
        fprintf(stderr, "\n"); \
    } \
} while (0)

#define LOG_DBG(...) do { \
    if (g_verbose >= 2) { \
        fprintf(stderr, "[snappydock-d] DEBUG: " __VA_ARGS__); \
        fprintf(stderr, "\n"); \
    } \
} while (0)

#endif /* SNAPPY_LOG_H */
