# Introduction
Neo is a language and compiler toolchain that doesn't fully exist yet. Its main inspirations are languages like Zig, Hare, Gleam, Rust, and C++. In the future, neo aims to be a general purpose systems-oriented language that will prioritize the fun of programming while being simple and built on composable patterns that reach from the simplest of features to the more complex. It will also cater to three different yet non-distinct types of programmers.

**Producers** are the kinds of users that will use the tools and features of the language that have the lowest barrier to entry in order to bring their vision from imagination into the real world. They will not need to know all of the language features and should not be expected to jump through hoops to be productive. Neo will work to find a balance between being simple to work with, but expressive enough as to not lock users into solutions that aren't their own.  

**Librarians** have found a specific problem that needs to be solved where an abstraction or a defined implementation would be the best solution. neo needs to have the expressiveness to define clean and simple-to-use libraries that can fit the specific nature of a given problem. This is a harder balance to strike as bad library design is an easy feat, but neo cannot be too opinionated as to disallow better solutions.

**Rockstars** are an extreme user. They will push the boundaries of neo's language design to achieve a hyper-specific goal. This could mean striving for ultimate performance, designing a solution for a problem that has not previously been solved, or using neo in highly unconventional ways or places. The tricks that these users will need to perform will be discouraged for non-rockstars, so escape hatches will need to be made.
# Getting Familiar with neo
In order to give an idea about what neo is and will be some vaporware examples and explanations are given. Keep in mind, the language design is subject to change at a whim and is open to be discussed.
## Hello World
```rust
use std::io

main : fn : {
	io::println("Hello, {} {}!", { "cool", "world" })
}
```

There's a lot going on that may be similar to other languages like Rust or Hare, but there's a few key differences. 

First and most importantly no semicolons! As you will see later, semicolons are a bit of a redundancy when trying to achieve expressiveness as the purpose that semicolons would normally fill are encoded in the structure of the source code itself. 

Other than that, you may find that the declaration of the main function to be unconventional. But, if read aloud in a certain way it might make more sense. It could be read as main is a function with no arguments that returns the result of an expression found in the following block. This pattern has a name and it's called: The Neo Pattern
## The Neo Pattern
```
`name` : ?`expr` ?`: | =` ?`expr`
```

All declarations in Neo will follow this pattern. A declaration will have a name, followed by a colon, an optional type hint, either `:` for constant declarations or `=` for mutable declarations, and an expression. Here's some more usages of this pattern to solidify it.

```rust
num : u32 : 42 // num is a u32 that is constant and has the value of 42.

num : u32 = 68 // num is a u32 that is mutable and has the value of 68.

message :: "oooh" // message is of a type inferred by the constant value of "oooh"
message := "Just like Go!" // message is of a type inferred by the constannt value of "Just like Go!"

undefined : []u8 // undefined is of a type `[]u8` that has not been assigned a value. "See Zig, you don't need a keyword for everything"

cond :: if (num == 68) {
	9 + 10
} else {
	21
}
```

Woah, that last declaration is kinda funky. We just said that declarations can only be assigned the value of an expression. I'm not a liar so that would mean that all statements are also expressions.
## All Statements are also Expressions
In order to achieve high levels of composition and expressiveness modern languages like Zig, Rust, etc. have come up with the based idea of making statements expressions. This means that control flow, types, and even variable declarations themselves are also expressions. Here's a snippet of C that can show how cool this ability is.

```c
int get_color(int temp) {
	int color = 0;

	if (temp < -20) {
		color = 1; // Blue
	
	} else if (-20 <= temp && temp < 10) {
		color = 2; // Green
	
	} else {
		switch (color) {
			case 0:
				color = 3; // Red
				break;
			
			case 1:
				color = 4;
				break;
			
			default:
				color = 5;
				break;
		}
	}

	return color;
}
```

That's a whole lotta code. Lets see how statements as expressions make this easier.

```rust
get_color : fn(s32 temp) : s32 {
	color = if (temp < -20) {
		1
	} else if (-20 <= temp and temp < 10) {
		2
	
	} else 0

	match (color) {
		0 => color = 3
		1 => color = 4
		_ => color = 5
	}

	color
}
```

That's already a lot better, but this is not even close to the limit of composition that can be achieved. Keep on reading and you might find even more uses of statements as expressions.

