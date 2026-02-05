#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* YAML Pipeline Stages */
extern int stream_parse(void);      /* Presentation -> Events (Stage 1) */
extern int compose_events(void);    /* Events -> Representation (Stage 2) */

int main(int argc, char **argv) {
    /* Mode selection via command-line flags */
    if (argc > 1 && strcmp(argv[1], "-dump-tokens") == 0) {
        /* Output event stream only */
        return stream_parse();
    }
    
    if (argc > 1 && strcmp(argv[1], "-ast-dump") == 0) {
        /* Output IR representation */
        return stream_parse() || compose_events();
    }
    
    if (argc > 1 && (strcmp(argv[1], "-help") == 0 || strcmp(argv[1], "-h") == 0)) {
        fprintf(stderr, "Usage: %s [OPTIONS]\n", argv[0]);
        fprintf(stderr, "  -dump-tokens   Output event stream\n");
        fprintf(stderr, "  -ast-dump      Output IR representation\n");
        return 0;
    }
    
    if (argc > 1) {
        /* Unknown option */
        fprintf(stderr, "Unknown option: %s\n", argv[1]);
        return 1;
    }
    
    /* Default: full parse to representation */
    return stream_parse() || compose_events();
}
