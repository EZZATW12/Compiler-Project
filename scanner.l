%{
typedef struct Node Node;
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>
%}

DIGIT   [0-9]
ID      [A-Za-z_][A-Za-z0-9]*
WS      [ \t\r\n]+

%%

"int"     { return INT; }
"print"   { return PRINT; }
"if"      { return IF; }
"else"    { return ELSE; }

"=="      { return EQ; }
"!="      { return NEQ; }
"<="      { return LE; }
">="      { return GE; }
"<"       { return LT; }
">"       { return GT; }

\"[^"]*\" { yylval.str = strdup(yytext); return STRING; }

{ID}      { yylval.id = strdup(yytext); return ID; }
{DIGIT}+  { yylval.num = atoi(yytext); return NUMBER; }

"="       return '=';
";"       return ';';
"("       return '(';
")"       return ')';
"+"       return '+';
"-"       return '-';
"*"       return '*';
"/"       return '/';
"{"       return '{';
"}"       return '}';
{WS}      /* skip whitespace */ ;
.         { printf("Unknown character: %s\n", yytext); }

%%

int yywrap() { return 1; }
/*
 Flex calls this function automatically whenever it reaches the end of the input file (EOF). 
*/