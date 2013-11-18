%{
#include <stdio.h>
#include <math.h>
#include "calc.h"
#include "myfunc.h"
int yylex(void);
void yyerror(char const *);
#define YYDEBUG 1
%}

%define api.value.type union
%token <double> NUM
%token <symrec*> VAR FNCT 
%type <double> exp
%precedence '='
%left '-' '+'
%left '*' '/'
%precedence NEG
/*%right '^'*/
%right POWER

%%

input:
 %empty
| input line
;

line:
 '\n'
| exp '\n' {printf("%.10g\n", $1);}
| error '\n' {yyerrok;}
;

exp:
 NUM {$$ = $1;}
| VAR {$$ = $1->value.var;}
| VAR '=' exp {$$ = $3; $1->value.var = $3;}
| FNCT '(' exp ')' {$$ = (*($1->value.fnctptr))($3);}
| exp '+' exp {$$ = $1 + $3;}
| exp '-' exp {$$ = $1 - $3;}
| exp '*' exp {$$ = $1 * $3;}
| exp '/' exp {
				if($3 != 0) {
					$$ = $1 / $3;
				} else {
					$$ = 0;
					fprintf(stderr, "%d-%d: division by zero\n", @3.first_line, @3.last_line);
				}
			}
| '-' exp %prec NEG {$$ = -$2;}
| exp POWER exp {$$ = pow($1, $3);}
| '(' exp ')' {$$ = $2;}
;

%%

symrec *sym_table;
static void init_table(void) {
	int i;
	for(i = 0; arith_fncts[i].fname != 0; ++ i) {
		symrec *ptr = putsym(arith_fncts[i].fname, FNCT);
		ptr->value.fnctptr = arith_fncts[i].fnct;
	}
}

#include <stdlib.h> /* malloc */
#include <string.h> /* strlen */

symrec * putsym(char const *sym_name, int sym_type) {
	symrec *ptr = (symrec *) malloc(sizeof(symrec));
	ptr->name = (char*) malloc(strlen(sym_name) + 1);
	strcpy(ptr->name, sym_name);
	ptr->type = sym_type;
	ptr->value.var = 0;
	ptr->next = (symrec *)sym_table;
	sym_table = ptr;
	return ptr;
}

symrec * getsym(char const *sym_name) {
	symrec *ptr;
	for(ptr = sym_table; ptr != (symrec *)0; ptr = (symrec *)ptr->next) {
		if(strcmp(ptr->name, sym_name) == 0) {
			return ptr;
		}
	}
	return 0;
}

#include <ctype.h>
int yylex(void) {
	int c;
	while((c = getchar()) == ' ' || c == '\t') {
		continue;
	}
	yylloc.first_line = yylloc.last_line;
	if(c == EOF) {
		return 0;
	}
	if(c == '*') {
		if((c = getchar()) == '*' ) {
			return POWER;
		}
		ungetc(c, stdin);
		return '*';
	}
	if(c == '.' || isdigit(c)) {
		ungetc(c, stdin);
		scanf("%lf", &yylval.NUM);
		return NUM;
	}
	if(isalpha(c)) {
		static size_t length = 40;
		static char *symbuf = 0;
		symrec *s;
		int i;
		if(!symbuf) {
			symbuf = (char*) malloc(length + 1);
		}
		i = 0;
		do {
			if(i == length) {
				length <<= 1;
				symbuf = (char*)realloc(symbuf, length + 1);
			}
			symbuf[i ++] = c;
			c = getchar();
		} while(isalnum(c));
		ungetc(c, stdin);
		symbuf[i] = '\0';
		s = getsym(symbuf);
		if(s == 0) {
			s = putsym(symbuf, VAR);
		}
		*((symrec**)&yylval) = s;
		return s->type;
	}
	if(c == '\n') {
		++ yylloc.last_line;
	}
	return c;
}

void yyerror(char const *s) {
	fprintf(stderr, "%s\n", s);
}

int main(int argc, char const **argv) {
	int i;
	yylloc.first_line = yylloc.last_line = 1;
	for(i = 1; i < argc; ++ i) {
		if(!strcmp(argv[i], "-p")) {
			yydebug = 1;
		}
	}
	init_table();
	return yyparse();
}
