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
float_num {digit}+.{digit}+

/* Define state */
%x SIG_COM
%x MUL_COM
%x STRING

/* Rules section */
%%

"+"         { print_token("ADD"); }
"-"         { print_token("SUB"); }
"("         { print_token("LPAREN"); }
")"         { print_token("RPAREN"); }
"{"         { print_token("LBRACE"); }
"}"         { print_token("RBRACE"); }
";"         { print_token("SEMICOLON"); }

"/*"        { BEGIN(MUL_COM); }
<MUL_COM>"*/" { print_token("MUTI_LINE_COMMENT"); BEGIN(INITIAL); }
<MUL_COM>"\n"  { comment_num++; line_num++; }
<MUL_COM>([^\n]) { yymore(); }

"//"        {BEGIN(SIG_COM); }
<SIG_COM>"\n" {  print_token("COMMENT"); print_token("NEWLINE"); BEGIN(INITIAL); comment_num++; line_num++;}
<SIG_COM>([^\n]) { yymore(); }

"\""        { print_token("QUOTA"); BEGIN(STRING); }
<STRING>"\"" {  print_token("QUOTA"); BEGIN(INITIAL); }
<STRING>([^\"]) {print_token("STRING_LIT"); yymore(); }

"\n"        { print_token("NEWLINE"); line_num++; }
"str_lit"   { print_token("STRING_LIT"); }
"println"   { print_token("PRINTLN"); }
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
 