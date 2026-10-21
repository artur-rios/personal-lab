---
title: "What Is the Interface Segregation Principle? Fat Interfaces, Role Interfaces and the Clients That Shape Them"
description: "The interface segregation principle says that no client should be forced to depend on methods it does not use. Here is what that means, where it came from, from Robert C. Martin's 1996 column to Go's one-method interfaces, what a fat interface costs in a compiled language and in a dynamic one, how to split one into role interfaces, with runnable examples in Python and C#, how it relates to the other SOLID principles, and when splitting goes too far."
date: 2026-10-21T00:04:00Z
categories: ["Concepts"]
tags: ["SOLID", "Interface Segregation Principle", "Interfaces", "Software Design", "Object-Oriented Design", "Concepts"]
series: ["SOLID"]
seriesOrder: 4
seriesGroup: "The five principles"
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

An invoice printer needs to read one order. In many codebases it is handed an
object that can also save orders, cancel them, total the month's revenue and
export everything to a spreadsheet, because that is the interface the order
store happens to have. The printer never calls those methods, but it depends on
them all the same: when one of them changes, the printer is rebuilt, retested
and redeployed, and anyone writing a stand-in for it in a test has to implement
all five. The **interface segregation principle** is the rule against that
arrangement, and the fourth of the five SOLID principles this
[series](../../series/solid/) covers. This article explains
what it says, where it came from, what a fat interface costs, how to split one
into interfaces shaped by their clients, and where splitting stops paying.
Every output shown here was produced by running the code on Windows 11, with
Python 3.14.6 and with the .NET 10 SDK, not written by hand.

## What the interface segregation principle is

**The interface segregation principle (ISP) says that no client should be
forced to depend on methods it does not use: an interface should be shaped by
the needs of the code that calls it, and a class that serves several kinds of
client should offer each kind its own, smaller interface.**

Robert C. Martin stated it in 1996 in capital letters, as a rule that clients
should not be forced to depend upon *interfaces* they do not use.[^isp1996] By
his 2003 book the wording had settled on *methods*, the form most often quoted
today.[^asd][^spinellis] Either way the subject is the same. Martin called an
interface that bundles groups of methods for different clients **fat**, or
**polluted**:
the class behind it may need all those methods, because they work on the same
data, but no single client needs all of them.[^isp1996]

The principle does not ask for that class to be broken up. It asks that its
clients not see it as one thing. A class with three kinds of client can stay
one class and implement three interfaces, each holding what one kind of client
calls; each client then names only its own interface. What changes is the
*dependency*, not necessarily the implementation.

### Who an interface belongs to

The idea underneath is that an interface belongs to its clients, not to the
class that implements it. Martin Fowler put the distinction in a pair of short
articles in December 2006. A **header interface** mirrors a class: it takes
every public method of the class and declares it again in an interface, so that
another implementation can be swapped in.[^header] A **role interface** is
found the other way round, by looking at one particular interaction between a
supplier and its consumers and declaring only what that interaction uses; a
supplier usually plays several roles and implements several such
interfaces.[^role] Fowler notes that role interfaces follow the interface
segregation principle and header interfaces do not, and credits the analysis of
objects by the roles they play to Trygve Reenskaug.[^role]

The header interface is the easy one to write, because it needs no thought
about who calls what. That is also its flaw: it is shaped by the supplier, so
every client inherits the supplier's whole surface.

## A short history

### 1996: fat interfaces in *The C++ Report*

The principle was published in August 1996, as the fourth of Martin's
*Engineering Notebook* columns for *The C++ Report*, following his column on
the [dependency inversion principle](../dependency-inversion-principle/) in
May.[^isp1996][^ispcite] Its main example is a security system. A `Door` can be
locked, unlocked and asked whether it is open; a `TimedDoor` must sound an
alarm when it has been left open too long, and to hear about timeouts it must
be a `TimerClient` that a `Timer` can call back. The obvious fix, making `Door`
itself inherit from `TimerClient`, is the one Martin warns against: every kind
of door now carries a timeout method most of them have no use for, every
module that uses a door now depends on the timer's interface, and a change to
`TimerClient`, such as adding an identifier to each timeout, reaches every
client of `Door`.[^isp1996]

