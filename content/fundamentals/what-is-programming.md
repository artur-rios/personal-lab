---
title: "What Is Programming? A Short History of Telling Machines What to Do"
description: "Programming is the craft of turning a process into a precise description a machine can carry out. Here is what that means, and how we got from looms and punched cards to modern languages."
date: 2026-10-19T09:00:00Z
categories: ["Fundamentals"]
tags: ["Programming", "History", "Computer Science", "Fundamentals"]
---

Ask ten developers what programming is and you will get ten answers: "writing
code", "solving problems", "telling a computer what to do". All of them are
true, and none of them is quite enough. This article tries to pin the idea down,
and then follows it through roughly two centuries of history — because most of
what feels arbitrary about programming today makes sense once you know where it
came from.

## What programming is

At its core, **programming is the act of describing a process precisely enough
that a machine can carry it out without understanding it.**

Each part of that sentence matters:

- **A process.** A program is not a static fact but a recipe — a sequence of
  steps that transforms some input into some output. Abelson and Sussman open
  their classic textbook by describing computational processes as abstract
  beings that inhabit computers, directed by "a pattern of rules called a
  program".[^sicp]
- **Precisely.** Natural language tolerates ambiguity because the listener fills
  the gaps. A machine fills nothing. Every case — the empty list, the negative
  number, the file that does not exist — has to be decided in advance.
- **Without understanding it.** The machine does not know what the program is
  *for*. It follows rules mechanically. All the meaning lives with the
  programmer, which is why programs can be perfectly obeyed and still be wrong.

### Algorithms, programs and languages

Three words are often used interchangeably, but they are worth separating:

| Term | What it is | Example |
|---|---|---|
| **Algorithm** | A finite, unambiguous procedure for solving a problem, independent of any machine | Euclid's method for the greatest common divisor |
| **Program** | An algorithm (or many) expressed in a form a specific machine can execute | A `gcd` function in Python |
| **Programming language** | A formal notation, with exact rules of syntax and meaning, for writing programs | Python, C, Lisp |

Donald Knuth's definition of an algorithm is the standard one: it must be
*finite* (it terminates), *definite* (each step is precisely specified), have
inputs and outputs, and be *effective* (each step is basic enough to actually be
done).[^knuth] The word itself comes from the name of the 9th-century Persian
mathematician Muhammad ibn Musa al-Khwarizmi, whose works on arithmetic carried
the Hindu–Arabic numerals into Europe.[^knuth]

Algorithms are far older than computers. Euclid described his method for the
greatest common divisor around 300 BCE, and it still runs unchanged today:

```python
def gcd(a: int, b: int) -> int:
    """Euclid's algorithm: the greatest common divisor of a and b."""
    while b != 0:
        a, b = b, a % b
    return a

print(gcd(1071, 462))  # 21
```

### Programming as abstraction

The other half of the definition is that programming is about **managing
complexity**. A processor only understands very small operations — load a
number, add two numbers, jump to another instruction. Everything else is built
from layers of abstraction: machine code, then assembly language, then
high-level languages, then libraries, frameworks and services. Each layer lets
the programmer think in larger ideas while the layer below handles the detail.

Niklaus Wirth summarised the craft in the title of a 1976 book:
*Algorithms + Data Structures = Programs*.[^wirth76] Choosing how to represent
information is as much a part of programming as choosing the steps that work on
it.

## A history of programming

### Before computers: programs for looms and engines

The first machine "programs" were not for calculation at all. In 1804 Joseph
Marie Jacquard patented a loom controlled by a chain of punched cards: each
card encoded which threads to lift for one row of the pattern. Change the cards
and the same loom wove a different fabric — the essential idea of separating the
machine from its instructions.[^jacquard]

In the 1830s Charles Babbage designed the **Analytical Engine**, a mechanical,
general-purpose computer that would have read its instructions from Jacquard-style
cards. It was never completed, but it had the shape of a modern computer: a
"store" (memory) and a "mill" (processor).

In 1843 **Ada Lovelace** translated an article on the engine by Luigi Menabrea
and added a set of notes three times its length.[^lovelace] Her Note G contains
a step-by-step table for computing Bernoulli numbers on the engine, widely
regarded as the first published computer program. More importantly, she saw
past arithmetic: she suggested the engine could act on anything whose relations
could be expressed symbolically, such as musical notes. That is the leap from
*calculator* to *computer*.

At the end of the century, Herman Hollerith's punched-card tabulating machines
processed the 1890 US census. His company merged into the
Computing-Tabulating-Recording Company in 1911, which was renamed IBM in
1924.[^ceruzzi] Punched cards would remain the main way of feeding programs
into computers until the 1970s.

