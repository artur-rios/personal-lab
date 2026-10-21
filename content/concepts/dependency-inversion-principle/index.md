---
title: "What Is the Dependency Inversion Principle? Policy, Detail and Who Owns the Interface"
description: "The dependency inversion principle says that the code holding an application's policy should not depend on the code holding its details, and that both should depend on abstractions the policy owns. Here is what it means, where it came from, from Robert C. Martin's 1996 column to ports and adapters and the clean architecture, why the flow of control and the direction of a dependency can point opposite ways, why the interface has to live with its client, what not to invert, with runnable examples, and how it differs from dependency injection."
date: 2026-10-21T00:05:00Z
categories: ["Concepts"]
tags: ["Dependency Inversion Principle", "SOLID", "Software Design", "Object-Oriented Design", "Ports and Adapters", "Clean Architecture", "Concepts"]
series: ["SOLID"]
seriesOrder: 5
seriesGroup: "The five principles"
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

A checkout that takes a payment has to call the payment provider: there is no
way around that at run time. It does not follow that the checkout's source code
has to *name* the provider, import its SDK, or change when the provider changes
its API. The **dependency inversion principle** is the rule that separates those
two things. It asks which way the arrows between modules should point, and its
answer is that the code holding the important decisions should not depend on the
code holding the details; the details should depend on it. This is part five of
a series on SOLID, after the [single responsibility](../single-responsibility-principle/),
[open-closed](../open-closed-principle/), [Liskov substitution](../liskov-substitution-principle/)
and [interface segregation](../interface-segregation-principle/) principles, and
it leads into [inversion of control](../inversion-of-control/), the mechanism
most programs use to put the principle into practice. This article explains what
the principle says, where it came from, why the flow of control and the
direction of a dependency can point opposite ways, why the abstraction has to
belong to the code that uses it, and what is not worth inverting. Every output
shown here was produced by running the code on Windows 11, with Python 3.14.6,
not written by hand.

## What the dependency inversion principle is

**The dependency inversion principle (DIP) is the rule that a module holding
high-level policy should not depend on the modules holding low-level detail;
both should depend on abstractions, and those abstractions should be shaped by
the policy, not by the details.** Robert C. Martin stated it in 1996 in two
parts: high-level modules should not depend upon low-level modules, both should
depend upon abstractions; and abstractions should not depend upon details,
details should depend upon abstractions.[^martin]

*High-level* and *low-level* are not about layers in a diagram or about which
code is more clever. A high-level module is one that holds the decisions the
application exists to make: how an order is priced, when a payment is taken,
what happens if it is declined. A low-level module holds the means of carrying
those decisions out: the HTTP calls to a particular payment provider, the SQL of
a particular database, the bytes sent to a particular printer. The policy is
what the business would recognise; the detail is what could be replaced without
the business noticing.

Martin's own example was a program that copies characters typed on a keyboard to
a printer. Written as a structured program, a `Copy` routine calls `ReadKeyboard`
and `WritePrinter`, so the one part of the program worth reusing, the loop that
moves characters from a source to a sink, is welded to one keyboard and one
printer. To copy to a disk instead, the routine grows an `if` and a dependency on
a third module, and with every new device another. His fix was to make `Copy`
depend on two abstract classes, a `Reader` and a `Writer`, and to have the
keyboard and the printer implement them.[^martin] The same program in Python
needs no declarations at all, because the abstraction is the file-like protocol
the standard library already defines:

```python
import io


def copy(reader, writer):
    """Martin's Copy, in Python: the policy knows only read and write."""
    while c := reader.read(1):
        writer.write(c)


class Printer:  # a detail written long after copy, which copy never names
    def write(self, c):
        print(f"[printer] {c!r}")


copy(io.StringIO("hi\n"), Printer())
disk = io.StringIO()
copy(io.StringIO("to disk"), disk)
print("[disk]", disk.getvalue())
```

```txt
[printer] 'h'
[printer] 'i'
[printer] '\n'
[disk] to disk
```

