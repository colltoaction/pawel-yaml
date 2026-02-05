#include <stdio.h>
#include "yaml.tab.h"

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    yaml_pipeline_run(stdin, stdout);
    return 0;
}

