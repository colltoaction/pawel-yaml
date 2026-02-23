#include <stdlib.h>
#include <string.h>
#include "stream.tab.h"

typedef struct InternedStringNode {
    char *value;
    struct InternedStringNode *next;
} InternedStringNode;

static InternedStringNode *string_pool_head = NULL;

static char *string_pool_track(char *value) {
    InternedStringNode *node;

    if (!value) {
        return NULL;
    }

    node = (InternedStringNode*)malloc(sizeof(InternedStringNode));
    if (!node) {
        free(value);
        return NULL;
    }

    node->value = value;
    node->next = string_pool_head;
    string_pool_head = node;
    return value;
}

char *string_intern(const char *input) {
    const char *source = input ? input : "";
    InternedStringNode *node;

    for (node = string_pool_head; node; node = node->next) {
        if (strcmp(node->value, source) == 0) {
            return node->value;
        }
    }

    return string_pool_track(strdup(source));
}

char *string_unit(void) {
    return string_intern("");
}

char *string_intern_slice(const char *start, size_t len) {
    char *copy;

    if (!start) {
        return string_unit();
    }

    copy = (char*)malloc(len + 1);
    if (!copy) {
        return NULL;
    }
    memcpy(copy, start, len);
    copy[len] = '\0';
    return string_pool_track(copy);
}

char *string_concat(const char *left, const char *right) {
    const char *lhs = left ? left : "";
    const char *rhs = right ? right : "";
    size_t lhs_len = strlen(lhs);
    size_t rhs_len = strlen(rhs);
    char *joined = (char*)malloc(lhs_len + rhs_len + 1);

    if (!joined) {
        return NULL;
    }

    memcpy(joined, lhs, lhs_len);
    memcpy(joined + lhs_len, rhs, rhs_len);
    joined[lhs_len + rhs_len] = '\0';
    return string_pool_track(joined);
}

void string_pool_reset(void) {
    InternedStringNode *node = string_pool_head;
    while (node) {
        InternedStringNode *next = node->next;
        free(node->value);
        free(node);
        node = next;
    }
    string_pool_head = NULL;
}
