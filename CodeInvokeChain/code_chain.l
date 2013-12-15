%option noyywrap nodefault yylineno
%x COMMENT

UCN (\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8})
EXP ([E|e][-+]?[0-9]+)
ILEN ([Uu](L|l|LL|ll)?|(L|l|LL|ll)[Uu]?)

%{
	#define MAX_LINE 1024
	int fulltext = 0;
	typedef struct functbl_ {
		struct functbl_ *next;
		char *filename;
		char *funcname;
		int lineno;
	} functbl;
	typedef struct bufstack_ {
		struct bufstack_ *prev;
		YY_BUFFER_STATE bs;
		int lineno;
		int depth;
		int findfuncdef;
		char *funcname;
		char *filename;
		FILE *f;
	} bufstack;
	bufstack *curbs = NULL;
	functbl *functable = NULL;
	int defining;
	int push_func(const char*, const char*);
	int pop_func();
	void find_func(char*, int, const char*);
	int circular_invoke(const char *);
	void display_func(const char*, const char*, const int, const int);
	void init_func_tbl(const char*);
	void str_split(const char*, char, char (*res)[MAX_LINE]);
%}

%%
"/*"	{ BEGIN COMMENT; }
<COMMENT>"*/"	{ BEGIN INITIAL; }
<COMMENT>([^*]|\n)+|. {}
<COMMENT><<EOF>>	{
						printf("%s:%d: Unterminated comment\n", curbs->filename, yylineno);
						return 0;
					}
"//".*\n {}

_Bool |
_Complex |
_Imaginary |
auto |
char |
const |
double |
enum |
extern |
float |
inline |
int |
long |
register |
restrict |
short |
signed |
static |
struct |
typedef |
union |
unsigned |
void |
volatile { defining = 1; }

