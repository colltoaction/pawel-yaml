#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* YAML Pipeline Stages - Full 4-stage round-trip */
extern int yaml_parse(void);     /* Stage 1: Parse - Presentation -> Events */
extern int yaml_compose(void);   /* Stage 2: Compose - Events -> Representation */
extern int yaml_serialize(void); /* Stage 3: Serialize - Representation -> Events */
extern int yaml_present(void);   /* Stage 4: Present - Events -> Presentation */

int main(int argc, char **argv) {
    if (yaml_parse() != 0) return 1;
    if (argc > 1 && strcmp(argv[1], "-dump-tokens") == 0) return 0;

    if (yaml_compose() != 0) return 1;
    if (argc > 1 && strcmp(argv[1], "-ast-dump") == 0) return 0;

    if (yaml_serialize() != 0) return 1;
    if (argc > 1 && strcmp(argv[1], "-emit-yaml") == 0) return 0;

    return yaml_present();
}
