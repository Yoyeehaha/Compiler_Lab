/* Definition section */
%{
   #include <stdio.h>
   #include <stdlib.h>
   #include <string.h>

   #define YY_NO_UNPUT
   #define YY_NO_INPUT
   #define print_token(token) \
       printf("%-8s \t %s\n", strcmp(token, "NEWLINE")? yytext: "", token)

   int line_num = 0;
   int comment_num = 0;
   int last_comment_line = -1;
%}


/* Define regular expression label */
letter [a-zA-Z_]
digit [0-9]
func fn\ {letter}
ident {letter}({letter}|{digit})*
str_lit {letter}*
int_num {digit}+
int_val (i){digit}+
float_num {digit}+.{digit}+
float_val (f){digit}+

/* Define state */
%x SIG_COM
%x MUL_COM
%x STRING

/* Rules section */
%%

"+"         { print_token("ADD"); }
"+="        { print_token("ADD_ASSIGN"); }
"-"         { print_token("SUB"); }
"-="        { print_token("SUB_ASSIGN"); }
"*"         { print_token("MUL"); }
"*="        { print_token("MUL_ASSIGN"); }
"/"         { print_token("QUO"); }
"/="        { print_token("QUO_ASSIGN"); }
"%"         { print_token("REM"); }
"%="        { print_token("REM_ASSIGN"); }
">>"        { print_token("RSHIFT"); }
"<<"        { print_token("LSHIFT"); }
"<="        { print_token("LEQ"); }
">="        { print_token("GEQ"); }
"=="        { print_token("EQL"); }
">"         { print_token("GTR"); }
"<"         { print_token("LSS"); }
"!"         { print_token("NOT"); }
"&"         { print_token("BAND"); }
"&&"        { print_token("LAND"); }
"||"        { print_token("LOR"); }

"("         { print_token("LPAREN"); }
")"         { print_token("RPAREN"); }
"{"         { print_token("LBRACE"); }
"}"         { print_token("RBRACE"); }
"["         { print_token("LBRACK"); }
"]"         { print_token("RBRACK"); }
".."        { print_token("DOTDOT"); }
","         { print_token("COMMA"); }  
":"         { print_token("COLON"); }
"="         { print_token("ASSIGN"); }
";"         { print_token("SEMICOLON"); }

"/*"        { yymore(); BEGIN(MUL_COM); }
<MUL_COM>"*/" { print_token("MUTI_LINE_COMMENT"); BEGIN(INITIAL); }
<MUL_COM>"\n"  { comment_num++; line_num++; printf("%s", yytext); }
<MUL_COM>([^\n]) { yymore(); }

"//"        { yymore(); BEGIN(SIG_COM); }
<SIG_COM>"\n" { print_token("COMMENT"); print_token("NEWLINE"); comment_num++; line_num++; BEGIN(INITIAL); }
<SIG_COM>[^\n]* { yymore(); }

"\""        { print_token("QUOTA"); BEGIN(STRING); }
<STRING>"\"" { BEGIN(INITIAL); print_token("QUOTA");}
<STRING>[^\"]* { print_token("STRING_LIT"); }

"\n"        { print_token("NEWLINE"); line_num++; }

"as"        { print_token("AS"); }
"in"        { print_token("IN"); }
"if"        { print_token("IF"); }
"else"      { print_token("ELSE"); }
"while"     { print_token("WHILE"); }
"break"     { print_token("BREAK"); }
"for"       { print_token("FOR"); }
"loop"      { print_token("LOOP"); }
"let"       { print_token("LET"); }
"mut"       { print_token("MUT"); }
"print"     { print_token("PRINT"); }
"println"   { print_token("PRINTLN"); }
"bool"      { print_token("BOOL"); }
"false"     { print_token("FALSE"); }
"true"      { print_token("TRUE"); }
{int_num}   { print_token("INT_LIT"); }
{int_val}   { print_token("INT"); }
{float_num} { print_token("FLOAT_LIT"); }
{float_val} { print_token("FLOAT"); }
{func}      { yyless(3); print_token("FUNC"); }
{ident}     { print_token("IDENT"); }
<<EOF>>     { line_num++; yyterminate(); }
[ \t]+      {;}
.           {;}
%%

/*  C Code section */
int yywrap(void)
{
   return 1;
}

int main(int argc, char *argv[])
{
   if (argc == 2) {
       yyin = fopen(argv[1], "r");
   } else {
       yyin = stdin;
   }
   yylex();
   printf("\nFinish scanning,\n");
   printf("total line: %d\n", line_num);
   printf("comment line: %d\n", comment_num);
   fclose(yyin);
   return 0;
}
 