{{< diagram src="timed-door.svg" caption="Martin's 1996 example. Making Door a TimerClient pollutes every door with timing; an adapter or multiple inheritance gives the timed door both interfaces without either client seeing the other's." >}}

The column gives two ways out. In the first, an adapter object implements
`TimerClient` and forwards each timeout to the door, so the door's clients never
meet the timer at all. In the second, `TimedDoor` inherits from both `Door` and
`TimerClient`, and each client uses the object through the base class it
needs.[^isp1996] A second case study applies the same reasoning to an automated
teller machine, whose single user-interface class had a method for every
message every transaction might show: deposits, withdrawals and transfers each
used a slice of it, so a change for one forced a rebuild of the others, and the
cure was a separate interface for each kind of transaction.[^isp1996]

The column is frank that the cost it is fighting is partly a C++ one. Its answer
to "but it's just a recompile" is that recompiling takes time, tempts developers
to make changes in the wrong place to avoid it, and produces more object files
and libraries to ship than the change deserves.[^isp1996]

### The Xerox story

The principle is often said to have been born at Xerox, where Martin was
consulting on the software for a new printer system that could print, staple
and fax. In the usual telling, almost every task went through a single `Job`
class, so a stapling job knew about every printing method, and the system had
grown to the point where even a small change took about an hour to redeploy;
the fix was a separate interface for each kind of job, all implemented by the
`Job` class.[^wikipedia] The story is widely repeated, but it does not appear in
the 1996 column, which uses the doors and the cash machine instead, and the
accounts that tell it do not cite Martin's own words. It is best read as the
principle's origin story rather than a documented case study.

### 2000: one of the principles of class design

In 2000 Martin's paper *Design Principles and Design Patterns* gathered his
principles of class and package design in one place. Among the class design
principles, interface segregation sits beside the open-closed, Liskov
substitution and dependency inversion principles, summed up as the line that
many client-specific interfaces are better than one general-purpose
one.[^dpdp] The paper adds two clarifications worth keeping. *Client-specific*
does not mean one interface per calling class, which would make the service
depend on every client it has; clients are grouped by type, and each type gets
an interface, with a method appearing in more than one interface if more than
one type needs it. And when an existing interface must change, the impact can
often be contained by adding a new interface to the object instead of changing
the old one, which is how component systems such as Microsoft's COM evolved
their objects.[^dpdp] A COM object is reached only through its interfaces, and
a client asks it at run time, with `QueryInterface`, whether it supports
another.[^queryinterface]

The paper does not yet list the single responsibility principle among them, and
the five were not yet called SOLID; how the acronym came about is told in the
[first article of the series](../single-responsibility-principle/). Martin's
2003 book *Agile Software Development, Principles, Patterns, and Practices*
gave the principle its own chapter.[^asd]

### 2006: role interfaces

Fowler's two bliki entries of 21 and 22 December 2006 gave the principle the
vocabulary used above, header and role interfaces, and moved the emphasis from
compilation to communication: a role interface says, in the code, how a client
and a supplier actually collaborate.[^header][^role]

### Go: small interfaces as a language habit

Go made small interfaces the house style. Its `io` package defines `Reader` and
`Writer` with one method each, and builds bigger interfaces such as
`ReadWriter` and `ReadWriteCloser` by embedding the small ones.[^goio] *Effective
Go* notes that interfaces with one or two methods are common in Go code and are
usually named after their method, and that a type implements an interface just
by having its methods, with no declaration that it does.[^effectivego] Because
the interface is satisfied implicitly, a client can declare the small interface
it needs next to its own code, after the fact, and every type that already has
the method fits it. Rob Pike put the attitude into one of his Go Proverbs at
Gopherfest in 2015: the bigger the interface, the weaker the
abstraction.[^proverbs]

