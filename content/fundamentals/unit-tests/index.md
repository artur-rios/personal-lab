---
title: "What Is a Unit Test? Where Unit Testing Came From and How to Write Good Ones"
description: "A unit test is a small, fast, automated check that one piece of code does what it should. Here is what that means and why the definition is still argued over; how the practice grew from 1970s module testing through SUnit, JUnit and test-driven development; how test frameworks and test doubles work, with runnable Python examples; how to measure a test suite; and what separates a suite you can trust from one you have to carry."
date: 2026-10-20T22:30:00Z
categories: ["Fundamentals"]
tags: ["Testing", "Unit Tests", "TDD", "Test Doubles", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

You change one line in a pricing function and want to know whether anything
broke. You could start the whole application, log in, fill a cart and look at
the total, for every kind of cart you can think of. Or you could run a few
hundred small programs that each call the pricing function with one input and
check the answer, and know in under a second. Those small programs are **unit
tests**, and the second way of working is one of the biggest changes in how
software has been written in the last thirty years: from testing as a phase at
the end of a project, done by someone else, to testing as something every
programmer does every few minutes.

This article explains what a unit test is and why the definition is still
argued over, where the practice came from, how test frameworks and test doubles
work inside, how to tell whether a test suite is any good, and what goes wrong
when it is not. The examples are in Python with
[pytest](https://docs.pytest.org/), but every idea carries over to JUnit,
xUnit.net, Jest, Go's `testing` package or any other framework.

## What a unit test is

**A unit test is a small, automated, self-checking program that runs one
piece of code, a function, a class or a small group of objects, with known
inputs and checks that it produces the expected result. It runs in
milliseconds, needs nothing outside the process, and reports only "pass" or
"fail", so it can be run thousands of times a day without anyone looking at
it.**

Here is one. It checks a function that applies a percentage discount to a
price held in cents:

```python
# pricing.py
def apply_discount(price_cents: int, percent: int) -> int:
    """Return the price after a percentage discount, rounded down to whole cents."""
    if not 0 <= percent <= 100:
        raise ValueError("percent must be between 0 and 100")
    return price_cents * (100 - percent) // 100
```

```python
# test_pricing.py
from pricing import apply_discount


def test_ten_percent_off_2000_cents_is_1800():
    # Arrange
    price = 2000
    # Act
    result = apply_discount(price, 10)
    # Assert
    assert result == 1800
```

```txt
$ pytest -q test_pricing.py
.                                                                        [100%]
1 passed in 0.45s
```

Most of what makes this a *unit* test, rather than just a test, is in what it
does not do. It does not start a server, open a database, read a file or wait
for anything. It does not need a person to read its output and decide whether
it looks right. And when it fails, there is only one function it can be
complaining about.

Almost every definition agrees on a handful of properties, even when it
disagrees about the details:[^fowlerunit][^khorikov]

- **Small scope.** It exercises one unit of behaviour, not a whole feature or
  system.
- **Fast.** Milliseconds each, so a suite of thousands runs in seconds and can
  be run after every change.
- **Automated and self-checking.** The test decides by itself whether it
  passed; no human compares outputs.
- **Isolated.** Its result does not depend on other tests, on the order they
  run in, or on the network, the clock or the file system.
- **Repeatable.** Run it a thousand times on any machine and it gives the same
  answer every time.

### What counts as a unit

The word "unit" is where the agreement ends. Some programmers mean a single
function or class, and replace every object it talks to with a stand-in. Others
mean a unit of *behaviour*, and let the class under test use its real
collaborators as long as they are fast and in-process. Martin Fowler calls the
first kind **solitary** tests and the second **sociable** tests, and notes that
both camps write tests they call unit tests.[^fowlerunit]

{{< diagram src="solitary-sociable.svg" caption="The same class tested two ways. A solitary test replaces every collaborator with a double; a sociable test uses the real in-process collaborators and replaces only what is slow or external." >}}

A more practical boundary is what a unit test must *not* touch. Michael Feathers
put it as a list in 2005: a test is not a unit test if it talks to a database,
communicates across a network, touches the file system, cannot run at the same
time as other unit tests, or needs special changes to the environment (such as
editing configuration files) to run.[^feathersrules] Those tests may be
valuable, but they are slower and fail for reasons that have nothing to do with
the code being tested, so they belong in a separate, slower suite.

Google sidesteps the vocabulary altogether and classifies tests by **size**,
meaning the resources a test may use, rather than by the amount of code it
covers.[^swe11]

| Size | May use | Typical kind |
|---|---|---|
| **Small** | A single process, usually a single thread; no network, disk, sleeping or blocking calls | Unit tests |
| **Medium** | A single machine: several processes, `localhost` network, a local database | Integration tests |
| **Large** | Anything, including several machines and real services | End-to-end and system tests |

### Unit tests among other tests

| Kind | What it checks | Speed | When it fails, you know |
|---|---|---|---|
| **Unit** | One function, class or small cluster, in-process | Milliseconds | Which unit and which behaviour |
| **Integration** | That several parts work together: code and a real database, two services, a framework's wiring | Seconds | That some part of the connection is wrong |
| **End-to-end (system)** | A whole feature through the real interface, as a user would use it | Seconds to minutes | That a user-visible behaviour is broken, somewhere |
| **Acceptance** | That the system does what the customer asked for, often written with them | Any of the above | That a requirement is not met |
| **Regression** | That something which used to work still does; any of the above, kept after a bug fix | Any of the above | That an old bug is back |

### Related words

| Term | Meaning |
|---|---|
| **System under test (SUT)** | Whatever the test is exercising: a function, an object, a module |
| **Test case** | One test: a single scenario with its own setup and checks |
| **Assertion** | A check inside a test that raises an error when the actual result differs from the expected one |
| **Fixture** | The setup a test needs, such as objects, data or a temporary directory, and the clean-up afterwards |
| **Test suite** | A collection of test cases run together |
| **Test runner** | The program that finds tests, runs them and reports the results |
| **Test double** | Any object that stands in for a real dependency during a test: a stub, spy, mock, fake or dummy |
| **Red, green** | A failing test, a passing test, from the colours of the runner's progress bar |
| **Flaky test** | A test that sometimes passes and sometimes fails without any change to the code |
| **Code coverage** | The share of the code, by lines or branches, that the tests execute |

## A history of unit testing

### Before frameworks: testing as a phase

Early programmers tested their programs, of course, but "testing" and
"debugging" were not clearly separated: you ran the program until it stopped
misbehaving. By the late 1960s it was clear that this did not scale. In 1969,
at the NATO software engineering conference in Rome and in his *Notes on
Structured Programming*, Edsger Dijkstra put the limit of testing in one
sentence: program testing can be used to show the presence of bugs, but never
to show their absence.[^nato69][^dijkstra] His conclusion was that programs
should be designed to be provably correct; the industry's conclusion, for the
most part, was to test more systematically.

Glenford Myers's *The Art of Software Testing* (1979) gave testing its own
discipline and its best-known definition: testing is the process of executing
a program *with the intent of finding errors*.[^myers] A test that finds
nothing, in that view, is a test that did not try hard enough. The book's
chapter on **module (unit) testing**, testing each class, function or
procedure on its own before combining them, describes the scaffolding this
needs: a **driver** module that feeds the module under test its inputs and
shows the results, and **stub** modules that stand in for the modules it
calls.[^myers3] Both words survive today.

The IEEE standardised the activity as IEEE Std 1008, *Standard for Software
Unit Testing*, approved in 1986 and published as 1008-1987: "an integrated
approach to systematic and documented unit testing", made of a hierarchy of
phases, activities and tasks.[^ieee1008] It described a planned, documented
process carried out alongside a project. The change that followed came from
programmers, not standards bodies.

### Smalltalk and SUnit

In 1994 Kent Beck published "Simple Smalltalk Testing: With Patterns", which
described a tiny testing framework and the patterns for using it.[^beck94]
Its ideas are the ones every framework since has copied: each test is a method on a
**test case** class; shared setup goes into a **fixture** built fresh before
each test and torn down after it; tests are grouped into **suites**; and the
framework, not a person, checks the results and reports them, distinguishing
*failures*, which a test anticipated and checked for, from *errors*, which it
did not. The framework became known as **SUnit**.[^gnusunit]

### JUnit and the xUnit family

In 1997 Beck and Erich Gamma wrote a Java version, **JUnit**, famously on a
flight from Zurich to the OOPSLA conference in Atlanta.[^fowlerxunit] Their 1998
article "Test Infected: Programmers Love Writing Tests" introduced it to Java
programmers and argued for the habit as much as the tool.[^testinfected] JUnit
spread fast, and versions for other languages followed: CppUnit, NUnit for .NET,
PyUnit, which became Python's standard `unittest` module,[^pyunit][^unittest]
and many more. The whole family came to be called
**xUnit**.[^fowlerxunit] Later frameworks such as pytest, Jest and Go's
`testing` package dropped the class hierarchy, but kept the structure: discover
tests, set up a fixture, run, assert, report.

### Extreme Programming and test-first

Frameworks made tests cheap to write and run; Extreme Programming made them a
discipline. In *Extreme Programming Explained* (1999), Beck made automated
tests written by the programmers themselves one of the core practices, with
the rule that the tests are written *before* the code.[^xp] His
*Test-Driven Development: By Example* (2002) turned this into a method:
write a failing test, make it pass, clean up, repeat.[^tdd] Test-first
programming changed what a unit test was for. It was no longer only a check on
finished code, but a way of designing code: a test written first is the first
user of an interface, and awkward tests reveal awkward designs.

Feathers took the argument to its end in *Working Effectively with Legacy Code*
(2004), defining **legacy code** simply as code without tests, because without
them nobody can change it safely.[^featherslegacy]

### Mock objects and the two schools

Testing an object in isolation means replacing the objects it talks to. In
2000, Tim Mackinnon, Steve Freeman and Philip Craig presented **mock objects**:
stand-ins that check how the code under test uses them, so a test can verify
the *interactions* of an object, not only its final state.[^mackinnon] Mocks
divided practitioners into two styles that are still with us. Fowler's essay
"Mocks Aren't Stubs" (2004, revised 2007) named them: **classical** testers
use real objects where they can and check the resulting state, while
**mockist** testers use a mock for any collaborator with interesting behaviour
and check the calls made to it.[^mocksarentstubs] Vladimir Khorikov calls the
same two styles the **classical** and **London** schools of unit
testing.[^khorikov]

### Patterns and names

As test suites grew into the thousands, their own design started to matter.
Bill Wake observed and named the **Arrange, Act, Assert** pattern for laying
out a test in 2001.[^aaa] Dan North's **behaviour-driven development** (2006)
recast tests as specifications of behaviour, written as *Given* a context,
*When* an event
happens, *Then* an outcome follows.[^north] Gerard Meszaros's *xUnit Test
Patterns* (2007) catalogued the patterns and "test smells" of the whole family,
and gave test doubles the names most writers use today: dummy, stub, spy, mock
and fake.[^meszaros]

### The pyramid

In *Succeeding with Agile* (2009), Mike Cohn drew the **test automation
pyramid**: many unit tests at the base, fewer service tests in the middle, and
few user-interface tests at the top.[^cohn][^fowlerpyramid] The layer names
have aged, and the shape has been argued over and redrawn many times, but its
advice has held: "push your tests as far down the test pyramid as you
can".[^vocke]

### Beyond hand-picked examples

Two older ideas returned as tools matured. **Mutation testing**, proposed by
Richard DeMillo, Richard Lipton and Frederick Sayward in 1978, judges a test
suite by planting small bugs in the code and counting how many the tests
catch.[^demillo] It was long too expensive for everyday use; by 2018 Google
was running it at scale, on the code changes its engineers send for
review.[^googlemutation] **Property-based testing**, introduced by Koen
Claessen and John Hughes's QuickCheck for Haskell in 2000, has the computer
generate the inputs: the programmer states a property
that must hold for all inputs, and the tool searches for one that breaks
it.[^quickcheck] Libraries such as Hypothesis brought it to mainstream
languages.[^hypothesis]

Research also started to test the folklore. A 2014 study of large Java
projects found that, once the number of tests is accounted for, a suite's code
coverage is not strongly correlated with how many faults it
detects,[^inozemtseva] and another catalogued the causes of **flaky tests** in open-source projects,
finding asynchronous waiting, concurrency and dependence on test order the
three most common.[^luo]

## A timeline at a glance

| Year | Milestone |
|---|---|
| 1969 | Dijkstra: testing shows the presence of bugs, never their absence |
| 1978 | DeMillo, Lipton and Sayward propose mutation testing |
| 1979 | Myers's *The Art of Software Testing* |
| 1986–87 | IEEE Std 1008, *Standard for Software Unit Testing* |
| 1994 | Beck's "Simple Smalltalk Testing": SUnit |
| 1997–98 | JUnit; "Test Infected" |
| 1999 | *Extreme Programming Explained*: tests written first, by programmers |
| 2000 | Mock objects; QuickCheck |
| 2001 | Arrange, Act, Assert |
| 2002 | *Test-Driven Development: By Example* |
| 2004 | *Working Effectively with Legacy Code*; "Mocks Aren't Stubs" |
| 2005 | Feathers's unit testing rules |
| 2006 | Behaviour-driven development: Given, When, Then |
| 2007 | *xUnit Test Patterns* |
| 2009 | The test automation pyramid |
| 2014 | Studies of coverage and of flaky tests |
| 2018 | Mutation testing at scale at Google |

## Models

### The anatomy of a test

Every unit test, whatever the framework, goes through the same four phases,
which Meszaros calls the **four-phase test**: set up, exercise, verify and tear
down.[^meszaros] Arrange, Act, Assert names the first three;[^aaa] Given, When,
Then names them again in the language of behaviour.[^north]

{{< diagram src="four-phase.svg" caption="The four phases of a test, and the two common names for them. Teardown is usually left to the framework or the garbage collector." >}}

A fuller version of the discount tests shows the patterns frameworks offer for
each phase. `parametrize` runs one test body over a table of cases, and
`pytest.raises` asserts that the code fails in the expected way:

```python
# test_pricing.py
import pytest

from pricing import apply_discount


def test_ten_percent_off_2000_cents_is_1800():
    # Arrange
    price = 2000
    # Act
    result = apply_discount(price, 10)
    # Assert
    assert result == 1800


@pytest.mark.parametrize(
    "price, percent, expected",
    [
        (2000, 0, 2000),    # no discount
        (2000, 100, 0),     # everything off
        (999, 50, 499),     # rounds down, never up
    ],
)
def test_discount_edge_cases(price, percent, expected):
    assert apply_discount(price, percent) == expected


def test_percent_above_100_is_rejected():
    with pytest.raises(ValueError):
        apply_discount(2000, 101)
```

```txt
$ pytest -q test_pricing.py
.....                                                                    [100%]
5 passed in 0.45s
```

Each parametrized case counts as its own test. If someone believed half of
9.99 should round up to 5.00 and changed the expectation to 500, the report
would point at exactly that case, with the values involved:

```txt
FAILED test_pricing.py::test_discount_edge_cases[999-50-500] - assert 499 == 500
1 failed, 4 passed in 0.50s
```

That precision is what a unit test is for. A failing end-to-end test says
"checkout is broken"; a failing unit test says "this function, given these
arguments, returned 499 instead of 500".

### The test pyramid

{{< diagram src="pyramid.svg" caption="The test pyramid. The higher a test sits, the more of the real system it covers, and the slower, costlier and less precise it is." >}}

The pyramid is an argument about cost. Each layer catches problems the others
cannot: unit tests cannot see that two services disagree about a date format,
and an end-to-end test cannot cheaply try fifty edge cases of a discount
calculation. So each check goes to the lowest layer able to make it, and the
upper layers are kept for what only they can show: that the parts are wired
together correctly.[^vocke] The opposite shape, a "test ice-cream cone" of
mostly end-to-end tests and few unit tests, is the usual sign of a suite that
is slow to run and hard to maintain.[^vocke]

### Test doubles

Few units work alone. The reminder service below asks a repository for unpaid
invoices, asks a clock for today's date and tells a mailer to send emails. In a
unit test, none of those can be the real thing: the real clock changes every
day, and the real mailer sends real email. Meszaros's term for the stand-ins is
**test double**, after the stunt doubles of film.[^meszaros] What distinguishes
the kinds of double is the direction of the information they handle. The code
under test receives **indirect inputs** from its dependencies (today's date)
and sends **indirect outputs** to them (an email), neither of which passes
through the test's own arguments or return values.

{{< diagram src="doubles.svg" caption="Direct and indirect inputs and outputs. Stubs control what the code under test receives from its dependencies; spies and mocks observe what it sends them." >}}

| Double | What it does | Used to |
|---|---|---|
| **Dummy** | Is passed to satisfy a parameter, but never used | Fill an argument list |
| **Stub** | Returns canned answers to the calls it receives | Control indirect inputs |
| **Spy** | Records the calls it receives, for the test to inspect afterwards | Verify indirect outputs |
| **Mock** | Is programmed with the calls it expects, and fails the test if they do not happen | Verify indirect outputs |
| **Fake** | Has a working but simplified implementation, such as an in-memory database | Replace a slow or external dependency with something that behaves like it |

Here is the code under test. It takes its three dependencies as constructor
arguments, which is what makes it testable at all:

```python
# reminders.py
class ReminderService:
    def __init__(self, invoices, mailer, today):
        self._invoices = invoices    # anything with .unpaid()
        self._mailer = mailer        # anything with .send(to, subject)
        self._today = today          # a function that returns today's date

    def send_due_reminders(self) -> int:
        sent = 0
        for invoice in self._invoices.unpaid():
            if invoice.due <= self._today():
                self._mailer.send(invoice.email, f"Invoice {invoice.number} is due")
                sent += 1
        return sent
```

And the tests, with every kind of double:

```python
# test_reminders.py
from dataclasses import dataclass
from datetime import date
from unittest.mock import Mock

from reminders import ReminderService


@dataclass
class Invoice:
    number: str
    email: str
    due: date


class InMemoryInvoices:                  # fake: a real, simplified implementation
    def __init__(self, *invoices):
        self._invoices = list(invoices)

    def unpaid(self):
        return list(self._invoices)


class RecordingMailer:                   # spy: remembers what it was asked to do
    def __init__(self):
        self.sent = []

    def send(self, to, subject):
        self.sent.append((to, subject))


def fixed_today():                       # stub: always gives the same answer
    return date(2026, 10, 20)


def test_reminds_overdue_and_due_today_but_not_future_invoices():
    invoices = InMemoryInvoices(
        Invoice("A-1", "ana@example.com", date(2026, 10, 1)),
        Invoice("A-2", "bo@example.com", date(2026, 10, 20)),
        Invoice("A-3", "cy@example.com", date(2026, 11, 1)),
    )
    mailer = RecordingMailer()
    service = ReminderService(invoices, mailer, today=fixed_today)

    sent = service.send_due_reminders()

    assert sent == 2
    assert mailer.sent == [
        ("ana@example.com", "Invoice A-1 is due"),
        ("bo@example.com", "Invoice A-2 is due"),
    ]


def test_sends_nothing_when_nothing_is_unpaid():
    # The mailer is a dummy: it must be passed, but is never used.
    service = ReminderService(InMemoryInvoices(), mailer=None, today=fixed_today)

    assert service.send_due_reminders() == 0


def test_with_a_library_mock():
    mailer = Mock()
    invoices = InMemoryInvoices(Invoice("A-1", "ana@example.com", date(2026, 10, 1)))
    service = ReminderService(invoices, mailer, today=fixed_today)

    service.send_due_reminders()

    mailer.send.assert_called_once_with("ana@example.com", "Invoice A-1 is due")
```

```txt
$ pytest -v test_reminders.py
test_reminders.py::test_reminds_overdue_and_due_today_but_not_future_invoices PASSED [ 33%]
test_reminders.py::test_sends_nothing_when_nothing_is_unpaid PASSED      [ 66%]
test_reminders.py::test_with_a_library_mock PASSED                       [100%]
```

The stub turns "today" from a moving target into a constant, which is the only
way a test about due dates can give the same answer tomorrow. The last test
uses `unittest.mock.Mock` from Python's standard library, which builds a double
on the fly, accepts any call and lets the test assert afterwards how it was
used.[^unittestmock] In Meszaros's strict terms that makes it closer to a spy
than to a mock; libraries use the names more loosely than the taxonomy does,
and "mock" has become the everyday word for any double.

### Classical and London schools

The choice of doubles reflects the two schools that grew out of mock
objects:[^mocksarentstubs][^khorikov]

| | Classical | London (mockist) |
|---|---|---|
| **A unit is** | A unit of behaviour, possibly several classes | A single class |
| **Doubles for** | Only shared, slow or external dependencies: databases, networks, clocks | Every collaborator with behaviour |
| **Verifies** | State: the return value, or the state of objects afterwards | Behaviour: which calls were made, with what arguments |
| **Strengths** | Tests survive refactoring; fewer doubles to maintain | Failures point at exactly one class; drives the design of interfaces from the outside in |
| **Risks** | One bug can fail many tests; setup can grow large | Tests mirror the implementation, so refactoring breaks them even when behaviour is unchanged |

Most teams mix the two. Khorikov, who favours the classical school, argues for
mocking only what the code under test sends to the *outside world*, such as
emails, messages and calls to other systems, where the interaction *is* the
behaviour, and using real objects or fakes for everything else.[^khorikov]

### Test-driven development

Test-driven development (TDD) uses unit tests as the engine of a short design
loop.[^tdd]

{{< diagram src="tdd-cycle.svg" caption="Red, green, refactor. Each turn adds one small behaviour; the refactoring step is safe because the tests already pin the behaviour down." >}}

1. **Red.** Write a test for the next small piece of behaviour, and run it to
   see it fail. A test that has never failed has never proved it can.
2. **Green.** Write the simplest code that passes, even if it is crude.
3. **Refactor.** Remove duplication and improve names and structure, in the
   code and in the tests, running the tests after each change.

TDD is a way of working, not a property of the tests: a suite written first
and one written after the code look the same. What TDD changes is that every
piece of code has a test that was seen to fail, that the code is testable by
construction, and that design decisions are made from the point of view of the
code's caller.

## How it works

### What a test framework does

A test framework is less magic than it looks. Stripped to its core, it does
five things: **discover** the tests, **set up** each one's fixture, **run** it,
**catch** what it raises, and **report**. Here is a complete, working test
runner in about thirty lines:

```python
# tiny_runner.py
import importlib
import sys
import time
import traceback


def run(module_name):
    module = importlib.import_module(module_name)
    # Discovery: every function whose name starts with "test_" is a test.
    tests = [(name, obj) for name, obj in vars(module).items()
             if name.startswith("test_") and callable(obj)]

    passed, failed, errors = 0, 0, 0
    start = time.perf_counter()
    for name, test in tests:
        try:
            test()                       # a test passes if it returns normally
        except AssertionError:
            failed += 1                  # a failed check
            print(f"FAIL  {name}")
            traceback.print_exc(limit=-1, file=sys.stdout)
        except Exception:
            errors += 1                  # the test itself broke
            print(f"ERROR {name}")
            traceback.print_exc(limit=-1, file=sys.stdout)
        else:
            passed += 1
            print(f"ok    {name}")
    elapsed = time.perf_counter() - start
    print(f"\n{passed} passed, {failed} failed, {errors} errors in {elapsed:.3f}s")
    return failed == 0 and errors == 0


if __name__ == "__main__":
    sys.exit(0 if run(sys.argv[1]) else 1)
```

Given a module with one good test, one wrong expectation and one test that
crashes:

```python
# test_demo.py
from pricing import apply_discount


def test_half_price():
    assert apply_discount(1000, 50) == 500


def test_wrong_expectation():
    assert apply_discount(1000, 25) == 700


def test_broken_test():
    apply_discount("1000", 50)
```

```txt
$ python tiny_runner.py test_demo
ok    test_half_price
FAIL  test_wrong_expectation
Traceback (most recent call last):
  File ".../test_demo.py", line 9, in test_wrong_expectation
    assert apply_discount(1000, 25) == 700
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError
ERROR test_broken_test
Traceback (most recent call last):
  File ".../pricing.py", line 5, in apply_discount
    return price_cents * (100 - percent) // 100
           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^~~~~
TypeError: unsupported operand type(s) for //: 'str' and 'int'

1 passed, 1 failed, 1 errors in 0.001s
```

The runner exits with status 1, which is how a build server knows to stop. The
pieces map directly onto what real frameworks do:

- **Discovery** is by convention: pytest collects functions and methods named
  `test_*` in files named `test_*.py`; JUnit and xUnit.net look for methods
  marked with an attribute such as `@Test` or `[Fact]`.
- **Assertions are exceptions.** A failed check is simply an exception the test
  did not catch, which is why a test needs no special syntax to fail. The
  distinction between a *failure* (an assertion was false) and an *error* (the
  test crashed) goes back to SUnit.[^beck94]
- **Each test is independent.** One failing test does not stop the others,
  and nothing carries over from one test to the next unless it is deliberately
  shared.

Real frameworks add a great deal on top: fixtures with scopes and clean-up,
parametrization, parallel execution, filtering, timing, plugins, and much
better failure messages. pytest, for example, rewrites the `assert` statements
in test modules before they run, so that a failing `assert result == 1800`
reports both sides of the comparison instead of a bare `AssertionError`, as
the parametrized failure above showed.[^pytestassert]

### Fixtures and isolation

A test's **fixture** is everything it needs in place before it runs. The xUnit
tradition builds a **fresh fixture** for every test, in a `setUp` method run
before each test and a `tearDown` method after it, so that no test can see
another's leftovers.[^beck94][^unittest] pytest expresses the same idea with
fixture functions that a test requests by naming them as parameters. In the
reminder tests, the mailer could be one:

```python
import pytest


@pytest.fixture
def mailer():
    return RecordingMailer()          # a new, empty spy for every test that asks


def test_sends_nothing_when_nothing_is_due(mailer):
    invoices = InMemoryInvoices(Invoice("A-3", "cy@example.com", date(2026, 11, 1)))
    service = ReminderService(invoices, mailer, today=fixed_today)

    service.send_due_reminders()

    assert mailer.sent == []
```

Shared, mutable state between tests is the most common way to break isolation:
a module-level list one test appends to, a singleton, a class attribute, a row
left in a database, an environment variable. The symptom is a suite that passes
in one order and fails in another, or passes alone and fails in parallel.

### Seams: making code testable

The reminder service was easy to test because it *received* its clock, its
repository and its mailer instead of creating them. Code that calls
`datetime.now()`, opens a database connection or instantiates an email client
in the middle of its logic gives the test no place to substitute a double.
Feathers calls such a place a **seam**: a point where behaviour can be changed
without editing the code at that point.[^featherslegacy] Passing dependencies
in, as in
[inversion of control]({{< ref "/concepts/inversion-of-control" >}}) and the
[dependency inversion principle]({{< ref "/concepts/dependency-inversion-principle" >}}),
is the most common way to create one. Much of what is called "making code
testable" is the work of putting seams where the code meets time, randomness,
the file system and the network.

## Writing good unit tests

### The FIRST properties

A common checklist for good unit tests is the acronym **FIRST**:[^first][^cleancode]

| Letter | Property | Meaning |
|---|---|---|
| **F** | Fast | Milliseconds, so the whole suite is run after every change, not saved for later |
| **I** | Isolated (independent) | No test depends on another or on the order they run in |
| **R** | Repeatable | Same result every run, on every machine, at any time of day |
| **S** | Self-validating | The test decides pass or fail itself; nobody reads logs |
| **T** | Timely | Written with the code, not months later; ideally just before it |

### Test behaviour, not implementation

The most important rule, and the one most often broken, is to test *what* the
code does, through the interface its real callers use, and not *how* it does
it.[^swe12] A test that reaches into private fields, asserts on the order
of internal calls, or mocks a class's own helper methods will break when the
code is refactored, even though nothing a user could notice has changed. Such
tests make refactoring more expensive instead of cheaper, which is the
opposite of their job. A useful test fails when, and only when, the behaviour
it describes is broken.

Google's guidance puts the same idea as "test behaviours, not methods": one
method may have several behaviours worth a test each, and one behaviour may
span several methods.[^swe12]

### One behaviour per test, named for it

A test's name is the first line of its failure report. Name it after the
behaviour and the expected outcome, not after the method it happens to call:
`test_order_of_exactly_50_ships_free` says what broke;
`test_shipping_fee_3` does not. Many teams use a fixed pattern, such as
`methodName_condition_expectedResult` or the behaviour-driven
`GivenContext_WhenAction_ThenOutcome`. The pattern matters less than applying
one consistently.

Keeping to one behaviour per test means a failure has one meaning. It does not
mean one `assert` per test: several assertions about the same outcome, such as
the count and the list of emails in the reminder test, belong together.

### Clear over clever

Production code is read by people who know it well; a test is most often read
by someone who has just broken it and has never seen it before. That changes
the trade-offs:

- **Prefer DAMP to DRY.** Google's phrase is "descriptive and meaningful
  phrases": some repetition is acceptable if each test can be understood on its
  own, without jumping to shared helpers and base classes.[^swe12]
- **Keep logic out of tests.** No loops, conditionals or calculations that
  recompute the expected value. If the test computes `price * (100 - percent)
  // 100` to get its expectation, it repeats the bug instead of catching it.
  Write `1800`.
- **Show the relevant data.** A test whose inputs live in a distant fixture or
  data file is what Meszaros calls a *mystery guest*: the reader cannot see
  why the expected result is right.[^meszaros]

### Keep tests deterministic

A unit test must not depend on anything that changes between runs. The usual
suspects, and their fixes:

| Source of non-determinism | Fix |
|---|---|
| The current date and time | Inject a clock or a "today" function; use a fixed date in tests |
| Random numbers | Inject the random source, or seed it |
| Concurrency and timing (`sleep`, thread scheduling) | Test the logic synchronously; avoid sleeps; use explicit synchronisation in the few tests that need threads |
| Order of tests, shared state | Fresh fixtures; no module-level mutable state |
| The network, the file system, environment variables | Doubles or temporary, per-test resources; move the real thing to integration tests |
| Unordered collections (sets, dictionary iteration in some languages) | Compare as sets, or sort before comparing |

## Measuring a test suite

### Code coverage

**Code coverage** measures which parts of the code the tests executed. *Line*
(or statement) coverage counts lines; *branch* coverage also checks that each
decision went both ways.[^coveragebranch] Coverage is good at one thing:
showing code that *no* test runs, which is certainly untested. It is poor at
the opposite: code that runs during a test is not necessarily checked by it.

Take a shipping rule and two tests:

```python
# shipping.py
def shipping_fee(order_cents: int) -> int:
    """Orders of 50.00 or more ship free; smaller ones pay 5.00."""
    if order_cents >= 5000:
        return 0
    return 500
```

```python
# test_shipping.py
from shipping import shipping_fee


def test_large_order_ships_free():
    assert shipping_fee(6000) == 0


def test_small_order_pays_shipping():
    assert shipping_fee(1000) == 500
```

```txt
$ coverage run --branch -m pytest -q test_shipping.py
2 passed in 0.48s
$ coverage report -m
Name          Stmts   Miss Branch BrPart  Cover   Missing
---------------------------------------------------------
shipping.py       4      0      2      0   100%
---------------------------------------------------------
TOTAL             4      0      2      0   100%
```

Full line and branch coverage. Yet the tests never try an order of exactly
50.00, the one value where `>=` and `>` disagree, and that is where a bug is
most likely to be. Research agrees: once the size of a suite is taken into
account, its coverage says little about how many faults it
detects.[^inozemtseva] Google's guidance calls coverage "a lossy and indirect
metric", says that much of its value lies in highlighting what is *not*
covered, and warns that pushing the number towards 100% "leads to a false sense
of security".[^googlecoverage] Coverage works best as a map of what is
untested, and worst as a target: a team told to reach a percentage will write
tests that execute code without checking it.

### Mutation testing

**Mutation testing** asks the question coverage cannot: *would the tests
notice if the code were wrong?* A mutation tool makes many small changes to the
code, one at a time, such as replacing `>=` with `>`, `+` with `-` or `True`
with `False`, and runs the tests against each **mutant**.[^demillo] A mutant
that makes some test fail is *killed*; one that passes every test *survives*,
and marks a behaviour nothing checks.

Done by hand on the shipping rule:

```txt
# Mutant: change  >= 5000  to  > 5000
$ pytest -q test_shipping.py
2 passed in 0.43s                      ← the mutant survives
```

The surviving mutant points straight at the missing boundary test:

```python
def test_order_of_exactly_50_ships_free():
    assert shipping_fee(5000) == 0
```

```txt
# Against the mutant:
FAILED test_shipping.py::test_order_of_exactly_50_ships_free - assert 500 == 0
1 failed, 2 passed in 0.49s            ← now killed
# Against the real code:
3 passed in 0.45s
```

Tools such as PIT for Java, Stryker for JavaScript and .NET, and mutmut for
Python automate this. Mutation testing is expensive, since every mutant means
another test run, so large organisations run it selectively: Google's system
works on the diff under code review, skips lines no test covers and lines it
judges uninteresting, and shows surviving mutants to the author and the
reviewers of the change.[^googlemutation]

### Property-based testing

Example-based tests check the cases their author thought of. **Property-based
tests** state something that must be true for *every* input and let a library
search for a counterexample.[^quickcheck][^hypothesis] Here is a function that
splits a bill among friends, with one example test that passes:

```python
# bill.py
def split_bill(total_cents: int, people: int) -> list[int]:
    """Split a bill into shares that add up to the total."""
    share = total_cents // people
    return [share] * people
```

```python
# test_bill.py
from hypothesis import given, strategies as st

from bill import split_bill


def test_split_100_between_4():
    assert split_bill(100, 4) == [25, 25, 25, 25]


@given(total=st.integers(min_value=0, max_value=1_000_000),
       people=st.integers(min_value=1, max_value=50))
def test_shares_always_add_up_to_the_total(total, people):
    shares = split_bill(total, people)
    assert len(shares) == people
    assert sum(shares) == total
    assert max(shares) - min(shares) <= 1      # nobody pays more than a cent extra
```

```txt
$ pytest -q test_bill.py
E       assert 0 == 1
E        +  where 0 = sum([0, 0])
E       Failing test case: test_shares_always_add_up_to_the_total(
E           total=1,
E           people=2,
E       )
FAILED test_bill.py::test_shares_always_add_up_to_the_total - assert 0 == 1
1 failed, 1 passed in 0.61s
```

Hypothesis tried many random totals and group sizes, found that the shares do
not add up whenever the total does not divide evenly, and reported not the
first failure it hit but the simplest one it could reduce it to: one cent
between two people. The fix hands out the remainder:

```python
def split_bill(total_cents: int, people: int) -> list[int]:
    """Split a bill into shares that add up to the total."""
    share, remainder = divmod(total_cents, people)
    # The first `remainder` people pay one extra cent each.
    return [share + 1] * remainder + [share] * (people - remainder)
```

```txt
$ pytest -q test_bill.py
2 passed in 0.58s
```

Good properties are often simple: an operation and its inverse cancel out
(encode then decode), a result has an invariant (shares sum to the total, a
sorted list is ordered and has the same elements), or a fast implementation
agrees with a slow, obviously correct one.

## Common problems

| Problem | Symptom | Usual cause | Remedy |
|---|---|---|---|
| **Flaky tests** | Pass and fail at random; people re-run until green | Time, randomness, async waits, concurrency, shared state, test order[^luo] | Fix or quarantine at once: a suite that cries wolf is ignored |
| **Slow suite** | Tests run only before a push, or only on the server | Real databases, networks or sleeps inside "unit" tests | Move them to an integration suite; use doubles and fakes |
| **Brittle tests** | Every refactoring breaks dozens of tests | Testing implementation: private methods, internal calls, over-mocking | Test through the public interface; mock only the outside world |
| **Tests that check nothing** | High coverage, bugs still slip through | Assertions missing, too weak (`is not None`) or recomputing the answer | Mutation testing; review tests like code |
| **Opaque failures** | A failure needs a debugger to understand | Vague names, many behaviours per test, mystery guests | One behaviour per test; descriptive names; data in view |
| **Untestable code** | Tests need elaborate setup or global patching | No seams: dependencies created inside the logic | Inject dependencies; separate decisions from side effects |

## Putting it together

A unit test is worth writing when it will fail for a reason someone cares
about, and stay quiet otherwise. A checklist for each new test:

1. **Name the behaviour.** If you cannot say in one line what the test checks,
   it checks too much or nothing in particular.
2. **Arrange only what matters.** Inputs that affect the result belong in the
   test; everything else goes into helpers or defaults.
3. **Act once,** through the public interface.
4. **Assert the outcome,** with literal expected values, on the observable
   result or on calls to the outside world.
5. **Watch it fail.** Break the code, or write the test first, and check that
   the failure message tells you what went wrong.
6. **Keep it fast and deterministic.** No clock, network, disk or sleep that the
   test does not control.

And for the suite as a whole: run it on every change, keep it fast enough that
nobody is tempted not to, treat a flaky test as a broken build, use coverage to
find untested code rather than as a score, and let surviving mutants and
property-based counterexamples show you the tests you did not think to write.

## Why it matters

Dijkstra was right that tests cannot prove a program correct. What unit tests
do instead is make change cheap. A codebase with a fast, trustworthy suite can
be refactored, upgraded and extended by people who did not write it, because
they find out within seconds when they break something, and where. A codebase
without one gets more expensive to touch every year, which is why Feathers
could define legacy code by that absence alone. Tests are also the most
precise documentation a system has: each one is an example of how the code is
meant to be used, which never goes out of date without someone noticing. The
skill is not in writing many tests, but in writing ones that describe
behaviour, fail for real reasons and run fast enough to be run all the time.

## References

[^fowlerunit]: Fowler, M. (2014, May 5). UnitTest. *martinfowler.com*. <https://martinfowler.com/bliki/UnitTest.html>

[^khorikov]: Khorikov, V. (2020). *Unit testing: Principles, practices, and patterns*. Manning. ISBN 978-1-61729-627-7. <https://www.manning.com/books/unit-testing>

[^feathersrules]: Feathers, M. (2005, September 9). A set of unit testing rules. *Artima Weblogs*. <https://www.artima.com/weblogs/viewpost.jsp?thread=126923>

[^swe11]: Bender, A. (2020). Testing overview. In T. Winters, T. Manshreck, & H. Wright (Eds.), *Software engineering at Google: Lessons learned from programming over time* (Chapter 11). O'Reilly. <https://abseil.io/resources/swe-book/html/ch11.html>

[^nato69]: Buxton, J. N., & Randell, B. (Eds.). (1970). *Software engineering techniques: Report on a conference sponsored by the NATO Science Committee, Rome, Italy, 27–31 October 1969* (p. 16). NATO Science Committee. <http://homepages.cs.ncl.ac.uk/brian.randell/NATO/nato1969.PDF>

[^dijkstra]: Dijkstra, E. W. (1969). *Notes on structured programming* (EWD249). <https://www.cs.utexas.edu/~EWD/transcriptions/EWD02xx/EWD249/EWD249.html>

[^myers]: Myers, G. J. (1979). *The art of software testing*. Wiley. ISBN 0-471-04328-1.

[^myers3]: Myers, G. J., Badgett, T., & Sandler, C. (2012). Module (unit) testing. In *The art of software testing* (3rd ed., Chapter 5). Wiley. ISBN 978-1-118-03196-4.

[^ieee1008]: IEEE. (1986). *IEEE standard for software unit testing* (IEEE Std 1008-1987). <https://doi.org/10.1109/IEEESTD.1986.81001>

[^beck94]: Beck, K. (1994, October). Simple Smalltalk testing: With patterns. *The Smalltalk Report*. Reprinted in *Kent Beck's guide to better Smalltalk* (pp. 277–288). Cambridge University Press, 1997. <https://doi.org/10.1017/CBO9780511574979.033>

[^gnusunit]: Free Software Foundation. (n.d.). SUnit. In *GNU Smalltalk user's guide*. <https://www.gnu.org/software/smalltalk/manual/html_node/SUnit.html>

[^fowlerxunit]: Fowler, M. (2006, January 17). Xunit. *martinfowler.com*. <https://martinfowler.com/bliki/Xunit.html>

[^testinfected]: Beck, K., & Gamma, E. (1998). Test infected: Programmers love writing tests. *Java Report*, 3(7), 37–50.

[^pyunit]: Python Software Foundation. (n.d.). *unittest: Unit testing framework* (Python 2.7 documentation). <https://docs.python.org/2.7/library/unittest.html>

[^unittest]: Python Software Foundation. (n.d.). *unittest: Unit testing framework*. Python documentation. <https://docs.python.org/3/library/unittest.html>

[^xp]: Beck, K. (1999). *Extreme programming explained: Embrace change*. Addison-Wesley. ISBN 0-201-61641-6.

[^tdd]: Beck, K. (2002). *Test-driven development: By example*. Addison-Wesley. ISBN 978-0-321-14653-3. <https://www.informit.com/store/test-driven-development-by-example-9780321146533>

[^featherslegacy]: Feathers, M. C. (2004). *Working effectively with legacy code*. Prentice Hall. ISBN 978-0-13-117705-5. <https://www.informit.com/store/working-effectively-with-legacy-code-9780131177055>

[^mackinnon]: Mackinnon, T., Freeman, S., & Craig, P. (2001). Endo-testing: Unit testing with mock objects. In G. Succi & M. Marchesi (Eds.), *Extreme programming examined* (pp. 287–301). Addison-Wesley. Presented at XP2000. <https://www2.ccs.neu.edu/research/demeter/related-work/extreme-programming/MockObjectsFinal.PDF>

[^mocksarentstubs]: Fowler, M. (2007, January 2). Mocks aren't stubs. *martinfowler.com*. First published 2004. <https://martinfowler.com/articles/mocksArentStubs.html>

[^aaa]: Wake, B. (2011, April 26). 3A – Arrange, act, assert. *XP123*. <https://xp123.com/3a-arrange-act-assert/>

[^north]: North, D. (2006, March). Introducing BDD. *Better Software*. <https://dannorth.net/blog/introducing-bdd/>

[^meszaros]: Meszaros, G. (2007). *xUnit test patterns: Refactoring test code*. Addison-Wesley. ISBN 978-0-13-149505-0. <http://xunitpatterns.com/Test%20Double.html>

[^cohn]: Cohn, M. (2009). *Succeeding with agile: Software development using Scrum*. Addison-Wesley. ISBN 978-0-321-57936-2. <https://www.informit.com/store/succeeding-with-agile-software-development-using-scrum-9780321579362>

[^fowlerpyramid]: Fowler, M. (2012, May 1). TestPyramid. *martinfowler.com*. <https://martinfowler.com/bliki/TestPyramid.html>

[^vocke]: Vocke, H. (2018, February 26). The practical test pyramid. *martinfowler.com*. <https://martinfowler.com/articles/practical-test-pyramid.html>

[^demillo]: DeMillo, R. A., Lipton, R. J., & Sayward, F. G. (1978). Hints on test data selection: Help for the practicing programmer. *Computer*, 11(4), 34–41. <https://doi.org/10.1109/C-M.1978.218136>

[^googlemutation]: Petrović, G., & Ivanković, M. (2018). State of mutation testing at Google. *Proceedings of the 40th International Conference on Software Engineering: Software Engineering in Practice*, 163–171. <https://doi.org/10.1145/3183519.3183521>

[^quickcheck]: Claessen, K., & Hughes, J. (2000). QuickCheck: A lightweight tool for random testing of Haskell programs. *Proceedings of the Fifth ACM SIGPLAN International Conference on Functional Programming*, 268–279. <https://doi.org/10.1145/351240.351266>

[^hypothesis]: MacIver, D. R., Hatfield-Dodds, Z., & many other contributors. (2019). Hypothesis: A new approach to property-based testing. *Journal of Open Source Software*, 4(43), 1891. <https://doi.org/10.21105/joss.01891>

[^inozemtseva]: Inozemtseva, L., & Holmes, R. (2014). Coverage is not strongly correlated with test suite effectiveness. *Proceedings of the 36th International Conference on Software Engineering*, 435–445. <https://doi.org/10.1145/2568225.2568271>

[^luo]: Luo, Q., Hariri, F., Eloussi, L., & Marinov, D. (2014). An empirical analysis of flaky tests. *Proceedings of the 22nd ACM SIGSOFT International Symposium on Foundations of Software Engineering*, 643–653. <https://doi.org/10.1145/2635868.2635920>

[^unittestmock]: Python Software Foundation. (n.d.). *unittest.mock: Mock object library*. Python documentation. <https://docs.python.org/3/library/unittest.mock.html>

[^pytestassert]: pytest-dev. (n.d.). How to write and report assertions in tests. *pytest documentation*. <https://docs.pytest.org/en/stable/how-to/assert.html>

[^first]: Ottinger, T. (2009, February). F.I.R.S.T. *Agile in a Flash* (blog by T. Ottinger & J. Langr). <http://agileinaflash.blogspot.com/2009/02/first.html>

[^cleancode]: Martin, R. C. (2008). Unit tests. In *Clean code: A handbook of agile software craftsmanship* (Chapter 9). Prentice Hall. ISBN 978-0-13-235088-4.

[^swe12]: Kuefler, E. (2020). Unit testing. In T. Winters, T. Manshreck, & H. Wright (Eds.), *Software engineering at Google: Lessons learned from programming over time* (Chapter 12). O'Reilly. <https://abseil.io/resources/swe-book/html/ch12.html>

[^coveragebranch]: Batchelder, N. (n.d.). Branch coverage measurement. *Coverage.py documentation*. <https://coverage.readthedocs.io/en/latest/branch.html>

[^googlecoverage]: Arguelles, C., Ivanković, M., & Bender, A. (2020, August 7). Code coverage best practices. *Google Testing Blog*. <https://testing.googleblog.com/2020/08/code-coverage-best-practices.html>
