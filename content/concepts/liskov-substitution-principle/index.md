---
title: "What Is the Liskov Substitution Principle? Subtypes, Contracts and the Promises a Base Class Makes"
description: "The Liskov substitution principle says that code written against a type must keep working when handed any of its subtypes. Here is what that means, where it came from, from Barbara Liskov's 1987 keynote and Bertrand Meyer's contracts to behavioural subtyping and Robert C. Martin's column, the rules a subtype has to keep, with runnable examples of the rectangle and the square, a payment contract test and the history constraint, the violations built into .NET and Java, how to fix one, and when the principle is worth enforcing."
date: 2026-10-21T00:03:00Z
categories: ["Concepts"]
tags: ["SOLID", "Liskov Substitution Principle", "Subtyping", "Design by Contract", "Software Design", "Object-Oriented Design", "Concepts"]
series: ["SOLID"]
seriesOrder: 3
seriesGroup: "The five principles"
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

A function that sorts a list of shapes by area has never heard of the square.
It was written against a base type, and it will be handed whatever subclasses
exist now and whatever subclasses someone writes next year. Whether it keeps
working depends on a promise nobody wrote down: that every one of those classes
behaves the way the base type said it would. The **Liskov substitution
principle** is that promise, made explicit. It is the third of the five SOLID
principles, and this is part 3 of a [series on SOLID](../../series/solid/).
This article explains what the principle says, where it came from, the rules a
subtype has to keep, the violations that ship inside widely used platforms, and
how to repair one. Every output shown here was produced by running the code on
Windows 11, with Python 3.14.6, mypy 2.4.0 and the .NET 10 SDK, not written by
hand.

## What the Liskov substitution principle is

**The Liskov substitution principle (LSP) says that if S is a subtype of T,
then objects of type T may be replaced by objects of type S without breaking
any program written against T.** A subtype is not just something that has the
same methods as its base. It is something that behaves, as far as any caller
can tell, the way the base type promised to behave.

Barbara Liskov put it as a substitution property: S is a subtype of T if, for
every object of S, there is an object of T such that any program defined in
terms of T behaves the same when the one is swapped for the other.[^liskov88]
Robert C. Martin, who gave the idea its name as a design principle, restated it
for working programmers: a function that uses references to a base class must
be able to use objects of any derived class without knowing which one it has
been given.[^martinlsp]

The emphasis on *behaviour* is the whole point. A type checker can confirm that
a subclass has a `width` setter because its base has one. It cannot confirm
that the subclass's setter does what callers of the base expect. That gap is
where the classic example lives.

### The rectangle and the square

A square is a rectangle, in geometry and in ordinary speech, so modelling
`Square` as a subclass of `Rectangle` looks natural. The subclass keeps its
sides equal by setting both whenever either one is set:

```python
class Rectangle:
    def __init__(self, width, height):
        self._width, self._height = width, height

    @property
    def width(self):
        return self._width

    @width.setter
    def width(self, value):
        self._width = value

    @property
    def height(self):
        return self._height

    @height.setter
    def height(self, value):
        self._height = value

    def area(self):
        return self.width * self.height


class Square(Rectangle):
    """A square is a rectangle, so it inherits, and keeps its sides equal."""

    def __init__(self, side):
        super().__init__(side, side)

    @Rectangle.width.setter
    def width(self, value):
        self._width = self._height = value

    @Rectangle.height.setter
    def height(self, value):
        self._width = self._height = value


# Written against Rectangle, relying on what Rectangle promises:
# setting the width leaves the height alone.
def make_banner(shape):
    shape.width = 5
    shape.height = 2
    assert shape.area() == 10, f"expected area 10, got {shape.area()}"
    return f"{type(shape).__name__}: banner is {shape.width} x {shape.height}"


for shape in (Rectangle(1, 1), Square(1)):
    try:
        print(make_banner(shape))
    except AssertionError as error:
        print(f"{type(shape).__name__}: AssertionError: {error}")
```

```txt
Rectangle: banner is 5 x 2
Square: AssertionError: expected area 10, got 4
```

Nothing in `Square` is wrong on its own terms. Every method does what a square
needs, and the class is a perfectly good square. The trouble is that
`make_banner` was written against `Rectangle`, and a rectangle promises
something a square cannot keep: that its width and height can be set
independently. Martin used exactly this example in 1996, and drew the lesson
from it: the *is-a* relationship that matters in a design is about the
behaviour callers depend on, not about what the objects are in the world.[^martinlsp]

