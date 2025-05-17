/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h"
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    int addr = -1, level = 0;
    static const char* expr_type = "i32";
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Symbol table function - you can add new functions if needed. */
    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol();
    static void lookup_symbol();
    static void dump_symbol();

    /* Global variables */
    bool HAS_ERROR = false;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
%token TRUE FALSE
%token GEQ LEQ EQL NEQ LOR LAND
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN
%token IF ELSE FOR WHILE LOOP
%token PRINT PRINTLN
%token FUNC RETURN BREAK
%token ID ARROW AS IN DOTDOT RSHIFT LSHIFT

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT
%token <s_val> IDENT

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type

/* decide the priority (form low to high) */
%left  LOR
%left  LAND
%nonassoc EQL NEQ '>' GEQ '<' LEQ
%left  '+' '-'
%left  '*' '/' '%'
%right  NOT_UMINUS //To rise the priority of 'NOT' 

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : FunctionDeclStmt
    | NEWLINE
;

FunctionDeclStmt
    : { create_symbol(0); } FUNC { printf("func: main\n"); } ID { insert_symbol(addr, "main", 0); } { addr++; level++;} { create_symbol(1); } '(' ')' '{' Content '}' { dump_symbol(--level); }
;

Content
    : Content Statement
    |
;

Statement
    : PRINTLN '(' '"' STRING_LIT '"' ')' ';' { printf("STRING_LIT"); } { printf("\"%s\"\n", $<s_val>4); } { printf("PRINTLN str\n"); } 
    | PRINTLN '(' Expr ')' ';' { printf("PRINTLN %s\n", expr_type); } 
    | PRINT '(' Expr ')' ';' { printf("PRINT %s\n", expr_type); } 
    | LET ID ':' Type '=' Expr ';' { insert_symbol(addr, $<s_val>2, level); } { addr++; }
    | LET MUT ID ':' Type '=' Expr ';' { insert_symbol(addr, $<s_val>3, level); } { addr++; }
    | LET MUT ID ':' Type ';' { insert_symbol(addr, $<s_val>3, level); } { addr++; }  
    | '{' { create_symbol(++level); } Content '}' { dump_symbol(level--); }
    | GiveValueStatement ';'
    | NEWLINE
;

GiveValueStatement
    : ID '=' Expr          { printf("ASSIGN\n");  }
    | ID ADD_ASSIGN Expr     { printf("ADD_ASSIGN\n");  }
    | ID SUB_ASSIGN Expr     { printf("SUB_ASSIGN\n");  }
    | ID MUL_ASSIGN Expr     { printf("MUL_ASSIGN\n");  }
    | ID DIV_ASSIGN Expr     { printf("DIV_ASSIGN\n");  }
    | ID REM_ASSIGN Expr     { printf("REM_ASSIGN\n");  }
    | Expr
;

Expr
    : Expr '+' Expr { printf("ADD\n"); } 
    | Expr '-' Expr { printf("SUB\n"); }
    | Expr '*' Expr { printf("MUL\n"); }
    | Expr '/' Expr { printf("DIV\n"); }
    | Expr '%' Expr { printf("REM\n"); }

    | Expr '>' Expr   { printf("GTR\n"); }
    | Expr GEQ Expr   { printf("GEQ\n"); }
    | Expr '<' Expr   { printf("LSS\n"); }
    | Expr LEQ Expr   { printf("LEQ\n"); }
    | Expr EQL Expr   { printf("EQL\n"); }
    | Expr NEQ Expr   { printf("NEQ\n"); }

    | Expr LAND Expr  { printf("LAND\n"); }
    | Expr LOR  Expr  { printf("LOR\n"); }

    | Expr AS Type    { if (strcmp(expr_type, "f32") == 0 && strcmp($<s_val>3, "i32") == 0) {
                            printf("f2i\n"); expr_type = "i32";
                        } else {
                            printf("i2f\n"); expr_type = "f32";
                        }
                      }

    | '!' Expr  %prec NOT_UMINUS  { printf("NOT\n"); }
    | '-' Expr        { printf("NEG\n"); }
    | '(' Expr ')'

    | ID { printf("IDENT (name=%s, address=%d)\n", $<s_val>1, addr); }
    | Literal
;

//Using this to avoid public prefix problem
Literal 
    : INT_LIT { printf("INT_LIT "); expr_type = "i32"; } { printf("%d\n", $<i_val>1); }
    | FLOAT_LIT { printf("FLOAT_LIT "); expr_type = "f32"; } { printf("%f\n", $<f_val>1); }
    | '\"' STRING_LIT '\"'{ printf("STRING_LIT "); expr_type = "str"; } { printf("\"%s\"\n", $<s_val>2); }
    | '\"' '\"'{ printf("STRING_LIT "); expr_type = "str"; } { printf("\"\"\n"); }
    | TRUE { printf("bool TRUE\n"); expr_type = "bool"; }
    | FALSE { printf("bool FALSE\n"); expr_type = "bool"; }
;

Type
    : INT {$$ = "i32";}
    | FLOAT {$$ = "f32";}
    | BOOL {$$ = "bool";}
    | STR {$$ = "str";}
    | '&' STR {$$ = "str";}
;
%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    yylineno = 0;
    yyparse();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol(int sc_level) {
    printf("> Create symbol table (scope level %d)\n", sc_level);
}

static void insert_symbol(int addr, char* name, int sc_level) {
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, addr, sc_level);
}

static void lookup_symbol() {
}

static void dump_symbol(int sc_level) {
    printf("\n> Dump symbol table (scope level: %d)\n", sc_level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
            0, "name", 0, "type", 0, 0, "func_sig");
}
