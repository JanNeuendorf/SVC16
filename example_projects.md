## The first program

A simple example would be to print all $2^{16}$ possible colors to the screen.
We make our lives easier, by mapping each index of the screen-buffer to the
color which is encoded with the index. Here, we use the names of the opcodes
instead of their numbers.

```
Set 501 1 0       // Write the value 1 to address 501
Set 502 65535 0   // Write the largest possible value to 502
Print 500 500 0   // Display color=@500 at screen-index=@500
Add 500 501 500   // Increment the color/screen-index
Cmp 500 502 503   // See if we are not at the max number
Xor 503 501 503   // Negate it
Skip 0 4 503      // Unless we are at the max number, go back 4 instructions
Sync 0 0 0        // Sync 
GoTo 0 0 0        // Repeat to keep the window open
```

We could rely on the fact that the value at index 500 starts at zero and we did
not have to initialize it.

To build a program that we can execute, we could use python:

```python
import struct

code = [
    0, 501, 1, 0, #Opcodes replaced with numbers
    0, 502, 65535, 0,
    11, 500, 500, 0,
    # ...
]
with open("all_colors.svc16", "wb") as f:
    for value in code:
        f.write(struct.pack("<H", value))

```

Inspecting the file, we should see:

```ansi
➜ hexyl examples/all_colors.svc16 -pv --panels 1

  00 00 f5 01 01 00 00 00
  00 00 f6 01 ff ff 00 00
  0b 00 f4 01 f4 01 00 00
  03 00 f4 01 f5 01 f4 01
  07 00 f4 01 f6 01 f7 01
  0e 00 f7 01 f5 01 f7 01
  02 00 00 00 04 00 f7 01
  0f 00 00 00 00 00 00 00
  01 00 00 00 00 00 00 00
```

When we run this, we get the following output:

![All colors](specification/colors_scaled.png)

## Designing a simple assembly language

If we want to compile the program from the beginning, all we have to do is to
replace `Set`, `Add`, `Print` etc. with their corresponding numbers. If we then
make our python script into a command line program that reads in this code, does
the replacement and produces the binary output, we already have our first
assembler.

### Adding variables

Not having to remember the opcodes is an improvement, but we still have to
manually decide which memory address holds which value. This can be automated
relatively easily.

First, we need to identify variables. This can be easily done with the criterion
that they start with a letter and are not an instruction.

We need to know the first memory address that is not used for instructions.
Right now, this is very easily done since every line of our program takes up
four values in memory. The first variable name we see gets replaced with the
first free address. For all the following ones we check if the variable was
assigned before. If it was, we reuse that address, and if not, we reserve a new
one.

Our program can now look like this:

```
Set one 1 0       
Set max_value 65535 0   
Print color color 0   
Add color one color   
...

```

This is already much easier to understand.

### Adding constants

In the first line of that example we assigned the value 1 to a variable called
"one". This is a little catastrophe. In order to get the value 1 into our
program, we needed to run an instruction at runtime and take up 5 addresses (4
for the instruction, one for the value).

We want to write the values of constants into our binary directly. The program
could look like this:

```
Print color color 0   
Add color "1" color   
...

```

The way this is resolved is very similar to the way the variables are assigned.
We replace every new constant with the next free address and every reappearing
constant with its known address. The only difference is that we have to write
the values of the constant to their addresses as well.

It would be best to change the ordering of variables and constants. The
addresses for constants already hold a value when the program starts and the
addresses for variables do not. We should put the variables at the end, so the
binary file does not contain a bunch of zeros.

### Simple replacements

This is a good time to invent some new instructions which are expanded to the
known ones. For now, they should have a one to one mapping, meaning that each
instruction is replaced by exactly one new one. We can, however, have
instructions with fewer arguments. Examples would be:

```
Incr variable -> Add variable "1" variable
Negate variable -> Xor variable "1" variable
JumpTo location condition  -> GoTo "0" location condition // where location is not a variable
JumpAfter location condition  -> GoTo "1" location condition // where location is not a variable

```

### Labels

As it stands, we still have to count or remember line numbers for the `Skip` and
`GoTo` instructions. One simple Idea would be to allow a label (or multiple) for
each line.

```
Print color color 0  <start>
Incr color    
Cmp color "65535" condition   
Negate condition
JumpTo @start condition   
Sync 0 0 0        
JumpTo @start "0"       
```

References can then be resolved by counting the lines (and multiplying by 4 to
get the memory address).

### Including Data

We might want to include large sequences of data for things like sprites. This
can be done in a way very similar to constants. The syntax could look something
like this

```
Print "path/to/binary.dat" index 0  <start>
```

This does two things:

- 1. It places the content of the binary file into the program.
- 2. It creates a constant that stores the first address of this content.

This way, we can iterate over the data at runtime, using the `Deref`
instruction.

### Enabling memory management

So far, we can only use variables of fixed size. If we want to allocate memory
at runtime, we have to know what part of memory is not used by the program (or
variables, constants, data ...). This can be easily done by adding a constant
called `"free"` which resolves to an address where the first free address is
stored.

## The first compiler

We want to design a simple programming language that is then compiled down to
the assembly syntax we just made up. We will not give any examples for the
syntax here as this can be easily changed according to personal preference.In
order to get a working version that will suffice for our next project, we need
three basic things: conditionals, loops and routines.

### Conditionals

The easiest kind of conditional would be of the form
`if(condition_variable) {block}`. We can compile this in three steps:

- 1. Compile the block to lines of instructions.
- 2. Generate a unique label for the if block and add it to the last instruction
     of the block.
- 3. Add the instruction `JumpAfter @unique_label condition_variable` to the
     front of the block.

### Loops

There are, of course, different kinds of loop we want to consider. A loop
without a condition can be compiled as follows:

- 1. Generate two unique labels for the loop: `unique_start` and `unique_end`
- 2. Compile the inner block of the loop with the labels as additional contexts
     so that statements like `break` and `continue` can be handled.
- 3. Label the first instruction of the block `unique_start`.
- 4. Add the instruction `JumpTo @unique_start "0" <unique_end>` to the end.
