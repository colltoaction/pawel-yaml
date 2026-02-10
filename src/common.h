#ifndef YAML_COMMON_H
#define YAML_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * Stable Event Types (Alphabet for all stages)
 */
typedef enum {
    EVENT_STREAM_START = 300,
    EVENT_STREAM_END,
    EVENT_DOCUMENT_START,
    EVENT_DOCUMENT_END,
    EVENT_SEQUENCE_START,
    EVENT_SEQUENCE_END,
    EVENT_MAPPING_START,
    EVENT_MAPPING_END,
    EVENT_SCALAR,
    EVENT_ALIAS,
} YAMLEventType;

/**
 * Individual YAML event representation
 */
typedef struct {
    YAMLEventType type;
    char quote_style;
    char *value;
    char *anchor;
    char *tag;
    int explicit_start;
    char *alias_name;
} YAMLEvent;

/**
 * Event stream container
 */
typedef struct {
    YAMLEvent **events;
    int count;
    int capacity;
} EventStream;

/**
 * Node properties structure for anchor/tag pairs
 */
typedef struct {
    char *anchor;
    char *tag;
} NodeProps;

/**
 * Scalar value representation for grammar actions
 */
typedef struct {
    char type;
    char *value;
} ScalarValue;

#endif /* YAML_COMMON_H */
