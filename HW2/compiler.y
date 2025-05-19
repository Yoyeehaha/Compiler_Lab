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

    typedef struct {
        char name[64];
        int mut;
        char type[16];
        int addr;
        int lineno;
        char func_sig[32]; 
    } Symbol;

    Symbol symbol_tables[10][100]; // 10 levels max, 100 symbols each
    int symbol_count[10];          // 每層目前有幾個 symbol

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
    static Symbol* lookup_symbol();
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
    : { create_symbol(0); } FUNC { printf("func: main\n"); } ID { insert_symbol(addr, "main", -1, 0); } { addr++; level++;} { create_symbol(1); } '(' ')' '{' Content { dump_symbol(level--); } '}' { dump_symbol(level--); }
;


Content
    : Content Statement
    |
;


Statement
    : PRINTLN '(' Expr ')' ';' { printf("PRINTLN %s\n", expr_type); } 
    | PRINT '(' Expr ')' ';' { printf("PRINT %s\n", expr_type); } 

    | LET ID ':' Type '=' Expr ';' { insert_symbol(addr, $<s_val>2, 0, level); } { addr++; }
    | LET ID ':' '[' Type ';' Expr ']' '=' '[' Expr ']' ';' { expr_type = "array"; insert_symbol(addr, $<s_val>2, 0, level); } { addr++; }
    | LET MUT ID '=' Expr ';' { insert_symbol(addr, $<s_val>3, 1, level); } { addr++; }
    | LET MUT ID ':' Type '=' Expr ';' { insert_symbol(addr, $<s_val>3, 1, level); } { addr++; }
    | LET MUT ID ':' Type ';' { insert_symbol(addr, $<s_val>3, 1, level); } { addr++; }  

    | '{' { create_symbol(++level); } Content '}' { dump_symbol(level--); }
    | IF Expr '{' { create_symbol(++level); } Content '}' { dump_symbol(level--); }
    | ELSE '{' {create_symbol(++level); } Content '}' { dump_symbol(level--); }
    | WHILE Expr '{' { create_symbol(++level); }Content '}' { dump_symbol(level--); }

    | GiveValueStatement ';'

    | NEWLINE
;


GiveValueStatement
    : ID '=' Expr            { 
                                Symbol* s = lookup_symbol($<s_val>1); 
                                if (s == NULL) { 
                                    printf("error:%d: undefined: %s\n", yylineno + 1, $<s_val>1); 
                                } else if (!(s->mut) && !HAS_ERROR) { 
                                    printf("ASSIGN\n");
                                    printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", yylineno + 1, $<s_val>1); 
                                } else {
                                    printf("ASSIGN\n");
                                    HAS_ERROR = false;
                                }
                             } 
    | ID ADD_ASSIGN Expr     { printf("ADD_ASSIGN\n");  }
    | ID SUB_ASSIGN Expr     { printf("SUB_ASSIGN\n");  }
    | ID MUL_ASSIGN Expr     { printf("MUL_ASSIGN\n");  }
    | ID DIV_ASSIGN Expr     { printf("DIV_ASSIGN\n");  }
    | ID REM_ASSIGN Expr     { printf("REM_ASSIGN\n");  }
    | Expr
;


