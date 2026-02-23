%include "stream_header.l.inc"

%%

%include "lexer_core.l.inc"

%%

int scanning_lex_init_extra(void *user_defined, void **scanner) {
    return yylex_init_extra((LexerContext *)user_defined, scanner);
}
