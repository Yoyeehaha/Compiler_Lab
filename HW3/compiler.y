
/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h" //Extern variables that communicate with lex
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

    int addr = -1, level = 0, label_count = 0;
    static const char* expr_type = "i32";
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Used to generate code */
    /* As printf; the usage: CODEGEN("%d - %s\n", 100, "Hello world"); */
    /* We do not enforce the use of this macro */
    #define CODEGEN(...) \
        do { \
            for (int i = 0; i < g_indent_cnt; i++) { \
                fprintf(fout, "\t"); \
            } \
            fprintf(fout, __VA_ARGS__); \
        } while (0)

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol();
    static Symbol* lookup_symbol();
    static void dump_symbol();
    int new_label();

    /* Global variables */
    bool g_has_error = false;
    FILE *fout = NULL;
    int g_indent_cnt = 0;
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
%token ARROW AS IN DOTDOT RSHIFT LSHIFT

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT
%token <s_val> ID

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type

/* decide the priority (form low to high) */
%left LOR
%left LAND
%left EQL NEQ
%left '>' '<' GEQ LEQ
%left '+' '-'
%left '*' '/' '%'
%right NOT_UMINUS //To rise the priority of 'NOT' 

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
    : { create_symbol(0); } FUNC { CODEGEN("\n"); CODEGEN(".method public static main([Ljava/lang/String;)V\n"); } ID { insert_symbol(addr, "main", -1, 0); } { addr++; level++;} { create_symbol(1); CODEGEN(".limit stack 100\n"); CODEGEN(".limit locals 100\n");} '(' ')' '{' Content { dump_symbol(level--); } '}' { CODEGEN("return\n"); CODEGEN(".end method\n"); }
;


Content
    : Content Statement
    |
;


Statement
    : PRINTLN { CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n"); } '(' Expr ')' ';'  { 
                                                                                                        if(strcmp(expr_type, "i32") == 0) { CODEGEN("invokevirtual java/io/PrintStream/println(I)V\n"); } 
                                                                                                        else if(strcmp(expr_type, "f32") == 0) { CODEGEN("invokevirtual java/io/PrintStream/println(F)V\n"); }   
                                                                                                        else if(strcmp(expr_type, "str") == 0) { CODEGEN("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n"); } 
                                                                                                        else if(strcmp(expr_type, "bool") == 0) { CODEGEN("invokevirtual java/io/PrintStream/println(Z)V\n"); } 
                                                                                                       }
    | PRINT { CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n"); } '(' Expr ')' ';'    { 
                                                                                                        if(strcmp(expr_type, "i32") == 0) { CODEGEN("invokevirtual java/io/PrintStream/print(I)V\n"); } 
                                                                                                        else if(strcmp(expr_type, "f32") == 0) { CODEGEN("invokevirtual java/io/PrintStream/print(F)V\n"); }   
                                                                                                        else if(strcmp(expr_type, "str") == 0) { CODEGEN("invokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n"); } 
                                                                                                        else if(strcmp(expr_type, "bool") == 0) { CODEGEN("invokevirtual java/io/PrintStream/print(Z)V\n"); } 
                                                                                                       }

    | LET ID ':' Type '=' Expr ';' { insert_symbol(addr, $<s_val>2, 0, level); } { if (strcmp(expr_type, "i32") == 0) { CODEGEN("istore %d\n", addr); } else if (strcmp(expr_type, "f32") == 0) { CODEGEN("fstore %d\n", addr); }else if (strcmp(expr_type, "str") == 0){ CODEGEN("astore %d\n", addr); }else if (strcmp(expr_type, "bool") == 0) { CODEGEN("istore %d\n", addr); }} { addr++; }
    | LET ID ':' '[' Type ';' Expr ']' '=' '[' Expr ']' ';' { expr_type = "array"; insert_symbol(addr, $<s_val>2, 0, level); } { addr++; }
    | LET MUT ID LetMutId { insert_symbol(addr, $<s_val>3, 1, level); } { if (strcmp(expr_type, "i32") == 0) { CODEGEN("istore %d\n", addr); } else if (strcmp(expr_type, "f32") == 0) { CODEGEN("fstore %d\n", addr); } else if (strcmp(expr_type, "str") == 0){ CODEGEN("astore %d\n", addr); }else if (strcmp(expr_type, "bool") == 0) { CODEGEN("istore %d\n", addr); } } { addr++; }
    | LET MUT ID ':' Type ';' { insert_symbol(addr, $<s_val>3, 1, level); } { addr++; }

    | '{' { create_symbol(++level); } Content '}' { dump_symbol(level--); }
    | IF { CODEGEN("L%d:\n", level); } Expr '{' { create_symbol(++level); } Content '}' { dump_symbol(level--); } { CODEGEN("L%dEND:\n",level); } { level += 3; } 
    | ELSE '{' {create_symbol(++level); } Content '}' { dump_symbol(level--); }
    | WHILE { int label_start = new_label(); CODEGEN("L%d:\n", label_start); } Expr '{' { create_symbol(++level); } Content '}' { dump_symbol(level--); } { CODEGEN("goto L0\nL0_END:\n"); } 

    | GiveValueStatement ';'

    | NEWLINE
