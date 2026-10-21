---
title: "Anvil OS: An Operating System From Scratch"
description: "An idea for an operating system built from scratch to learn how one works, starting from the simplest kernel and growing it into something usable and POSIX-compatible, with a suggested technology stack and a roadmap of milestones."
date: 2026-10-21T15:00:00Z
categories: ["Brainstorms"]
tags: ["Anvil OS", "Operating Systems", "Kernel", "Rust", "x86-64", "POSIX", "Technology Stack"]
---

An open source operating system built from scratch.

## Overview

The idea is to build a fully functional operating system, to learn about how an operating system works, and from the simpler version of a kernel, improve it until something really usable.

## Roadmap

- Start with the simpler version of a kernel
- Build functionalities on top of the kernel
- Improve as we test

## Technology stack

An operating system has almost no stack in the usual sense: there is no
runtime, no standard library and no framework beneath it, because it is the
thing those normally run on. The choices that matter are the language, the
processor architecture, how the kernel gets loaded, and the tools for running
and debugging a kernel that cannot print an error when it crashes. The
background for all of it is in [Operating Systems]({{< ref "/fundamentals/operating-systems" >}})
and [Processors]({{< ref "/fundamentals/processors" >}}).

### The suggestion at a glance

| Concern | Choice | Why |
| --- | --- | --- |
| Language | Rust, with `#![no_std]` | Memory safety everywhere outside the `unsafe` blocks that touch hardware, and Cargo for building, at no runtime cost. |
| Architecture | x86-64 | It runs on the PCs already at hand, so the OS can boot on real hardware, and it has the most documentation. |
| Compiler target | `x86_64-unknown-none` | Rust's built-in target for bare-metal x86-64, so the kernel builds without a custom target file. |
| Boot loader | Limine, with the `limine` crate | Loads the kernel already in 64-bit mode with paging on, and hands over the memory map, framebuffer and modules. |
| Emulator | QEMU | Boots the kernel in a second, emulates the devices a first kernel needs, and runs headless in CI. |
| Debugger | GDB, through QEMU's GDB server | Breakpoints and stepping inside the kernel, with Rust's symbols. |
| Build tool | Cargo with an `xtask` | One `cargo xtask run` builds the kernel, makes the bootable image and starts QEMU, without Make or shell scripts. |
| Testing | Host unit tests and QEMU integration tests | Pure logic is tested on the host with `cargo test`; anything that needs hardware boots in QEMU and reports over the serial port. |
| CI | GitHub Actions on Linux | Builds the image and boots every test kernel in QEMU on each pull request. |
| C library | mlibc | A portable C library written for hobby operating systems, which gives programs the POSIX interface on top of Anvil's own system calls. |
| Ported programs | An Anvil target for GCC or Clang | Compiles existing POSIX programs, such as a shell and core utilities, for Anvil OS. |

### Why Rust

A kernel bug rarely says what went wrong. A stray pointer corrupts memory, and
much later the processor faults, or resets with no message at all. Rust's
borrow checker rules out most of those bugs at compile time, and confines the
rest to `unsafe` blocks that can be found with a search. Rust also has a
complete OS development path to learn from: Philipp Oppermann's *Writing an OS
in Rust* builds a kernel step by step, and Redox OS is a full operating system
written in Rust.

| Option | Strengths | Trade-off |
| --- | --- | --- |
| **Rust** | Memory safety, Cargo, `core` and `alloc` without an OS, a growing body of OS projects | A steep start, and a few kernel features, such as the interrupt calling convention, are only on nightly |
| C | The language of most tutorials, of the OSDev wiki and of xv6, and the closest to the hardware | No safety net: memory bugs show up as crashes far from their cause |
| C++ | Classes and templates, and SerenityOS as a complete example | Exceptions and RTTI must be turned off, and parts of the runtime written by hand |
| Zig | Excellent cross-compilation and compile-time code | Not yet at 1.0, so the language changes between releases, and fewer OS resources exist |

