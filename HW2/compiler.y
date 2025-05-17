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
    : { create_symbol(0); } FUNC { printf("func: main\n"); } ID { insert_symbol(addr, "main", 0); } { addr++; level++;} { create_symbol(1); } '(' ')' '{' Content '}'
;

Content
    : PRINTLN '(' '"' STRING_LIT '"' ')' ';' { printf("STRING_LIT"); } { printf(" \""); } { printf("%s", $<s_val>4); } { printf("\"\n"); } { printf("PRINTLN str\n"); } 
    | PRINTLN '(' ARITHMETIC ')' ';' { printf("PRINTLN %s\n", $<s_val>3); } 
    | LET ID ':' TypeList ';' { insert_symbol(addr, $<s_val>2, level); } { addr++; } 
    | Content Content
;

ARITHMETIC
    : ID '+' ID { printf("IDENT (name=%s, address=%d)\n", $<s_val>1, addr); } { printf("IDENT (name=%s, address=%d)\n", $<s_val>3, addr); } { printf("ADD\n"); } 
    | ID '-' ID { printf("IDENT (name=%s, address=%d)\n", $<s_val>1, addr); } { printf("IDENT (name=%s, address=%d)\n", $<s_val>3, addr); } { printf("SUB\n"); }
    | ID '*' ID { printf("IDENT (name=%s, address=%d)\n", $<s_val>1, addr); } { printf("IDENT (name=%s, address=%d)\n", $<s_val>3, addr); } { printf("MUL\n"); }
    | ID '/' ID { printf("IDENT (name=%s, address=%d)\n", $<s_val>1, addr); } { printf("IDENT (name=%s, address=%d)\n", $<s_val>3, addr); } { printf("DIV\n"); }
    | ID '%' ID { printf("IDENT (name=%s, address=%d)\n", $<s_val>1, addr); } { printf("IDENT (name=%s, address=%d)\n", $<s_val>3, addr); } { printf("REM\n"); }
;

TypeList
    : Type '=' Literal
;  

//Using this to avoid public prefix problem
Literal 
    : INT_LIT { printf("INT_LIT "); } { printf("%d\n", $<i_val>1); }
    | FLOAT_LIT { printf("FLOAT_LIT "); } { printf("%f\n", $<f_val>1); }
    | STRING_LIT { printf("STRING_LIT "); } { printf("%s\n", $<s_val>1); }

Type
    : INT {$$ = "i32";}
    | FLOAT {$$ = "f32";}
    | BOOL {$$ = "bool";}
    | STR {$$ = "str";}
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

static void dump_symbol() {
    printf("\n> Dump symbol table (scope level: %d)\n", 0);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
            0, "name", 0, "type", 0, 0, "func_sig");
}
