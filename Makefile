all: devops2

devops2: main.o FuncA.o
	g++ -g -Wall main.o FuncA.o -o funcA.elf

main.o: main.cpp
	g++ -g -Wall -c main.cpp

FuncA.o: FuncA.cpp FuncA.h
	g++ -g -Wall -c FuncA.cpp

clean:
	rm -rf -v *.o *.elf
	rm -rf -v *.gch