Learning in C first is a fair choice too, since most material assumes it. But a
from-scratch project lives for years, and Rust's guarantees pay for themselves
more the larger the kernel grows. Reading C examples and writing Rust is a
common way to get both.

### Why x86-64 and Limine

| Architecture | Strengths | Trade-off |
| --- | --- | --- |
| **x86-64** | Runs on ordinary PCs, the most documentation, fast in QEMU | Decades of legacy, such as segmentation and the old interrupt controller, that a kernel has to set up before it can ignore |
| RISC-V | A small, clean instruction set, and the architecture xv6 teaches on | Real boards are less common, and they differ more from one another |
| AArch64 | Phones, the Raspberry Pi and Apple computers | Each board boots differently and describes its devices in a device tree |

The worst of x86-64's legacy is in booting: a PC starts in 16-bit real mode,
and reaching 64-bit long mode takes a page of assembly that teaches little. A
boot loader that follows the Limine protocol does that part. It loads the
kernel into the higher half of the address space with paging on, and answers
the kernel's requests for the memory map, the framebuffer, the processors and
any files loaded alongside it. Limine also supports AArch64 and RISC-V, so a
later port keeps the same boot path.

Writing a boot loader is worth doing once, to learn how a machine starts, but
it can come later as a side project rather than blocking the kernel.

### Developing on Windows

QEMU runs on Windows, but making the bootable image needs `xorriso`, and most
OS development guides assume a Linux shell. The smoothest setup is to build in
WSL 2 or a dev container, and to run QEMU from there or from Windows. CI uses
Linux anyway, so the two match.

### Testing a kernel

`cargo test` cannot run kernel code directly, because the test runner itself
needs an operating system. The kernel is split so that most of it does not
need one:

- **Host tests.** Allocators, data structures, parsers for ELF files and file
  systems, and the scheduler's policy live in crates that also build for the
  host, and are tested there with plain `cargo test`.
- **QEMU tests.** Code that needs the hardware is tested by small test kernels.
  Each boots in QEMU, writes its results to the serial port, and ends by
  writing to QEMU's `isa-debug-exit` device, which closes QEMU with an exit
  code CI can read.

### POSIX compatibility

POSIX describes an operating system from a program's side: the C functions,
such as `open`, `read`, `fork` and `exec`, and how files, processes, signals
and permissions behave. It does not prescribe the system calls underneath, so
Anvil OS keeps its own system call interface and gets POSIX from a C library:

- **mlibc** implements the C and POSIX functions once, and reaches the kernel
  through a small layer of system-dependent functions that each operating
  system writes for itself. Managarm and other hobby systems use it in the
  same way.
- **An Anvil target for the compiler** lets GCC or Clang build programs for
  Anvil OS, linked against mlibc. With it, existing software, such as dash,
  core utilities and later the compiler itself, is ported by building it
  rather than rewriting it.

POSIX also shapes the kernel early. The process model needs `fork`, `exec`
and `wait`, every process needs a table of file descriptors that files, pipes
and devices share, and files need owners and permission bits, which rules out
FAT32 as the main file system. Programs written in Rust come later: Rust's
standard library needs a target for Anvil OS in the Rust compiler, built on
the same C library.

### A hybrid kernel

Kernels come in three designs:

- **Monolithic**, as in Linux: the scheduler, memory manager, file systems
  and drivers all run in kernel mode and call each other directly. The
  quickest to get working, but a bug in any driver can bring the whole system
  down.
- **Microkernel**, as in Redox, MINIX 3 and seL4: the kernel keeps only
  address spaces, threads and messages, and drivers and file systems run as
  user processes. A crashed driver can be restarted, but every request becomes
  messages between processes, which is slower and harder to get right.
