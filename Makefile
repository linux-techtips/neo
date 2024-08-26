CC := g++
SRC := ./src
LIB := ./lib
BUILD := ./build
TARGET := neo
FLAGS := -std=c++23 -I$(LIB) -I$(SRC) -mavx2 -mbmi2 -Wall -Werror -Wpedantic -Wconversion -fno-rtti -fno-exceptions
RFLAGS := -Ofast -s -DNDEBUG -DFAST
DFLAGS := -g -ggdb3 -Og -fno-omit-frame-pointer

nix: FLAGS += $(RFLAGS) -DUNITY -static -fuse-ld=mold -flto=auto
nix: $(SRC)/$(TARGET).cpp
	$(CC) $(FLAGS) $< -o $(BUILD)/$(TARGET)

release: FLAGS += $(RFLAGS) -march=native -mtune=native
release: $(BUILD)/$(TARGET)

debug: FLAGS += $(DFLAGS) -fsanitize=address,undefined -DDEBUG
debug: $(BUILD)/$(TARGET)

$(BUILD)/lex.o: $(SRC)/lexer/lex.cpp
	$(CC) $(FLAGS) -c $< -o $@

$(BUILD)/$(TARGET): $(SRC)/$(TARGET).cpp $(BUILD)/lex.o
	$(CC) $(FLAGS) $(BUILD)/lex.o $< -o $@

run: debug
	$(BUILD)/$(TARGET) $(*)

clean:
	rm -r $(BUILD)/*
