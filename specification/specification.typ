#import "@preview/colorful-boxes:1.4.0":slanted-colorbox
#let title= "SVC16: A Simple Virtual Computer"
#set text(size: 8pt)
#set page(
paper:"a4",
margin: (left:40pt,right:40pt,top:60pt,bottom:60pt),
flipped: false,
columns: 2,
numbering: "- 1 -",
foreground: rotate(24deg,
  text(48pt, fill: rgb("#ff4e375f"))[
    *WORK IN PROGRESS*
  ]
))

#let not-specified(txt) = slanted-colorbox(
  title: "Not specified",
  color: "gray"
)[#txt]

#show link: underline
#set heading(numbering:"1.1")
#set table(inset:10pt,fill:rgb("#f5f5f5"),stroke:(paint:rgb("#000000"),thickness: 1pt))

#{
  

  set align(center)
  text(17pt,emph(title))
  
}

= Motivation and Goals

We want to fully specify a very simple virtual computer that can be emulated.
The goal is to recreate the feeling of writing games for a system with very tight hardware constraints without having to deal with the complicated reality of real retro systems. 
It should be simple to understand every instruction, to write machine code that runs on it, and to write a compiler for it.
The instruction set and the design in general are in no way meant to resemble something that would make sense in real hardware.
It is also not intended to be as simple and elegant as it could possibly be. This might make it easier to explain but harder to develop for.
Since learning about assemblers and compilers is the point, we provide no guidelines on how to build the programs.

== Reproducibility

The biggest secondary goal is to design a system that behaves the same everywhere.
The question of how the emulation is run should never matter for the person writing the program or game.
This means there can be no features that might only available in one implementation. 
It also means, that the performance characteristics must be the same.
An emulator can either run the system at the intended speed, or it can not. 


= General Principles

Every value is represented as a (little-endian) unsigned 16-bit integer.
That includes numbers, addresses, colors, the instruction pointer and the input.
Booleans are represented as `u16` values as well: 0 for `false` and >0 for `true`. 
Whenever an instruction writes out a boolean explicitly, it is guaranteed to represented as the number 1.

All numerical operations that will appear in the instructions are wrapping operations. 
This includes manipulations of the instruction pointer.

Division by zero crashes the program.

= The Simulated System
#figure(
  image("sketch.svg", width: 90%),
  caption: [A sketch of all components of the virtual computer.],
) <sketch>

As seen in @sketch, the addressable memory contains one value for each address.
There is a separate screen buffer of the same size as the main memory.
The screen itself has a fixed resolution ($256 times 256$). 
The instruction pointer is stored separately. 
It always starts at zero. 

== Screen and Colors <screen>
The color of each pixel is represented with 16-bits using `RGB565`.
The coordinate $(x,y)$ of the screen maps to the index $256 y + x$ in the screen buffer.
The coordinate $(0,0)$ is in the upper left-hand corner. Changes to the screen-buffer are not reflected on the screen until the system is synchronized.

#not-specified[
- Colors do not have to be represented accurately (accessability options).
- There is no rule for how scaling and aspect ratio might be handled.
- It is not fixed what the screen shows before it is first synchronized.
- A cursor can be shown on the window, as long as its position matches the mouse position passed to the system]

== Input
The only supported inputs are the mouse position and a list of eight keys. 
These keys are supposed to represent the face buttons of an NES controller.
The codes for the *A* and *B* keys also represent the left and right mouse buttons.

On synchronization the new input is loaded into the input-buffer.
Before the first synchronization, both input codes are zero.

The *position code* is the index of the pixel, the mouse is currently on. 
It follows the same convention as the screen index explained in @screen.


#let input_table=table(
  columns: (auto, auto, auto,auto),
  align: horizon,
  table.header(
    [*Bit*],[*Controller Key*], [*Mouse Key*],[*Suggested Mapping*],
  ),
  [0],[*A*],[Left],[*Space* / Mouse Left],
  [1],[*B*],[Right],[*B* / Mouse Right],
  [2],[*Up*],[-],[*Up* / *W*],
  [3],[*Down*],[-],[*Down* / *S*],
  [4],[*Left*],[-],[*Left* / *A*],
  [5],[*Right*],[-],[*Right* / *D*],
  [6],[*Select*],[-],[*N*],
  [7],[*Select*],[-],[*M*],
  )

  #figure(
  input_table,
  caption: [The available input codes. We count from the least significant bit.],
) <inputs>

The *key code* uses bitflags. 
The bits in @inputs are supposed to indicate if a key is currently pressed (and not if it was just pressed or released). As an example, if only the *A* and the *Down* key are pressed, the key code is equal to the number $2^0+2^3=9$.

#not-specified[
- It is not guaranteed on which frame the virtual machine sees an input activate or deactivate.
- The emulator might not allow arbitrary combinations of buttons to be pressed simultaneously.
]


== Synchronization
When the console executes the *Sync* instruction, the screen buffer is drawn to the screen.
It is not cleared. The system will be put to sleep until the beginning of the next frame. 
The targeted timing is 30fps. There is a hard limit of 3000000 instructions per frame. 
This means that if the Sync command has not been called for 3000000 instructions, it will be performed automatically.
This can mean that an event (like a mouse click) is never handled.
An alternative way to describe it is that the syncing happens automatically every frame and the instructions each take $frac(1,30*3000000)$ seconds. Then the *Sync* command just sleeps until the next frame starts. 

