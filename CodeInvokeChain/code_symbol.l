%option noyywrap nodefault yylineno
%x COMMENT
%x IFILE 

UCN (\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8})
EXP ([E|e][-+]?[0-9]+)
ILEN ([Uu](L|l|LL|ll)?|(L|l|LL|ll)[Uu]?)

%{
	#define NHASH 9997
	#define FUNCTION 0 
	#define VARIABLE 1 
	typedef struct ref_ {
		char *fname;
		int flags;
		int lineno;
		struct ref_ *next;
	} ref;
	typedef struct symbol_ {
		ref *reflist;
		char *fname;
		int symboltype; 
	} symbol;
	typedef struct bufstack_ {
		struct bufstack_ *prev;
		YY_BUFFER_STATE bs;
		int lineno;
		int depth;
		char *fname;
		FILE *f;
	} bufstack;
	bufstack *curbs;
	symbol symtab[NHASH];
	symbol *look_up(char*, int);
	void add_ref(int, char*, char*, int, int);
	char *curfname;
	int push_file(char*);
	int pop_file(void);
	int has_open(char*);
	int defining;
%}

%%
"/*"	{ BEGIN COMMENT; }
<COMMENT>"*/"	{ BEGIN INITIAL; }
<COMMENT>([^*]|\n)+|. {}
<COMMENT><<EOF>>	{
						printf("%s:%d: Unterminated comment\n", curfname, yylineno);
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

([_a-zA-Z]|{UCN})([_a-zA-Z0-9]|{UCN})*	{ add_ref(yylineno, curfname, yytext, defining, VARIABLE); }
([_a-zA-Z]|{UCN})([_a-zA-Z0-9]|{UCN})*\(	{ 
												yytext[yyleng - 1] = '\0';
												add_ref(yylineno, curfname, yytext, defining, FUNCTION);
											}

[ \t\n]+ {}

\\$

"#"" "*if.*\n {}
"#"" "*else.*\n {}
"#"" "*endif.*\n {}
"#"" "*define.*\n {}
"#"" "*line.*\n {}

^"#"[ \t]*include[ \t]*[\"<] { BEGIN IFILE; }
<IFILE>[^ \t\n>\"]+	{
						int c;
						while((c = input()) && c != '\n');
						char *fname = strdup(yytext);
						if(!push_file(fname)) {
							//yyterminate();
						}
						fname[strlen(fname) - 1] = 'c';
						push_file(fname);
						BEGIN INITIAL;
					}
<IFILE>.|\n {
				fprintf(stderr, "%4d bad include line\n", yylineno);
				yyterminate();
			}
<<EOF>> { if(!pop_file()) yyterminate(); }
. { fprintf(stderr, "%s:%d: Mystery character '%s'\n", curfname, yylineno, yytext); }

%%
static unsigned symhash(char *sym) {
	unsigned int hash = 0;
	unsigned int c;
	while((c = *sym ++)) {
		hash = hash * 9 ^ c;
	}
	return hash;
}

symbol* look_up(char *sym, int symboltype) {
	symbol *sp = &symtab[symhash(sym) % NHASH];
	int scount = NHASH;
	while(-- scount >= 0) {
		if(sp->fname && 0 == strcmp(sp->fname, sym) 
			&& sp->symboltype == symboltype) {
			return sp;
		}
		if(!sp->fname) {
			sp->fname = strdup(sym);
			sp->symboltype = symboltype;
			sp->reflist = 0;
			return sp;
		}
		if(++ sp >= symtab + NHASH) {
			sp = symtab;
		}
	}
	fputs("symbol table overflow\n", stderr);
	abort();
}

void add_ref(int lineno, char *fname, char *word, int flags, int symboltype) {
	ref *r;
	symbol *sp = look_up(word, symboltype);
	if(sp->reflist 
		&& sp->reflist->lineno == lineno 
		&& 0 == strcmp(sp->reflist->fname, fname)) {
		return;
	}
	r = malloc(sizeof(ref));
	if(!r) {
		fputs("out of space\n", stderr);
		abort();
	}
	r->next = sp->reflist;
	r->fname = fname;
	r->lineno = lineno;
	r->flags = flags;
	sp->reflist = r;
	sp->symboltype = symboltype;
}

static int symcmp(const void *xa, const void *xb) {
	const symbol *a = xa;
	const symbol *b = xb;
	if(!a->fname) {
		if(!b->fname) {
			return 0;
		}
		return 1;
	}
	if(!b->fname) {
		return -1;
	}
	return strcmp(a->fname, b->fname);
}

void printrefs(FILE *f) {
	symbol *sp;
	qsort(symtab, NHASH, sizeof(symbol), symcmp);
	for(sp = symtab; sp->fname && sp < symtab + NHASH; ++ sp) {
		char *prevfn = NULL;
		ref *rp = sp->reflist;
		ref *prerp = 0;
		ref *tmprp;
		do {
			tmprp = rp->next;
			rp->next = prerp;
			prerp = rp;
			rp = tmprp;
		} while(rp);
		int line = -1;
		for(rp = prerp; rp; rp = rp->next) {
			if(rp->fname == prevfn) {
				if(rp->flags & 1) {
					line = rp->lineno;
					break;
				}
			} else {
				prevfn = rp->fname;
				if(rp->flags & 1) {
					line = rp->lineno;
					break;
				}
			}
		}
		// ignore variables in symbol file
		if(sp->symboltype == FUNCTION) {
			if(line > 0 && prevfn) {
				fprintf(f, "%s:%s:%d\n", sp->fname, prevfn, line);
			} else {
				fprintf(f, "%s:lib:-1\n", sp->fname);
			}
		} 
	}
}

int has_open(char *fn) {
	bufstack *bs = curbs;
	while(bs != NULL) {
		if(strcmp(bs->fname, fn) == 0) {
			return 1;
		}
		bs = bs->prev;
	}
	return 0;
}

int push_file(char *fn) {
	if(has_open(fn)) {
		return 0;
	}
	FILE *f = fopen(fn, "r");
	if(!f) {
		//perror(fn);
		return 0;
	}
	bufstack *bs = malloc(sizeof(bufstack));
	if(!bs) {
		perror("malloc error");
		exit(1);
	}
	if(curbs) {
		curbs->lineno = yylineno;
	}
	bs->prev = curbs;
	bs->bs = yy_create_buffer(f, YY_BUF_SIZE);
	bs->f = f;
	bs->fname = strdup(fn);
	yy_switch_to_buffer(bs->bs);
	curbs = bs;
	yylineno = 1;
	curfname = fn;
	return 1;
}

int pop_file(void) {
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
	yylineno = curbs->lineno;
	curfname = curbs->fname;
	return 1;
}

int main(int argc, char **argv) {
	int i;
	if(argc < 3) {
		fprintf(stderr, "Usage:code_symbol <symbol file> <file>...\n");
		return 1;
	}
	FILE *symbolf;
	symbolf = fopen(argv[1], "w");
	for(i = 2; i < argc; ++ i) {
		if(push_file(argv[i])) {
			yylex();
		}
	}
	printrefs(symbolf);
	fclose(symbolf);
	return 0;
}