# Keywords
| Name       | Description                                                                                                                                                                                                                                                                                                         | Links                 |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| `comptime` | Comptime instructs the compiler to perform the following expression before outputting the resulting program. Support for I/O operations like reading from disk, allocating memory, and networking are planned. Whatever the result of the expression is will be compiled into the program.                          | [[#comptime]]         |
| `extern`   | Defines a symbol to be resolved at link time.                                                                                                                                                                                                                                                                       | [[#extern]]           |
| `inline`   | Inline can request the compiler to perform an expression in-place. If it is a function, rather than performing a function call, it will copy-past the body of the function into the current scope (This only has effect on the resulting program, not the source code). It can also request that loops be unrolled. | [[#inline]]           |
| `opaque`   | Defines a type to have some unknown, but non-zero size.                                                                                                                                                                                                                                                             | [[#opaque]]           |
| `packed`   | Defines a type to not be padded, it must be the exact space as specified in the source code at the cost of alignment.                                                                                                                                                                                               | [[#packed]]           |
| `struct`   | Defines a type to be a structure.                                                                                                                                                                                                                                                                                   | [[#struct]]           |
| `align`    | Defines that type that represents memory or a memory layout, i.e. pointers, structs, etc. will be aligned to a given offset. Used to enforce memory layouts and make pointer alignment part of the type system.                                                                                                     | [[#align]]            |
| `const`    | Currently makes a slice immutable. (I need a better solution for this problem)                                                                                                                                                                                                                                      | [[#Slices]]           |
| `defer`    | Defers the execution of the following expression to the end of the enclosing block.                                                                                                                                                                                                                                 | [[#Defer]]            |
| `error`    | Defines an enumeration that is considered an error in the type system.                                                                                                                                                                                                                                              | [[#Error]]            |
| `match`    | Used to perform pattern matching.                                                                                                                                                                                                                                                                                   | [[#Match]]            |
| `union`    | Defines a type to be a union.                                                                                                                                                                                                                                                                                       | [[#Union]]            |
| `else`     | if not this, then ...                                                                                                                                                                                                                                                                                               | [[#Control Flow]]     |
| `loop`     | Not your grandpa's for and while loop.                                                                                                                                                                                                                                                                              | [[#loop]]             |
| `next`     | Performs the next iteration of a loop. Akin to `continue` in C.                                                                                                                                                                                                                                                     | [[#loop]]             |
| `stop`     | Exits the current loop. Akin to `break` in C.                                                                                                                                                                                                                                                                       | [[#loop]]             |
| `type`     | Defines a type.                                                                                                                                                                                                                                                                                                     | [[#Types]]            |
| `yeet`     | Returns a value from the first parent function.                                                                                                                                                                                                                                                                     | [[#yeet]]             |
| `and`      | Binary and logical `AND` operation                                                                                                                                                                                                                                                                                  | [[#Control Flow]]     |
| `any`      | The value specified to be of type any can be any value. It cannot be assigned a value of a different type once assigned. Useful in meta-programming.                                                                                                                                                                | [[#Meta Programming]] |
| `not`      | Binary and logical `NOT` operation                                                                                                                                                                                                                                                                                  | [[#Control Flow]]     |
| `pub`      | Defines a symbol to be publicly known to outside modules.                                                                                                                                                                                                                                                           | [[#pub]]              |
| `use`      | Brings into scope specified symbols from a non-local module.                                                                                                                                                                                                                                                        | [[#use]]              |
| `as`       | Casting operation used to cast a value of one type to another type with sane limits.                                                                                                                                                                                                                                | [[#as]]               |
| `fn`       | Defines a symbol to be a function.                                                                                                                                                                                                                                                                                  | [[#Functions]]        |
| `if`       | Gatekeeps invariant programs from becoming variant programs.                                                                                                                                                                                                                                                        | [[#Control Flow]]     |
| `or`       | Binary and logical `OR` operation.                                                                                                                                                                                                                                                                                  | [[#Control Flow]]     |

# Primitives
## Primitive Types

| Type    | Description                                                                                                                                                       |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `s8`    | Signed 8-bit integer.                                                                                                                                             |
| `s16`   | Signed 16-bit integer.                                                                                                                                            |
| `s32`   | Signed 32-bit integer.                                                                                                                                            |
| `s64`   | Signed 64-bit integer.                                                                                                                                            |
| `s128`  | Signed 128-bit integer.                                                                                                                                           |
| `ssize` | Signed integer with a bit-width of the system register size.                                                                                                      |
| `u8`    | Unsigned 8-bit integer.                                                                                                                                           |
| `u16`   | Unsigned 16-bit integer.                                                                                                                                          |
| `u32`   | Unsigned 32-bit integer.                                                                                                                                          |
| `u64`   | Unsigned 64-bit integer.                                                                                                                                          |
| `u128`  | Unsigned 128-bit integer.                                                                                                                                         |
| `usize` | Unsigned integer with a bit-width of the system register size.                                                                                                    |
| `d16`   | 16-bit decimal value.                                                                                                                                             |
| `d32`   | 32-bit decimal value.                                                                                                                                             |
| `d64`   | 64-bit decimal value.                                                                                                                                             |
| `d128`  | 128-bit decimal value.                                                                                                                                            |
| `dsize` | Decimal value with a bit-width of the system register size.                                                                                                       |
| `b8`    | 8-bit boolean value.                                                                                                                                              |
| `b16`   | 16-bit boolean value.                                                                                                                                             |
| `b32`   | 32-bit boolean value.                                                                                                                                             |
| `b64`   | 64-bit boolean value.                                                                                                                                             |
| `b128`  | 128-bit boolean value. (why?)                                                                                                                                     |
| `bsize` | Boolean value with a bit-width of the system register size.                                                                                                       |
| `void`  | Not your grandpa's void, it's a zero-sized type that will cause the expression to not be present in the outputted program. It will be useful for meta-programing. |
Any type that has a specified bit-width can also have an arbitrary bit-width between it's smallest and largest value. For variables on the stack, the bit-widths of the type will be rounded up to the nearest specified width. In structures, the exact precision will be used packing the struct. This is done to strike a balance between the hardware as well as the design of your program as compile-time checks can be done to make sure values fit within the specified bit-width.

```rust
num : s7 : 'A' // A regular ascii codepoint only consists of 7-bits.
perms : u6 : 077 // An octal value is normally 6-bits. This can be useful for representing permissions on kernels like linux.
```

## Primitive Values
| Value   | Description                                                                                |
| ------- | ------------------------------------------------------------------------------------------ |
| `true`  | A truthy value for all integer types.                                                      |
| `false` | A falsey value for all integer types.                                                      |
| `null`  | Not your gradpa's null, it is used to denote the lack of a value present in an `optional`. |

# Variables
`todo`

# Integers
`todo`

# Floats
`todo`

# Arrays
`todo`

# Vectors
`todo`

# Operators
`todo`

# Pointers
`todo`

# Slices
`todo`

# Blocks
`todo`

# Functions
`todo`

# Control Flow
`todo`

# Types
`todo`

# Specifiers
`todo`

# Comptime
`todo`

# Meta Programming
`todo`

# Builtin's
`todo`