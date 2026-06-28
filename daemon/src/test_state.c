#define _POSIX_C_SOURCE 200809L
#include "state.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ── test framework macros ─────────────────────────────────────────── */

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { tests_run++; fprintf(stderr, "  %-50s ", #name); name(); tests_passed++; fprintf(stderr, "PASS\n"); } while(0)

#define ASSERT_STR_EQ(a, b) do { if (strcmp((a), (b)) != 0) { fprintf(stderr, "FAIL\n    Expected: \"%s\"\n    Got:      \"%s\"\n    at %s:%d\n", (b), (a), __FILE__, __LINE__); exit(1); } } while(0)

#define ASSERT_INT_EQ(a, b) do { if ((a) != (b)) { fprintf(stderr, "FAIL\n    Expected: %d\n    Got:      %d\n    at %s:%d\n", (b), (a), __FILE__, __LINE__); exit(1); } } while(0)

#define ASSERT_TRUE(expr) do { if (!(expr)) { fprintf(stderr, "FAIL\n    Assertion failed: %s\n    at %s:%d\n", #expr, __FILE__, __LINE__); exit(1); } } while(0)

#define ASSERT_NULL(ptr) do { if ((ptr) != NULL) { fprintf(stderr, "FAIL\n    Expected NULL\n    at %s:%d\n", __FILE__, __LINE__); exit(1); } } while(0)

/* ── helper to manually add clients ────────────────────────────────── */

static void add_test_client(DockState *s, const char *addr, const char *cls,
                            const char *title, int ws) {
    if (s->client_count >= s->client_cap) {
        s->client_cap = s->client_cap ? s->client_cap * 2 : 8;
        s->clients = realloc(s->clients, (size_t)s->client_cap * sizeof(DockClient));
    }
    DockClient *c = &s->clients[s->client_count++];
    c->addr = strdup(addr);
    c->class_name = strdup(cls);
    c->title = strdup(title);
    c->icon = strdup("test-icon");
    c->workspace_id = ws;
    c->is_active = false;
    c->is_floating = false;
    c->is_fullscreen = false;
}

/* ── tests ─────────────────────────────────────────────────────────── */

static void test_state_init_free(void) {
    DockState s;
    state_init(&s);
    ASSERT_INT_EQ(s.client_count, 0);
    ASSERT_INT_EQ(s.pinned_count, 0);
    ASSERT_NULL(s.active_addr);
    state_free(&s);
}

static void test_add_and_find(void) {
    DockState s;
    state_init(&s);
    add_test_client(&s, "0xAABB", "firefox", "Mozilla", 1);

    ASSERT_INT_EQ(state_instance_count(&s, "firefox"), 1);

    const DockClient *c = state_first_instance(&s, "firefox");
    ASSERT_TRUE(c != NULL);
    ASSERT_STR_EQ(c->class_name, "firefox");

    state_free(&s);
}

static void test_closewindow(void) {
    DockState s;
    state_init(&s);
    add_test_client(&s, "0xAA", "kitty", "Terminal", 1);
    add_test_client(&s, "0xBB", "firefox", "Browser", 1);

    bool removed = state_on_closewindow(&s, "AA");
    ASSERT_TRUE(removed);
    ASSERT_INT_EQ(s.client_count, 1);
    ASSERT_STR_EQ(s.clients[0].addr, "0xBB");

    state_free(&s);
}

static void test_closewindow_nonexistent(void) {
    DockState s;
    state_init(&s);
    add_test_client(&s, "0xAA", "kitty", "Terminal", 1);

    bool removed = state_on_closewindow(&s, "DEAD");
    ASSERT_TRUE(!removed);
    ASSERT_INT_EQ(s.client_count, 1);

    state_free(&s);
}

static void test_activewindow(void) {
    DockState s;
    state_init(&s);
    add_test_client(&s, "0xAA", "kitty", "Terminal", 1);

    state_on_activewindow(&s, "AA");
    ASSERT_STR_EQ(s.active_addr, "0xAA");
    ASSERT_TRUE(s.clients[0].is_active);

    state_free(&s);
}

static void test_workspace_change(void) {
    DockState s;
    state_init(&s);
    s.active_ws = 1;

    state_on_workspace(&s, "3");
    ASSERT_INT_EQ(s.active_ws, 3);

    state_free(&s);
}

static void test_instance_count_multi(void) {
    DockState s;
    state_init(&s);
    add_test_client(&s, "0x01", "firefox", "Tab 1", 1);
    add_test_client(&s, "0x02", "firefox", "Tab 2", 1);
    add_test_client(&s, "0x03", "firefox", "Tab 3", 2);
    add_test_client(&s, "0x04", "kitty", "Terminal", 1);

    ASSERT_INT_EQ(state_instance_count(&s, "firefox"), 3);
    ASSERT_INT_EQ(state_instance_count(&s, "kitty"), 1);
    ASSERT_INT_EQ(state_instance_count(&s, "nonexistent"), 0);

    state_free(&s);
}

static void test_first_instance_null(void) {
    DockState s;
    state_init(&s);

    ASSERT_NULL(state_first_instance(&s, "any"));
    ASSERT_NULL(state_first_instance(&s, NULL));

    state_free(&s);
}

static void test_focusedmon(void) {
    DockState s;
    state_init(&s);

    state_on_focusedmon(&s, "DP-1,1");
    ASSERT_STR_EQ(s.active_mon, "DP-1");

    state_free(&s);
}

/* ── main ──────────────────────────────────────────────────────────── */

int main(void) {
    fprintf(stderr, "\n=== State Tests ===\n");

    TEST(test_state_init_free);
    TEST(test_add_and_find);
    TEST(test_closewindow);
    TEST(test_closewindow_nonexistent);
    TEST(test_activewindow);
    TEST(test_workspace_change);
    TEST(test_instance_count_multi);
    TEST(test_first_instance_null);
    TEST(test_focusedmon);

    fprintf(stderr, "\n  %d/%d tests passed\n\n", tests_passed, tests_run);
    return (tests_passed == tests_run) ? 0 : 1;
}