### Since then: beyond the language

In *Clean Architecture* (2017) Martin gave the principle a short chapter in two
halves. The first concedes that the recompilation argument belongs to
statically typed languages, where a client's source must import the declaration
it depends on; the second argues that the principle is really about
architecture, since depending on a framework that drags in a database brings
along every feature of that database the system never uses, and every failure
in them.[^cleanarch] In 2020, answering critics who called SOLID outdated, he
restated the principle as keeping interfaces small so that users do not depend
on things they do not need, and noted that dynamically typed languages are less
affected by the compile-time version of the problem but not immune to
it.[^relevance]

### A timeline at a glance

| Year | Event |
|---|---|
| 1996 | Martin's *C++ Report* column states the interface segregation principle, with the timed door and the cash machine |
| 2000 | *Design Principles and Design Patterns* lists it among the principles of class design |
| 2003 | *Agile Software Development* gives it a chapter, in the wording about methods |
| 2006 | Fowler names header interfaces and role interfaces |
| 2012 | .NET Framework 4.5 adds read-only collection interfaces beside `IList<T>` |
| 2015 | Pike's Go Proverbs: the bigger the interface, the weaker the abstraction |
| 2017 | *Clean Architecture* extends the principle from languages to architecture |

## A fat interface in practice

Here is the shop's order store as one interface for everything any part of the
shop does with orders, one client that only reads, and an archive of last
year's orders that can do nothing but read:

```python
from abc import ABC, abstractmethod


class OrderStore(ABC):
    """One interface for everything any part of the shop does with orders."""

    @abstractmethod
    def get(self, order_id): ...

    @abstractmethod
    def save(self, order): ...

    @abstractmethod
    def cancel(self, order_id): ...

    @abstractmethod
    def monthly_revenue(self, month): ...

    @abstractmethod
    def export_csv(self): ...


class InvoicePrinter:
    """Only ever reads one order, but must be handed a whole OrderStore."""

    def __init__(self, store: OrderStore):
        self.store = store

    def print_invoice(self, order_id):
        order = self.store.get(order_id)
        return f"INVOICE {order_id}: {order['customer']} owes {order['total']:.2f}"


class ArchivedOrders(OrderStore):
    """Last year's orders: read-only, but the interface demands writes too."""

    def __init__(self, rows):
        self.rows = rows

    def get(self, order_id):
        return self.rows[order_id]

    def save(self, order):
        raise NotImplementedError("the archive is read-only")

    def cancel(self, order_id):
        raise NotImplementedError("the archive is read-only")

    def monthly_revenue(self, month):
        raise NotImplementedError("no reporting on the archive")

    def export_csv(self):
        raise NotImplementedError("no exports from the archive")


archive = ArchivedOrders({"A-17": {"customer": "Ada", "total": 42.5}})
print(InvoicePrinter(archive).print_invoice("A-17"))

# Anything typed as an OrderStore may call any of its methods, so the
# archive's refusals only surface when some client happens to try one.
try:
    archive.cancel("A-17")
except NotImplementedError as error:
    print("NotImplementedError:", error)


# A test double for InvoicePrinter needs one method. The interface asks for five.
class FakeStore(OrderStore):
    def get(self, order_id):
        return {"customer": "Test", "total": 1.0}


try:
    FakeStore()
except TypeError as error:
    print("TypeError:", error)
```

```txt
INVOICE A-17: Ada owes 42.50
NotImplementedError: the archive is read-only
TypeError: Can't instantiate abstract class FakeStore without an implementation for abstract methods 'cancel', 'export_csv', 'monthly_revenue', 'save'
```

The program works, and that is what makes fat interfaces so common: nothing
fails until someone looks closely. Three costs are visible in it.

1. **Implementers have to refuse.** `ArchivedOrders` is an `OrderStore` by
   declaration but can honour only one of its five methods. The other four
   raise, and the type says nothing about which: any code holding an
   `OrderStore` is entitled to call `cancel`, and finds out only at run time
   that this one cannot. A method that exists only to refuse is a broken
   promise, which is what the [Liskov substitution
   principle](../liskov-substitution-principle/) forbids.
