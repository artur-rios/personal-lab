---
title: "What Is the Open-Closed Principle? Extension, Abstraction, Plug-ins and the Expression Problem"
description: "The open-closed principle says that a module should be open to new behaviour and closed to edits of the code that already works. Here is what that means, where it came from, from Meyer's inheritance to Martin's abstractions and Larman's protected variation, how it looks in running code, why no module can be closed against every change, how the expression problem sets its limits, and when the abstraction is worth paying for."
date: 2026-10-21T00:02:00Z
categories: ["Concepts"]
tags: ["Open-Closed Principle", "SOLID", "Software Design", "Object-Oriented Design", "Design Patterns", "Expression Problem", "Concepts"]
series: ["SOLID"]
seriesOrder: 2
seriesGroup: "The five principles"
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

A shop adds a new way to ship parcels. In one codebase that means opening the
function that prices shipping, adding a branch to the middle of it, and
re-testing everything that calls it. In another it means writing one new class
in one new file, and nothing that already works is touched. The difference
between the two is what the **open-closed principle** is about: arranging code
so that new behaviour arrives as new code, rather than as edits to code that is
released, tested and depended on. It is the second of the five SOLID principles,
and this is part 2 of a series on them, after
[the single responsibility principle](../single-responsibility-principle/).
This article explains what the principle means, where it came from, what it
looks like in running code, why no module can be closed against every change,
how the expression problem sets its limits, and when the abstraction it calls
for is worth paying for. Every output shown here was produced by running the
code on Windows 11, with Python 3.14.6, not written by hand.

## What the open-closed principle is

**The open-closed principle (OCP) says that software entities, such as classes,
modules and functions, should be open for extension but closed for
modification: it should be possible to add to what they do without editing the
code that already does it.** Robert C. Martin's 1996 statement of it, a
paraphrase of Bertrand Meyer, uses nearly those words, and his later summary is
plainer still: the behaviour of a system should be extensible without changing
the system.[^martin1996][^martin2014]

The two halves sound contradictory, and the point of the principle is that
they are not:

- **Open for extension** means the module's behaviour can be made to grow: it
  can be made to handle a new case, a new format, a new rule, as the
  requirements change.
- **Closed for modification** means that growth does not require editing the
  module's source. Code that has been written, reviewed, tested and released,
  and that other code depends on, stays as it is.

The usual way to make code do something new is to change it, so the question is
how a module can gain behaviour without being changed. Martin's 1996 answer is
**abstraction**. A module that works only through an abstraction, an interface
or an abstract base class, is fixed in its own source, yet the set of behaviours
it can drive is unbounded, because anyone can write a new implementation of
that abstraction.[^martin1996]

### Closed does not mean frozen

The slogan is easy to read too literally. Martin later wrote that his 1996
article had overstated the "closed" half as a sound-bite, and that the article
itself had already said no significant program can be fully closed. His own
gentler wording is that it should be easy to change what a module does without
changing the module's source code.[^martin2013] Bugs still get fixed and
designs still get refactored. The principle is about the common case, *adding*
a feature, and asks that it be mostly a matter of adding code, not about
forbidding edits altogether.

## A short history

### 1972: hiding what is likely to change

The idea is older than its name. In 1972 David Parnas argued, in "On the
Criteria To Be Used in Decomposing Systems into Modules", that a system should
not be split into modules by the steps of its processing, but by its design
decisions: start from the decisions that are difficult or likely to change, and
give each module one of them to hide from the others.[^parnas] That is
**information hiding**, and it is the root of the open-closed principle. A
module that hides a decision behind a stable interface can have that decision
changed without its clients being touched.

### 1988: Meyer and inheritance

Bertrand Meyer coined the name in *Object-Oriented Software Construction* in
1988.[^meyer] His concern was a practical one. A module that other modules use
should be *closed*: compiled, stable and available for use, with a well-defined
interface. But the same module should stay *open*: available for extension,
for adding fields or operations that new needs call for. In a language without
classes those pull in opposite directions, since adding to a library usually
meant editing it, and editing it disturbed everything that depended on it.

