---
title: "What Is Inversion of Control? Frameworks, Callbacks, Dependency Injection and Containers"
description: "Inversion of control is what happens when someone else's code decides when yours runs, or what it works with. Here is what the term means, where it came from, the forms it takes, from callbacks and event loops to the template method and dependency injection, how an IoC container works inside, with runnable examples, how it differs from the dependency inversion principle, and when it is worth it."
date: 2026-10-20T23:00:00Z
categories: ["Concepts"]
tags: ["Inversion of Control", "Dependency Injection", "Design Patterns", "Software Design", "Frameworks", "Concepts"]
series: ["SOLID"]
seriesOrder: 6
seriesGroup: "Putting it to work"
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

A web framework calls a function when a request arrives. A test runner finds
the tests in a file and runs each one. A browser calls a handler when a button
is clicked, and an application server hands a class the database connection it
asked for in its constructor. In each case the code a programmer wrote does not
decide when it runs or where its collaborators come from: something else does.
That reversal has a name, **inversion of control**, and it is one of the ideas
most of modern software is quietly built on. This article explains what it
means, where the term came from, the forms it takes, how dependency injection
and IoC containers work inside, and when the indirection is worth paying for.
It closes a series on [SOLID](../../series/solid/): where the
[dependency inversion principle](../dependency-inversion-principle/) says which
way dependencies should point, this is the mechanism that makes them point
that way at run time. Every output shown here was produced by running the code on Windows 11, with
Python 3.14.6 and with the .NET 10 SDK and Microsoft.Extensions.DependencyInjection
10.0.13, not written by hand.

## What inversion of control is

**Inversion of control (IoC) is the arrangement in which a piece of reusable
code, usually a framework, calls the code a programmer writes, instead of the
programmer's code calling it.** The control flow, who decides what runs next,
belongs to the framework, and the programmer's code is plugged into it.

The clearest way to see it is to compare a library with a framework. A library
is a set of functions a program calls; each call does some work and returns
control to the caller. A framework embodies a design of its own: the programmer
fills in pieces, and the framework calls those pieces at the right moments.
Martin Fowler names that inversion as the very thing that distinguishes a
framework from a library.[^fowlerbliki] Ralph Johnson and Brian Foote described
it in 1988: the methods a user writes to tailor a framework are often called
from inside the framework rather than from the user's own code, so the
framework, not the application, plays the role of the main
program.[^johnsonfoote]

{{< diagram src="who-calls-whom.svg" caption="With a library your code is in charge and calls out; with a framework the framework is in charge and calls in. Same pieces, opposite arrows." >}}

A few lines of Python show the difference. The first function is in charge: it
asks for each value in turn and decides what happens next. The second half
hands the loop to a tiny framework, registers two handlers, and lets the
framework call them as events arrive:

```python
from collections import defaultdict


# Your code in charge: it asks for each input and decides what happens next.
def ask_loop(answers):
    replies = iter(answers)
    name = next(replies)
    print(f"[program] asked for a name, got {name!r}")
    colour = next(replies)
    print(f"[program] asked for a colour, got {colour!r}")
    print(f"[program] {name} likes {colour}")


# The framework in charge: it owns the loop and calls whatever was registered.
class TinyFramework:
    def __init__(self):
        self.handlers = defaultdict(list)

    def on(self, event):
        def register(handler):
            self.handlers[event].append(handler)
            return handler
        return register

    def run(self, events):
        for event, payload in events:
            for handler in self.handlers[event]:
                print(f"[framework] {event} -> {handler.__name__}")
                handler(payload)


app = TinyFramework()
profile = {}


@app.on("name")
def remember_name(value):
    profile["name"] = value


@app.on("colour")
def remember_colour(value):
    profile["colour"] = value
    print(f"[handler] {profile['name']} likes {value}")


ask_loop(["Ada", "green"])
print()
app.run([("name", "Ada"), ("colour", "green"), ("size", 42)])
```

```txt
[program] asked for a name, got 'Ada'
[program] asked for a colour, got 'green'
[program] Ada likes green

[framework] name -> remember_name
[framework] colour -> remember_colour
[handler] Ada likes green
```