2. **Test doubles have to implement everything.** The invoice printer's test
   needs a store that answers `get`. Python will not even build the fake until
   it also provides `save`, `cancel`, `monthly_revenue` and `export_csv`, which
   in practice means four stub methods or a mocking library that fakes the
   whole surface.
3. **Clients are coupled to each other.** The invoice printer, the checkout
   and the month-end report all depend on one interface, so a change any of
   them asks for is a change to what the others depend on. That is the coupling
   Martin's 1996 column was written against.[^isp1996]

Large platforms have shipped the first cost on purpose. Java's collection
interfaces mark their mutating methods as *optional operations*: an
implementation that does not support one, such as an unmodifiable list, throws
`UnsupportedOperationException` instead.[^javacollection] The trade was a
smaller set of interfaces in exchange for errors that only appear at run time.

## Splitting by role

The fix is to give each kind of client an interface of its own, named for the
role it needs, and let the classes that can play several roles play them all.
Python's `typing.Protocol`, added in Python 3.8 by PEP 544, suits this well: a
class satisfies a protocol by having the right methods, without inheriting from
it, much as a Go type satisfies an interface.[^pep544]

```python
from typing import Protocol, runtime_checkable


# One small interface per kind of client, named for the role it plays.
@runtime_checkable
class OrderReader(Protocol):
    def get(self, order_id): ...


@runtime_checkable
class OrderWriter(Protocol):
    def save(self, order): ...

    def cancel(self, order_id): ...


@runtime_checkable
class RevenueSource(Protocol):
    def monthly_revenue(self, month): ...


class InvoicePrinter:
    def __init__(self, orders: OrderReader):  # asks for exactly what it uses
        self.orders = orders

    def print_invoice(self, order_id):
        order = self.orders.get(order_id)
        return f"INVOICE {order_id}: {order['customer']} owes {order['total']:.2f}"


class MonthEndReport:
    def __init__(self, revenue: RevenueSource):
        self.revenue = revenue

    def line(self, month):
        return f"REVENUE {month}: {self.revenue.monthly_revenue(month):.2f}"


class DatabaseOrders:
    """The live store plays every role, without inheriting from any of them."""

    def __init__(self):
        self.rows = {}

    def get(self, order_id):
        return self.rows[order_id]

    def save(self, order):
        self.rows[order["id"]] = order

    def cancel(self, order_id):
        self.rows[order_id]["status"] = "cancelled"

    def monthly_revenue(self, month):
        return sum(o["total"] for o in self.rows.values()
                   if o["month"] == month and o.get("status") != "cancelled")


class ArchivedOrders:
    """Read-only, and now it only has to say so: it plays one role."""

    def __init__(self, rows):
        self.rows = rows

    def get(self, order_id):
        return self.rows[order_id]


live = DatabaseOrders()
live.save({"id": "B-1", "customer": "Ada", "total": 30.0, "month": "2026-10"})
live.save({"id": "B-2", "customer": "Grace", "total": 12.5, "month": "2026-10"})
live.cancel("B-2")
archive = ArchivedOrders({"A-17": {"customer": "Ada", "total": 42.5}})

print(InvoicePrinter(live).print_invoice("B-1"))
print(InvoicePrinter(archive).print_invoice("A-17"))
print(MonthEndReport(live).line("2026-10"))

for role in (OrderReader, OrderWriter, RevenueSource):
    print(f"{role.__name__:<13}  live: {isinstance(live, role)!s:<5}"
          f"  archive: {isinstance(archive, role)}")


# The test double for InvoicePrinter implements the one method it needs.
class FakeReader:
    def get(self, order_id):
        return {"customer": "Test", "total": 1.0}


print(InvoicePrinter(FakeReader()).print_invoice("T-1"))
```