= Instruction Set

All instructions are 4 values long. A value is, of course, a `u16`.

The instructions have the form `opcode` `arg1` `arg2` `arg3`.

In the following table, all instructions are listed. `@arg1` refers to the value at the memory address `arg1`. If the opcode is greater than 15, the system will abort. If one of the three arguments is not used, it can be set to any value, but it can not be omitted.

When the instruction pointer advances, it does so by four positions.

#let instruction_table=table(
  columns: (auto,auto,auto),
  align: horizon,
  table.header(
    [*Opcode*], [*Name*],[*Effect*],
  ),
  [0],[*Set*],[`@arg1=arg2`],
  [1],[*GoTo*],[`if(not @arg3){inst_ptr=@arg1+arg2}`],
  [2],[*Skip*],[
  ```
  if(not @arg3){
    inst_ptr=inst_ptr+4*arg1-4*arg2
    }
  ```
  ],
  [3],[*Add*],[`@arg3=(@arg1+@arg2)`],
  [4],[*Sub*],[`@arg3=(@arg1-@arg2)`],
  [5],[*Mul*],[`@arg3=(@arg1*@arg2)`],
  [6],[*Div*],[`@arg3=(@arg1/@arg2)`],
  [7],[*Cmp*],[`@arg3=(@arg1<@arg2)` (as unsigned)],
  [8],[*Deref*],[`@arg2=@(@arg1+arg3)`],
  [9],[*Ref*],[`@(@arg1+arg3)=@arg2`],
  [10],[*Inst*],[`@arg1=inst_ptr`],
  [11],[*Print*],[Writes `color=@arg1` to `index=@arg2` of the screen buffer.],
  [12],[*Read*],[Copies `index=@arg1` of the screen buffer to `@arg2`.],
  [13],[*Band*],[`@arg3=@arg1&@arg2` (binary and)],
  [14],[*Xor*],[`@arg3=@arg1^@arg2` (binary exclusive or)],
  [15],[*Sync*],[Puts `@arg1=position_code`, `@arg2=key_code` and synchronizes (in that order).],
  )

  #figure(
  instruction_table,
  caption: [The instruction set.],
) <instructions>

Every instruction shown in @instructions advances the instruction pointer by four positions _after_ it is completed. The exceptions to this are the *GoTo* and *Skip* instructions. They only do this, if the condition is _not_ met.

= Constructing the Program

A program is really just the initial state of the main memory.
There is no distinction between memory that contains instructions and memory that contains some other asset.
The initial state is loaded from a binary file that is read as containing the (le) u16 values in order. 
The maximum size is $2*2^16  upright("bytes") approx 131.1 upright("kB")$.
It can be shorter, in which case the end is padded with zeroes.
The computer will begin by executing the instruction at index 0.

= Handling Exceptions 
There are only two reasons the program can fail (for internal reasons).

- It tries to divide by zero
- It tries to execute an instruction with an opcode greater than 15. 

In both cases, the execution of the program is stopped. It is not restarted automatically.
(So you can not cause an error to restart a game.) 
There is intentionally no way of restarting or even quitting a program from within.

#not-specified[
  - There is no rule for how (or even if) the cause of the exception is reported.
  - It is not guaranteed that the emulator closes if an exception occurs. (So you can not use it to quit a program.)
]

= Example Program 

#[
  
  #show raw: it => block(
  fill: rgb("#f5f5f5"),
  inset: 10pt,
  radius: 4pt,
  stroke: (paint: rgb("9e9e9e"),thickness: 2pt),
  text(fill: rgb("#000000"), it))


A simple example would be to print all $2^16$ possible colors to the screen.
We make our lives easier, by mapping each index of the screen buffer to the color which is encoded with the index.
Here, we use the names of the opcodes instead of their numbers.

```typ
// Write the value 1 to address 501
Set 501 1 0 
// Write the largest possible value to 502
Set 502 65535 0
// Display color=@500 at screen-index=@500
Print 500 500 0
// Increment the color/screen-index
Add 500 501 500
// See if we are not at the max number and negate it.
Cmp 500 502 503 
Xor 503 501 503
// Unless we are at the max number,
// go back 4 instructions.
Skip 0 4 503
// Sync and repeat.
Sync 0 0 0
GoTo 0 0 0 
```
We could rely on the fact that the value at index 500 starts at zero and we did not have to initialize it.

To build a program that we can execute, we could use python #emoji.snake:

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


```
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
Every line represents one instruction.
The second column is zero because it is the most significant byte of the opcode.


When we run this, we should see the output shown in @colors.
#figure(
  image("colors_scaled.png", width: 40%),
  caption: [Output of the color example.],
) <colors>

]

= Miscellaneous
Further information, examples and a reference emulator can be found at #link("https://github.com/JanNeuendorf/SVC16").
Everything contained in this project is provided under the _MIT License_.
Do with it whatever you want.

One think we would ask is that if you distribute a modified version that is incompatible with the specifications,
you make it clear that it has breaking changes. 