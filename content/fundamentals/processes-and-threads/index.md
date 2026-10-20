---
title: "Processes and Threads: What They Are, Where They Came From and How They Work"
description: "A process is a running program with its own private world; a thread is one line of execution inside it. Here is what each one is, how the ideas developed from 1960s time-sharing to goroutines and virtual threads, and how operating systems create, schedule and coordinate them."
date: 2026-10-20T15:30:00Z
categories: ["Fundamentals"]
tags: ["Processes", "Threads", "Concurrency", "Operating Systems", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

[What Is an Operating System?]({{< ref "operating-systems" >}}) introduced
processes and threads in a few paragraphs, and
[What Is a Processor?]({{< ref "processors" >}}) showed the hardware they run
on. This article gives them the space they deserve. Almost every question about
how a program behaves when it does more than one thing at a time, from "why did
my server run out of memory?" to "why does this counter come out wrong?", comes
down to the difference between a process and a thread.

## What they are

**A process is a running program together with everything it owns: a private
address space, open files and network connections, and an identity. A thread is
one sequence of execution inside a process: a program counter, a set of
registers and a stack. Every process has at least one thread; a multithreaded
process has several, all sharing the process's memory and resources.**

The distinction is between *ownership* and *execution*. The process is the
container that the operating system protects and accounts for; the thread is
what the scheduler actually puts on a CPU core.

{{< diagram src="process-anatomy.svg" caption="A process with three threads. Everything in the top row is shared; each thread has only its own registers, stack and thread-local storage." >}}

| | Process | Thread |
|---|---|---|
| **What it is** | A program in execution, with its own resources | One flow of control within a process |
| **Memory** | Its own private address space | Shares its process's address space |
| **Owns** | Address space, open files, sockets, user and group identity, signal handlers | Registers, program counter, stack, thread-local storage |
| **Isolation** | Strong: one process cannot read or corrupt another's memory without the OS's help | None from its sibling threads: any thread can read or overwrite any shared data |
| **Cost to create** | Higher: a new address space and resource tables | Lower: a new stack and register set |
| **Communication** | Through the OS: pipes, sockets, shared-memory segments, signals | Directly through shared variables, guarded by locks |
| **If it crashes** | Usually only that process dies | Usually the whole process dies with it |

### Why have both

One thread per process was the original model, and it is still the simplest:
each process is isolated, and nothing inside it happens at the same time as
anything else. Threads were added because many programs want to do several
things at once *on the same data*:

- **Use several cores.** A single thread can run on only one core at a time.
  A computation split across threads can use them all.
- **Stay responsive.** An editor can keep accepting keystrokes in one thread
  while another saves the file or checks spelling.
- **Overlap waiting.** A server can wait on one client's slow network
  connection in one thread while others serve everyone else.
- **Share cheaply.** Threads exchange data simply by reading and writing the
  same memory, with no copying through the operating system.

The cost of that sharing is the subject of half this article: when several
threads can touch the same data, the programmer has to coordinate them.

### Related words

| Term | Meaning |
|---|---|
| **Program** | The executable file on disk. One program can be running as many processes at once |
| **Task** | Used loosely; inside the Linux kernel, the single structure that represents both processes and threads |
| **Kernel thread** | A thread the operating system kernel knows about and schedules directly |
| **User-level (green) thread** | A thread managed by a library or language runtime inside a process, invisible to the kernel |
| **Fiber, coroutine** | A unit of execution that switches only where the code explicitly yields, never preemptively |
| **Job** | A group of processes treated as one, such as a shell pipeline or a Windows job object |

## A history of processes and threads

### The 1960s: the process is named

The idea of a process grew out of multiprogramming and time-sharing. Once a
computer switched between several programs, its designers needed a name for
"a program as it is being run", distinct from the program text and from the
processor running it. Jack Dennis and Earl Van Horn gave the classic
definition in 1966: a process is a locus of control within an instruction
sequence, the abstract entity that moves through a program's instructions as a
processor executes them.[^dennis] In the same years, Melvin Conway proposed the **fork** and
**join** operations for splitting a computation into parallel paths and
waiting for them to finish,[^conway] and Edsger Dijkstra's *Cooperating
Sequential Processes* introduced semaphores to coordinate processes that share
data.[^ewd123]

### Unix: fork, exec and the pipe

Unix (1969 onwards) made processes cheap and composable. A process is created
with `fork`, which duplicates the caller, and given a new program with `exec`;
the shell, pipes and redirection are all built from those two calls.[^unix74]
Dennis Ritchie later noted that the split between fork and exec was not new: it
was already present in the Berkeley time-sharing system of Project Genie, which
Ken Thompson knew well.[^ritchie84] Each Unix process had exactly
one thread of control, and for most of the 1970s that was the normal model.

### The 1980s and early 1990s: threads arrive

As shared-memory multiprocessors appeared, a process with one thread became
too coarse. Several systems split the process in two. **Mach** (Carnegie Mellon,
from 1985) separated the **task**, which owns an address space and resources,
from the **thread**, the unit of execution, and allowed many threads per
task.[^mach] **Windows NT** (1993) was designed from the start with processes
that contain one or more kernel-scheduled threads.[^custer][^mslearn] Sun's **Solaris 2**
used a two-level design that multiplexed user threads over kernel
"lightweight processes"; from Solaris 9 (2002) every thread got its own
lightweight process.[^eykholt][^solaris]

Researchers argued over where threads should live. User-level thread
libraries were fast but invisible to the kernel, so one thread blocking in a
system call stopped them all; kernel threads were safe but slower to create and
switch. Anderson and colleagues proposed **scheduler activations** (1991) as a
way for the kernel and a user-level library to cooperate.[^anderson] The
portable programming interface was settled in 1995 by **POSIX threads**
(Pthreads, IEEE Std 1003.1c).[^pthreads]

### Linux: one structure for both

Linux took an unusual route. Instead of separate process and thread objects, it
has one kernel structure, the **task**, and a system call, `clone`, that
creates a new task and lets the caller choose what to share with it: memory,
open files, signal handlers and so on.[^clone] Share nothing and you have a new
process; share everything and you have a new thread. The first Pthreads library
built on this, **LinuxThreads** (1996), had awkward corners, such as each thread
showing up with its own process ID.[^pthreads7] The **Native POSIX Thread
Library (NPTL)**, written by Ulrich Drepper and Ingo Molnar, fixed them. It
became part of glibc from version 2.3.2 and relies on support added in the
Linux 2.6 kernel (2003) for thread groups and for fast user-space locks called
**futexes**.[^nptl][^futex][^pthreads7]

### Threads under criticism, and events

Threads made concurrency easy to start and hard to get right. In 1996 John
Ousterhout gave a widely cited talk arguing that threads were a bad idea for
most purposes and that event-driven programming was simpler.[^ousterhout] In
1999 Dan Kegel's *The C10K problem* asked how one server could handle ten
thousand simultaneous connections, when a thread per connection meant ten
thousand stacks.[^c10k] The answer that spread was the **event loop**: one
thread waiting on many connections through `epoll` or `kqueue`, as in nginx and
later Node.js.[^nginxevents][^libuv] In 2006 Edward Lee argued that threads
were a fundamentally flawed model of concurrency because they make every
shared variable a potential bug.[^lee] Others had already defended them,
arguing that the problems were in particular implementations, not the
model.[^vonbehren]

Meanwhile the hardware turned against single threads. Once clock speeds stalled
in the mid-2000s, more performance meant more cores, and more cores meant more
threads. Languages also had to define precisely what a thread sees when another
writes to memory: Java's memory model was revised in 2004, and C and C++ gained
one in 2011.[^jsr133][^jmm][^cppmm]

### Lightweight threads return

The latest turn reconciles the two camps. **Erlang** (from 1986) had always run
huge numbers of tiny, isolated processes inside one operating system process,
scheduled by its runtime.[^erlang] **Go** (2009) made **goroutines** the
everyday unit of concurrency: cheap enough to start hundreds of thousands, and
multiplexed by the Go runtime over a small set of OS threads.[^effectivego][^gofaq] Java added
**virtual threads** in Java 21 (2023), which let ordinary blocking code scale
like an event loop.[^jep444] Many languages took a third path with
**async/await**, which writes event-loop code in a sequential style.

## A timeline at a glance

| Year | Milestone |
|---|---|
| 1963 | Conway proposes fork and join |
| 1965 | Dijkstra's *Cooperating Sequential Processes* and semaphores |
| 1966 | Dennis and Van Horn define the process |
| 1969–74 | Unix: processes with fork and exec, then pipes |
| 1974 | Hoare's monitors and condition variables |
| 1985 | Mach separates tasks from threads |
| 1986 | Erlang |
| 1991 | Scheduler activations |
| 1993 | Windows NT: kernel threads from the start |
| 1995 | POSIX threads standard |
| 1996 | Ousterhout's *Why Threads Are a Bad Idea*; LinuxThreads |
| 1999 | The C10K problem |
| 2003 | NPTL in Linux 2.6 |
| 2004–11 | Memory models for Java (2004), C and C++ (2011) |
| 2009 | Go and goroutines |
| 2023 | Virtual threads in Java 21 |

## Models

### The process life cycle

The kernel tracks what each process (or, on Linux, each task) is doing. On
Linux, `ps` shows it as a one-letter state:[^ps]

| Code | State | Meaning |
|---|---|---|
| `R` | Running or runnable | On a CPU, or ready and waiting for one |
| `S` | Interruptible sleep | Waiting for an event, such as input or a timer; a signal can wake it |
| `D` | Uninterruptible sleep | Waiting inside the kernel, usually for disk I/O; cannot be interrupted |
| `T` | Stopped | Paused by a job-control signal such as Ctrl+Z (a process stopped under a debugger shows as lowercase `t`) |
| `Z` | Zombie | Finished, but its parent has not yet collected its exit status |

On Unix-like systems processes form a tree. Every process except the first has
a **parent**, the process that created it, and each is identified by a
**process ID (PID)**.

{{< diagram src="fork-exec.svg" caption="Creating, running and reaping a child process on Unix. The zombie stage lasts only until the parent calls wait; a parent that is already waiting reaps the child at once." >}}

1. **Creation.** `fork` creates a child that is a copy of the parent: same
   program, same memory contents, same open files. Copying is lazy: parent and
   child share every page **copy-on-write**, so only pages one of them modifies
   are actually copied.[^fork]
2. **New program.** The child calls `execve`, which replaces its whole address
   space with a new program while keeping its PID and, unless marked otherwise,
   its open files. This is how a shell connects the child's standard input and
   output to a file or a pipe before the new program starts.
3. **Termination.** The child calls `exit` (or is killed by a signal). The
   kernel frees its memory but keeps a small record, its exit status, so the
   parent can learn how it ended. Until then it is a **zombie**.
4. **Reaping.** The parent calls `wait` or `waitpid`, collects the status, and
   the zombie disappears. If the parent dies first, the orphan is adopted by
   init (process 1) or a designated "subreaper", which reaps it.[^prctl]

Here is the shell pipeline `ls | wc -l` built by hand from these calls:

```c
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

/* The equivalent of the shell pipeline  ls | wc -l  */
int main(void) {
    int fd[2];
    pipe(fd);                          /* fd[0] is the read end, fd[1] the write end */

    if (fork() == 0) {                 /* first child: ls */
        dup2(fd[1], STDOUT_FILENO);    /* its output goes into the pipe */
        close(fd[0]); close(fd[1]);
        execlp("ls", "ls", (char *)NULL);
        _exit(127);                    /* reached only if exec failed */
    }
    if (fork() == 0) {                 /* second child: wc -l */
        dup2(fd[0], STDIN_FILENO);     /* its input comes from the pipe */
        close(fd[0]); close(fd[1]);
        execlp("wc", "wc", "-l", (char *)NULL);
        _exit(127);
    }
    close(fd[0]); close(fd[1]);        /* the parent uses neither end */
    while (wait(NULL) > 0)             /* reap both children */
        ;
    return 0;
}
```

Not every system works this way. The Win32 API has no `fork`: Windows creates a
process and loads its program in one step with `CreateProcess`.[^createprocess]
POSIX offers `posix_spawn` for the same one-step pattern, and some researchers
argue that `fork` has become a liability: it is slow for large processes,
interacts badly with threads, and complicates the kernel.[^forkroad]

### Threading models

There are three ways to map the threads a program creates onto the threads the
kernel schedules:

{{< diagram src="threading-models.svg" caption="The three threading models. The dashed line separates user space (above) from the kernel (below)." >}}

| Model | How it works | Strength | Weakness | Examples |
|---|---|---|---|---|
| **One-to-one (1:1)** | Every thread is a kernel thread | Real parallelism; a blocking call blocks only its own thread | Each thread costs a kernel structure and a full-size stack | Pthreads on Linux (NPTL), Windows threads, macOS |
| **Many-to-one (N:1)** | All of a process's threads run on one kernel thread, switched by a library | Very cheap to create and switch | No parallelism; one blocking system call stops every thread | Early Java "green threads",[^greenthreads] GNU Pth[^pth] |
| **Many-to-many (M:N)** | A runtime multiplexes many user threads over a pool of kernel threads | Cheap threads *and* parallelism | Complex; the runtime must avoid blocking its kernel threads | Go, Erlang, Java virtual threads, Solaris before version 9 |

General-purpose operating systems have converged on 1:1 for their native
threads, and M:N now lives in language runtimes, which know enough about the
program to schedule it well.

### Communicating between processes

Because processes do not share memory by default, the operating system provides
**inter-process communication (IPC)**:

| Mechanism | What it carries | Typical use |
|---|---|---|
| **Pipe** | A one-way byte stream between related processes | Shell pipelines |
| **Named pipe (FIFO)** | A byte stream with a name in the file system | Unrelated processes on one machine |
| **Unix domain socket** | A two-way stream or messages, local only | Talking to local daemons, such as Docker or a database |
| **Network socket** | A two-way stream or messages across machines | Every network service |
| **Shared memory** | A region mapped into several address spaces | High-volume data, such as video frames |
| **Message queue** | Discrete messages with an order | Decoupling producers and consumers |
| **Signal** | A small integer notification | "Stop", "reload your configuration", "a child exited" |

Shared memory is the fastest, and it brings back exactly the coordination
problems of threads.

## How they work

### What the kernel stores

For every process, the kernel keeps a **process control block**; for every
thread, its saved registers and scheduling state. In Linux both are the same
`task_struct`, and threads of one process are simply tasks that share their
memory map, file table and signal handlers and belong to one **thread group**.
What user space calls a process ID is the thread group ID; each thread also has
its own thread ID.[^clone] You can see this from the shell:

```bash
ps -eLf               # one line per thread: LWP is the thread ID, NLWP the thread count
ls /proc/self/task    # each thread of a process has its own directory
```

Each thread needs its own stack, and stacks are where much of a thread's cost
lies. On Linux a new Pthread's stack defaults to the process's stack size limit,
commonly 8 MiB of reserved address space;[^pthreadcreate] on Windows the default
is 1 MB.[^winstack] Memory is committed only as the stack is actually used, but
the reservation is why tens of thousands of OS threads strain a system. Go
instead starts goroutines with stacks of a few kilobytes,[^gofaq] and Java keeps
virtual-thread stacks as small objects on the heap; both grow on
demand.[^jep444]

### Creating a thread

In C with POSIX threads, a thread is a function started with `pthread_create`
and waited for with `pthread_join`. On Linux, `pthread_create` allocates a
stack and calls `clone` (or its newer form, `clone3`) with flags that share the address space, file
descriptors, file system information and signal handlers, and place the new
task in the caller's thread group.[^clone] Creating a thread this way is much
cheaper than creating a process, but still involves a system call and kernel
data structures, which is what user-level threads avoid.

In Go, the same idea is a keyword. This starts a hundred thousand goroutines,
which would be reckless with OS threads (it needs Go 1.22 or later, where each
loop iteration gets its own `i`):

```go
package main

import (
	"fmt"
	"sync"
)

func main() {
	var wg sync.WaitGroup
	results := make([]int, 100_000)
	for i := range results {
		wg.Add(1)
		go func() { // a new goroutine, not a new OS thread
			defer wg.Done()
			results[i] = i * i
		}()
	}
	wg.Wait()
	fmt.Println(results[99_999]) // 9999800001
}
```

### Context switching

When the kernel moves a CPU core from one thread to another, it performs a
**context switch**.

{{< diagram src="context-switch.svg" caption="A context switch on one core. Between the two threads, the kernel saves one set of registers, runs the scheduler and restores the other." >}}

1. Control enters the kernel, through a timer interrupt (the running thread's
   time slice is up), a system call that blocks (it is waiting for I/O or a
   lock), or an interrupt that wakes a more important thread.
2. The kernel saves the running thread's registers, including its stack pointer
   and program counter.
3. The scheduler chooses the next thread to run.
4. If the next thread belongs to a different process, the kernel switches the
   MMU to that process's page tables. Switching between threads of the same
   process skips this step, which is one reason it is cheaper.
5. The kernel restores the next thread's registers and returns to user mode,
   where it continues exactly where it was last stopped.

The switch itself takes on the order of microseconds. Its indirect cost is often
larger: the new thread finds the caches and TLB full of the previous thread's
data, and runs slowly until they warm up again.[^lichen] A user-level runtime
can switch between its own threads without entering the kernel at all, which
is how Go and Java virtual threads keep switches cheap.

### Scheduling threads

The scheduler (described in
[What Is an Operating System?]({{< ref "operating-systems" >}})) schedules
threads, not processes: a process with eight runnable threads can occupy eight
cores at once. Two refinements matter for threaded programs:

- **Affinity.** The scheduler prefers to keep a thread on the core it last ran
  on, where its data may still be in cache, and programs can pin threads to
  particular cores.
- **Simultaneous multithreading.** A core with SMT (Intel's Hyper-Threading)
  appears to the operating system as two (on some processors more) logical CPUs, so two threads can
  share one physical core and its execution units.

How much a program speeds up with more threads is limited by the part of it
that cannot run in parallel. Gene Amdahl's 1967 argument, now called **Amdahl's
law**, says that if a fraction *s* of the work is serial, no number of
processors can make the program more than 1/*s* times faster.[^amdahl] A
program that is 10 percent serial will never run more than ten times faster,
however many cores it gets.

### Synchronisation

Threads share memory, so whenever two of them access the same data and at least
one writes, the program must control the order. Otherwise it has a **data
race**, and the result depends on how the scheduler happened to interleave the
threads, which changes from run to run.

The building blocks, all ultimately built on atomic instructions in the
processor, are:

| Tool | What it guarantees | Typical use |
|---|---|---|
| **Atomic operation** | A single read-modify-write (increment, compare-and-swap) happens indivisibly | Counters, flags, lock-free data structures |
| **Mutex (lock)** | Only one thread at a time holds it | Protecting a data structure |
| **Read-write lock** | Many readers or one writer | Data that is read far more than written |
| **Condition variable** | Lets a thread sleep, with a mutex released, until another signals that something changed | Waiting for a queue to become non-empty |
| **Semaphore** | A counter that threads decrement (waiting at zero) and increment | Limiting how many threads use a resource[^ewd123] |
| **Barrier** | Every thread waits until all have arrived | Phases of a parallel computation |

Condition variables come from **monitors**, developed by Per Brinch Hansen and
Tony Hoare (1974), which bundle
data with the procedures allowed to touch it and let a procedure wait inside
until a condition holds.[^hoare] The classic use is a bounded buffer between a
producer and a consumer:

```c
#include <pthread.h>
#include <stdio.h>

#define SIZE 8
static int buf[SIZE], count = 0, head = 0, tail = 0;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t not_empty = PTHREAD_COND_INITIALIZER;
static pthread_cond_t not_full = PTHREAD_COND_INITIALIZER;

static void put(int v) {
    pthread_mutex_lock(&lock);
    while (count == SIZE)                     /* re-check after every wake-up */
        pthread_cond_wait(&not_full, &lock);  /* sleeps with the lock released */
    buf[tail] = v; tail = (tail + 1) % SIZE; count++;
    pthread_cond_signal(&not_empty);
    pthread_mutex_unlock(&lock);
}

static int get(void) {
    pthread_mutex_lock(&lock);
    while (count == 0)
        pthread_cond_wait(&not_empty, &lock);
    int v = buf[head]; head = (head + 1) % SIZE; count--;
    pthread_cond_signal(&not_full);
    pthread_mutex_unlock(&lock);
    return v;
}

static void *producer(void *arg) {
    (void)arg;
    for (int i = 1; i <= 100; i++)
        put(i);
    put(-1);                                  /* tell the consumer to stop */
    return NULL;
}

int main(void) {
    pthread_t t;
    pthread_create(&t, NULL, producer, NULL);
    long sum = 0;
    for (int v; (v = get()) != -1; )
        sum += v;
    pthread_join(t, NULL);
    printf("%ld\n", sum);                     /* 5050 */
    return 0;
}
```

The `while` loops matter: a woken thread must check its condition again,
because another thread may have got there first, and POSIX allows
**spurious wake-ups**.[^condwait]

Locks are made fast by keeping the common case out of the kernel. A Linux
**futex** is an integer in shared memory that threads update with atomic
instructions; only when a thread actually has to wait, or wake a waiter, does it
make a system call.[^futex] An uncontended lock therefore needs only an atomic
instruction, with no system call at all.

Locks have their own failure modes. A **deadlock** happens when threads wait for
each other in a cycle; the usual cure is to always take locks in the same order.
**Priority inversion** happens when a low-priority thread holding a lock is
starved by medium-priority work while a high-priority thread waits for that
lock. **Contention** happens when so many threads want the same lock that they
spend their time queuing rather than working.

### Memory models

Modern processors and compilers reorder memory operations for speed. A single
thread cannot tell, but another thread can. Leslie Lamport defined the
intuitive ideal in 1979 as **sequential consistency**: the result is as if all
threads' operations ran in some single interleaved order, each thread's in
program order.[^lamport] Real hardware does not guarantee it, so languages
specify a **memory model**: a contract saying which reorderings are allowed and
which operations (locks, atomics, `volatile` in Java) restore order. Hans
Boehm showed in 2005 that threads cannot be added correctly to a language
purely as a library, because the compiler has to know the rules too.[^boehm]
Java's memory model had been rebuilt in 2004, and C and C++ adopted one in
2011, which Boehm's work helped shape.[^jsr133][^jmm][^cppmm] The practical rule they give programmers: a program
without data races behaves as if it were sequentially consistent.

### Signals and threads

Signals predate threads, and the combination is awkward. A signal sent to a
process is delivered to any one of its threads that has not blocked it, so
multithreaded programs usually block signals in every thread but one, which
waits for them explicitly.[^signal7] Calling `fork` in a multithreaded program
copies only the calling thread; any lock another thread held at that moment
stays locked forever in the child, which is why a child of a threaded program
should call `exec` almost immediately.[^fork]

## Putting it together: serving many clients

How a network server handles many clients at once is a direct choice between
the models in this article.

{{< diagram src="server-models.svg" caption="Three classic server designs. The top circles are client connections; the small solid boxes are threads." >}}

| Design | How it works | Strengths | Weaknesses |
|---|---|---|---|
| **Process per connection** | A new (or pre-forked) process serves each client | A crash or bug affects one client; simple code | Memory and creation cost per client; sharing state needs IPC |
| **Thread per connection** | One thread per client, all in one process | Simple blocking code; shared caches in memory | Thousands of stacks; locking around shared state |
| **Event loop** | One thread waits on all connections with `epoll` or `kqueue` and handles whichever is ready | Tens of thousands of connections with little memory | Code split into callbacks; one slow handler stalls everyone; one core per loop |
| **Lightweight threads** | Thread-per-connection code on goroutines or virtual threads, which the runtime parks on an event loop underneath | Simple blocking code *and* event-loop scale | Requires a runtime that controls every blocking call |

Real systems mix them. nginx runs one event loop per worker process, and is
usually configured with one worker per CPU core.[^nginxcore] Web browsers went
the other way for safety. Chrome ran web pages in separate renderer processes
from its first release in 2008, by default giving each site instance (roughly,
a group of related tabs on one site) its own process, so one crashing page did
not take the others down.[^reis][^chromium] Strict per-site isolation,
including cross-site frames inside a page, became the default only with Site
Isolation in Chrome 67 in 2018.[^siteisolation]

## Why it matters

Processes and threads are the two answers to the question "what is running?",
and they sit at opposite ends of a trade-off. Processes give isolation and
pay for it in memory and communication. Threads give sharing and pay for it in
coordination. Most of the bugs that are hardest to reproduce, such as races,
deadlocks and memory corruption that appears only under load, come from
treating threads as if they were processes. Many of the performance problems,
such as servers with thousands of idle stacks and programs that do not speed up
on more cores, come from treating processes or threads as free. Knowing what
each one really costs, and what it really shares, is the start of reasoning
about any concurrent program.

## References

[^dennis]: Dennis, J. B., & Van Horn, E. C. (1966). Programming semantics for multiprogrammed computations. *Communications of the ACM*, 9(3), 143–155. <https://doi.org/10.1145/365230.365252>

[^conway]: Conway, M. E. (1963). A multiprocessor system design. *Proceedings of the November 12–14, 1963, Fall Joint Computer Conference*, 139–146. <https://doi.org/10.1145/1463822.1463838>

[^ewd123]: Dijkstra, E. W. (1965). *Cooperating Sequential Processes* (EWD 123). Department of Mathematics, Technological University, Eindhoven. <https://www.cs.utexas.edu/~EWD/transcriptions/EWD01xx/EWD123.html>

[^unix74]: Ritchie, D. M., & Thompson, K. (1974). The UNIX time-sharing system. *Communications of the ACM*, 17(7), 365–375. <https://doi.org/10.1145/361011.361061>

[^ritchie84]: Ritchie, D. M. (1984). The evolution of the Unix time-sharing system. *AT&T Bell Laboratories Technical Journal*, 63(8), 1577–1593. <https://doi.org/10.1002/j.1538-7305.1984.tb00054.x>

[^mach]: Accetta, M., Baron, R., Bolosky, W., Golub, D., Rashid, R., Tevanian, A., & Young, M. (1986). Mach: A new kernel foundation for UNIX development. *Proceedings of the USENIX Summer Conference*, 93–112.

[^mslearn]: Microsoft. (n.d.). About processes and threads. *Microsoft Learn*. <https://learn.microsoft.com/en-us/windows/win32/procthread/about-processes-and-threads>

[^eykholt]: Eykholt, J. R., Kleiman, S. R., Barton, S., Faulkner, R., Shivalingiah, A., Smith, M., Stein, D., Voll, J., Weeks, M., & Williams, D. (1992). Beyond multiprocessing: Multithreading the SunOS kernel. *Proceedings of the USENIX Summer Conference*, 11–18.

[^anderson]: Anderson, T. E., Bershad, B. N., Lazowska, E. D., & Levy, H. M. (1992). Scheduler activations: Effective kernel support for the user-level management of parallelism. *ACM Transactions on Computer Systems*, 10(1), 53–79. <https://doi.org/10.1145/146941.146944>

[^pthreads]: IEEE. (1995). *IEEE Standard for Information Technology—Portable Operating System Interface (POSIX)—System Application Program Interface (API) Amendment 2: Threads Extension (C Language)* (IEEE Std 1003.1c-1995). <https://standards.ieee.org/ieee/1003.1c/1393/>

[^clone]: Linux man-pages project. (n.d.). clone(2). *Linux manual page*. <https://man7.org/linux/man-pages/man2/clone.2.html>

[^nptl]: Drepper, U., & Molnar, I. (2005). *The Native POSIX Thread Library for Linux*. <https://www.akkadia.org/drepper/nptl-design.pdf>

[^futex]: Franke, H., Russell, R., & Kirkwood, M. (2002). Fuss, futexes and furwocks: Fast userlevel locking in Linux. *Proceedings of the Ottawa Linux Symposium*, 479–495. <https://www.kernel.org/doc/ols/2002/ols2002-pages-479-495.pdf>

[^ousterhout]: Ousterhout, J. (1996, January 25). *Why threads are a bad idea (for most purposes)* [Invited talk]. USENIX Annual Technical Conference. <https://web.stanford.edu/~ouster/cgi-bin/papers/threads.pdf>

[^c10k]: Kegel, D. (1999; last updated 2014). The C10K problem. <http://www.kegel.com/c10k.html>

[^lee]: Lee, E. A. (2006). The problem with threads. *Computer*, 39(5), 33–42. <https://doi.org/10.1109/MC.2006.180>

[^vonbehren]: von Behren, R., Condit, J., & Brewer, E. (2003). Why events are a bad idea (for high-concurrency servers). *Proceedings of the 9th Workshop on Hot Topics in Operating Systems*. <https://www.usenix.org/conference/hotos-ix/why-events-are-bad-idea-high-concurrency-servers>

[^jmm]: Manson, J., Pugh, W., & Adve, S. V. (2005). The Java memory model. *Proceedings of the 32nd ACM SIGPLAN-SIGACT Symposium on Principles of Programming Languages*, 378–391. <https://doi.org/10.1145/1040305.1040336>

[^cppmm]: Boehm, H.-J., & Adve, S. V. (2008). Foundations of the C++ concurrency memory model. *Proceedings of the 29th ACM SIGPLAN Conference on Programming Language Design and Implementation*, 68–78. <https://doi.org/10.1145/1375581.1375591>

[^erlang]: Armstrong, J. (2007). A history of Erlang. *Proceedings of the Third ACM SIGPLAN Conference on History of Programming Languages*, 6-1–6-26. <https://doi.org/10.1145/1238844.1238850>

[^effectivego]: The Go Authors. (n.d.). Effective Go: Goroutines. <https://go.dev/doc/effective_go#goroutines>

[^jep444]: Pressler, R., & Bateman, A. (2023). *JEP 444: Virtual threads*. OpenJDK. <https://openjdk.org/jeps/444>

[^hoare]: Hoare, C. A. R. (1974). Monitors: An operating system structuring concept. *Communications of the ACM*, 17(10), 549–557. <https://doi.org/10.1145/355620.361161>

[^ps]: procps-ng. (n.d.). ps(1): Process state codes. *Linux manual page*. <https://man7.org/linux/man-pages/man1/ps.1.html>

[^fork]: Linux man-pages project. (n.d.). fork(2). *Linux manual page*. <https://man7.org/linux/man-pages/man2/fork.2.html>

[^prctl]: Linux man-pages project. (n.d.). PR_SET_CHILD_SUBREAPER(2const). *Linux manual page*. <https://man7.org/linux/man-pages/man2/PR_SET_CHILD_SUBREAPER.2const.html>

[^createprocess]: Microsoft. (n.d.). CreateProcessA function (processthreadsapi.h). *Microsoft Learn*. <https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessa>

[^forkroad]: Baumann, A., Appavoo, J., Krieger, O., & Roscoe, T. (2019). A fork() in the road. *Proceedings of the Workshop on Hot Topics in Operating Systems*, 14–22. <https://doi.org/10.1145/3317550.3321435>

[^pthreadcreate]: Linux man-pages project. (n.d.). pthread_create(3). *Linux manual page*. <https://man7.org/linux/man-pages/man3/pthread_create.3.html>

[^winstack]: Microsoft. (n.d.). Thread stack size. *Microsoft Learn*. <https://learn.microsoft.com/en-us/windows/win32/procthread/thread-stack-size>

[^lichen]: Li, C., Ding, C., & Shen, K. (2007). Quantifying the cost of context switch. *Proceedings of the 2007 Workshop on Experimental Computer Science*, Article 2. <https://doi.org/10.1145/1281700.1281702>

[^amdahl]: Amdahl, G. M. (1967). Validity of the single processor approach to achieving large scale computing capabilities. *Proceedings of the April 18–20, 1967, Spring Joint Computer Conference*, 483–485. <https://doi.org/10.1145/1465482.1465560>

[^condwait]: The Open Group. (2018). pthread_cond_timedwait, pthread_cond_wait. *The Open Group Base Specifications Issue 7* (IEEE Std 1003.1-2017). <https://pubs.opengroup.org/onlinepubs/9699919799/functions/pthread_cond_wait.html>

[^lamport]: Lamport, L. (1979). How to make a multiprocessor computer that correctly executes multiprocess programs. *IEEE Transactions on Computers*, C-28(9), 690–691. <https://doi.org/10.1109/TC.1979.1675439>

[^boehm]: Boehm, H.-J. (2005). Threads cannot be implemented as a library. *Proceedings of the 2005 ACM SIGPLAN Conference on Programming Language Design and Implementation*, 261–268. <https://doi.org/10.1145/1065010.1065042>

[^signal7]: Linux man-pages project. (n.d.). signal(7). *Linux manual page*. <https://man7.org/linux/man-pages/man7/signal.7.html>

[^reis]: Reis, C., & Gribble, S. D. (2009). Isolating web programs in modern browser architectures. *Proceedings of the 4th ACM European Conference on Computer Systems*, 219–232. <https://doi.org/10.1145/1519065.1519090>

[^custer]: Custer, H. (1993). *Inside Windows NT*. Microsoft Press.

[^solaris]: Oracle. (n.d.). Multithreading terms. In *Multithreaded Programming Guide* (Solaris 10). <https://docs.oracle.com/cd/E19253-01/816-5137/6mba5vpj4/index.html>

[^pthreads7]: Linux man-pages project. (n.d.). pthreads(7). *Linux manual page*. <https://man7.org/linux/man-pages/man7/pthreads.7.html>

[^nginxevents]: nginx. (n.d.). Connection processing methods. <https://nginx.org/en/docs/events.html>

[^libuv]: libuv. (n.d.). Design overview. *libuv documentation*. <https://docs.libuv.org/en/v1.x/design.html>

[^jsr133]: Java Community Process. (2004). *JSR 133: Java Memory Model and Thread Specification Revision*. <https://jcp.org/en/jsr/detail?id=133>

[^gofaq]: The Go Authors. (n.d.). Frequently asked questions: Why goroutines instead of threads? <https://go.dev/doc/faq#goroutines>

[^greenthreads]: Sun Microsystems. (n.d.). Multithreading models. In *Java on Solaris 7 Developer's Guide*, Chapter 2. <https://docs.oracle.com/cd/E19620-01/805-4031/6j3qv1oej/index.html>

[^pth]: Engelschall, R. S. (2003). *GNU Pth: The GNU Portable Threads* (README). <https://gnu.cs.utah.edu/pth/README>

[^nginxcore]: nginx. (n.d.). Core functionality: worker_processes. <https://nginx.org/en/docs/ngx_core_module.html#worker_processes>

[^chromium]: The Chromium Authors. (n.d.). Process model and site isolation. *Chromium Docs*. <https://chromium.googlesource.com/chromium/src/+/main/docs/process_model_and_site_isolation.md>

[^siteisolation]: The Chromium Projects. (n.d.). Site isolation. <https://www.chromium.org/Home/chromium-security/site-isolation/>
