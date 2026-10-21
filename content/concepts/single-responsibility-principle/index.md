---
title: "What Is the Single Responsibility Principle? Reasons to Change, Actors and Cohesion"
description: "The single responsibility principle says a module should have one reason to change, and a reason to change turns out to be a person: the actor who asks for it. Here is what the principle means, where it came from, from Parnas's modules and Constantine's cohesion to Martin's actors, how the SOLID acronym was born, what goes wrong when one class answers to several people, with runnable examples, how to find the actors, how far to split, and when it is worth it."
date: 2026-10-21T00:01:00Z
categories: ["Concepts"]
tags: ["SOLID", "Single Responsibility Principle", "Cohesion", "Software Design", "Object-Oriented Design", "Concepts"]
series: ["SOLID"]
seriesOrder: 1
seriesGroup: "The five principles"
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

An online shop has an `Order` class. Finance uses it to book revenue, the
storefront uses it to print receipts, and the platform team uses it to store
orders in the database. One day the storefront asks for receipts to show prices
with VAT, a developer makes the change in the obvious place, every test the
storefront cares about passes, and at the end of the month finance's revenue is
twenty per cent too high. Nobody touched finance's code. They touched code that
finance *shared*. The **single responsibility principle** is the rule that
would have kept those two apart, and it is the most quoted and least understood
of the five SOLID principles. This is the first part of a series on SOLID: it
explains what the principle says, where it came from, how the acronym itself
was born, what it looks like in running code, and how far to take it. Every
output shown here was produced by running the code on Windows 11, with Python
3.14.6, not written by hand.

## What the single responsibility principle is

**The single responsibility principle (SRP) says that a module should have one,
and only one, reason to change, where a reason to change is a person or group
of people, an actor, who can ask for it to change.** A module that serves one
actor changes only when that actor's needs change. A module that serves several
can be broken for one of them by a change requested by another.

Robert C. Martin, who named the principle, has stated it three ways over twenty
years, and the differences are the best guide to what it means:

| Year | Statement | Source |
|---|---|---|
| 2003 | A class should have only one reason to change | *Agile Software Development, Principles, Patterns, and Practices*[^asd] |
| 2014 | Gather together the things that change for the same reasons; separate those that change for different reasons | "The Single Responsibility Principle", Clean Coder blog[^blog2014] |
| 2017 | A module should be responsible to one, and only one, actor | *Clean Architecture*[^cleanarch] |

The first statement leaves open what counts as a *reason*. A bug fix? A
refactoring? A faster database driver? Martin's 2014 post answers that the
reasons are people: in his words, "this principle is about people". A module
should answer to one business function, the people whose needs drive its
behaviour, and not to several at once.[^blog2014] The 2017 statement makes
that the definition, and gives those people a name: the **actor**, a group of
one or more stakeholders or users who would want the same change.[^cleanarch]
The middle statement shows the other half of the principle, the half that is
often forgotten: it is as much a rule about what to keep *together* as about
what to pull apart.

### It is not "do one thing"

The name invites a misreading. "Single responsibility" sounds like "does one
thing", and a great deal of code has been split into tiny classes in its name.
Martin addresses this directly in *Clean Architecture*: there is a rule that a
function should do one, and only one, thing, and it is a good rule for
refactoring large functions into small ones, but it is a rule about functions,
and it is not the single responsibility principle.[^cleanarch]

The difference matters in practice. A `ReceiptPrinter` that formats lines,
works out VAT and lays out a footer does three things, and that is fine, because
all three change when the storefront wants receipts to look different and for
no other reason. An `Order` class that does only one thing, holding an order,
but whose methods are used by finance, the storefront and the platform team,
has three reasons to change. The test is not *how many things does this do* but
*who would ask for it to change*.

## A short history

### Before the name: modules, concerns and cohesion

The idea is older than the name by about thirty years. In 1972 David Parnas
compared two ways of dividing the same program into modules and argued that the
better one did not follow the steps of the processing but the decisions that
were hard or likely to change: each module should hide one such decision from
the rest.[^parnas] Two years later Edsger Dijkstra wrote of studying one aspect
of a problem at a time, its correctness, its efficiency, whether it was the
right thing to build, while treating the others as irrelevant for the moment,
and called that "the separation of concerns".[^dijkstra]

Larry Constantine had meanwhile been working out the twin measures of a good
module, **coupling**, how much it depends on others, and **cohesion**, how
closely its own parts belong together. The 1974 paper "Structured design", by
Wayne Stevens, Glenford Myers and Constantine, set them out for a wide
audience.[^smc] Tom DeMarco and Meilir Page-Jones carried them into the
structured analysis and design books of the following years.[^demarco][^pagejones]