`copy` was written once and never edited. The printer and the in-memory "disk"
were plugged in afterwards, and either could be swapped for a socket or a real
file without `copy` knowing. Martin made the same observation about C: a `Copy`
written with `getchar` and `putchar` already obeys the principle, because it
depends on the abstract facilities `stdio.h` declares, and so do the device
drivers underneath.[^martin]

{{< diagram src="copy-program.svg" caption="Martin's Copy program. As a structure chart the policy depends on the details it calls. Inverted, the policy and the details both depend on two abstractions, and the arrows from the details point up." >}}

### Why "inversion"

The name describes a reversal of habit rather than anything the code does at run
time. Martin chose the word because the structured analysis and design methods
of the time produced exactly the shape on the left of the diagram: a hierarchy
of subprograms in which each high-level routine calls, and therefore depends
on, the low-level routines beneath it. A well-designed object-oriented program,
he argued, has a dependency structure that is inverted with respect to
that.[^martin]

His case for the reversal was about what should be allowed to change what. The
high-level modules hold the policy and the business model, the part of the
program that gives it its identity. If they depend on low-level modules, then a
change to a driver or a library can force a change to the policy, which Martin
called absurd: it is the policy that ought to drive changes to the details. And
the high-level modules are the ones worth reusing; low-level code is already
reused well, in the form of libraries.[^martin]

## A short history

### 1996: the Engineering Notebook columns

Martin set out the principle in the third of his *Engineering Notebook* columns
for *The C++ Report*, in May 1996, after columns on the
[open-closed principle](../open-closed-principle/) in January and the
[Liskov substitution principle](../liskov-substitution-principle/) in March. He
presented it as what you get by applying those two rigorously: if code is closed
to modification and every subtype can stand in for its base, the structure that
results has policy and details both hanging off abstractions.[^martin]

The column began with a definition of a bad design that most engineers could
accept: one that is *rigid*, hard to change because every change spreads;
*fragile*, breaking in unexpected places when changed; and *immobile*, hard to
reuse because the useful part cannot be disentangled from the rest. All three,
he argued, come from the way the modules depend on each other.[^martin] After
the Copy program it turned to layering. A naive reading of Grady Booch's advice
that well-structured architectures have clearly defined layers produces a
*Policy* layer that uses a *Mechanism* layer, which uses a *Utility* layer, and
because dependency is transitive the policy ends up sensitive to changes all the
way down. Martin's alternative gave each lower layer an abstract interface that
the layer above uses and the layer below implements, so that no layer depends on
any other. It closed with a button that switches a lamp: the naive `Button`
includes `lamp.h`, so it cannot switch a motor, while an inverted `Button` talks
to an abstract `ButtonClient` that a lamp, a motor or an adapter around a
third-party lamp can implement.[^martin]

### The early 2000s: who owns the interface

Martin collected the principles into a book, *Agile Software Development,
Principles, Patterns, and Practices* (2003), whose chapter on the principle made
explicit something the column had only implied: the inversion is of ownership
as well as of dependency. A utility library is usually thought of as owning its
own interface, but when the principle is applied it is the clients that own the
abstract interfaces, and the servers that implement them.[^asd][^seemann]

Martin Fowler catalogued the same arrangement at the level of packages in
*Patterns of Enterprise Application Architecture* (2002) as the **Separated
Interface**: an interface defined in one package and implemented in another, so
that a client depending on the interface is unaware of the implementation, and
a package that may not depend on another can still call it.[^separated] Two
years later Fowler gave [dependency injection](../inversion-of-control/) its
name, the mechanism by which an implementation reaches a client that only knows
the interface.[^fowler]

### 2005 to 2017: ports, adapters and the dependency rule

In 2005 Alistair Cockburn described the **hexagonal architecture**, also called
**ports and adapters**. An application talks to the outside world only through
*ports*, interfaces defined in its own terms, and every technology, a user
interface, a database, a test harness, is attached through an *adapter* that
translates between that technology and a port. Its stated aim was to let an
application be driven equally by users, programs, tests or scripts, and to be
developed and tested without the databases and devices it would eventually use.
Cockburn tied it explicitly to Martin's principle.[^hexagonal]

