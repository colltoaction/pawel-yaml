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

stream: RML_STR_START[start] docs[list] RML_STR_END[end] ;

docs: 
    | docs[head] doc[tail]
    ;

doc: 
    RML_DOC_START[start] node[body] RML_DOC_END[end]
    | node[content]
    ;

node: 
    RML_SCALAR[val]
    | RML_ALIAS[ref]
    | RML_SEQ_START[start] seq_items[items] RML_SEQ_END[end]
    | RML_MAP_START[start] map_pairs[pairs] RML_MAP_END[end]
    ;

seq_items:
    | seq_items[head] node[item]
    ;

map_pairs:
    | map_pairs[head] node[key] node[value]
    ;

%%

void rml_error(const char *s) {
    /* Grammar validation error */
}