### The name

Martin gathered these ideas into a principle in the late 1990s. He has written
that he may have taken the name from Bertrand Meyer, but has not been able to
confirm it.[^blog2014] The principle appeared in print in his 2003 book *Agile
Software Development, Principles, Patterns, and Practices*, where the chapter
opens by crediting DeMarco and Page-Jones with the idea, under the name
cohesion, and then shifts its meaning: from how closely the elements of a module
are related to the forces that cause the module to change.[^asd] There a
responsibility *is* a reason to change, and each responsibility is an **axis of
change**: when the requirements move along it, the class that holds the
responsibility has to move too. The chapter's examples are still the classic
ones: a `Rectangle` that both computes its area and draws itself, used by one
application that does geometry and another that draws, and a `Modem` interface
that mixes managing a connection with sending data over it.[^asd]

### Where SOLID came from

The single responsibility principle is the first letter of an acronym that was
assembled after the principles themselves. Martin wrote up most of the others
first, in a run of columns for *The C++ Report* in 1996: the open-closed
principle was the first of them, and the dependency inversion principle followed
later that year.[^ocp96][^dip96] In 2000 his paper "Design Principles and Design
Patterns" collected them. It began with the symptoms of a rotting design,
**rigidity**, **fragility**, **immobility** and **viscosity**, and set out the
open-closed, Liskov substitution, dependency inversion and interface segregation
principles for classes, followed by principles for packages.[^ddp] The single
responsibility principle is not among them. It joined the other four in the
2003 book.[^asd]

The word came last. Martin recalls that in 2004 or thereabouts Michael Feathers
emailed him to point out that if the principles were put in a different order,
their initials spelled SOLID.[^infoq] The order the acronym imposes is the order
of this series: [single responsibility](../single-responsibility-principle/),
[open-closed](../open-closed-principle/), [Liskov
substitution](../liskov-substitution-principle/), [interface
segregation](../interface-segregation-principle/) and [dependency
inversion](../dependency-inversion-principle/), followed by [inversion of
control](../inversion-of-control/), the mechanism that puts the last of them to
work.

### People, not code