Martin's 2012 post **"The Clean Architecture"** drew Cockburn's hexagon, Jeffrey
Palermo's onion architecture and several others as concentric circles and gave
them one rule, the **dependency rule**: source-code dependencies point only
inwards, towards the policy, and nothing in an inner circle names anything in an
outer one. Where the flow of control has to go outwards, from a use case to the
presenter that displays its result, the use case calls an interface declared in
its own circle and the outer circle implements it, which is the dependency
inversion principle at the scale of a whole system.[^cleanblog] The 2017 book of
the same name developed it at length.[^cleanbook]

### A timeline at a glance

| Year | Event |
|---|---|
| 1996 | Martin's *C++ Report* column states the dependency inversion principle |
| 2002 | Fowler catalogues the Separated Interface pattern |
| 2003 | Martin's *Agile Software Development* makes interface ownership explicit |
| 2004 | Fowler names dependency injection |
| 2005 | Cockburn describes the hexagonal architecture, ports and adapters |
| 2012 | Martin's "The Clean Architecture" states the dependency rule |
| 2017 | Martin's *Clean Architecture* book |

## Two arrows that point different ways

The principle is about **source-code dependencies**: which module imports,
includes or names which. That is a different arrow from the **flow of
control**, which module calls which at run time, and the whole principle rests
on the fact that the two can be made to point in opposite directions.

### Before: the policy names the detail

Start with a checkout that takes payments through a provider called CardCo. The
provider's SDK is a stand-in here, a few lines that print instead of making a
network call, but its shape is typical: amounts in cents, results as
dictionaries, error codes as strings.

```python
# vendor/cardco_sdk.py
# Stands in for a payment provider's SDK: amounts in cents, results as dicts.
class CardCoClient:
    def __init__(self, api_key):
        self.api_key = api_key

    def create_charge(self, amount_cents, currency, source):
        print(f"  [cardco] POST /charges {amount_cents} {currency.lower()}")
        if source == "tok_declined":
            return {"id": None, "status": "failed", "code": "card_declined"}
        return {"id": "ch_1001", "status": "succeeded"}
```

The first version of the checkout does what comes naturally and uses the SDK
directly:

```python
# shop/checkout.py
from decimal import Decimal

from vendor.cardco_sdk import CardCoClient


class Checkout:
    def __init__(self):
        self.cardco = CardCoClient(api_key="from-config")

    def place(self, total: Decimal, card_token: str) -> str:
        result = self.cardco.create_charge(
            amount_cents=int(total * 100), currency="EUR", source=card_token)
        if result["status"] != "succeeded":
            raise RuntimeError(f"payment failed: {result['code']}")
        return result["id"]
```

A `main.py` that calls `Checkout().place(Decimal("42.50"), "tok_visa")` and
prints the result shows it working:

```txt
  [cardco] POST /charges 4250 eur
order placed, charge ch_1001
```

It works, and it has every problem Martin listed. The checkout's source code
knows that CardCo counts in cents, reports failure in a dictionary and spells
its status `"succeeded"`. Changing provider means editing the checkout.
Testing the checkout means either reaching CardCo or replacing a module behind
Python's back. And the checkout cannot be reused anywhere the CardCo SDK is not
installed. Here the flow of control and the source-code dependency point the
same way: the checkout calls CardCo, and the checkout imports CardCo.

### After: the policy owns the interface

The inverted version starts by writing down what the checkout needs from a
payment provider, in the checkout's own terms, and putting that next to the
checkout:

```python
# shop/checkout.py
from decimal import Decimal
from typing import Protocol


class PaymentDeclined(Exception):
    pass


class PaymentGateway(Protocol):
    """What checkout needs from a payment provider, in checkout's own terms."""

    def charge(self, amount: Decimal, card_token: str) -> str:
        """Take the payment and return a reference, or raise PaymentDeclined."""
        ...


class Checkout:
    def __init__(self, payments: PaymentGateway):
        self.payments = payments

    def place(self, total: Decimal, card_token: str) -> str:
        if total <= 0:
            raise ValueError("nothing to pay for")
        print(f"  [checkout] charging {total}")
        return self.payments.charge(total, card_token)
```

