#include "a.h"
#include "b.h"
#include "src/c.h"
#include <string.h>

int dis() {
	char disa = 'a';
	int disb = 1;
	while(1 == 2) {
		printf("3=4");
	}
	printf("%c\n", disa);
	return disb;
}

void pk(int a, int b) {
	if (a > b) {
		a -= b;
	} else {
		b -= a;
	}
}

enum TYPE {
	INT,
	FLOAT
} t;

void check(char *a, char b[]) {
	printf("check: %d\n", strcmp(a, b));
	printf("check: %d\n", a == b);
}

void thisFunc() {
	dis();
}

void refval(char *chr, int len) {
	strncpy(chr, "1234kk", len);
	thisFunc();
	//*chr = "1234kk";
}

int main(void) {
	printf("%s\n", __FUNCTION__);
	char strt[] = "fun1(int ak, int bk), fun2()";
	fprintf(stderr, "%s\n", strt);
	refval(strt, strlen(strt));
	fprintf(stderr, "%s\n", strt);
	int kc = 100;
	int kb = 100;
	pk(kb, kc);
	dis();
	char a[] = "abc";
	char *b = "abc";
	printf("%d\n", a == b);
	check(a, b);
	disp();
	thisFunc();
	return 0;
}
