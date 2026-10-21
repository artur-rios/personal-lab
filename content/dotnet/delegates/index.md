---
title: "C# Delegates: Methods as Values"
description: "A delegate is a type-safe reference to one or more methods, so a method can be stored, passed and called later like any other value. Here is what a delegate object actually holds, how lambdas, method groups and the built-in Func and Action types create one, how multicast invocation, events and variance behave, what closures capture and why the for loop surprises people, how delegates compare with interfaces, expression trees and function pointers, and how the feature grew from C# 1.0 to C# 11."
date: 2026-10-21T12:50:00Z
categories: [".NET"]
tags: ["C#", ".NET", "Delegates", "Lambdas", "Events", "Closures", "Expression Trees"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

`List<T>.Sort` doesn't know how you want your items ordered, so it asks you:
pass it a method that compares two items, and it calls that method whenever it
needs to. A button doesn't know what should happen when it is clicked, so it
keeps a list of methods to call. LINQ's `Where` doesn't know which items you
want, so it takes a method that answers yes or no for each one. All three
need the same thing from the language: a way to treat *a method* as a value
that can be stored in a field, passed as an argument and called later. In C#
that value is a **delegate**.

Delegates are among the oldest features of C#, and most code uses them
without naming them: every lambda, every event, every LINQ query. This article
looks at what a delegate object actually is, how it is created and called, what
happens when it holds several methods, how events build on it, and the parts
that cause bugs: closures, exceptions in event handlers, and subscriptions that
keep objects alive. The programs shown were run with the .NET 10 SDK
(10.0.400) on 21 October 2026, and their output is shown as printed.

## What a delegate is

**A delegate is an instance of a delegate type: a class the compiler generates
from a `delegate` declaration, deriving from `System.MulticastDelegate`. The
object holds an *invocation list* of one or more methods, each with the object
it should be called on, and calling the delegate calls every method in the list
with the same arguments.**

The C# specification states it directly: "A delegate declaration defines a
class that is derived from the class `System.Delegate`. A delegate instance
encapsulates an ***invocation list***, which is a list of one or more methods,
each of which is referred to as a ***callable entity***. For instance methods,
a callable entity consists of an instance and a method on that instance. For
static methods, a callable entity consists of just a method."[^specdelegates]
The C# guide adds that the compiler generates "a class derived from
`MulticastDelegate`" for each declaration, and that the language prevents you
from deriving from `Delegate` or `MulticastDelegate` yourself.[^delegateclass]

A small program makes those parts visible:

```csharp
public delegate int Transformer(int value);

Transformer twice = Maths.Double;            // a static method
var counter = new Counter(10);
Transformer add = counter.Add;               // an instance method

Console.WriteLine($"Type:      {twice.GetType()}");
Console.WriteLine($"Base:      {twice.GetType().BaseType}");
Console.WriteLine($"Base base: {twice.GetType().BaseType!.BaseType}");
Console.WriteLine($"twice.Method: {twice.Method}");
Console.WriteLine($"twice.Target: {twice.Target ?? "(null, a static method)"}");
Console.WriteLine($"add.Method:   {add.Method}");
Console.WriteLine($"add.Target:   {add.Target}");
Console.WriteLine($"twice(21) = {twice(21)}, add.Invoke(5) = {add.Invoke(5)}");
```

```txt
$ dotnet run -c Release -- anatomy
Type:      Transformer
Base:      System.MulticastDelegate
Base base: System.Delegate
twice.Method: Int32 Double(Int32)
twice.Target: (null, a static method)
add.Method:   Int32 Add(Int32)
add.Target:   Counter(start: 10)
twice(21) = 42, add.Invoke(5) = 15
```

`Transformer` is a real class, two steps below `System.Delegate`. Each
delegate carries a `Method`, the method to call, and a `Target`, the object to
call it on: "`null` if the delegate represents a static method".[^target] That
`Target` reference matters later: a delegate to an instance method keeps that
instance alive for as long as the delegate itself is alive.

Two more rules from the specification are worth knowing early. Delegate types
are "implicitly `sealed`", and they are "name equivalent, not structurally
equivalent": two delegate types with identical signatures, such as
`delegate int D1(int i, double d)` and `delegate int D2(int c, double d)`, are
different types and not interchangeable.[^specdelegates] That is one reason
most code uses the shared `Func` and `Action` types rather than declaring its
own.

## Creating and calling delegates

There are four ways to produce a delegate, and they all produce the same kind
of object:

```csharp
static int Double(int x) => x * 2;

Transformer a = Double;                                // method group conversion
Transformer b = new Transformer(Double);               // explicit creation, the C# 1.0 form
Transformer c = x => x * 3;                            // lambda expression
Transformer d = delegate (int x) { return x * 4; };    // anonymous method

int r1 = a(10);          // call it like a method
int r2 = c.Invoke(10);   // or call Invoke, which is the same thing
```

- **Method groups.** A method name without parentheses converts to any
  compatible delegate type. The C# guide's example is
  `phrases.Sort(CompareLength)`: "you use the method name without parentheses.
  This tells the compiler to convert the method reference into a delegate that
  can be invoked later."[^delegateclass]
- **Lambdas.** "You can convert any lambda expression to a delegate type", and
  the compiler infers the parameter types from the delegate type it is
  converted to.[^lambdas]
- **Anonymous methods.** The `delegate` operator came first, in C# 2.0, and
  lambdas made it mostly redundant. The C# reference says lambdas "provide a
  more concise and expressive way", and names the one thing an anonymous
  method can still do that a lambda cannot: omit the parameter list entirely,
  as in `Action<int, double> introduce = delegate { … };`, which ignores
  whatever arguments it is given.[^delegateop]

Calling `d(x)` and `d.Invoke(x)` are the same: the specification requires
every delegate type to have an `Invoke` method, and "calling the `Invoke`
method on a delegate type is semantically equivalent to using the delegate
invocation syntax".[^specdelegates] Calling a delegate variable that holds
`null` throws a `NullReferenceException`, which is why code that may have no
subscriber writes `handler?.Invoke(x)`.

### The built-in delegate types

You rarely need to declare a delegate type. The base library provides generic
ones that cover almost every signature:

| Type | Signature | Typical use |
|---|---|---|
| `Action`, `Action<T1…T16>` | returns `void` | callbacks, `Task.Run`, `List<T>.ForEach` |
| `Func<TResult>`, `Func<T1…T16, TResult>` | returns a value, always the last type argument | LINQ operators, factories |
| `Predicate<T>` | `bool (T)` | `List<T>.FindAll`, `Array.Exists` |
| `Comparison<T>` | `int (T, T)` | `List<T>.Sort`, `Array.Sort` |
| `Converter<TInput, TOutput>` | `TOutput (TInput)` | `List<T>.ConvertAll` |
| `EventHandler`, `EventHandler<TEventArgs>` | `void (object? sender, TEventArgs e)` | events |

`Predicate<int>` and `Func<int, bool>` have the same shape but, being name
equivalent, they are different types, so a variable of one cannot be assigned
to the other. A custom delegate type is still worth declaring when its name
documents intent better than `Func<string, int, bool>` does, or when the
signature needs something the generic types cannot express, such as `ref` or
`out` parameters, or default parameter values.

### Natural types

Since C# 10, a lambda or method group can have a *natural type*: "the compiler
infers the delegate type from the lambda expression", choosing "an available
`Func` or `Action` delegate, if a suitable one exists. Otherwise, it
synthesizes a delegate type."[^lambdas][^history] That is what lets you write
`var` with a lambda:

```csharp
var square = (int x) => x * x;
var greet = () => Console.WriteLine("  hi");
var parse = (string s) => int.Parse(s);
var read = Console.ReadLine;          // a method group with a single overload
var withRef = (ref int x) => x++;
```

```txt
$ dotnet run -c Release -- natural
square: System.Func`2[System.Int32,System.Int32]
greet:  System.Action
parse:  System.Func`2[System.String,System.Int32]
read:   System.Func`1[System.String]
ref lambda: <>F{00000001}`2[System.Int32,System.Int32]
```

The lambda with a `ref` parameter fits no `Func`, so the compiler made up a
delegate type for it, with an unspeakable name. When there is no single
answer, there is no natural type: `Console.WriteLine` has many overloads, and
the compiler refuses to guess.

```csharp
var write = Console.WriteLine;
```

```txt
$ dotnet build
error CS8917: The delegate type could not be inferred.
```

## Multicast delegates

Every delegate type derives from `MulticastDelegate`, so every delegate can
hold more than one method. The C# guide explains why there is no separate
"single-cast" kind: the original design considered one, but "this distinction
proved less useful than originally thought, so all delegates in .NET support
multiple target methods".[^delegateclass]

`+` and `+=` combine delegates, `-` and `-=` remove them. The key detail is
that **a delegate never changes**. "Once instantiated, a delegate instance
always refers to the same invocation list"; combining or removing produces "a
new delegate … with its own invocation list; the invocation lists of the
delegates combined or removed remain unchanged".[^specdelegates] So `+=` on a
delegate variable builds a new object and stores it back in the variable.

{{< diagram src="invocation-list.svg" caption="`+=` builds a new delegate whose invocation list is the old one plus the new method; the original is unchanged. Calling it calls every entry in order with the same arguments, and returns the last entry's result." >}}

```csharp
Func<int, int> chain = x => { Console.WriteLine($"  first({x})"); return x + 1; };
Func<int, int> original = chain;
chain += x => { Console.WriteLine($"  second({x})"); return x * 10; };
chain += x => { Console.WriteLine($"  third({x})"); return x - 1; };

Console.WriteLine($"same object after += ? {ReferenceEquals(original, chain)}");
Console.WriteLine($"original has {original.GetInvocationList().Length} method(s), chain has {chain.GetInvocationList().Length}");
Console.WriteLine("calling chain(5):");
int result = chain(5);
Console.WriteLine($"result = {result}");
```

```txt
$ dotnet run -c Release -- multicast
same object after += ? False
original has 1 method(s), chain has 3
calling chain(5):
  first(5)
  second(5)
  third(5)
result = 4
```

All three methods ran, in the order they were added, each with the same
argument. Only the last one's return value came back: `first` returned 6 and
`second` returned 50, and both values were thrown away. The specification
says so: invocation proceeds "by invoking each of the methods in the
invocation list synchronously, in order", and if the delegate has "output
parameters or a return value, their final value will come from the invocation
of the last delegate in the list".[^specdelegates] A multicast delegate that
returns a value is almost always a mistake, which is why event handlers return
`void`.

### When a handler throws

The same paragraph of the specification describes the other trap: if a
method in the list throws, "any methods further down the invocation list are
not invoked".[^specdelegates] To keep one failing handler from silencing the
rest, take the list apart with `GetInvocationList()`, which returns one
single-method delegate per entry "in invocation order", and call each one
yourself:[^getinvocationlist]

```csharp
Action handlers = () => Console.WriteLine("  A");
handlers += () => throw new InvalidOperationException("B failed");
handlers += () => Console.WriteLine("  C");

Console.WriteLine("Invoking the delegate directly:");
try { handlers(); }
catch (Exception ex) { Console.WriteLine($"  caught: {ex.Message}"); }

Console.WriteLine("Invoking each entry of GetInvocationList():");
foreach (Action handler in handlers.GetInvocationList().Cast<Action>())
{
    try { handler(); }
    catch (Exception ex) { Console.WriteLine($"  caught: {ex.Message}"); }
}
```

```txt
$ dotnet run -c Release -- exceptions
Invoking the delegate directly:
  A
  caught: B failed
Invoking each entry of GetInvocationList():
  A
  caught: B failed
  C
```

Called directly, `C` never ran. Called entry by entry, it did.

### Removing a method

`-=` removes a matching entry, and when the same method appears more than once
"the last occurrence in the invocation list is the one actually removed".
Removing something that isn't there is "not an error".[^specdelegates] That
leniency hides a common bug: a lambda written twice is two different
delegates, so it doesn't match.

```csharp
Action handlers = () => Console.WriteLine("  A");
handlers += () => Console.WriteLine("  B");
handlers -= () => Console.WriteLine("  B");   // a different lambda
Console.WriteLine($"after -= with a new lambda: {handlers.GetInvocationList().Length} handlers");

Action b = () => Console.WriteLine("  B");
handlers += b;
handlers -= b;                                // the same instance
Console.WriteLine($"after += b and -= b: {handlers.GetInvocationList().Length} handlers");
```

```txt
$ dotnet run -c Release -- remove
after -= with a new lambda: 2 handlers
after += b and -= b: 2 handlers
```

The first `-=` silently did nothing, and the list still has `A` and `B`. The
second removed `b` and left the same two. The fix is the one the .NET event
guide gives: keep the handler in a variable if you will ever need to remove
it, because otherwise the removal "would be a different instance of the
delegate, and silently do nothing".[^eventpattern]

## Events

An event is a delegate with a guard around it. The `event` keyword declares a
member "of a delegate type"; event handlers are "delegate instances added to
the event and executed when the event is raised".[^eventkeyword] What the
keyword adds is access control. Code outside the declaring type can only add
and remove handlers; it cannot call the delegate, replace it or clear it.

```csharp
public class Clock
{
    public event EventHandler? Tick;
    public void RaiseTick() => Tick?.Invoke(this, EventArgs.Empty);
}

var clock = new Clock();
clock.Tick(clock, EventArgs.Empty);   // raise it from outside
clock.Tick = null;                    // or wipe every subscriber
```

```txt
$ dotnet build
error CS0070: The event 'Clock.Tick' can only appear on the left hand side of += or -= (except when used from within the type 'Clock')
```

A plain public delegate field would allow both lines, so any caller could fire
the event or remove everyone else's handlers. With `event`, the guide notes,
"the only operations available on a field-like event are *add* and *remove*
handler", and "code outside the class can't raise the event".[^eventpattern]
That includes derived classes: a subclass of `Clock` that writes
`Tick?.Invoke(…)` gets the same CS0070 error. That is why the pattern in the C#
reference wraps the raise in a `protected virtual` method, "to enable derived
classes to raise the event".[^eventkeyword]

The declaration above is a *field-like event*: the compiler generates a
private delegate field plus `add` and `remove` accessors. You can write the
accessors yourself, like a property, when you need control over where
handlers are stored:[^eventpattern]

```csharp
internal event EventHandler<SearchDirectoryArgs> DirectoryChanged
{
    add { _directoryChanged += value; }
    remove { _directoryChanged -= value; }
}
private EventHandler<SearchDirectoryArgs>? _directoryChanged;
```

### The standard pattern

.NET events follow one shape. The standard signature returns `void`, because
"listeners don't provide values in response to events"; its first parameter
is the `object` that raised the event; and the second is an `EventArgs`-derived
type that carries the details, or `EventArgs.Empty` when there are
none.[^eventpattern] `EventHandler<TEventArgs>` saves you from declaring a
delegate type per event. The design guidelines add the naming rules: name
events "with a verb or a verb phrase", use the present and past tense for
before and after (`Closing`, `Closed`) rather than "Before" or "After", call
the parameters `sender` and `e`, and give argument classes the `EventArgs`
suffix.[^naming]

Raise an event with `Tick?.Invoke(this, EventArgs.Empty)`. The C# reference
calls this raising the event "in a thread-safe manner using the `?.`
operator".[^eventkeyword] It works because of immutability: `?.` reads the
field once, and if another thread unsubscribes in the meantime it replaces the
field with a new delegate, but the one already read stays intact. Without that
single read, a check like `if (Tick != null) Tick(…)` can find a subscriber
on the check and `null` on the call.

### Subscriptions keep subscribers alive

Since a delegate stores its `Target`, subscribing an instance method to an
event gives the publisher a reference to the subscriber. If the publisher
lives longer than the subscriber should, the subscriber can't be collected.
The WPF documentation describes exactly this: attaching a handler "creates a
strong reference from the event source to the event listener", and unless the
handler is removed, "the object lifetime of the listener will be influenced by
the object lifetime of the source".[^weakevents]

{{< diagram src="event-leak.svg" caption="The publisher's event field holds a delegate, and the delegate's `Target` is the subscriber. While the publisher is reachable, so is every subscriber it has not been told to forget." >}}

The program subscribes a `Screen` holding a 1 MB buffer to a `Clock`, drops
every other reference to the screen, and forces a garbage collection:

```csharp
var clock = new Clock();
WeakReference weak = Subscribe(clock);   // creates a Screen, subscribes it, returns a weak reference
GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
Console.WriteLine($"subscriber alive while subscribed: {weak.IsAlive}");
Console.WriteLine($"handlers on Tick: {clock.HandlerCount}");
clock.RaiseTick();

clock.UnsubscribeAll();
GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
Console.WriteLine($"subscriber alive after unsubscribing: {weak.IsAlive}");
```

```txt
$ dotnet run -c Release -- events
subscriber alive while subscribed: True
handlers on Tick: 1
  Screen got a tick from Clock
subscriber alive after unsubscribing: False
```

Nothing in the program referenced the screen except the clock's delegate, and
that was enough to keep it, and its buffer, alive. Unsubscribe when the
subscriber's useful life ends, typically in `Dispose`. WPF and some libraries
offer *weak event* managers for cases where the subscriber can't know when to
unsubscribe.[^weakevents]

## Variance: methods don't have to match exactly

A method doesn't need exactly the delegate's signature. The specification's
compatibility rule requires an identity or implicit *reference* conversion
from each delegate parameter type to the method's parameter type, and from the
method's return type to the delegate's. As it says, "this definition of
compatibility allows covariance in return type and contravariance in parameter
types".[^specdelegates] In practice: a method may return something more
derived, and accept something less derived, than the delegate promises. This
is why one handler taking `EventArgs` can subscribe to events that pass
`KeyEventArgs` or `MouseEventArgs`.[^usingvariance]

Generic delegates go further. Since .NET Framework 4, type parameters can be
declared `out` (covariant, return positions only) or `in` (contravariant,
parameter positions only), and `Func`, `Action`, `Predicate`, `Comparison` and
`Converter` all use them, as in `Func<in T, out TResult>`. That allows a
*delegate* of one type to be assigned to a variable of another:[^variance]

```csharp
Func<string> makeText = () => "hello";
Func<object> makeObject = makeText;               // covariance: out TResult
Action<object> printAnything = o => Console.WriteLine($"  {o} ({o.GetType().Name})");
Action<string> printText = printAnything;         // contravariance: in T

Console.WriteLine($"makeObject() returned \"{makeObject()}\"");
printText("a string");
Console.WriteLine($"same instance? {ReferenceEquals(makeText, makeObject)}");

Func<object, string> describe = Maths.Describe;   // Describe(object) returns string
Console.WriteLine(describe(42));
```

```txt
$ dotnet run -c Release -- variance
makeObject() returned "hello"
  a string (String)
same instance? True
described 42 as Int32
```

The variant conversion is a reference conversion: `makeObject` *is*
`makeText`, viewed through a different type. Two limits apply, and both show
up as compile errors:

```csharp
Func<int> makeNumber = () => 42;
Func<object> boxed = makeNumber;          // int is a value type

delegate T Maker<T>();                    // no 'out' on T
Maker<string> makeText = () => "hello";
Maker<object> makeObject = makeText;
```

```txt
$ dotnet build
error CS0029: Cannot implicitly convert type 'System.Func<int>' to 'System.Func<object>'
error CS0029: Cannot implicitly convert type 'Maker<string>' to 'Maker<object>'
```

"Variance for generic type parameters is supported for reference types only",
because converting an `int` to `object` needs boxing, not a reference
conversion. And variance has to be declared: `Maker<T>` would work with `out
T`.[^variance] One more caveat from the same page: "Don't combine variant
delegates". `Delegate.Combine` "expects delegates to be of exactly the same
type", so `actStr += actObj`, adding an `Action<object>` to an
`Action<string>`, compiles and then throws at run time.[^variance]

## Closures: what a lambda captures

A lambda can use local variables of the method around it. It captures the
*variable*, not its value at the time: "the lambda expression stores them for
use even if the variables go out of scope", and "a variable that you capture
isn't garbage collected until the delegate that references it becomes eligible
for garbage collection".[^lambdas] The current compiler does this by moving
captured variables into a hidden class and making the lambda an instance
method on it. The names are compiler implementation details, but the effect is
visible through `Target`:

```csharp
int factor = 3;
Func<int, int> capturing = x => x * factor;
Func<int, int> nonCapturing = x => x * 2;
Func<int, int> staticLambda = static x => x * 2;
Console.WriteLine($"capturing.Target:    {capturing.Target!.GetType().Name}");
Console.WriteLine($"nonCapturing.Target: {nonCapturing.Target!.GetType().Name}");
Console.WriteLine($"staticLambda.Target: {staticLambda.Target!.GetType().Name}");
factor = 10;
Console.WriteLine($"capturing(2) after factor = 10: {capturing(2)}");
Console.WriteLine($"capturing.Method:    {capturing.Method.Name}");
```

```txt
$ dotnet run -c Release -- targets
capturing.Target:    <>c__DisplayClass0_3
nonCapturing.Target: <>c
staticLambda.Target: <>c
capturing(2) after factor = 10: 20
capturing.Method:    <<Main>$>b__35
```

The capturing lambda's target is a closure object holding `factor`, and
changing `factor` after the lambda was created changed its result: 2 × 10 is 20,
not 6. The lambda itself became a method with a generated name. In this build,
the lambdas that capture nothing became methods on one shared helper object,
`<>c`, so they allocate no closure.

### The for loop trap

Capturing variables rather than values is what makes loops surprising.

{{< diagram src="closures.svg" caption="A `for` loop has one loop variable, shared by every lambda created in it. Since C# 5, a `foreach` loop has a fresh variable per iteration." >}}

```csharp
var fromFor = new List<Func<int>>();
for (int i = 0; i < 3; i++)
    fromFor.Add(() => i);

var fromForeach = new List<Func<int>>();
foreach (int i in new[] { 0, 1, 2 })
    fromForeach.Add(() => i);

var fromCopy = new List<Func<int>>();
for (int i = 0; i < 3; i++)
{
    int copy = i;
    fromCopy.Add(() => copy);
}
```

```txt
$ dotnet run -c Release -- closures
for:            3, 3, 3
foreach:        0, 1, 2
for with copy:  0, 1, 2
```

The `for` loop declares `i` once, so all three lambdas share it, and by the
time they run it holds 3, the value that ended the loop. Copying it into a
variable declared *inside* the body gives each iteration its own. `foreach`
used to behave like `for`, and it was a famous source of bugs. C# 5 changed
it, a deliberate breaking change: Eric Lippert announced that "the loop
variable of a foreach will be logically inside the loop, and therefore
closures will close over a fresh copy of the variable each time", and that
"the for loop will not be changed".[^lippert][^langhistory] The trap now
applies to `for` and `while` loops only.

### Static lambdas and cached delegates

C# 9 added `static` lambdas and anonymous methods, to "ensure that anonymous
functions don't capture `this` or local variables".[^langhistory] A static
lambda "can't capture local variables or instance state from enclosing scopes,
but it can reference static members and constant definitions".[^lambdas] Its
use is to make an accidental capture, and the closure object that comes with
it, a compile error:

```csharp
int factor = 3;
Func<int, int> triple = static x => x * factor;
```

```txt
$ dotnet build
error CS8820: A static anonymous function cannot contain a reference to 'factor'.
```

The compiler also reuses delegate objects where it can. The specification
permits a method group conversion to "use an existing delegate instance that
already contains these references", and lets identical non-capturing lambdas
"return the same delegate instance".[^specconversions] Since C# 11, listed as
"Improved method group conversion to delegate", the compiler does this for
static method groups: "When you assign the method group to a delegate, the
compiler caches the delegate."[^history][^delegateop]

```csharp
Action fromMethodGroup1 = Maths.Hello;
Action fromMethodGroup2 = Maths.Hello;
Console.WriteLine($"two delegates to Maths.Hello equal? {fromMethodGroup1 == fromMethodGroup2}, same object? {ReferenceEquals(fromMethodGroup1, fromMethodGroup2)}");
```

The same `remove` run printed:

```txt
two delegates to Maths.Hello equal? True, same object? True
```

Equality doesn't depend on that cache: two delegates are equal when their
targets and methods match. Allocation does. A lambda that captures a local
variable allocates a closure object and a delegate each time the enclosing
code runs, which matters only in hot loops, and is the reason function
pointers exist.

## Delegates or interfaces?

Both let a caller plug behaviour into code it doesn't own. The difference is
how much they carry.

- **Use a delegate** when the caller needs to provide *one operation*: a
  comparison, a filter, a callback, a factory. A lambda at the call site is
  shorter than a class that implements an interface, and `Func` and `Action`
  need no declaration at all.
- **Use an interface** when the behaviour is a *role* with several members
  that belong together, has state of its own, or should be registered and
  resolved by name, for example through a dependency injection container. An
  `IComparer<T>` can be configured and reused; a `Comparison<T>` is just the
  comparing.
- **Use an event** when there can be zero, one or many listeners and the
  publisher doesn't care which.

The base library often offers both, as `List<T>.Sort` does: an overload that
takes `IComparer<T>` and one that takes `Comparison<T>`.

## Delegates and expression trees

A lambda can become one of two very different things, depending on the type
it is converted to:

```csharp
Func<int, bool> asCode = x => x > 2 && x % 2 == 0;
Expression<Func<int, bool>> asData = x => x > 2 && x % 2 == 0;
```

```txt
$ dotnet run -c Release -- expressions
Func:       System.Func`2[System.Int32,System.Boolean]
Expression: x => ((x > 2) AndAlso ((x % 2) == 0))
Body node:  AndAlso
Left:       (x > 2) (GreaterThan)
Right:      ((x % 2) == 0) (Equal)
Compiled(4) = True, asCode(4) = True
```

The `Func` is compiled code; all you can do with it is call it. The
`Expression<Func<…>>` is a data structure, "a tree-like data structure, where
each node is an expression", which a library can walk, rewrite or translate,
and which `Compile()` turns into a delegate when you do want to run
it.[^expressiontrees] That is how Entity Framework turns
`Where(u => u.IsActive)` into SQL: `Queryable.Where` takes an expression tree,
while `Enumerable.Where` takes a `Func`, and the same lambda fits
both.[^lambdas] Expression trees have limits: the compiler "can't parse
statement lambdas", and they can't contain `await`, `?.`, pattern matching and
many other newer features.[^expressiontrees]

## Function pointers

C# 9 added *function pointers*, `delegate*`, for code that needs a reference
to a method without the cost of a delegate. "Invoking a delegate involves
instantiating a type derived from `System.Delegate` and making a virtual method
call to its `Invoke` method", while for a function pointer "the compiler calls
the function by using the `calli` instruction rather than instantiating a
`delegate` object".[^unsafe]

```csharp
unsafe
{
    delegate*<int, int> square = &Square;
    Console.WriteLine($"square(7) = {square(7)}");
}

static int Square(int x) => x * x;
```

```txt
$ dotnet run
square(7) = 49
```

The price is everything that makes delegates convenient. Function pointers
need an `unsafe` context and the `AllowUnsafeBlocks` option, the `&` operator
works only on static methods, and there is no target, no invocation list, no
closure and no variance.[^unsafe] They exist mainly for interop, where the
`unmanaged` calling conventions let C# call native function pointers, and for
the hottest code paths of runtime libraries.

## A short history

| Version | Released | What it added |
|---|---|---|
| C# 1.0 | January 2002 | Delegates and events |
| C# 2.0 | November 2005 | Anonymous methods, method group conversions, delegate covariance and contravariance |
| C# 3.0 | November 2007 | Lambda expressions and expression trees, the foundation of LINQ |
| C# 4.0 | April 2010 | Generic variance (`in` and `out`), used by `Func` and `Action` from .NET Framework 4 |
| C# 5.0 | August 2012 | `foreach` declares a fresh loop variable per iteration |
| C# 9 | November 2020 | Static anonymous functions and function pointers |
| C# 10 | November 2021 | Natural types for lambdas and method groups, explicit return types, attributes on lambdas |
| C# 11 | November 2022 | Improved method group conversion: cached delegates for static methods |
| C# 12 | November 2023 | Default parameter values in lambdas |

Release dates and features come from the official C# history and the
`csharplang` version history.[^history][^langhistory][^variance] The design
goals behind the original delegate types are spelled out in the C# guide:
type safety, performance, and simplicity in a .NET 1.0 that had no generics,
which is why every signature needed its own compiler-generated
class.[^delegateclass] Generics, and then `Func` and `Action`, removed most of
that ceremony, and lambdas removed the rest.

## Common misunderstandings

| Misunderstanding | What is actually true |
|---|---|
| "A delegate is a function pointer." | It is an object: a class instance with a target, a method and an invocation list. `delegate*` is the actual function pointer. |
| "`+=` adds a method to the delegate." | Delegates are immutable. `+=` builds a new delegate and assigns it to the variable. |
| "A multicast delegate returns all the results." | It returns only the last method's result; the others are discarded. |
| "If one handler throws, the others still run." | The exception stops the invocation. Use `GetInvocationList()` and call each entry to isolate them. |
| "`-=` with the same lambda unsubscribes it." | A second lambda is a different delegate. Keep the handler in a variable to remove it. |
| "An event is just a public delegate field." | Outside the declaring type, an event allows only `+=` and `-=`, not even from derived classes. |
| "Subscribing to an event doesn't affect the subscriber's lifetime." | The publisher holds the subscriber through the delegate's `Target` until it unsubscribes. |
| "Lambdas capture the value of a variable." | They capture the variable. Later changes are visible, and a `for` loop variable is shared by every iteration. |
| "`Func<int>` converts to `Func<object>` like `Func<string>` does." | Variance works for reference types only. |
| "`Func<T, bool>` and `Expression<Func<T, bool>>` are the same thing." | One is compiled code; the other is a tree a library can inspect and translate, which is how LINQ providers produce SQL. |

## References

[^specdelegates]: ECMA International and Microsoft. (2026). Delegates. In *C# language specification* (chapter 21). Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/delegates>

[^delegateclass]: Microsoft. (n.d.). *System.Delegate and the `delegate` keyword*. C# guide, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/delegate-class>

[^target]: Microsoft. (n.d.). *Delegate.Target property*. .NET API reference, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/api/system.delegate.target>

[^lambdas]: Microsoft. (2026). *Lambda expressions and anonymous functions*. C# language reference, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/lambda-expressions>

[^delegateop]: Microsoft. (2026). *delegate operator*. C# language reference, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/delegate-operator>

[^history]: Microsoft. (2025). *The history of C#*. Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-version-history>

[^getinvocationlist]: Microsoft. (n.d.). *MulticastDelegate.GetInvocationList method*. .NET API reference, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/api/system.multicastdelegate.getinvocationlist>

[^eventpattern]: Microsoft. (2025). *Standard .NET event patterns*. C# guide, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/event-pattern>

[^eventkeyword]: Microsoft. (2026). *The `event` keyword*. C# language reference, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/event>

[^naming]: Cwalina, K., & Abrams, B. (2008). Names of type members. In *Framework Design Guidelines* (2nd ed.). Reprinted on Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/standard/design-guidelines/names-of-type-members>

[^weakevents]: Microsoft. (2024). *Weak event patterns*. WPF documentation, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/desktop/wpf/events/weak-event-patterns>

[^usingvariance]: Microsoft. (n.d.). *Using variance in delegates*. C# guide, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/covariance-contravariance/using-variance-in-delegates>

[^variance]: Microsoft. (n.d.). *Variance in delegates*. C# guide, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/covariance-contravariance/variance-in-delegates>

[^lippert]: Lippert, E. (2009, November 12). *Closing over the loop variable considered harmful, part one* [Updated with the C# 5 decision]. Fabulous Adventures in Coding. <https://ericlippert.com/2009/11/12/closing-over-the-loop-variable-considered-harmful-part-one/>

[^langhistory]: .NET Foundation. (n.d.). *C# language version history*. dotnet/csharplang repository, GitHub. <https://github.com/dotnet/csharplang/blob/main/Language-Version-History.md>

[^specconversions]: ECMA International and Microsoft. (2026). Conversions: anonymous function conversions and method group conversions. In *C# language specification* (chapter 10). Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/conversions>

[^expressiontrees]: Microsoft. (2025). *Expression trees*. C# guide, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/expression-trees/>

[^unsafe]: Microsoft. (2026). *Unsafe code, pointers to data, and function pointers*. C# language reference, Microsoft Learn. <https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/unsafe-code>