Expr
    : Expr '+' Expr { printf("ADD\n"); } 
    //Arithmetic operation
    | Expr '-' Expr { printf("SUB\n"); }
    | Expr '*' Expr { printf("MUL\n"); }
    | Expr '/' Expr { printf("DIV\n"); }
    | Expr '%' Expr { printf("REM\n"); }


    //for checking error
    | ID LSHIFT ID    { 
                        Symbol* s1 = lookup_symbol($<s_val>1);
                        Symbol* s2 = lookup_symbol($<s_val>3);
                        printf("IDENT (name=%s, address=%d)\n", s1->name, s1->addr);
                        printf("IDENT (name=%s, address=%d)\n", s2->name, s2->addr);
                        if (strcmp(s1->type, s2->type) != 0) {
                            printf("error:%d: invalid operation: LSHIFT (mismatched types %s and %s)\n", yylineno + 1, s1->type, s2->type);
                            HAS_ERROR = true;
                        } 
                        printf("LSHIFT\n");
                      }
    | ID { Symbol* s = lookup_symbol($<s_val>1); if (s == NULL){ printf("error:%d: undefined: %s\n", yylineno + 1, $<s_val>1);} } '>' Expr { Symbol* s = lookup_symbol($<s_val>1); if (s == NULL) { printf("error:%d: invalid operation: GTR (mismatched types undefined and i32)\n", yylineno + 1); } printf("GTR\n"); }


    //Comparison operation
    | Expr '>' Expr   { printf("GTR\n"); }
    | Expr GEQ Expr   { printf("GEQ\n"); }
    | Expr '<' Expr   { printf("LSS\n"); }
    | Expr LEQ Expr   { printf("LEQ\n"); }
    | Expr EQL Expr   { printf("EQL\n"); }
    | Expr NEQ Expr   { printf("NEQ\n"); }


    //Logical operation
    | Expr LAND Expr  { printf("LAND\n"); }
    | Expr LOR  Expr  { printf("LOR\n"); }


    //AS operation
    | Expr AS Type    { 
                        if (strcmp($<s_val>3, "i32") == 0) {
                            printf("f2i\n"); expr_type = "i32";
                        } else {
                            printf("i2f\n"); expr_type = "f32";
                        }
                      }
                      

    //unary operation
    | '!' Expr  %prec NOT_UMINUS  { printf("NOT\n"); }
    | '-' Expr  %prec NOT_UMINUS  { printf("NEG\n"); }
    | '(' Expr ')'


    //for array
    | Expr ',' Expr 
    | ID '[' { Symbol* s = lookup_symbol($<s_val>1); printf("IDENT (name=%s, address=%d)\n", s->name, s->addr); } Expr ']' { expr_type = "array"; }


    //for ID and Literal
    | ID { 
           Symbol* s = lookup_symbol($<s_val>1); 
           if (s == NULL){
               printf("error:%d: undefined: %s\n", yylineno + 1, $<s_val>1);
           } else {
               printf("IDENT (name=%s, address=%d)\n", s->name, s->addr);
               expr_type = s->type; 
           }
         }
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
    : INT {$$ = "i32"; expr_type = "i32";}
    | FLOAT {$$ = "f32"; expr_type = "f32";}
    | BOOL {$$ = "bool"; expr_type = "bool";}
    | STR {$$ = "str"; expr_type = "str";}
    | '&' STR {$$ = "str"; expr_type = "str";}
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

// To create a new symbol table
static void create_symbol(int sc_level) {
    symbol_count[sc_level] = 0;
    printf("> Create symbol table (scope level %d)\n", sc_level);
}

// To insert a new symbol into the symbol table
static void insert_symbol(int addr, char* name, int mut, int sc_level) {
    Symbol s;
    strcpy(s.name, name);
    strcpy(s.type, expr_type);
    s.addr = addr;
    s.mut = mut;
    s.lineno = yylineno + 1;
    if (sc_level == 0) {
        strcpy(s.type, "func");
        strcpy(s.func_sig, "(V)V");
    } else {
        strcpy(s.func_sig, "-");
    }
    
    symbol_tables[sc_level][symbol_count[sc_level]++] = s;
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, addr, sc_level);
}

// To lookup the right symbol
static Symbol* lookup_symbol(const char* name) {
    for (int i = level; i >= 0; i--) {
        for (int j = 0; j < symbol_count[i]; j++) {
            if (strcmp(symbol_tables[i][j].name, name) == 0) {
                return &symbol_tables[i][j];
            }
        }
    }

    return NULL;  //avoid warning
}

// To dump the symbol table
static void dump_symbol(int sc_level) {
    printf("\n> Dump symbol table (scope level: %d)\n", sc_level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    for (int i = 0; i < symbol_count[sc_level]; i++) {
        Symbol* s = &symbol_tables[sc_level][i];
        printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n", i, s->name, s->mut, s->type, s->addr, s->lineno, s->func_sig);
    }
}