`PaymentGateway` speaks in decimals and exceptions, because that is how the shop
thinks about money and failure. Cents, dictionaries and status strings have
gone from the policy altogether. They move into an **adapter**, a module in a
separate package whose only job is to translate between the checkout's
interface and CardCo's:

```python
# adapters/cardco.py
from decimal import Decimal

from shop.checkout import PaymentDeclined, PaymentGateway
from vendor.cardco_sdk import CardCoClient


class CardCoGateway(PaymentGateway):
    """Translates checkout's PaymentGateway into CardCo's API."""

    def __init__(self, client: CardCoClient):
        self.client = client

    def charge(self, amount: Decimal, card_token: str) -> str:
        result = self.client.create_charge(
            amount_cents=int(amount * 100), currency="EUR", source=card_token)
        if result["status"] != "succeeded":
            raise PaymentDeclined(result["code"])
        return result["id"]
```

A second adapter keeps payments in memory, for tests and for running the shop
without a provider:

```python
# adapters/fake.py
from decimal import Decimal

from shop.checkout import PaymentDeclined, PaymentGateway


class FakeGateway(PaymentGateway):
    """Records charges in memory; a token of 'tok_declined' is refused."""

    def __init__(self):
        self.charges = []

    def charge(self, amount: Decimal, card_token: str) -> str:
        if card_token == "tok_declined":
            raise PaymentDeclined("card_declined")
        self.charges.append(amount)
        return f"fake_{len(self.charges)}"
```

Something still has to choose an adapter and hand it to the checkout. That is
the job of the **composition root**, the one module at the entry point that is
allowed to know every concrete class; how it does so, by hand or with a
container, is the subject of the [inversion of control](../inversion-of-control/)
article and is kept deliberately plain here:

```python
# main.py
import sys
from decimal import Decimal

from adapters.cardco import CardCoGateway
from adapters.fake import FakeGateway
from shop.checkout import Checkout, PaymentDeclined
from vendor.cardco_sdk import CardCoClient

# The composition root: the one place that knows which adapter is in use.
if sys.argv[1] == "cardco":
    gateway = CardCoGateway(CardCoClient(api_key="from-config"))
else:
    gateway = FakeGateway()

checkout = Checkout(gateway)
for token in ("tok_visa", "tok_declined"):
    try:
        print(f"{sys.argv[1]}: placed, ref", checkout.place(Decimal("42.50"), token))
    except PaymentDeclined as error:
        print(f"{sys.argv[1]}: declined ({error})")
```

Run with `cardco` and then with `fake` as its argument, it places one order
that succeeds and one that is declined, each time:

```txt
  [checkout] charging 42.50
  [cardco] POST /charges 4250 eur
cardco: placed, ref ch_1001
  [checkout] charging 42.50
  [cardco] POST /charges 4250 eur
cardco: declined (card_declined)
```

```txt
  [checkout] charging 42.50
fake: placed, ref fake_1
  [checkout] charging 42.50
fake: declined (card_declined)
```

The provider changed and `shop/checkout.py` did not. The decline, which CardCo
reports as a dictionary and the fake reports by refusing a token, reaches the
checkout's caller in both cases as the same `PaymentDeclined`, because each
adapter translates its provider's idea of failure into the shop's.

### Reading the arrows

The trace shows the flow of control: `[checkout]` runs first and then CardCo,
exactly as before. The imports tell a different story, and they can be read
straight out of the source. The script below parses every module with Python's
`ast` module, lists what it imports, sets the standard library aside, and checks
one rule: the `shop` package may depend on nothing but itself and the standard
library.

