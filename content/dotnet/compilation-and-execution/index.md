---
title: "How C# Runs: From Source to IL to Machine Code"
description: "C# is compiled twice: once by Roslyn into IL and metadata inside an assembly, and again by the .NET runtime into machine code for the CPU it runs on. Here is what an assembly contains, what IL looks like, how the JIT compiles method by method and moves hot code through tiers, on-stack replacement and dynamic PGO, what ReadyToRun and Native AOT change, what managed, unmanaged and unsafe code mean, and how .NET got here."
date: 2026-10-21T12:30:00Z
categories: [".NET"]
tags: [".NET", "C#", "Compilers", "JIT", "IL", "CLR", "Native AOT", "ReadyToRun"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

A C# program is not compiled straight to machine code, and it is not
interpreted either. It is compiled **twice**. When you build, the C# compiler
turns source code into an intermediate language and a description of every
type, packed into an assembly, a `.dll` file. When you run, the .NET runtime
turns that intermediate language into machine code for the CPU it is running
on, usually one method at a time and often more than once as it learns which
code is hot.

That second compilation is why the same `.dll` runs on Windows, Linux and
macOS, on x64 and Arm64. It is also why a .NET program gets faster in its
first seconds of running, why startup time can be traded against peak speed,
and why ReadyToRun and Native AOT exist at all. This article follows one small
program through both compilations. The commands shown were run with the
.NET SDK 10.0.400 and the .NET 10.0.13 runtime on Windows x64, on
21 October 2026, and the output is shown as printed, with long paths shortened
to `…`.

## From source to running code

**C# source is compiled by Roslyn into an assembly: a portable executable (PE)
file that holds Common Intermediate Language (CIL, usually just "IL") and
metadata describing every type and member. At run time the .NET runtime, the
Common Language Runtime (CLR), compiles that IL into native machine code,
normally just in time, method by method, and runs it with services such as
garbage collection, type safety and exception handling.**

Microsoft's documentation calls the result *managed code*: "code whose
execution is managed by a runtime". The runtime "is in charge of taking the
managed code, compiling it into machine code and then executing it".[^managed]
The documentation lists the same four steps for every managed program:
choose a compiler that targets the runtime, compile to CIL and metadata,
compile CIL to native code, and run it.[^execution]

{{< diagram src="pipeline.svg" caption="Roslyn produces an assembly holding IL and metadata. The IL reaches machine code by JIT compilation at run time (the default), with ReadyToRun code precompiled at publish, or entirely ahead of time with Native AOT." >}}

The example program sums the squares of 1 to 1,000, two hundred times, with a
short sleep between rounds so the runtime has time to notice that the method
is hot:

```csharp
long total = 0;
for (int i = 0; i < 200; i++)
{
    total += MathOps.SumOfSquares(1_000);
    Thread.Sleep(1);
}
Console.WriteLine($"Total: {total}");

public static class MathOps
{
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static long SumOfSquares(int n)
    {
        long sum = 0;
        for (int i = 1; i <= n; i++)
        {
            sum += (long)i * i;
        }
        return sum;
    }
}
```

`NoInlining` keeps the method a method of its own, so that it can be watched
on its own. Without it, the JIT is free to paste a small method into its
caller.

## The first compilation: Roslyn and the assembly

The C# compiler is **Roslyn**, "the open-source implementation of both the C#
and Visual Basic compilers". It is also a library: "The Roslyn .NET compiler
provides C# and Visual Basic languages with rich code analysis APIs", which is
what IDEs, analysers and source generators are built on.[^roslyn]
`dotnet build` runs it through MSBuild; you rarely call `csc` yourself.

What Roslyn writes is an **assembly**. Microsoft describes assemblies as "the
fundamental units of deployment, version control, reuse, activation scoping,
and security permissions for .NET-based applications", taking the form of
`.exe` or `.dll` files.[^assemblies] Physically, an assembly is a PE file, the
same container format Windows uses for native executables, extended with a
CLI header that says "this is managed code". The CIL and metadata are
contained in a PE file "that is based on and that extends the published
Microsoft PE and common object file format (COFF)".[^execution]

Reading the compiled `Hello.dll` with `System.Reflection.Metadata`, the
library .NET itself uses to read assemblies, shows those parts:

```txt
$ dotnet run -- …/Hello/bin/Release/net10.0/Hello.dll
PE format:        PE32
Machine:          I386
Has CLI header:   True
IL only:          True
Metadata version: v4.0.30319
Assembly:         Hello, Version=1.0.0.0
References:
  System.Runtime, Version=10.0.0.0
  System.Collections, Version=10.0.0.0
  System.Reflection.Primitives, Version=10.0.0.0
  System.Console, Version=10.0.0.0
  System.Threading.Thread, Version=10.0.0.0
  System.Linq, Version=10.0.0.0
Types:
  <Module> (0 methods)
  Program (3 methods)
  MathOps (1 methods)
  <>c (4 methods)
```

A few things in that output are worth a second look.

- **The header names a 32-bit x86 machine, and the file runs on x64 all the
  same.** The default "AnyCPU" build contains no machine code at all, only IL,
  as the `IL only` flag says, and the runtime compiles that IL for whatever
  CPU it finds itself on.
- **The metadata header says `v4.0.30319`**, although the assembly was built
  for .NET 10. What the program actually targets shows up in its references
  instead: `System.Runtime, Version=10.0.0.0`.
- **Metadata describes everything.** Every type, every method signature and
  every reference to another assembly is recorded. "Every loadable common
  language runtime portable executable (PE) file contains metadata", and the
  runtime uses it "to locate and load classes, lay out instances in memory,
  resolve method invocations, generate native code, enforce security, and set
  runtime context boundaries".[^clr] It is also what makes reflection work.
- **The references are the manifest at work.** The assembly manifest lists
  the assembly's identity, its files and "a list of all external
  dependencies"; CIL in a PE file "won't be executed unless it has an
  associated assembly manifest".[^assemblies] `<>c` is a class the compiler
  generated to hold the program's lambdas.

### What `dotnet build` puts next to the `.dll`

A built console app has both `Hello.dll` and `Hello.exe`. The `.exe` is not a
second copy of the program. It is the **app host**, a small native launcher
that finds the installed runtime and asks it to load `Hello.dll`. The SDK
creates one by default; "a native executable is required for self-contained
deployments", and the `UseAppHost` property turns it off.[^msbuild] In this
build the app host is 162,304 bytes and the program itself, IL and metadata,
is 7,168 bytes. On .NET Framework the `.exe` *was* the managed assembly; on
modern .NET the program always lives in the `.dll`, and `dotnet Hello.dll`
runs it without the app host.

## Common Intermediate Language

IL is the instruction set of a virtual machine defined by the **ECMA-335**
standard, the Common Language Infrastructure, whose Partition III "describes
the Common Intermediate Language (CIL) instruction set".[^ecma335] Microsoft
called it MSIL, Microsoft Intermediate Language, in its early documentation,
and the name survives in tools such as ILVerify, which describes itself as
"capable of verifying MSIL code based on ECMA-335".[^ilverify] Today's
documentation says IL, and notes that it "is sometimes also called Common
Intermediate Language (CIL)".[^managed] They are three names for one thing.

The managed execution guide describes CIL as "a CPU-independent set of
instructions that can be efficiently converted to native code".[^execution]
This is the IL of `SumOfSquares`, decoded from the method body's bytes with
the `OpCodes` table from `System.Reflection.Emit`:

```txt
$ dotnet run -c Release -- il
IL_0000: ldc.i4.0
IL_0001: conv.i8
IL_0002: stloc.0
IL_0003: ldc.i4.1
IL_0004: stloc.1
IL_0005: br.s       IL_0013
IL_0007: ldloc.0
IL_0008: ldloc.1
IL_0009: conv.i8
IL_000a: ldloc.1
IL_000b: conv.i8
IL_000c: mul
IL_000d: add
IL_000e: stloc.0
IL_000f: ldloc.1
IL_0010: ldc.i4.1
IL_0011: add
IL_0012: stloc.1
IL_0013: ldloc.1
IL_0014: ldarg.0
IL_0015: ble.s      IL_0007
IL_0017: ldloc.0
IL_0018: ret
```

IL is a **stack machine**. There are no registers: instructions push values
onto an evaluation stack and pop them off. `ldc.i4.0` pushes the constant 0,
`conv.i8` widens it to a 64-bit integer, `stloc.0` stores it in local 0
(`sum`). The loop body loads `sum`, loads `i` twice, widens both, multiplies,
adds and stores back into `sum`. The condition `i <= n` sits at the bottom,
at `IL_0013`, and the first jump skips to it, a layout compilers use so that
each iteration takes one branch instead of two. The whole method is 25 bytes.

Two things are absent. There is nothing about x64, Arm64 or registers, and
there is no optimisation to speak of: Roslyn translates faithfully and leaves
the heavy optimisation to the runtime, which knows the exact CPU, the actual
values of `static readonly` fields and, as the next sections show, how the
code really behaves.

## The runtime

The runtime that executes IL is the **Common Language Runtime**. On .NET
Framework it has its own version numbers, and they do not follow the
product's: ".NET Framework 4, 4.5, and later releases include CLR 4, but
.NET Framework 2.0, 3.0, and 3.5 include CLR 2.0. (There was no version 3 of
the CLR.)"[^fxversions] On modern .NET, ".NET Core and .NET 5+ releases have a
single product version, that is, there's no separate CLR version".[^clr] The
implementation is called CoreCLR and lives, with the class libraries, in the
`dotnet/runtime` repository; Microsoft's documentation keeps using "CLR" for
"the .NET runtime" whatever the implementation, including Mono.[^managed]

Besides compiling IL, the runtime provides the services that make code
*managed*:

- **Memory management.** "The garbage collector (GC) serves as an automatic
  memory manager": it allocates objects on the managed heap, finds the ones
  no longer reachable and reclaims them, which "can eliminate common problems
  such as forgetting to free an object and causing a memory leak or
  attempting to access freed memory".[^gc]
- **Type loading and type safety.** The runtime lays out every type from its
  metadata and checks every cast and array access, so that, in the GC
  documentation's words, "an object can't use for itself the memory allocated
  for another object".[^gc]
- **Exception handling.** Exceptions unwind across methods, and across
  languages, with the same rules everywhere.
- **Interop.** Calls into native libraries and callbacks from them, covered
  [below](#managed-unmanaged-and-unsafe-code).

What modern .NET does *not* provide is a sandbox inside the process. .NET
Framework had Code Access Security (CAS) for running partially trusted code,
but "CAS is no longer treated as a security boundary", and it is not supported
on .NET 6 and later. The recommendation is to use the operating system's
boundaries instead: "virtualization, containers, or user accounts".[^cas]

## The second compilation: just in time

The runtime does not compile a whole assembly when it loads it. When a type is
loaded, every method gets a small stub. "When a method is called for the
first time, the stub passes control to the JIT compiler, which converts the
CIL for that method into native code and modifies the stub to point directly
to the generated native code."[^execution] Methods that are never called are
never compiled.

The JIT can be watched. The shipped runtime honours a few JIT diagnostics
variables: `DOTNET_JitDisasmSummary=1` prints "a list of all JIT
compiled functions", `DOTNET_JitDisasm` prints the generated assembly code of
the named methods, and `DOTNET_JitStdOutFile` sends the output to a file
instead of the console.[^jitdumps] Running the example with a summary:

```txt
$ DOTNET_JitDisasmSummary=1 DOTNET_JitStdOutFile=summary.txt dotnet bin/Release/net10.0/Hello.dll
Total: 66766700000
$ cat summary.txt
   1: JIT compiled System.Guid:FormatGuidVector128Utf8(System.Guid,bool) [Tier0, IL size=304, code size=544]
   …
  24: JIT compiled Program:<Main>$(System.String[]) [Instrumented Tier0, IL size=165, code size=523]
  25: JIT compiled MathOps:SumOfSquares(int) [Instrumented Tier0, IL size=25, code size=148]
  26: JIT compiled MathOps:SumOfSquares(int) [Tier1-OSR @0x13 with Synthesized PGO, IL size=25, code size=57]
  27: JIT compiled MathOps:SumOfSquares(int) [Instrumented Tier0, IL size=25, code size=148]
  28: JIT compiled System.Threading.Thread:Sleep(int) [Instrumented Tier1, IL size=19, code size=193]
  29: JIT compiled MathOps:SumOfSquares(int) [Tier1-OSR @0x13 with Synthesized PGO, IL size=25, code size=57]
  30: JIT compiled MathOps:SumOfSquares(int) [Tier1 with Dynamic PGO, IL size=25, code size=28]
  31: JIT compiled System.Threading.Thread:Sleep(int) [Tier1, IL size=19, code size=193]
```

Two surprises. The whole run JIT-compiled **31 methods**, although it used
`Console`, string interpolation, `Thread` and the startup path of the runtime
itself. And one 25-byte method was compiled **five times**, at three
different levels. Both come from the same design: tiered compilation, with
precompiled code for the framework.

### Tiered compilation

Compiling well takes time, and time spent compiling at startup is time the
user waits. So the runtime compiles twice. The first tier "generates code more
quickly (quick JIT) or loads pre-compiled code (ReadyToRun)"; the second
"generates optimized code in the background".[^config] Tiered compilation has
been on by default since .NET Core 3.0.[^config]

- **Tier0** is "whatever code can be made available most quickly to first
  run a method": quick, unoptimised code.[^tiered]
- **Tier1** is "whatever code the runtime thinks will run faster than Tier0".
  A method is promoted once it has been "called at least 30 times, as
  measured by the call counter". Counting only starts once a 100 ms timer has
  run out without any new Tier0 compilation, so that a busy startup is not
  slowed by Tier1 work, and the Tier1 code is compiled on a background thread
  and then swapped in.[^tiered]

That is why only 31 methods were compiled. The .NET libraries ship with
precompiled ReadyToRun code (more on that [below](#readytorun)), which counts
as their first tier. The JIT only compiles what has no precompiled code, such
as this program and a few generic instantiations, plus framework methods hot
enough to deserve Tier1. `Thread.Sleep` was called 200 times, so its
precompiled code was replaced: lines 28 and 31.

### On-stack replacement

Call counting has a blind spot. `SumOfSquares` could be called once and spend
minutes in its loop, stuck in slow Tier0 code that call counting never
replaces. For years the answer was to skip Tier0 for any method with a loop.
**On-stack replacement (OSR)**, enabled by default in .NET 7, solves it
properly: it "allows the runtime to change the code executed by a currently
running method in the middle of its execution (that is, while it's 'on
stack')".[^net7] The .NET 7 change that turned OSR on also enabled
`DOTNET_TC_QuickJitForLoops` by default, so methods with loops start at Tier0
like any other.[^toub7] (The runtime configuration reference still says quick
JIT is not used for methods with loops when the setting is omitted;[^config]
the summary above, with a loop method compiled at Tier0, shows the current
behaviour.)

Here is the start of the Tier0 code for `SumOfSquares`:

```txt
$ DOTNET_JitDisasm=SumOfSquares dotnet bin/Release/net10.0/Hello.dll
; Assembly listing for method MathOps:SumOfSquares(int):long (Instrumented Tier0)
; Emitting BLENDED_CODE for generic X64 + VEX on Windows
; Instrumented Tier0 code
; rbp based frame
; fully interruptible
; compiling with minopt

G_M000_IG01:                ;; offset=0x0000
       push     rbp
       sub      rsp, 112
       lea      rbp, [rsp+0x70]
       …
G_M000_IG02:                ;; offset=0x0016
       mov      dword ptr [rbp-0x50], 0x3E8
       …
G_M000_IG03:                ;; offset=0x002C
       mov      rcx, 0x7FFDEE241230
       call     CORINFO_HELP_COUNTPROFILE32
       movsxd   rax, dword ptr [rbp-0x44]
       movsxd   rcx, dword ptr [rbp-0x44]
       imul     rax, rcx
       add      rax, qword ptr [rbp-0x40]
       mov      qword ptr [rbp-0x40], rax
       …
G_M000_IG04:                ;; offset=0x0057
       mov      eax, dword ptr [rbp-0x50]
       dec      eax
       mov      dword ptr [rbp-0x50], eax
       cmp      dword ptr [rbp-0x50], 0
       jg       SHORT G_M000_IG06

G_M000_IG05:                ;; offset=0x0065
       lea      rcx, [rbp-0x50]
       mov      edx, 19
       call     CORINFO_HELP_PATCHPOINT
       …
; Total bytes of code 148
```

Everything lives in memory on the stack frame (`[rbp-0x40]` is `sum`,
`[rbp-0x44]` is `i`), and every iteration does extra bookkeeping:

- `CORINFO_HELP_COUNTPROFILE32` counts how often the loop body runs. That
  is the *instrumented* part, used by PGO below.
- `0x3E8` is a countdown, decremented on every iteration. In Stephen Toub's
  words, "that `0x3E8` is the hex value for the decimal 1,000, which is the
  default number of iterations a loop needs to iterate before the JIT will
  generate the optimized version".[^toub7] When it reaches zero,
  `CORINFO_HELP_PATCHPOINT` is called with the IL offset of the loop, 19 or
  `0x13`, and the runtime jumps into an optimised version that resumes the
  loop from where the Tier0 frame left off. That is the
  `Tier1-OSR @0x13` entry in the summary: 57 bytes instead of 148.

The summary shows the Tier0 and OSR pair compiled twice before Tier1 arrived.
The exact sequence is an implementation detail of the runtime that changes
between releases; what matters is the direction, from fast to compile towards
fast to run.

### Dynamic PGO

Instrumenting Tier0 code is the other half of the story. **Dynamic
profile-guided optimisation** uses the counts collected while the method ran
at Tier0 to decide how to compile Tier1: which branches are likely, which
types a virtual or interface call usually sees, which loops are hot. .NET 8
made it the default: "dynamic profile-guided optimization (PGO) has been
improved and is now enabled by default", and Microsoft measured that "on
average, dynamic PGO increases performance by about 15%".[^net8] The final
version of `SumOfSquares`:

```txt
; Assembly listing for method MathOps:SumOfSquares(int):long (Tier1)
; Emitting BLENDED_CODE for generic X64 + VEX on Windows
; Tier1 code
; optimized code
; optimized using Dynamic PGO
; rsp based frame
; fully interruptible
; with Dynamic PGO: fgCalledCount is 18

G_M000_IG01:                ;; offset=0x0000

G_M000_IG02:                ;; offset=0x0000
       xor      eax, eax
       mov      edx, 1
       test     ecx, ecx
       jle      SHORT G_M000_IG04
       align    [0 bytes for IG03]

G_M000_IG03:                ;; offset=0x000B
       movsxd   r8, edx
       imul     r8, r8
       add      rax, r8
       inc      edx
       cmp      edx, ecx
       jle      SHORT G_M000_IG03

G_M000_IG04:                ;; offset=0x001B
       ret

; Total bytes of code 28
```

No stack frame, no counters: `sum` lives in `rax`, `i` in `edx`, `n` arrives
in `ecx`, and the loop is six instructions. Twenty-five bytes of IL became
148, then 57, then 28 bytes of x64 code during one run of the program.

{{< diagram src="tiers.svg" caption="The path of `SumOfSquares` in this run: instrumented Tier0 code, replaced mid-loop by an optimised OSR version after 1,000 iterations, then a fully optimised Tier1 version built in the background once the method had been called 30 times." >}}

## Compiling ahead of time

JIT compilation has costs: CPU time at startup, memory for the compiler, and
a requirement to be allowed to generate code at run time at all, which some
platforms forbid. .NET has two ways to move the work to publish time.

### ReadyToRun

"R2R is a form of ahead-of-time (AOT) compilation." A ReadyToRun assembly
contains native code for one platform *next to* the IL, so the first tier
loads precompiled code instead of compiling. The documentation is upfront
about the trade-offs: "R2R binaries are larger because they contain both
intermediate language (IL) code, which is still needed for some scenarios, and
the native version of the same code", and since "ahead-of-time generated code
is not as highly optimized as code produced by the JIT", tiered compilation
"will replace commonly used ReadyToRun methods with JIT-generated
methods".[^r2r] This is the mechanism the .NET libraries themselves use,
which is why `Thread.Sleep` above went from precompiled code straight to an
instrumented Tier1.

```bash
dotnet publish -c Release -r win-x64 -p:PublishReadyToRun=true
```

### Native AOT

Native AOT goes all the way: "Native AOT apps don't use a just-in-time (JIT)
compiler when the application runs." The publish step compiles the IL of the
app and of every library it uses into one native executable that "can run on
machines that don't have the .NET runtime installed", with "a stripped-down
version of the coreclr runtime" linked in for the GC and other
services.[^aot] .NET 7 introduced it for console apps,[^net7] and .NET 8
added ASP.NET Core support.[^aot] On Windows it needs the Visual Studio
"Desktop development with C++" workload, for the native linker.[^aot]

```bash
dotnet publish -c Release -r win-x64 -p:PublishAot=true
```

Native AOT pays for its startup with restrictions. Among the documented
limitations: "No dynamic loading", "No runtime code generation, for example,
`System.Reflection.Emit`", and it "requires trimming", which removes code the
compiler cannot see being used.[^aot] Publishing the example program shows
what that means in practice. Its `il` mode reads method bodies by reflection,
and the compiler flags it:

```txt
$ dotnet publish -c Release -r win-x64 -p:PublishAot=true
…
  Generating native code
…\Hello\Program.cs(30): Trim analysis warning IL2026: Program.<<Main>$>g__PrintIL|0_0(MethodInfo): Using member 'System.Reflection.MethodBase.GetMethodBody()' which has 'RequiresUnreferencedCodeAttribute' can break functionality when trimming application code. Trimming may change method bodies. For example it can change some instructions, remove branches or local variables. […\Hello\Hello.csproj]
…\Hello\Program.cs(45): Trim analysis warning IL2026: Program.<<Main>$>g__PrintIL|0_0(MethodInfo): Using member 'System.Reflection.Module.ResolveMethod(Int32)' which has 'RequiresUnreferencedCodeAttribute' can break functionality when trimming application code. Trimming changes metadata tokens. […\Hello\Hello.csproj]
  Hello -> …\pub-aot\
```

The warnings are honest: a Native AOT binary has no IL left to read.

### The three side by side

The example program has a third mode, `hi`, that prints one line and exits,
to measure startup. Published the three ways for `win-x64`, each run 20 times
from PowerShell with `Measure-Command`:

```txt
$ .\pub-fdd\Hello.exe hi
Hello from .NET 10.0.13
$ .\pub-aot\Hello.exe hi
Hello from .NET 10.0.11
```

| | Framework-dependent | ReadyToRun | Native AOT |
|---|---|---|---|
| Program file | `Hello.dll`, 7,168 bytes, plus 162,304-byte app host | `Hello.dll`, 24,576 bytes, plus app host | `Hello.exe`, 1,867,776 bytes |
| Needs the .NET runtime installed | Yes | Yes | No |
| Methods JIT-compiled to print one line | 24 | 23 | None |
| Median startup, 20 runs | 43.9 ms | 41.2 ms | 9.4 ms |

The ReadyToRun `Hello.dll` grew to more than three times its size and saved
one JIT compilation, `Main`, which is all a program this small has to offer;
the documentation warns that "applications that have small amounts of code
will likely not experience a significant improvement from enabling
ReadyToRun, as the .NET runtime libraries have already been precompiled with
ReadyToRun".[^r2r] Native AOT started more than four times faster and needs
no runtime on the machine, at the price of a 1.8 MB executable and the
restrictions above. It also reports a different version: the runtime it
carries is the one compiled into it at publish, 10.0.11, while the other two
use the shared 10.0.13 runtime installed on the machine.

The ReadyToRun file also changes shape. Read with the same metadata
inspector, it is now an x64 image that is no longer "IL only", because it
contains machine code:

```txt
$ dotnet run -- …/pub-r2r/Hello.dll
PE format:        PE32+
Machine:          Amd64
Has CLI header:   True
IL only:          False
```

## Managed, unmanaged and unsafe code

**Managed code** runs under the runtime's control: the runtime compiled it,
tracks its objects and enforces its types. **Unmanaged** or native code is
machine code the runtime knows nothing about, such as a C library or the
operating system's API. Microsoft's description of unmanaged code is blunt:
"the programmer is in charge of pretty much everything".[^managed]

The two meet through **interop**. "P/Invoke is a technology that allows you
to access structs, callbacks, and functions in unmanaged libraries from your
managed code."[^pinvoke] Since .NET 7 the preferred way to declare one is the
`LibraryImport` source generator, which writes the marshalling code at compile
time, so that "no IL stub needs to be generated at runtime, as it does when
using `DllImportAttribute`", which also makes it work with Native
AOT.[^net7] Once a call crosses into native code, "the actual management of
the execution is again in the hand of unmanaged code".[^managed]

C# also has **unsafe code**: an `unsafe` context in which you can use
pointers, take addresses and read raw memory. "Unsafe code isn't necessarily
dangerous; it's just code whose safety can't be verified by .NET tools." It
still runs inside the managed process, it is used to call native functions
that need pointers or to avoid bounds checks in hot code, and it needs the
`AllowUnsafeBlocks` compiler option.[^unsafe] A small example with both:

```csharp
using System.Runtime.InteropServices;

// Managed: the runtime knows the process id.
Console.WriteLine($"Environment.ProcessId:  {Environment.ProcessId}");

// Unmanaged: ask Windows directly, through P/Invoke.
Console.WriteLine($"GetCurrentProcessId():  {Native.GetCurrentProcessId()}");

// Unsafe: read the bytes of an int through a pointer.
int number = 1024;
unsafe
{
    byte* p = (byte*)&number;
    Console.WriteLine($"Bytes of {number}:       {p[0]:X2} {p[1]:X2} {p[2]:X2} {p[3]:X2}");
}

static partial class Native
{
    [LibraryImport("kernel32.dll")]
    internal static partial uint GetCurrentProcessId();
}
```

```txt
$ dotnet run
Environment.ProcessId:  29412
GetCurrentProcessId():  29412
Bytes of 1024:       00 04 00 00
```

The pointer shows the integer's bytes in memory, least significant first:
x64 is little-endian. Nothing stops a pointer from reading past the four
bytes, which is exactly why the code has to be marked `unsafe`. The C#
language reference also documents an updated memory safety model, in preview
in C# 15 and .NET 11, in which only operations that actually access unmanaged
memory need an `unsafe` context.[^unsafe]

## A short history

- **2001.** The Common Language Infrastructure becomes an Ecma standard: the
  first edition of ECMA-335 is dated December 2001.[^ecma335]
  The Mono project, an independent open-source implementation, is announced
  on 30 June 2001.[^mono]
- **2002.** Microsoft launches Visual Studio .NET and the .NET Framework on
  13 February 2002, with CLR 1.0.[^launch][^fxversions]
- **2004.** Mono 1.0 is released on 30 June 2004.[^mono]
- **Later .NET Framework releases.** .NET Framework 2.0 brings CLR 2.0 and
  generics; 3.0 and 3.5 add libraries on top of the same runtime; .NET
  Framework 4 brings CLR 4, which every later .NET Framework release
  keeps.[^fxversions]
- **2014.** On 12 November 2014, Microsoft announces that ".NET Core will be
  open source, including the runtime as well as the framework
  libraries".[^opensource]
- **2016.** .NET Core 1.0 is released on 27 June 2016, cross-platform from the
  start: Windows, OS X and Linux.[^core1]
- **2019.** .NET Core 3.0, released on 23 September 2019, turns tiered
  compilation on by default.[^core3][^config]
- **2020.** .NET 5.0, released on 10 November 2020, drops "Core" from the
  name and is "the first release in our .NET unification journey".[^net5]
- **2022.** .NET 7 enables on-stack replacement by default and introduces
  Native AOT for console apps.[^net7][^toub7]
- **2023.** .NET 8 enables dynamic PGO by default and adds Native AOT support
  to ASP.NET Core.[^net8][^aot]

## Common misunderstandings

| Misunderstanding | What is actually true |
|---|---|
| "C# is interpreted." | It is compiled twice: to IL by Roslyn, then to machine code by the runtime, before each method first runs. |
| "The `.exe` is my program." | On modern .NET it is the app host; the program is the `.dll`. With Native AOT, the `.exe` really is the whole program. |
| "Each method is compiled once." | With tiered compilation a hot method can be compiled several times: Tier0, OSR, then Tier1 with PGO. |
| "JIT code is slower than native code." | It *is* native code. The JIT can also optimise for the exact CPU and for observed behaviour, and the documentation notes that ahead-of-time code "is not as highly optimized as code produced by the JIT". |
| "ReadyToRun makes everything faster." | It improves startup and first use. Steady-state speed comes from Tier1, which replaces hot R2R code anyway. |
| "Native AOT is always better." | It wins on startup and deployment, at the cost of size, reflection, dynamic loading and runtime code generation. |
| "`unsafe` code runs outside the runtime." | It runs in the same managed process; only its memory safety is no longer checked. Native code is reached through interop. |
| "CLR means .NET Framework." | Microsoft's documentation uses CLR for the runtime of any .NET implementation; modern .NET simply has no separate CLR version. |

## Why it matters

Most of the time the two compilations are invisible, and that is the point:
one build runs on every supported platform, and the runtime keeps improving
the code while it runs. Knowing they exist explains the things that do
become visible. A benchmark has to warm up before it measures anything,
because its first iterations run Tier0 code. A serverless function cares about
startup, and ReadyToRun or Native AOT is the lever for it. A library that
leans on reflection or `Reflection.Emit` will produce trimming warnings the day
someone publishes it with Native AOT. And a `.dll` that says "I386" in its
header will still run on an Arm64 laptop, because there was never any x86 code
in it, only IL waiting for the runtime to finish the job.

## References

[^managed]: Microsoft. (2025). *What is managed code?* .NET documentation. <https://learn.microsoft.com/en-us/dotnet/standard/managed-code>

[^execution]: Microsoft. (n.d.). *Managed execution process*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/standard/managed-execution-process>

[^roslyn]: .NET Foundation. (n.d.). *dotnet/roslyn: The Roslyn .NET compiler* [Repository]. GitHub. <https://github.com/dotnet/roslyn>

[^assemblies]: Microsoft. (2025). *Assemblies in .NET*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/standard/assembly/>

[^clr]: Microsoft. (2025). *Common Language Runtime (CLR) overview*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/standard/clr>

[^msbuild]: Microsoft. (n.d.). *MSBuild reference for .NET SDK projects*. Property `UseAppHost`. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/project-sdk/msbuild-props>

[^ecma335]: Ecma International. (2012). *ECMA-335: Common Language Infrastructure (CLI)* (6th ed.). First edition December 2001. <https://ecma-international.org/publications-and-standards/standards/ecma-335/>

[^ilverify]: .NET Foundation. (n.d.). *ILVerify* [README]. dotnet/runtime repository. <https://github.com/dotnet/runtime/blob/main/src/coreclr/tools/ILVerify/README.md>

[^fxversions]: Microsoft. (2026). *.NET Framework & Windows OS versions*. .NET Framework documentation. <https://learn.microsoft.com/en-us/dotnet/framework/install/versions-and-dependencies>

[^gc]: Microsoft. (2025). *Fundamentals of garbage collection*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/fundamentals>

[^cas]: Microsoft. (2023). *.NET Framework technologies unavailable on .NET 6+*. Section "Code access security (CAS)". .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/porting/net-framework-tech-unavailable>

[^jitdumps]: .NET Foundation. (n.d.). *Viewing JIT dumps*. dotnet/runtime repository, design documentation. <https://github.com/dotnet/runtime/blob/main/docs/design/coreclr/jit/viewing-jit-dumps.md>

[^config]: Microsoft. (2026). *Compilation config settings*. Tiered compilation, quick JIT, quick JIT for loops, ReadyToRun and profile-guided optimisation. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/runtime-config/compilation>

[^tiered]: .NET Foundation. (n.d.). *Tiered compilation*. dotnet/runtime repository, design documentation. <https://github.com/dotnet/runtime/blob/main/docs/design/features/tiered-compilation.md>

[^net7]: Microsoft. (2022). *What's new in .NET 7*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-7>

[^toub7]: Toub, S. (2022, August 31). Performance improvements in .NET 7. *.NET Blog*. Section "On-Stack Replacement". <https://devblogs.microsoft.com/dotnet/performance_improvements_in_net_7/>

[^net8]: Microsoft. (2023). *What's new in .NET 8 runtime*. Section "Performance improvements". .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-8/runtime>

[^r2r]: Microsoft. (2021). *ReadyToRun deployment overview*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/deploying/ready-to-run>

[^aot]: Microsoft. (2025). *Native AOT deployment overview*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/>

[^pinvoke]: Microsoft. (2024). *Platform Invoke (P/Invoke)*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke>

[^unsafe]: Microsoft. (2026). *Unsafe code, pointers to data, and function pointers*. C# language reference. <https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/unsafe-code>

[^mono]: Mono Project. (n.d.). *History*. <https://www.mono-project.com/docs/about-mono/history/>

[^launch]: Microsoft. (2002, February 13). *Microsoft launches XML Web services revolution with Visual Studio .NET and .NET Framework* [Press release]. <https://news.microsoft.com/2002/02/13/microsoft-launches-xml-web-services-revolution-with-visual-studio-net-and-net-framework/>

[^opensource]: Landwerth, I. (2014, November 12). .NET Core is open source. *.NET Blog*. <https://devblogs.microsoft.com/dotnet/net-core-is-open-source/>

[^core1]: Lander, R. (2016, June 27). Announcing .NET Core 1.0. *.NET Blog*. <https://devblogs.microsoft.com/dotnet/announcing-net-core-1-0/>

[^core3]: Lander, R. (2019, September 23). Announcing .NET Core 3.0. *.NET Blog*. <https://devblogs.microsoft.com/dotnet/announcing-net-core-3-0/>

[^net5]: Lander, R. (2020, November 10). Announcing .NET 5.0. *.NET Blog*. <https://devblogs.microsoft.com/dotnet/announcing-net-5-0/>
