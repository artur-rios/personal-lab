---
title: "IEnumerable, ICollection, IList and IQueryable: What Each Collection Interface Promises"
description: "The collection interfaces in .NET look like a ladder of ever more capable lists, but each one makes a specific, smaller promise. Here is what IEnumerable, IEnumerator, ICollection, IList, the read-only interfaces and IQueryable actually guarantee, how foreach and yield return work underneath, why LINQ queries run late and sometimes twice, where an IQueryable filter really executes, which types to accept and return in your own APIs, and how the family grew from .NET 1.0 to .NET 8."
date: 2026-10-21T12:40:00Z
categories: [".NET"]
tags: [".NET", "C#", "Collections", "IEnumerable", "IQueryable", "LINQ", "Deferred Execution", "Iterators"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Open almost any C# codebase and you will find method signatures that take an
`IEnumerable<T>`, entities with `ICollection<T>` navigation properties,
repositories returning `IQueryable<T>`, and the occasional `IList<T>` or
`IReadOnlyList<T>`. They are easy to treat as interchangeable names for "a bunch
of items", and the code usually compiles whichever one you pick. Yet each
interface makes a different promise, and choosing the wrong one causes real
bugs: a query that runs three times, a database table loaded into memory to be
filtered in C#, an exception thrown far from the line that caused it, or a
"read-only" list that changes under your feet.

This article walks through the interfaces from the smallest promise to the
largest, then the read-only family and `IQueryable<T>`, which looks like a
collection but is something else. Along the way it covers how `foreach` and
`yield return` work underneath, why LINQ queries run late, and what the .NET
design guidelines say about which types to accept and return. Every output
shown comes from small programs run with the .NET SDK 10.0.400 on
21 October 2026; the database examples use EF Core 10 with SQLite.

## The interface families

**The .NET collection interfaces are a hierarchy of promises. `IEnumerable<T>`
only promises that you can walk the items once, in order. `ICollection<T>` adds
a count and the ability to add and remove. `IList<T>` adds positions. A
parallel read-only branch, `IReadOnlyCollection<T>` and its children, promises a
count or positions without any mutation methods. `IQueryable<T>` also extends
`IEnumerable<T>`, but represents a query that a provider translates and runs,
not items held in memory.**

The generic interfaces live in `System.Collections.Generic`, except
`IQueryable<T>`, which is in `System.Linq`. Each has an older non-generic
counterpart in `System.Collections` (`IEnumerable`, `ICollection`, `IList`,
`IDictionary`) from .NET 1.0, which works with `object` and should be avoided in
new code. One detail trips people up: `IEnumerable<T>` extends the non-generic
`IEnumerable`, but `ICollection<T>` does *not* extend the non-generic
`ICollection`, and `IList<T>` does not extend `IList`. The generic and
non-generic families meet only at the root.

{{< diagram src="hierarchy.svg" caption="The generic interfaces. Each arrow points to the interface being extended. The mutable and read-only branches are separate: `ICollection<T>` does not extend `IReadOnlyCollection<T>`, but `List<T>` and arrays implement both." >}}

| Interface | Adds | Typical implementations |
|---|---|---|
| `IEnumerable<T>` | `GetEnumerator()`: you can iterate | everything below, iterators, LINQ results |
| `ICollection<T>` | `Count`, `IsReadOnly`, `Add`, `Remove`, `Clear`, `Contains`, `CopyTo` | `List<T>`, `HashSet<T>`, `Dictionary<K,V>` |
| `IList<T>` | indexer `this[int]`, `IndexOf`, `Insert`, `RemoveAt` | `List<T>`, `T[]`, `Collection<T>` |
| `IReadOnlyCollection<T>` | `Count` | `List<T>`, `T[]`, `ImmutableArray<T>` |
| `IReadOnlyList<T>` | read-only indexer | `List<T>`, `T[]`, `ReadOnlyCollection<T>` |
| `IQueryable<T>` | `Expression`, `ElementType`, `Provider` | EF Core `DbSet<T>`, `AsQueryable()` |

## `IEnumerable<T>` and `IEnumerator<T>`: the iteration contract

`IEnumerable<T>` "exposes the enumerator, which supports a simple iteration
over a collection of a specified type". It declares one method, and the Remarks
put it plainly: it "contains a single method that you must implement when
implementing this interface; GetEnumerator, which returns an IEnumerator<T>
object".[^ienumerable] It is "the base interface for collections in the
System.Collections.Generic namespace", and anything that implements it can be
used in a `foreach`.

The enumerator is the object that actually walks. `IEnumerator<T>` has
`Current`, and inherits `MoveNext()` and `Reset()` from the non-generic
`IEnumerator` and `Dispose()` from `IDisposable`. Its rules are worth knowing
exactly:[^ienumerator]

- It starts *before* the first element, where `Current` is undefined, so
  `MoveNext()` must be called first.
- When `MoveNext()` passes the end it returns `false`, and keeps returning
  `false`. To go round again, "you must create a new enumerator instance".
- `Reset()` "is provided for COM interoperability. It does not necessarily need
  to be implemented; instead, the implementer can simply throw a
  NotSupportedException".
- "Enumerators can be used to read the data in the collection, but they cannot
  be used to modify the underlying collection." If the collection changes
  anyway, "the behavior of the enumerator is undefined".

Two of those are easy to see. The enumerator the compiler generates for an
iterator method does not support `Reset()`, and `List<T>` turns the undefined
case into an error: its enumerator "is irrecoverably invalidated and the next
call to MoveNext or IEnumerator.Reset throws an
InvalidOperationException".[^listenumerator] In this and the later examples,
each call that throws is wrapped in a `try`/`catch` that prints the exception's
type and message.

```csharp
IEnumerator e = Gen().GetEnumerator();
e.Reset();                       // Gen() is an iterator method

var list = new List<int> { 1, 2, 3 };
foreach (var n in list)
    if (n == 2) list.Remove(n);  // modifies the list mid-loop
```

```txt
$ dotnet Demo.dll reset
NotSupportedException: Specified method is not supported.
$ dotnet Demo.dll modify
InvalidOperationException: Collection was modified; enumeration operation may not execute.
```

Note what `IEnumerable<T>` does *not* promise. It does not say the data is
read-only: a `List<T>` passed as an `IEnumerable<T>` is still a list someone
else can change. It does not say how many items there are, or that iterating
twice gives the same items, or that iterating is cheap. It promises only that
you can ask for an enumerator.

### How foreach really works

The C# specification does not define `foreach` in terms of the interface. The
compiler first looks for a `GetEnumerator` method on the type itself, by member
lookup and overload resolution; it needs a public instance method whose return
type has a public readable `Current` property and a public `MoveNext()`
method. Only if that fails does it "check for an enumerable interface",
`IEnumerable<T>` and then `IEnumerable`.[^spec] So a type that implements no
interface at all can still be used in a `foreach`:

```csharp
// No interface at all: foreach only needs GetEnumerator(), MoveNext() and Current.
sealed class Countdown(int from)
{
    public Enumerator GetEnumerator() => new(from);

    public struct Enumerator(int from)
    {
        private int _current = from + 1;
        public int Current => _current;
        public bool MoveNext() => --_current > 0;
    }
}

foreach (var n in new Countdown(3))
    Console.WriteLine(n);
```

```txt
$ dotnet Demo.dll foreach
3
2
1
```

The specification then says a `foreach` over `x` "is semantically equivalent
to":[^spec]

```csharp
{
    E e = ((C)(x)).GetEnumerator();
    try
    {
        while (e.MoveNext())
        {
            V v = (V)(T)e.Current;
            «embedded_statement»
        }
    }
    finally
    {
        ... // Dispose e
    }
}
```

The `finally` block disposes the enumerator when it implements `IDisposable`,
and is left empty when the enumerator type is sealed and does not. That disposal
is why an iterator's `using` blocks and `finally` clauses run even if the loop
breaks early.[^iterators] The pattern-based lookup is also why the built-in
collections can avoid allocating: `List<T>.GetEnumerator()` returns a
`List<T>.Enumerator` struct rather than an `IEnumerator<T>`,[^listenumerator]
so a `foreach` over a variable typed as `List<T>` uses the struct directly,
while the same loop over an `IEnumerable<T>` variable goes through the
interface.

### Iterators: yield return

An iterator method is the easy way to produce an `IEnumerable<T>`. Any method
returning `IEnumerable<T>` (or `IEnumerator<T>`) that contains `yield return`
is turned by the compiler into a class with its own enumerator, a state machine
that remembers where the method stopped. "Calling an iterator doesn't execute
it immediately"; on each `MoveNext()`, execution resumes "after the
`yield return` statement that caused the previous suspension".[^yield]

```csharp
var sequence = Numbers();
Console.WriteLine($"type: {sequence.GetType().Name}");
using var e = sequence.GetEnumerator();
Console.WriteLine("enumerator created");
while (e.MoveNext())
    Console.WriteLine($"  Current = {e.Current}");

static IEnumerable<int> Numbers()
{
    Console.WriteLine("  body starts");
    yield return 1;
    Console.WriteLine("  resumed after 1");
    yield return 2;
    Console.WriteLine("  body ends");
}
```

```txt
$ dotnet Demo.dll iterator
type: <<<Main>$>g__Numbers|0_12>d
enumerator created
  body starts
  Current = 1
  resumed after 1
  Current = 2
  body ends
```

The type name gives the game away: `Numbers()` returned an instance of a
compiler-generated class, and not a single line of its body ran until the
first `MoveNext()`. Iterators were added in C# 2.0.[^history]

## Deferred execution: queries run late, and can run twice

Most LINQ operators over `IEnumerable<T>`, such as `Where`, `Select` and
`Take`, are written as iterators. They return a small object that remembers its
source and its lambda, and do the work only when something enumerates the
result. The .NET documentation defines it: "Deferred execution means that the
evaluation of an expression is delayed until its *realized* value is actually
required."[^deferred] This is a property of how those operators are written,
not of the `IEnumerable<T>` interface itself.

```csharp
var numbers = new List<int> { 1, 2, 3, 4 };
var query = numbers.Where(n =>
{
    Console.WriteLine($"  checking {n}");
    return n % 2 == 0;
});
Console.WriteLine("query built");
numbers.Add(6);
foreach (var n in query)
    Console.WriteLine($"  got {n}");
Console.WriteLine("done");
```

```txt
$ dotnet Demo.dll deferred
query built
  checking 1
  checking 2
  got 2
  checking 3
  checking 4
  got 4
  checking 6
  got 6
done
```

Three things show in that output. Building the query checked nothing. The
filter and the loop body interleave: each item travels the whole pipeline
before the next is read, which the documentation calls *lazy evaluation*, as
opposed to *eager evaluation*, where an operator such as `OrderBy` "has to sort
the entire collection before it returns the first element".[^deferred] And the
`6`, added after the query was built, was still found, because the list was
read during the loop.

{{< diagram src="deferred.svg" caption="A deferred query is a recipe. `foreach` pulls items through it one at a time, reading the source at that moment." >}}

The flip side is **multiple enumeration**. A variable typed `IEnumerable<T>`
may hold a query rather than data, and each operator that consumes it runs the
whole query again:

```csharp
var calls = 0;
IEnumerable<int> expensive = Enumerable.Range(1, 3).Select(n => { calls++; return n * 10; });
var total = expensive.Sum();
var count = expensive.Count();
var max = expensive.Max();
Console.WriteLine($"sum={total} count={count} max={max} selector calls={calls}");

calls = 0;
var materialised = expensive.ToList();
total = materialised.Sum();
count = materialised.Count;
max = materialised.Max();
Console.WriteLine($"sum={total} count={count} max={max} selector calls={calls}");
```

```txt
$ dotnet Demo.dll multiple
sum=60 count=3 max=30 selector calls=9
sum=60 count=3 max=30 selector calls=3
```

Three consumers, three full runs of the selector. With a cheap lambda that is
waste; with a lambda that calls a web service, reads a file or, as we will see,
queries a database, it is a real bug. Calling `ToList()` or `ToArray()` once
runs the query and stores the result, after which the data can be read as often
as you like. When a method receives an `IEnumerable<T>` and needs to walk it
more than once, materialising it first is the safe default.

## `ICollection<T>`: a size and the right to change

`ICollection<T>` "defines methods to manipulate generic collections". It
extends `IEnumerable<T>` with `Count`, `IsReadOnly`, `Add`, `Remove`, `Clear`,
`Contains` and `CopyTo`, and it is the parent of `IList<T>` and
`IDictionary<TKey,TValue>`.[^icollection] It has no notion of position: a
`HashSet<T>` is an `ICollection<T>` but has no "third item". That is why
Entity Framework entity classes often type navigation properties as
`ICollection<T>`: a set of related rows has a size and can gain or lose
members, but no meaningful order. The convention is ergonomic, not required.

`IsReadOnly` deserves a look, because an `ICollection<T>` is allowed to refuse
`Add`. Arrays are the classic case. A `T[]` implements `ICollection<T>` and
`IList<T>`, but it reports itself read-only through `ICollection<T>`, and fixed
in size through the non-generic `IList`:

```csharp
ICollection<int> array = new[] { 1, 2, 3 };
Console.WriteLine($"array IsReadOnly = {array.IsReadOnly}, IsFixedSize = {((IList)array).IsFixedSize}");
array.Add(4);
```

```txt
$ dotnet Demo.dll readonly
...
array IsReadOnly = True, IsFixedSize = True
NotSupportedException: Collection was of a fixed size.
```

The non-generic `IList` documentation names the three kinds: "A read-only IList
cannot be modified. A fixed-size IList does not allow the addition or removal
of elements, but it allows the modification of existing elements. A
variable-size IList allows the addition, removal, and modification of
elements."[^ilistnongeneric] An array is the middle kind, which is why
`array[0] = 9` works while `Add` throws. Accepting an `ICollection<T>`
therefore does not guarantee you can add to it.

### Counting without enumerating

The main reason code checks for `ICollection<T>` is `Count`. `Enumerable.Count()`
is an extension method on `IEnumerable<T>`, and its documentation says: "If the
type of `source` implements ICollection<T>, that implementation is used to
obtain the count of elements. Otherwise, this method determines the
count", by enumerating.[^count] Since .NET 6, `TryGetNonEnumeratedCount` asks
the question without ever enumerating. It "performs a series of type tests,
identifying common subtypes whose count can be determined without enumerating.
This includes ICollection<T>, ICollection, and internal types used in the LINQ
implementation."[^trycount]

```csharp
IEnumerable<int> list = new List<int> { 1, 2, 3 };
IEnumerable<int> lazy = Lazy();   // an iterator yielding 1, 2, 3
Console.WriteLine($"list:  TryGetNonEnumeratedCount -> {list.TryGetNonEnumeratedCount(out var a)} ({a})");
Console.WriteLine($"lazy:  TryGetNonEnumeratedCount -> {lazy.TryGetNonEnumeratedCount(out var b)} ({b})");
Console.WriteLine($"lazy:  Count() -> {lazy.Count()}");
```

```txt
$ dotnet Demo.dll count
list:  TryGetNonEnumeratedCount -> True (3)
lazy:  TryGetNonEnumeratedCount -> False (0)
  yielding 1
  yielding 2
  yielding 3
lazy:  Count() -> 3
```

Neither list mentions `IReadOnlyCollection<T>`, and that is not an oversight. A
type that implements only `IReadOnlyCollection<T>` has a `Count` property, but
`Count()` and `TryGetNonEnumeratedCount` do not look for it:

```csharp
// Implements IReadOnlyCollection<T> but not ICollection<T>.
sealed class Trio : IReadOnlyCollection<int>
{
    public int Count => 3;
    public IEnumerator<int> GetEnumerator()
    {
        for (var i = 1; i <= 3; i++)
        {
            Console.WriteLine($"  enumerating {i}");
            yield return i;
        }
    }
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
}
```

```txt
$ dotnet Demo.dll rocount
TryGetNonEnumeratedCount -> False
  enumerating 1
  enumerating 2
  enumerating 3
Count() = 3
```

Built-in types such as `List<T>` and arrays implement both interfaces, so this
only bites custom collections, but it is a reason to implement `ICollection<T>`
(or at least the non-generic `ICollection`) on a custom collection whose count
is cheap.

## `IList<T>`: positions

`IList<T>` "represents a collection of objects that can be individually
accessed by index". It extends `ICollection<T>` with an indexer, `IndexOf`,
`Insert` and `RemoveAt`, and is "the base interface of all generic
lists".[^ilist] Use it when position matters: reading item `i`, replacing it,
inserting before it.

Two things the interface does not promise. It does not promise fast indexing:
the indexer is O(1) on `List<T>` and arrays, which are backed by arrays, but the
interface does not require it, and a custom `IList<T>` could walk a chain of
nodes. (The framework's own `LinkedList<T>` sidesteps the question by not
implementing `IList<T>` at all.) And it does not include sorting or searching
helpers: `Sort` and `BinarySearch` are methods on the concrete `List<T>`
class, not on the interface.

## The read-only interfaces, and why read-only is not immutable

`IReadOnlyCollection<T>`, `IReadOnlyList<T>` and
`IReadOnlyDictionary<TKey,TValue>` arrived in .NET Framework 4.5, seven years
after the mutable interfaces; `IReadOnlySet<T>` only followed in
.NET 5.[^irocollection][^irolist][^irodictionary][^iroset]
`IReadOnlyCollection<T>` "represents a strongly-typed, read-only collection of
elements" and adds only `Count`; `IReadOnlyList<T>` adds a get-only indexer.
Their `T` is covariant, like `IEnumerable<T>`'s, so an `IReadOnlyList<Derived>`
can be passed where an `IReadOnlyList<Base>` is expected; `IList<T>` cannot
allow that, because it also accepts items.[^variance]

"Read-only" describes what *you* can do through the interface, not what the
collection will do. The underlying object may still change, and the cast back
to a mutable type is always one line away:

```csharp
var items = new List<string> { "a", "b" };
IReadOnlyList<string> view = items;
items.Add("c");
Console.WriteLine($"view.Count = {view.Count}");
Console.WriteLine($"cast back: {((List<string>)view).Count}");

var wrapper = items.AsReadOnly();
Console.WriteLine($"wrapper is IList<string>: {wrapper is IList<string>}");
((IList<string>)wrapper).Add("d");
```

```txt
$ dotnet Demo.dll readonly
view.Count = 3
cast back: 3
wrapper is IList<string>: True
NotSupportedException: Collection is read-only.
...
```

Returning `IReadOnlyList<T>` from a method documents an intention; returning a
`ReadOnlyCollection<T>` from `AsReadOnly()` enforces it, because the wrapper
throws on every mutating call. Even the wrapper is a *view*: "if changes are
made to the underlying collection, the read-only collection reflects those
changes".[^readonlycollection]

When the data itself must never change, use an immutable or frozen collection:

- **`ImmutableArray<T>`** (`System.Collections.Immutable`) "represents an array
  that is immutable, meaning it can't be changed once it's created". It is a
  struct over an array; "adding" returns a new array, an O(n) copy, so it suits
  data that is rarely updated or small, and fast to read.[^immutablearray]
- **`FrozenSet<T>`** and **`FrozenDictionary<TKey,TValue>`**, new in .NET 8,
  are "optimized for situations where a set is created infrequently but is used
  frequently at run time": expensive to build, very fast to read, ideal for
  lookup tables built once at start-up.[^frozenset][^net8]

```csharp
var immutable = ImmutableArray.Create(1, 2, 3);
var bigger = immutable.Add(4);
Console.WriteLine($"immutable: {immutable.Length}, after Add: {bigger.Length}");

var frozen = new[] { "red", "green", "blue" }.ToFrozenSet();
Console.WriteLine($"frozen contains green: {frozen.Contains("green")}");
```

```txt
$ dotnet Demo.dll readonly
...
immutable: 3, after Add: 4
frozen contains green: True
```

### Dictionaries and sets

Two more members of the mutable branch complete the picture.
`IDictionary<TKey,TValue>` is an `ICollection<KeyValuePair<TKey,TValue>>` that
adds lookup by key; `Dictionary<TKey,TValue>` is the everyday implementation.
`ISet<T>`, added in .NET Framework 4, "provides the base interface for the
abstraction of sets", with operations such as `UnionWith`, `IntersectWith`,
`IsSubsetOf` and `SetEquals`; `HashSet<T>` and `SortedSet<T>` implement
it.[^iset][^icollection] Each has a read-only counterpart.

## `IQueryable<T>`: a query, not a collection

`IQueryable<T>` extends `IEnumerable<T>`, so it can be passed anywhere an
`IEnumerable<T>` is expected, but it is a different kind of object. It
"provides functionality to evaluate queries against a specific data source", is
"intended for implementation by query providers", and has three properties:
the `Expression` it represents, its `ElementType`, and the `Provider` that will
run it. "Enumeration forces the expression tree associated with an
IQueryable<T> object to be executed."[^iqueryable]

The difference is in how lambdas arrive. The LINQ operators on
`IEnumerable<T>`, in `System.Linq.Enumerable`, take `Func<T,bool>` delegates:
compiled code. The same-named operators on `IQueryable<T>`, in
`System.Linq.Queryable`, take `Expression<Func<T,bool>>`. "When a lambda
expression is assigned to a variable of type Expression<TDelegate>, the
compiler emits code to build an expression tree that represents the lambda
expression", a data structure describing the code rather than the code
itself.[^expressiontrees] A provider can read that tree and translate it into
something else, such as SQL.

`AsQueryable()` shows the machinery without a database:

```csharp
var numbers = new[] { 1, 2, 3, 4, 5, 6 };
IQueryable<int> q = numbers.AsQueryable().Where(n => n % 2 == 0).Select(n => n * 10);
Console.WriteLine(q.Expression);
Console.WriteLine(q.ElementType);
Console.WriteLine(q.Provider.GetType().Name);
Console.WriteLine(string.Join(", ", q));

IEnumerable<int> e = numbers.Where(n => n % 2 == 0).Select(n => n * 10);
Console.WriteLine(e.GetType().Name);
```

```txt
$ dotnet Demo.dll queryable
System.Int32[].Where(n => ((n % 2) == 0)).Select(n => (n * 10))
System.Int32
EnumerableQuery`1
20, 40, 60
ArrayWhereSelectIterator`2
```

The `IQueryable<int>` carries a readable description of the whole query, the
expression tree, and a provider (`EnumerableQuery<T>`, which simply compiles the
tree and runs it in memory). The `IEnumerable<int>` version is just a chain of
iterator objects, here an internal `ArrayWhereSelectIterator` that LINQ uses to
fuse a `Where` and a `Select` over an array.

### Where the work happens

With a real provider, the type of the variable decides where the filter runs.
This program, using EF Core 10 and SQLite, prints every SQL command it sends:

```csharp
IQueryable<Product> queryable = db.Products.Where(p => p.Price > 100);
Console.WriteLine($"rows: {queryable.Count()}");

IEnumerable<Product> enumerable = db.Products.AsEnumerable().Where(p => p.Price > 100);
Console.WriteLine($"rows: {enumerable.Count()}");
```

```txt
$ dotnet Ef.dll
--- IQueryable<Product>: the filter becomes SQL
SQL sent: SELECT COUNT(*) FROM "Products" AS "p" WHERE "p"."Price" > 100.0
rows: 2
--- IEnumerable<Product>: the filter runs in memory
SQL sent: SELECT "p"."Id", "p"."Name", "p"."Price" FROM "Products" AS "p"
rows: 2
```

Same lambda, same answer, very different work. Through `IQueryable<T>`, both
the filter and the `Count()` became SQL, and the database returned a single
number. After `AsEnumerable()`, the static type is `IEnumerable<T>`, so
`Where` and `Count` bind to `Enumerable`: EF Core sent a query with no
`WHERE`, every row was materialised into a `Product` object, and the filter ran
in C#. With three rows nobody notices; with three million, it is an outage. The
same thing happens silently when a repository method returns `IEnumerable<T>`
and the caller adds `.Where(...)` to it.

{{< diagram src="queryable.svg" caption="The same lambda as an expression tree, translated to SQL, and as a compiled delegate, run in memory after every row has been fetched." >}}

### Translation can fail, and fails late

A provider can only translate what it understands. EF Core "attempts to
evaluate a query on the server as much as possible"; it allows parts it cannot
translate only in the final projection, and "if EF Core detects an expression,
in any place other than the top-level projection, which can't be translated to
the server, then it throws a runtime exception".[^clienteval] Before EF Core
3.0, it quietly evaluated such parts on the client instead, which is how many
applications ended up loading whole tables without knowing. A method of your
own is the simplest thing it cannot translate:

```csharp
var cheap = db.Products.Where(p => Rules.IsCheap(p)).ToList();

static class Rules
{
    public static bool IsCheap(Product p) => p.Price < 100;
}
```

```txt
$ dotnet Ef.dll
...
--- a method the provider cannot translate
The LINQ expression 'DbSet<Product>()
    .Where(p => Rules.IsCheap(p))' could not be translated. Either rewrite the query in a form that can be translated, or switch to client evaluation explicitly by inserting a call to 'AsEnumerable', 'AsAsyncEnumerable', 'ToList', or 'ToListAsync'. See https://go.microsoft.com/fwlink/?linkid=2101038 for more information.
```

The code compiles, because to the C# compiler any lambda is a valid expression
tree. The exception comes from `ToList()`, when the query is executed, not from
`Where`, where the problem was written. In a layered application, where one
method builds an `IQueryable<T>` and another enumerates it, the stack trace
points at the wrong place. The fix is the one the message suggests: rewrite the
condition in terms the provider knows (`p.Price < 100`), or switch to client
evaluation on purpose, after the database has filtered as much as it can.

## Choosing types for parameters and return values

The .NET Framework Design Guidelines give a clear rule for inputs: "DO use the
least-specialized type possible as a parameter type. Most members taking
collections as parameters use the `IEnumerable<T>` interface." They add: "AVOID
using ICollection<T> or ICollection as a parameter just to access the `Count`
property", and instead check for those interfaces at run time, which is exactly
what `TryGetNonEnumeratedCount` does for you.[^guidelines]

For outputs the same guidelines recommend `Collection<T>` or
`ReadOnlyCollection<T>` for properties and return values, and say "DO NOT use
ArrayList or List<T> in public APIs", because `List<T>` "is optimized for
performance and power at the cost of cleanness of the APIs and flexibility". And
"DO NOT return null values from collection properties or from methods
returning collections. Return an empty collection or an empty array
instead."[^guidelines] The page reprints the 2008 second edition of the book,
from before the `IReadOnly*` interfaces existed, so read its advice on read-only
return types alongside them.

In practice that comes down to a few rules of thumb:

| Situation | Use |
|---|---|
| A method only iterates its input once | Accept `IEnumerable<T>` |
| A method iterates its input several times | Accept `IEnumerable<T>` and call `ToList()` once, or accept `IReadOnlyCollection<T>` |
| A method needs indexes | Accept `IReadOnlyList<T>`, or `IList<T>` if it writes |
| Returning finished data the caller should not change | Return `IReadOnlyList<T>` or `IReadOnlyCollection<T>`; wrap with `AsReadOnly()` to enforce it |
| Returning data that must never change | Return `ImmutableArray<T>` or a frozen collection |
| A data-access method the caller should compose | Return `IQueryable<T>` only inside the data layer; elsewhere run the query and return data |
| Returning a large or endless stream | Return `IEnumerable<T>` (or `IAsyncEnumerable<T>`) from an iterator, and document that it is lazy |

## A short history

- **.NET Framework 1.0 and C# 1.0 (2002).** Collections were non-generic:
  `ArrayList`, `Hashtable` and the `IEnumerable`, `ICollection` and `IList`
  interfaces, all working with `object`. C# 1.0 had no generics and no
  LINQ.[^history] C# 1.2 (2003) made `foreach` call `Dispose` on enumerators
  that implement `IDisposable`.[^history]
- **.NET Framework 2.0 and C# 2.0 (2005).** Generics brought
  `System.Collections.Generic`: `IEnumerable<T>`, `ICollection<T>`,
  `IList<T>`, `List<T>`, `Dictionary<K,V>`. C# 2.0 also added iterators and
  `yield return`.[^history][^ienumerable]
- **.NET Framework 3.5 and C# 3.0 (2007).** LINQ arrived, with lambda
  expressions, extension methods, expression trees and `IQueryable<T>`; the
  `Enumerable.Count()` extension dates from here.[^history][^iqueryable][^count]
- **.NET Framework 4 and C# 4.0 (2010).** Generic variance made
  `IEnumerable<out T>` covariant, and `ISet<T>` appeared.[^history][^variance][^iset]
- **.NET Framework 4.5 (2012).** `IReadOnlyCollection<T>`,
  `IReadOnlyList<T>` and `IReadOnlyDictionary<TKey,TValue>` were added, fixing
  the long-standing lack of a read-only abstraction.[^irocollection][^irolist][^irodictionary][^fx45]
- **.NET 5 (2020).** `IReadOnlySet<T>` completed the read-only branch.[^iroset][^net5]
- **.NET 6 (2021).** `TryGetNonEnumeratedCount` made the "count without
  enumerating" check a public API.[^trycount][^net6]
- **.NET 8 (2023).** `FrozenSet<T>` and `FrozenDictionary<TKey,TValue>`.[^net8]

## Common misunderstandings

| Misunderstanding | What is actually true |
|---|---|
| "`IEnumerable<T>` means read-only." | It only means you can iterate. The object behind it may be a `List<T>` that anyone can change. |
| "`IEnumerable<T>` is lazy." | Laziness belongs to iterators and LINQ operators. A `List<T>` typed as `IEnumerable<T>` is already in memory. |
| "Calling `Count()` and then `foreach` is free." | On a query, each one runs the whole query again. Materialise first. |
| "`Count()` is O(1) on any type with a `Count` property." | Only for `ICollection<T>`, `ICollection` and LINQ's internal types. An `IReadOnlyCollection<T>` alone is enumerated. |
| "`ICollection<T>` means I can add to it." | Not if `IsReadOnly` is true. Arrays implement `ICollection<T>` and throw on `Add`. |
| "`IList<T>` indexing is always O(1)." | It is on `List<T>` and arrays; the interface does not require it. |
| "`IReadOnlyList<T>` means the data never changes." | The owner can still change it, and a caller can cast it back. Use immutable or frozen collections for that. |
| "`IQueryable<T>` is a collection from the database." | It is a description of a query. Nothing runs until it is enumerated, and each enumeration runs it again. |
| "Turning `IQueryable<T>` into `IEnumerable<T>` changes nothing." | Every operator after that point runs in memory, on every row the database returned. |
| "If a LINQ query compiles, the provider can run it." | The compiler accepts any expression tree; untranslatable parts throw at run time, when the query executes. |

## References

[^ienumerable]: Microsoft. (n.d.). *IEnumerable<T> interface*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ienumerable-1>

[^ienumerator]: Microsoft. (n.d.). *IEnumerator<T> interface*. .NET API reference. Remarks. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ienumerator-1>

[^listenumerator]: Microsoft. (n.d.). *List<T>.GetEnumerator method*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.list-1.getenumerator>

[^spec]: Microsoft. (n.d.). Statements: The foreach statement (§13.9.5). In *C# language specification*. <https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/statements#1395-the-foreach-statement>

[^iterators]: Microsoft. (n.d.). *Iterators*. C# documentation. <https://learn.microsoft.com/en-us/dotnet/csharp/iterators>

[^yield]: Microsoft. (2026). *yield statement: provide the next element in an iterator*. C# language reference. <https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/statements/yield>

[^history]: Microsoft. (2025). *The history of C#*. C# documentation. <https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-version-history>

[^deferred]: Microsoft. (n.d.). *Deferred execution and lazy evaluation*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/standard/linq/deferred-execution-lazy-evaluation>

[^icollection]: Microsoft. (n.d.). *ICollection<T> interface*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.icollection-1>

[^ilistnongeneric]: Microsoft. (n.d.). *IList interface*. .NET API reference. Remarks. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.ilist>

[^count]: Microsoft. (n.d.). *Enumerable.Count method*. .NET API reference. Remarks. <https://learn.microsoft.com/en-us/dotnet/api/system.linq.enumerable.count>

[^trycount]: Microsoft. (n.d.). *Enumerable.TryGetNonEnumeratedCount<TSource> method*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.linq.enumerable.trygetnonenumeratedcount>

[^ilist]: Microsoft. (n.d.). *IList<T> interface*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ilist-1>

[^irocollection]: Microsoft. (n.d.). *IReadOnlyCollection<T> interface*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ireadonlycollection-1>

[^irolist]: Microsoft. (n.d.). *IReadOnlyList<T> interface*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ireadonlylist-1>

[^irodictionary]: Microsoft. (n.d.). *IReadOnlyDictionary<TKey,TValue> interface*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ireadonlydictionary-2>

[^iroset]: Microsoft. (n.d.). *IReadOnlySet<T> interface*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ireadonlyset-1>

[^variance]: Microsoft. (2026). *Covariance and contravariance in generics*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/standard/generics/covariance-and-contravariance>

[^readonlycollection]: Microsoft. (n.d.). *ReadOnlyCollection<T> class*. .NET API reference. Remarks. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.objectmodel.readonlycollection-1>

[^immutablearray]: Microsoft. (n.d.). *ImmutableArray<T> struct*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.immutable.immutablearray-1>

[^frozenset]: Microsoft. (n.d.). *FrozenSet<T> class*. .NET API reference. Remarks. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.frozen.frozenset-1>

[^net8]: Microsoft. (2023, November 14). *What's new in .NET 8 runtime*. .NET documentation. Section "Performance-focused types". <https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-8/runtime>

[^iset]: Microsoft. (n.d.). *ISet<T> interface*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.iset-1>

[^iqueryable]: Microsoft. (n.d.). *IQueryable<T> interface*. .NET API reference. <https://learn.microsoft.com/en-us/dotnet/api/system.linq.iqueryable-1>

[^expressiontrees]: Microsoft. (2025). *Expression trees*. C# documentation. <https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/expression-trees/>

[^clienteval]: Microsoft. (n.d.). *Client vs. server evaluation*. Entity Framework Core documentation. <https://learn.microsoft.com/en-us/ef/core/querying/client-eval>

[^guidelines]: Cwalina, K., & Abrams, B. (2008). Guidelines for collections. In *Framework design guidelines* (2nd ed.). Reprinted on Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/standard/design-guidelines/guidelines-for-collections>

[^fx45]: Bray, B. (2012, August 15). Announcing the release of .NET Framework 4.5 RTM – product and source code. *.NET Blog*. <https://devblogs.microsoft.com/dotnet/announcing-the-release-of-net-framework-4-5-rtm-product-and-source-code/>

[^net5]: Lander, R. (2020, November 10). Announcing .NET 5.0. *.NET Blog*. <https://devblogs.microsoft.com/dotnet/announcing-net-5-0/>

[^net6]: Lander, R. (2021, November 8). Announcing .NET 6: The fastest .NET yet. *.NET Blog*. <https://devblogs.microsoft.com/dotnet/announcing-net-6/>
