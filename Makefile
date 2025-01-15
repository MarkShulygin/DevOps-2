CXX = g++
CXXFLAGS = -Wall -Wextra -std=c++17
SOURCES = ./main.cpp ./FuncA.cpp
OBJECTS = $(SOURCES:.cpp=.o)
TARGET = my_program

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CXX) $(CXXFLAGS) -o $@ $^

clean:
	rm -f $(TARGET) $(OBJECTS)
