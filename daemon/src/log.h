/* snappydock-d  —  log.h
 *
 * Header-only leveled logging.  All output goes to stderr so stdout
 * remains clean for the JSON protocol.
 *
 * Levels:  ERR > WRN > INF > DBG
 *
 * Build with -DSNAPPY_DEBUG to enable DBG output.
 */
#ifndef SNAPPY_LOG_H
#define SNAPPY_LOG_H

#include <stdio.h>

#define LOG_ERR(...) \
    fprintf(stderr, "[snappydock-d] ERROR: " __VA_ARGS__), \
    fprintf(stderr, "\n")

#define LOG_WRN(...) \
    fprintf(stderr, "[snappydock-d] WARN:  " __VA_ARGS__), \
    fprintf(stderr, "\n")

#define LOG_INF(...) \
    fprintf(stderr, "[snappydock-d] INFO:  " __VA_ARGS__), \
    fprintf(stderr, "\n")

#ifdef SNAPPY_DEBUG
#define LOG_DBG(...) \
    fprintf(stderr, "[snappydock-d] DEBUG: " __VA_ARGS__), \
    fprintf(stderr, "\n")
#else
#define LOG_DBG(...) ((void)0)
#endif

#endif /* SNAPPY_LOG_H */