break
case
case\(
continue
default
do
else
for
for\(
goto
if
if\(
return
return\(
sizeof
sizeof\(
switch
switch\(
while
while\(

0[0-7]*{ILEN}?
[1-9][0-9]*{ILEN}?
0[Xx][0-9a-fA-F]+{ILEN}?

([0-9]*\.[0-9]+|[0-9]+\.){EXP}?[flFL]?
[0-9]+{EXP}[flFL]?
0[Xx]([0-9a-fA-F]*\.[0-9a-fA-F]+|[0-9a-fA-F]+\.?)[Pp][-+]?[0-9]+[flFL]?

\'([^'\\]|\\['"?\\abfnrtv]|\\[0-7]{1,3}|\\[xX][0-9a-fA-F]+|{UCN})+\'
L?\"([^"\\]|\\['"?\\abfnrtv]|\\[0-7]{1,3}|\\[xX][0-9a-fA-F]+{UCN})*\"

"{"|"<%"|";" { defining = 0; }
"["|"]"|"("|")"|"{"|"}"|"."|"->"|"++"|"--"|"&"|"*"|"+"|"-"|"~"|"!"|"/"|"%"|"<<"|">>"|"<"|">"|"<="|">="|"=="|"!="|"^"|"|"|"&&"|"||"|"?"|":"|";"|"..."|"="|"*="|"/="|"%="|"+="|"-="|"<<="|">>="|"&="|"^="|"|="|","|"#"|"##"
"<:"|":>"|"%>"|"%:"|"%:%:"

([_a-zA-Z]|{UCN})([_a-zA-Z0-9]|{UCN})*	{ /*variables*/ } 
([_a-zA-Z]|{UCN})([_a-zA-Z0-9]|{UCN})*\(	{ 
												yytext[yyleng - 1] = '\0';
												if(defining == 1) { 
													defining = 0;
													if(strcmp(yytext, curbs->funcname) == 0) {
														curbs->findfuncdef = 1;
														display_func(curbs->funcname, curbs->filename, curbs->lineno, 0);
													} else if(curbs->findfuncdef == 1) {
														pop_func();
													}
												} else {
													if(curbs->findfuncdef == 1) {
														char filename[MAX_LINE];
														find_func(filename, MAX_LINE, yytext);
														if(strcmp(filename, "lib") == 0) {
															display_func(yytext, curbs->filename, yylineno, 1);
														} else {
															push_func(filename, yytext);
														}
													}
												}
											}

[ \t\n]+ {}

\\$

"#"" "*include.*\n {}
"#"" "*if.*\n {}
"#"" "*else.*\n {}
"#"" "*endif.*\n {}
"#"" "*define.*\n {}
"#"" "*line.*\n {}

<<EOF>> { if(!pop_func()) yyterminate(); }
. { fprintf(stderr, "%s:%d: Mystery character '%s'\n", curbs->filename, yylineno, yytext); }

%%

void str_split(const char *src, char delimit, char (*res)[MAX_LINE]) {
	int len = strlen(src);
	int i;
	int cnt = 0;
	int j = 0;
	for(i = 0; i < len; ++ i) {
		if(src[i] == delimit) {
			res[cnt][j] = '\0';
			++ cnt;
			j = 0;
			continue;
		}
		res[cnt][j ++] = src[i];
	}
}

void debug_func_tbl() {
	functbl *head = functable;
	while(head != NULL) {
		fprintf(stdout, "%s:%s:%d\n", head->funcname, head->filename, head->lineno);
		head = head->next;
	}
}

void init_func_tbl(const char *fname) {
	FILE *f = fopen(fname, "r");
	if(!f) {
		perror(fname);
		return;
	}
	char line[MAX_LINE];
	char fields[4][MAX_LINE];
	functbl *head = functable;
	while(fgets(line, MAX_LINE, f) != NULL) {
		int len = strlen(line);
		line[len - 1] = '\0';
		str_split(line, ':', fields);
		functbl *ft = malloc(sizeof(functbl));
		ft->funcname = strdup(fields[0]);
		ft->filename = strdup(fields[1]);
		ft->lineno = atoi(fields[2]);
		ft->next = NULL;
		if(functable == NULL) {
			functable = ft;
			head = functable;
		} else {
			head->next = ft;
			head = ft;
		}
	}
}

void find_func(char *filename, int filenamelen, const char *funcname) {
	functbl *first = functable;
	while(first != NULL) {
		if(strcmp(first->funcname, funcname) == 0) {
			strncpy(filename, first->filename, filenamelen);
			return;
		}
		first = first->next;
	}
}

void display_func(const char *funcname, const char *filename, const int lineno, const int islib) {
	int c;
	if(curbs) {
		for(c = 1; c <= curbs->depth; ++ c) {
			fprintf(yyout, " ");
		}
	}
	if(islib) {
		puts("  |");
		for(c = 1; c <= curbs->depth; ++ c) {
			fprintf(yyout, " ");
		}
		if(fulltext) {
			fprintf(yyout, "  |--%s*:%s:%d\n", funcname, filename, lineno);
		} else {
			fprintf(yyout, "  |--%s*\n", funcname);
		}
	} else {
		puts("|");
		for(c = 1; c <= curbs->depth; ++ c) {
			fprintf(yyout, " ");
		}
		if(fulltext) {
			fprintf(yyout, "|--%s:%s:%d\n", funcname, filename, lineno);
		} else {
			fprintf(yyout, "|--%s\n", funcname);
		}
	}
}

int circular_invoke(const char *fn) {
	bufstack *bs = curbs;
	bufstack *prevbs;
	if(!bs) {
		return 0;
	}
	while(1) {
		prevbs = bs->prev;
		if(!prevbs) {
			return 0;
		}
		if(strcmp(prevbs->funcname, fn) == 0) {
			return 1;
		}
		bs = prevbs;
	}
	return 0;
}

int push_func(const char *filename, const char *funcname) {
	FILE *f = fopen(filename, "r");
	if(!f) {
		perror(filename);
		return 0;
	}
	bufstack *bs = malloc(sizeof(bufstack));
	if(!bs) {
		perror("malloc");
		exit(1);
	}
	int first = 0;
	if(curbs) {
		if(circular_invoke(funcname)) {
			return 0;
		}
		curbs->lineno = yylineno;
	} else {
		first = 1;
	}
	bs->prev = curbs;
	bs->bs = yy_create_buffer(f, YY_BUF_SIZE);
	bs->f = f;
	bs->lineno = yylineno;
	bs->funcname = strdup(funcname);
	bs->filename = strdup(filename);
	bs->findfuncdef = 0;
	if(first) {
		bs->depth = 1;
	} else {
		bs->depth = curbs->depth + 2;
	}
	yy_switch_to_buffer(bs->bs);
	curbs = bs;
	yylineno = 1;
	return 1;
}

int pop_func() {
	bufstack *bs = curbs;
	bufstack *prevbs;
	if(!bs) {
		return 0;
	}
	fclose(bs->f);
	yy_delete_buffer(bs->bs);
	prevbs = bs->prev;
	free(bs);
	curbs = prevbs;
	if(!prevbs) {
		return 0;
	}
	yy_switch_to_buffer(prevbs->bs);
	return 1;
}

void usage() {
	fprintf(stderr, "Usage:code_chain [-f] <symbol file> <source file> <entry function>\n");
}

int main(int argc, char **argv) {
	if(argc < 4) {
		usage();
		return 1;
	}
	if(argc == 5) {
		if(argv[1][1] == 'f') {
			fulltext = 1;
		} else {
			usage();
			return 1;
		}
	}
	int i = 1;
	if(fulltext) {
		++ i;
	}
	init_func_tbl(argv[i]);
	//debug_func_tbl();
	push_func(argv[i + 1], argv[i + 2]);
	yylex();
	return 0;
}
