/*  config_internal.h  –  Internal config helpers exposed for unit tests.
 *
 *  NOT part of the public API.  Only include from test files.
 */
#ifndef SNAPPY_CONFIG_INTERNAL_H
#define SNAPPY_CONFIG_INTERNAL_H

#include "config.h"

/*
 * Set all fields to compiled-in defaults.
 * Exported for unit testing.
 */
void config_set_defaults_for_test(DockConfig *cfg);

/*
 * Apply a single INI key/value under the given section.
 * Exported for unit testing.
 */
void config_apply_ini_key_for_test(DockConfig *cfg, const char *section,
                                   const char *key, const char *val);

/*
 * Validate and normalise the mode field in place.
 * Exported for unit testing.
 */
void config_validate_mode_for_test(DockConfig *cfg);

/*
 * Free all heap memory owned by cfg fields (not cfg itself).
 * Exported for unit testing of standalone DockConfig instances.
 */
void config_free_fields(DockConfig *cfg);

#endif /* SNAPPY_CONFIG_INTERNAL_H */
