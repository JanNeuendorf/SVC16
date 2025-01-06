#import "@preview/colorful-boxes:1.4.0":slanted-colorbox
#let version=sys.inputs.at(default:"??.??.??","semver")
#let title= "SVC16: A Simple Virtual Computer"
#set text(size: 8pt)
#set page(
paper:"a4",
margin: (left:50pt,right:50pt,top:60pt,bottom:60pt),
flipped: false,
columns: 2,
numbering: "- 1 -",
header: align(right,[v #version])) 

#let not-specified(txt) = slanted-colorbox(
  title: "Not specified",
  color: "gray"
)[#txt]

#show link: underline
#show figure: set block(breakable: true)
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
It is also not intended to be as simple and elegant as it could possibly be. This might make it easier to emulate but harder to develop for.
Since learning about assemblers and compilers is the point, we provide no guidelines on how to build the programs.

== Reproducibility

The biggest secondary goal is to design a system that behaves the same everywhere.
The question of how the emulation is run should never matter for the person writing the program or game.
This means there can be no features that might only available in one implementation. 
It also means, that the performance characteristics must be the same.
An emulator can either run the system at the intended speed, or it can not. 

== Expandability

This might seem at odds with the previous goal. 
But if adding a new feature always requires changing the specification, that either means that supporting any new feature means breaking all compatibility, or it means that any expansions are ruled out forever.
The compromise is that the behavior for the computer itself is fixed and we define an interface and rules for expansions that can be emulated together with the computer.
The Idea is that it is always enough to know this specification and one specification (if any) for the expansion.


= General Principles

Every value is represented as a (little-endian) unsigned 16-bit integer.
That includes numbers, addresses, colors, the instruction pointer and the input.
Booleans are represented as `u16` values as well: 0 for `false` and >0 for `true`. 
Whenever an instruction writes out a boolean explicitly, it is guaranteed to represented as the number 1.

There are no registers, no built-in stack or special sections of memory. 
Operations can be performed directly on arbitrary addresses.
There is no separation between data and instructions.

All numerical operations that will appear in the instructions are wrapping operations. 
This includes manipulations of the instruction pointer. Division by zero crashes the program.

= The Simulated System
#figure(
  image("sketch.svg", width: 90%),
  caption: [A sketch of all components of the virtual computer. The shaded area indicates what is visible to the simulation.],
) <sketch>

As seen in @sketch, the addressable memory contains one value for each address.
There is a separate screen buffer of the same size as the main memory and a third buffer that is of the same size as well. 
The screen itself has a fixed resolution ($256 times 256$). 
The instruction pointer is stored separately. 
It always starts at zero. 

Information is only transferred in and out of the simulated system when it is synchronized (see @synchronization).

== Screen and Colors <screen>
The color of each pixel is represented with 16-bits using `RGB565`.
This means that a color code is given as $2^11*upright("red")+2^5*upright("green")+upright("blue")$, 
where the color channels go from zero to 31 for red and blue and 63 for green.

The coordinate $(x,y)$ of the screen maps to the index $256 y + x$ in the screen buffer.
The coordinate $(0,0)$ is in the upper left-hand corner. 


#not-specified[
- Colors do not have to be represented accurately (accessability options).
- There is no rule for how scaling and aspect ratio might be handled.
- It is not fixed what the screen shows before it is first synchronized.
- A cursor can be shown on the window, as long as its position matches the mouse position passed to the system
- There might be a delay before the updated frame is shown on screen.
  For example one might need to wait for _vsync_ or the window takes time to update.]

== Input
The only supported inputs are the mouse position and a list of eight keys. 
These keys are supposed to represent the face buttons of an NES controller.
The codes for the *A* and *B* keys also represent the left and right mouse buttons.

On synchronization the new input is loaded into the input-buffer.
Before the first synchronization, both input codes are zero.

The *position code* is the index of the pixel, the mouse is currently on. 
It follows the same convention as the screen index explained in @screen.

