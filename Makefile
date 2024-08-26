CC := g++
SRC := ./src
LIB := ./lib
BUILD := ./build
TARGET := neo
FLAGS := -std=c++23 -I$(LIB) -I$(SRC) -mavx2 -mbmi2 -Wall -Werror -Wpedantic -Wconversion -fuse-ld=mold -fno-rtti -fno-exceptions
RFLAGS := -Ofast -s -static -flto=auto -DNDEBUG -DFAST
DFLAGS := -g -ggdb3 -Og -fno-omit-frame-pointer

nix: FLAGS += $(RFLAGS) -DUNITY
nix: $(BUILD)/$(TARGET)

profile: FLAGS += $(RFLAGS) -march=native -mtune=native 
profile: $(BUILD)/$(TARGET)

debug: FLAGS += $(DFLAGS) -fsanitize=address,undefined -DDEBUG
debug: $(BUILD)/$(TARGET)

$(BUILD)/lex.o: $(SRC)/lexer/lex.cpp
	$(CC) $(FLAGS) -c $< -o $@

$(BUILD)/$(TARGET): $(SRC)/$(TARGET).cpp $(BUILD)/lex.o
	$(CC) $(FLAGS) $(BUILD)/lex.o $< -o $@

run: debug
	$(BUILD)/$(TARGET) $(*)