{{< diagram src="substitution.svg" caption="The caller relies on Rectangle's contract, not on the Rectangle class. Any class behind that contract must keep every promise in it; Square has the same methods and breaks one." >}}

### Why it is a design principle and not a typing rule

The failure above is invisible until a particular caller meets a particular
subclass. That is what makes the principle hard and what makes it important.
Martin's argument was that a violation spreads: once some subclass misbehaves,
callers start defending themselves with checks on the concrete type, an
`isinstance(shape, Square)` here and a special case there, and every such check
is a place that must be edited when the next subclass arrives.[^martinlsp] That
is a direct breach of the [open-closed principle](../open-closed-principle/),
which promises that new behaviour can be added by adding new classes. The
promise only holds if the new classes can be substituted for the old ones.

## A short history

### 1987: data abstraction and hierarchy

The principle began as a remark in a keynote. Barbara Liskov, who had designed
the CLU language at MIT around the idea of abstract data types, gave the
keynote address at OOPSLA '87, the conference on object-oriented programming,
under the title "Data Abstraction and Hierarchy". The text was published in
*SIGPLAN Notices* in May 1988.[^liskov88] Looking at how inheritance was being
used in the object-oriented languages of the time, she separated two uses of
it: sharing an implementation, and defining a type hierarchy in which a subtype
can stand in for its supertype. For the second, she offered the substitution
property quoted above as what is wanted from a subtype.

### 1988: contracts and the rules for redefinition

The same year, Bertrand Meyer published *Object-Oriented Software
Construction*, which introduced **Design by Contract**: each routine states a
*precondition*, what must be true before it is called, and a *postcondition*,
what it guarantees afterwards, and each class states *invariants* that hold
between calls.[^meyer88] Meyer gave the rule that inheritance must follow: a
routine redefined in a descendant may only replace its precondition with a
weaker one and its postcondition with a stronger one. He later described a
redefined routine as a *subcontractor*, which may accept more work and deliver
more than the contract asks, but never less.[^meyer92] Eiffel, his language,
builds the rule in: a redefinition can only add alternatives to a precondition,
with `require else`, and only add guarantees to a postcondition, with `ensure
then`.

### 1991 to 1994: behavioural subtyping