```txt
INVOICE B-1: Ada owes 30.00
INVOICE A-17: Ada owes 42.50
REVENUE 2026-10: 30.00
OrderReader    live: True   archive: True
OrderWriter    live: True   archive: False
RevenueSource  live: True   archive: False
INVOICE T-1: Test owes 1.00
```

Nothing about the work has changed; the dependencies have. The invoice printer
asks for an `OrderReader` and accepts the live store, the archive and a
one-method fake alike. The archive no longer raises anything, because it no
longer claims to do what it cannot: it plays one role, and the table in the
output says so. `DatabaseOrders` is still a single class with all the order
logic in one place, and it plays all three roles. The interfaces are split; the
implementation is not.

{{< diagram src="fat-vs-role.svg" caption="Above, three clients share one five-method interface and the archive must refuse four of them. Below, each client names the role it needs; the archive plays one role and the database store plays all three." >}}

Two details of the Python are worth knowing. The names of the protocols are
*role* names, `OrderReader` rather than `IDatabaseOrders`: they describe what
a client wants, not what a supplier is, which is Fowler's
distinction.[^role] And `runtime_checkable` makes `isinstance` work with a
protocol, but it only checks that the methods exist, not their signatures; the
full check is the job of a static type checker such as mypy, which is where
protocols do most of their work.[^pep544]

## What a fat interface costs, by language

How much a fat interface hurts depends on the language, and this is the part of
the principle most often misunderstood in both directions.

In a **statically compiled language**, a client's source code names the
interface it uses, so it depends on the declaration of every method in it. In
C++, changing one method of a widely included header recompiles every file
that includes it; in Java or C#, changing a method of an interface in a shared
library means rebuilding, retesting and redeploying every assembly or JAR that
references it, whether or not it calls that method. That is the cost the 1996
column measured.[^isp1996][^cleanarch] Segregating the interface turns one
change that reaches everything into one that reaches only the clients of the
role that changed.

{{< diagram src="ripple.svg" caption="The same change, a new parameter on monthly_revenue, made to a fat interface and to a role interface. On the left everything that names OrderStore must be revisited; on the right only the one client and the one implementer of RevenueSource." >}}

In a **dynamically typed language** nothing is recompiled, and it is tempting
to conclude the principle does not apply. Martin himself grants that such
languages are less affected.[^relevance][^cleanarch] But the dependency is
still there in three forms the examples above show:

- **Implementers break.** Adding an abstract method to `OrderStore` stops every
  subclass from being constructed until it implements it, as `FakeStore`'s
  `TypeError` showed, including subclasses whose clients never call it.
- **Test doubles grow.** A client typed against a fat interface needs a fake
  or mock of the whole thing, and every method added to the interface is
  another one to stub.
- **Readers must know more.** A parameter typed `OrderStore` tells the reader
  that the function might save, cancel or export. One typed `OrderReader` tells
  them it only reads, which is both documentation and a promise a type checker
  can hold the code to.

In both kinds of language there is a further cost Martin added in 2017: a
client that depends on a big interface depends on everything behind it,
including the failures of features it never uses.[^cleanarch]

## A real example: read-only collections in .NET

.NET's collections show the principle being applied after the fact, and both
designs still live side by side. `IList<T>` bundles reading and writing: it has
an indexer and a count, and also `Add`, `Remove` and `Insert`. A type that can
be read but not grown, such as an array, or a list wrapped as read-only, still
implements `IList<T>`, and has to refuse the writes at run time. .NET Framework
4.5, released in 2012, added `IReadOnlyCollection<T>` and `IReadOnlyList<T>`:
interfaces for the reading role alone, implemented by `List<T>`, arrays and the
immutable collections.[^ireadonlylist]