### 1936: what can be computed at all?

Before anyone built an electronic computer, mathematicians asked a deeper
question: which problems can be solved by a mechanical procedure at all?

In 1936 **Alan Turing** answered with an imaginary device — now called the
Turing machine — that reads and writes symbols on an infinite tape according to
a table of rules.[^turing] He showed that a single *universal* machine could
simulate any other one if given its rule table as input. That is, in theory, the
stored-program computer: the program is just more data.

The same year, **Alonzo Church** reached equivalent conclusions with the lambda
calculus, a system built entirely from function definition and
application.[^church] The Church–Turing thesis — that these models capture
everything that is "effectively computable" — remains the foundation of computer
science. The lambda calculus would later become the direct ancestor of
functional programming.

### The 1940s: programming by hand

The first electronic computers were programmed physically. Konrad Zuse's Z3
(1941) read instructions from punched film, and between 1942 and 1945 Zuse
designed **Plankalkül**, arguably the first high-level programming language,
though it was not published in full until 1972 and was first implemented
only in 1975, by Joachim Hohmann.[^plankalkul]

**ENIAC**, completed in 1945 at the University of Pennsylvania, was programmed
by setting switches and plugging cables between its units — "programming" a new
problem could take days. That work was done by a team of six women: Kathleen
McNulty, Jean Jennings, Betty Snyder, Marlyn Wescoff, Frances Bilas and Ruth
Lichterman. They worked out how to program the machine largely from its logical
diagrams, and for decades their contribution went unrecognised.[^light]

The fix for rewiring was the **stored-program concept**: keep the instructions in
the same memory as the data. John von Neumann's *First Draft of a Report on the
EDVAC* (1945) described this design so clearly that it is still called the "von
Neumann architecture".[^vonneumann] On 21 June 1948 the Manchester "Baby" became
the first machine to run a program from electronic memory,[^lavington] and
Cambridge's **EDSAC** followed in 1949. The EDSAC team — Maurice Wilkes, David
Wheeler and Stanley Gill — published the first textbook on programming in 1951,
introducing ideas such as the subroutine library.[^wwg]

### The 1950s: from machine code to languages

Early programs were written in raw numeric machine code, then in **assembly
language**, where mnemonics like `ADD` stand for instructions. Both tie the
program to one machine and force the programmer to manage every detail.

The next step was to let the computer translate a more human notation itself.
Grace Hopper's **A-0** system (1952) assembled programs from a library of
routines, and she argued forcefully that computers should do this kind of
clerical work for programmers.[^hopper] Alick Glennie's **Autocode** for the
Manchester Mark 1 appeared the same year.[^knuthpardo]

The breakthrough came with **FORTRAN** ("Formula Translation"), developed at IBM
by a team led by John Backus and released in 1957.[^backus] Its compiler produced
code nearly as efficient as hand-written assembly, which convinced a sceptical
industry that high-level languages were practical. Within a few years three more
foundational languages appeared:

- **LISP** (1958), by John McCarthy, built on the lambda calculus, with programs
  represented as lists, recursion and automatic memory management.[^mccarthy]
- **COBOL** (1959–60), designed by the CODASYL committee and heavily influenced
  by Hopper's FLOW-MATIC, aimed at business data processing in English-like
  syntax.
- **ALGOL 60**, which introduced block structure with lexical scope and was the
  first language whose syntax was defined in the formal notation now known as
  Backus–Naur Form.[^algol] Almost every
  mainstream language since is, syntactically, a descendant of ALGOL.

### The 1960s and 1970s: programming becomes a discipline

As programs grew, they became unreliable, late and expensive. In 1968 a NATO
conference in Garmisch, Germany, put a name to the problem — the "software
crisis" — and popularised the term **software engineering**.[^nato]

The same year Edsger Dijkstra published his letter *Go To Statement Considered
Harmful*,[^dijkstra] arguing that unrestricted jumps made programs impossible to
reason about. The resulting **structured programming** movement — sequence,
selection and iteration as the only control structures — is now so universal
that it is hard to see it as an idea that once had to win an argument.

This period also produced the paradigms we still use:

- **Object-oriented programming** began with **Simula** (1962–67) by Ole-Johan
  Dahl and Kristen Nygaard, which introduced classes and objects for
  simulation,[^simula] and was developed further by Alan Kay's **Smalltalk** at
  Xerox PARC in the 1970s.[^kay]
