#include <stdio.h>
#include <iostream>
#include "../FuncA.h"

int main() {

	FuncA func;
	double result = func.calculate();

	if (std::abs(result) < 1)  {
		std::cout << "Calcuted succesfully";
	} else {
		std::cout << "Calculations failed";
	}
	return 0;	
}
