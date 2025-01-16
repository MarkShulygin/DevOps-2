#include <iostream>
#include "FuncA.h"

int main() {
	double x = 0.5;
	int n = 5;
	std::cout << "Result: " << FuncA::calculate(x, n) << std::endl;
	return 0;
};