- **Systems programming** was transformed by **C** (1972), developed by Dennis
  Ritchie at Bell Labs as the implementation language for Unix, whose kernel was
  rewritten in C in 1973. C gave programmers
  close control over the machine while remaining portable across
  hardware.[^ritchie]
- **Pascal** (1970), by Niklaus Wirth, was designed to teach structured
  programming clearly.[^pascal]
- **Logic and functional programming** took shape with **Prolog** (1972) and
  **ML** (1973), the latter introducing type inference that many modern
  languages have since borrowed.

### The 1980s and 1990s: personal computers and the internet

Cheap microcomputers put programming in homes and schools, often through BASIC.
Object orientation went mainstream with **C++** (1985), which Bjarne Stroustrup
built by adding Simula-style classes to C.[^stroustrup]

The 1990s brought languages shaped by the internet and by programmer
productivity rather than raw machine efficiency: **Python** (first released in
1991 by Guido van Rossum),[^python] **Java** (1995), with its promise of "write
once, run anywhere" on a virtual machine, and **JavaScript** (1995), prototyped by
Brendan Eich in about ten days to make web pages interactive and now one of the
most widely deployed languages in the world.[^js] Garbage collection,
virtual machines and huge standard libraries went from research ideas to
everyday expectations.

### The 2000s to today

Recent decades have been less about inventing paradigms than combining and
refining them. Languages such as C# (announced in 2000), Go (2009), Rust (1.0 in
2015)[^rust] and Swift (2014) mix object-oriented, functional and systems ideas,
with a strong focus on safety — particularly memory safety and concurrency.

Meanwhile, the work around code has changed as much as the code itself:
version control, open-source collaboration, automated testing, continuous
integration and cloud deployment are now part of what "programming" means in
practice. Since the early 2020s, assistants built on large language models have
begun generating and reviewing code from natural-language descriptions — in a
sense, the latest step in the long move toward letting the machine handle more
of the translation from intent to instructions.

## A timeline at a glance

| Year | Milestone |
|---|---|
| c. 300 BCE | Euclid's algorithm for the greatest common divisor |
| c. 820 | al-Khwarizmi's works on arithmetic and algebra |
| 1804 | Jacquard's punched-card loom |
| 1843 | Ada Lovelace's notes on the Analytical Engine |
| 1890 | Hollerith's tabulators process the US census |
| 1936 | Turing machines and Church's lambda calculus |
| 1945 | ENIAC; von Neumann's EDVAC report |
| 1948 | Manchester Baby runs the first stored program |
| 1951 | Wilkes, Wheeler and Gill publish the first programming textbook |
| 1952 | Hopper's A-0 and Glennie's Autocode |
| 1957 | FORTRAN |
| 1958–60 | LISP, COBOL, ALGOL 60 |
| 1967 | Simula 67 introduces classes and objects |
| 1968 | NATO software engineering conference; "Go To Statement Considered Harmful" |
| 1972 | C, Smalltalk, Prolog |
| 1985 | C++ |
| 1991 | Python |
| 1995 | Java and JavaScript |
| 2015 | Rust 1.0 |

## Why the history matters

Almost every habit of modern programming is the answer to a problem someone hit
earlier. We store programs in memory because rewiring ENIAC was unbearable. We
use high-level languages because FORTRAN proved compilers could compete with
hand-written code. We write loops instead of `goto` because Dijkstra showed we
could not otherwise reason about our programs. We fuss over memory safety
because decades of C taught us what its absence costs.

The machines have changed beyond recognition since Lovelace's notes, but the
job has not: understand a process well enough to describe it with complete
precision, and organise that description so that people — including your future
self — can still understand it.

## References

[^sicp]: Abelson, H., Sussman, G. J., & Sussman, J. (1996). *Structure and Interpretation of Computer Programs* (2nd ed.). MIT Press. Chapter 1.

[^knuth]: Knuth, D. E. (1997). *The Art of Computer Programming, Vol. 1: Fundamental Algorithms* (3rd ed.). Addison-Wesley. Section 1.1.

[^wirth76]: Wirth, N. (1976). *Algorithms + Data Structures = Programs*. Prentice-Hall.

[^jacquard]: Computer History Museum. (n.d.). 1801: Punched cards control Jacquard loom. *The Storage Engine*. <https://www.computerhistory.org/storageengine/punched-cards-control-jacquard-loom/>

[^ceruzzi]: Ceruzzi, P. E. (2012). *Computing: A Concise History*. MIT Press.

