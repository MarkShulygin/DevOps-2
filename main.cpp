#include <iostream>
#include <stdio.h>
#include "FuncA.h"

int main() {
	FuncA func;
<<<<<<< HEAD
	std::cout << "Result: " << func.calculate() << std::endl;
=======
	std::cout << "Result: " << func::calculate() << std::endl;
>>>>>>> 862df72 (Bag fix)
	return 0;
};