```csharp
using System.Collections.Immutable;
using System.Globalization;

CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;

// A client that only reads asks for the read-only role, so anything that can
// be read from will do.
static decimal Total(IReadOnlyList<decimal> prices)
{
    var total = 0m;
    for (var i = 0; i < prices.Count; i++) total += prices[i];
    return total;
}

Console.WriteLine($"List<T>:           {Total(new List<decimal> { 9.99m, 5m })}");
Console.WriteLine($"array:             {Total(new[] { 9.99m, 5m })}");
Console.WriteLine($"ImmutableArray<T>: {Total(ImmutableArray.Create(9.99m, 5m))}");

// The older IList<T> bundles reading with writing, so types that cannot
// write still have to carry Add and Remove, and refuse them at run time.
IList<decimal> fixedSize = new[] { 9.99m, 5m };
IList<decimal> wrapped = new List<decimal> { 9.99m }.AsReadOnly();
foreach (var (name, list) in new[] { ("array", fixedSize), ("AsReadOnly()", wrapped) })
{
    try
    {
        list.Add(1m);
    }
    catch (NotSupportedException error)
    {
        Console.WriteLine($"{name,-12} IsReadOnly={list.IsReadOnly,-5} Add: {error.Message}");
    }
}

// One class, many roles: the generic interfaces List<T> implements.
var roles = typeof(List<decimal>).GetInterfaces()
    .Where(i => i.IsGenericType)
    .Select(i => i.Name.Split('`')[0] + "<T>")
    .Order();
Console.WriteLine("List<T> roles: " + string.Join(", ", roles));
```

```txt
List<T>:           14.99
array:             14.99
ImmutableArray<T>: 14.99
array        IsReadOnly=True  Add: Collection was of a fixed size.
AsReadOnly() IsReadOnly=True  Add: Collection is read-only.
List<T> roles: ICollection<T>, IEnumerable<T>, IList<T>, IReadOnlyCollection<T>, IReadOnlyList<T>
```

A method that takes `IReadOnlyList<T>` accepts a list, an array and an
immutable array, and its signature says it will not modify any of them. The
same objects seen through `IList<T>` advertise an `Add` they reject, and an
`IsReadOnly` property exists so that callers can ask in advance, which is the
fat interface's usual workaround: a flag that says which of its promises not to
rely on. The last line shows the other half of the principle. `List<T>` is one
class playing five roles, each of them a separate interface a client can ask
for.

## Putting roles back together

Some clients do need more than one role, and the principle does not ask them to
pretend otherwise. There are two honest ways to say so:

```python
from typing import Protocol, runtime_checkable


@runtime_checkable
class OrderReader(Protocol):
    def get(self, order_id): ...


@runtime_checkable
class OrderWriter(Protocol):
    def save(self, order): ...

    def cancel(self, order_id): ...


# An aggregate: a name for a combination some clients really do need.
@runtime_checkable
class OrderRepository(OrderReader, OrderWriter, Protocol):
    pass


class DatabaseOrders:
    def __init__(self):
        self.rows = {}

    def get(self, order_id):
        return self.rows[order_id]

    def save(self, order):
        self.rows[order["id"]] = order

    def cancel(self, order_id):
        self.rows[order_id]["status"] = "cancelled"


# Monadic: one parameter, typed as the aggregate.
def apply_discount(orders: OrderRepository, order_id, percent):
    order = orders.get(order_id)
    orders.save({**order, "total": order["total"] * (100 - percent) / 100})


# Polyadic: one parameter per role, even when the same object fills both.
def copy_order(source: OrderReader, target: OrderWriter, order_id):
    target.save(source.get(order_id))


live = DatabaseOrders()
live.save({"id": "B-1", "customer": "Ada", "total": 30.0})
apply_discount(live, "B-1", 10)
print(live.get("B-1"))