Both halves do the same work, but the second one never says *when* anything
happens. The handlers only say what to do *if* their event comes, and the
`size` event, which nobody registered for, passes without a word. That is the
trade at the heart of inversion of control: the programmer gives up the main
loop, and in return gets one that someone else has written, tested and made to
handle the cases the programmer would rather not think about.

### Don't call us, we'll call you

The idea is often summed up as the **Hollywood principle**: *don't call us,
we'll call you*. The phrase comes from Richard Sweet's paper on the Mesa
programming environment at Xerox PARC, where "Hollywood's Law" was a design
goal for the tools of the environment: rather than asking the user for a
command and then executing it, a tool should let the system notify it of the
user's actions.[^sweet][^fowlerbliki] It is the same reversal: the tool does not
poll, it waits to be called.

## A short history

### The 1980s: frameworks and the inverted main program

The behaviour is older than the name. Any program built on an interrupt
handler, an operating system's callbacks or a windowing system's event loop has
handed some control to code it did not write. What changed in the 1980s was
that object-oriented frameworks made the arrangement deliberate. Sweet's Mesa
paper, published in 1985, made "don't call us, we'll call you" an explicit
design goal for the tools of a programming environment.[^sweet] Johnson and
Foote's 1988 article "Designing Reusable Classes" described frameworks, sets of
classes that embody an abstract design for a family of related problems, and observed
that the framework, by calling the methods its users supply, takes over the
role of the main program. Fowler traces the term *inversion of control* to that
paper.[^johnsonfoote][^fowlerbliki]

### The 1990s: patterns and principles

