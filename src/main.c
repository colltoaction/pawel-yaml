#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Stage 1: Parse - Presentation -> Events */
extern int yaml_parse(void);
/* Stage 2: Compose - Events -> Representation */
extern int yaml_compose(void);
/* Stage 3: Serialize - Representation -> Events */
extern int yaml_serialize(void);
/* Stage 4: Present - Events -> Presentation */
extern int yaml_present(void);

/* YAML Compilation Pipeline */
int main(int argc, char **argv) {
    (void)argc; (void)argv;
    
    if (yaml_parse() != 0) return 1;
    if (yaml_compose() != 0) return 1;
    if (yaml_serialize() != 0) return 1;

    return yaml_present();
}