- **Hybrid**, as in Windows and macOS: a kernel designed in layers like a
  microkernel, with most services moved back into kernel mode for speed.
  Windows NT's executive, its drivers and, since NT 4.0, even its window and
  graphics code run in kernel mode, while some drivers can run in user mode
  through the User-Mode Driver Framework.

Anvil OS is hybrid. macOS shows the combination works, since it is certified
POSIX on a hybrid kernel, XNU, which joins the Mach microkernel to BSD code
running in the same address space. For Anvil, hybrid means three rules from
the first milestone on:

- **Layers with narrow interfaces.** The architecture code, everything that
  knows it runs on x86-64, sits in one layer at the bottom, as Windows' hardware
  abstraction layer does. Memory management, scheduling, the virtual file
  system and the drivers each sit above it as separate crates that talk
  through defined interfaces, never through each other's internals.
- **Kernel mode by default.** Drivers and file systems run inside the kernel,
  so the first versions get a monolithic kernel's speed and simplicity.
- **User mode where it pays.** The kernel offers messages between processes
  and a way to map a device's memory into a process, so a driver whose crash
  should not take the system down, such as USB, can later run as a user
  process instead.

Rust helps keep the layers honest: each layer is its own crate, and a crate
can only use what another one makes public.

## Milestones

The roadmap above, broken into steps that each end with something that boots
and can be shown:

1. **Boot and print.** Limine loads the kernel, which writes text to the
   framebuffer and logs to the serial port, so QEMU's output appears in the
   terminal.
2. **Take over the processor.** The segment and interrupt descriptor tables,
   handlers for exceptions such as page faults, the local APIC timer, and the
   keyboard.
3. **Manage memory.** A physical frame allocator built from Limine's memory
   map, page tables the kernel controls, and a kernel heap, which unlocks
   Rust's `alloc` crate with `Box` and `Vec`.
4. **Run more than one thing.** Kernel threads, context switching and a
   round-robin scheduler driven by the timer; see
   [Processes and Threads]({{< ref "/fundamentals/processes-and-threads" >}}).
5. **Enter user mode.** Ring 3, system calls through `syscall` and `sysret`,
   an ELF loader, and processes with their own address spaces, created with
   `fork` and `exec` and collected with `wait`.
6. **Files.** A virtual file system with file descriptors, pipes and
   permissions, an initial RAM disk loaded by Limine, then a disk driver, such
   as virtio-blk in QEMU, and ext2, which has the owners and permissions POSIX
   expects.
7. **A POSIX user space.** mlibc ported to Anvil's system calls, a compiler
   target for Anvil OS, and the first ported programs: the dash shell and the
   basic commands to list, read and copy files.

Beyond that, the order is open: multiple processors, networking with virtio-net
and smoltcp, a Rust TCP/IP stack that runs without an OS, graphics and a window
system, and USB, which is the hardest driver of all and the first candidate to
run as a user-mode driver.

## References

| Resource | What it gives |
| --- | --- |
| OSDev wiki | The reference for nearly every piece of hardware and boot step |
| *Writing an OS in Rust*, by Philipp Oppermann | A kernel in Rust, built one post at a time |
| xv6 and its book, from MIT | A complete teaching kernel small enough to read in a week |
| *Operating Systems: Three Easy Pieces* | The theory behind processes, memory and file systems, free online |
| Intel and AMD architecture manuals | The final word on how an x86-64 processor behaves |
| Redox OS and SerenityOS | Two from-scratch operating systems that became usable |

## Decisions

The questions this brainstorm raised, and how they were settled:

- **Anvil OS is POSIX-compatible.** Existing programs are ported through a C
  library rather than rewritten.
- **The code is published under the author's own attribution licence.** Code
  ported from other projects, such as the C library and the programs in user
  space, keeps its own licence.
- **The working name is Anvil OS.** The first name, Craft OS, was dropped
  because CraftOS is already the operating system in ComputerCraft, the
  Minecraft mod.
- **The kernel is hybrid**, as in Windows and macOS, and POSIX-compatible, as
  macOS is.