In 1994 the *Design Patterns* book by Gamma, Helm, Johnson and Vlissides
catalogued the **Template Method**, a base class whose algorithm calls steps
that subclasses fill in: inversion of control within a single class
hierarchy.[^gof] In 1996 Robert C. Martin published the **dependency inversion
principle** in his column for *The C++ Report*, a rule about which way
dependencies between modules should point.[^martin] Despite the similar name it
is a different idea, with [an article of its own](../dependency-inversion-principle/),
and the two are compared [below](#ioc-dependency-injection-and-dependency-inversion).

### The 2000s: containers and dependency injection

Around the turn of the century the Java world brought the term into everyday
use, as a reaction against the heavyweight component model of the time. The
**Apache Avalon** project, proposed in January 1999, made inversion of control
a central design principle of its component framework, with one of its
founders, Stefano Mazzocchi, promoting the concept.[^avalon] In 2002 Rod
Johnson's book *Expert One-on-One J2EE Design and Development* shipped with
about 30,000 lines of framework code that already contained an IoC container;
that code became the **Spring Framework**, which went public in June 2003 and
reached version 1.0 in March 2004.[^springorigins][^spring10] **PicoContainer**,
a small container that built objects through their constructors, released its
1.0 in June 2004 after about a year of work.[^pico][^fowler]

By then *inversion of control* had become the name of a whole category of
"lightweight containers", and Martin Fowler argued in January 2004 that the
name was too generic: every framework inverts control in some way, so saying a
container did so said little. The particular inversion these containers
performed was about how a component *gets its dependencies*, and after
discussion with the advocates of IoC he proposed a more specific name,
**dependency injection**.[^fowler] The name stuck.

In March 2007 Google released **Guice**, its internal Java dependency injection
framework, as open source, with Bob Lee leading the project.[^guice] Lee and
Rod Johnson then led **JSR 330**, which standardised a common set of
annotations for Java dependency injection, including `@Inject`, and reached its
final release in October 2009.[^jsr330][^inject]

### Today: built into the platform

Dependency injection is now part of the platforms themselves rather than an
add-on. .NET ships a container in `Microsoft.Extensions.DependencyInjection`,
and describes dependency injection as a technique for achieving inversion of
control between classes and their dependencies.[^msdi] Angular builds it into
the framework: components and services ask for what they need, and a hierarchy
of injectors supplies it.[^angulardi][^angularhier] Spring's reference
documentation still introduces its core as *the IoC container*, and calls
dependency injection a specialised form of inversion of control.[^springioc]

### A timeline at a glance

| Year | Event |
|---|---|
| 1985 | Sweet's Mesa paper makes "don't call us, we'll call you" a design goal for programming tools |
| 1988 | Johnson and Foote describe frameworks that invert control of the main program |
| 1994 | *Design Patterns* catalogues the Template Method |
| 1996 | Martin publishes the dependency inversion principle |
| 1999 | Apache Avalon is proposed, with inversion of control as a core principle |
| 2002 | Rod Johnson's book ships the code that becomes Spring |
| 2004 | Fowler names *dependency injection*; Spring 1.0 and PicoContainer 1.0 are released |
| 2007 | Google open-sources Guice |
| 2009 | JSR 330 standardises `@Inject` for Java |

## The forms it takes

Inversion of control is a family of techniques rather than one. They share the
reversal, someone else's code deciding when yours runs, and differ in what is
handed over.

{{< diagram src="family.svg" caption="Inversion of control is the umbrella. Dependency injection is the member that hands over the choice of collaborators; the dependency inversion principle is a related design rule, not a member." >}}

### Callbacks and event handlers

A **callback** is a function passed to other code so that the other code can
call it later. Sorting with a comparison function, registering a click handler
in a browser and passing a completion function to an asynchronous read are all
callbacks. The receiver decides when, and how often, the function runs.

### Event loops

An **event loop** is a framework in its smallest form. The program registers
callbacks and returns; the runtime waits for events and calls whatever was
registered for them. Node.js is built this way: when an I/O operation
completes, its callback is placed in a queue, and the loop works through its
phases, timers, pending callbacks, polling for I/O and the rest, running the
queued callbacks in order.[^nodeloop] The program never writes the loop; it
only writes what happens inside it, as `TinyFramework` above showed.

### The template method

The **Template Method** puts the inversion inside a class hierarchy. A base
class defines the skeleton of an algorithm and calls steps that subclasses
supply; the subclasses never call the skeleton's steps themselves, they are
called.[^gof]

```python
from abc import ABC, abstractmethod


class Report(ABC):
    """The skeleton is fixed here; subclasses only fill in the steps."""

    def render(self):  # the template method: subclasses do not override it
        lines = [self.header()]
        lines += [f"  {row}" for row in self.rows()]
        lines.append(self.footer())
        return "\n".join(lines)

    def header(self):
        return f"== {type(self).__name__} =="

    @abstractmethod
    def rows(self): ...

    def footer(self):  # a hook with a default the subclass may replace
        return "-- end --"


class SalesReport(Report):
    def rows(self):
        return ["north: 120", "south: 95"]


class StockReport(Report):
    def rows(self):
        return ["pens: 40"]

    def footer(self):
        return "-- reorder below 50 --"


for report in (SalesReport(), StockReport()):
    print(report.render())
```

```txt
== SalesReport ==
  north: 120
  south: 95
-- end --
== StockReport ==
  pens: 40
-- reorder below 50 --
```

`SalesReport` and `StockReport` contain no control flow at all. They answer
two questions, what the rows are and what the footer says, and `render` decides
when to ask. This is Johnson and Foote's *white-box* framework: it is reused by
subclassing, so its users must know something of its insides. Their *black-box*
frameworks are reused instead by plugging in objects that follow an interface,
which is where dependency injection comes from.[^johnsonfoote]

### Frameworks and plug-ins

A full framework combines all of these. A test runner is a good example
because it is so familiar. Python's `unittest` discovers the test files,
finds the `TestCase` subclasses inside them, creates an instance for each test
method, and for each one calls `setUp`, then the test, then
`tearDown`.[^unittest] The person who writes the tests never calls any of it.
Web frameworks do the same with request handlers, GUI toolkits with widgets and
plug-in hosts with plug-ins.

### Dependency injection

The last member of the family hands over a different decision. The others give
away *when* code runs; **dependency injection** gives away *which objects it
works with*. It is the subject of the rest of this article.

## Dependency injection

### The problem it solves

A class that creates its own collaborators decides, inside itself, exactly
which ones it uses. Nothing outside the class can change that decision, and
nothing outside it can even see it:

```python
from typing import Protocol


class SmtpMailer:
    def send(self, to, text):
        raise ConnectionError("no SMTP server in this sandbox")


# Before: the service picks and builds its own collaborator.
class SignupServiceBefore:
    def __init__(self):
        self.mailer = SmtpMailer()  # fixed here, invisible from outside

    def sign_up(self, email):
        self.mailer.send(email, "Welcome!")
        return f"signed up {email}"


# After: the service states what it needs; whoever builds it decides what.
class Mailer(Protocol):
    def send(self, to: str, text: str) -> None: ...


class SignupService:
    def __init__(self, mailer: Mailer):  # constructor injection
        self.mailer = mailer

    def sign_up(self, email):
        self.mailer.send(email, "Welcome!")
        return f"signed up {email}"


class OutboxMailer:  # a stand-in that only records what it was asked to send
    def __init__(self):
        self.sent = []

    def send(self, to, text):
        self.sent.append((to, text))


try:
    SignupServiceBefore().sign_up("ada@example.com")
except ConnectionError as error:
    print("before:", error)

outbox = OutboxMailer()
service = SignupService(outbox)  # the caller composes the objects
print("after:", service.sign_up("ada@example.com"))
print("outbox:", outbox.sent)
```

```txt
before: no SMTP server in this sandbox
after: signed up ada@example.com
outbox: [('ada@example.com', 'Welcome!')]
```

`SignupServiceBefore` cannot be used, or tested, without a mail server, because
it builds an `SmtpMailer` the moment it is created. `SignupService` does the
same job but only *states* what it needs: something with a `send` method. The
code that creates it decides what that is, a real mailer in production and an
outbox that just records the message in a test. The service has not changed;
only the decision has moved out of it.

{{< diagram src="injection.svg" caption="Before, the class creates its collaborator and hides the choice. After, it declares the interface it needs, and the composition root at the entry point decides and passes in the implementation." >}}

That move is the whole of dependency injection. A **dependency** is an object
another object needs to do its work; **injecting** it means handing it in from
outside rather than letting the object find or build it. Fowler's original
description says the same thing in terms of the containers of the time: a
separate object, the assembler, populates a field of the class with a suitable
implementation.[^fowler]

### Three ways to inject

Fowler distinguished three forms, by how the dependency is handed over:[^fowler]

| Form | How the dependency arrives | Associated in 2004 with |
|---|---|---|
| **Constructor injection** | As a constructor argument; the object cannot exist without it | PicoContainer |
| **Setter injection** | Through a property or setter method after construction | Spring |
| **Interface injection** | Through a method of an interface the object implements for the purpose | Avalon |

Constructor injection has become the usual default, because it makes the
dependencies part of the object's signature: an object that has been created at
all has everything it needs, and a reader can see what it depends on by looking
at one method. Setter injection suits dependencies that are genuinely optional
or have a sensible default. Interface injection is rarely seen today.

### The composition root

If no class builds its own collaborators, something must build all of them.
Mark Seemann's answer is the **composition root**: a single place, as close as
possible to the application's entry point, where the whole object graph is put
together. The rest of the application only declares what it needs, and only an
application, never a library, has a composition root.[^compositionroot] In the
example above it is the line `SignupService(outbox)`. In a real application it
is a few dozen lines in `main` or in the start-up code, and it can be written
entirely by hand. For a small program, wiring the objects by hand like this,
without any container, is often all that is needed.

## IoC containers

### What a container does

As an application grows, the composition root grows with it, and much of it
becomes mechanical: to build a `CheckoutService`, first build an
`OrderRepository`, which needs a `Database`, and so on down the graph. An **IoC
container**, or DI container, automates that. It does four things:

1. **Registration.** The program tells the container which implementation to
   use for each service, often an interface: "when someone needs a `Mailer`,
   give them a `ConsoleMailer`".
2. **Resolution and auto-wiring.** Asked for a service, the container looks at
   the constructor of its implementation, works out what *that* needs, resolves
   each of those in turn, and builds the whole graph from the bottom up.
3. **Lifetimes.** It decides whether each request gets a new object or a shared
   one, and how long a shared one lives.
4. **Disposal.** It cleans up the objects it created when their lifetime ends.

### A container in sixty lines

Nothing about this needs magic. The container below reads constructor type
hints to auto-wire, supports the three lifetimes most containers offer, and
reports cycles and missing registrations:

```python
import inspect
from typing import get_type_hints

TRANSIENT, SCOPED, SINGLETON = "transient", "scoped", "singleton"


class Container:
    def __init__(self):
        self.registrations = {}  # service -> (implementation, lifetime)
        self.singletons = {}

    def register(self, service, implementation=None, lifetime=TRANSIENT):
        self.registrations[service] = (implementation or service, lifetime)

    def scope(self):
        return Scope(self)


class Scope:
    def __init__(self, container):
        self.container = container
        self.instances = {}

    def resolve(self, service, _chain=()):
        if service in _chain:
            path = " -> ".join(s.__name__ for s in (*_chain, service))
            raise LookupError(f"cycle: {path}")
        if service not in self.container.registrations:
            raise LookupError(f"nothing registered for {service.__name__}")

        implementation, lifetime = self.container.registrations[service]
        cache = {SINGLETON: self.container.singletons,
                 SCOPED: self.instances}.get(lifetime)
        if cache is not None and service in cache:
            return cache[service]

        # Auto-wiring: read the constructor's type hints and resolve each one.
        hints = get_type_hints(implementation.__init__)
        arguments = {
            name: self.resolve(hints[name], (*_chain, service))
            for name in inspect.signature(implementation).parameters
        }
        instance = implementation(**arguments)
        if cache is not None:
            cache[service] = instance
        return instance
```

An application registers its classes once and then only ever asks for the top
of the graph:

```python
class Clock:
    def now(self):
        return "2026-10-20T12:00"


class Database:
    count = 0

    def __init__(self):
        Database.count += 1
        self.id = Database.count


class Mailer:
    def send(self, to, text):
        print(f"  mail to {to}: {text}")


class ConsoleMailer(Mailer):
    pass


class OrderRepository:
    def __init__(self, db: Database):
        self.db = db


class CheckoutService:
    def __init__(self, orders: OrderRepository, mailer: Mailer, clock: Clock):
        self.orders, self.mailer, self.clock = orders, mailer, clock

    def checkout(self, email):
        self.mailer.send(email, f"order placed at {self.clock.now()}")


container = Container()
container.register(Clock, lifetime=SINGLETON)
container.register(Database, lifetime=SCOPED)  # one per request
container.register(Mailer, ConsoleMailer)  # ask for the abstraction
container.register(OrderRepository)
container.register(CheckoutService)

for request in (1, 2):
    scope = container.scope()
    a = scope.resolve(CheckoutService)
    b = scope.resolve(CheckoutService)
    print(f"request {request}:")
    a.checkout("ada@example.com")
    print(f"  same service? {a is b}  same db? {a.orders.db is b.orders.db}"
          f"  db id {a.orders.db.id}  same clock? {a.clock is b.clock}")

print("singleton across requests:",
      container.scope().resolve(Clock) is container.scope().resolve(Clock))


class Chicken:
    def __init__(self, egg: "Egg"): ...


class Egg:
    def __init__(self, chicken: Chicken): ...


container.register(Chicken)
container.register(Egg)
for service in (Chicken, dict):
    try:
        container.scope().resolve(service)
    except LookupError as error:
        print("LookupError:", error)
```

```txt
request 1:
  mail to ada@example.com: order placed at 2026-10-20T12:00
  same service? False  same db? True  db id 1  same clock? True
request 2:
  mail to ada@example.com: order placed at 2026-10-20T12:00
  same service? False  same db? True  db id 2  same clock? True
singleton across requests: True
LookupError: cycle: Chicken -> Egg -> Chicken
LookupError: nothing registered for dict
```

`CheckoutService` was never constructed by hand. The container read its
constructor, saw an `OrderRepository`, a `Mailer` and a `Clock`, built each of
those, including the `Database` the repository needs, and passed them in. It
used `ConsoleMailer` where `Mailer` was asked for, because that was the
registration, and none of the classes know a container exists. The output also
shows the three lifetimes at work, and the last two lines show the two errors
every container has to report well: a cycle, where two classes each need the
other, and a dependency nobody registered.

### Lifetimes

The lifetimes are the part of a container that most often goes wrong, so they
are worth being precise about. In the terms .NET's documentation uses:[^mslifetimes]

| Lifetime | One instance per | Typical use |
|---|---|---|
| **Transient** | Every request for the service | Lightweight, stateless services |
| **Scoped** | Scope; in a web application, each client request | A database context or unit of work shared by everything handling one request |
| **Singleton** | The container's whole lifetime | Configuration, caches, clocks; must be safe to use from many threads at once |

{{< diagram src="lifetimes.svg" caption="Two requests, two scopes. Transient services are new every time, scoped ones are shared within a request, and the singleton is shared by everything." >}}

The rule that follows from the table is that an object must not hold on to one
that is meant to live for less time than it does. A singleton that keeps a
scoped database context keeps *the first request's* context for every request
after it, long after that request has finished. Seemann named this a **captive
dependency**, and .NET's guidelines list it as an anti-pattern.[^msguidelines]

### A real container

Production containers do the same job as the sixty-line one, with more care:
compiled factories instead of reflection on every call, disposal, open
generics, decorators and validation. Here is the same application on .NET's
built-in container, followed by a deliberate captive dependency:

```csharp
using Microsoft.Extensions.DependencyInjection;

var services = new ServiceCollection();
services.AddSingleton<IClock, SystemClock>();
services.AddScoped<OrderRepository>();
services.AddTransient<IMailer, ConsoleMailer>();
services.AddTransient<CheckoutService>();

using var provider = services.BuildServiceProvider(validateScopes: true);

for (var request = 1; request <= 2; request++)
{
    using var scope = provider.CreateScope();
    var a = scope.ServiceProvider.GetRequiredService<CheckoutService>();
    var b = scope.ServiceProvider.GetRequiredService<CheckoutService>();
    Console.WriteLine($"request {request}: same service {ReferenceEquals(a, b)}, " +
        $"same repository {ReferenceEquals(a.Orders, b.Orders)} (#{a.Orders.Id}), " +
        $"same clock {ReferenceEquals(a.Clock, b.Clock)}");
}

// A singleton that holds a scoped service would keep one request's
// repository alive for every request after it: a captive dependency.
var bad = new ServiceCollection();
bad.AddScoped<OrderRepository>();
bad.AddSingleton<ReportCache>();
try
{
    bad.BuildServiceProvider(new ServiceProviderOptions
    {
        ValidateScopes = true,
        ValidateOnBuild = true,
    });
}
catch (AggregateException error)
{
    Console.WriteLine(error.InnerExceptions[0].Message);
}

interface IClock { DateTime Now { get; } }
class SystemClock : IClock { public DateTime Now => DateTime.UtcNow; }
interface IMailer { void Send(string to, string text); }
class ConsoleMailer : IMailer
{
    public void Send(string to, string text) => Console.WriteLine($"mail to {to}: {text}");
}
class OrderRepository
{
    static int created;
    public int Id { get; } = ++created;
}
class CheckoutService(OrderRepository orders, IMailer mailer, IClock clock)
{
    public OrderRepository Orders { get; } = orders;
    public IMailer Mailer { get; } = mailer;
    public IClock Clock { get; } = clock;
}
class ReportCache(OrderRepository orders)
{
    public OrderRepository Orders { get; } = orders;
}
```

```txt
request 1: same service False, same repository True (#1), same clock True
request 2: same service False, same repository True (#2), same clock True
Error while validating the service descriptor 'ServiceType: ReportCache Lifetime: Singleton ImplementationType: ReportCache': Cannot consume scoped service 'OrderRepository' from singleton 'ReportCache'.
```

The lifetimes behave exactly as in the Python version: a new `CheckoutService`
each time, one repository per scope and one clock overall. The second half is
the more useful lesson. With scope validation on, which .NET's default host
enables in development, the container refuses to build a provider in which a
singleton consumes a scoped service, and says so before a single request is
served.[^msdi] A good container turns the lifetime rule into an error at start-up
rather than a stale-data bug in production.

## Service locator: the inversion that isn't

A **service locator** also hands out dependencies, and is often confused with
dependency injection. The difference is who asks. With a locator, the class
asks for what it needs while it runs, usually by calling something like
`locator.Get<IMailer>()` from inside a method; with injection, the class is
given what it needs and never asks at all. Fowler noted that both separate a
class from the concrete services it uses, and that the locator is simpler, but
that it makes every class depend on the locator itself and keeps its
dependencies out of sight.[^fowler]

Seemann went further and called it an anti-pattern: a class that pulls its
dependencies from a locator does not show them in its constructor, so neither
the compiler nor a reader can tell what it needs, and a missing registration
surfaces only when that line of code finally runs.[^locator] .NET's guidelines
give the same advice, to avoid the service locator pattern and calls to
`GetService` where injection can supply the dependency instead.[^msguidelines]
A container used as a locator, passed around so that classes can fetch from it,
loses most of what injection gains. A container used only in the composition
root does not.

## IoC, dependency injection and dependency inversion

Three terms with similar names are easy to mix up, and they are not the same
thing.

- **Inversion of control** is the broad arrangement: someone else's code
  decides when yours runs. Callbacks, event loops, template methods and
  frameworks are all forms of it.
- **Dependency injection** is one specific form: someone else decides which
  objects yours works with, and hands them in. It is how a class gets its
  dependencies, a *mechanism*.
- **The dependency inversion principle** is a design rule about which way
  dependencies point. In Martin's words it has two parts: high-level modules
  should not depend on low-level modules, both should depend on abstractions;
  and abstractions should not depend on details, details should depend on
  abstractions.[^martin] It is the fifth of the SOLID principles, and
  [its own article](../dependency-inversion-principle/) covers it in full.

The principle and the mechanism meet in practice. In the signup example,
`SignupService`, the high-level policy, depends only on the `Mailer`
abstraction, and the low-level `SmtpMailer` depends on that abstraction too, by
implementing it. That is dependency inversion. Dependency injection is what
gets an implementation into the service at run time without the service naming
it. Each can exist without the other: a class can receive a concrete
`SmtpMailer` by injection, which is injection without inversion, and a module
can depend on an interface it looks up through a locator, which is inversion
without injection.

## What it costs and what it buys

| It buys | It costs |
|---|---|
| **Reuse.** A framework's loop, error handling and plumbing are written once and shared by every program built on it | **Control.** The program no longer decides the order of events, and must learn the framework's rules for when it will be called |
| **Testability.** A class whose collaborators are injected can be tested with stand-ins, as `OutboxMailer` showed | **Indirection.** Reading the code no longer tells you which implementation runs; the answer is in a registration somewhere else |
| **Loose coupling.** Implementations can be swapped, decorated or reconfigured without editing the classes that use them | **Failures moved later.** With a container, a missing or wrong registration is a start-up or run-time error rather than a compile error, unless the container validates the graph |
| **Explicit dependencies.** Constructor injection makes everything a class needs visible in one signature | **Learning curve and magic.** Auto-wiring, lifetimes and scopes are one more system to understand, and a stack trace through a container is long |
| **Managed lifetimes.** One place decides what is shared, what is per request and what is cleaned up | **Lifetime bugs.** Captive dependencies and shared mutable singletons are new ways to fail |

The costs are the reason not to reach for a container by reflex. A command-line
tool with ten classes is clearer with a hand-written composition root in
`main`. A web application with hundreds of services, per-request database
contexts and a framework that already expects a container is clearer with one.

## When to use it

- **Use a framework's inversion of control** whenever the framework fits the
  problem. Writing your own event loop, HTTP router or test runner is rarely a
  good use of time, and handing over control is the price of not having to.
- **Inject dependencies through the constructor** in any class that talks to
  something slow, external or nondeterministic, a database, the network, the
  clock, the file system, so that it can be tested and swapped without editing
  it.
- **Compose by hand first.** Keep the wiring in one composition root near the
  entry point. Introduce a container when that wiring becomes long, repetitive
  or needs lifetimes such as per-request scopes, and keep the container in that
  one place.
- **Do not use a container as a locator.** If classes start receiving the
  container itself, or calling it from inside their methods, the dependencies
  have gone back into hiding.
- **Turn on validation.** If the container can check the graph and its
  lifetimes at start-up, as .NET's can, let it.
- **Do not inject what never varies.** A pure function, a value object or a
  standard-library type with no side effects needs no abstraction and no
  container entry.

## Why it matters

Almost every program of any size today runs inside someone else's main loop: a
web framework, a mobile operating system, a browser, a test runner, a cloud
function's runtime. Knowing that this is inversion of control, and that it is a
trade, explains why frameworks feel the way they do, why their rules about when
code is called matter so much, and why the same idea, applied to where objects
come from, turned into dependency injection and the containers that now ship
with the platforms. Used with care, it keeps each piece of a program ignorant
of the pieces it does not need to know about. Used by reflex, it hides the
program's structure behind registrations nobody can follow. The skill is
telling the two apart.

## References

[^fowlerbliki]: Fowler, M. (2005, June 26). *InversionOfControl*. martinfowler.com. <https://martinfowler.com/bliki/InversionOfControl.html>

[^johnsonfoote]: Johnson, R. E., & Foote, B. (1988). Designing reusable classes. *Journal of Object-Oriented Programming*, 1(2), 22–35. <http://www.laputan.org/drc/drc.html>

[^sweet]: Sweet, R. E. (1985). The Mesa programming environment. *ACM SIGPLAN Notices*, 20(7), 216–229. <https://doi.org/10.1145/17919.806843>

[^gof]: Gamma, E., Helm, R., Johnson, R., & Vlissides, J. (1994). *Design Patterns: Elements of Reusable Object-Oriented Software*. Addison-Wesley.

[^martin]: Martin, R. C. (1996). The dependency inversion principle. *The C++ Report*. <https://cs.utexas.edu/~downing/papers/DIP-1996.pdf>

[^avalon]: Apache Excalibur. (n.d.). *Avalon Framework: Guide: Inversion of Control*. The Apache Software Foundation. <https://excalibur.apache.org/framework/guide-patterns-ioc.html>; and *Introduction*, <https://excalibur.apache.org/developing/introduction.html>

[^springorigins]: Johnson, R. (2006, November 9). Spring Framework: The origins of a project and a name. *Spring Blog*. <https://spring.io/blog/2006/11/09/spring-framework-the-origins-of-a-project-and-a-name/>

[^spring10]: Risberg, T. (2004, March 24). Spring Framework 1.0 final released. *Spring Blog*. <https://spring.io/blog/2004/03/24/spring-framework-1-0-final-released>

[^pico]: Hammant, P. (2004, June 5). PicoContainer 1.0 released (finally). <https://paulhammant.com/blog/000250>

[^fowler]: Fowler, M. (2004, January 23). *Inversion of control containers and the dependency injection pattern*. martinfowler.com. <https://martinfowler.com/articles/injection.html>

[^guice]: Almaer, D. (2007, March 12). Guice, Google's internal Java dependency injection framework, released as open source. *Google Developers Blog*. <https://developers.googleblog.com/2007/03/guice-google-internal-java-dependency.html>

[^jsr330]: Johnson, R., & Lee, B. (2009). *JSR 330: Dependency Injection for Java*. Java Community Process. <https://jcp.org/en/jsr/detail?id=330>

[^inject]: Oracle. (n.d.). *Annotation Type Inject*. Java EE 6 API specification. <https://docs.oracle.com/javaee/6/api/javax/inject/Inject.html>

[^msdi]: Microsoft. (2026, January 26). *Dependency injection in .NET*. Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/overview>

[^angulardi]: Angular. (n.d.). *Dependency injection in Angular*. <https://angular.dev/guide/di>

[^angularhier]: Angular. (n.d.). *Hierarchical injectors*. <https://angular.dev/guide/di/hierarchical-dependency-injection>

[^springioc]: Spring. (n.d.). Introduction to the Spring IoC container and beans. In *Spring Framework Reference Documentation*. <https://docs.spring.io/spring-framework/reference/core/beans/introduction.html>

[^nodeloop]: Node.js. (n.d.). *The Node.js event loop*. <https://nodejs.org/en/learn/asynchronous-work/event-loop-timers-and-nexttick>

[^unittest]: Python Software Foundation. (n.d.). *unittest: Unit testing framework*. Python documentation. <https://docs.python.org/3/library/unittest.html>

[^compositionroot]: Seemann, M. (2011, July 28). *Composition Root*. ploeh blog. <https://blog.ploeh.dk/2011/07/28/CompositionRoot/>

[^mslifetimes]: Microsoft. (2025, October 21). *Service lifetimes*. Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/service-lifetimes>

[^msguidelines]: Microsoft. (2026, January 14). *Dependency injection guidelines*. Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/guidelines>

[^locator]: Seemann, M. (2010, February 3). *Service Locator is an anti-pattern*. ploeh blog. <https://blog.ploeh.dk/2010/02/03/ServiceLocatorisanAnti-Pattern/>