;

LetMutId
    : '=' Expr ';' 
    | ':' Type '=' Expr ';' 
;


GiveValueStatement
    : ID '=' Expr            { 
                                Symbol* s = lookup_symbol($<s_val>1); 
                                if (strcmp(expr_type, "i32") == 0) {
                                    CODEGEN("istore %d\n", s->addr); 
                                } else if (strcmp(expr_type, "f32") == 0) { 
                                    CODEGEN("fstore %d\n", s->addr); 
                                } else if (strcmp(expr_type, "str") == 0) {
                                    CODEGEN("astore %d\n", s->addr); 
                                } else if (strcmp(expr_type, "bool") == 0) {
                                    CODEGEN("istore %d\n", s->addr); 
                                }
                             } 
    | ID {Symbol* s = lookup_symbol($<s_val>1); if (strcmp(expr_type, "i32") == 0) { CODEGEN("iload %d\n", s->addr); } else if (strcmp(expr_type, "f32") == 0) {CODEGEN("fload %d\n", s->addr); } } 
      ADD_ASSIGN Expr { 
                        Symbol* s = lookup_symbol($<s_val>1);  
                        if (strcmp(expr_type, "i32") == 0) {                            
                            CODEGEN("iadd\n"); 
                            CODEGEN("istore %d\n", s->addr); 
                        } else if (strcmp(expr_type, "f32") == 0) {                           
                            CODEGEN("fadd\n");
                            CODEGEN("fstore %d\n", s->addr); 
                        } 
                      }
    | ID {Symbol* s = lookup_symbol($<s_val>1); if (strcmp(expr_type, "i32") == 0) { CODEGEN("iload %d\n", s->addr); } else if (strcmp(expr_type, "f32") == 0) {CODEGEN("fload %d\n", s->addr); } }
      SUB_ASSIGN Expr { 
                        Symbol* s = lookup_symbol($<s_val>1);  
                        if (strcmp(expr_type, "i32") == 0) {      
                            CODEGEN("isub\n"); 
                            CODEGEN("istore %d\n", s->addr); 
                        } else if (strcmp(expr_type, "f32") == 0) {        
                            CODEGEN("fsub\n");
                            CODEGEN("fstore %d\n", s->addr); 
                        }
                      }
    | ID {Symbol* s = lookup_symbol($<s_val>1); if (strcmp(expr_type, "i32") == 0) { CODEGEN("iload %d\n", s->addr); } else if (strcmp(expr_type, "f32") == 0) {CODEGEN("fload %d\n", s->addr); } }
      MUL_ASSIGN Expr { 
                        Symbol* s = lookup_symbol($<s_val>1);  
                        if (strcmp(expr_type, "i32") == 0) {  
                            CODEGEN("imul\n"); 
                            CODEGEN("istore %d\n", s->addr); 
                        } else if (strcmp(expr_type, "f32") == 0) {
                            CODEGEN("fmul\n");
                            CODEGEN("fstore %d\n", s->addr); 
                        }
                      }
    | ID {Symbol* s = lookup_symbol($<s_val>1); if (strcmp(expr_type, "i32") == 0) { CODEGEN("iload %d\n", s->addr); } else if (strcmp(expr_type, "f32") == 0) {CODEGEN("fload %d\n", s->addr); } }
      DIV_ASSIGN Expr { 
                        Symbol* s = lookup_symbol($<s_val>1);  
                        if (strcmp(expr_type, "i32") == 0) { 
                            CODEGEN("idiv\n"); 
                            CODEGEN("istore %d\n", s->addr); 
                        } else if (strcmp(expr_type, "f32") == 0) {
                            CODEGEN("fdiv\n");
                            CODEGEN("fstore %d\n", s->addr); 
                        } 
                      }
    | ID {Symbol* s = lookup_symbol($<s_val>1); if (strcmp(expr_type, "i32") == 0) { CODEGEN("iload %d\n", s->addr); } else if (strcmp(expr_type, "f32") == 0) {CODEGEN("fload %d\n", s->addr); } }
      REM_ASSIGN Expr { 
                            Symbol* s = lookup_symbol($<s_val>1);
                            CODEGEN("irem\n");
                            CODEGEN("istore %d\n", s->addr);
                      }
    | Expr
