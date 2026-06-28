#define _POSIX_C_SOURCE 200809L
#include "config.h"
#include "config_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { \
    tests_run++; \
    fprintf(stderr, "  %-50s ", #name); \
    name(); \
    tests_passed++; \
    fprintf(stderr, "PASS\n"); \
} while(0)

#define ASSERT_STR_EQ(a, b) do { \
    if (strcmp((a), (b)) != 0) { \
        fprintf(stderr, "FAIL\n    Expected: \"%s\"\n    Got:      \"%s\"\n    at %s:%d\n", \
                (b), (a), __FILE__, __LINE__); \
        exit(1); \
    } \
} while(0)

#define ASSERT_INT_EQ(a, b) do { \
    if ((a) != (b)) { \
        fprintf(stderr, "FAIL\n    Expected: %d\n    Got:      %d\n    at %s:%d\n", \
                (b), (a), __FILE__, __LINE__); \
        exit(1); \
    } \
} while(0)

#define ASSERT_TRUE(expr) do { \
    if (!(expr)) { \
        fprintf(stderr, "FAIL\n    Assertion failed: %s\n    at %s:%d\n", \
                #expr, __FILE__, __LINE__); \
        exit(1); \
    } \
} while(0)

#define ASSERT_NULL(ptr) do { \
    if ((ptr) != NULL) { \
        fprintf(stderr, "FAIL\n    Expected NULL\n    at %s:%d\n", \
                __FILE__, __LINE__); \
        exit(1); \
    } \
} while(0)

static void test_config_defaults(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);

    ASSERT_STR_EQ(cfg.position, "bottom");
    ASSERT_STR_EQ(cfg.alignment, "center");
    ASSERT_INT_EQ(cfg.icon_size, 48);
    ASSERT_STR_EQ(cfg.icon_theme, "");
    ASSERT_STR_EQ(cfg.icon_fallback, "application-x-executable");
    ASSERT_STR_EQ(cfg.layer, "overlay");
    ASSERT_INT_EQ(cfg.full_width, false);
    ASSERT_INT_EQ(cfg.exclusive_zone, 0);
    ASSERT_INT_EQ(cfg.margin_bottom, 5);
    ASSERT_INT_EQ(cfg.autohide, false);
    ASSERT_STR_EQ(cfg.launcher_cmd, "fuzzel");
    ASSERT_STR_EQ(cfg.launcher_pos, "start");
    ASSERT_STR_EQ(cfg.launcher_icon, "dots");
    ASSERT_INT_EQ(cfg.launcher_icon_size, 0);
    ASSERT_INT_EQ(cfg.launcher_hover_bg, true);
    ASSERT_INT_EQ(cfg.launcher_hover_bg_size, 0);
    ASSERT_STR_EQ(cfg.font_family, "Sans");
    ASSERT_STR_EQ(cfg.font_weight, "Bold");
    ASSERT_INT_EQ(cfg.workspace_count, 5);
    ASSERT_INT_EQ(cfg.hotspot_delay, 50);
    ASSERT_STR_EQ(cfg.mode, "static");
    ASSERT_INT_EQ(cfg.spread, 3);
    ASSERT_INT_EQ(cfg.icon_spacing, 2);
    ASSERT_TRUE(cfg.magnification > 0.77 && cfg.magnification < 0.79);

    config_free_fields(&cfg);
}

static void test_mode_snappy_accepted(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);
    config_apply_ini_key_for_test(&cfg, "Dock", "Mode", "snappy");
    config_validate_mode_for_test(&cfg);

    ASSERT_STR_EQ(cfg.mode, "snappy");

    config_free_fields(&cfg);
}

static void test_mode_case_normalize(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);
    config_apply_ini_key_for_test(&cfg, "Dock", "Mode", "SNAPPY");
    config_validate_mode_for_test(&cfg);

    ASSERT_STR_EQ(cfg.mode, "snappy");

    config_free_fields(&cfg);
}

static void test_mode_mixed_case(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);
    config_apply_ini_key_for_test(&cfg, "Dock", "Mode", "Snappy");
    config_validate_mode_for_test(&cfg);

    ASSERT_STR_EQ(cfg.mode, "snappy");

    config_free_fields(&cfg);
}

static void test_mode_invalid_fallback(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);
    config_apply_ini_key_for_test(&cfg, "Dock", "Mode", "magnify");
    config_validate_mode_for_test(&cfg);

    ASSERT_STR_EQ(cfg.mode, "static");

    config_free_fields(&cfg);
}

static void test_mode_empty_fallback(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);
    free(cfg.mode);
    cfg.mode = strdup("");
    config_validate_mode_for_test(&cfg);

    ASSERT_STR_EQ(cfg.mode, "static");

    config_free_fields(&cfg);
}

static void test_ini_position(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);
    config_apply_ini_key_for_test(&cfg, "Dock", "Position", "top");

    ASSERT_STR_EQ(cfg.position, "top");

    config_free_fields(&cfg);
}

static void test_ini_icon_size(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);
    config_apply_ini_key_for_test(&cfg, "Icons", "IconSize", "64");

    ASSERT_INT_EQ(cfg.icon_size, 64);

    config_free_fields(&cfg);
}

static void test_ini_margins(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);
    config_apply_ini_key_for_test(&cfg, "Margins", "Top", "10");
    config_apply_ini_key_for_test(&cfg, "Margins", "Bottom", "20");

    ASSERT_INT_EQ(cfg.margin_top, 10);
    ASSERT_INT_EQ(cfg.margin_bottom, 20);

    config_free_fields(&cfg);
}

static void test_free_zeroes_all(void) {
    DockConfig cfg = {0};
    config_set_defaults_for_test(&cfg);
    config_free_fields(&cfg);

    ASSERT_NULL(cfg.position);
    ASSERT_NULL(cfg.mode);
    ASSERT_INT_EQ(cfg.icon_size, 0);
}

int main(void) {
    fprintf(stderr, "\n=== Config Tests ===\n");

    TEST(test_config_defaults);
    TEST(test_mode_snappy_accepted);
    TEST(test_mode_case_normalize);
    TEST(test_mode_mixed_case);
    TEST(test_mode_invalid_fallback);
    TEST(test_mode_empty_fallback);
    TEST(test_ini_position);
    TEST(test_ini_icon_size);
    TEST(test_ini_margins);
    TEST(test_free_zeroes_all);

    fprintf(stderr, "\n  %d/%d tests passed\n\n", tests_passed, tests_run);
    return tests_passed == tests_run ? 0 : 1;
}
