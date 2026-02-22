#ifndef YAML_BISON_COMPAT_H
#define YAML_BISON_COMPAT_H

/* Stable fallback values when generated parser headers are not in scope. */
#ifndef YYEMPTY
#define YYEMPTY -2
#endif

#ifndef YYEOF
#define YYEOF 0
#endif

#ifndef YYACCEPT
#define YYACCEPT 0
#endif

#ifndef YYABORT
#define YYABORT 1
#endif

#ifndef YYTERROR
#define YYTERROR 1
#endif

#ifndef YYERRCODE
#define YYERRCODE 256
#endif

typedef int YAMLBisonToken;

typedef struct {
    YAMLBisonToken token;
} YAMLTokenRef;

static inline YAMLTokenRef yaml_token_ref(YAMLBisonToken token) {
    YAMLTokenRef ref;
    ref.token = token;
    return ref;
}

#endif /* YAML_BISON_COMPAT_H */
