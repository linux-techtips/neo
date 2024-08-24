CC := g++
SRC := ./src
LIB := ./lib
BUILD := ./build
TARGET := neo
FLAGS := -std=c++23 -I$(LIB) -I$(SRC) -mavx2 -mbmi2 -Wall -Werror -Wpedantic -Wconversion -fuse-ld=mold -fno-rtti -fno-exceptions
RFLAGS := -Ofast -s -flto=auto -march=native -mtune=native -DNDEBUG -DFAST
DFLAGS := -g -ggdb3 -Og -fno-omit-frame-pointer

profile: FLAGS += $(RFLAGS) -I/usr/include/Tracy /usr/lib/libTracyClient.a -DTRACY_ENABLE=1
profile: $(TARGET)

release: FLAGS += $(RFLAGS) 
release: $(TARGET)

debug: FLAGS += $(DFLAGS) -fsanitize=address,undefined -DDEBUG
debug: $(TARGET)

$(TARGET): $(SRC)/$(TARGET).cpp
	mkdir -p $(BUILD)
	$(CC) $(FLAGS) $< -o $(BUILD)/$@

run: debug
	./$(BUILD)/$(TARGET) $(*)
