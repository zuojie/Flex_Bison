#include "myfunc.h"
/* Function type */
typedef double (*func_t) (double);
/*Data type for links in the chain of symbols */
struct symrec {
	char *name; /* name of symbol */
	int type; /* type of symbol: either var or fnct */
	union {
		double var;
		func_t fnctptr;
	} value;
	struct symrec *next;
};
typedef struct symrec symrec;
extern symrec *sym_table;
symrec *putsym(char const *, int);
symrec *getsym(char const *);
struct init {
	char const *fname;
	double (*fnct) (double);
};
typedef struct init init;
init const arith_fncts[] = {
							{"atan", atan},
							{"cos", cos},
							{"exp", exp},
							{"ln", log},
							{"sin", sin},
							{"sqrt", sqrt},
							{"superfact", super_factorial},
							{0, 0},
						};