backup = DatabaseOrders()
copy_order(live, backup, "B-1")
print(backup.get("B-1"))
print("live is an OrderRepository:", isinstance(live, OrderRepository))
```

```txt
{'id': 'B-1', 'customer': 'Ada', 'total': 27.0}
{'id': 'B-1', 'customer': 'Ada', 'total': 27.0}
live is an OrderRepository: True
```

An **aggregate interface** such as `OrderRepository` is built from the roles,
not instead of them, the way Go builds `ReadWriter` out of `Reader` and
`Writer`.[^goio] It is a name for a combination that some clients genuinely
need, and clients that need less still ask for less. The alternative is to take
one parameter per role, as `copy_order` does. Martin's 1996 column argued for
that *polyadic* form even when both arguments are the same object, because the
function then depends only on the two roles it uses, and does not assume they
will always be played by one object.[^isp1996] In `copy_order` that assumption
would have been wrong from the start: the source and the target are different
stores.

## ISP and the other principles

The interface segregation principle is easy to confuse with its neighbours,
because they all concern how code is divided.

- **[Single responsibility](../single-responsibility-principle/)** is about
  why a module changes: it should answer to one group of people with one kind
  of reason. Interface segregation is about what each client sees. A class can
  have a single responsibility and still be used by several kinds of client
  that each need a different slice of it; and a fat interface is often, though
  not always, the visible sign of a class doing too many jobs.
- **[Liskov substitution](../liskov-substitution-principle/)** says a subtype
  must keep its supertype's promises. A method that raises
  `NotImplementedError` breaks one, so fat interfaces push implementers into
  violations. Segregation removes the reason to refuse: a class implements only
  the roles it can honour.
- **[Dependency inversion](../dependency-inversion-principle/)** says
  high-level code should depend on abstractions. Interface segregation says
  what those abstractions should look like: small, and shaped by the high-level
  code that uses them rather than by the low-level code that implements them.
- **[Open-closed](../open-closed-principle/)** asks that code be extended
  without being modified. Adding a new role interface to an existing class,
  rather than widening an old one, is that idea applied to interfaces, and is
  how the 2000 paper suggests interfaces should evolve.[^dpdp]
- **[Inversion of control](../inversion-of-control/)** is where the roles get
  their implementations. A container can register one class under several role
  interfaces, so that each client is injected with the same object seen through
  the interface it asked for.

## What it costs and what it buys

| It buys | It costs |
|---|---|
| **Isolation.** A change to one role reaches only that role's clients and implementers | **More types.** Every role is another interface to name, document and find |
| **Honest implementers.** A class implements only what it can do, so nothing needs to refuse | **Design effort.** Role interfaces require knowing how clients use a class; a header interface needs no thought |
| **Smaller test doubles.** A fake implements the one or two methods the client calls | **Fragmentation.** Split too finely, a client needs five interfaces where one would have read better |
| **Clearer signatures.** A parameter's type says what the function will do with it | **Indirection.** Finding every role a class plays, or every class that plays a role, needs tooling |
| **Substitutability.** Any object with the right methods fits, including ones written later | **Premature splitting.** Interfaces split for clients that do not exist yet add cost and no benefit |

The costs are why the principle should be applied to real clients rather than
imagined ones. An interface with one implementation and one client is not
improved by being split into three; an interface with a dozen methods used in
four different ways by four different modules usually is.

## When to use it

- **Shape interfaces from the client's side.** When a module needs something
  from outside, declare the interface it needs, near that module, with only
  what it calls. Do not reach first for an interface that copies a class.
- **Split when the clients differ.** If different callers use disjoint groups
  of methods, give each group a role interface. If every caller uses most of
  the methods, the interface is not fat; leave it alone.
- **Treat refusals as a signal.** A `NotImplementedError`,
  `NotSupportedException` or `UnsupportedOperationException` in an
  implementation, or an `IsReadOnly`-style flag on an interface, usually means a
  role is missing.
- **Treat big mocks as a signal.** If a unit test needs a fake with ten stubbed
  methods to exercise code that calls one, the code is asking for too much.
- **Keep one class if the data is shared.** Segregate the interfaces, not
  necessarily the implementation. A class that implements several roles over
  the same data is fine.
- **Name the combinations that matter.** When several clients need the same
  group of roles, compose an aggregate interface from them rather than going
  back to a fat one.
- **Weigh the language.** In a compiled language with shared binaries, the
  rebuild cost makes segregation pay early. In a dynamic one, apply it where
  readability, testing and type checking benefit, not to every class.

## Why it matters

Every interface is a promise, and every client of it is bound to all of its
terms, including the ones it never uses. A fat interface makes the clients of
a class into one another's dependants: the report is rebuilt because the
checkout needed something new, the archive pretends to write, and the tests
fake five methods to exercise one. The interface segregation principle undoes
that by moving the interface to the side of the client. Small interfaces named
for roles keep changes local, keep implementations honest and make every
signature say what the code actually needs. Applied with judgement, to real
clients that really differ, it is one of the cheapest design improvements
available; applied by reflex, it scatters a design across interfaces nobody
needed. The skill, as with the rest of SOLID, is in telling the two apart.

## References

[^isp1996]: Martin, R. C. (1996, August). The interface segregation principle. *The C++ Report*, 8. <https://cs.utexas.edu/~downing/papers/ISP-1996.pdf>

[^ispcite]: Hochschule Augsburg. (n.d.). *Martin, R.C. (1996): The Interface Segregation Principle*. Glossar. <https://glossar.hs-augsburg.de/Martin,_R.C._(1996):_The_Interface_Segregation_Principle>

[^asd]: Martin, R. C. (2003). *Agile Software Development, Principles, Patterns, and Practices*. Prentice Hall.

[^spinellis]: Spinellis, D. (2004). Review of *Agile Software Development, Principles, Patterns, and Practices* by R. C. Martin. *ACM Computing Reviews*. <https://www.spinellis.gr/pubs/Breview/2004-CR-AgileDev/html/review.html>

[^header]: Fowler, M. (2006, December 21). *HeaderInterface*. martinfowler.com. <https://martinfowler.com/bliki/HeaderInterface.html>

[^role]: Fowler, M. (2006, December 22). *RoleInterface*. martinfowler.com. <https://martinfowler.com/bliki/RoleInterface.html>

[^wikipedia]: Wikipedia. (n.d.). *Interface segregation principle*. <https://en.wikipedia.org/wiki/Interface_segregation_principle>

[^dpdp]: Martin, R. C. (2000). *Design Principles and Design Patterns*. Object Mentor. <http://staff.cs.utu.fi/~jounsmed/doos_06/material/DesignPrinciplesAndPatterns.pdf>

[^queryinterface]: Microsoft. (2024, February 22). *IUnknown::QueryInterface(REFIID,void)*. Microsoft Learn. <https://learn.microsoft.com/en-us/windows/win32/api/unknwn/nf-unknwn-iunknown-queryinterface(refiid_void)>

[^goio]: The Go Authors. (n.d.). *Package io*. Go Packages. <https://pkg.go.dev/io>

[^effectivego]: The Go Authors. (n.d.). *Effective Go*. <https://go.dev/doc/effective_go>

[^proverbs]: Pike, R. (2015). *Go Proverbs* [Conference talk]. Gopherfest SV 2015. <https://go-proverbs.github.io/>

[^cleanarch]: Martin, R. C. (2017). ISP: The interface segregation principle. In *Clean Architecture: A Craftsman's Guide to Software Structure and Design* (chapter 10). Prentice Hall.

[^relevance]: Martin, R. C. (2020, October 18). *Solid Relevance*. The Clean Code Blog. <https://blog.cleancoder.com/uncle-bob/2020/10/18/Solid-Relevance.html>

[^javacollection]: Oracle. (n.d.). *Interface Collection&lt;E&gt;*. Java SE 21 API specification. <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Collection.html>

[^pep544]: Levkivskyi, I., Lehtosalo, J., & Langa, Ł. (2017). *PEP 544: Protocols: Structural subtyping (static duck typing)*. Python Enhancement Proposals. <https://peps.python.org/pep-0544/>

[^ireadonlylist]: Microsoft. (n.d.). *IReadOnlyList&lt;T&gt; Interface*. .NET API reference, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ireadonlylist-1>
