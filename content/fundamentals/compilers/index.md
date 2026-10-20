---
title: "What Is a Compiler? How Source Code Becomes a Running Program"
description: "A compiler translates a program from the language people write into the language a machine runs. Here is what that means, how compilers came to be, how each phase works, how gcc turns a C file into an executable, and how to build a small compiler yourself."
date: 2026-10-20T16:00:00Z
categories: ["Fundamentals"]
tags: ["Compilers", "Programming Languages", "Toolchains", "Computer Science", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

[What Is Programming?]({{< ref "what-is-programming" >}}) ended with
high-level languages taking over from machine code, and
[What Is a Processor?]({{< ref "processors" >}}) described the machine
instructions a CPU actually runs. Between the two sits the compiler: the
program that turns one into the other. This article explains what a compiler
is, where compilers came from, how each of their phases works, how a C file
becomes an executable on a real system, and how to build a small compiler of
your own. Every compiler output shown here was produced by running the tools
on Ubuntu 22.04 with GCC 11.4 and Python 3.10, not written by hand.

## What a compiler is

**A compiler is a program that translates a program written in one language,
the source language, into an equivalent program in another language, the
target language, and reports errors it finds in the source along the
way.**[^dragon]

Usually the source is a high-level language such as C, Rust or Go and the
target is machine code for a particular processor, but the definition is
wider than that. What makes something a compiler is that it translates the
whole program *before* it runs, preserving its meaning, rather than carrying
it out.

| Kind of translator | What it does | Examples |
|---|---|---|
| **Compiler** | Translates a whole program ahead of time into a lower-level language | GCC, Clang, `rustc`, the Go compiler |
| **Assembler** | Translates assembly language, one mnemonic per machine instruction, into machine code | GNU `as`, NASM |
| **Interpreter** | Reads a program and carries out its instructions directly, without producing a translated program | Shells, early BASIC |
| **Bytecode compiler and virtual machine** | Compiles to a portable intermediate code that a virtual machine then runs | `javac` and the JVM, CPython |
| **Just-in-time (JIT) compiler** | Compiles parts of a program to machine code *while it runs*, guided by what it observes | Java HotSpot, JavaScript engines such as V8 |
| **Source-to-source compiler (transpiler)** | Translates between languages at a similar level | TypeScript to JavaScript |
| **Cross-compiler** | Runs on one kind of machine and produces code for another | Building phone or microcontroller software on a laptop |

Every compiler has two halves. The **front end** reads the source language:
it checks that the program is well formed and works out what it means. The
**back end** produces the target language. In between, most modern compilers
have a **middle end** that improves the program without being tied to either
the source language or the target machine.

## A history of compilers

### The 1950s: the computer writes its own programs

Early programs were written directly in machine code or assembly. In 1952 Grace
Hopper's **A-0** system assembled programs from a library of subroutines, and
she argued that computers should take over this kind of clerical work from
programmers.[^hopper] She called it a "compiler" because it compiled programs
from library routines, and she is usually credited with coining the term,
though its modern meaning came later.[^hoppermilestone] The same year, Alick
Glennie wrote **Autocode** for the Manchester Mark 1, an early translator for a
more readable, though still machine-dependent, notation.[^knuthpardo]

The breakthrough was **FORTRAN**. A team at IBM led by John Backus delivered
the FORTRAN compiler for the IBM 704 in 1957, after about three years of
work.[^backus57][^backus78][^ibmfortran] Its central achievement was optimisation: it
produced code nearly as efficient as experienced programmers wrote by hand,
which persuaded a sceptical industry that high-level languages were
practical.[^backus78]

### The 1960s and 1970s: compilers get a theory

Writing a compiler was at first a feat of craftsmanship. Over the next two
decades it became an engineering discipline built on theory.

- **Grammars.** Noam Chomsky's work on formal grammars, begun in 1956 and
  refined into a hierarchy of grammar types in 1959, gave a precise way to
  describe the syntax of a language.[^chomsky][^chomsky59] The ALGOL 60
  report defined its syntax in the notation now called Backus–Naur Form, so
  that a grammar could be the language's official definition.[^algol60]
- **Parsing.** Donald Knuth's 1965 paper on LR parsing showed how to parse any
  deterministic context-free language efficiently, left to right, in a single
  pass.[^knuth65] Frank DeRemer's simpler variants, SLR and LALR, made LR
  parsers small enough to be practical.[^deremer]
- **Generators.** At Bell Labs, Stephen Johnson's **yacc** (1975) generated a
  parser from a grammar, and Mike Lesk and Eric Schmidt's **lex** generated a
  lexer from regular expressions; their descendants, Bison and Flex, are still in use.[^yacc][^lex]
- **Optimisation.** Frances Allen's work at IBM put control-flow analysis on a
  formal footing,[^allen] and Gary Kildall's 1973 framework unified data-flow
  analyses.[^kildall] Allen became the first woman to receive the Turing Award,
  in 2006, for this work.[^allenturing][^ibmallen]
- **Textbooks.** Alfred Aho and Jeffrey Ullman's *Principles of Compiler Design*
  (1977), the first "Dragon Book" after its cover, made the theory standard
  teaching; its successor is still a standard reference.[^aho77][^dragon]

### The 1980s and 1990s: better code, more targets

Gregory Chaitin and colleagues at IBM turned **register allocation**, deciding
which values live in the processor's few registers, into a graph-colouring
problem (1981–82).[^chaitin81][^chaitin] Ron Cytron and colleagues showed in 1991 how to compute
**static single assignment (SSA)** form efficiently, an intermediate form in
which every variable is assigned exactly once; most modern optimising
compilers, GCC and LLVM among them, use it.[^ssa][^treessa][^llvmlangref]

Richard Stallman released the **GNU C Compiler** in 1987 as part of the GNU
project. Now the GNU Compiler Collection, it supports many languages and
processors and was for decades the standard compiler of free
software.[^gccrel] Just-in-time compilation also matured: Peter Deutsch and
Allan Schiffman's 1984 Smalltalk-80 implementation translated code to machine
code on demand, and Java's **HotSpot** virtual machine (1999) made adaptive JIT
compilation mainstream.[^deutsch][^aycock][^hotspot]

### The 2000s to today: compiler infrastructure

Chris Lattner and Vikram Adve's **LLVM** (2004) recast the compiler as a set of
reusable libraries built around a single, well-specified intermediate
representation.[^llvm04] **Clang**, a front end for C, C++ and Objective-C
begun at Apple and open-sourced in 2007, followed,[^clang] and LLVM now also
generates code for Rust, Swift and many other languages.[^aosa][^rustcodegen][^swiftcompiler]
JavaScript engines such as Google's V8 (2008) brought multi-tier JIT
compilation to every web browser,[^v8] and **WebAssembly**, supported by all
major browsers by the end of 2017, gave them a portable compilation target for
languages other than JavaScript.[^wasm][^wasmbrowsers]

Two older ideas have become practical concerns. In 1984 Ken Thompson showed
that a compiler can be made to insert a back door into chosen programs, and
into every future version of itself, leaving no trace in any source
code.[^thompson] And **CompCert**, a C compiler developed by a team led by
Xavier Leroy and first released in 2008, comes with a machine-checked proof in
the Coq proof assistant that the code it generates behaves as the source
program's semantics allow.[^compcert][^compcertsite]

## A timeline at a glance

| Year | Milestone |
|---|---|
| 1952 | Hopper's A-0; Glennie's Autocode |
| 1956–59 | Chomsky's formal grammars and their hierarchy |
| 1957 | The FORTRAN compiler |
| 1960 | ALGOL 60 report, with syntax in Backus–Naur Form |
| 1965 | Knuth's LR parsing |
| 1970 | Allen's control-flow analysis |
| 1973 | Kildall's data-flow framework |
| 1975 | yacc and lex |
| 1977 | The first Dragon Book |
| 1981–82 | Register allocation by graph colouring |
| 1984 | Thompson's *Reflections on Trusting Trust*; Smalltalk-80 JIT |
| 1987 | GCC |
| 1991 | Efficient SSA construction |
| 1999 | Java HotSpot |
| 2004 | LLVM |
| 2008 | First release of the CompCert verified compiler |
| 2017 | WebAssembly in all major browsers |

## How a compiler works

A compiler is a pipeline. Each phase takes one representation of the program
and produces another, a little closer to the machine.

{{< diagram src="compiler-pipeline.svg" caption="The phases of a typical compiler. Real compilers interleave and repeat some of them, but the order is the same." >}}

To follow a program through the pipeline, take one C function:

```c
int scale(int a, int b) {
    int x = a + b * 2;
    return x;
}
```

### Lexical analysis

The **lexer** (or scanner) reads the source as a stream of characters and
groups them into **tokens**, the words of the language: identifiers, keywords,
numbers, operators and punctuation. It throws away what the grammar does not
care about, such as spaces and comments, and records where each token came from
so that error messages can point at the right line.

Token patterns are **regular expressions** (an identifier is a letter followed
by letters or digits), and a lexer is in effect a finite automaton that
recognises them all at once, which is exactly what lex generates.[^dragon][^lex]
The statement `x = a + b * 2` becomes seven tokens.

### Syntax analysis

The **parser** checks the tokens against the language's **grammar** and builds
a **syntax tree** that records their structure. A grammar for arithmetic
expressions, in extended Backus–Naur Form, can be as short as:

```txt
expr    = term   { ("+" | "-") term } ;
term    = factor { ("*" | "/") factor } ;
factor  = number | identifier | "(" expr ")" ;
```

The layering encodes **precedence**: because a `term` is built from `factor`s
joined by `*` and `/`, multiplication binds more tightly than addition, and
`a + b * 2` parses as `a + (b * 2)`.

{{< diagram src="ast.svg" caption="From characters to structure: the tokens the lexer produces, and the syntax tree the parser builds from them." >}}

There are two families of parsing technique:[^dragon]

| | Top-down (LL) | Bottom-up (LR) |
|---|---|---|
| **How it works** | Starts from the grammar's start symbol and predicts which rule comes next | Shifts tokens onto a stack and reduces them to rules once a rule's right-hand side is complete |
| **Usually written** | By hand, as **recursive descent**: one function per grammar rule | By a generator such as yacc or Bison, from the grammar |
| **Strengths** | Simple, fast, easy to give good error messages | Handles a larger class of grammars |
| **Used by** | GCC's and Clang's C and C++ front ends, the Go compiler, most new compilers | Many language tools and older compilers |

### Semantic analysis

A program can be grammatically perfect and still meaningless: it can use a
variable that was never declared, call a function with the wrong number of
arguments, or add a string to a structure. **Semantic analysis** catches these.
It builds a **symbol table** that records every name and what it refers to in
each scope, works out the type of every expression, inserts implicit
conversions (such as `int` to `double`), and reports errors. The output is the
same tree, now annotated with types and resolved names.

### Intermediate representation

The checked tree is then **lowered** into an **intermediate representation
(IR)**: a simpler language, closer to the machine but independent of any one
processor, in which each instruction does one small thing. GCC's main
language-independent IR, GIMPLE, is a three-address code.[^gimple] Asking GCC to show it for `scale`
(`gcc -fdump-tree-gimple`) gives:

```txt
int scale (int a, int b)
{
  int D.1948;
  int x;

  _1 = b * 2;
  x = a + _1;
  D.1948 = x;
  return D.1948;
}
```

The nested expression has been flattened into steps with a temporary, `_1`.
LLVM's IR plays the same role in Clang, Rust and Swift.[^llvmlangref] Most
optimisers then convert the IR into **SSA form**, where every variable is
assigned exactly once, because that makes it easy to see where each value comes
from and where it is used.[^ssa]

### Optimisation

The **optimiser** is a sequence of passes, each of which takes IR and returns
equivalent, better IR: faster, smaller, or both. GCC and LLVM each run dozens of
them.[^gccopt][^llvmpasses]

| Optimisation | What it does |
|---|---|
| **Constant folding and propagation** | Computes at compile time anything whose value is already known |
| **Dead code elimination** | Removes code whose results are never used |
| **Common subexpression elimination** | Computes a repeated expression once |
| **Inlining** | Replaces a call with a copy of the called function's body, which exposes further optimisations |
| **Loop-invariant code motion** | Moves work that does not change between iterations out of the loop |
| **Strength reduction** | Replaces expensive operations with cheaper ones, such as a multiplication with a shift or an addition |
| **Vectorisation** | Rewrites loops to use SIMD instructions that process several values at once |

Optimisations combine to remarkable effect. Given this code:

```c
static int sum_to(int n) {
    int s = 0;
    for (int i = 1; i <= n; i++)
        s += i;
    return s;
}

int answer(void) {
    return sum_to(10) * 2;
}
```

`gcc -O2` inlines `sum_to`, runs the loop at compile time and folds the
multiplication, so the whole of `answer` becomes a single constant (directives
trimmed):

```asm
answer:
	endbr64
	movl	$110, %eax
	ret
```

Optimisers are not allowed to change what a correct program does, and that is
a precise contract defined by the language standard. Code with undefined
behaviour, such as signed integer overflow in C, falls outside it, which is why
such bugs can appear or disappear when the optimisation level changes.[^ub]

### Code generation

The **back end** turns IR into instructions for a real processor. It has three
main jobs:

1. **Instruction selection** chooses machine instructions for each piece of IR.
   Several IR operations can often be covered by one instruction.
2. **Register allocation** decides which values live in the processor's small
   set of registers and which must be kept in memory (**spilled**). Chaitin's
   approach builds an *interference graph*, with an edge between any two values
   alive at the same time, and colours it with as many colours as there are
   registers.[^chaitin]
3. **Instruction scheduling** orders the instructions to keep the processor's
   pipelines busy.

It must also follow the platform's **calling convention**, the rules for
passing arguments and results that let separately compiled code work together.
On x86-64 Linux, the System V ABI passes the first integer arguments in `rdi`,
`rsi`, `rdx`, `rcx`, `r8` and `r9` and returns integers in `rax`.[^sysvabi]

Here is `scale` compiled without optimisation (`gcc -O0 -S`, directives
trimmed). Every variable lives in memory on the stack, exactly as written:

```asm
scale:
	endbr64
	pushq	%rbp
	movq	%rsp, %rbp
	movl	%edi, -20(%rbp)        # store a
	movl	%esi, -24(%rbp)        # store b
	movl	-24(%rbp), %eax        # load b
	leal	(%rax,%rax), %edx      # b * 2
	movl	-20(%rbp), %eax        # load a
	addl	%edx, %eax             # a + b * 2
	movl	%eax, -4(%rbp)         # store x
	movl	-4(%rbp), %eax         # return x
	popq	%rbp
	ret
```

And with `gcc -O2`. The register allocator keeps everything in registers, and
instruction selection notices that `a + b * 2` is exactly what x86's
address-calculation instruction `lea` computes:

```asm
scale:
	endbr64
	leal	(%rdi,%rsi,2), %eax
	ret
```

(The comments in the `-O0` listing are added; the instructions are GCC's. The
`endbr64` at the start of each function is a marker for Intel's control-flow
protection, which Ubuntu's GCC enables by default.)[^cet]

### Assembly and machine code

Assembly language is still text. The **assembler** encodes each instruction
into the bytes the processor decodes. Disassembling the optimised object file
(`objdump -d`) shows both:

```txt
0000000000000000 <scale>:
   0:	f3 0f 1e fa          	endbr64
   4:	8d 04 77             	lea    (%rdi,%rsi,2),%eax
   7:	c3                   	ret
```

The whole function is eight bytes. `8d 04 77` is the `lea` instruction: the
opcode `8d`, then two bytes that name the registers and the scale factor of 2.

### One compiler, many languages and machines

A compiler for *M* languages and *N* processors would need *M × N* separate
translators if each went straight from source to machine code. A shared IR
cuts that to *M* front ends plus *N* back ends, with one optimiser that all of
them share.[^aosa]

{{< diagram src="ir-hub.svg" caption="A shared intermediate representation lets front ends and back ends be written once and combined freely." >}}

This is the design of both GCC and LLVM. It is why a new language such as Rust
could produce fast code for many processors early on: it needed only a front
end that emitted LLVM IR, and it inherited the optimiser and every back end.

## From source code to a running program

"Compiling" a C program with `gcc` actually goes through four stages, run by
three programs: the compiler proper, `cc1`, which also does the preprocessing;
the assembler, `as`; and the linker, `ld`. The operating system adds a fifth
step when the program starts. The GCC options
`-E`, `-S` and `-c` stop the process after each stage, so each one can be
seen on its own.[^gccoverall]

{{< diagram src="toolchain.svg" caption="Each stage of building and running hello.c, with the gcc option that stops after it and what the output holds. The sizes are from the build described below." >}}

The program is the classic:

```c
#include <stdio.h>

int main(void) {
    printf("hello, world\n");
    return 0;
}
```

### 1. Preprocessing

The **preprocessor** handles the lines beginning with `#`: it pastes in
`#include`d files, expands macros and evaluates conditional compilation.
`gcc -E hello.c -o hello.i` turns these 6 lines into 744, almost all of them the
declarations from `<stdio.h>`, including:

```c
extern int printf (const char *__restrict __format, ...);
```

### 2. Compilation

The **compiler proper** translates the preprocessed C into assembly, through
all the phases above. `gcc -S hello.c` produces, in part:

```asm
.LC0:
	.string	"hello, world"
	.text
	.globl	main
	.type	main, @function
main:
	endbr64
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	.LC0(%rip), %rax
	movq	%rax, %rdi
	call	puts@PLT
	movl	$0, %eax
	popq	%rbp
	ret
```

Even without optimisation, GCC has replaced `printf` with `puts`. It knows the
meaning of standard library functions, and printing a constant string that
ends in a newline is exactly what `puts` does, more cheaply; `-fno-builtin`
turns this off.[^gccbuiltins]

### 3. Assembly

The **assembler** encodes the instructions into machine code and writes an
**object file**. `gcc -c hello.c` produces `hello.o`, which `file` describes
as an *ELF 64-bit LSB relocatable, x86-64* file. ELF, the Executable and
Linkable Format, is the standard file format for programs on Linux and most
Unix-like systems; Windows uses PE/COFF and macOS Mach-O for the same
purpose.[^elf]

An object file is not yet runnable. Its **symbol table** (`nm hello.o`) shows
one symbol it defines and one it only uses:

```txt
0000000000000000 T main
                 U puts
```

`T` means `main` is defined in the text (code) section; `U` means `puts` is
undefined here and must come from somewhere else. The machine code has holes
where those addresses will go, each marked with a **relocation** that tells the
linker what to fill in (`objdump -dr hello.o`):

```txt
   8:	48 8d 05 00 00 00 00 	lea    0x0(%rip),%rax
			b: R_X86_64_PC32	.rodata-0x4
   f:	48 89 c7             	mov    %rax,%rdi
  12:	e8 00 00 00 00       	call   17 <main+0x17>
			13: R_X86_64_PLT32	puts-0x4
```

The zeros after `48 8d 05` and after the call opcode `e8` are placeholders for
the address of the string and of `puts`.

### 4. Linking

The **linker** combines object files and libraries into one executable. It
does two jobs: **symbol resolution**, matching every undefined symbol with a
definition, and **relocation**, assigning final addresses and patching every
hole.[^levine] It also adds start-up code from the C library that sets the
process up and then calls `main`.

Libraries can be linked in two ways:

| | Static linking | Dynamic linking |
|---|---|---|
| **How** | The library's code is copied into the executable | The executable records which shared library it needs; the code is loaded when the program starts |
| **Pros** | One self-contained file; no dependency problems | Smaller files; one copy of the library in memory is shared by every program; security fixes apply without relinking |
| **Cons** | Larger files; every program must be rebuilt to pick up a library fix | The right library version must be present at run time |

By default `gcc hello.o -o hello` links dynamically. The result is a
16-kilobyte *ELF 64-bit LSB pie executable … dynamically linked, interpreter
/lib64/ld-linux-x86-64.so.2*, and `ldd hello` lists the shared libraries it
will need:

```txt
	linux-vdso.so.1 (0x000077dc90b2d000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x000077dc90800000)
	/lib64/ld-linux-x86-64.so.2 (0x000077dc90b2f000)
```

`puts` now appears as `U puts@GLIBC_2.2.5`: still undefined in the file, but
bound to a specific version of the C library, to be resolved when the program
runs. Calls to it go through small stubs in the **procedure linkage table
(PLT)**, which jump through slots in the **global offset table (GOT)** that the
dynamic linker fills in.[^dsohowto] Ubuntu links with `-z now`, so this
happens when the program starts rather than on the first call.

### 5. Loading and running

Typing `./hello` asks the kernel to `execve` the file
([What Is an Operating System?]({{< ref "operating-systems" >}}) describes the
system call). The kernel reads the ELF header (`readelf -h` reports *Type: DYN
(Position-Independent Executable file)* and an entry point of `0x1060`), maps
the file's code and data segments into a new address space, and, because the
file names an *interpreter*, starts the **dynamic linker**,
`ld-linux-x86-64.so.2`, first.[^ldso] The dynamic linker maps `libc.so.6`,
resolves the symbols the program needs, and jumps to the program's entry point.
The C library's start-up code calls `main`, `puts` writes the line, and the
program prints:

```txt
hello, world
```

Because the executable is **position-independent (PIE)**, the kernel can load
it at a different random address each time it runs, which makes memory-corruption
attacks harder.[^pie]

## Compilers, interpreters and JITs

Compilation and interpretation are not opposites so much as two ends of a
range, and most language implementations sit somewhere in between.

{{< diagram src="execution-models.svg" caption="Three ways to run a program. The dashed line separates work done before the program runs from work done while it runs." >}}

- **Ahead-of-time compilation** does all the translation before the program
  runs, so nothing is spent on it at run time, and the compiler can take its
  time optimising. C, C++, Rust and Go work this way.
- **Interpretation** skips translation: the interpreter reads the program and
  performs each operation itself. It starts instantly and is simple, but each
  operation costs many machine instructions of interpreter overhead.
- **Bytecode** is a middle path. CPython, for example, compiles source to
  bytecode for a stack-based virtual machine and then interprets that
  bytecode.[^pydis] In Python 3.10, `dis.dis('x = a + b * 2')` shows the same
  expression as before, now for a stack machine:

  ```txt
    1           0 LOAD_NAME                0 (a)
                2 LOAD_NAME                1 (b)
                4 LOAD_CONST               0 (2)
                6 BINARY_MULTIPLY
                8 BINARY_ADD
               10 STORE_NAME               2 (x)
               12 LOAD_CONST               1 (None)
               14 RETURN_VALUE
  ```

- **Just-in-time compilation** adds a compiler to the virtual machine. The VM
  typically starts by interpreting, counts which code runs most, and compiles those **hot**
  parts to machine code, using what it has observed (such as the actual types
  that reach a function) to optimise more aggressively than would be safe
  without that information. If an assumption later proves wrong, it falls back
  to the interpreter.[^aycock][^hotspot] Some virtual machines, such as .NET's,
  skip interpretation and JIT-compile each method the first time it is
  called.[^dotnet]

## How to build a compiler

A compiler sounds forbidding, but a small one fits in a page. Building one is
one of the best ways to understand how languages work. The recipe is the
pipeline above:

1. **Define the language.** Write its grammar first, small enough to finish.
2. **Write the lexer.** Regular expressions are enough for most languages.
3. **Write the parser.** Recursive descent, one function per grammar rule, is
   the easiest to write and debug.
4. **Check the tree.** Build a symbol table and report undefined names and
   type errors.
5. **Generate code.** The simplest strategy treats the processor as a **stack
   machine**: compute each operand, push it, pop operands to combine them. The
   code is slow but correct, and correctness comes first.
6. **Test it end to end.** Compile real programs, run them, and compare the
   output with what the language says it should be.

### A complete example

Here is a working compiler, in about 150 lines of Python, for a tiny language
of integer variables and arithmetic. It compiles a program such as

```txt
let x = 6 * 7
let y = (x - 2) / 4
print y + x
print -y * 3
```

into x86-64 assembly, which GCC then assembles and links. Each of the four
phases is a section of the code:

```python
"""tinyc: compile a tiny calculator language to x86-64 assembly.

    let x = 6 * 7
    print x / 2 + 1

Usage: python3 tinyc.py prog.calc > prog.s && gcc prog.s -o prog && ./prog
"""
import re
import sys

# 1. Lexical analysis: characters -> tokens
TOKEN = re.compile(r"\s*(?:(\d+)|([A-Za-z_]\w*)|(.))")

def lex(src):
    tokens = []
    for line in src.splitlines():
        for number, name, op in TOKEN.findall(line):
            if number:
                tokens.append(("num", int(number)))
            elif name:
                tokens.append(("kw" if name in ("let", "print") else "id", name))
            elif op.strip():
                tokens.append(("op", op))
        tokens.append(("nl", None))
    return tokens + [("eof", None)]

# 2. Syntax analysis: tokens -> abstract syntax tree (recursive descent)
class Parser:
    def __init__(self, tokens):
        self.tokens, self.pos = tokens, 0

    def peek(self):
        return self.tokens[self.pos]

    def take(self, kind, value=None):
        tok = self.peek()
        if tok[0] != kind or (value is not None and tok[1] != value):
            raise SyntaxError(f"expected {value or kind}, got {tok[1]!r}")
        self.pos += 1
        return tok[1]

    def program(self):
        stmts = []
        while self.peek()[0] != "eof":
            if self.peek()[0] == "nl":
                self.pos += 1
                continue
            stmts.append(self.statement())
            self.take("nl")
        return stmts

    def statement(self):
        if self.take("kw") == "let":
            name = self.take("id")
            self.take("op", "=")
            return ("let", name, self.expr())
        return ("print", self.expr())

    def expr(self):                       # expr = term { ("+" | "-") term }
        node = self.term()
        while self.peek() in (("op", "+"), ("op", "-")):
            node = (self.take("op"), node, self.term())
        return node

    def term(self):                       # term = unary { ("*" | "/") unary }
        node = self.unary()
        while self.peek() in (("op", "*"), ("op", "/")):
            node = (self.take("op"), node, self.unary())
        return node

    def unary(self):                      # unary = "-" unary | primary
        if self.peek() == ("op", "-"):
            self.pos += 1
            return ("neg", self.unary())
        return self.primary()

    def primary(self):                    # primary = number | name | "(" expr ")"
        kind, value = self.peek()
        if kind == "num":
            self.pos += 1
            return ("num", value)
        if kind == "id":
            self.pos += 1
            return ("var", value)
        self.take("op", "(")
        node = self.expr()
        self.take("op", ")")
        return node

# 3. Semantic analysis: give every variable a stack slot, reject undefined names
def check(stmts):
    slots = {}
    def visit(node):
        if node[0] == "var" and node[1] not in slots:
            raise NameError(f"undefined variable {node[1]!r}")
        for child in node[1:]:
            if isinstance(child, tuple):
                visit(child)
    for stmt in stmts:
        visit(stmt[-1])
        if stmt[0] == "let":
            slots.setdefault(stmt[1], -8 * (len(slots) + 1))
    return slots

# 4. Code generation: AST -> x86-64 assembly (AT&T syntax), result in %rax
OPS = {"+": "addq %rcx, %rax", "-": "subq %rcx, %rax",
       "*": "imulq %rcx, %rax", "/": "cqto\n\tidivq %rcx"}

def gen(node, slots, out):
    kind = node[0]
    if kind == "num":
        out.append(f"movq ${node[1]}, %rax")
    elif kind == "var":
        out.append(f"movq {slots[node[1]]}(%rbp), %rax")
    elif kind == "neg":
        gen(node[1], slots, out)
        out.append("negq %rax")
    else:                                 # binary operator
        gen(node[1], slots, out)          # left operand -> %rax
        out.append("pushq %rax")
        gen(node[2], slots, out)          # right operand -> %rax
        out.append("movq %rax, %rcx")
        out.append("popq %rax")
        out.append(OPS[kind])

def compile_program(src):
    stmts = Parser(lex(src)).program()
    slots = check(stmts)
    frame = (len(slots) * 8 + 15) // 16 * 16   # keep %rsp 16-byte aligned
    out = []
    for stmt in stmts:
        gen(stmt[-1], slots, out)
        if stmt[0] == "let":
            out.append(f"movq %rax, {slots[stmt[1]]}(%rbp)")
        else:
            out += ["movq %rax, %rsi", "leaq fmt(%rip), %rdi",
                    "xorl %eax, %eax", "call printf@PLT"]
    body = "\n\t".join(out)
    return f""".section .rodata
fmt:	.string "%ld\\n"
	.text
	.globl main
main:
	pushq %rbp
	movq %rsp, %rbp
	subq ${frame}, %rsp
	{body}
	movl $0, %eax
	leave
	ret
	.section .note.GNU-stack,"",@progbits
"""

if __name__ == "__main__":
    print(compile_program(open(sys.argv[1]).read()))
```

Running it on the program above:

```bash
python3 tinyc.py prog.calc > prog.s
gcc prog.s -o prog
./prog
```

prints

```txt
52
-30
```

and a program that uses an undefined variable stops with
`NameError: undefined variable 'b'` instead of producing code.

A few details are worth noticing, because every real compiler has to get them
right too:

- **Precedence comes from the grammar.** `term` is called from `expr`, so `*`
  and `/` bind more tightly than `+` and `-`, exactly as in the EBNF grammar
  earlier. The `while` loops make the operators left-associative, so
  `10 - 3 - 2` is `(10 - 3) - 2`.
- **The code generator is a stack machine.** For `x - 2` it computes `x` into
  `rax`, pushes it, computes `2`, moves it to `rcx`, pops `x` back into `rax` and
  subtracts. `cqto` before `idivq` sign-extends `rax` into `rdx`, which x86's
  division instruction requires.
- **It follows the calling convention.** To call `printf` it puts the format
  string in `rdi` and the value in `rsi`, sets `eax` to zero (for variadic
  functions, `al` must give an upper bound on the number of vector registers
  used), and keeps the stack
  pointer a multiple of 16 at the call, all as the System V ABI
  requires.[^sysvabi]
- **It produces terrible code.** Every operand goes through memory, and
  nothing is optimised. Adding constant folding, then a register allocator,
  would be the next steps, followed by `if`, `while` and functions.

### Where to go next

Real compilers grow from exactly this skeleton. Some well-trodden paths:

- **Target an existing back end.** Emit LLVM IR, C or WebAssembly instead of
  assembly, and get optimisation and portability for free.[^aosa]
- **Grow the compiler in small steps.** Abdulaziz Ghuloum's *An Incremental
  Approach to Compiler Construction* builds a compiler for a Scheme subset one
  feature at a time, with a working compiler after every step.[^ghuloum]
- **Write an interpreter first.** Robert Nystrom's *Crafting Interpreters*,
  free online, builds a tree-walking interpreter and then a bytecode virtual
  machine for the same language.[^crafting]
- **Read the classics.** The Dragon Book covers the theory in depth;[^dragon]
  Cooper and Torczon's *Engineering a Compiler* focuses on optimisation and
  code generation.[^cooper]

Eventually a compiler can be **self-hosting**: written in the language it
compiles, and compiled by a previous version of itself. Go's compiler, for
example, was converted from C to Go for Go 1.5 in 2015.[^go15] Getting the first
version requires **bootstrapping** from a compiler written in another language,
and Thompson's *Reflections on Trusting Trust* is the classic warning about
what that chain of trust implies.[^thompson]

## Why it matters

Every program that runs has passed through a compiler, an interpreter, or
both, and their choices shape what programs can do and how fast. Knowing how
a compiler works explains why compile errors look the way they do, why the
optimisation level can change how a buggy program behaves, why "undefined
symbol" is a linker error and not a compiler error, why a release build can
be ten times faster than a debug build, and why a JavaScript function gets
faster after it has run a few thousand times. It is also, as the example shows,
far less mysterious than its reputation: a pipeline of small, understandable
translations, each a little closer to the machine.

## References

[^dragon]: Aho, A. V., Lam, M. S., Sethi, R., & Ullman, J. D. (2006). *Compilers: Principles, Techniques, and Tools* (2nd ed.). Addison-Wesley.

[^hopper]: Hopper, G. M. (1952). The education of a computer. *Proceedings of the 1952 ACM National Meeting (Pittsburgh)*, 243–249. <https://doi.org/10.1145/609784.609818>

[^knuthpardo]: Knuth, D. E., & Trabb Pardo, L. (1980). The early development of programming languages. In N. Metropolis, J. Howlett, & G.-C. Rota (Eds.), *A History of Computing in the Twentieth Century* (pp. 197–273). Academic Press.

[^backus57]: Backus, J. W., Beeber, R. J., Best, S., Goldberg, R., Haibt, L. M., Herrick, H. L., Nelson, R. A., Sayre, D., Sheridan, P. B., Stern, H. J., Ziller, I., Hughes, R. A., & Nutt, R. (1957). The FORTRAN automatic coding system. *Papers Presented at the Western Joint Computer Conference*, 188–198. <https://doi.org/10.1145/1455567.1455599>

[^backus78]: Backus, J. (1978). The history of FORTRAN I, II, and III. *ACM SIGPLAN Notices*, 13(8), 165–180. <https://doi.org/10.1145/960118.808380>

[^chomsky]: Chomsky, N. (1956). Three models for the description of language. *IRE Transactions on Information Theory*, 2(3), 113–124. <https://doi.org/10.1109/TIT.1956.1056813>

[^algol60]: Backus, J. W., Bauer, F. L., Green, J., Katz, C., McCarthy, J., Perlis, A. J., Rutishauser, H., Samelson, K., Vauquois, B., Wegstein, J. H., van Wijngaarden, A., & Woodger, M. (1960). Report on the algorithmic language ALGOL 60 (P. Naur, Ed.). *Communications of the ACM*, 3(5), 299–311. <https://doi.org/10.1145/367236.367262>

[^knuth65]: Knuth, D. E. (1965). On the translation of languages from left to right. *Information and Control*, 8(6), 607–639. <https://doi.org/10.1016/S0019-9958(65)90426-2>

[^yacc]: Johnson, S. C. (1975). *Yacc: Yet Another Compiler-Compiler* (Computing Science Technical Report No. 32). Bell Laboratories. Archived at <https://web.archive.org/web/20201201001559/http://dinosaur.compilertools.net/yacc/index.html>

[^lex]: Lesk, M. E., & Schmidt, E. (1975). *Lex - A Lexical Analyzer Generator* (Computing Science Technical Report No. 39). Bell Laboratories. Archived at <https://web.archive.org/web/20201218031717/http://dinosaur.compilertools.net/lex/index.html>

[^allen]: Allen, F. E. (1970). Control flow analysis. *ACM SIGPLAN Notices*, 5(7), 1–19. <https://doi.org/10.1145/390013.808479>

[^kildall]: Kildall, G. A. (1973). A unified approach to global program optimization. *Proceedings of the 1st Annual ACM SIGACT-SIGPLAN Symposium on Principles of Programming Languages*, 194–206. <https://doi.org/10.1145/512927.512945>

[^allenturing]: ACM. (n.d.). Frances Allen. *A.M. Turing Award*. <https://amturing.acm.org/award_winners/allen_1012327.cfm>

[^chaitin]: Chaitin, G. J. (1982). Register allocation & spilling via graph coloring. *Proceedings of the 1982 SIGPLAN Symposium on Compiler Construction*, 98–101. <https://doi.org/10.1145/800230.806984>

[^ssa]: Cytron, R., Ferrante, J., Rosen, B. K., Wegman, M. N., & Zadeck, F. K. (1991). Efficiently computing static single assignment form and the control dependence graph. *ACM Transactions on Programming Languages and Systems*, 13(4), 451–490. <https://doi.org/10.1145/115372.115320>

[^gccrel]: GCC team. (n.d.). GCC releases. <https://gcc.gnu.org/releases.html>

[^deutsch]: Deutsch, L. P., & Schiffman, A. M. (1984). Efficient implementation of the Smalltalk-80 system. *Proceedings of the 11th ACM SIGACT-SIGPLAN Symposium on Principles of Programming Languages*, 297–302. <https://doi.org/10.1145/800017.800542>

[^aycock]: Aycock, J. (2003). A brief history of just-in-time. *ACM Computing Surveys*, 35(2), 97–113. <https://doi.org/10.1145/857076.857077>

[^hotspot]: Paleczny, M., Vick, C., & Click, C. (2001). The Java HotSpot server compiler. *Proceedings of the Java Virtual Machine Research and Technology Symposium (JVM '01)*. USENIX Association. <https://www.usenix.org/conference/jvm-01/java-hotspot%E2%84%A2-server-compiler>

[^llvm04]: Lattner, C., & Adve, V. (2004). LLVM: A compilation framework for lifelong program analysis & transformation. *International Symposium on Code Generation and Optimization*, 75–86. <https://doi.org/10.1109/CGO.2004.1281665>

[^aosa]: Lattner, C. (2011). LLVM. In A. Brown & G. Wilson (Eds.), *The Architecture of Open Source Applications* (Vol. 1). <https://aosabook.org/en/v1/llvm.html>

[^wasm]: Haas, A., Rossberg, A., Schuff, D. L., Titzer, B. L., Holman, M., Gohman, D., Wagner, L., Zakai, A., & Bastien, J. F. (2017). Bringing the web up to speed with WebAssembly. *Proceedings of the 38th ACM SIGPLAN Conference on Programming Language Design and Implementation*, 185–200. <https://doi.org/10.1145/3062341.3062363>

[^thompson]: Thompson, K. (1984). Reflections on trusting trust. *Communications of the ACM*, 27(8), 761–763. <https://doi.org/10.1145/358198.358210>

[^compcert]: Leroy, X. (2009). Formal verification of a realistic compiler. *Communications of the ACM*, 52(7), 107–115. <https://doi.org/10.1145/1538788.1538814>

[^gimple]: GCC team. (n.d.). GIMPLE. In *GNU Compiler Collection (GCC) Internals*. <https://gcc.gnu.org/onlinedocs/gccint/GIMPLE.html>

[^llvmlangref]: LLVM Project. (n.d.). LLVM language reference manual. <https://llvm.org/docs/LangRef.html>

[^gccopt]: GCC team. (n.d.). Options that control optimization. In *Using the GNU Compiler Collection*. <https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html>

[^sysvabi]: Lu, H. J., Matz, M., Girkar, M., Hubička, J., Jaeger, A., & Mitchell, M. (Eds.). (n.d.). *System V Application Binary Interface: AMD64 Architecture Processor Supplement (With LP64 and ILP32 Programming Models)* (Version 1.0). <https://gitlab.com/x86-psABIs/x86-64-ABI>

[^cet]: GCC team. (n.d.). Program instrumentation options: -fcf-protection. In *Using the GNU Compiler Collection*. <https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html>

[^gccoverall]: GCC team. (n.d.). Options controlling the kind of output. In *Using the GNU Compiler Collection*. <https://gcc.gnu.org/onlinedocs/gcc/Overall-Options.html>

[^gccbuiltins]: GCC team. (n.d.). Library builtins. In *Using the GNU Compiler Collection*. <https://gcc.gnu.org/onlinedocs/gcc/Library-Builtins.html>

[^elf]: Tool Interface Standard Committee. (1995). *Tool Interface Standard (TIS) Executable and Linking Format (ELF) Specification* (Version 1.2). <https://refspecs.linuxfoundation.org/elf/elf.pdf>

[^levine]: Levine, J. R. (2000). *Linkers and Loaders*. Morgan Kaufmann.

[^dsohowto]: Drepper, U. (2011). *How to Write Shared Libraries* (Version 4.1.2). <https://www.akkadia.org/drepper/dsohowto.pdf>

[^ldso]: Linux man-pages project. (n.d.). ld.so(8). *Linux manual page*. <https://man7.org/linux/man-pages/man8/ld.so.8.html>

[^pydis]: Python Software Foundation. (n.d.). dis: Disassembler for Python bytecode. In *Python 3.10 Documentation*. <https://docs.python.org/3.10/library/dis.html>

[^ghuloum]: Ghuloum, A. (2006). An incremental approach to compiler construction. *Proceedings of the 2006 Scheme and Functional Programming Workshop*. <http://scheme2006.cs.uchicago.edu/11-ghuloum.pdf>

[^crafting]: Nystrom, R. (2021). *Crafting Interpreters*. Genever Benning. <https://craftinginterpreters.com/>

[^cooper]: Cooper, K. D., & Torczon, L. (2022). *Engineering a Compiler* (3rd ed.). Morgan Kaufmann.

[^go15]: The Go Authors. (2015). Go 1.5 release notes. <https://go.dev/doc/go1.5>

[^llvmpasses]: LLVM Project. (n.d.). LLVM's analysis and transform passes. <https://llvm.org/docs/Passes.html>

[^ub]: cppreference.com. (n.d.). Undefined behavior. <https://en.cppreference.com/w/c/language/behavior>

[^pie]: Taylor, I. L. (2012, February 29). Piece of PIE. *Airs*. <https://www.airs.com/blog/archives/549>

[^dotnet]: Microsoft. (n.d.). Managed execution process. *Microsoft Learn*. <https://learn.microsoft.com/en-us/dotnet/standard/managed-execution-process>

[^hoppermilestone]: IEEE Milestones Wiki. (2024). Milestone proposal: Grace Hopper's compiler and programming language work, 1952–1959. <https://ieeemilestones.ethw.org/Milestone-Proposal:Grace_Hopper's_Compiler_and_Programming_Language_Work,_1952-1959>

[^ibmfortran]: IBM. (n.d.). Fortran. <https://www.ibm.com/history/fortran>

[^chomsky59]: Chomsky, N. (1959). On certain formal properties of grammars. *Information and Control*, 2(2), 137–167. <https://doi.org/10.1016/S0019-9958(59)90362-6>

[^deremer]: DeRemer, F. L. (1971). Simple LR(k) grammars. *Communications of the ACM*, 14(7), 453–460. <https://doi.org/10.1145/362619.362625>

[^ibmallen]: IBM. (n.d.). Frances Allen. <https://www.ibm.com/history/frances-allen>

[^aho77]: Aho, A. V., & Ullman, J. D. (1977). *Principles of Compiler Design*. Addison-Wesley.

[^chaitin81]: Chaitin, G. J., Auslander, M. A., Chandra, A. K., Cocke, J., Hopkins, M. E., & Markstein, P. W. (1981). Register allocation via coloring. *Computer Languages*, 6(1), 47–57. <https://doi.org/10.1016/0096-0551(81)90048-5>

[^treessa]: GCC team. (n.d.). Tree SSA. In *GNU Compiler Collection (GCC) Internals*. <https://gcc.gnu.org/onlinedocs/gccint/Tree-SSA.html>

[^clang]: Lattner, C. (2007, July 11). New LLVM C front-end: "clang" [Mailing list post]. cfe-dev. <https://lists.llvm.org/pipermail/cfe-dev/2007-July/000000.html>

[^rustcodegen]: The Rust Project. (n.d.). Code generation. In *Rust Compiler Development Guide*. <https://rustc-dev-guide.rust-lang.org/backend/codegen.html>

[^swiftcompiler]: Swift.org. (n.d.). Swift compiler. <https://www.swift.org/documentation/swift-compiler/>

[^v8]: V8 Project. (2018, September 11). Celebrating 10 years of V8. *V8 Blog*. <https://v8.dev/blog/10-years>

[^wasmbrowsers]: Mozilla. (2017, November 13). WebAssembly support now shipping in all major browsers. *The Mozilla Blog*. <https://blog.mozilla.org/en/mozilla/webassembly-in-browsers/>

[^compcertsite]: CompCert. (n.d.). Context and motivations. <https://compcert.org/motivations.html>