Meyer's resolution was **implementation inheritance**. A class can be closed,
compiled and used by its clients, and still be open, because a new class can
inherit from it and add features. The original is never edited, so its clients
are never disturbed. The principle returned in the book's much expanded second
edition of 1997.[^meyer]

### 1996: Martin and abstraction

In January 1996 Robert C. Martin opened his *Engineering Notebook* column in
*The C++ Report* with an article on the principle.[^martin1996] He set it as the
source of familiar rules of thumb, such as keeping member variables private,
avoiding global variables and distrusting run-time type checks, and recast it
around polymorphism rather than code reuse. His example was a C function that
drew a list of shapes with a `switch` on each shape's type, and so had to be
edited for every new shape, against a C++ version that called a virtual `Draw`
on an abstract `Shape`, which did not. In Martin's version the thing that stays
closed is not a reusable base class but an **abstract interface**; the
implementations behind it are what vary. This is the reading of the principle
most people learn today, and the one in which it takes its place as the *O* in
SOLID.

The same article added the caveat that keeps the principle honest: no
significant program can be completely closed, so closure has to be
**strategic**, chosen for the kinds of change the designer judges most
likely.[^martin1996] The [section on strategic closure](#strategic-closure)
below comes back to it.

### 1998: the expression problem

In November 1998 Philip Wadler sent a message titled "The Expression Problem"
to the Java-genericity mailing list. It described a challenge: define a data
type by its cases, then add both new cases and new functions over it, without
recompiling existing code and without giving up static type safety.[^wadler]
It is the open-closed principle stated as a test a language can pass or fail,
and most languages fail it in one direction or the other. The
[section on the expression problem](#the-expression-problem) shows why.

### 2001: protected variation

In 2001 Craig Larman wrote "Protected Variation: The Importance of Being
Closed" for the design column of *IEEE Software*.[^larman] He argued that the
open-closed principle and Alistair Cockburn's **Protected Variation** pattern
were two expressions of one principle: identify the points where variation is
predicted, and put a stable interface around them. He also argued that this was
what Parnas had really meant by information hiding, a phrase that had since
been worn down into a synonym for data encapsulation. And he warned against the
opposite mistake: protection has a cost, and a good designer applies it to the
likely points of change and not to others.

### The 2010s: plug-ins and a softer reading

In 2013 Martin wrote a short reply to the charge that the principle meant never
editing a source file, and softened the sound-bite of 1996.[^martin2013] In
2014 he described plug-in architectures as the fullest expression of the
principle: an editor, an IDE or a game whose core is never modified or
redeployed, and which is extended by plug-ins that know about the core while
the core knows nothing about them.[^martin2014]

### A timeline at a glance

| Year | Event |
|---|---|
| 1972 | Parnas proposes decomposing systems around the design decisions likely to change |
| 1988 | Meyer names the open-closed principle, achieved through inheritance |
| 1994 | *Design Patterns* catalogues Strategy, Visitor and others that close code against change |
| 1996 | Martin recasts the principle around abstract interfaces and strategic closure |
| 1997 | The second edition of Meyer's book keeps it as a founding principle |
| 1998 | Wadler states the expression problem |
| 2001 | Larman equates it with protected variation and Parnas's information hiding |
| 2013 | Martin answers the reading of "closed" as "never edited" |
| 2014 | Martin presents plug-in architectures as the principle at its fullest |

## The principle in code

### A function that grows with every case

Here is the shipping calculation of a small online shop, written the
straightforward way. One function knows every method and prices each one:

```python
def shipping_cost(order_total, method):
    if method == "standard":
        return 0.00 if order_total >= 50 else 4.99
    elif method == "express":
        return 12.00
    elif method == "pickup":
        return 0.00
    else:
        raise ValueError(f"unknown shipping method: {method!r}")


for method in ("standard", "express", "pickup"):
    print(f"{method:<9} on 30.00: {shipping_cost(30.00, method):5.2f}")
print(f"standard  on 80.00: {shipping_cost(80.00, 'standard'):5.2f}")

try:
    shipping_cost(30.00, "locker")
except ValueError as error:
    print("ValueError:", error)
```

```txt
standard  on 30.00:  4.99
express   on 30.00: 12.00
pickup    on 30.00:  0.00
standard  on 80.00:  0.00
ValueError: unknown shipping method: 'locker'
```

Nothing is wrong with this code today. It is short, it is clear, and it works.
The trouble is what happens on the day the shop adds parcel lockers. The only
way to support them is to open `shipping_cost` and add a branch to it, and the
same goes for every other place in the program that asks "which method is
this?" and acts on the answer: the label printer, the delivery estimate, the
returns page. Each new method is a set of edits scattered through code that was
already tested and released, and each edit is a chance to break a method that
used to work. That is the shape the principle warns against: a module that is
open only by being modified.

### Closing it with an abstraction

The open version moves the question "which method is this?" out of the code
that uses the methods. `Checkout` depends only on a `ShippingMethod` protocol,
anything with a `name` and a `cost`, and each method is a class of its own:

```python
# shipping.py
from typing import Protocol


class ShippingMethod(Protocol):
    name: str

    def cost(self, order_total: float) -> float: ...


class Checkout:
    """Closed: written, tested and released once. Knows only the protocol."""

    def __init__(self, methods: list[ShippingMethod]):
        self.methods = {method.name: method for method in methods}

    def quote(self, order_total: float) -> dict[str, float]:
        return {name: method.cost(order_total)
                for name, method in self.methods.items()}

    def cost(self, order_total: float, name: str) -> float:
        if name not in self.methods:
            raise ValueError(f"unknown shipping method: {name!r}")
        return self.methods[name].cost(order_total)


class Standard:
    name = "standard"

    def cost(self, order_total):
        return 0.00 if order_total >= 50 else 4.99


class Express:
    name = "express"

    def cost(self, order_total):
        return 12.00


class Pickup:
    name = "pickup"

    def cost(self, order_total):
        return 0.00
```

Lockers now arrive as a new file. It does not import `Checkout`, and nothing
in `shipping.py` changes to make room for it:

```python
# locker.py
# A new file. shipping.py is not edited, re-tested or even re-read.
class Locker:
    name = "locker"

    def __init__(self, fee=2.50, free_from=30.00):
        self.fee, self.free_from = fee, free_from

    def cost(self, order_total):
        return 0.00 if order_total >= self.free_from else self.fee
```

The only line that has to know about it is in the composition root, the one
place where the program is assembled:

```python
# main.py
# The composition root: the one place that knows every method there is.
from shipping import Checkout, Express, Pickup, Standard
from locker import Locker

before = Checkout([Standard(), Express(), Pickup()])
after = Checkout([Standard(), Express(), Pickup(), Locker()])

print("before:", before.quote(25.00))
print("after: ", after.quote(25.00))
print("locker on 40.00:", after.cost(40.00, "locker"))
```

```txt
before: {'standard': 4.99, 'express': 12.0, 'pickup': 0.0}
after:  {'standard': 4.99, 'express': 12.0, 'pickup': 0.0, 'locker': 2.5}
locker on 40.00: 0.0
```

{{< diagram src="modify-or-extend.svg" caption="Two ways to add lockers. Modifying puts a new branch inside released code; extending adds a class beside the old ones, and `Checkout` never learns its name." >}}

`Checkout` is closed: it has not changed, so its tests still describe it and
nothing that depends on it needs to be looked at again. It is also open: it
priced lockers correctly the first time it was handed one. The design that
makes this work is the **Strategy** pattern from *Design Patterns*, a family of
interchangeable algorithms behind one interface, chosen by whoever builds the
object that uses them.[^gof] Handing the methods in through the constructor,
rather than having `Checkout` import them, is
[dependency injection](../inversion-of-control/#dependency-injection-1), and the
direction of the dependencies, the policy depending on an abstraction and the
details implementing it, is the
[dependency inversion principle](../dependency-inversion-principle/). The
open-closed principle states the goal; those two are much of the means.

There is a condition on all of this, and it belongs to the next principle in
the series. `Checkout` can only stay closed if every new method really behaves
like a shipping method: returns a cost, does not raise for ordinary totals,
does not need to be special-cased. A `Locker` whose `cost` returned `None` for
small orders would force a check back into `Checkout`, and the closure would be
gone. Extensions must be substitutable for the abstraction they extend, which
is the subject of [the Liskov substitution principle](../liskov-substitution-principle/).

### Plug-ins: closure at the scale of a system

The same move, made at the scale of a whole program, is a **plug-in
architecture**. The core defines an interface for extensions and a way of
finding them, and new features are shipped as separate packages that the core
loads without being rebuilt. Martin calls this the apotheosis of the principle,
with editors, IDEs and games such as Minecraft as his examples, and stresses the
direction of knowledge: the plug-ins know about the system, and the system
knows nothing about any plug-in.[^martin2014]

Python's packaging has a standard mechanism for exactly this. An installed
distribution can advertise components in named groups of **entry points**,
and a host application looks up a group at run time to find whatever has been
installed. The specification itself gives the example of Pygments picking up
extra lexers and styles from separately installed packages, and pytest finds
its plug-ins the same way.[^entrypoints] In both, the host is closed in the most
literal sense: it is a released package that its users do not edit, and it is
extended every day.

## Strategic closure

### No module is closed against everything

`Checkout` is closed against one kind of change: a new shipping method. It is
not closed against others. Martin's 1996 article makes the point with his own
shapes example: the version that is closed against new kinds of shape is not
closed against a rule that all circles must be drawn before all squares. No
matter how closed a module is, some change will force it open; since closure
cannot be complete, the designer has to choose which changes to close
against.[^martin1996]

Suppose the shop now wants the cheapest option listed first. `quote` returns
the methods in the order they were registered, and nothing about that order is
behind an abstraction, so the only way to change it is to edit `Checkout`. The
edit is worth making in a way that closes the module against the *next*
ordering request too, by passing the policy in:

```python
# ordering.py: Checkout, edited once for a change it was not closed against
from shipping import Express, Pickup, Standard
from locker import Locker


def as_registered(quotes):
    return quotes


def cheapest_first(quotes):
    return sorted(quotes, key=lambda quote: (quote[1], quote[0]))


class Checkout:
    """Now closed against ordering policies too: the policy is passed in."""

    def __init__(self, methods, order=as_registered):
        self.methods, self.order = list(methods), order

    def quote(self, order_total):
        quotes = [(m.name, m.cost(order_total)) for m in self.methods]
        return self.order(quotes)


methods = [Standard(), Express(), Pickup(), Locker()]
print("as registered: ", Checkout(methods).quote(25.00))
print("cheapest first:", Checkout(methods, cheapest_first).quote(25.00))
```

```txt
as registered:  [('standard', 4.99), ('express', 12.0), ('pickup', 0.0), ('locker', 2.5)]
cheapest first: [('pickup', 0.0), ('locker', 2.5), ('standard', 4.99), ('express', 12.0)]
```

That is closure added after the fact, along the axis on which change has
actually arrived. Other axes remain open. If the cost of shipping starts to
depend on the destination, `cost(order_total)` no longer receives enough to
answer, and the protocol and every implementation of it must change. If prices
must be quoted in two currencies, every method changes again. `Checkout` is
closed against some changes and exposed to others, and that is not a flaw in
the design: it is the only kind of design there is.

{{< diagram src="strategic-closure.svg" caption="Closure is per axis. New methods and new orderings are absorbed by an abstraction before they reach `Checkout`; a change to what a cost depends on goes straight through it." >}}

### Choosing the axis

The skill the principle asks for is therefore not "make everything
extensible" but *predicting which variations are likely*, and Martin
admits that it takes a kind of foresight that only experience
provides.[^martin1996] Larman's version is blunter: pick your battles. He
describes novices drifting towards brittle designs and intermediate designers
towards elaborate, general ones whose flexibility is never used, while experts
sometimes choose the simple, brittle design on purpose, because its cost of
change is low enough for how likely that change is.[^larman]

A few working habits follow from that:

- **Close against change you have seen, not change you can imagine.** The
  first shipping function did not need a protocol. The second time a new method
  arrived, the pattern of change was visible, and the abstraction could be cut
  to fit it. An interface written before any variation exists is a guess about
  its shape, and guesses are usually wrong in the details.
- **Let the domain tell you.** Some axes vary in almost every business: payment
  providers, tax rules, export formats, notification channels. Others almost
  never do. Knowing the business is how one tells them apart.
- **Prefer cheap closure.** Passing a function, as `order=` does, costs a line;
  a class hierarchy, a registry and a plug-in loader cost much more. The
  smallest mechanism that absorbs the change is usually the right one.

Martin Fowler's description of **YAGNI**, "you aren't gonna need it", gives
the economic case against closing too early: a feature, or an abstraction,
built for a need that has not arrived costs the effort of building it, delays
something that is needed, and makes the code harder to change until it is
used or removed, and an abstraction that makes the current code harder to
understand is presumed guilty.[^yagni] The open-closed principle and YAGNI are
not opposed. One says where the joints of a design should be; the other says
not to cut a joint until there is something to bend.

## The expression problem

Every closure has a direction, and the clearest demonstration is the problem
Wadler named. A program works with some kinds of data and some operations on
them. Think of it as a table: the kinds are rows and the operations are
columns. Wadler's observation was that in a functional language the rows are
fixed by the data type's declaration and new columns are easy to add, while in
an object-oriented language the columns are fixed by the class's methods and
new rows are easy to add.[^wadler] Neither style is open in both directions.

### Objects: open to new kinds

In object-oriented code, each kind of thing is a class that carries its own
operations. The shop's basket can hold products, gift cards and, added later,
subscriptions:

```python
# Object-oriented: each kind of line item is a class that carries its operations.
class Product:
    def __init__(self, name, price, quantity):
        self.name, self.price, self.quantity = name, price, quantity

    def total(self):
        return self.price * self.quantity

    def describe(self):
        return f"{self.quantity} x {self.name}"


class GiftCard:
    def __init__(self, amount):
        self.amount = amount

    def total(self):
        return self.amount

    def describe(self):
        return f"gift card {self.amount:.2f}"


# A new kind of item is one new class; nothing above is edited.
class Subscription:
    def __init__(self, plan, monthly, months):
        self.plan, self.monthly, self.months = plan, monthly, months

    def total(self):
        return self.monthly * self.months

    def describe(self):
        return f"{self.plan} plan, {self.months} months"


basket = [Product("pen", 1.50, 4), GiftCard(20.00), Subscription("coffee", 9.00, 3)]
for item in basket:
    print(f"{item.describe():<24} {item.total():6.2f}")

# A new operation, say tax, needs a new method in every class above.
try:
    print(sum(item.tax() for item in basket))
except AttributeError as error:
    print("AttributeError:", error)
```

```txt
4 x pen                    6.00
gift card 20.00           20.00
coffee plan, 3 months     27.00
AttributeError: 'Product' object has no attribute 'tax'
```

Adding `Subscription` was pure extension. Adding `tax` is not: there is no way
to give every item a tax calculation without opening `Product`, `GiftCard` and
`Subscription` and adding a method to each. The design is closed against new
kinds and open, by modification only, to new operations.

### Functions: open to new operations

Turn the table round. With the items as plain data and each operation as a
function that matches on the kind of item, using the structural pattern
matching Python gained in version 3.10,[^pep634] the strengths swap:

```python
# Functional: the kinds of item are plain data; each operation is a function.
from dataclasses import dataclass


@dataclass
class Product:
    name: str
    price: float
    quantity: int


@dataclass
class GiftCard:
    amount: float


def total(item):
    match item:
        case Product(price=price, quantity=quantity):
            return price * quantity
        case GiftCard(amount=amount):
            return amount
    raise TypeError(f"total: no case for {type(item).__name__}")


def describe(item):
    match item:
        case Product(name=name, quantity=quantity):
            return f"{quantity} x {name}"
        case GiftCard(amount=amount):
            return f"gift card {amount:.2f}"
    raise TypeError(f"describe: no case for {type(item).__name__}")


# A new operation is one new function; nothing above is edited.
def tax(item):
    match item:
        case Product():
            return round(total(item) * 0.20, 2)
        case GiftCard():
            return 0.00  # gift cards are taxed when they are spent
    raise TypeError(f"tax: no case for {type(item).__name__}")


basket = [Product("pen", 1.50, 4), GiftCard(20.00)]
for item in basket:
    print(f"{describe(item):<24} {total(item):6.2f}  tax {tax(item):.2f}")


# A new kind of item needs a new case in every function above.
@dataclass
class Subscription:
    plan: str
    monthly: float
    months: int


try:
    total(Subscription("coffee", 9.00, 3))
except TypeError as error:
    print("TypeError:", error)
```

```txt
4 x pen                    6.00  tax 1.20
gift card 20.00           20.00  tax 0.00
TypeError: total: no case for Subscription
```

Now `tax` was pure extension and `Subscription` is the expensive one: every
function needs a new `case`, and any function that is missed fails only when a
subscription finally reaches it.

{{< diagram src="expression-problem.svg" caption="The same table, two ways. Objects make a new row one new class and a new column an edit to every class; functions make a new column one new function and a new row an edit to every function." >}}

This is the deepest reason closure has to be strategic. It is not only that a
designer cannot foresee every change; it is that the two most common kinds of
change, new kinds of thing and new things to do with them, pull the structure
of a program in opposite directions. Choosing classes or functions is, among
other things, choosing which of those the code will be closed against. A shop
that adds payment providers every quarter and rarely adds operations on them
wants classes. A compiler, whose syntax tree rarely gains a node but constantly
gains passes, wants functions over data.

### Visitor, and having both

Object-oriented code can borrow the functional shape when it needs to. The
**Visitor** pattern from *Design Patterns* moves each operation into a visitor
class with one method per kind of element, so that a new operation is a new
visitor, at the cost of every visitor needing a change when a new kind of
element is added.[^gof] It is the functional row-and-column trade, expressed in
classes.

Having both at once is harder, and that is precisely the problem Wadler posed.
Dynamic languages can come close by giving up something he insisted on.
Python's `functools.singledispatch` turns a function into a generic function
that dispatches on the type of its first argument, and new implementations can
be registered for new types from any module.[^singledispatch] Both new kinds and
new operations become additions:

```python
from dataclasses import dataclass
from functools import singledispatch


@dataclass
class Product:
    name: str
    price: float
    quantity: int


@dataclass
class GiftCard:
    amount: float


@singledispatch
def total(item):
    raise TypeError(f"total: nothing registered for {type(item).__name__}")


@total.register
def _(item: Product):
    return item.price * item.quantity


@total.register
def _(item: GiftCard):
    return item.amount


# --- later, in another module: a new kind of item, without editing the above
@dataclass
class Subscription:
    plan: str
    monthly: float
    months: int


@total.register
def _(item: Subscription):
    return item.monthly * item.months


# --- later still, in a third module: a new operation, also without editing
@singledispatch
def tax(item):
    raise TypeError(f"tax: nothing registered for {type(item).__name__}")


@tax.register
def _(item: Product):
    return round(total(item) * 0.20, 2)


@tax.register
def _(item: GiftCard):
    return 0.00


basket = [Product("pen", 1.50, 4), GiftCard(20.00), Subscription("coffee", 9.00, 3)]
print("totals:", [total(item) for item in basket])
for item in basket:
    try:
        print(f"tax on {type(item).__name__}: {tax(item):.2f}")
    except TypeError as error:
        print("TypeError:", error)
```

```txt
totals: [6.0, 20.0, 27.0]
tax on Product: 1.20
tax on GiftCard: 0.00
TypeError: tax: nothing registered for Subscription
```

Both extensions were made without editing anything, but the last line shows
the price. The module that added `tax` and the module that added
`Subscription` did not know about each other, and nobody filled in the cell
where they meet. The program found out at run time, when a subscription was
taxed. Wadler's version of the problem asks for that gap to be caught before
the program runs, which is what makes it hard, and why languages keep
returning to it.

## The principle among the others

The open-closed principle is less a technique than a goal, and the other SOLID
principles read naturally as ways of reaching it:

- **[Single responsibility](../single-responsibility-principle/)** keeps
  each module answerable to one source of change, so that a given change lands
  in one place instead of several.
- **[Liskov substitution](../liskov-substitution-principle/)** is the condition
  that makes extension safe: an extension that does not honour the abstraction's
  contract forces its users to special-case it, which reopens them.
- **[Interface segregation](../interface-segregation-principle/)** keeps the
  abstractions small, so that a new implementation does not have to supply, or
  a client depend on, methods it has nothing to do with.
- **[Dependency inversion](../dependency-inversion-principle/)** points the
  dependencies at the abstraction, so that the policy can stay closed while the
  details multiply beneath it.
- **[Inversion of control](../inversion-of-control/)** is how the pieces are put
  together at run time: the composition root or the framework hands the closed
  module the open set of implementations.

## Common misreadings

- **"Never edit existing code."** The principle concerns how features are
  added, not whether code may be fixed or refactored. Martin himself rejected
  the literal reading.[^martin2013]
- **"Every class needs an interface."** An abstraction with one implementation
  and no variation in sight is not closure; it is indirection. Closure is worth
  having where change is expected, and only there.
- **"Extension means inheritance."** That was Meyer's mechanism in 1988, and it
  still works, but subclassing a concrete class ties the extension to the
  details of its parent. Today extension is more often an implementation of an
  interface, a function passed as an argument, a registered handler or a
  plug-in.
- **"If statements are a violation."** A conditional that chooses between
  cases is only a problem when the set of cases keeps growing and the same
  choice is repeated in many places. A `match` over a set of cases that is
  genuinely fixed is often the clearest code there is, as the expression
  problem showed.

## What it costs and what it buys

| It buys | It costs |
|---|---|
| **Safer change.** New features are new code, so released and tested code is not reopened, and existing behaviour is less likely to break | **Indirection.** Reading `Checkout` no longer tells you how any particular method is priced; the answer is in another class or another package |
| **Independent delivery.** An extension can be written, tested, shipped and even owned by another team without coordinating edits to the core | **Speculative abstraction.** Closing against a change that never comes adds interfaces and classes that make the code harder to follow for no return |
| **Smaller reviews and tests.** A change that adds one file affects one file's worth of behaviour | **Closure in one direction only.** Being closed against new kinds opens a design to edits for new operations, and the other way round |
| **Ecosystems.** A closed core with a stable extension point is what lets editors, browsers and build tools gather plug-ins written by strangers | **Frozen interfaces.** Once others implement an abstraction, changing it is expensive, so a badly chosen one is hard to fix |
| **A clear seam for testing.** The abstraction a module is closed behind is also the point where a test can substitute a stand-in | **Contracts to keep.** Every extension must honour the abstraction's contract, or the closure leaks |

## When to use it

- **Close against change that has happened.** When the same kind of change has
  arrived twice, such as a second payment provider or a third export format,
  that is a strong sign it will arrive again; introduce the abstraction then,
  shaped by the cases you have.
- **Close released, shared code more carefully than private code.** A
  library, a public API or a module many teams use is expensive to reopen, and
  an extension point there pays for itself. A module that one person edits in
  an afternoon can simply be edited.
- **Look for the repeated switch.** The same `if`/`elif` chain or `match` on the
  same kind field in several places is the classic sign that a set of cases
  should become a set of implementations.
- **Use the smallest mechanism that works.** A function parameter before a
  strategy class, a strategy before a registry, a registry before a plug-in
  system.
- **Choose the axis knowingly.** If new kinds of data are the common change,
  favour classes behind an interface; if new operations are, favour functions
  over data. The expression problem guarantees you cannot have both for free.
- **Make extensions substitutable.** An extension point is only closed if every
  extension can be used without special cases, so state the contract and test
  it against every implementation.

## Why it matters

Most of the cost of software is in changing it, and most changes add something
rather than replace it. The open-closed principle is the observation that a
design can make those additions cheap or expensive, and that the difference
lies in whether the code that varies is separated, behind a stable interface,
from the code that does not. That idea runs from Parnas's modules through
Meyer's classes and Martin's abstractions to every plug-in system in daily use.
Its limits are just as instructive: no design is closed against everything,
and the expression problem shows that closing in one direction opens another.
Used with judgement, the principle puts the joints of a program where it is
going to bend. Used by reflex, it fills a program with joints that never move.
The skill, as with most of SOLID, is knowing which is which.

## References

[^martin1996]: Martin, R. C. (1996, January). The open-closed principle. *The C++ Report*, 8(1). <https://www.cs.utexas.edu/~downing/papers/OCP-1996.pdf>

[^martin2014]: Martin, R. C. (2014, May 12). *The Open Closed Principle*. The Clean Code Blog. <https://blog.cleancoder.com/uncle-bob/2014/05/12/TheOpenClosedPrinciple.html>

[^martin2013]: Martin, R. C. (2013, March 8). *An Open and Closed Case*. The Clean Code Blog. <https://blog.cleancoder.com/uncle-bob/2013/03/08/AnOpenAndClosedCase.html>

[^parnas]: Parnas, D. L. (1972). On the criteria to be used in decomposing systems into modules. *Communications of the ACM*, 15(12), 1053–1058. <https://doi.org/10.1145/361598.361623>

[^meyer]: Meyer, B. (1988). *Object-Oriented Software Construction*. Prentice Hall. Second edition, 1997.

[^wadler]: Wadler, P. (1998, November 12). *The Expression Problem*. Message to the Java-genericity mailing list. <https://homepages.inf.ed.ac.uk/wadler/papers/expression/expression.txt>

[^larman]: Larman, C. (2001). Protected variation: The importance of being closed. *IEEE Software*, 18(3), 89–91. <https://doi.org/10.1109/52.922731>

[^gof]: Gamma, E., Helm, R., Johnson, R., & Vlissides, J. (1994). *Design Patterns: Elements of Reusable Object-Oriented Software*. Addison-Wesley.

[^entrypoints]: Python Packaging Authority. (n.d.). *Entry points specification*. Python Packaging User Guide. <https://packaging.python.org/en/latest/specifications/entry-points/>

[^pep634]: Bucher, B., & van Rossum, G. (2020). *PEP 634: Structural Pattern Matching: Specification*. Python Software Foundation. <https://peps.python.org/pep-0634/>

[^singledispatch]: Python Software Foundation. (n.d.). *functools: Higher-order functions and operations on callable objects*. Python documentation. <https://docs.python.org/3/library/functools.html#functools.singledispatch>

[^yagni]: Fowler, M. (2015, May 26). *Yagni*. martinfowler.com. <https://martinfowler.com/bliki/Yagni.html>
