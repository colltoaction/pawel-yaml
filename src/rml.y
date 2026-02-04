%{
void rml_error(const char *s);
int rml_lex(void);
%}

%token RML_STR_START RML_STR_END
%token RML_DOC_START RML_DOC_END
%token RML_SEQ_START RML_SEQ_END
%token RML_MAP_START RML_MAP_END
%token RML_SCALAR RML_ALIAS

%%

stream: RML_STR_START docs RML_STR_END ;

docs: 
    | docs doc
    ;

doc: 
    RML_DOC_START node RML_DOC_END
    | node
    ;

node: 
    RML_SCALAR
    | RML_ALIAS
    | RML_SEQ_START seq_items RML_SEQ_END
    | RML_MAP_START map_pairs RML_MAP_END
    ;

seq_items:
    | seq_items node
    ;

map_pairs:
    | map_pairs node node
    ;

%%

void rml_error(const char *s) {
    /* Grammar validation error */
}