```python
import ast
import sys
from pathlib import Path


def imports_of(path):
    """The top-level names a module imports, read from its source."""
    found = set()
    for node in ast.walk(ast.parse(path.read_text())):
        if isinstance(node, ast.Import):
            found |= {alias.name for alias in node.names}
        elif isinstance(node, ast.ImportFrom):
            found.add(node.module)
    return found


def report(root):
    print(f"{root.name}/")
    broken = []
    for path in sorted(root.rglob("*.py")):
        if path.name == "__init__.py":
            continue
        module = ".".join(path.relative_to(root).with_suffix("").parts)
        names = imports_of(path)
        stdlib = sorted(n for n in names if n.split(".")[0] in sys.stdlib_module_names)
        ours = sorted(names - set(stdlib))
        extra = f"  (stdlib: {', '.join(stdlib)})" if stdlib else ""
        print(f"  {module:<18} -> {', '.join(ours) or '(nothing)'}{extra}")
        if module.startswith("shop."):
            broken += [f"{module} -> {n}" for n in ours if not n.startswith("shop")]
    verdict = "kept" if not broken else "broken by " + "; ".join(broken)
    print(f"  policy depends only on itself and the stdlib: {verdict}")


for root in sys.argv[1:]:
    report(Path(root))
```

Run over the two versions, saved side by side in `before/` and `after/`:

```txt
before/
  main               -> shop.checkout  (stdlib: decimal)
  shop.checkout      -> vendor.cardco_sdk  (stdlib: decimal)
  vendor.cardco_sdk  -> (nothing)
  policy depends only on itself and the stdlib: broken by shop.checkout -> vendor.cardco_sdk
after/
  adapters.cardco    -> shop.checkout, vendor.cardco_sdk  (stdlib: decimal)
  adapters.fake      -> shop.checkout  (stdlib: decimal)
  main               -> adapters.cardco, adapters.fake, shop.checkout, vendor.cardco_sdk  (stdlib: decimal, sys)
  shop.checkout      -> (nothing)  (stdlib: decimal, typing)
  vendor.cardco_sdk  -> (nothing)
  policy depends only on itself and the stdlib: kept
```

Before, `shop.checkout` imports the vendor SDK. After, it imports nothing of the
application's at all, and the arrow between `shop` and `adapters` runs from
`adapters.cardco` to `shop.checkout`: from the detail to the policy, against the
flow of control. The only module that depends on everything is `main`, which is
what a composition root is for.

{{< diagram src="flow-vs-dependency.svg" caption="Control flows from the checkout out to the provider. The imports follow it inside each package, but at the boundary between shop and adapters the adapter imports the interface from shop: the dependency points back against the flow of control." >}}

That reversal at a boundary is the mechanism behind every use of the principle,
from Martin's `Copy` to the clean architecture's use cases and presenters. A
call can go anywhere at run time through an interface, so the source code is
free to point the other way.[^cleanblog]

### What the policy can now do without the detail

Martin's third symptom, immobility, can be tested directly. The script below
copies *only* the `shop` package into an empty directory, where neither the
vendor SDK nor the adapters exist, and tries to place an order through a
`Recorder` written on the spot:

```python
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Reuse the policy somewhere the vendor SDK does not exist: copy only shop/.
PROBE = """
from decimal import Decimal
from shop.checkout import Checkout

class Recorder:
    def charge(self, amount, card_token):
        return f"recorded {amount}"

print(Checkout(Recorder()).place(Decimal("42.50"), "tok_visa"))
"""

for tree in sys.argv[1:]:
    with tempfile.TemporaryDirectory() as elsewhere:
        shutil.copytree(Path(tree, "shop"), Path(elsewhere, "shop"))
        run = subprocess.run([sys.executable, "-c", PROBE], cwd=elsewhere,
                             capture_output=True, text=True)
        last = (run.stdout or run.stderr).strip().splitlines()[-1]
        print(f"{tree}: {last}")
```

```txt
before: ModuleNotFoundError: No module named 'vendor'
after: recorded 42.50
```