[^lovelace]: Menabrea, L. F. (1843). Sketch of the Analytical Engine invented by Charles Babbage, with notes by the translator, A. A. Lovelace. *Scientific Memoirs*, 3, 666–731. (Original work published 1842)

[^turing]: Turing, A. M. (1936). On computable numbers, with an application to the Entscheidungsproblem. *Proceedings of the London Mathematical Society*, s2-42(1), 230–265. <https://doi.org/10.1112/plms/s2-42.1.230>

[^church]: Church, A. (1936). An unsolvable problem of elementary number theory. *American Journal of Mathematics*, 58(2), 345–363. <https://doi.org/10.2307/2371045>

[^plankalkul]: Bauer, F. L., & Wössner, H. (1972). The "Plankalkül" of Konrad Zuse: A forerunner of today's programming languages. *Communications of the ACM*, 15(7), 678–685. <https://doi.org/10.1145/361454.361515>

[^light]: Light, J. S. (1999). When computers were women. *Technology and Culture*, 40(3), 455–483.

[^vonneumann]: von Neumann, J. (1945). *First Draft of a Report on the EDVAC*. Moore School of Electrical Engineering, University of Pennsylvania.

[^lavington]: Lavington, S. (1998). *A History of Manchester Computers* (2nd ed.). British Computer Society.

[^wwg]: Wilkes, M. V., Wheeler, D. J., & Gill, S. (1951). *The Preparation of Programs for an Electronic Digital Computer, with Special Reference to the EDSAC and the Use of a Library of Subroutines*. Addison-Wesley Press.

[^hopper]: Hopper, G. M. (1952). The education of a computer. *Proceedings of the 1952 ACM National Meeting (Pittsburgh)*, 243–249. <https://doi.org/10.1145/609784.609818>

[^knuthpardo]: Knuth, D. E., & Trabb Pardo, L. (1980). The early development of programming languages. In N. Metropolis, J. Howlett, & G.-C. Rota (Eds.), *A History of Computing in the Twentieth Century* (pp. 197–273). Academic Press.

[^backus]: Backus, J. (1978). The history of FORTRAN I, II, and III. *ACM SIGPLAN Notices*, 13(8), 165–180. <https://doi.org/10.1145/960118.808380>

[^mccarthy]: McCarthy, J. (1960). Recursive functions of symbolic expressions and their computation by machine, Part I. *Communications of the ACM*, 3(4), 184–195. <https://doi.org/10.1145/367177.367199>

[^algol]: Naur, P. (Ed.). (1960). Report on the algorithmic language ALGOL 60. *Communications of the ACM*, 3(5), 299–314. <https://doi.org/10.1145/367236.367262>

[^nato]: Naur, P., & Randell, B. (Eds.). (1969). *Software Engineering: Report on a Conference Sponsored by the NATO Science Committee, Garmisch, Germany, 7–11 October 1968*. NATO Scientific Affairs Division, Brussels.

[^dijkstra]: Dijkstra, E. W. (1968). Go to statement considered harmful. *Communications of the ACM*, 11(3), 147–148. <https://doi.org/10.1145/362929.362947>

[^simula]: Dahl, O.-J., & Nygaard, K. (1966). SIMULA — an ALGOL-based simulation language. *Communications of the ACM*, 9(9), 671–678. <https://doi.org/10.1145/365813.365819>

[^kay]: Kay, A. C. (1993). The early history of Smalltalk. *ACM SIGPLAN Notices*, 28(3), 69–95. <https://doi.org/10.1145/155360.155364>

[^ritchie]: Ritchie, D. M. (1993). The development of the C language. *ACM SIGPLAN Notices*, 28(3), 201–208. <https://doi.org/10.1145/155360.155580>

[^pascal]: Wirth, N. (1971). The programming language Pascal. *Acta Informatica*, 1(1), 35–63. <https://doi.org/10.1007/BF00264291>

[^stroustrup]: Stroustrup, B. (1994). *The Design and Evolution of C++*. Addison-Wesley.

[^python]: van Rossum, G. (2009, January 20). A Brief Timeline of Python. *The History of Python*. <https://python-history.blogspot.com/2009/01/brief-timeline-of-python.html>

[^js]: Wirfs-Brock, A., & Eich, B. (2020). JavaScript: The first 20 years. *Proceedings of the ACM on Programming Languages*, 4(HOPL), Article 77. <https://doi.org/10.1145/3386327>

[^rust]: The Rust Core Team. (2015, May 15). Announcing Rust 1.0. *The Rust Programming Language Blog*. <https://blog.rust-lang.org/2015/05/15/Rust-1.0/>