Through the late 1980s and early 1990s the idea was made precise. Pierre
America described a language design built on what he called *behavioural
subtyping*, in which a subtype is defined by its specification rather than its
implementation.[^america] In 1994 Liskov and Jeannette Wing published "A
Behavioral Notion of Subtyping" in *ACM Transactions on Programming Languages
and Systems*.[^liskovwing] Its position is simple to state: the subtype
relation should guarantee that any property proved about objects of the
supertype also holds for objects of the subtype. The paper defined that
relation in terms of the types' specifications and dealt with what earlier
definitions had missed, including objects shared through several references and
a new rule, the **history constraint**, discussed [below](#the-history-constraint).

### 1996: a principle with a name

In March 1996 Robert C. Martin devoted the second of his "Engineering Notebook"
columns in *The C++ Report* to "The Liskov Substitution Principle".[^martinlsp]
The previous column, in January, had covered the open-closed principle, and
Martin presented substitution as what makes that principle work. The column
brought Liskov's property, Meyer's contract rules and the rectangle and square
together, and it is the form in which most programmers have met the idea since.
It later became the L of SOLID, the set of five principles that this series
covers.

### 2008: the Turing Award

Liskov received the 2008 ACM A. M. Turing Award, announced in March 2009, for
her contributions to the practical and theoretical foundations of programming
language and system design, in particular data abstraction, fault tolerance and
distributed computing.[^turing][^mitnews] The substitution principle is a small
part of that body of work, but it is the part that most working programmers
know her name from.

### A timeline at a glance

| Year | Event |
|---|---|
| 1987 | Liskov's OOPSLA keynote states the substitution property |
| 1988 | The keynote is published in *SIGPLAN Notices*; Meyer's *Object-Oriented Software Construction* sets out Design by Contract |
| 1991 | America describes a language built on behavioural subtyping |
| 1992 | Meyer's "Applying 'Design by Contract'" frames redefinition as subcontracting |
| 1994 | Liskov and Wing publish "A Behavioral Notion of Subtyping", with the history constraint |
| 1996 | Martin's *C++ Report* column names the Liskov substitution principle |
| 2009 | Liskov receives the 2008 Turing Award |

## The rules a subtype must keep

The principle can be broken down into rules. Some concern only the shape of a
method, its parameter and return types, and a type checker can enforce them.
The rest concern behaviour, and only the programmer can.

### Signatures: accept more, return less

For a method's signature to be substitutable, two rules apply. An overriding
method must accept at least every argument the base method accepts, so its
parameter types may be the same or *wider*; this is called **contravariance**
of parameters. It must return something every caller of the base can handle,
so its return type may be the same or *narrower*; this is **covariance** of
return types. A static type checker can check both. Here is mypy checking three
overrides of a `pay` method:

```python
class Order: ...
class GiftOrder(Order): ...  # a more specific kind of order


class Receipt: ...
class EmailedReceipt(Receipt): ...


class Checkout:
    def pay(self, order: Order) -> Receipt:
        return Receipt()


class Fine(Checkout):
    # Accepts at least what the base accepts; returns something narrower.
    def pay(self, order: object) -> EmailedReceipt:
        return EmailedReceipt()


class NarrowInput(Checkout):
    # Accepts less than the base: callers passing a plain Order are refused.
    def pay(self, order: GiftOrder) -> Receipt:
        return Receipt()


class WideOutput(Checkout):
    # Promises less than the base: callers expecting a Receipt may get None.
    def pay(self, order: Order) -> Receipt | None:
        return None


class Rectangle:
    def __init__(self, width: float, height: float) -> None:
        self.width, self.height = width, height

    def set_width(self, value: float) -> None:
        self.width = value


class Square(Rectangle):
    # Same signature, different behaviour: the checker has nothing to object to.
    def set_width(self, value: float) -> None:
        self.width = self.height = value
```

```txt
variance.py:22: error: Argument 1 of "pay" is incompatible with supertype "Checkout"; supertype defines the argument type as "Order"  [override]
variance.py:22: note: This violates the Liskov substitution principle
variance.py:22: note: See https://mypy.readthedocs.io/en/stable/common_issues.html#incompatible-overrides
variance.py:28: error: Return type "Receipt | None" of "pay" incompatible with return type "Receipt" in supertype "Checkout"  [override]
Found 2 errors in 1 file (checked 1 source file)
```

mypy accepts `Fine`, rejects the narrowed parameter and the widened return
type, and names the principle in its message: its documentation calls
overriding with a more specific argument type unsafe for exactly this
reason.[^mypy] It also accepts `Square` without a word. The signatures match,
and the broken promise lives in the body of `set_width`, where no type checker
looks. That is the boundary between what tools can enforce and what is left to
design.

### Behaviour: require no more, promise no less

The behavioural rules come from Meyer's contracts and Liskov and Wing's
paper.[^meyer88][^liskovwing] Seen from a caller who holds a reference to the
base type, they all say the same thing: the subtype must not surprise them.

| Rule | A subtype may | A subtype must not |
|---|---|---|
| **Preconditions** | Accept more inputs than the base | Demand anything the base did not, such as a minimum amount or a prior call |
| **Postconditions** | Guarantee more than the base | Guarantee less, such as returning a different amount or leaving a job half done |
| **Invariants** | Add invariants of its own | Break any invariant of the base |
| **History** | Restrict which changes of state happen | Allow a change of state the base forbids, such as mutating what the base made immutable |
| **Exceptions** | Raise fewer kinds of error, or more specific kinds of the declared ones | Raise kinds of error callers of the base were never told to expect |

{{< diagram src="contract.svg" caption="A subtype's accepted calls must contain the base's, and its results must fit inside what the base allows. Invariants, history and errors complete the contract." >}}

The rule about exceptions is the one most often broken in practice, because
raising an error feels like a refusal rather than a change of behaviour. It is
a change of behaviour: a caller that handled every error the base type declared
now meets one it did not, and an unhandled exception is as much a failure as a
wrong answer.

### A contract test

The practical tool that follows from these rules is a **contract test**: one
suite of checks, written against the base type's documented contract, and run
against every implementation. Here the contract of a payment method in a small
shop is written in its docstring, and four implementations are checked
against it:

```python
from dataclasses import dataclass
from decimal import Decimal


class PaymentDeclined(Exception):
    """The one failure the contract allows: the payment was refused."""


@dataclass(frozen=True)
class Receipt:
    amount: Decimal
    method: str


class PaymentMethod:
    """charge(amount)
    requires: amount > 0
    ensures:  returns a Receipt for exactly the amount charged
    raises:   PaymentDeclined, and nothing else
    """

    def charge(self, amount: Decimal) -> Receipt:
        raise NotImplementedError


class Card(PaymentMethod):
    def charge(self, amount):
        return Receipt(amount, "card")


class GiftCard(PaymentMethod):
    def __init__(self, balance):
        self.balance = Decimal(balance)

    def charge(self, amount):
        if amount > self.balance:  # declining is part of the contract
            raise PaymentDeclined(f"balance {self.balance} is below {amount}")
        self.balance -= amount
        return Receipt(amount, "gift card")


class BankTransfer(PaymentMethod):
    def charge(self, amount):
        if amount < Decimal("10.00"):  # a precondition the base never had
            raise ValueError("transfers start at 10.00")
        return Receipt(amount, "transfer")


class CardWithFee(PaymentMethod):
    def charge(self, amount):  # a postcondition weaker than the base's
        return Receipt(amount + Decimal("0.30"), "card + fee")


def contract_test(make):
    """Run the base class's promises against one implementation."""
    failures = []
    for amount in (Decimal("0.50"), Decimal("25.00")):
        try:
            receipt = make().charge(amount)
        except PaymentDeclined:
            continue  # allowed: the base says a charge may be declined
        except Exception as error:
            failures.append(f"{amount}: raised {type(error).__name__}: {error}")
            continue
        if receipt.amount != amount:
            failures.append(f"{amount}: receipt says {receipt.amount}")
    return failures


implementations = {
    "Card": Card,
    "GiftCard": lambda: GiftCard("20.00"),
    "BankTransfer": BankTransfer,
    "CardWithFee": CardWithFee,
}
for name, make in implementations.items():
    failures = contract_test(make)
    print(f"{name:<13}", "ok" if not failures else "BROKEN")
    for failure in failures:
        print(f"  {failure}")
```

```txt
Card          ok
GiftCard      ok
BankTransfer  BROKEN
  0.50: raised ValueError: transfers start at 10.00
CardWithFee   BROKEN
  0.50: receipt says 0.80
  25.00: receipt says 25.30
```

The results are worth reading closely. `GiftCard` refuses the charge of 25.00,
and passes, because the base contract says a charge may be declined and names
the error that signals it: a caller of `PaymentMethod` is already prepared for
that. `BankTransfer` also refuses a charge, but with a precondition the base
never stated and an exception the base never declared; a checkout that offers
every payment method for a 0.50 order will crash on it. `CardWithFee` never
fails at all, and is the more dangerous of the two: it returns a receipt for
an amount nobody asked for, so the order total and the money taken quietly
disagree.

Two things follow. First, the contract has to be written down before it can be
kept. Whether `GiftCard` is substitutable depends entirely on whether the base
type says a charge may be declined. Second, the fix for `BankTransfer` and
`CardWithFee` may well be to change the *contract*, not the subclass: if fees
are a real part of the business, the base type should say so, and every caller
should be written to expect them.

### The history constraint

Liskov and Wing's paper added a rule that pre- and postconditions alone do not
capture.[^liskovwing] A type's specification also says which changes of state
can happen over an object's life, and a subtype must not allow changes the
supertype rules out. The standard case is mutability: a mutable type cannot be
a subtype of an immutable one, even if every method it inherits keeps its pre-
and postconditions, because a caller of the immutable type is entitled to
assume the value never changes. Adding one method is enough to break that:

```python
class OrderSnapshot:
    """An order as it was when placed. Its lines never change."""

    def __init__(self, lines):
        self._lines = list(lines)

    def lines(self):
        return tuple(self._lines)

    def total(self):
        return sum(price for _, price in self._lines)


class EditableOrder(OrderSnapshot):
    """Adds one method, and with it a change the base never allowed."""

    def add_line(self, item, price):
        self._lines.append((item, price))


class InvoiceDesk:
    """Relies on the snapshot's promise: a total, once worked out, stays true."""

    def __init__(self):
        self._totals = {}

    def invoice(self, order):
        if order not in self._totals:
            self._totals[order] = order.total()
        return f"{len(order.lines())} line(s), total {self._totals[order]}"


desk = InvoiceDesk()
for order in (OrderSnapshot([("pen", 3)]), EditableOrder([("pen", 3)])):
    print(type(order).__name__)
    print(f"  {desk.invoice(order)}")
    if isinstance(order, EditableOrder):
        order.add_line("ink", 7)
    print(f"  {desk.invoice(order)}  (actual total {order.total()})")
```

```txt
OrderSnapshot
  1 line(s), total 3
  1 line(s), total 3  (actual total 3)
EditableOrder
  1 line(s), total 3
  2 line(s), total 3  (actual total 10)
```

Every method `EditableOrder` inherits behaves exactly as before. The subclass
only *adds* a method, which looks like the safest kind of extension there is.
But the invoice desk cached a total on the strength of the snapshot's promise,
and the second invoice now lists two lines and charges for one. The new method
was not called through the base type at all; it was enough that some other
code, holding the same object, could call it.

## Violations built into the platforms

The principle is broken in some of the most widely used libraries in the
world, usually on purpose, as a trade for convenience. Two cases are worth
knowing because they show what a violation costs even when it is documented.

### Covariant arrays

In C# and in Java an array of strings can be used where an array of objects is
expected. Reading from it is safe, since every string is an object. Writing to
it is not: an array of objects promises to accept any object, and an array of
strings cannot keep that promise. Microsoft's documentation states plainly that
array covariance is not type safe, and the runtime has to check every store
into such an array.[^msvariance] Java does the same and throws
`ArrayStoreException`.[^javaarraystore]

### Read-only collections behind writable interfaces

.NET's `ReadOnlyCollection<T>` implements `IList<T>` and `ICollection<T>`,
interfaces that include `Add`, `Insert`, `Remove` and an indexer setter. It
implements those members by always throwing `NotSupportedException`.[^msreadonly]
The interface's escape hatch is a property, `IsReadOnly`, which says whether the
collection allows elements to be added or removed.[^msisreadonly] Both effects
are visible in a few lines:

```csharp
using System.Collections.ObjectModel;

// Arrays: a string[] may be used where an object[] is expected...
object[] items = new string[2];
items[0] = "pen";
try
{
    items[1] = 42; // ...which the compiler accepts, because object[] allows it
}
catch (ArrayTypeMismatchException error)
{
    Console.WriteLine($"{error.GetType().Name}: {error.Message}");
}

// Collections: a read-only list is also an IList<T>, which promises Add.
var basket = new List<string> { "pen" };
AddFreeGift(basket);
AddFreeGift(new ReadOnlyCollection<string>(basket));
AddFreeGiftChecked(new ReadOnlyCollection<string>(basket));

static void AddFreeGift(IList<string> lines)
{
    try
    {
        lines.Add("sticker");
        Console.WriteLine($"{Name(lines)}: {string.Join(", ", lines)}");
    }
    catch (NotSupportedException error)
    {
        Console.WriteLine($"{Name(lines)}: {error.GetType().Name}: {error.Message}");
    }
}

// The interface's own escape hatch: every caller has to remember to ask.
static void AddFreeGiftChecked(IList<string> lines)
{
    if (lines.IsReadOnly)
    {
        Console.WriteLine($"{Name(lines)}: read-only, gift skipped");
        return;
    }
    lines.Add("sticker");
}

static string Name(object value) => value.GetType().Name.Split('`')[0];
```

```txt
ArrayTypeMismatchException: Attempted to access an element as a type incompatible with the array.
List: pen, sticker
ReadOnlyCollection: NotSupportedException: Collection is read-only.
ReadOnlyCollection: read-only, gift skipped
```

Whether this is a violation depends on how the contract is read. Strictly, it
is not: `IList<T>` documents that some implementations are read-only and
provides a property to find out, so throwing is within the contract. In
practice, a contract that says "this method works, unless it doesn't" pushes
the check into every caller, and the callers who forget it, like
`AddFreeGift`, compile cleanly and fail at run time. Java's collections made
the same choice deliberately: modifying methods such as `add` are marked
*optional operations*, and an implementation that does not support one throws
`UnsupportedOperationException`.[^javacollection]

Python's standard library shows the alternative. `collections.abc` splits
reading from writing: `Sequence` requires only indexing and length, and
`MutableSequence` extends it with the methods that change the
sequence.[^pyabc] An immutable type registers as the first and not the second:

```python
from collections.abc import MutableSequence, Sequence

for value in ([1, 2], (1, 2), "12"):
    print(f"{type(value).__name__:<6} Sequence: {isinstance(value, Sequence)!s:<5}"
          f"  MutableSequence: {isinstance(value, MutableSequence)}")
```

```txt
list   Sequence: True   MutableSequence: True
tuple  Sequence: True   MutableSequence: False
str    Sequence: True   MutableSequence: False
```

A function that needs to append asks for a `MutableSequence`, and a tuple can
never reach it. .NET later added the same split, as `IReadOnlyList<T>` and
`IReadOnlyCollection<T>`, which `ReadOnlyCollection<T>` also
implements.[^msreadonly]

{{< diagram src="split.svg" caption="One interface that promises writing forces read-only types to refuse. Two interfaces, one for reading and one that adds writing, let every type keep every promise it makes." >}}

## Fixing a violation

### Change the contract so the subtype can keep it

The rectangle and square conflict comes from one promise: that width and height
can be changed independently, in place. Take away the mutation and the conflict
goes with it. If shapes are immutable and "changing the width" means producing
a new shape, a square can be a rectangle after all:

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class Rectangle:
    width: float
    height: float

    def area(self):
        return self.width * self.height

    # Promise: a shape with the new width and the same height.
    def with_width(self, width):
        return Rectangle(width, self.height)

    def with_height(self, height):
        return Rectangle(self.width, height)


class Square(Rectangle):
    def __init__(self, side):
        super().__init__(side, side)


def make_banner(shape):
    banner = shape.with_width(5).with_height(2)
    assert banner.area() == 10, f"expected area 10, got {banner.area()}"
    return f"{type(shape).__name__} -> {banner}"


for shape in (Rectangle(1, 1), Square(1)):
    print(make_banner(shape))
print("square still square:", Square(1))
```

```txt
Rectangle -> Rectangle(width=5, height=2)
Square -> Rectangle(width=5, height=2)
square still square: Square(width=1, height=1)
```

Stretching a square now gives a rectangle that is not a square, which is
exactly what happens in geometry. Every promise `Rectangle` makes, a new shape
with the given width and the old height, is one `Square` keeps. Immutability
removed the history the square could not honour.

### Split the abstraction

When different implementations genuinely support different operations, the
honest model is several smaller types rather than one large one with methods
that some implementations refuse. That is the read-only collection lesson, and
it is the subject of the [interface segregation principle](../interface-segregation-principle/):
a type that promises less is a type more implementations can keep.

### Prefer composition to inheritance

Much of the trouble starts with inheritance used to share code. `EditableOrder`
inherited from `OrderSnapshot` to reuse `lines` and `total`, and inherited a
promise it could not keep along with them. An editable order that *holds* its
lines and can *produce* a snapshot, `order.snapshot()`, reuses the same code
without claiming to be something it is not. Liskov's keynote drew the same
line, between inheritance as a way to share an implementation and inheritance
as a statement that one type can stand in for another.[^liskov88]

### Treat type checks in callers as a symptom

Code that asks what concrete type it has been given, with `isinstance` or a
type switch, before deciding what to do, is often working around a subtype
that does not keep its base's contract.[^martinlsp] Sometimes the check is
legitimate, at the edge of a system where data arrives untyped. Inside a
design, it usually points to a contract that needs fixing.

## The Liskov substitution principle and the rest of SOLID

- **[Open-closed](../open-closed-principle/).** Extending a system by adding
  subclasses is only safe if they can be substituted for their bases. Liskov
  substitution is the condition under which open-closed works, which is how
  Martin introduced it.[^martinlsp]
- **[Interface segregation](../interface-segregation-principle/).** Smaller
  interfaces make fewer promises, so fewer implementations are tempted to break
  one.
- **[Dependency inversion](../dependency-inversion-principle/).** High-level
  code depends on abstractions, and an abstraction is only as good as the
  substitutability of what stands behind it. When an implementation is chosen
  by configuration and handed in by
  [dependency injection](../inversion-of-control/), the caller cannot even see
  which one it got, so the contract is all it has.

## What it costs and what it buys

| It buys | It costs |
|---|---|
| **Safe extension.** New implementations can be added without editing or retesting the code that uses the base type | **Specification work.** A contract has to be stated, and stated precisely, before anyone can tell whether it is kept |
| **Local reasoning.** A caller can be understood from the base type alone, without reading every subclass | **Rejected shortcuts.** Some convenient inheritance, used to share code, has to become composition instead |
| **Fewer type checks.** Callers do not need `isinstance` switches to defend themselves | **More types.** Honest models often need several narrow abstractions where one wide one would have been shorter |
| **Testable promises.** One contract test suite covers every implementation, present and future | **No tool does it for you.** Type checkers enforce the signature rules; the behavioural rules depend on tests and review |

## When to use it

- **Apply it to every type hierarchy that callers depend on.** If code is
  written against a base type or an interface, every implementation must keep
  its contract. This is not optional in the way some principles are: a
  violation is a bug waiting for the right caller.
- **Write the contract down.** State preconditions, guarantees and permitted
  errors in the documentation of the base type, as `PaymentMethod` does. A
  contract that lives only in the original author's head cannot be kept by the
  next one.
- **Write contract tests for interfaces with several implementations.** Run the
  same suite against every implementation, including test doubles, so that a
  fake behaves like the real thing.
- **Do not inherit only to reuse code.** If the subclass could not stand in for
  its base everywhere, use composition.
- **Do not make a base type promise what some implementations cannot do.** Split
  it instead of adding methods that throw `NotSupported`.
- **Do not stretch it to types nobody substitutes.** A class with no subclasses
  and no interface has no contract to keep beyond its own tests. The principle
  is about the boundary between a type and the code written against it.

## Why it matters

Every abstraction is a promise. An interface, a base class, a protocol or a
function signature tells the code that uses it what it may assume, and the
whole value of programming against abstractions, the plug-in architectures,
the swappable implementations, the injected dependencies and the test doubles,
rests on implementations keeping those promises. The Liskov substitution
principle is the name for that obligation. It explains why a square should not
always inherit from a rectangle, why a read-only list behind a writable
interface keeps causing bugs, and why a test double that behaves differently
from the real service can make a test suite lie. It asks for something that no
compiler can check: that a subtype be judged by what its callers rely on, not
by what it is called.

## References

[^liskov88]: Liskov, B. (1988). Keynote address: Data abstraction and hierarchy. *ACM SIGPLAN Notices*, 23(5), 17–34. <https://doi.org/10.1145/62139.62141>

[^martinlsp]: Martin, R. C. (1996, March). The Liskov substitution principle. *The C++ Report*. <https://cs.utexas.edu/~downing/papers/LSP-1996.pdf>

[^meyer88]: Meyer, B. (1988). *Object-Oriented Software Construction*. Prentice Hall.

[^meyer92]: Meyer, B. (1992). Applying "design by contract". *Computer*, 25(10), 40–51. <https://doi.org/10.1109/2.161279>

[^america]: America, P. (1991). Designing an object-oriented programming language with behavioural subtyping. In *Foundations of Object-Oriented Languages* (Lecture Notes in Computer Science, pp. 60–90). Springer. <https://doi.org/10.1007/BFb0019440>

[^liskovwing]: Liskov, B. H., & Wing, J. M. (1994). A behavioral notion of subtyping. *ACM Transactions on Programming Languages and Systems*, 16(6), 1811–1841. <https://doi.org/10.1145/197320.197383>

[^turing]: Computing Research Association. (2009). Barbara Liskov wins ACM A. M. Turing Award. *CRA-W*. <https://cra.org/cra-w/barbara-liskov-wins-acm-a-m-turing-award>

[^mitnews]: MIT News Office. (2009, March 10). Barbara Liskov wins Turing Award. *MIT News*. <https://news.mit.edu/2009/turing-liskov-0310>

[^mypy]: mypy. (n.d.). Incompatible overrides. In *Common issues and solutions*. mypy documentation. <https://mypy.readthedocs.io/en/stable/common_issues.html#incompatible-overrides>

[^msvariance]: Microsoft. (n.d.). *Covariance and contravariance (C#)*. Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/covariance-contravariance/>

[^javaarraystore]: Oracle. (n.d.). *Class ArrayStoreException*. Java SE 21 API specification. <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/ArrayStoreException.html>

[^msreadonly]: Microsoft. (n.d.). *ReadOnlyCollection\<T\> class*. .NET API reference, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.objectmodel.readonlycollection-1>

[^msisreadonly]: Microsoft. (2025, July 1). *ICollection\<T\>.IsReadOnly property*. .NET API reference, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.icollection-1.isreadonly>

[^javacollection]: Oracle. (n.d.). *Interface Collection\<E\>*. Java SE 21 API specification. <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Collection.html>

[^pyabc]: Python Software Foundation. (n.d.). *collections.abc: Abstract base classes for containers*. Python documentation. <https://docs.python.org/3/library/collections.abc.html>
