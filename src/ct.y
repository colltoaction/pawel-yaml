%define api.prefix {ct_yy_}
%define parse.error verbose

%start parser

%{
int ct_yy_lex(void);
void ct_yy_error(const char *s);
%}

%token GENERATOR
%token STAR
%token SEMI
%token OPEN
%token CLOSE

%%

parser:
    monoid YYEOF
    ;

gamma:
    GENERATOR
    ;

monoid:
    language
    ;

language:
    unit
    | gamma
    | tensor_expr
    | compose_expr
    | boundary_expr
    ;

unit:
    %empty
    ;

tensor_expr:
    language tensor language
    ;

compose_expr:
    language compose language
    ;

boundary_expr:
    open language close
    | open close
    ;

tensor:
    STAR
    ;

compose:
    SEMI
    ;

open:
    OPEN
    ;

close:
    CLOSE
    ;

%%

int ct_yy_lex(void) {
    return 0;
}

void ct_yy_error(const char *s) {
    (void)s;
}
