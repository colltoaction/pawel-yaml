// https://yaml.org/spec/1.2.2/#chapter-3-processes-and-models
// YAML is both a text format and a method for presenting any native data
// structure in this format. A YAML processor converts information between these
// views on behalf of an application.

#include "common.h"

/* Processor grammar:
 *   processor        -> stream_monoid bison_gamma doc_monoid cmain_gamma
 *   bison_gamma      -> YYEOF
 *   cmain_gamma      -> EXIT_SUCCESS
 *   stream_monoid    -> YAML stream parser path
 *   doc_monoid       -> YAML compose/serialize/present path
 */

static int processor_bison_gamma(void) {
    return YAML_PROCESSOR_GAMMA_YYEOF;
}

static int processor_cmain_gamma(void) {
    return YAML_PROCESSOR_GAMMA_EXIT_SUCCESS;
}

static int processor_stream_monoid(const YAMLProcessorOptions *options) {
    return (yaml_parse(options) == 0)
        ? processor_bison_gamma()
        : EXIT_FAILURE;
}

static int processor_doc_monoid(const YAMLProcessorOptions *options) {
    return (yaml_compose() == 0 && yaml_serialize(options) == 0 && yaml_present() == 0)
        ? processor_cmain_gamma()
        : EXIT_FAILURE;
}

int yaml_processor_run(const YAMLProcessorOptions *options) {
    int stream_word = processor_stream_monoid(options);
    if (stream_word != processor_bison_gamma()) {
        return EXIT_FAILURE;
    }
    return (processor_doc_monoid(options) == processor_cmain_gamma())
        ? EXIT_SUCCESS
        : EXIT_FAILURE;
}

int yaml_processor_drive_lex(
    YAMLDriveLexFn lex_fn,
    void *yylval_param,
    void *yyloc_param,
    void *scanner) {
    return lex_fn(yylval_param, yyloc_param, scanner);
}

int yaml_processor_drive_parse(
    YAMLDriveParseFn parse_fn,
    void *scanner) {
    return parse_fn(scanner);
}

void yaml_processor_raise_error(
    YAMLErrorFn error_fn,
    void *scanner,
    const char *msg) {
    error_fn(NULL, scanner, msg);
}