;


Expr
    : Expr '+' Expr { if (strcmp(expr_type, "i32") == 0) { CODEGEN("iadd\n"); } else if (strcmp(expr_type, "f32") == 0) { CODEGEN("fadd\n"); } }  
    //Arithmetic operation
    | Expr '-' Expr { if (strcmp(expr_type, "i32") == 0) { CODEGEN("isub\n"); } else if (strcmp(expr_type, "f32") == 0) { CODEGEN("fsub\n"); } }  
    | Expr '*' Expr { if (strcmp(expr_type, "i32") == 0) { CODEGEN("imul\n"); } else if (strcmp(expr_type, "f32") == 0) { CODEGEN("fmul\n"); } }
    | Expr '/' Expr { if (strcmp(expr_type, "i32") == 0) { CODEGEN("idiv\n"); } else if (strcmp(expr_type, "f32") == 0) { CODEGEN("fdiv\n"); } }
    | Expr '%' Expr { CODEGEN("irem\n"); } 


    //for checking error
    | ID LSHIFT ID    { 
                        Symbol* s1 = lookup_symbol($<s_val>1);
                        Symbol* s2 = lookup_symbol($<s_val>3);
                        printf("IDENT (name=%s, address=%d)\n", s1->name, s1->addr);
                        printf("IDENT (name=%s, address=%d)\n", s2->name, s2->addr);
                        if (strcmp(s1->type, s2->type) != 0) {
                            printf("error:%d: invalid operation: LSHIFT (mismatched types %s and %s)\n", yylineno + 1, s1->type, s2->type);
                        } 
                        printf("LSHIFT\n");
                      }
    | ID { Symbol* s = lookup_symbol($<s_val>1); if (s == NULL){ printf("error:%d: undefined: %s\n", yylineno + 1, $<s_val>1);} } '>' Expr { Symbol* s = lookup_symbol($<s_val>1); if (s == NULL) { printf("error:%d: invalid operation: GTR (mismatched types undefined and i32)\n", yylineno + 1); } printf("GTR\n"); }


    //Comparison operation
    | Expr '>' Expr   {  
                        int label_true = new_label(); 
                        int label_end = new_label(); 
                        if (strcmp(expr_type, "i32") == 0) {
                            CODEGEN("if_icmpgt L%d\n", label_true);
                        } else {
                            CODEGEN("fcmpg\n");
                            CODEGEN("ifgt L%d\n", label_true);
                        } 
                        CODEGEN("iconst_0\n"); 
                        CODEGEN("goto L%d\n", label_end);
                        CODEGEN("L%d:\n", label_true);
                        CODEGEN("iconst_1\n");
                        CODEGEN("L%d:\n", label_end);
                      }
    | Expr GEQ Expr   { printf("GEQ\n"); }
    | Expr '<' Expr   { 
                        int label_true = new_label(); 
                        CODEGEN("if_icmplt L%d\n", label_true);
                        CODEGEN("goto L0_END\n");
                        CODEGEN("L%d:\n", label_true); 
                      }
    | Expr LEQ Expr   { printf("LEQ\n"); }
    | Expr EQL Expr   { 
                        int label_true = level + 1; 
                        CODEGEN("if_icmpeq L%d\n", label_true);
                        CODEGEN("goto L%dEND\n", level);
                        CODEGEN("L%d:\n", label_true); 
                      }
    | Expr NEQ Expr   { 
                        int label_true = level + 1; 
                        CODEGEN("if_icmpne L%d\n", label_true);
                        CODEGEN("goto L%dEND\n", level);
                        CODEGEN("L%d:\n", label_true); 
                      } 


    //Logical operation
    | Expr LAND Expr  { CODEGEN("iand\n"); }
    | Expr LOR  Expr  { CODEGEN("ior\n"); } 


    //AS operation
    | Expr AS Type    { 
                        if (strcmp($<s_val>3, "i32") == 0) {
                            CODEGEN("f2i\n"); expr_type = "i32";
                        } else {
                            CODEGEN("i2f\n"); expr_type = "f32";
                        }
                      }
                      

    //unary operation
    | '!' Expr  %prec NOT_UMINUS  { CODEGEN("iconst_1\nixor\n"); }
    | '-' Expr  %prec NOT_UMINUS  { if (strcmp(expr_type, "i32") == 0) { CODEGEN("ineg\n"); } else if (strcmp(expr_type, "f32") == 0) { CODEGEN("fneg\n"); } }
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
           if (strcmp(s->type, "i32") == 0) {
               CODEGEN("iload %d\n", s->addr);
           } else if (strcmp(s->type, "f32") == 0) {
               CODEGEN("fload %d\n", s->addr);
           } else if (strcmp(s->type, "str") == 0) {
               CODEGEN("aload %d\n", s->addr);
           } else if (strcmp(s->type, "bool") == 0) {
               CODEGEN("iload %d\n", s->addr);
           }
         }

    | Literal   