#let custom_button(lbl)=block(fill:rgb("#8cafbf"),outset:2pt,radius: 1pt, strong(text(fill:rgb("#fafafa"),lbl)))
#let input_table=table(
  columns: (auto, auto, auto,auto),
  align: horizon,
  table.header(
    [*Bit*],[*Controller Key*], [*Mouse Key*],[*Suggested Mapping*],
  ),
  [0],[#custom_button("A")],[Left],[*Space* / Mouse~Left],
  [1],[#custom_button("B")],[Right],[*B* / Mouse~Right],
  [2],[#emoji.arrow.t],[-],[*Up* / *W*],
  [3],[#emoji.arrow.b],[-],[*Down* / *S*],
  [4],[#emoji.arrow.l],[-],[*Left* / *A*],
  [5],[#emoji.arrow.r],[-],[*Right* / *D*],
  [6],[#custom_button("select")],[-],[*N*],
  [7],[#custom_button("start")],[-],[*M*],
  )

  #figure(
  input_table,
  caption: [The available input codes. We count from the least significant bit.],
) <inputs>

The *key code* uses bitflags. 
The bits in @inputs are supposed to indicate if a key is currently pressed (and not if it was just pressed or released). As an example, if only #emoji.arrow.t and #emoji.arrow.r are pressed, the key code is equal to the number $2^2+2^5=36$.

#not-specified[
- It is not guaranteed on which frame the virtual machine sees an input activate or deactivate.
- The emulator might not allow arbitrary combinations of buttons to be pressed simultaneously.
]


== Synchronization<synchronization>
When the console executes the *Sync* instruction, the screen buffer is drawn to the screen.
It is not cleared. The system will be put to sleep until the beginning of the next frame. 
The targeted timing is 30fps. There is a hard limit of 3000000 instructions per frame. 
This means that if the Sync command has not been called for 3000000 instructions, it will be performed automatically.
This can mean that an event (like a mouse click) is never handled.
An alternative way to describe it is that the syncing happens automatically every frame and the instructions each take $frac(1,30*3000000)$ seconds.
Then the *Sync* command just sleeps until the next frame starts. 



= Instruction Set

All instructions are 4 values long. A value is, of course, a `u16`.

The instructions have the form `opcode` `arg1` `arg2` `arg3`.

All instructions are listed in @instructions.
`@arg1` refers to the value at the memory address `arg1`.
If the opcode is greater than 15, the system will abort.


#let instruction_table=table(
  columns: (auto,auto,auto),
  align: horizon,
  table.header(
    [*Opcode*], [*Name*],[*Effect*],
  ),
  [0],[*Set*],[`if arg3{
  @arg1=inst_ptr
  }else{
  @arg1=arg2
  }`],
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
  [10],[*Debug*],[Provides `arg1,@arg2,@arg3` as debug information],
  [11],[*Print*],[Writes `value=@arg1` to `index=@arg2` of buffer `arg3`],
  [12],[*Read*],[Copies `index=@arg1` of buffer `arg3` to `@arg2`.],
  [13],[*Band*],[`@arg3=@arg1&@arg2` (binary and)],
  [14],[*Xor*],[`@arg3=@arg1^@arg2` (binary exclusive or)],
  [15],[*Sync*],[Puts `@arg1=position_code`, `@arg2=key_code` and synchronizes (in that order).If arg3!=0, it triggers the expansion port mechanism.],
  )

  #figure(
  instruction_table,
  caption: [The instruction set.],
) <instructions>

Every instruction shown in @instructions advances the instruction pointer by four positions _after_ it is completed. The exceptions to this are the *GoTo* and *Skip* instructions. They only do this, if the condition is _not_ met.

When an argument refers to the name of a buffer, it means the screen buffer if it is 0 and the utility buffer otherwise.

== The Debug Instruction
The *Debug* instruction is special, as it does not change anything about the state of the system.
It still counts as an instruction for the maximum instruction count.
It is up to the implementation if, when and in what way the information is provided to the user.
This means that it is valid to not do anything when the instruction is triggered. 
In fact, this might be necessary to run the emulator at the intended speed.

The way to think about the signature of the instruction is that the first argument is a label and the other arguments are the values of variables/addresses.

The instruction is meant only for debugging.
For the programmer that means that the output should not be needed for the use of the program or game as it might be shown in different ways or not at all.
For the emulator that means that there should be no functionality that depends on the *Debug* instruction. 
 

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
  - It is not guaranteed that the emulator itself closes if an exception occurs. (So you can not use it to quit a program.)
  - Expansions (see @expansion) might introduce new conditions for failure.
]

= The Utility Buffer and the Expansion Port<expansion>

The utility buffer behaves a lot like the screen buffer with the obvious difference that it is not drawn to the screen.
This can be used for intermediate storage at runtime, but it is always initialized to be filled with zeros when the program starts.

Its second function is to communicate with the expansion port.
The goal is to provide a mechanism for someone to add additional functionality to their emulator without making it completely incompatible.
This we call the expansion card.
The mechanism works as follows:
If the expansion port is triggered with the *Sync* instruction, it writes out the full utility buffer through the virtual port, making it available for the expansion card to read. It is then replaced by $2^16$ new values provided by the expansion. From the programs perspective, this is an atomic operation. It triggers the mechanism with the *Sync* instruction and when it gets to run again, the whole buffer has been exchanged. This is supposed to model a transfer of data between the program and the virtual expansion card. 
It should follow the following rules:
- The data coming in can not depend on the data being flushed out this frame. It can be influenced by previous transfers, but it can not run computations during a transfer. 
- The expansion card does not get access to any other information internal to the system (screen buffer, memory or instruction pointer). It can not manipulate these components either. 
- It can not manipulate the utility buffer at any point where the mechanism was not explicitly activated.
- It can not see or manipulate what is on the screen or what input is being passed to the system.
- It can not change any rule of the emulation. 


Synchronizations that are caused by exceeding the instruction limit never trigger the expansion mechanism. The expansion card can not know that such a synchronization happened. 


If no expansion card is available, there is no answer when the exchange is triggered. As a result the utility buffer is simply cleared.

Here are some examples of what an expansion card might do:
- Play an audio sample. 
- Provide keyboard or other text input. 
- Perform some computation on the input and report back the result the next time it is activated. 
- Access some emulated file system. 
- Connect two SVC16 systems.

The mechanism is intentionally designed to allow for emulators that mimic _swapping the expansion card at runtime_.
The system itself has no mechanism to know with which expansion (if any) it is being emulated at any given time, so in addition to changing the expansion externally this change would need to be communicated to the program. 


= Miscellaneous
Further information, examples and a reference emulator can be found at #link("https://github.com/JanNeuendorf/SVC16").
Everything contained in this project is provided under the _MIT License_.
Do with it whatever you want.

One think we would ask is that if you distribute a modified version that is incompatible with the specifications,
you make it clear that it has breaking changes. 

= Example Program 

#[
  
  #show raw: it => block(
  fill: rgb("#f5f5f5"),
  inset: 10pt,
  radius: 4pt,
  stroke: (paint: rgb("9e9e9e"),thickness: 2pt),
  text(fill: rgb("#000000"), it))

While this is not needed for the specifications, it might be helpful to look at a very simple example. 


Our goal could be to print all $2^16$ possible colors to the screen.
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
Can you figure why the program crashes if a button is pressed? How could this be fixed?
]

