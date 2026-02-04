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

stream: start:RML_STR_START docs:docs end:RML_STR_END ;

docs: 
    | docs:docs doc:doc
    ;

doc: 
    start:RML_DOC_START node:node end:RML_DOC_END
    | node:node
    ;

node: 
    scalar:RML_SCALAR
    | alias:RML_ALIAS
    | start:RML_SEQ_START items:seq_items end:RML_SEQ_END
    | start:RML_MAP_START pairs:map_pairs end:RML_MAP_END
    ;

seq_items:
    | items:seq_items node:node
    ;

map_pairs:
    | pairs:map_pairs key:node value:node
    ;

%%

void rml_error(const char *s) {
    /* Grammar validation error */
}
