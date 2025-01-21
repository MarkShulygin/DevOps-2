#include <cmath>
#include "FuncA.h"
#include <random>

double factorial(int num) {
	if (num <= 1) return 1;
	return num * factorial(num - 1);
}

double FuncA::calculate() {
	std::random_device rd;
	std::mt19937 gen(rd());
	std::uniform_real_distribution<> dis(0.0, 1.0);

	double result = M_PI / 2;
	for (int i = 0; i < 3; ++i) 
	{
		double x = dis(gen);
		double term = (factorial(2*i) / (pow(4,i) * pow(factorial(i), 2) * (2 * i + 1)));
		term *= pow(x, 2*i+1);
		result -= term;
	}
	return result;
};
