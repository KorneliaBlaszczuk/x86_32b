# Define the compiler and assembler
CXX = g++
NASM = nasm

# Define compiler and assembler flags
CXXFLAGS = -std=c++11 -Wall -g
NASMFLAGS = -f elf32

# Define the output executable name
OUTPUT = marker_detector

# Define the source files
CPP_SRC = main.cpp
ASM_SRC = find_marker.asm

# Define the object files
OBJ = main.o find_marker.o

# Rule to build the final executable
$(OUTPUT): $(OBJ)
	$(CXX) -m32 -o $(OUTPUT) $(OBJ)

# Rule to compile the C++ source file
main.o: main.cpp
	$(CXX) $(CXXFLAGS) -m32 -c main.cpp

# Rule to assemble the assembly source file
find_marker.o: find_marker.asm
	$(NASM) $(NASMFLAGS) -o find_marker.o find_marker.asm

# Rule to clean the build directory
clean:
	rm -f $(OBJ) $(OUTPUT)
