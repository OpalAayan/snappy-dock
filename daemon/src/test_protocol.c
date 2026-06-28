/*
 * test_protocol.c — Unit tests for JSON protocol serialization
 */

#define _POSIX_C_SOURCE 200809L
#include "config.h"
#include "config_internal.h"
#include "state.h"
#include "protocol.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <json-c/json.h>

/* ── test framework macros ────────────────────────────────────────── */

static int tests_run    = 0;
static int tests_passed = 0;

#define TEST(name)                                                     \
    do {                                                               \
        tests_run++;                                                   \
        fprintf(stderr, "  %-50s ", #name);                            \
        name();                                                        \
        tests_passed++;                                                \
        fprintf(stderr, "PASS\n");                                     \
    } while (0)

#define ASSERT_STR_EQ(a, b)                                            \
    do {                                                               \
        const char *_a = (a), *_b = (b);                               \
        if (!_a || !_b || strcmp(_a, _b) != 0) {                       \
            fprintf(stderr, "FAIL\n    %s:%d: expected \"%s\", got \"%s\"\n",\
                   __FILE__, __LINE__, _b ? _b : "(null)",             \
                   _a ? _a : "(null)");                                \
            exit(1);                                                   \
        }                                                              \
    } while (0)

#define ASSERT_INT_EQ(a, b)                                            \
    do {                                                               \
        int _a = (a), _b = (b);                                       \
        if (_a != _b) {                                                \
            fprintf(stderr, "FAIL\n    %s:%d: expected %d, got %d\n",  \
                   __FILE__, __LINE__, _b, _a);                        \
            exit(1);                                                   \
        }                                                              \
    } while (0)

#define ASSERT_TRUE(expr)                                              \
    do {                                                               \
        if (!(expr)) {                                                 \
            fprintf(stderr, "FAIL\n    %s:%d: %s is false\n",          \
                   __FILE__, __LINE__, #expr);                         \
            exit(1);                                                   \
        }                                                              \
    } while (0)

#define ASSERT_NULL(expr)                                              \
    do {                                                               \
        if ((expr) != NULL) {                                          \
            fprintf(stderr, "FAIL\n    %s:%d: %s is not NULL\n",       \
                   __FILE__, __LINE__, #expr);                         \
            exit(1);                                                   \
        }                                                              \
    } while (0)

/* ── stdout capture helpers ───────────────────────────────────────── */

static char *capture_emit_config(const DockConfig *cfg) {
    fflush(stdout);
    int pipefd[2];
    if (pipe(pipefd) != 0) return NULL;
    int saved = dup(STDOUT_FILENO);
    dup2(pipefd[1], STDOUT_FILENO);
    close(pipefd[1]);
    protocol_emit_config(cfg);
    fflush(stdout);
    dup2(saved, STDOUT_FILENO);
    close(saved);
    char *buf = malloc(8192);
    ssize_t n = read(pipefd[0], buf, 8191);
    close(pipefd[0]);
    if (n <= 0) { free(buf); return NULL; }
    buf[n] = '\0';
    return buf;
}

static char *capture_emit_state(const DockState *s) {
    fflush(stdout);
    int pipefd[2];
    if (pipe(pipefd) != 0) return NULL;
    int saved = dup(STDOUT_FILENO);
    dup2(pipefd[1], STDOUT_FILENO);
    close(pipefd[1]);
    protocol_emit_state(s);
    fflush(stdout);
    dup2(saved, STDOUT_FILENO);
    close(saved);
    char *buf = malloc(8192);
    ssize_t n = read(pipefd[0], buf, 8191);
    close(pipefd[0]);
    if (n <= 0) { free(buf); return NULL; }
    buf[n] = '\0';
    return buf;
}

/* ── JSON helpers ─────────────────────────────────────────────────── */

static const char *jget_str(struct json_object *obj, const char *key) {
    struct json_object *v;
    if (!json_object_object_get_ex(obj, key, &v)) return NULL;
    return json_object_get_string(v);
}

static int jget_int(struct json_object *obj, const char *key) {
    struct json_object *v;
    if (!json_object_object_get_ex(obj, key, &v)) return -9999;
    return json_object_get_int(v);
}

static double jget_double(struct json_object *obj, const char *key) {
    struct json_object *v;
    if (!json_object_object_get_ex(obj, key, &v)) return -9999.0;
    return json_object_get_double(v);
}

/* ── tests ────────────────────────────────────────────────────────── */

static void test_emit_config_static(void) {
    DockConfig cfg;
    config_set_defaults_for_test(&cfg);

    char *buf = capture_emit_config(&cfg);
    ASSERT_TRUE(buf != NULL);

    struct json_object *obj = json_tokener_parse(buf);
    ASSERT_TRUE(obj != NULL);

    ASSERT_STR_EQ(jget_str(obj, "type"),     "config");
    ASSERT_STR_EQ(jget_str(obj, "mode"),     "static");
    ASSERT_STR_EQ(jget_str(obj, "position"), "bottom");
    ASSERT_INT_EQ(jget_int(obj, "icon_size"), 48);

    json_object_put(obj);
    free(buf);
    config_free_fields(&cfg);
}

static void test_emit_config_snappy(void) {
    DockConfig cfg;
    config_set_defaults_for_test(&cfg);
    config_apply_ini_key_for_test(&cfg, "dock", "Mode", "snappy");
    config_validate_mode_for_test(&cfg);

    char *buf = capture_emit_config(&cfg);
    ASSERT_TRUE(buf != NULL);

    struct json_object *obj = json_tokener_parse(buf);
    ASSERT_TRUE(obj != NULL);

    ASSERT_STR_EQ(jget_str(obj, "mode"), "snappy");

    json_object_put(obj);
    free(buf);
    config_free_fields(&cfg);
}

static void test_emit_config_fields(void) {
    DockConfig cfg;
    config_set_defaults_for_test(&cfg);

    char *buf = capture_emit_config(&cfg);
    ASSERT_TRUE(buf != NULL);

    struct json_object *obj = json_tokener_parse(buf);
    ASSERT_TRUE(obj != NULL);

    ASSERT_STR_EQ(jget_str(obj, "alignment"),    "center");
    ASSERT_STR_EQ(jget_str(obj, "launcher_cmd"), "fuzzel");
    ASSERT_INT_EQ(jget_int(obj, "workspace_count"), 5);
    ASSERT_INT_EQ(jget_int(obj, "margin_bottom"),   5);
    ASSERT_INT_EQ(jget_int(obj, "spread"),           3);
    ASSERT_INT_EQ(jget_int(obj, "icon_spacing"),     2);
    ASSERT_TRUE(jget_double(obj, "magnification") > 0.77 && jget_double(obj, "magnification") < 0.79);

    json_object_put(obj);
    free(buf);
    config_free_fields(&cfg);
}

static void test_emit_state_empty(void) {
    DockState s;
    state_init(&s);

    char *buf = capture_emit_state(&s);
    ASSERT_TRUE(buf != NULL);

    struct json_object *obj = json_tokener_parse(buf);
    ASSERT_TRUE(obj != NULL);

    ASSERT_STR_EQ(jget_str(obj, "type"), "state");

    struct json_object *clients;
    ASSERT_TRUE(json_object_object_get_ex(obj, "clients", &clients));
    ASSERT_INT_EQ((int)json_object_array_length(clients), 0);

    struct json_object *pinned;
    ASSERT_TRUE(json_object_object_get_ex(obj, "pinned", &pinned));
    ASSERT_INT_EQ((int)json_object_array_length(pinned), 0);

    json_object_put(obj);
    free(buf);
    state_free(&s);
}

static void test_emit_state_with_client(void) {
    DockState s;
    state_init(&s);

    s.client_cap = 4;
    s.clients = calloc(4, sizeof(DockClient));
    s.clients[0].addr         = strdup("0xABCD");
    s.clients[0].class_name   = strdup("firefox");
    s.clients[0].title        = strdup("Home");
    s.clients[0].icon         = strdup("firefox");
    s.clients[0].workspace_id = 1;
    s.clients[0].is_active    = true;
    s.client_count = 1;
    s.active_addr  = strdup("0xABCD");
    s.active_ws    = 1;

    char *buf = capture_emit_state(&s);
    ASSERT_TRUE(buf != NULL);

    struct json_object *obj = json_tokener_parse(buf);
    ASSERT_TRUE(obj != NULL);

    struct json_object *clients;
    ASSERT_TRUE(json_object_object_get_ex(obj, "clients", &clients));
    ASSERT_INT_EQ((int)json_object_array_length(clients), 1);

    struct json_object *c0 = json_object_array_get_idx(clients, 0);
    ASSERT_TRUE(c0 != NULL);
    ASSERT_STR_EQ(jget_str(c0, "class"), "firefox");

    json_object_put(obj);
    free(buf);
    state_free(&s);
}

/* ── main ─────────────────────────────────────────────────────────── */

int main(void) {
    fprintf(stderr, "\n=== Protocol Tests ===\n");

    TEST(test_emit_config_static);
    TEST(test_emit_config_snappy);
    TEST(test_emit_config_fields);
    TEST(test_emit_state_empty);
    TEST(test_emit_state_with_client);

    fprintf(stderr, "\n  %d / %d tests passed\n\n", tests_passed, tests_run);
    return (tests_passed == tests_run) ? 0 : 1;
}
