---
title: "What Is a Processor? History, Architectures and How a CPU Works"
description: "A processor is the part of a computer that actually carries out instructions. Here is what that means, how it went from room-sized machines to billions of transistors on a chip, and how a modern CPU fetches, decodes and executes your code."
date: 2026-10-20T15:00:00Z
categories: ["Fundamentals"]
tags: ["Processors", "Computer Architecture", "History", "Computer Science", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

[What Is Programming?]({{< ref "what-is-programming" >}}) described programs as
precise descriptions of a process, and
[What Is an Operating System?]({{< ref "operating-systems" >}}) described the
software that shares a machine between them. This article goes one level
further down, to the part that does the work: the processor. It covers what a
processor is, how it got from vacuum tubes to tens of billions of transistors,
the main ways processors are designed, and, in some detail, how a modern CPU
turns instructions into results.

## What a processor is

**A processor is the part of a computer that carries out instructions. It
fetches them from memory one after another, works out what each one asks for,
and does it, operating on values held in its registers and in memory.**

Everything a computer does, from drawing a window to training a neural network,
ends up as a long stream of very simple instructions: load a number from
memory, add two numbers, compare them, jump to a different instruction if the
result was zero, store a number back. The processor's whole job is to run that
stream correctly and as fast as possible.

{{< diagram src="cpu-blocks.svg" caption="The main parts of a processor and what it connects to. Real chips repeat this block once per core and add graphics, memory controllers and more on the same die." >}}

The essential parts have barely changed since the 1940s:

| Part | What it does |
|---|---|
| **Control unit** | Fetches each instruction, decodes it and sends the signals that make the rest of the processor carry it out |
| **Registers** | A small set of very fast storage slots inside the processor. The **program counter** holds the address of the next instruction; general-purpose registers hold the values being worked on |
| **Arithmetic logic unit (ALU)** | Does the arithmetic (add, subtract) and logic (and, or, compare, shift). Modern processors have several, plus units for multiplication, floating point and vectors |
| **Caches** | Small, fast memories on the chip that keep copies of recently used data and instructions, because main memory is far slower than the processor |
| **Clock** | A signal that ticks billions of times a second; each tick advances the processor's circuits by one step |

### CPU, core, processor, chip

These words overlap, and are often used interchangeably:

| Term | Meaning today |
|---|---|
| **CPU** (central processing unit) | The general-purpose processor that runs the operating system and ordinary programs, as opposed to a GPU or other accelerator |
| **Core** | One complete processor, able to run its own stream of instructions. A modern CPU chip has several, sometimes dozens |
| **Microprocessor** | A processor built on a single integrated circuit. Since the 1970s, practically every processor is one |
| **System on a chip (SoC)** | One chip that combines CPU cores with a GPU, memory controller, media engines and more, as in every phone and in Apple's M-series Macs |

### Architecture and microarchitecture

The most important idea for understanding processors is the difference between
**what** a processor promises to do and **how** it does it.

- The **instruction set architecture (ISA)** is the contract between hardware
  and software: the instructions, the registers, how memory is addressed, how
  interrupts and privilege levels work. x86-64, ARM (AArch64) and RISC-V are
  ISAs. Compilers and operating systems are written against the ISA.
- The **microarchitecture** is one particular design that implements an ISA:
  how many instructions it works on at once, how big its caches are, how it
  predicts branches. Intel's and AMD's latest cores are completely different
  microarchitectures that run the same x86-64 programs.

IBM made this separation deliberately with the **System/360** in 1964: one
architecture for a whole family of machines at very different prices and
speeds, so customers could move to a bigger model without rewriting their
software.[^amdahl64] Every major processor family since works the same way, which is
why a program compiled years ago still runs on a processor designed this year.

### Kinds of processors

| Kind | Built for | Examples |
|---|---|---|
| **CPU** | General-purpose code: fast at one thread of complex, branchy logic | Intel Core, AMD Ryzen, Apple M-series, Arm Cortex-A |
| **GPU** | Thousands of simple operations in parallel: graphics, and now machine learning | NVIDIA GeForce and data-centre GPUs, AMD Radeon |
| **Microcontroller** | Cheap, low-power control of a device, with memory and I/O on the same chip | Arm Cortex-M, AVR, ESP32 |
| **DSP** | Signal processing: audio, radio, image pipelines | Qualcomm Hexagon, TI C6000 |
| **AI accelerator** | Matrix arithmetic for neural networks | Google TPU, the neural engines in phones and laptops |

## A history of processors

### Before the microprocessor

The first electronic computers of the 1940s built their processors out of
vacuum tubes and relays, and the stored-program design that every processor
still follows came out of that decade (the story is told in
[What Is Programming?]({{< ref "what-is-programming" >}})). John von Neumann's
1945 report described a machine with an arithmetic unit, a control unit and a
single memory for both instructions and data.[^vonneumann]

Two inventions made modern processors possible:

- The **transistor**, demonstrated at Bell Labs in December 1947 by John
  Bardeen and Walter Brattain, working in William Shockley's group, replaced
  the vacuum tube with a small, cool and reliable switch.[^bardeen][^chmtransistor]
- The **integrated circuit** put many transistors and their wiring on one
  piece of semiconductor. Jack Kilby built the first at Texas Instruments in
  1958.[^kilby] In 1959 Robert Noyce at Fairchild conceived a silicon version
  built with the planar process, which could be manufactured in volume; the
  first working ones followed in 1960.[^chmnoyce]

Processor design advanced quickly on these parts. In 1951 Maurice Wilkes
proposed **microprogramming**: implementing the control unit as a small
internal program of simpler steps rather than as fixed logic, which made
complex instruction sets practical to build.[^wilkes] The **CDC 6600** (1964),
designed by Seymour Cray, used ten functional units working at once and a
"scoreboard" to track which instructions could proceed, and was the fastest
computer of its day.[^thornton] For the **IBM System/360 Model 91** (1967),
Robert Tomasulo devised an algorithm that let instructions run as soon as their
inputs were ready, not strictly in program order.[^tomasulo] Both ideas are at
the heart of every high-performance processor today.

### 1971: the microprocessor

By the late 1960s an integrated circuit could hold thousands of transistors,
enough for a whole, simple processor. Intel was asked by the Japanese
calculator company Busicom to build a set of chips for a calculator, and
instead of many custom chips, Ted Hoff, Federico Faggin, Stanley Mazor and
Busicom's Masatoshi Shima designed a single programmable one. The **Intel
4004**, announced in November 1971, was a 4-bit processor of about 2,300
transistors.[^faggin][^intel4004]

Then came a rush of 8-bit processors that started the personal computer
industry: the Intel **8008** (1972) and **8080** (1974), the Motorola
**6800** (1974),[^chmmicro] the MOS Technology **6502** (1975), which powered
the Apple II and, as the 6510 variant, the Commodore 64,[^spectrum6502] and the
Zilog **Z80** (1976).[^spectrumz80] In 1978 Intel's 16-bit **8086** introduced
the **x86** instruction set,[^intel8086] and IBM's choice of its sibling, the
8088, for the IBM PC in 1981 made x86 the dominant architecture of personal
computing.[^ibmpc]

### Moore's law and Dennard scaling

In 1965 Gordon Moore, then at Fairchild, observed that the number of
components that could be put economically on a chip was doubling every year,
and predicted it would continue for at least a decade.[^moore65] In 1975 he
revised the rate to a doubling about every two years.[^moore75] The
prediction became a self-fulfilling industry roadmap and held, roughly, for
half a century.

A second, less famous rule mattered as much. In 1974 Robert Dennard and
colleagues at IBM showed that as transistors shrink, their voltage and current
can shrink in proportion, so the power used per unit of chip area stays
constant.[^dennard] **Dennard scaling** meant that each new generation of
smaller transistors could also run at a faster clock without the chip getting
hotter. For three decades, programs got faster every year without anyone
changing them.

### The 1980s: RISC

As compilers improved, researchers measured what instructions programs actually
used and found that compilers rarely used the complicated ones that
microprogramming had made easy to add. **RISC** (reduced instruction set
computer) proposed the opposite: a small set of simple, fixed-length
instructions, each doing one thing quickly, with only load and store
instructions touching memory, and many registers.[^pattersonditzel]

- At IBM, John Cocke's team began the **801** in the mid-1970s and had a
  prototype running by 1980, the first machine designed this way.[^radin][^ibmrisc]
- At Berkeley, the project led by David Patterson and Carlo Séquin, which
  coined the name RISC, produced its first **RISC I** chips in
  1981.[^vlsirisc][^ethwrisc]
- At Stanford, John Hennessy's **MIPS** project followed the same
  lines.[^ethwrisc]

Commercial RISC processors followed: MIPS, Sun's **SPARC**, IBM and Motorola's
**PowerPC**, and, in 1985, the first **ARM** processor, designed at Acorn
Computers in Cambridge by Sophie Wilson and Steve Furber.[^furber] Designed for
simplicity and low power, ARM went on to dominate phones and embedded systems,
and Arm describes it as the most widely used processor architecture in the
world.[^armhistory]

x86 survived the RISC era by borrowing its ideas. Starting with the **Pentium
Pro** (1995), Intel's processors translate x86 instructions internally into
simple, RISC-like **micro-operations** and execute those out of order.

### The 1990s: pipelines, superscalar and out-of-order

With more transistors to spend, designers made each processor do more work per
clock tick. The **Intel 80486** (1989) was pipelined and put the cache and
floating-point unit on the chip. The **Pentium** (1993) was **superscalar**,
able to start two instructions per cycle.[^intelquickref] Out-of-order execution, Tomasulo's
idea from the 1960s, returned in microprocessors such as the Pentium Pro, the
MIPS R10000 and the Alpha 21264. Clock speeds climbed from tens of megahertz to
over a gigahertz by 2000.

### The 2000s: 64 bits and the power wall

Two shifts defined the next decade.

**64 bits.** Intel's attempt to replace x86 with a new 64-bit architecture,
**Itanium** (2001), never caught on. Instead AMD extended x86 to 64 bits as
**AMD64**, disclosed in 1999 and first shipping in the Opteron in April 2003,
and Intel adopted the same extension in 2004.[^amd64][^amd10k] This **x86-64** is what desktops, laptops and most
servers run today.

**The power wall.** Around 2004, Dennard scaling broke down. Transistors had
become so small that they leaked current even when switched off, and voltage
could no longer be lowered in step with their size. Higher clock speeds now
meant much more heat than a chip could get rid of. Intel's Pentium 4 topped out
at 3.8 GHz,[^intelquickref] and desktop clock speeds have grown only slowly
since. The industry turned to **multicore** chips instead, putting several
complete processors on one die. IBM's POWER4 (2001) was the first commercial
example;[^ibmpower] AMD and Intel shipped dual-core desktop chips in
2005.[^athlonx2] Herb Sutter's essay *The Free Lunch Is
Over* (2005) warned programmers that from then on, faster programs would have
to be parallel programs.[^sutter][^olukotun]

### The 2010s and 2020s: phones, specialisation and open ISAs

Smartphones made energy efficiency the central design goal, and ARM-based SoCs
took over mobile computing. Arm's **big.LITTLE** design paired fast,
power-hungry cores with slow, efficient ones on the same chip,[^armhistory] an
idea now used in laptops and desktops as well. In 2020 Apple moved the Mac from Intel to
its own ARM-based **M1**, a chip of 16 billion transistors.[^m1]

As general-purpose cores stopped getting much faster, more work moved to
**specialised** processors. GPUs, originally graphics chips, became general
parallel processors once NVIDIA's CUDA (2006) let programmers write ordinary
code for them,[^cuda] and they now do most machine-learning work. Google built the
**Tensor Processing Unit**, deployed in its data centres from 2015, purely for
neural-network arithmetic.[^tpu]

**RISC-V**, started at Berkeley in 2010, is an open instruction set: anyone may
build a RISC-V processor without a licence or royalties.[^asanovic][^riscvhistory] It has
spread quickly in microcontrollers and embedded chips and is moving into larger
systems.

In January 2018, the **Spectre** and **Meltdown** attacks showed that the
speculative execution processors had relied on for decades could leak secrets
through cache timing.[^projectzero][^spectre][^meltdown] Processor security is now a design
goal alongside speed and power.

## A timeline at a glance

| Year | Milestone |
|---|---|
| 1945 | von Neumann's EDVAC report: the stored-program design |
| 1947 | Point-contact transistor at Bell Labs |
| 1951 | Wilkes proposes microprogramming |
| 1958–59 | Integrated circuit: Kilby (TI), Noyce (Fairchild) |
| 1964 | IBM System/360 separates architecture from implementation; CDC 6600 |
| 1965 | Moore's law |
| 1967 | Tomasulo's algorithm in the IBM System/360 Model 91 |
| 1971 | Intel 4004, the first commercial microprocessor |
| 1974 | Dennard scaling; Intel 8080, Motorola 6800 |
| 1978 | Intel 8086 and the x86 architecture |
| 1980–82 | RISC: IBM 801, Berkeley RISC I, Stanford MIPS |
| 1985 | First ARM processor; Intel 80386 (32-bit x86) |
| 1993 | Intel Pentium, superscalar x86 |
| 1995 | Pentium Pro: out-of-order x86 with micro-operations |
| 2001 | IBM POWER4, first commercial multicore chip; Itanium |
| 2003 | AMD64 in the Opteron |
| 2004–05 | The power wall; dual-core desktop processors |
| 2006 | NVIDIA CUDA |
| 2010 | RISC-V project begins |
| 2015 | Google's TPU enters service |
| 2018 | Spectre and Meltdown |
| 2020 | Apple M1 |

## Instruction set architectures

### von Neumann and Harvard

The first architectural choice is how instructions and data reach the
processor.

{{< diagram src="von-neumann-harvard.svg" caption="In a von Neumann machine, instruction fetches and data accesses share one path to one memory. A Harvard machine gives each its own." >}}

In a **von Neumann architecture**, instructions and data share one memory and
one path to it. This is flexible (a program is just data, so it can be loaded,
generated or modified like any other data) but the processor cannot fetch an
instruction and read data in the same instant. That single path is the **von
Neumann bottleneck**. A **Harvard architecture** keeps instructions and data in
separate memories with separate paths, so both can be accessed at once; many
microcontrollers and DSPs work this way.

Modern CPUs are a hybrid, sometimes called **modified Harvard**: main memory is
shared, as in von Neumann's design, but the first-level cache is split into an
instruction cache and a data cache, so the core can fetch and access data in
the same cycle.[^hp]

### CISC and RISC

| | CISC | RISC |
|---|---|---|
| **Instructions** | Many, some very complex (string copies, instructions that read memory, compute and write back) | Fewer, simple, each doing one operation |
| **Encoding** | Variable length; x86 instructions are 1 to 15 bytes[^intelsdm] | Fixed length, usually 32 bits, sometimes with a 16-bit compressed form |
| **Memory access** | Most instructions can read or write memory directly | Only loads and stores touch memory (a **load/store architecture**) |
| **Registers** | Historically few (x86 had 8; x86-64 has 16 general-purpose) | Many (31 in ARM AArch64 plus a zero register; 32 in RISC-V, including the zero register) |
| **Examples** | x86, IBM System/360 and its successors, VAX | ARM, RISC-V, MIPS, POWER, SPARC |

The distinction matters less than it once did. Large x86 cores decode their
instructions into RISC-like micro-operations, and ARM has grown a large,
sophisticated instruction set. What remains is that simple, fixed-length
encodings are easier to decode quickly and with less power, while x86 carries
decades of compatibility.

### The main ISAs today

| ISA | Where you find it | How it is licensed |
|---|---|---|
| **x86-64** | Desktops, laptops, most servers | Controlled by Intel and AMD, who cross-license their patents; only a few others, such as VIA, hold licences[^via] |
| **ARM (AArch64)** | Phones, tablets, Apple Macs, a growing share of servers, most embedded devices | Arm licenses its core designs and the architecture itself to chip makers |
| **RISC-V** | Microcontrollers, storage and embedded controllers, a growing range of larger chips | Open standard, free to implement |
| **POWER** | IBM servers | IBM; opened through the OpenPOWER Foundation |

### What an instruction looks like

An instruction is just a number whose bits the processor's decoder splits into
fields. In RISC-V every basic instruction is 32 bits, laid out in a handful of
fixed formats.[^riscv] The register-to-register format looks like this:

{{< diagram src="riscv-encoding.svg" caption="How the instruction `add x5, x6, x7` is encoded in RISC-V. The source and destination register numbers sit in the same bit positions in every format that has them, so the decoder can start reading registers before it knows exactly which instruction it has." >}}

### Classifying parallelism

Michael Flynn's 1966 taxonomy classifies machines by how many instruction
streams and data streams they handle at once:[^flynn]

| | Single data stream | Multiple data streams |
|---|---|---|
| **Single instruction stream** | **SISD**: a classic single-core processor | **SIMD**: one instruction applied to many values at once, as in vector units and GPUs |
| **Multiple instruction streams** | **MISD**: rare in practice | **MIMD**: several independent cores, each running its own program |

A modern chip is all of these at once: several MIMD cores, each with SIMD
vector units.

## How a processor works

### From transistors to logic

At the bottom, a processor is made of **transistors** used as switches: a
voltage on one terminal turns the connection between the other two on or off.
A few transistors make a **logic gate** (NOT, AND, OR, NAND). Gates combine
into larger blocks:

- **Combinational logic** computes an output purely from its current inputs:
  adders, comparators, and **multiplexers** that choose between inputs.
- **Sequential logic** remembers: a **flip-flop** stores one bit and updates it
  only on a clock edge. Registers are rows of flip-flops.

The **clock** ties it together. On each tick, every register captures the
output of the logic feeding it, and in the time before the next tick that new
value ripples through the next stage of logic. The slowest path through the
logic between two registers sets the fastest the clock can run.

### The fetch–decode–execute cycle

Every processor, from the 4004 to the newest server chip, repeats the same
cycle:

1. **Fetch** the instruction at the address in the program counter.
2. **Decode** it: which operation, which registers, which immediate values.
3. **Execute** it: compute a result, an address or a branch decision.
4. **Access memory** if the instruction is a load or store.
5. **Write back** the result to a register, and move the program counter to the
   next instruction, or to the branch target.

The classic RISC design maps each of those steps onto one stage of hardware:

{{< diagram src="datapath.svg" caption="The five stages of the classic RISC pipeline and the state each one uses. Instructions come from the instruction cache; operands come from and results return to the register file." >}}

Here is a short C function and the RISC-V assembly a compiler might produce for
it. Every line of the assembly is one trip around that cycle:

```c
long sum(const long *a, long n) {
    long s = 0;
    for (long i = 0; i < n; i++)
        s += a[i];
    return s;
}
```

```asm
# a0 = pointer to the array, a1 = n; the result goes back in a0
sum:
    li    t0, 0           # s = 0
    blez  a1, done        # nothing to add if n <= 0
loop:
    ld    t1, 0(a0)       # load the next element         (memory)
    add   t0, t0, t1      # s += element                  (ALU)
    addi  a0, a0, 8       # step to the next 8-byte element
    addi  a1, a1, -1      # one fewer to go
    bnez  a1, loop        # go round again while n != 0   (branch)
done:
    mv    a0, t0          # return s
    ret
```

### Control: hardwired or microcoded

The control unit turns each decoded instruction into the signals that steer the
datapath: which registers to read, what the ALU should do, whether to access
memory. In a **hardwired** design this is fixed logic, which is fast and suits
simple RISC instructions. In a **microcoded** design, as Wilkes proposed, each
instruction runs a short sequence of micro-instructions from a small internal
memory.[^wilkes] Modern x86 cores use both: common instructions are decoded
directly into micro-operations by hardware, and rare complex ones fall back to
microcode. Because microcode can be updated, processor makers can also use it
to fix some bugs after a chip has shipped.

### Pipelining

Running one instruction through all five stages before starting the next would
leave four of the five stages idle at any moment. **Pipelining** overlaps
them, like an assembly line: while one instruction is being executed, the next
is being decoded and the one after that fetched.

{{< diagram src="pipeline.svg" caption="Five instructions in a five-stage pipeline. Each instruction still takes five cycles, but from cycle 5 on, one finishes every cycle." >}}

A pipeline does not make any single instruction faster; it raises
**throughput**, the number of instructions finished per second. A deeper
pipeline, with more and shorter stages, also allows a faster clock. The cost is
**hazards**, situations where the next instruction cannot proceed:

- **Data hazards.** In the loop above, `add t0, t0, t1` needs the value that
  `ld t1, 0(a0)` is still loading. Processors **forward** results straight
  from one stage to the next instead of waiting for them to reach the register
  file, and **stall** (insert a bubble) only when the value genuinely is not
  ready yet.
- **Control hazards.** At `bnez a1, loop` the processor does not know which
  instruction comes next until the branch is resolved, several stages later.
- **Structural hazards.** Two instructions need the same piece of hardware in
  the same cycle; designers avoid these by duplicating hardware, such as the
  split instruction and data caches.

### Branch prediction

In typical integer code roughly one instruction in five to seven is a
branch,[^panda] and a deep pipeline cannot afford to wait for each one. So processors **predict** the
outcome and keep fetching down the predicted path; if the guess was wrong, they
discard the work and restart from the right place.

Early schemes simply guessed that backward branches (loops) are taken. James
Smith's 1981 study showed that remembering each branch's recent behaviour in a
small table of two-bit counters predicts more accurately and more consistently
than fixed rules.[^smith] Modern predictors combine many such tables indexed by
the history of recent branches and are right well over 95 percent of the time
on typical code.[^panda] They need to be: on a current desktop core a
misprediction throws away around 15 to 20 cycles of work, during which the core
could have started several instructions per cycle.[^agner]

### Superscalar and out-of-order execution

A pipelined processor finishes at most one instruction per cycle. A
**superscalar** processor has several pipelines and can start several
instructions in the same cycle; large modern cores can decode, rename and
retire around eight per cycle.[^lioncove]

To keep that many units busy, the processor cannot simply run instructions in
program order: whenever one is waiting, for example on a load that missed in
the cache, everything behind it would wait too. **Out-of-order execution**
looks ahead in the instruction stream for independent work.

{{< diagram src="ooo-core.svg" caption="A simplified out-of-order core. The front end and retirement work in program order; in between, instructions run whenever their inputs are ready." >}}

1. The **front end** predicts branches, fetches instructions and decodes them
   into micro-operations, in program order.
2. **Register renaming** maps each architectural register (such as `t0`) onto
   one of a much larger pool of physical registers. This removes false
   dependencies between instructions that merely reuse the same register name.
3. A **scheduler** holds waiting micro-operations and issues each one to an
   execution unit as soon as its inputs are ready, which is Tomasulo's
   algorithm in modern form.[^tomasulo]
4. The **reorder buffer** keeps every micro-operation in its original order
   until it completes, then **retires** them in that order, making their
   results officially visible. If a branch was mispredicted or an instruction
   faulted, everything after it is discarded as if it had never run.

Modern cores keep several hundred instructions in flight this way; Intel's
Lion Cove core, for example, has a 576-entry reorder buffer.[^lioncove] The illusion
they maintain is the important part: the program sees exactly the results it
would have seen if each instruction had run one at a time, in order.

### Speculation and its side effects

Out-of-order execution and branch prediction together mean a processor
constantly runs instructions it is not sure it needs, and throws away the
results if it guessed wrong. The results are discarded, but not every trace of
them: data that a discarded instruction loaded is still in the cache.
**Spectre** showed that an attacker can trick the branch predictor into
speculatively reading a secret and then detect, from cache timing, which cache
line the secret touched.[^spectre] **Meltdown** showed that some processors
would speculatively read kernel memory from user code before checking
permission.[^meltdown] Fixes have combined microcode updates, operating system
changes (such as keeping kernel memory almost entirely out of user page
tables)[^kpti] and new hardware designs.

### The memory hierarchy

A processor core can start several instructions every nanosecond, but reading
main memory takes on the order of a hundred nanoseconds. William Wulf and Sally
McKee called the widening gap between processor and memory speed the
**memory wall**.[^wulf] The answer is a hierarchy of memories, each larger and
slower than the one above it:

{{< diagram src="memory-hierarchy.svg" caption="The memory hierarchy of a typical current desktop or laptop processor. Sizes and times are rough and vary between chips, as does the layout: Apple's M-series, for example, shares a large L2 between a cluster of cores and has no L3. One nanosecond is a few clock cycles." >}}

Caches work because programs have **locality**:

- **Temporal locality.** Data used recently is likely to be used again soon,
  such as a loop counter or the top of the stack.
- **Spatial locality.** Data near recently used data is likely to be used soon,
  such as the next element of an array.

Typical figures for current cores are an L1 hit in about four cycles and a
trip to main memory of roughly a hundred nanoseconds.[^lioncove][^m1caches]
Caches move data in **cache lines**, typically 64 bytes,[^intelsdm3] so reading one array
element brings its neighbours along for free. When a line is needed and the
cache is full, the cache evicts an older line, usually the least recently used.
How you walk through memory can therefore matter more than how many operations
you do. These two functions add up the same numbers:

```c
#define N 4096
static double m[N][N];

double sum_rows(void) {       /* walks memory in order: uses every byte of each line */
    double s = 0;
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            s += m[i][j];
    return s;
}

double sum_columns(void) {    /* jumps 32 KiB per step: a new cache line every time */
    double s = 0;
    for (int j = 0; j < N; j++)
        for (int i = 0; i < N; i++)
            s += m[i][j];
    return s;
}
```

C stores each row contiguously, so `sum_rows` reads memory sequentially, while
`sum_columns` touches a different cache line, and with 4 KiB pages a different
page, on every addition. On a typical machine the second is several times
slower.[^drepper]

With several cores, each with its own caches, the hardware must also keep them
**coherent**: when one core writes to a line, copies of it in other cores'
caches must be updated or invalidated. Protocols such as **MESI** track whether
each line is modified, exclusive, shared or invalid.[^hp][^intelsdm3]

### Vectors, cores and threads

Beyond running one instruction stream fast, processors find parallelism in
three more ways:

- **SIMD (vector) instructions** apply one operation to several values packed
  in a wide register: four, eight or sixteen numbers in one instruction. x86 has
  SSE and AVX, ARM has NEON and SVE, and RISC-V has its V extension.
  Compilers use them automatically for simple loops like `sum` above, and
  libraries for graphics, media and machine learning use them heavily.
- **Multiple cores** run separate instruction streams, which is why
  multithreaded programs matter.
- **Simultaneous multithreading (SMT)**, which Intel calls Hyper-Threading,
  lets one core hold the state of two threads and fill idle execution units
  from either, recovering some of the time one thread spends waiting.

### Power and the clock

The power a chip burns switching its transistors grows roughly as
**C × V² × f**: the capacitance being switched, the square of the supply
voltage, and the clock frequency.[^hp][^energymodel] Since a higher frequency
also needs a higher voltage, power climbs much faster than speed. That is why the clock race
ended, and why every processor now constantly adjusts its own speed: **dynamic
voltage and frequency scaling** lowers voltage and clock when there is little
to do, and **boost** or **turbo** modes raise them briefly while there is
thermal headroom. Chips with **hybrid** designs, such as big.LITTLE, schedule
background work on small efficient cores and save the large ones for work that
needs them.

Manufacturing **process nodes** are still named in nanometres ("7 nm",
"3 nm"), but the names began to drift away from physical dimensions in the
late 1990s and are now labels for a generation of technology, not the size of
any feature on the chip.[^spectrumnodes]

## Putting it together: one trip round the loop

Following the `sum` loop through a modern out-of-order core shows most of the
machinery at work in a few nanoseconds.

1. **Predict.** The branch predictor has seen `bnez a1, loop` taken many times,
   so it predicts taken again and tells the front end to keep fetching from
   `loop` without waiting.
2. **Fetch and decode.** The front end reads the next several instructions from
   the L1 instruction cache and decodes them, often a whole loop iteration per
   cycle.
3. **Rename.** `t0`, `t1`, `a0` and `a1` are mapped to fresh physical
   registers, so iteration *k*+1's `addi a0, a0, 8` does not have to wait for
   iteration *k*'s load to finish reading `a0`.[^agner] Several iterations are now in
   flight at once.
4. **Execute out of order.** The pointer and counter updates are ready at once
   and run immediately. Each `ld` goes to a load unit; if the element is in the
   L1 data cache, it arrives in about four cycles, and the matching
   `add` is issued the moment it does. If it misses, the core keeps working on
   later iterations whose data is already there, while the hardware
   **prefetcher**, having noticed that the loop walks memory in order, has
   probably already started fetching the next lines.
5. **Retire.** As each instruction completes, the reorder buffer retires it in
   program order, and its result becomes part of the official state.
6. **Mispredict, once.** On the last iteration the branch falls through. The
   predictor guessed wrong, the core discards the speculative instructions
   from the iteration that never happened, and fetching restarts at `done`.

To the program, all of this is invisible: it ran one instruction after
another, exactly as written.

## Why it matters

For most of computing history, software got faster for free as processors
improved. That ended with the power wall, and what decides performance now is
much more visible to programmers: whether code can use several cores, whether
its loops can use vector instructions, whether its data is laid out so the
caches and prefetchers can do their job, and whether its branches are
predictable. Knowing how the processor really works, and the illusion of simple
sequential execution it maintains, explains why two programs that do the same
arithmetic can differ in speed by an order of magnitude.

## References

[^hp]: Hennessy, J. L., & Patterson, D. A. (2019). *Computer Architecture: A Quantitative Approach* (6th ed.). Morgan Kaufmann.

[^amdahl64]: Amdahl, G. M., Blaauw, G. A., & Brooks, F. P., Jr. (1964). Architecture of the IBM System/360. *IBM Journal of Research and Development*, 8(2), 87–101. <https://doi.org/10.1147/rd.82.0087>

[^vonneumann]: von Neumann, J. (1945). *First Draft of a Report on the EDVAC*. Moore School of Electrical Engineering, University of Pennsylvania. Reprinted in *IEEE Annals of the History of Computing*, 15(4), 27–75 (1993). <https://doi.org/10.1109/85.238389>

[^bardeen]: Bardeen, J., & Brattain, W. H. (1948). The transistor, a semi-conductor triode. *Physical Review*, 74(2), 230–231. <https://doi.org/10.1103/PhysRev.74.230>

[^chmtransistor]: Computer History Museum. (n.d.). 1947: Invention of the point-contact transistor. *The Silicon Engine*. <https://www.computerhistory.org/siliconengine/invention-of-the-point-contact-transistor/>

[^kilby]: Kilby, J. S. (1976). Invention of the integrated circuit. *IEEE Transactions on Electron Devices*, 23(7), 648–654. <https://doi.org/10.1109/T-ED.1976.18467>

[^chmnoyce]: Computer History Museum. (n.d.). 1959: Practical monolithic integrated circuit concept patented. *The Silicon Engine*. <https://www.computerhistory.org/siliconengine/practical-monolithic-integrated-circuit-concept-patented/>

[^wilkes]: Wilkes, M. V. (1951). The best way to design an automatic computing machine. In *Report of the Manchester University Computer Inaugural Conference* (pp. 16–18). Manchester University.

[^thornton]: Thornton, J. E. (1964). Parallel operation in the Control Data 6600. *Proceedings of the October 27–29, 1964, Fall Joint Computer Conference, Part II*, 33–40. <https://doi.org/10.1145/1464039.1464045>

[^tomasulo]: Tomasulo, R. M. (1967). An efficient algorithm for exploiting multiple arithmetic units. *IBM Journal of Research and Development*, 11(1), 25–33. <https://doi.org/10.1147/rd.111.0025>

[^faggin]: Faggin, F., Hoff, M. E., Jr., Mazor, S., & Shima, M. (1996). The history of the 4004. *IEEE Micro*, 16(6), 10–20. <https://doi.org/10.1109/40.546561>

[^intel4004]: Intel Corporation. (n.d.). The story of the Intel 4004. Archived 2023 by the Internet Archive. <https://web.archive.org/web/2023/https://www.intel.com/content/www/us/en/history/museum-story-of-intel-4004.html>

[^chmmicro]: Computer History Museum. (n.d.). 1971: Microprocessor integrates CPU function onto a single chip. *The Silicon Engine*. <https://www.computerhistory.org/siliconengine/microprocessor-integrates-cpu-function-onto-a-single-chip/>

[^spectrum6502]: IEEE Spectrum. (2017, June 30). Chip Hall of Fame: MOS Technology 6502 microprocessor. <https://spectrum.ieee.org/chip-hall-of-fame-mos-technology-6502-microprocessor>

[^spectrumz80]: IEEE Spectrum. (2017, June 30). Chip Hall of Fame: Zilog Z80 microprocessor. <https://spectrum.ieee.org/chip-hall-of-fame-zilog-z80-microprocessor>

[^intel8086]: Intel Corporation. (n.d.). Intel's first 16-bit microprocessor: 8086 and Operation Crush. <https://www.intel.com/content/www/us/en/history/virtual-vault/articles/the-intel-8086.html>

[^ibmpc]: IBM. (n.d.). The IBM PC. <https://www.ibm.com/history/personal-computer>

[^moore65]: Moore, G. E. (1965). Cramming more components onto integrated circuits. *Electronics*, 38(8), 114–117. Reprinted in *Proceedings of the IEEE*, 86(1), 82–85 (1998). <https://doi.org/10.1109/JPROC.1998.658762>

[^moore75]: Moore, G. E. (1975). Progress in digital integrated electronics. *Technical Digest of the International Electron Devices Meeting*, 11–13. Reprinted in *IEEE Solid-State Circuits Society Newsletter*, 11(3), 36–37 (2006). <https://doi.org/10.1109/N-SSC.2006.4804410>

[^dennard]: Dennard, R. H., Gaensslen, F. H., Yu, H.-N., Rideout, V. L., Bassous, E., & LeBlanc, A. R. (1974). Design of ion-implanted MOSFET's with very small physical dimensions. *IEEE Journal of Solid-State Circuits*, 9(5), 256–268. <https://doi.org/10.1109/JSSC.1974.1050511>

[^pattersonditzel]: Patterson, D. A., & Ditzel, D. R. (1980). The case for the reduced instruction set computer. *ACM SIGARCH Computer Architecture News*, 8(6), 25–33. <https://doi.org/10.1145/641914.641917>

[^radin]: Radin, G. (1982). The 801 minicomputer. *Proceedings of the First International Symposium on Architectural Support for Programming Languages and Operating Systems*, 39–47. <https://doi.org/10.1145/800050.801824>

[^ibmrisc]: IBM. (n.d.). RISC. <https://www.ibm.com/history/risc>

[^vlsirisc]: Patterson, D. A., & Séquin, C. H. (1982). A VLSI RISC. *Computer*, 15(9), 8–21. <https://doi.org/10.1109/MC.1982.1654133>

[^ethwrisc]: Engineering and Technology History Wiki. (n.d.). Milestones: First RISC (reduced instruction-set computing) microprocessor, 1980–1982. <https://ethw.org/Milestones:First_RISC_(Reduced_Instruction-Set_Computing)_Microprocessor_1980-1982>

[^furber]: Furber, S. (2000). *ARM System-on-Chip Architecture* (2nd ed.). Addison-Wesley.

[^armhistory]: Arm. (n.d.). The official history of Arm. *Arm Newsroom*. <https://newsroom.arm.com/blog/arm-official-history>

[^intelquickref]: Intel Corporation. (n.d.). Intel microprocessor quick reference guide: Product family. <https://www.intel.com/pressroom/kits/quickreffam.htm>

[^amd64]: Hachman, M. (1999, October 5). AMD discloses internally-developed 64-bit architecture. *EE Times*. <https://www.eetimes.com/amd-discloses-internally-developed-64-bit-architecture/>

[^amd10k]: Advanced Micro Devices. (2004). *Form 10-K for the fiscal year ended December 28, 2003*. U.S. Securities and Exchange Commission. <https://www.sec.gov/Archives/edgar/data/2488/000119312504037179/d10k.htm>

[^ibmpower]: IBM. (n.d.). IBM Power4. <https://www.ibm.com/history/power>

[^athlonx2]: Smith, T. (2005, May 31). AMD launches dual-core Athlon 64 X2. *The Register*. <https://www.theregister.com/2005/05/31/amd_athlon_64_x2/>

[^sutter]: Sutter, H. (2005). The free lunch is over: A fundamental turn toward concurrency in software. *Dr. Dobb's Journal*, 30(3). <http://www.gotw.ca/publications/concurrency-ddj.htm>

[^olukotun]: Olukotun, K., Nayfeh, B. A., Hammond, L., Wilson, K., & Chang, K. (1996). The case for a single-chip multiprocessor. *Proceedings of the Seventh International Conference on Architectural Support for Programming Languages and Operating Systems*, 2–11. <https://doi.org/10.1145/237090.237140>

[^m1]: Apple. (2020, November 10). Apple unleashes M1 [Press release]. <https://www.apple.com/newsroom/2020/11/apple-unleashes-m1/>

[^cuda]: NVIDIA. (2018). *CUDA C Programming Guide* (Version 10.0), Chapter 1: Introduction. <https://docs.nvidia.com/cuda/archive/10.0/cuda-c-programming-guide/index.html>

[^tpu]: Jouppi, N. P., Young, C., Patil, N., Patterson, D., et al. (2017). In-datacenter performance analysis of a tensor processing unit. *Proceedings of the 44th Annual International Symposium on Computer Architecture*, 1–12. <https://doi.org/10.1145/3079856.3080246>

[^asanovic]: Asanović, K., & Patterson, D. A. (2014). *Instruction Sets Should Be Free: The Case for RISC-V* (Technical Report No. UCB/EECS-2014-146). University of California, Berkeley. <https://www2.eecs.berkeley.edu/Pubs/TechRpts/2014/EECS-2014-146.html>

[^riscvhistory]: RISC-V International. (n.d.). About RISC-V: History. <https://riscv.org/about/history/>

[^projectzero]: Horn, J. (2018, January 3). Reading privileged memory with a side-channel. *Project Zero*. <https://projectzero.google/2018/01/reading-privileged-memory-with-side.html>

[^spectre]: Kocher, P., Horn, J., Fogh, A., Genkin, D., Gruss, D., Haas, W., Hamburg, M., Lipp, M., Mangard, S., Prescher, T., Schwarz, M., & Yarom, Y. (2019). Spectre attacks: Exploiting speculative execution. *2019 IEEE Symposium on Security and Privacy*, 1–19. <https://doi.org/10.1109/SP.2019.00002>

[^meltdown]: Lipp, M., Schwarz, M., Gruss, D., Prescher, T., Haas, W., Horn, J., Mangard, S., Kocher, P., Genkin, D., Yarom, Y., Hamburg, M., & Strackx, R. (2020). Meltdown: Reading kernel memory from user space. *Communications of the ACM*, 63(6), 46–56. <https://doi.org/10.1145/3357033>

[^kpti]: The Linux Kernel documentation. (n.d.). Page table isolation (PTI). <https://docs.kernel.org/arch/x86/pti.html>

[^via]: Intel Corporation. (2003, April 7). Intel and VIA Technologies, Inc. settle patent infringement cases [Press release]. <https://www.intel.com/pressroom/archive/releases/2003/20030407corp.htm>

[^intelsdm]: Intel Corporation. (2026). *Intel 64 and IA-32 Architectures Software Developer's Manual, Combined Volumes 2A, 2B, 2C, and 2D: Instruction Set Reference, A–Z* (Order No. 325383-093), Section 2.3.11. <https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html>

[^intelsdm3]: Intel Corporation. (2026). *Intel 64 and IA-32 Architectures Software Developer's Manual, Volume 3A: System Programming Guide, Part 1* (Order No. 253668-093US), Chapter 11, Memory Cache Control. <https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html>

[^riscv]: Waterman, A., & Asanović, K. (Eds.). (2019). *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA* (Document Version 20191213). RISC-V Foundation. <https://github.com/riscv/riscv-isa-manual/releases/tag/Ratified-IMAFDQC>

[^spectrumnodes]: Moore, S. K. (2020, July 21). A better way to measure progress in semiconductors. *IEEE Spectrum*. <https://spectrum.ieee.org/a-better-way-to-measure-progress-in-semiconductors>

[^flynn]: Flynn, M. J. (1966). Very high-speed computing systems. *Proceedings of the IEEE*, 54(12), 1901–1909. <https://doi.org/10.1109/PROC.1966.5273>

[^panda]: Panda, R., Song, S., Dean, J., & John, L. K. (2018). Wait of a decade: Did SPEC CPU 2017 broaden the performance horizon? *2018 IEEE International Symposium on High Performance Computer Architecture*, 271–282. <https://doi.org/10.1109/HPCA.2018.00032>

[^smith]: Smith, J. E. (1981). A study of branch prediction strategies. *Proceedings of the 8th Annual Symposium on Computer Architecture*, 135–148. Reprinted in *25 Years of the International Symposia on Computer Architecture* (1998), 202–215. <https://doi.org/10.1145/285930.285980>

[^agner]: Fog, A. (n.d.). *The Microarchitecture of Intel, AMD and VIA CPUs: An Optimization Guide for Assembly Programmers and Compiler Makers*. Technical University of Denmark. Retrieved October 20, 2026, from <https://www.agner.org/optimize/microarchitecture.pdf>

[^lioncove]: Chips and Cheese. (2024, September 27). Lion Cove: Intel's P-core roars. <https://old.chipsandcheese.com/2024/09/27/lion-cove-intels-p-core-roars/>

[^m1caches]: 7-cpu.com. (n.d.). Apple M1. Retrieved October 20, 2026, from <https://7-cpu.com/cpu/Apple_M1.html>

[^drepper]: Drepper, U. (2007, October 23). Memory part 5: What programmers can do. *LWN.net*. <https://lwn.net/Articles/255364/>

[^wulf]: Wulf, W. A., & McKee, S. A. (1995). Hitting the memory wall: Implications of the obvious. *ACM SIGARCH Computer Architecture News*, 23(1), 20–24. <https://doi.org/10.1145/216585.216588>

[^energymodel]: The Linux Kernel documentation. (n.d.). Energy model of devices. <https://docs.kernel.org/power/energy-model.html>
