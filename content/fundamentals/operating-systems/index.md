---
title: "What Is an Operating System? History, Architectures and How It Works"
description: "An operating system is the software that turns bare hardware into a machine many programs can share safely. Here is what that means, how it evolved from batch monitors to phones and clouds, and how kernels are built and work on the inside."
date: 2026-10-20T09:00:00Z
categories: ["Fundamentals"]
tags: ["Operating Systems", "Kernels", "History", "Computer Science", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Every program you have ever written leaned on an operating system without
asking. Printing a line, opening a file, allocating memory, waiting for a key
press: none of these is something a processor knows how to do. The operating
system does them on the program's behalf, and does them for hundreds of other
programs at the same time without letting any of them trample the others.

[What Is Programming?]({{< ref "what-is-programming" >}}) followed the history
of telling machines what to do. This article follows the program that stands
between every other program and the machine: what it is, how it came to exist,
the main ways it can be built, and, in some detail, how it actually works.

## What an operating system is

**An operating system is the layer of software that manages a computer's
hardware and presents programs with a simpler, safer machine to run on.**

Andrew Tanenbaum describes this as two jobs that look different but are really
one.[^tanenbaum]

- **An extended machine.** Raw hardware is awkward to program. A disk is a
  grid of numbered blocks; a network card is a set of registers and ring
  buffers; memory is one flat array that everybody shares. The operating system
  replaces these with **abstractions**: files and directories instead of
  blocks, sockets instead of network registers, processes instead of a single
  processor, and a private address space for each program instead of shared
  physical memory.
- **A resource manager.** Several programs want the same processor, memory,
  disk and network at once. The operating system **multiplexes** them: in
  *time* (taking turns on the CPU or a printer) and in *space* (splitting memory
  and disk between them), while keeping each program from reading or damaging
  what belongs to another.

Remzi and Andrea Arpaci-Dusseau's textbook organises the subject around three
ideas that fall out of those two jobs: **virtualisation** (making one CPU and one
memory look like many), **concurrency** (coping with many things happening at
once) and **persistence** (keeping data safe when the power goes
off).[^ostep]

{{< diagram src="layers.svg" caption="Where the operating system sits. Everything above the system call interface runs in user mode with restricted privileges; the kernel below it runs in kernel mode with full control of the hardware." >}}

### Kernel, operating system and distribution

The words are often used loosely, so it is worth separating them:

| Term | What it is | Examples |
|---|---|---|
| **Kernel** | The core that runs in the processor's privileged mode, is always resident in memory and owns the hardware | Linux, the Windows NT kernel, XNU |
| **Operating system** | The kernel plus the system libraries, utilities, shell and services that programs and people rely on | GNU/Linux, Windows, macOS, Android |
| **Distribution or edition** | An operating system packaged with an installer, applications, defaults and an update channel | Ubuntu, Fedora, Debian; Windows 11 Pro |

Silberschatz, Galvin and Gagne call the kernel "the one program running at all
times on the computer".[^silberschatz] Everything else, including the shell you
type into and the window system you click on, is an ordinary program running
with ordinary privileges. That is why one kernel can sit under very different
systems: Linux runs both Ubuntu desktops and Android phones.

### What it is responsible for

| Area | What the OS does | The abstraction it gives programs |
|---|---|---|
| **Processes** | Creates, schedules and destroys running programs; switches the CPU between them | The process and the thread |
| **Memory** | Gives each process its own address space, maps it onto physical memory, moves pages to disk when memory runs short | The virtual address space |
| **Storage** | Organises raw blocks into named, protected, durable data | Files and directories |
| **Devices** | Drives disks, keyboards, displays, sensors and every other piece of hardware through device drivers | The device file, or a device-specific API |
| **Networking** | Implements protocols such as TCP/IP and shares network interfaces between programs | The socket |
| **Protection and security** | Separates users and programs, enforces permissions, isolates faults | Users, permissions, sandboxes |
| **Interface** | Lets people start programs and manage the system | The shell, the graphical desktop |

### Kinds of operating systems

The same ideas are tuned differently depending on what the machine is for:

| Kind | Optimised for | Examples |
|---|---|---|
| **Batch** | Throughput: running one job after another with no human waiting | IBM OS/360 in its early use, many mainframe workloads today |
| **Time-sharing / general-purpose** | Responsiveness for many interactive users and programs | Unix, Linux, Windows, macOS |
| **Real-time** | Predictability: meeting deadlines, measured in micro- or milliseconds, every time | QNX, VxWorks, FreeRTOS, Zephyr |
| **Embedded** | Small memory and power budgets, fixed hardware | FreeRTOS, embedded Linux |
| **Mobile** | Battery life, touch interfaces, sandboxed apps | Android, iOS |
| **Distributed and cloud** | Making many machines behave like one, or one machine like many | Kubernetes clusters, hypervisors |

A **hard** real-time system treats a missed deadline as a failure (an airbag
controller); a **soft** one treats it as degraded quality (a video call that
stutters).

## A history of operating systems

### The 1940s and early 1950s: no operating system at all

The first computers had no operating system; the programmer was the operating
system. You booked the machine for a block of time, carried your program to it
on punched cards or paper tape, loaded it by hand, ran it and debugged it from
the console switches. While you set up, the expensive machine sat idle. The
first operating-system-like code was the shared **loaders** and **subroutine
libraries** of machines such as EDSAC, which spared every programmer from
rewriting the same input and output routines.

### The mid-1950s: batch systems and resident monitors

The fix for idle time was to let the computer move from one job to the next by
itself. In 1956 General Motors and North American Aviation built **GM-NAA I/O**
for the IBM 704, generally counted as the first operating system.
A small **resident monitor** stayed in memory; operators collected jobs onto
magnetic tape in a **batch**; and the monitor read each job, ran it, and moved
on. Each job began with control cards telling the monitor what to do, the
ancestors of IBM's Job Control Language and of every shell script since.

Batching also exposed the first protection problem: a buggy job could overwrite
the monitor or never finish. Hardware began to grow the defences operating
systems still depend on: protected memory regions, privileged instructions and
timers that could take the processor back.

### The early 1960s: multiprogramming, interrupts and virtual memory

A processor running a batch job still spent most of its time waiting for slow
tapes and printers. Two hardware features changed that. **Interrupts** let a
device signal the processor when it had finished, and **I/O channels**
(the forerunners of DMA) moved data without the processor's help. Together they
made **multiprogramming** possible: keep several jobs in memory and, when one
waits for I/O, run another. **Spooling** (simultaneous peripheral operation
on-line) used the disk as a buffer so printing and card reading overlapped with
computation.

Two machines from this period introduced ideas that are now universal:

- The **Atlas** computer at the University of Manchester (1962) and its Atlas
  Supervisor introduced the **one-level store**: what programs saw as main
  memory was backed partly by a drum, and hardware plus software moved fixed-size
  *pages* between the two automatically.[^atlas] This was the first virtual
  memory.
- The **Burroughs B5000** (1961) ran its Master Control Program, written not in
  assembly but in a high-level language, ESPOL, and used segmented virtual
  memory.[^brinch2001]

### The 1960s: time-sharing

Batch processing meant waiting hours to learn that a program had a typo.
**Time-sharing** gave each user a terminal and cut the processor's time into
short slices handed out in turn, fast enough that everyone felt they had the
machine to themselves.

The **Compatible Time-Sharing System (CTSS)**, built at MIT by Fernando
Corbató's group and first demonstrated in 1961, showed it could
work.[^ctss] Its successor, **Multics** (1965, a joint project of MIT, General
Electric and Bell Labs), aimed to be a computing utility, as reliable as the
electricity supply.[^multics] Multics was only a modest commercial success, but
it introduced or refined an extraordinary number of lasting ideas: a
hierarchical file system, protection **rings**, dynamic linking, memory-mapped
files, and an operating system written mostly in a high-level language (PL/I).

At the same time IBM announced **OS/360** (1964), one operating system for an
entire family of compatible machines. It worked, but late and at great cost;
Fred Brooks, who managed the project, distilled the lessons into *The Mythical
Man-Month*.[^brooks] IBM's virtual machine work took a different path:
rather than share one operating system, it gave each user a *virtual copy of
the hardware*. The CP-40 research system came first; its successor **CP-67/CMS**
(1967–68) was the first widely available **virtual machine** system and led to
VM/370 in 1972.

### Structure becomes a research subject

As systems grew, people began to ask how they should be organised. In 1968
Edsger Dijkstra described the **THE** multiprogramming system as a stack of
layers, each using only the services of the layers below it, and used
**semaphores**, which he had introduced a few years earlier, to coordinate its
concurrent parts.[^the][^ewd123] In 1969 Per Brinch Hansen's **RC 4000** system
went further: a small **nucleus** that provided only processes and message
passing, on top of which different operating systems could be built.[^rc4000]
That is the ancestor of the microkernel.

### 1969 to the 1980s: Unix

After Bell Labs withdrew from Multics in 1969, Ken Thompson and Dennis Ritchie
began a much smaller system on a spare PDP-7. **Unix** kept the best Multics
ideas and dropped most of the complexity.[^unix74][^ritchie84] Its design rested
on a handful of simple, powerful choices:

- a single hierarchical file system, in which devices also appear as files;
- processes created by `fork` and given a new program by `exec`;
- a shell that is just an ordinary user program;
- **pipes** (1972, added at Doug McIlroy's urging), so small programs can be
  composed.

In 1973 the kernel was rewritten in C, which made Unix portable to new hardware
in a way that assembly-language systems were not. Because a 1956 antitrust
consent decree kept AT&T out of the computer business, Unix was licensed
cheaply to universities. The University of California, Berkeley, produced the
**Berkeley Software Distribution (BSD)**, which added paged virtual memory and,
in 4.2BSD (1983), the TCP/IP networking and socket interface the internet was
built on. Commercial Unixes multiplied, and the **POSIX** standard (IEEE
1003.1, 1988) fixed a common programming interface that Linux, macOS and others
still follow.

### Personal computers

Microcomputers started over, single-user and without memory protection.
**CP/M** (1974) by Gary Kildall separated the hardware-specific code into a
BIOS so that one operating system could run on many machines. **MS-DOS** (1981)
shipped with the IBM PC and dominated the decade. Graphical interfaces came from
Xerox PARC's **Alto** (1973) and reached the market with the Apple Lisa (1983),
the Macintosh (1984) and Windows 1.0 (1985), which ran on top of DOS.

These systems had to relearn the mainframe lessons. A crashing program could
take down the whole machine, because nothing stopped it from writing over the
operating system, and multitasking was **cooperative**: a program had to give
up the processor voluntarily. Mainstream personal computers got full memory
protection and **preemptive** multitasking with **Windows NT** (1993), designed
by a team led by Dave Cutler, who had earlier built DEC's VMS,[^custer] and
reaching home users with Windows XP (2001), and with **Mac OS X** (2001).

### Microkernels, GNU and Linux

The 1980s also brought a revival of the small-nucleus idea. **Mach** (Carnegie
Mellon, from 1985) moved much of Unix out of the kernel into user-space
servers.[^mach] **QNX** (1982) made a commercial success of a real-time
microkernel, and Andrew Tanenbaum's **MINIX** (1987) was written to teach
operating systems with readable source code.

Meanwhile, in 1983, Richard Stallman announced the **GNU** project to build a
completely free Unix-like system.[^gnu] By the early 1990s it had a compiler, a
shell, an editor and libraries, but no finished kernel. In August 1991 a
Finnish student, **Linus Torvalds**, posted to the MINIX newsgroup that he was
writing a free operating system, "just a hobby".[^torvalds] **Linux** was a
monolithic kernel, which led Tanenbaum to declare in January 1992 that it was
"obsolete"; the long public argument that followed is still the classic
statement of the monolithic-versus-microkernel debate.[^debate] Linux combined
with the GNU tools made a free, complete system, and today Linux runs most
servers on the internet, every machine on the TOP500 list of supercomputers
since 2017,[^top500] and, as the kernel of Android, most of the world's phones.

Microkernel research continued. Jochen Liedtke's **L4** showed in the 1990s
that the message passing microkernels depend on could be made fast,[^l4] and
in 2009 **seL4**, a member of the L4 family, became the first general-purpose
operating system kernel with a machine-checked proof that its code matches its
specification.[^sel4]

### Mobile, virtualisation and the cloud

Apple's **Mac OS X** (2001) grew out of NeXTSTEP (1989) and is built on
**XNU**, a kernel that joins Mach with large parts of BSD.[^singh] The same
core went into the iPhone in 2007; Google's **Android** (2008) built a mobile
system on the Linux kernel. Phones pushed operating systems to treat every app
as untrusted: each runs in its own sandbox with explicit permissions, and power
management became as important as raw speed.

Virtualisation returned from the mainframe world. Gerald Popek and Robert
Goldberg had set out in 1974 the conditions a processor must meet to be
virtualised efficiently,[^popek] and the x86 architecture did not meet them.
**VMware** (1999) worked around this by rewriting privileged instructions on
the fly; **Xen** (2003) modified the guest kernels instead (paravirtualisation);
[^xen] and from 2005 Intel's VT-x and AMD's AMD-V added hardware support,
which Linux's **KVM** (2007) used to turn the kernel itself into a hypervisor.

A lighter form of isolation grew alongside: `chroot` (1979), FreeBSD **jails**
(2000), Solaris **Zones** (2004) and Linux **namespaces** and **control
groups** (cgroups, merged in 2008). **Docker** (2013) packaged them into
**containers** that start in milliseconds, and orchestration systems such as
Kubernetes (2014) now schedule containers across whole data centres, which is
an operating system's job at a larger scale.

## A timeline at a glance

| Year | Milestone |
|---|---|
| 1956 | GM-NAA I/O, the first batch operating system, for the IBM 704 |
| 1961 | CTSS demonstrated at MIT; Burroughs B5000 and its MCP |
| 1962 | Atlas Supervisor introduces paged virtual memory |
| 1964 | IBM announces OS/360 |
| 1965 | Multics project begins |
| 1967 | IBM CP-40 and CP-67: virtual machines |
| 1968 | Dijkstra's layered THE system |
| 1969 | RC 4000 nucleus; Unix begins on a PDP-7 |
| 1972 | Pipes added to Unix |
| 1973 | Unix rewritten in C |
| 1974 | CP/M; Popek and Goldberg's virtualisation requirements |
| 1981 | MS-DOS |
| 1983 | 4.2BSD with TCP/IP; GNU project announced |
| 1984 | Apple Macintosh |
| 1985 | Mach; Windows 1.0 |
| 1987 | MINIX |
| 1988 | POSIX standard |
| 1991 | Linux |
| 1993 | Windows NT 3.1 |
| 2001 | Mac OS X; Windows XP |
| 2003 | Xen |
| 2007 | iPhone; KVM merged into Linux |
| 2008 | Android; Linux cgroups |
| 2009 | seL4 formally verified |
| 2013 | Docker |

## The hardware the operating system stands on

An operating system cannot enforce anything by software alone: a program runs
directly on the processor, and nothing in software can stop it executing the
next instruction. Protection depends on a few hardware features, which is why
early PCs, built without them, were so fragile.

| Feature | What it does | Why the OS needs it |
|---|---|---|
| **Privilege modes** | The CPU runs either in *kernel* (supervisor) mode, where every instruction is allowed, or in *user* mode, where privileged instructions trap | Stops programs from reprogramming devices, disabling interrupts or changing memory maps |
| **Memory management unit (MMU)** | Translates every address a program uses and checks its permissions | Gives each process its own address space and protects the kernel's memory |
| **Interrupts and exceptions** | Let devices, errors and programs transfer control to kernel code at fixed entry points | The only safe ways into the kernel |
| **Timer** | Interrupts the CPU at regular intervals | Takes the processor back from a program that never yields; makes preemptive scheduling possible |
| **DMA** | Lets devices copy data to and from memory without the CPU | Frees the processor to run other work during I/O |

Processor families name their privilege levels differently. x86 has four
**rings**, of which mainstream systems use two: ring 0 for the kernel and ring 3
for applications. ARM defines **exception levels**, typically used as EL0 for
applications, EL1 for the kernel, EL2 for a hypervisor and EL3 for secure
firmware. RISC-V has
user, supervisor and machine modes. The idea is the same in all of them.

## Kernel architectures

The central design decision in an operating system is **how much of it runs in
kernel mode**. Code in the kernel is fast, because it can call other kernel code
directly, but any bug in it can corrupt or crash the whole system. Code in user
mode is isolated, but every interaction with the rest of the system costs a
crossing between modes.

{{< diagram src="kernel-architectures.svg" caption="Three common kernel designs. The dashed line separates user mode (above) from kernel mode (below); accent outlines mark operating system services such as file systems and drivers." >}}

### Monolithic kernels

In a **monolithic kernel** the entire operating system, including the
scheduler, memory manager, file systems, network stack and device drivers,
runs as one program in kernel mode, sharing one address space. A request from
an application enters through the system call interface and is handled by
ordinary function calls between kernel subsystems.

Classic Unix, the BSDs and Linux are monolithic. Modern monolithic kernels are
not unstructured: Linux is divided into well-defined subsystems and can load
and unload **kernel modules** (drivers and file systems, for example) while it
runs. But a module, once loaded, runs with full privilege like the rest of the
kernel.

- **Strengths:** speed, because subsystems talk by function call; and a long
  record of practical success.
- **Weaknesses:** a bug in any driver can bring down the machine or open a
  security hole, and the amount of privileged code is enormous (the Linux
  source tree runs to tens of millions of lines, most of them drivers).

### Layered systems

A **layered** system organises the kernel as a stack in which each layer uses
only the services of the layers beneath it. Dijkstra's THE system had six:[^the]

| Layer | Responsibility |
|---|---|
| 5 | The operator |
| 4 | User programs |
| 3 | Input/output buffering |
| 2 | Communication with the operator's console |
| 1 | Memory management (moving pages between core and drum) |
| 0 | Processor allocation and multiprogramming |

Strict layering makes a system easy to reason about and to test one layer at a
time, but real subsystems rarely fit a single order. The memory manager needs
the disk driver, while the disk driver needs memory, and every call that passes
through several layers pays for each. Pure layering is now rare, but the idea
survives inside most designs, such as the layers of a network stack.

### Microkernels

A **microkernel** keeps only the mechanisms that truly need privilege in kernel
mode: usually address spaces, threads, scheduling, interrupt delivery and
**inter-process communication (IPC)**. Everything else, including file systems,
device drivers and network protocols, runs as separate user-mode **servers**.
To read a file, an application sends a message to the file server; the file
server may in turn send a message to the disk driver; the kernel only carries
the messages.

- **Strengths:** a crashed driver is just a crashed process and can be
  restarted; the trusted code is small enough to audit, or even, as with seL4,
  to prove correct; servers can be replaced or updated independently.
- **Weaknesses:** every service request costs several mode switches and
  context switches. Early microkernels such as Mach were noticeably slower than
  monolithic Unix, which hurt their reputation, until L4 showed that careful
  design could make IPC cheap.[^l4]

Microkernels are common where reliability matters most: QNX runs in cars and
industrial controllers, the seL4 family in security-critical systems, and a
modified MINIX 3 runs inside Intel's Management Engine firmware (ME 11 onward).

### Hybrid kernels

A **hybrid** kernel starts from a microkernel-style structure but keeps most
services in kernel mode for speed. **Windows NT** has a small kernel layer for
scheduling, interrupts and synchronisation, a hardware abstraction layer (HAL)
beneath it, and an "executive" of managers for memory, I/O, processes and
security above it, all in kernel mode.[^custer] **XNU** in macOS and iOS
combines Mach (for tasks, threads, IPC and virtual memory) with a BSD layer (for
processes, POSIX system calls, file systems and networking) and IOKit for
drivers, in one kernel address space.[^singh]

Critics point out that a hybrid is, in terms of what runs privileged, a
monolithic kernel with a microkernel's internal organisation. The label is
useful mainly as a description of that organisation.

### Exokernels, library operating systems and unikernels

Some designs go further than microkernels. An **exokernel** (MIT, 1995)
securely multiplexes the hardware but provides almost no abstractions at all,
leaving applications to link a **library operating system** that implements
the abstractions they want.[^exokernel] A **unikernel** compiles one
application and just the operating system code it needs into a single image
that runs directly on a hypervisor, small and fast to boot, though with only
one program to run.[^unikernel]

### Comparing the designs

| Design | Runs in kernel mode | Typical strength | Typical weakness | Examples |
|---|---|---|---|---|
| **Monolithic** | Everything | Performance | A faulty driver can crash or compromise everything | Linux, FreeBSD, classic Unix |
| **Layered** | Everything, in ordered layers | Clarity, testability | Rigid ordering; overhead between layers | THE |
| **Microkernel** | IPC, threads, address spaces | Reliability, small trusted base | IPC overhead | QNX, MINIX 3, seL4 |
| **Hybrid** | Most services, around a small core | Performance with internal structure | Privileged code still large | Windows NT, XNU |
| **Exokernel / unikernel** | Minimal multiplexing | Application control, speed | Less isolation, specialised use | MIT Exokernel, MirageOS |

### Virtual machines and containers

Virtualisation applies the operating system's trick, giving each program the
illusion of its own machine, to operating systems themselves. A **hypervisor**
(or virtual machine monitor) runs several **guest** operating systems, each in
its own virtual machine with virtual processors, memory and devices.

{{< diagram src="virtualization.svg" caption="Type 1 and type 2 hypervisors give every workload its own guest kernel; containers share the host's kernel and are isolated by it." >}}

- A **type 1** (bare-metal) hypervisor runs directly on the hardware: Xen,
  Microsoft Hyper-V, VMware ESXi. KVM is usually counted as type 1 too, since
  it makes the Linux kernel itself the hypervisor.
- A **type 2** (hosted) hypervisor runs on top of a normal operating system:
  VirtualBox, VMware Workstation.
- **Containers** are not virtual machines. All containers on a host share its
  kernel; the kernel gives each one its own view of process IDs, file systems,
  network interfaces and users (**namespaces**) and its own limits on CPU,
  memory and I/O (**cgroups**). They are lighter and faster to start than
  virtual machines, but a kernel vulnerability can affect all of them.

## How an operating system works

### Booting

When a computer is switched on, memory is empty and the processor starts
executing at a fixed address in firmware. Starting the operating system is a
chain in which each stage loads a slightly larger and more capable next stage.

{{< diagram src="boot.svg" caption="The boot chain on a typical PC. Steps 1 to 3 run before any user program exists; from step 4 on, everything runs in user mode." >}}

1. **Firmware.** UEFI, or on older PCs the BIOS, runs a power-on self test,
   initialises the memory controller and basic devices, and finds a boot
   device. UEFI reads a boot loader from a FAT-formatted EFI system partition;
   with **Secure Boot**, it checks the loader's cryptographic signature first.
2. **Boot loader.** GRUB, systemd-boot or the Windows Boot Manager lets you pick
   a system, then loads the kernel image (and usually an initial RAM disk of
   early drivers) into memory and jumps to it.
3. **Kernel initialisation.** The kernel sets up its own page tables and
   switches the MMU on, installs the interrupt and exception handlers, starts the
   other processor cores, initialises the scheduler, probes devices and loads
   their drivers, and mounts the root file system.
4. **The first process.** The kernel starts the first program in user mode.
   On Unix-like systems this is process number 1, **init**: systemd on most
   Linux distributions, launchd on macOS. Every later process descends from it.
   Windows has no PID 1 in the same sense; its kernel starts the Session
   Manager (`smss.exe`), which, through a copy of itself for session 0, starts
   `wininit.exe`, which in turn starts the service control manager
   (`services.exe`).
5. **Services.** Init starts the system's background services, such as logging,
   networking, device management and scheduled jobs, ordered by their
   dependencies.
6. **Login.** A login manager or text prompt starts, and when you sign in it
   creates your session and shell.

### System calls

A program in user mode cannot touch the hardware, so it asks the kernel. A
**system call** is that request: a controlled transfer into kernel code at an
entry point the kernel chose in advance. The mechanism is the same everywhere
in outline:

{{< diagram src="syscall.svg" caption="A write system call on x86-64 Linux. Steps 1 and 2 run in user mode; the syscall instruction in step 2 raises the privilege level and jumps to the kernel's entry point, and sysret in step 6 lowers it again." >}}

1. The program calls a library function, such as `write` in the C library.
2. The library puts the **system call number** and the arguments where the
   kernel expects them (on x86-64 Linux, the number in `rax` and up to six
   arguments in `rdi`, `rsi`, `rdx`, `r10`, `r8` and `r9`) and executes a
   special instruction: `syscall` on x86-64, `svc` on ARM, `ecall` on
   RISC-V.[^syscall2]
3. The processor switches to kernel mode and jumps to the kernel's entry
   routine, which saves the program's registers and switches to a kernel stack.
4. The kernel uses the number as an index into its **system call table** to
   find the handler.
5. The handler validates every argument (a pointer from user space might point
   into the kernel, or nowhere) and does the work.
6. The kernel places the result in a register, restores the program's state and
   returns to user mode.

The C library hides all of this, but you can make the request directly. This
x86-64 Linux program writes three bytes and exits without using any library at
all:

```asm
# hello.s: build with  as hello.s -o hello.o && ld hello.o -o hello
.globl _start
.text
_start:
    mov  $1, %rax           # system call 1 is write
    mov  $1, %rdi           # argument 1: file descriptor 1, standard output
    lea  msg(%rip), %rsi    # argument 2: address of the bytes
    mov  $3, %rdx           # argument 3: how many bytes
    syscall                 # enter the kernel; the result comes back in rax

    mov  $60, %rax          # system call 60 is exit
    xor  %rdi, %rdi         # argument 1: exit status 0
    syscall

.data
msg: .ascii "hi\n"
```

System call numbers differ between operating systems and even between
processor architectures on the same system, and Windows does not document its
numbers at all and they change between builds, which is one reason programs go
through libraries such as libc or the Windows API rather than issuing system
calls themselves. Linux on x86-64 has close to 400 system calls today, covering processes (`fork`,
`execve`, `exit`, `wait4`), files (`openat`, `read`, `write`, `close`), memory
(`mmap`, `brk`), communication (`pipe`, `socket`, `connect`) and more.

### Interrupts, exceptions and traps

System calls are one of three ways control enters the kernel:

| Kind | Caused by | Timing | Examples |
|---|---|---|---|
| **Interrupt** | A device outside the CPU | Asynchronous: at any moment | A key press, a network packet arriving, a disk finishing a transfer, the timer |
| **Exception (fault)** | The instruction being executed | Synchronous | Dividing by zero, touching an unmapped page, executing a privileged instruction |
| **Trap** | A deliberate instruction | Synchronous | `syscall`, `svc`, a debugger breakpoint |

The processor finds the handler through a table the kernel sets up at boot,
the **interrupt descriptor table** on x86 or the **exception vector table** on
ARM, so that control only ever enters the kernel at addresses the kernel chose.
Interrupt handlers must be quick, because other interrupts may wait while they
run, so kernels split the work: a short **top half** acknowledges the device and
records what happened, and a deferred **bottom half** (softirqs, tasklets and
work queues on Linux; deferred procedure calls on Windows) does the rest later.

The **timer interrupt** deserves special mention. It fires many times a second,
and each time the kernel can decide whether the running program has used up its
turn. It is what makes multitasking **preemptive**: without it, a program in an
infinite loop would keep the processor forever.

### Processes and threads

A **process** is a program in execution. The program on disk is just a file of
instructions; the process is that program plus everything needed to run it:

- an **address space** holding its code, data, heap and stack;
- the **CPU state**: the program counter, stack pointer and other registers;
- **resources** such as open files, network connections and memory mappings;
- **identity and accounting**: process ID, parent, user, priority, CPU time used.

The kernel keeps all of this in a **process control block** (in Linux, a
`task_struct`). A **thread** is a separate flow of execution *inside* a process,
with its own registers and stack but sharing the address space and open files
of the other threads in that process. Threads are cheaper than processes and
communicate through shared memory, which is also what makes them hard to use
correctly.

A process moves between a handful of states during its life:

{{< diagram src="process-states.svg" caption="The five-state process model. Only one process per CPU core can be Running; the scheduler chooses which Ready process that is." >}}

On Unix-like systems a new process is created by **forking**, which duplicates
the calling process, and the copy then **execs**, replacing its program with a
new one. Separating the two steps is what lets a shell set up redirections and
pipes in the child before the new program starts:

```c
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void) {
    pid_t pid = fork();                  /* one process goes in, two come out */

    if (pid == 0) {                      /* in the child */
        execlp("ls", "ls", "-l", (char *)NULL);
        perror("execlp");                /* reached only if exec failed */
        return 1;
    }

    int status;
    waitpid(pid, &status, 0);            /* in the parent: wait for the child */
    printf("child %d exited with status %d\n", (int)pid, WEXITSTATUS(status));
    return 0;
}
```

Windows takes a single step instead: `CreateProcess` creates a process and
loads its program at once.

To switch the CPU from one thread to another, the kernel performs a **context
switch**: it saves the registers of the current thread in its control block,
picks the next thread, restores that thread's registers and, if it belongs to a
different process, switches the MMU to that process's page tables. A context
switch takes on the order of microseconds, and its hidden cost, the cold caches
and translation buffers it leaves behind, is often larger than the switch
itself.

### CPU scheduling

With more runnable threads than processor cores, the **scheduler** decides who
runs next and for how long. It balances goals that pull against each other:
throughput (work done per second), turnaround time (how long a job takes from
start to finish), response time (how quickly an interactive program reacts),
fairness, and, on phones and laptops, energy.

| Algorithm | How it chooses | Strength | Weakness |
|---|---|---|---|
| **First come, first served** | In order of arrival, each runs until it blocks | Simple | Short jobs wait behind long ones (the convoy effect) |
| **Shortest job first** | The job with the shortest next CPU burst | Minimises average waiting time | Needs to predict the future; long jobs can starve |
| **Round robin** | Each in turn, for a fixed time slice (quantum) | Fair and responsive | A slice too short wastes time switching; too long feels sluggish |
| **Priority** | Highest priority first | Expresses importance | Low priorities can starve unless they age upwards |
| **Multilevel feedback queue** | Several priority queues; a job that uses its whole slice moves down | Favours interactive jobs without knowing in advance which they are | Many parameters to tune |
| **Fair share** | The thread that has had least CPU relative to its share | Proportional fairness under load | Bookkeeping cost |

Real schedulers combine these. CTSS already used a multilevel feedback
queue,[^ctss] and Windows still schedules by 32 priority levels with
preemption and temporary priority boosts for threads that have just finished
waiting. Linux's **Completely Fair Scheduler** (2007) gave each thread a
*virtual runtime* that grows as it runs, weighted by priority, and always ran
the thread with the least, kept in a red-black tree.[^love] In Linux 6.6 (2023)
it was replaced by **EEVDF** (earliest eligible virtual deadline first). EEVDF
tracks each task's *lag*, how much CPU time it is owed, and runs the eligible
task with the earliest virtual deadline. Because the deadline depends on the
task's time slice, tasks with shorter slices run sooner, and newer kernels let
a latency-sensitive task ask for a shorter slice.[^eevdf] Real-time threads sit above all of this in strict priority
classes, because for them predictability matters more than fairness.

### Concurrency and synchronisation

Whenever two threads share data, or one thread shares data with an interrupt
handler, the order in which their instructions interleave can change the
result. This is a **race condition**. Even `counter++` is three steps (load,
add, store), and two threads can both load the old value before either stores
the new one:

```c
#include <pthread.h>
#include <stdio.h>

static long counter = 0;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

static void *work(void *arg) {
    (void)arg;
    for (int i = 0; i < 1000000; i++) {
        pthread_mutex_lock(&lock);    /* without the lock, the final */
        counter++;                    /* total usually comes out short */
        pthread_mutex_unlock(&lock);
    }
    return NULL;
}

int main(void) {
    pthread_t a, b;
    pthread_create(&a, NULL, work, NULL);
    pthread_create(&b, NULL, work, NULL);
    pthread_join(a, NULL);
    pthread_join(b, NULL);
    printf("%ld\n", counter);         /* 2000000 */
    return 0;
}
```

The code that touches shared data is a **critical section**, and the operating
system supplies the tools to make sure only one thread is inside it at a time.
They are all built on atomic instructions provided by the hardware, such as
compare-and-swap:

- **Spinlocks** busy-wait until the lock is free. They suit very short critical
  sections inside the kernel, especially where sleeping is not allowed.
- **Mutexes** put a waiting thread to sleep and wake it when the lock is
  released.
- **Semaphores**, introduced by Dijkstra, are counters with atomic wait and
  signal operations, able to admit up to *n* threads at once.[^ewd123]
- **Condition variables** let a thread sleep until some condition becomes true,
  such as a queue becoming non-empty.

Locks bring their own failure. A **deadlock** happens when threads wait for each
other in a cycle, each holding something another needs. Coffman, Elphick and
Shoshani showed that it requires four conditions at once: *mutual exclusion*,
*hold and wait*, *no preemption* and *circular wait*.[^coffman] Breaking any one
prevents it; the most common practical rule is to always acquire locks in the
same global order, which removes circular wait.

### Memory management

Each process sees a large, private **virtual address space**. On x86-64 Linux a
process's space is laid out roughly like this, from high addresses to low:

```txt
high addresses ┌───────────────────────┐
               │ kernel (inaccessible) │
               ├───────────────────────┤
               │ stack                 │  grows down
               │           ↓           │
               │                       │
               │ memory mappings       │  shared libraries, mmap'd files
               │                       │
               │           ↑           │
               │ heap                  │  grows up (malloc)
               ├───────────────────────┤
               │ data and bss          │  global variables
               ├───────────────────────┤
               │ text                  │  machine code, read-only
low addresses  └───────────────────────┘
```

None of these addresses is a real location in memory. The MMU translates each
**virtual address** to a **physical address** on every single access, using
**page tables** that the kernel maintains for each process. Memory is divided
into fixed-size **pages** (usually 4 KiB), and each page of virtual memory can
be mapped to any **frame** of physical memory, or to none at all.

{{< diagram src="paging.svg" caption="Translating a virtual address. The page number is translated; the offset within the page passes through unchanged." >}}

Walking page tables in memory for every access would be far too slow, so the MMU
caches recent translations in a **translation lookaside buffer (TLB)**. Most
accesses hit in the TLB. On a miss, the hardware walks the page tables and
fills the TLB. Because a flat table for a 48-bit address space would be huge,
the tables are a tree. On x86-64 with 4 KiB pages, a virtual address is split
like this:[^intel]

| Bits | 47–39 | 38–30 | 29–21 | 20–12 | 11–0 |
|---|---|---|---|---|---|
| **Selects** | Entry in the level-4 table (PML4) | Entry in the page-directory-pointer table | Entry in the page directory | Entry in the page table | Byte within the 4 KiB page |

Each table is itself one 4 KiB page holding 512 eight-byte entries, so nine
bits select an entry at each level. Only the parts of the tree a process uses
need to exist. Each entry also carries permission bits (present, writable,
user-accessible, no-execute), which is how the kernel protects its own memory
and keeps code from being overwritten. Newer processors add a fifth level for
57-bit addresses, and **huge pages** of 2 MiB or 1 GiB cut the number of TLB
entries large programs need.

If a translation finds no valid entry, the processor raises a **page fault**
and the kernel decides what it means:

- The page is part of the process but has not been loaded yet (**demand
  paging**): the kernel reads it from the program file or swap space, maps it
  and resumes the instruction. Programs start fast because pages are loaded only
  when first touched.
- The page is shared **copy-on-write**: after `fork`, parent and child share
  every page read-only, and the kernel copies a page only when one of them
  writes to it. This is why `fork` is cheap even for a large process.
- The address is invalid: the kernel sends a segmentation fault and usually
  ends the process.

When physical memory runs out, the kernel must evict pages, writing modified
ones to **swap space** first. The ideal victim is the page that will not be used
for the longest time (Belady's optimal algorithm), but that requires knowing the
future.[^belady] Real kernels approximate **least recently used (LRU)** with the
**clock** algorithm and its descendants, using the *accessed* bit the MMU sets in
each page-table entry. If the pages a set of processes actively uses (their
**working set**, in Peter Denning's term)[^denning] no longer fit in memory, the system
spends its time moving pages instead of computing. That collapse is called
**thrashing**.[^thrashing]

### Files and storage

A **file** is a named sequence of bytes that outlives the process that made it.
A **file system** turns a disk's numbered blocks into files and directories,
and has to keep them consistent even if the power fails mid-write.

In Unix-style file systems each file is described by an **inode**, which records
its size, owner, permissions, timestamps and the locations of its data blocks. A
**directory** is a special file that maps names to inode numbers. Because a name
is only a pointer to an inode, one file can have several names (**hard
links**), and deleting a name frees the file only when no names and no open
descriptors are left.

When a process opens a file, the kernel returns a small integer, the **file
descriptor**, which indexes a per-process table of open files. Every later
`read` and `write` names the descriptor, not the path. Descriptors 0, 1 and 2
are standard input, output and error, which is why the assembly program above
wrote to descriptor 1.

{{< diagram src="io-stack.svg" caption="The path of a read through the Linux storage stack. Most reads of recently used data stop at the page cache and never reach the disk." >}}

The **virtual file system (VFS)** layer gives every file system the same
interface, so the same `read` works on ext4, NTFS, a USB stick formatted as
FAT, a network share or `/proc`, a file system that does not exist on any disk
but describes the running kernel. The **page cache** keeps recently used file
data in otherwise free memory, which is why the second time you open a large
file it loads almost instantly. Writes usually land in the cache and reach the
disk later, unless a program asks for durability with `fsync`.

To survive crashes, modern file systems use one of two techniques:

- **Journaling** (ext4, NTFS, XFS): describe each change in a log first, then
  apply it. After a crash, replaying the log brings the file system back to a
  consistent state in seconds instead of a full scan.
- **Copy-on-write** (ZFS, Btrfs, APFS): never overwrite live data; write new
  blocks elsewhere and switch a pointer atomically. This also makes snapshots
  almost free.

### Devices and I/O

Every device is driven by a **device driver**, kernel code (or, in a
microkernel, a user-mode server) that knows that device's registers and
protocol and exposes a standard interface to the rest of the kernel. Drivers
are most of the code in any general-purpose kernel, and historically the
source of most of its crashes.

The CPU and a device can coordinate in three ways:

1. **Polling**: the CPU repeatedly reads a status register until the device is
   ready. Simple, and fastest for very quick devices, but it wastes the
   processor otherwise.
2. **Interrupts**: the CPU starts the operation and does other work; the device
   interrupts when it has finished.
3. **Direct memory access (DMA)**: the driver tells the device where in memory
   to read or write, the device moves the whole block itself, and it interrupts
   once at the end.

Unix carries its device model through to user space: devices appear as files
under `/dev`, so the same `open`, `read` and `write` work on a terminal, a disk
or a random-number generator, and the device-specific remainder goes through a
catch-all call, `ioctl`.

### Protection and security

Protection is the set of mechanisms that keep processes and users from
interfering with one another; security is using them to withstand someone
trying. The operating system provides several layers:

- **Isolation by hardware**: user and kernel mode, and separate address
  spaces, are the foundation everything else rests on.
- **Users and permissions**: every process runs as a user, and every file
  records who may read, write or execute it. Unix uses owner, group and other
  permission bits, with **access control lists** for finer control; Windows uses
  access control lists throughout.
- **Least privilege**: rather than one all-powerful administrator, systems split
  privilege into pieces, such as Linux **capabilities** or Windows privileges,
  so a program gets only what it needs.
- **Mandatory access control**: policies that even a file's owner cannot
  override, such as SELinux and AppArmor on Linux.
- **Hardening against exploits**: non-executable memory, **address space layout
  randomisation (ASLR)**, which places code and data at unpredictable addresses,
  and stack canaries make bugs much harder to turn into attacks.
- **Sandboxing**: limiting what a process may do at all, such as which system
  calls it may make (Linux's seccomp) or which files it may see. Every phone app
  and every browser tab runs this way.
- **A trusted boot chain**: Secure Boot and measured boot check that the
  firmware, boot loader and kernel have not been tampered with before they run.

### Networking

To programs, the network is another set of system calls. The **socket**
interface from 4.2BSD, with `socket`, `bind`, `listen`, `accept`, `connect`,
`send` and `recv`, is now used by nearly every operating system. Behind it, the
kernel implements the protocol stack: it splits data into TCP segments and IP
packets, handles acknowledgements, retransmission and congestion control, and
hands frames to the network card's driver. Waiting efficiently on thousands of
connections at once is itself an operating system feature, through `epoll` on
Linux, `kqueue` on the BSDs and macOS, I/O completion ports on Windows, and more
recently Linux's `io_uring`.

## Putting it together: what happens when you run `cat notes.txt`

Following one ordinary command shows almost every part of the system at work.

1. **Typing.** Each key press raises an interrupt. The keyboard driver reads
   the key code and passes it up through the terminal layer, which wakes the
   shell from its `read` on standard input.
2. **Creating a process.** The shell calls `fork`. The kernel creates a new
   process control block and a copy-on-write copy of the shell's address space,
   and the scheduler now has one more thread to run.
3. **Loading the program.** The child calls `execve("/usr/bin/cat", …)`. The
   kernel looks up the path through the VFS, checks execute permission, throws
   away the child's old address space and maps the `cat` executable and its
   dynamic linker in its place. Almost nothing is read from disk yet: demand
   paging will bring pages in as they are touched.
4. **Starting.** The first instructions page-fault; the kernel finds the pages,
   usually already in the page cache, maps them and resumes. The dynamic linker
   maps the C library, and `main` runs.
5. **Reading the file.** `cat` opens the file and reads it. Run under `strace`,
   the core of what it asks the kernel for looks like this (abridged; the exact
   calls vary by system, and coreutils before 9.5 read 128 KiB at a time
   rather than 256 KiB):

   ```txt
   openat(AT_FDCWD, "notes.txt", O_RDONLY) = 3
   read(3, "buy milk\n", 262144)           = 9
   write(1, "buy milk\n", 9)               = 9
   read(3, "", 262144)                     = 0
   close(3)                                = 0
   exit_group(0)                           = ?
   ```

   If the file is not in the page cache, the `read` goes down the storage stack
   to the disk driver, and the process sleeps in the Waiting state while the
   scheduler runs something else, until the disk's interrupt wakes it.
6. **Writing the output.** The `write` to descriptor 1 goes to the terminal
   driver, which passes the bytes to the terminal emulator to draw.
7. **Exiting.** `exit_group` releases the process's memory and closes its files.
   The kernel keeps a small record (a "zombie") until the parent collects the
   exit status, and the shell's `wait` returns so it can print the next prompt.

All of that, involving interrupts, two processes, a dozen system calls, page
faults, the scheduler, the VFS, the page cache and two drivers, typically
finishes in a few milliseconds.

## Why it matters

The operating system is the most successful abstraction in computing. It lets
a program written today assume it has a processor and a memory of its own, that
files are named streams of bytes that survive a power cut, and that another
program cannot read its secrets, none of which is true of the hardware. Each of
those assumptions was hard won: from monitors that could load the next job, to
time-sharing, to protected memory on personal computers, to sandboxes on
phones.

Knowing how the illusion is maintained explains a great deal of what programs
experience: why the first run of something is slower than the second, why
threads need locks, why a process can be killed for using too much memory, why
system calls are worth batching, and why a single bad driver can bring a whole
machine down.

## References

[^tanenbaum]: Tanenbaum, A. S., & Bos, H. (2015). *Modern Operating Systems* (4th ed.). Pearson. Chapter 1.

[^ostep]: Arpaci-Dusseau, R. H., & Arpaci-Dusseau, A. C. (2018). *Operating Systems: Three Easy Pieces* (Version 1.00). Arpaci-Dusseau Books. <https://pages.cs.wisc.edu/~remzi/OSTEP/>

[^silberschatz]: Silberschatz, A., Galvin, P. B., & Gagne, G. (2018). *Operating System Concepts* (10th ed.). Wiley. Chapter 1.

[^brinch2001]: Brinch Hansen, P. (Ed.). (2001). *Classic Operating Systems: From Batch Processing to Distributed Systems*. Springer. <https://doi.org/10.1007/978-1-4757-3510-9>

[^atlas]: Kilburn, T., Edwards, D. B. G., Lanigan, M. J., & Sumner, F. H. (1962). One-level storage system. *IRE Transactions on Electronic Computers*, EC-11(2), 223–235. <https://doi.org/10.1109/TEC.1962.5219356>

[^ctss]: Corbató, F. J., Merwin-Daggett, M., & Daley, R. C. (1962). An experimental time-sharing system. *Proceedings of the Spring Joint Computer Conference*, 335–344. <https://doi.org/10.1145/1460833.1460871>

[^multics]: Corbató, F. J., & Vyssotsky, V. A. (1965). Introduction and overview of the Multics system. *Proceedings of the Fall Joint Computer Conference*, 185–196. <https://doi.org/10.1145/1463891.1463912>

[^brooks]: Brooks, F. P., Jr. (1975). *The Mythical Man-Month: Essays on Software Engineering*. Addison-Wesley.

[^the]: Dijkstra, E. W. (1968). The structure of the "THE"-multiprogramming system. *Communications of the ACM*, 11(5), 341–346. <https://doi.org/10.1145/363095.363143>

[^ewd123]: Dijkstra, E. W. (1965). *Cooperating Sequential Processes* (EWD 123). Department of Mathematics, Technological University, Eindhoven. <https://www.cs.utexas.edu/~EWD/transcriptions/EWD01xx/EWD123.html>

[^rc4000]: Brinch Hansen, P. (1970). The nucleus of a multiprogramming system. *Communications of the ACM*, 13(4), 238–241. <https://doi.org/10.1145/362258.362278>

[^unix74]: Ritchie, D. M., & Thompson, K. (1974). The UNIX time-sharing system. *Communications of the ACM*, 17(7), 365–375. <https://doi.org/10.1145/361011.361061>

[^ritchie84]: Ritchie, D. M. (1984). The evolution of the Unix time-sharing system. *AT&T Bell Laboratories Technical Journal*, 63(8, Part 2), 1577–1593.

[^custer]: Custer, H. (1993). *Inside Windows NT*. Microsoft Press.

[^mach]: Accetta, M., Baron, R., Bolosky, W., Golub, D., Rashid, R., Tevanian, A., & Young, M. (1986). Mach: A new kernel foundation for UNIX development. *Proceedings of the USENIX Summer Conference*, 93–112.

[^gnu]: Stallman, R. (1983, September 27). Initial announcement of the GNU project. <https://www.gnu.org/gnu/initial-announcement.html>

[^torvalds]: Torvalds, L. (1991, August 25). What would you like to see most in minix? [Usenet post]. comp.os.minix. <https://groups.google.com/g/comp.os.minix/c/dlNtH7RRrGA>

[^debate]: DiBona, C., Ockman, S., & Stone, M. (Eds.). (1999). *Open Sources: Voices from the Open Source Revolution*. O'Reilly. Appendix A: The Tanenbaum–Torvalds debate.

[^top500]: TOP500. (n.d.). Operating system family: Linux. Retrieved October 20, 2026, from <https://www.top500.org/statistics/details/osfam/1/>

[^l4]: Liedtke, J. (1995). On micro-kernel construction. *Proceedings of the 15th ACM Symposium on Operating Systems Principles*, 237–250. <https://doi.org/10.1145/224056.224075>

[^sel4]: Klein, G., Elphinstone, K., Heiser, G., Andronick, J., Cock, D., Derrin, P., Elkaduwe, D., Engelhardt, K., Kolanski, R., Norrish, M., Sewell, T., Tuch, H., & Winwood, S. (2009). seL4: Formal verification of an OS kernel. *Proceedings of the 22nd ACM Symposium on Operating Systems Principles*, 207–220. <https://doi.org/10.1145/1629575.1629596>

[^singh]: Singh, A. (2006). *Mac OS X Internals: A Systems Approach*. Addison-Wesley.

[^popek]: Popek, G. J., & Goldberg, R. P. (1974). Formal requirements for virtualizable third generation architectures. *Communications of the ACM*, 17(7), 412–421. <https://doi.org/10.1145/361011.361073>

[^xen]: Barham, P., Dragovic, B., Fraser, K., Hand, S., Harris, T., Ho, A., Neugebauer, R., Pratt, I., & Warfield, A. (2003). Xen and the art of virtualization. *Proceedings of the 19th ACM Symposium on Operating Systems Principles*, 164–177. <https://doi.org/10.1145/945445.945462>

[^exokernel]: Engler, D. R., Kaashoek, M. F., & O'Toole, J., Jr. (1995). Exokernel: An operating system architecture for application-level resource management. *Proceedings of the 15th ACM Symposium on Operating Systems Principles*, 251–266. <https://doi.org/10.1145/224056.224076>

[^unikernel]: Madhavapeddy, A., Mortier, R., Rotsos, C., Scott, D., Singh, B., Gazagnaire, T., Smith, S., Hand, S., & Crowcroft, J. (2013). Unikernels: Library operating systems for the cloud. *Proceedings of the 18th International Conference on Architectural Support for Programming Languages and Operating Systems*, 461–472. <https://doi.org/10.1145/2451116.2451167>

[^syscall2]: Kerrisk, M. (n.d.). syscall(2). *Linux manual page*. <https://man7.org/linux/man-pages/man2/syscall.2.html>

[^love]: Love, R. (2010). *Linux Kernel Development* (3rd ed.). Addison-Wesley. Chapter 4.

[^eevdf]: The Linux Kernel documentation. (n.d.). EEVDF scheduler. <https://docs.kernel.org/scheduler/sched-eevdf.html>

[^coffman]: Coffman, E. G., Jr., Elphick, M., & Shoshani, A. (1971). System deadlocks. *ACM Computing Surveys*, 3(2), 67–78. <https://doi.org/10.1145/356586.356588>

[^intel]: Intel Corporation. (2026). *Intel 64 and IA-32 Architectures Software Developer's Manual, Volume 3A: System Programming Guide, Part 1* (Order No. 253668-093US). Chapter 5, Paging. <https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html>

[^belady]: Belady, L. A. (1966). A study of replacement algorithms for a virtual-storage computer. *IBM Systems Journal*, 5(2), 78–101. <https://doi.org/10.1147/sj.52.0078>

[^denning]: Denning, P. J. (1968). The working set model for program behavior. *Communications of the ACM*, 11(5), 323–333. <https://doi.org/10.1145/363095.363141>

[^thrashing]: Denning, P. J. (1968). Thrashing: Its causes and prevention. *Proceedings of the Fall Joint Computer Conference, Part I*, 915–922. <https://doi.org/10.1145/1476589.1476705>
