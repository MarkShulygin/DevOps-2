#include <iostream>
#include "FuncA.h"

int main() {
	FuncA func;
	std::cout << "Result: " << func::calculate() << std::endl;
	return 0;
};