The original checkout cannot even be imported without CardCo. The inverted one
runs with a class that does not import `PaymentGateway` or inherit from it:
Python's protocols are structural, so anything with a matching `charge` method
satisfies the type, and subclassing a protocol is optional.[^pep544] The two
adapters above subclass it anyway, which makes the relationship visible and lets
a type checker report a mismatched signature at the class rather than at the
call.

## Who owns the abstraction

It is tempting to summarise the principle as "depend on interfaces", and that
summary misses the half of it that does the work. An interface only inverts a
dependency if it lives on the right side of the boundary.

Suppose the team that wrote the CardCo adapter had also written the interface,
and put it where adapter authors tend to put things, in their own package:

```python
# adapters/base.py
from decimal import Decimal
from typing import Protocol


class PaymentDeclined(Exception):
    pass


class PaymentGateway(Protocol):
    def charge(self, amount: Decimal, card_token: str) -> str: ...
```

The checkout is otherwise unchanged, except that it now imports
`from adapters.base import PaymentGateway`, and the adapters and `main` import
from there too. The program runs exactly as before. The checker and the reuse
probe, run over this version, say something else:

```txt
misplaced/
  adapters.base      -> (nothing)  (stdlib: decimal, typing)
  adapters.cardco    -> adapters.base, vendor.cardco_sdk  (stdlib: decimal)
  adapters.fake      -> adapters.base  (stdlib: decimal)
  main               -> adapters.base, adapters.cardco, adapters.fake, shop.checkout, vendor.cardco_sdk  (stdlib: decimal, sys)
  shop.checkout      -> adapters.base  (stdlib: decimal)
  vendor.cardco_sdk  -> (nothing)
  policy depends only on itself and the stdlib: broken by shop.checkout -> adapters.base
```

```txt
misplaced: ModuleNotFoundError: No module named 'adapters'
```

There is an interface, the checkout depends only on it, and nothing has been
inverted. The package holding the policy still depends on the package holding
the details, so it still cannot be reused without them, and it still changes
when the people who own that package decide the interface should change. Worse,
an interface owned by the detail tends to drift towards the detail: the next
provider's adapter adds `amount_cents`, then a `currency` the shop never
varies, and the checkout is back to thinking in CardCo's terms with an extra
layer in the way.

This is the point Martin made explicit in his book: under the principle, the
clients own the abstract interfaces.[^asd][^seemann] The interface is written in
the policy's vocabulary, published from the policy's package, and changed only
when the policy's needs change. The implementers come to it, as `CardCoGateway`
comes to `shop.checkout`. Fowler's Separated Interface is the same move seen
from the packages: the interface is defined in one package and implemented in
another, so the client can be unaware of the implementation.[^separated] Which
package it is defined in is what decides whether anything was inverted.

{{< diagram src="ownership.svg" caption="The same two classes in two packages, three ways. Only when the interface belongs to the policy's package does the dependency between the packages point from the detail to the policy." >}}

Ownership is also what makes the interface the right size. Because it is written
from what the checkout needs rather than from what CardCo offers, it has one
method, not the forty a provider's SDK exposes. Keeping interfaces shaped by
their clients is the subject of the [interface segregation
principle](../interface-segregation-principle/); dependency inversion is what
puts them in the client's hands in the first place.

## What to invert and what to leave alone

Read literally, "depend upon abstractions" would forbid `shop.checkout` from
importing `Decimal`, a concrete class from another package. Nobody means that,
and the checker above deliberately sets the standard library aside. The test is
not whether a dependency is concrete but whether it is **volatile**: likely to
change, likely to be replaced, or likely to drag in the outside world.

In *Clean Architecture* Martin draws the line the same way. Concrete
dependencies on stable facilities such as the language's string class or the
operating system's services are tolerated, because they can be relied on not to
change; it is the volatile concrete parts of a system, the ones under active
development and frequent change, that a policy should avoid depending
on.[^cleanbook] In practice that sorts dependencies roughly like this:

| Leave it concrete | Put an interface in front of it |
|---|---|
| The standard library: `Decimal`, `datetime`, collections, `pathlib` | Payment providers, mail and SMS gateways, other companies' APIs |
| Value objects of the domain: `Money`, `OrderId`, `Address` | Databases, queues and file storage the policy reads or writes |
| Pure functions with no side effects | The clock, random numbers and anything else nondeterministic |
| Mature libraries the application is built around and would never swap | Code owned by another team that changes on its own schedule |

The right-hand column has two things in common. Each item is something the
policy would like to be tested without, and each is something whose changes
the policy should not have to absorb. The left-hand column is not less
important; it is simply less likely to move, and an abstraction over something
that never moves is a cost with nothing to show for it.

## Common misreadings

### "Dependency inversion means dependency injection"

They are often mentioned in the same breath and they answer different
questions. The principle is a **design rule**: which way the source-code
dependencies point and who owns the abstraction. Dependency injection is a
**mechanism**: how an object receives a collaborator from outside instead of
creating it. Injection is the usual way to get a `CardCoGateway` into a
`Checkout` that only knows `PaymentGateway`, but a checkout can receive a
concrete `CardCoClient` by injection, which is injection without inversion, and
a module can depend only on an interface it owns while finding the
implementation some other way. The [inversion of control](../inversion-of-control/#ioc-dependency-injection-and-dependency-inversion)
article compares the two at length.

### "Every class needs an interface"

A codebase where every `OrderService` has an `IOrderService` beside it, with
the same methods and a single implementation, has followed the letter of
"depend upon abstractions" and none of its purpose. Fowler calls an interface
that simply mirrors all the public methods of one class a **header interface**,
and contrasts it with a **role interface**, defined by looking at one specific
interaction between a consumer and a supplier.[^roleinterface] A header
interface belongs to the implementation, so it inverts nothing; it changes
whenever the class does, and doubles the number of files to edit when it does.
`PaymentGateway` is a role interface: it is what the checkout needs, and a
class that does many other things can play that role among others.

### "An interface anywhere will do"

The `misplaced` example above is the most common way the principle is followed
without being applied. An interface in the implementation's package, in a
vendor's SDK, or in a shared `common` package that everything depends on leaves
the policy pointing at the details. If deleting the adapters package would stop
the policy from compiling or importing, the dependency has not been inverted.

### "The details now depend on the high-level code, so the layers are upside down"

The adapter does import from `shop`, but only the interface and the types it
mentions, not the checkout's logic. The arrow points at an abstraction that the
policy publishes for the purpose. That is the second half of Martin's statement,
details depending upon abstractions, and it is what lets the policy be compiled,
tested and reused alone.[^martin]

## The principle at the scale of a system

The same move scales from a class to an architecture. Martin's layered example
already applied it to whole layers;[^martin] ports and adapters apply it to the
boundary between an application and everything it talks to, with the
application owning the ports;[^hexagonal] and the clean architecture's
dependency rule applies it to every boundary between circles.[^cleanblog] At
that scale the boundaries are usually packages, assemblies or modules rather
than classes, and the rule becomes one about which of them may reference which.

At that scale the rule is also worth checking mechanically, because a single
convenient import is enough to break it and nothing at run time will notice.
The checker in this article is a few dozen lines; many languages and build
systems can enforce the same thing with project references that only point one
way, or with tools that fail a build when a forbidden import appears. A check
that runs with the tests turns the principle from something reviewers have to
remember into something the build refuses to let slip.

## What it costs and what it buys

| It buys | It costs |
|---|---|
| **Protected policy.** Changes to a provider, a database or a library stop at the adapter instead of reaching the business rules | **More pieces.** An interface, at least one adapter and a composition root where there was one class |
| **Testability.** The policy can be run with in-memory stand-ins, as `FakeGateway` and `Recorder` showed | **Indirection.** Reading the policy no longer shows which implementation runs; that is decided in the composition root |
| **Reuse.** The policy can be imported and run where none of the details exist | **Design effort.** Finding an interface in the policy's own terms takes more thought than wrapping the SDK one method at a time |
| **Replaceability.** A second provider is a new adapter, not an edit to the checkout | **Translation code.** Every adapter converts between two vocabularies, and conversions can be wrong |
| **A boundary that can be checked.** "The policy imports nothing but itself and the standard library" is a rule a script can enforce | **Premature abstraction.** An interface over something that never varies is all cost, and a bad interface is harder to remove than none |

## When to use it

- **Invert dependencies on the volatile outside world**: payment providers,
  messaging, storage, other teams' services, the clock. These are what the
  policy most needs protecting from and most needs to be tested without.
- **Put the interface in the policy's package**, write it in the policy's
  vocabulary, and change it only when the policy's needs change. If it
  mentions the provider's concepts, it belongs to the provider.
- **Make interfaces roles, not headers.** One interface per thing a client
  needs, with the methods that client calls, rather than a copy of an
  implementation's public surface.
- **Leave stable dependencies concrete.** The standard library, value objects,
  pure functions and the framework the whole application is committed to do
  not need an abstraction in front of them.
- **Keep the wiring in one place.** The composition root is the only module
  that should depend on everything. Getting implementations to the policy is
  the job of [inversion of control](../inversion-of-control/), by hand or with
  a container.
- **Enforce the direction.** Use one-way project references, an import checker
  or an architecture test, so that the first convenient import from policy to
  detail fails the build.

## Why it matters

Most of what makes a codebase pleasant or painful to change is the shape of its
dependencies. Code that depends on its details is rigid, fragile and immobile in
exactly the ways Martin described in 1996, and the cure he proposed has hardly
needed revising since: decide which code holds the decisions, give it the
interfaces it needs in its own terms, and make everything else come to it. The
same idea, applied at different scales, is behind plug-in systems, the
hexagonal and clean architectures, and the everyday habit of testing business
logic against an in-memory fake. The principle is easy to state and easy to
follow in letter only, with an interface for every class or an interface in the
wrong package. The question that keeps it honest is the one the reuse probe
asked: could the policy be picked up and run somewhere none of the details
exist? If it could, the dependencies point the right way.

## References

[^martin]: Martin, R. C. (1996, May). The dependency inversion principle. *The C++ Report*. <https://cs.utexas.edu/~downing/papers/DIP-1996.pdf>

[^asd]: Martin, R. C. (2003). *Agile Software Development, Principles, Patterns, and Practices*. Prentice Hall. Chapter 11, "DIP: The Dependency-Inversion Principle"; the same chapter appears in Martin, R. C., & Martin, M. (2006). *Agile Principles, Patterns, and Practices in C#*. Prentice Hall.

[^seemann]: Seemann, M. (2014, December 24). *Placement of Abstract Factories*. ploeh blog. <https://blog.ploeh.dk/2014/12/24/placement-of-abstract-factories/>

[^separated]: Fowler, M. (2002). Separated Interface. In *Patterns of Enterprise Application Architecture*. Addison-Wesley. <https://martinfowler.com/eaaCatalog/separatedInterface.html>

[^fowler]: Fowler, M. (2004, January 23). *Inversion of control containers and the dependency injection pattern*. martinfowler.com. <https://martinfowler.com/articles/injection.html>

[^hexagonal]: Cockburn, A. (2005). *Hexagonal architecture* (HaT Technical Report 2005.02). <https://alistair.cockburn.us/hexagonal-architecture/>

[^cleanblog]: Martin, R. C. (2012, August 13). The clean architecture. *The Clean Code Blog*. <https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html>

[^cleanbook]: Martin, R. C. (2017). *Clean Architecture: A Craftsman's Guide to Software Structure and Design*. Prentice Hall.

[^roleinterface]: Fowler, M. (2006, December 22). *RoleInterface*. martinfowler.com. <https://martinfowler.com/bliki/RoleInterface.html>

[^pep544]: Levkivskyi, I., Lehtosalo, J., & Langa, Ł. (2017). *PEP 544: Protocols: Structural subtyping (static duck typing)*. Python Software Foundation. <https://peps.python.org/pep-0544/>
