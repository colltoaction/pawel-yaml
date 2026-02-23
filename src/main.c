#include "common.h"
#include <string.h>

static YAMLProcessorOptions processor_options_from_argv(int argc, char **argv) {
    YAMLProcessorOptions options;
    int i;

    options.parse_node = 0;
    options.dump_tokens = 0;
    options.emit_yaml = 0;
    options.ast_dump = 0;

    if (!argv || argc <= 1) return options;
    for (i = 1; i < argc; i++) {
        if (!argv[i]) continue;
        if (strcmp(argv[i], "-parse-node") == 0) options.parse_node = 1;
        if (strcmp(argv[i], "-dump-tokens") == 0) options.dump_tokens = 1;
        if (strcmp(argv[i], "-emit-yaml") == 0) options.emit_yaml = 1;
        if (strcmp(argv[i], "-ast-dump") == 0) options.ast_dump = 1;
    }
    return options;
}

/* YAML Compilation Pipeline */
int main(int argc, char **argv) {
    YAMLProcessorOptions options = processor_options_from_argv(argc, argv);
    return yaml_processor_run(&options);
}
