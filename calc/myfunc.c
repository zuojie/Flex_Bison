#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "myfunc.h"

double super_factorial(double param) {
	double tmp = 1;
	while(param > 1){
		tmp *= param;
		-- param;
	}
	while(tmp > 1) {
		param *= tmp;
		-- tmp;
	}
	return param;
}
