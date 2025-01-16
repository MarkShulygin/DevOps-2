#include <cmath>
#include "FuncA.h"

double factorial(int num) {
	if (num <= 1) return 1;
	return num * factorial(num - 1);
}

double FuncA::calculate(double x, int n) {
	double result = M_PI / 2;
	for (int i = 0; i < n; ++i) {
		double term = (factorial(2*i) /
				(pow(4,i) * pow(factorial(i), 2) * (2 * i + 1))) *
				pow(x, 2 * i + 1);
		result -= term;
	}
	return result;
};
