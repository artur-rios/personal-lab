---
title: "Craft: A Programming Language"
description: "An idea for a modern, multi-paradigm programming language with a syntax inspired by C# and proofs, parallelism and speed inspired by Bend, growing from a minimal version to a self-hosted compiler and an operating system, with a suggested technology stack to build it."
date: 2026-10-21T17:00:00Z
categories: ["Brainstorms"]
tags: ["Craft", "Programming Languages", "Compilers", "Parallelism", "Rust", "Technology Stack"]
---

A modern programming language that supports the most used paradigms, and has all the features you need to write elegant solutions.

## Features

- Multiplatform
- Syntax inspired by C#
- Proof, parallelism and speed inspired by [Bend](https://bend-lang.com/)

## Roadmap

- Develop a minimal version
- Develop and test more features on top of the minimal version
- Once we have a first stable version, start to develop simple programs in it
- Develop more features, as we test and identify requirements
- Build more complex programs and develop the language as we go
- After having a stable programming language, with complex projects written on it, create a compiler written in Craft itself
- Build an Operating System using the language

## Technology stack

A language is two things: the design people write in, and the compiler and
runtime that make it run. The stack is mostly the second, but three design
choices shape it so much that they come first: how parallelism works, how
memory is managed, and what "proof" means. The background on how a compiler is
structured is in [Compilers]({{< ref "/fundamentals/compilers" >}}), and the
way C# itself runs is in [How C# Runs]({{< ref "/dotnet/compilation-and-execution" >}}).

### Three design choices that shape the stack

**Parallelism comes from purity, and the programmer chooses how.** Bend splits
divide-and-conquer code across CPU cores or a GPU through its runtime, BendRT,
without threads, locks or GPU kernels in the code. That is only safe because
Bend's functions have no side effects: two calls that cannot affect each other
can run at the same time. C# is the opposite, with mutable objects everywhere.
Craft can have both if it is **immutable by default**: records and collections
cannot be changed, and functions that do not declare an effect are pure.
Mutation stays available, but explicit, and code that uses it runs in order.

On pure code, parallelism is the programmer's choice, in one of two modes:

- **Automatic**, as in Bend: a function or module opts in, and the compiler
  splits its pure work across cores wherever it can.
- **Explicit**: only what the programmer marks runs in parallel, which keeps
  the cost of each split visible.

```csharp
// A sketch, not a decision. In C#, the two calls run one after the other.
record Tree(int Value, Tree? Left, Tree? Right);

// Automatic: the compiler may run the two recursive calls in parallel.
[Parallel]
int Sum(Tree? tree) => tree switch
{
    null => 0,
    var (value, left, right) => value + Sum(left) + Sum(right),
};

// Explicit: only the marked pair runs in parallel.
var (left, right) = parallel (Sum(tree.Left), Sum(tree.Right));
```

**Memory is reference counted, not garbage collected.** The roadmap ends with
an operating system, and a kernel cannot pause for a garbage collector or
depend on one being there. Koka and Lean 4 show a better fit for an
immutable-by-default language: reference counting inserted by the compiler,
which frees memory the moment it is no longer used, and reuses it in place when
a value has only one owner, so immutable code still updates without copying.
Immutable values cannot form reference cycles, which is the usual weakness of
reference counting. Bend goes further: its values are affine, used at most
once, so closures and arrays are never shared at all. That is simpler for the
runtime but stricter for the programmer than a C#-like language should be.

| Option | Used by | Trade-off |
| --- | --- | --- |
| Tracing garbage collector | C#, Java, Go | The easiest for users, but it needs a runtime, pauses, and is hard to use in a kernel |
| **Compiler-inserted reference counting with reuse** | Koka, Lean 4, Swift in part | No pauses and no runtime beyond an allocator, which suits an operating system; cycles need care when mutation is used |
| Ownership and borrowing | Rust | The most control, but the hardest to learn, and the least like C# |

**Proofs go as far as Bend's: the type checker is a proof checker.** "Proof"
can mean two depths. Contracts checked by a solver, as in Spec#, Microsoft
Research's verified C#, and in Dafny, prove preconditions and postconditions
automatically, but only what the solver can find. Full proofs, as in Lean and
Rocq, can state and prove any property, because the types themselves can
express it. Bend 2 takes the second road: its type theory, BendTT, has
dependent types, and its type checker checks proofs in about a second, fast
enough to run after every change.

In Bend, a project states the rules it must never break as laws in
`LAWS.bend`, proves them in `PROOF.bend`, and runs `bend PROOF.bend` before
each commit; a change that breaks a law no longer compiles. Craft follows the
same model, in C#'s syntax:

- **Laws** are statements about the program, such as "a balance is never
  negative", written as types.
- **Proofs** are ordinary definitions whose type is a law, checked by the same
  type checker as the rest of the code, with no separate tool.
- **Proofs are optional.** Code with no laws compiles as usual, so a program
  can start without proofs and add them where correctness matters most.
- **Functions used in proofs must terminate**, since a proof by a loop that
  never ends proves nothing. The compiler checks termination, and code that
  must run forever, such as a server's main loop or an operating system's
  scheduler, is marked as exempt, as Bend's `@unsafe` does.

```csharp
// A sketch, after Bend's own example: the law that x + 0 equals x for every
// natural number, and its proof by induction on x.
law AddZero(Nat x): Add(x, 0) == x;

proof AddZero(Nat x) => x switch
{
    0 => Equal,
    1 + var p => Rewrite(AddZero(p)),
};
```

Bend writes every proof by hand, with no proof search. Craft could later add
what F* does, dependent types with an SMT solver such as Z3 that proves the
simple steps automatically, so only the hard ones are written out.

### The suggestion at a glance

| Concern | Choice | Why |
| --- | --- | --- |
| Compiler language | Rust | Enums and pattern matching fit syntax trees and passes, the result is one native binary, and it is the language of Thoth and Anvil OS. |
| Lexer and parser | Hand-written, recursive descent with Pratt parsing for expressions | The best error messages and recovery, which is why Roslyn and rustc are hand-written too. |
| Syntax tree | rowan | A lossless tree that keeps every space and comment, as rust-analyzer's does, so the same parser serves the compiler, the formatter and the editor. |
| Incremental compilation | salsa | Recomputes only what an edit affects, which makes a fast language server possible. |
| Diagnostics | ariadne | Errors that point at the code with labels, in the style of rustc. |
| First back end | An interpreter over the compiler's own intermediate representation | The quickest way to try the language's design before generating machine code. |
| Native code | Cranelift, then LLVM | Cranelift compiles fast and is written in Rust; LLVM, through inkwell, adds the optimisations release builds need. |
| Parallel runtime | A work-stealing scheduler | Splits pure work across cores, as .NET's thread pool and Rayon do, in both the automatic and the explicit mode. |
| Proofs | A dependent type checker in the compiler | Laws and proofs checked by the type checker itself, as in Bend 2, Lean and Rocq. |
| Platform | Craft's own standard library and package manager | Craft runs on no other platform, such as .NET; it reaches C libraries through a foreign function interface. |
| Editor support | A language server and a Tree-sitter grammar | Works in any editor, and gives Thoth a Craft module. |
| Testing | A suite of Craft programs with expected output, insta, cargo-fuzz | End-to-end tests of the language, snapshots of the compiler's stages, and fuzzing of the parser. |

### Why Rust for the first compiler

The first compiler is temporary by design, since the roadmap replaces it with
one written in Craft, so it should be the one that is quickest to write well.

| Option | Strengths | Trade-off |
| --- | --- | --- |
| **Rust** | Pattern matching, one native binary, Cranelift, salsa and rowan are Rust libraries | A slower start than a language with a garbage collector |
| C# | The language Craft's syntax comes from, and Roslyn as a reference | Fewer compiler libraries, and LLVM bindings are less used |
| OCaml | The classic compiler language; Rust's own first compiler was written in it | A small ecosystem and a language to learn only for this |
| C++ | LLVM's own language | No safety net in a large, long-lived code base |

### Back ends, in order

1. **An interpreter** first, so the minimal version can run programs while the
   syntax and type system are still changing every week.
2. **Cranelift** next, for native code on x86-64 and AArch64, on Windows,
   Linux and macOS, which covers "multiplatform" for the first stable version.
3. **LLVM** for optimised release builds, and for targets Cranelift does not
   have, such as WebAssembly in the browser.

Bend also compiles to CUDA and Metal and can run on a GPU. A GPU back end for
Craft's pure parallel code is a natural later step once the CPU back ends are
stable. Bend runs on Linux and macOS, with Windows only through WSL; Craft
targets Windows natively from the start.

### Its own platform

Craft does not run on .NET or any other virtual machine; it compiles to native
code and brings its own platform:

- **A standard library** written in Craft, with collections, text, files,
  networking and the parallel runtime, small enough to also run without an
  operating system underneath.
- **A package manager and registry** in the way of Cargo and crates.io: one
  tool that builds, tests, and fetches and publishes packages.
- **A foreign function interface** to C, so existing native libraries can be
  used before Craft has its own, and so Craft and Rust code can be linked
  together.

### Self-hosting and the operating system

Go shows how the self-hosting step works: until version 1.5 its compiler was
written in C, and from then on Go was built with the previous Go release. Craft
can follow the same path: the Rust compiler stays as the first stage until the
Craft compiler can compile itself, and after that each release is built with
the one before it.

The operating system in the last step of the roadmap is
[Anvil OS]({{< ref "/brainstorms/anvil-os" >}}). It starts in Rust, and is
rewritten in Craft over time, one part at a time: a new driver written in
Craft is linked into the Rust kernel through the C interface, until no Rust is
left. Anvil's layered, hybrid kernel helps, since each layer is a separate part
with a defined interface that can be replaced on its own. For that, Craft needs
features designed early, because they are hard to add later:

- **A freestanding mode**, with no runtime beyond an allocator the program
  provides, which reference counting makes possible.
- **Unsafe blocks** with raw pointers, for page tables and device memory.
- **Control over memory layout**, as C#'s `StructLayout` gives.
- **Inline assembly**, for the instructions no language has a word for.
- **No hidden allocations** in code that asks for none, such as an interrupt
  handler.

## Decisions

The questions this brainstorm raised, and how they were settled:

- **The operating system is Anvil OS**, rewritten in Craft part by part.
- **Proofs go as far as Bend's.** The type checker is a proof checker, with
  laws and proofs written in Craft itself, and proofs stay optional.
- **Craft is its own platform**, with its own standard library and package
  manager, and does not run on .NET.
- **Parallelism is the programmer's choice**, automatic or explicit, on pure
  code.
