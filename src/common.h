#ifndef YAML_COMMON_H
#define YAML_COMMON_H

#include "bison_compat.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BISON_GAMMA         YYEOF
#define YAML_GAMMA          BISON_GAMMA

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

/*
 * Monoidal alphabet Γ:
 * - token: Bison token id (scanner/parser contract)
 * - event: semantic event carried by that symbol when available
 */
typedef struct {
    YAMLTokenRef token;
    YAMLEventType event;
} YAMLAlphabetSymbol;

typedef struct {
    const YAMLAlphabetSymbol *symbols;
    size_t count;
} YAMLAlphabet;

static inline YAMLAlphabetSymbol yaml_gamma_event(YAMLEventType event) {
    YAMLAlphabetSymbol symbol;
    symbol.token = yaml_token_ref((YAMLBisonToken)event);
    symbol.event = event;
    return symbol;
}

static inline YAMLAlphabetSymbol yaml_gamma_token(YAMLBisonToken token) {
    YAMLAlphabetSymbol symbol;
    symbol.token = yaml_token_ref(token);
    symbol.event = (YAMLEventType)-1;
    return symbol;
}

static inline YAMLAlphabet yaml_alphabet_gamma(void) {
    static const YAMLAlphabetSymbol gamma_symbols[] = {
        { { EVENT_STREAM_START }, EVENT_STREAM_START },
        { { EVENT_STREAM_END }, EVENT_STREAM_END },
        { { EVENT_DOCUMENT_START }, EVENT_DOCUMENT_START },
        { { EVENT_DOCUMENT_END }, EVENT_DOCUMENT_END },
        { { EVENT_SEQUENCE_START }, EVENT_SEQUENCE_START },
        { { EVENT_SEQUENCE_END }, EVENT_SEQUENCE_END },
        { { EVENT_MAPPING_START }, EVENT_MAPPING_START },
        { { EVENT_MAPPING_END }, EVENT_MAPPING_END },
        { { EVENT_SCALAR }, EVENT_SCALAR },
        { { EVENT_ALIAS }, EVENT_ALIAS },
        { { YAML_GAMMA }, (YAMLEventType)-1 }
    };
    YAMLAlphabet gamma;
    gamma.symbols = gamma_symbols;
    gamma.count = sizeof(gamma_symbols) / sizeof(gamma_symbols[0]);
    return gamma;
}

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
    char *anchor;
    char *tag;
} ScalarValue;

typedef struct {
    int parse_node;
    int dump_tokens;
    int emit_yaml;
    int ast_dump;
} YAMLProcessorOptions;

/* Processor alphabet generators:
 * - C main closure generator
 * - Bison parser closure generator
 * - YAML stream/doc monoid markers
 */
typedef enum {
    YAML_PROCESSOR_GAMMA_EXIT_SUCCESS = EXIT_SUCCESS,
    YAML_PROCESSOR_GAMMA_YYEOF = YYEOF,
    YAML_PROCESSOR_MONOID_STREAM = EVENT_STREAM_START,
    YAML_PROCESSOR_MONOID_DOC = EVENT_DOCUMENT_START
} YAMLProcessorGenerator;

/* Processor-level parser driving helpers (folded from yaml_bison_control.h). */
typedef int (*YAMLDriveLexFn)(void *, void *, void *);
typedef int (*YAMLDriveParseFn)(void *);
typedef void (*YAMLErrorFn)(void *, void *, const char *);

/* Pipeline stage exports */
int yaml_parse(const YAMLProcessorOptions *options);
int yaml_parse_buffer(const char *input);
int yaml_parse_buffer_probe(const char *input);
int yaml_compose(void);
int yaml_serialize(const YAMLProcessorOptions *options);
int yaml_present(void);
int yaml_processor_run(const YAMLProcessorOptions *options);

/* Stage driving artifacts (owned runtime buffers). */
void yaml_runtime_reset_artifacts(void);
void yaml_runtime_set_serialization_tree(char *owned_text);
const char *yaml_runtime_serialization_tree(void);
size_t yaml_runtime_serialization_tree_size(void);
int yaml_runtime_has_serialization_tree(void);
void yaml_runtime_set_representation_graph(char *owned_text);
const char *yaml_runtime_representation_graph(void);
size_t yaml_runtime_representation_graph_size(void);
int yaml_runtime_has_representation_graph(void);

int yaml_processor_drive_lex(
    YAMLDriveLexFn lex_fn,
    void *yylval_param,
    void *yyloc_param,
    void *scanner);
int yaml_processor_drive_parse(
    YAMLDriveParseFn parse_fn,
    void *scanner);
void yaml_processor_raise_error(
    YAMLErrorFn error_fn,
    void *scanner,
    const char *msg);

#endif /* YAML_COMMON_H */