;


//Using this to avoid public prefix problem
Literal 
    : INT_LIT { printf("INT_LIT "); expr_type = "i32"; } { CODEGEN("ldc %d\n", $<i_val>1); } 
    | FLOAT_LIT { printf("FLOAT_LIT "); expr_type = "f32"; } { CODEGEN("ldc %f\n", $<f_val>1); } 
    | '\"' STRING_LIT '\"' { printf("STRING_LIT "); expr_type = "str"; } { CODEGEN("ldc \"%s\"\n", $<s_val>2); } 
    | '\"' '\"'{ printf("STRING_LIT "); expr_type = "str"; } { CODEGEN("ldc \"\"\n"); }
    | TRUE { printf("bool TRUE\n"); expr_type = "bool"; } { CODEGEN("iconst_1\n"); }
    | FALSE { printf("bool FALSE\n"); expr_type = "bool"; } { CODEGEN("iconst_0\n"); }
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
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }

    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    CODEGEN(".source hw3.j\n");
    CODEGEN(".class public Main\n");
    CODEGEN(".super java/lang/Object\n");

    /* Symbol table init */
    // Add your code

    yylineno = 0;
    yyparse();

    /* Symbol table dump */
    // Add your code

	printf("Total lines: %d\n", yylineno);
    fclose(fout);
    fclose(yyin);

    if (g_has_error) {
        remove(bytecode_filename);
    }
    yylex_destroy();
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

int new_label() {
    return label_count++;
}