#include <iostream>
#include <stdio.h>
#include "FuncA.h"

extern int CreateHTTPserver();

int main() {
	FuncA func;
	std::cout << "Result: " << func.calculate() << std::endl;
	return CreateHTTPserver();
};