Because "reason to change" was so often read as "thing it does", Martin
returned to the principle twice. The 2014 blog post tied reasons to the people
who ask for changes, using an `Employee` class whose pay calculation belongs to
the chief financial officer, whose hours report belongs to the chief operating
officer and whose persistence belongs to the chief technology officer.[^blog2014]
*Clean Architecture*, published in 2017, restated the principle in terms of
actors and named the two symptoms of breaking it, **accidental duplication** and
**merges**, both shown [below](#reasons-to-change-are-people).[^cleanarch] In
2020 he added that splitting a system into microservices does not settle the
matter: a service can mix code that changes for different reasons just as a
class can.[^relevance]

### A timeline at a glance

| Year | Event |
|---|---|
| 1972 | Parnas argues that modules should hide the decisions likely to change |
| 1974 | Stevens, Myers and Constantine publish "Structured design", with coupling and cohesion; Dijkstra names the separation of concerns |
| 1979 | DeMarco's *Structured Analysis and System Specification* |
| 1996 | Martin's *C++ Report* columns on the open-closed and dependency inversion principles, among others |
| 2000 | Martin's "Design Principles and Design Patterns" collects four of the five |
| 2003 | *Agile Software Development* states the single responsibility principle: one reason to change |
| c. 2004 | Michael Feathers notices the initials spell SOLID |
| 2014 | Martin's blog post: the reasons to change are people |
| 2017 | *Clean Architecture*: a module should be responsible to one actor |

## Reasons to change are people

The `Order` class from the opening is short enough to show in full. Its three
public methods belong to three different actors, and two of them share a
private helper, because both needed "the amount for a line" and it seemed
wasteful to write that twice:

```python
from dataclasses import dataclass

VAT = 0.20


@dataclass
class Line:
    sku: str
    qty: int
    unit_price: float  # net of VAT


class Order:
    """One class, three audiences: finance, the storefront and the platform team."""

    def __init__(self, number, lines):
        self.number = number
        self.lines = lines

    # Finance: revenue is booked net of VAT.
    def revenue(self):
        return round(sum(self._line_amount(line) for line in self.lines), 2)

    # Storefront: the receipt the customer sees.
    def receipt(self):
        rows = [f"  {line.qty} x {line.sku:<6} {self._line_amount(line):>7.2f}"
                for line in self.lines]
        return "\n".join([f"Receipt for order {self.number}", *rows])

    # Platform team: how the order is stored.
    def save(self, db):
        db[self.number] = [(l.sku, l.qty, l.unit_price) for l in self.lines]

    # Shared by revenue() and receipt(), because both needed "the line amount".
    def _line_amount(self, line):
        return round(line.qty * line.unit_price, 2)


order = Order("A-1001", [Line("mug", 2, 8.00), Line("teapot", 1, 24.50)])
db = {}
order.save(db)
print(order.receipt())
print(f"revenue booked: {order.revenue():.2f}")
print("stored:", db)
```

```txt
Receipt for order A-1001
  2 x mug      16.00
  1 x teapot   24.50
revenue booked: 40.50
stored: {'A-1001': [('mug', 2, 8.0), ('teapot', 1, 24.5)]}
```

Now the storefront asks for receipts to show prices including VAT, as shops
selling to consumers usually must. The developer looks at `receipt`, sees that
the amounts come from `_line_amount`, and changes that one line:

```python
    def _line_amount(self, line):
        return round(line.qty * line.unit_price * (1 + VAT), 2)
```

Running the same script with only that method changed prints:

```txt
Receipt for order A-1001
  2 x mug      19.20
  1 x teapot   29.40
revenue booked: 48.60
stored: {'A-1001': [('mug', 2, 8.0), ('teapot', 1, 24.5)]}
```

The receipt is exactly what the storefront asked for. The revenue line is
wrong: finance books revenue net of VAT, and it has just started booking the
tax as income. Nothing in the change mentioned finance, the developer had no
reason to look at `revenue`, and a test written for the storefront's request
would pass. The class did one thing, hold an order, and still had two reasons
to change, because two actors depended on the same line of code.

{{< diagram src="actors.svg" caption="Three actors, one class. Finance and the storefront both reach the same private helper, so a change made for one of them reaches the other." >}}

### The first symptom: accidental duplication

Martin calls this **accidental duplication**.[^cleanarch] `revenue` and
`receipt` both needed a line amount, the two amounts happened to be computed
the same way on the day the class was written, and so the computation was
shared. But they were never the same rule. One was finance's definition of
revenue and the other was the storefront's definition of what a customer sees.
They looked identical only until one of their owners changed their mind.

### The second symptom: merges

The other symptom is organisational. If finance asks for discounts to be
booked separately and the storefront asks for a SKU column on the receipt in
the same sprint, two developers on two teams edit the same file for unrelated
reasons, and their changes meet in a merge. Most merges go through cleanly;
the risk is the one that does not, or the one that goes through cleanly and
combines two changes that each made sense alone.[^cleanarch] A file that keeps
appearing in merge conflicts between teams that do not otherwise work together
is a strong sign that it answers to more than one of them.

## Separating the actors

The fix is to give each actor its own code. The data, an order and its lines,
is shared, because every actor needs it, but it becomes a plain structure that
no actor's rules live in. Each actor's behaviour moves into a class of its own,
with its own private helpers:

```python
from dataclasses import dataclass

VAT = 0.20


@dataclass(frozen=True)
class Line:
    sku: str
    qty: int
    unit_price: float  # net of VAT


@dataclass(frozen=True)
class OrderData:
    """Plain data. Every actor's code reads it; none of them owns it."""
    number: str
    lines: tuple


class RevenueCalculator:  # answers to finance
    def revenue(self, order):
        return round(sum(self._net(line) for line in order.lines), 2)

    def _net(self, line):
        return round(line.qty * line.unit_price, 2)


class ReceiptPrinter:  # answers to the storefront
    def receipt(self, order):
        rows = [f"  {line.qty} x {line.sku:<6} {self._shown(line):>7.2f}"
                for line in order.lines]
        return "\n".join([f"Receipt for order {order.number}", *rows])

    def _shown(self, line):  # the storefront's change lands here, and only here
        return round(line.qty * line.unit_price * (1 + VAT), 2)


class OrderRepository:  # answers to the platform team
    def __init__(self, db):
        self.db = db

    def save(self, order):
        self.db[order.number] = [(l.sku, l.qty, l.unit_price) for l in order.lines]


class Orders:
    """An optional facade, for callers that want one object to talk to."""

    def __init__(self, db):
        self.revenue = RevenueCalculator().revenue
        self.receipt = ReceiptPrinter().receipt
        self.save = OrderRepository(db).save


order = OrderData("A-1001", (Line("mug", 2, 8.00), Line("teapot", 1, 24.50)))
db = {}
orders = Orders(db)
orders.save(order)
print(orders.receipt(order))
print(f"revenue booked: {orders.revenue(order):.2f}")
print("stored:", db)
```

```txt
Receipt for order A-1001
  2 x mug      19.20
  1 x teapot   29.40
revenue booked: 40.50
stored: {'A-1001': [('mug', 2, 8.0), ('teapot', 1, 24.5)]}
```

This version already has the storefront's VAT change in it, and finance's
revenue is still 40.50. The change was made in `ReceiptPrinter._shown`, a
method finance's code cannot reach. Each class now has exactly one actor who
can ask for it to change, and a developer working on a request from that actor
can read the whole of the code that request could affect.

{{< diagram src="split.svg" caption="After the split: one class per actor, each with its own helpers, all reading a plain data structure. The facade is optional and holds no rules of its own." >}}

The `Orders` facade is the part of Martin's solution that answers the usual
objection, that callers now have three objects to find instead of one.[^cleanarch]
It holds no rules: it only forwards to the three classes, so it has no reason
to change except that a method was added or removed. Whether to have it at all
is a matter of taste; many codebases simply inject the class each caller needs,
which is what the [dependency inversion](../dependency-inversion-principle/) and
[inversion of control](../inversion-of-control/) parts of this series are
about.

### Duplication that is not duplication

The split version contains two methods, `_net` and `_shown`, that started life
as the same line of code, and a reviewer trained to remove duplication will want
to merge them again. That instinct comes from the DRY principle, *don't repeat
yourself*, from Andy Hunt and Dave Thomas's *The Pragmatic Programmer*. But
Thomas has said that DRY is widely misread as a rule against duplicated code,
when it is a rule about duplicated *knowledge*: every piece of knowledge in a
system should have one authoritative representation.[^dry] Finance's definition
of a line's revenue and the storefront's definition of a line's displayed price
are two pieces of knowledge that briefly had the same text. Merging them is not
removing duplication; it is creating the coupling the example above broke on.
The question to ask of two similar pieces of code is whether they would always
have to change together, and that is a question about who owns them.

## Finding the actors

The hard part of the principle is not splitting a class once the actors are
known but knowing who they are. The code does not say; the organisation does.
One practical source is the history of changes. If each change request is
recorded with who asked for it and what it touched, the methods that answer to
more than one actor fall out of a few lines of code:

```python
from collections import defaultdict

# A year of change requests against Order: who asked, and what each one touched.
changes = [
    ("finance",    "book discounts as a separate line", {"revenue", "_line_amount"}),
    ("storefront", "show prices with VAT",              {"receipt", "_line_amount"}),
    ("storefront", "add a SKU column to the receipt",   {"receipt"}),
    ("platform",   "move orders to PostgreSQL",         {"save"}),
    ("finance",    "round per order, not per line",     {"revenue", "_line_amount"}),
    ("platform",   "add created_at to stored orders",   {"save"}),
]

askers = defaultdict(set)
for actor, _, touched in changes:
    for method in touched:
        askers[method].add(actor)

for method in sorted(askers):
    who = sorted(askers[method])
    flag = "  <- answers to more than one actor" if len(who) > 1 else ""
    print(f"{method:<13} {', '.join(who)}{flag}")
```

```txt
_line_amount  finance, storefront  <- answers to more than one actor
receipt       storefront
revenue       finance
save          platform
```

Real projects rarely have their history labelled this neatly, but most have
something close: an issue tracker, commit messages that name a ticket, or the
memory of whoever reviews the changes. Without any of that, a few questions
usually find the actors:

- **Who would ask for this to change?** Name the role, not the person: the
  accountant and the database administrator may be the same employee, but they
  are different actors.[^cleanarch]
- **Who would be blamed if it were wrong?** Martin's blunter version of the
  same question is who would be held to account if the behaviour were badly
  mis-specified.[^blog2014]
- **Does it change at a different rate?** Business rules tend to change often,
  persistence less often and for unrelated reasons, which is why Martin calls
  mixing the two a common violation.[^asd]
- **Would it be released separately?** Code that two teams want to ship on two
  schedules is code that answers to two actors.

### Only when the change is real

Martin's own book adds a corollary that is easy to skip. Discussing the `Modem`
interface, which mixes dialling and hanging up with sending and receiving, he
asks whether the two should be separated, and answers that it depends on how
the application is actually changing. If the connection functions and the data
functions never change at different times, splitting them only adds what he
calls **needless complexity**. An axis of change, he writes, is only an axis of
change if the changes actually occur, and no principle should be applied where
there is no symptom.[^asd] The principle is a reason to split when two actors
are pulling one module in different directions, not a licence to guess at every
actor who might one day exist.

## Cohesion and fragmentation

Read as "gather together the things that change for the same reasons", the
principle cuts both ways. It condemns the **god class**, the `Order` or
`Customer` or `Manager` that every part of the system reaches into, because such
a class answers to everyone. But it equally condemns the opposite failure, a
design shattered into dozens of one-method classes, each too small to mean
anything, so that one change from one actor has to be made in seven files.
That is low cohesion of a different kind: things that change for the same
reason have been separated.

| Too little separation | About right | Too much separation |
|---|---|---|
| One class answers to several actors | Each module answers to one actor and holds everything that actor's changes touch | One actor's change is spread across many tiny classes |
| A change for one actor breaks another | A change for one actor stays in one place | A change for one actor needs edits in many places |
| Merge conflicts between unrelated teams | Teams rarely edit the same files | Every change is a scavenger hunt |

The middle column is cohesion in Constantine's sense, restated in terms of
change. Neither extreme is reached by counting methods or lines; both are
reached by losing sight of who the code is for.

## The principle at every scale

The same question, *who would ask for this to change*, applies at every level
of a system. Martin notes that the principle reappears at larger scales under
other names, and below the class it gives way to a different rule.[^cleanarch]

{{< diagram src="scales.svg" caption="The same question at four nested scales. Only at the level of classes and modules is it the single responsibility principle; above that it has other names, and below it the rule is a different one." >}}

- **Functions.** The rule here is the one SRP is mistaken for: a function should
  do one thing. It is a good rule, and a different one.
- **Classes and modules.** This is where the single responsibility principle
  itself applies: one actor, one reason to change.
- **Components and packages.** Martin's 2000 paper gives the package-level form
  as the **common closure principle**: classes that change together belong
  together, so that a change touches as few released packages as
  possible.[^ddp]
- **Services and systems.** In 1968 Melvin Conway observed that organisations
  tend to design systems whose structure copies their own communication
  structure.[^conway] The observation, now called **Conway's law**, is the
  single responsibility principle seen from the other side: if each team is an
  actor, a system whose boundaries match the teams lets each one change its
  part without asking the others. A service that two teams both have to change
  for different reasons has the `Order` class's problem at a larger scale, and,
  as Martin points out, splitting a system into microservices does not by itself
  prevent it.[^relevance]

## How it relates to the rest of SOLID

The single responsibility principle is about where the boundaries go. The
other four are largely about what happens at those boundaries once they exist.

- The [open-closed principle](../open-closed-principle/) asks that a module be
  extendable without being edited. A module that answers to one actor is the
  only kind for which that is a realistic goal, since its likely changes are
  known.
- The [Liskov substitution principle](../liskov-substitution-principle/) governs
  the contracts between a type and its subtypes, which only stay simple when
  each type has one job to keep.
- The [interface segregation principle](../interface-segregation-principle/) is
  close kin: it applies the same thinking to interfaces, from the side of the
  clients that use them, so that no client depends on methods only another
  client needs.
- The [dependency inversion principle](../dependency-inversion-principle/), and
  [inversion of control](../inversion-of-control/) as its mechanism, decide how
  the separated pieces find each other without being tied back together.

## What it costs and what it buys

| It buys | It costs |
|---|---|
| **Isolation of change.** A request from one actor can only break code that actor owns | **More types.** One class becomes several, plus perhaps a facade, and a reader has more names to learn |
| **Smaller blast radius in review.** Everything a change could affect is in one place | **Judgement.** The actors are not in the code, and finding them means knowing the organisation |
| **Fewer merge conflicts.** Teams that answer to different people stop editing the same files | **Apparent duplication.** Code that looks alike but belongs to different actors stays separate, and has to be defended in review |
| **Clearer ownership.** Each module has an obvious person to ask about it | **Risk of over-splitting.** Applied by reflex, it produces fragments that scatter one actor's change across many files |
| **Easier testing.** Each actor's rules can be tested without the others' setup | **Indirection.** Callers may need a facade or injection to find the pieces again |

The costs are the reason to wait for the symptom. A class that serves one actor
today needs nothing. A class that has broken one actor's behaviour while
serving another, or that keeps turning up in merge conflicts between unrelated
teams, is worth splitting along the line between them.

## When to use it

- **Ask who the code is for, not what it does.** When designing or reviewing a
  module, name the actors who would ask for it to change. One actor is the
  target; two is a question worth answering; three is usually a split waiting
  to happen.
- **Keep business rules and persistence apart from the start.** They answer to
  different people and change at different rates, so this split rarely turns
  out to be premature.
- **Split on evidence elsewhere.** Wait for the symptom, a change for one actor
  that breaks another, or repeated merges between teams, before separating
  responsibilities that might never diverge.
- **Do not merge code just because it looks alike.** Before removing
  duplication, check that the two copies belong to the same actor and would
  always change together.
- **Keep one actor's change in one place.** If the same request keeps needing
  edits in many small classes, the split has gone too far; gather them back
  together.
- **Use the same lens on packages and services.** If two teams must coordinate
  to change one component or one service for unrelated reasons, its boundary is
  in the wrong place.

## Why it matters

Software is changed far more often than it is written, and most of those
changes are requested by someone: an accountant, a product manager, a
regulator, an operations team. The single responsibility principle takes that
fact seriously. It says that the structure of the code should follow the
structure of the requests, so that a change asked for by one person cannot
quietly break the work of another, and so that a developer handling a request
can see everything it might touch. Read that way, it is less a rule about the
size of classes than a rule about trust: each part of the system keeps faith
with the people who depend on it. It is also the foundation the rest of SOLID
stands on, which is why it comes first in the acronym and in this series. The
[next part](../open-closed-principle/) asks what to do once a module has one
reason to change: how to let it grow without editing it.

## References

[^asd]: Martin, R. C. (2003). *Agile Software Development, Principles, Patterns, and Practices*. Prentice Hall.

[^blog2014]: Martin, R. C. (2014, May 8). The single responsibility principle. *The Clean Code Blog*. <https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html>

[^cleanarch]: Martin, R. C. (2017). *Clean Architecture: A Craftsman's Guide to Software Structure and Design*. Prentice Hall. Chapter 7, "SRP: The Single Responsibility Principle".

[^parnas]: Parnas, D. L. (1972). On the criteria to be used in decomposing systems into modules. *Communications of the ACM*, 15(12), 1053–1058. <https://doi.org/10.1145/361598.361623>

[^dijkstra]: Dijkstra, E. W. (1974, August 30). *On the role of scientific thought* (EWD447). E. W. Dijkstra Archive, University of Texas at Austin. <https://www.cs.utexas.edu/~EWD/transcriptions/EWD04xx/EWD447.html>

[^smc]: Stevens, W. P., Myers, G. J., & Constantine, L. L. (1974). Structured design. *IBM Systems Journal*, 13(2), 115–139. <https://doi.org/10.1147/sj.132.0115>

[^demarco]: DeMarco, T. (1979). *Structured Analysis and System Specification*. Prentice Hall.

[^pagejones]: Page-Jones, M. (1988). *The Practical Guide to Structured Systems Design* (2nd ed.). Yourdon Press.

[^ocp96]: Martin, R. C. (1996, January). The open-closed principle. *The C++ Report*. <https://courses.cs.duke.edu/compsci308/spring22/readings/ocp.pdf>

[^dip96]: Martin, R. C. (1996). The dependency inversion principle. *The C++ Report*. <https://cs.utexas.edu/~downing/papers/DIP-1996.pdf>

[^ddp]: Martin, R. C. (2000). *Design Principles and Design Patterns*. Object Mentor.

[^infoq]: Reisz, W. (Host). (2018, August 24). Uncle Bob Martin on clean software, craftsperson, origins of SOLID, DDD, & software ethics [Audio podcast episode]. In *The InfoQ Podcast*. InfoQ. <https://www.infoq.com/podcasts/uncle-bob-solid-ddd/>

[^relevance]: Martin, R. C. (2020, October 18). Solid relevance. *The Clean Code Blog*. <https://blog.cleancoder.com/uncle-bob/2020/10/18/Solid-Relevance.html>

[^dry]: Venners, B. (2003, March 10). Orthogonality and the DRY principle: A conversation with Andy Hunt and Dave Thomas, part II. *Artima Developer*. <https://www.artima.com/articles/orthogonality-and-the-dry-principle>

[^conway]: Conway, M. E. (1968). How do committees invent? *Datamation*, 14(4), 28–31. <https://www.melconway.com/Home/Committees_Paper.html>
