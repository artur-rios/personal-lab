---
title: "The .NET Libraries I Reach For"
description: "The eight libraries I add to my own .NET projects, and why: xUnit.net for tests, Bogus for test data, Moq and Moq.AutoMocker for mocks, ClosedXML for Excel files, FluentValidation for validation, Polly for resilience and TickerQ for background jobs. For each one: what it solves, a real example, when to pick something else, and the facts a fair recommendation has to disclose, from Moq's SponsorLink episode to TickerQ's licence change."
date: 2026-10-21T13:20:00Z
categories: [".NET"]
tags: [".NET", "C#", "Libraries", "NuGet", "Testing", "xUnit", "Moq", "Bogus", "FluentValidation", "Polly", "ClosedXML", "TickerQ"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Every new .NET project starts with the same handful of decisions. How will I
test it? Where does fake data come from? How do I validate input, survive a
flaky dependency, export a spreadsheet, run something every night? The base
class library answers some of these. For the rest, I have settled on a short
list of NuGet packages that I add almost without thinking.

This page is that list, with the reasoning written down. For each library I
explain what it is for, why I use it, show a small example and say when I
would pick something else. A recommendation is only as good as what it
leaves out, so I also flag what I would want to know before adding a
dependency: licence, maintenance, breaking changes, and in two cases events
that every user of the library should know about.

Package versions, licences and target frameworks were checked on nuget.org
and in the project repositories on 21 October 2026. Every example was
compiled and run with the .NET 10 SDK (10.0.400); the output shown is from
those runs, with long paths shortened to `…`.

## How I choose

The criteria are simple, and every library below meets them, with one caveat
for TickerQ:

- **It solves one problem well**, and its name tells you which.
- **It is actively maintained**: recent releases, current target frameworks.
- **Its licence lets me use it anywhere**, including commercial work, without
  a separate agreement.
- **Its API reads like the problem**, so the code that uses it is easy to
  review.

{{< diagram src="where-they-fit.svg" caption="Four libraries live in the application, at its edges: what comes in, what goes out, what runs later and what is exported. Four live in the test project." >}}

## Testing: xUnit.net

xUnit.net "is a free, open source, community-focused unit testing tool for
C#, F#, and Visual Basic".[^xunit] It is the test framework I use in every
project: tests are plain methods marked `[Fact]` (one case) or `[Theory]`
(the same test over several inputs). "xUnit.net creates a new instance of
the test class for every test that is run",[^xunitcontext] so tests cannot
leak state into each other through fields.

**Why I use it.** It has very little ceremony, and every tool in the
ecosystem, from IDE test explorers to coverage collectors, supports it.

**Use v3 for new projects.** xUnit.net v3 is a different set of packages, not
an update of the old ones: "Most of the packages for v3 Core Framework have
moved to new names that start with `xunit.v3`." Test projects are now
programs in their own right: "Test projects in v3 are stand-alone
executables now, capable of running themselves", so the project's
`OutputType` becomes `Exe`.[^xunitmigration] v3 "supports .NET 8.0 or later,
and .NET Framework 4.7.2 or later".[^xunit] The old `xunit` package still
exists, but its latest version, 2.9.3, dates from January 2025, while
`xunit.v3` reached 4.0.2 in October 2026.[^nugetxunit] The quickest start is
the official template:

```bash
dotnet new install xunit.v3.templates
dotnet new xunit3 -n Shop.Tests
```

The template targets `net8.0`; I changed it to `net10.0`. The tests further
down run under it, either with `dotnet test` or by running the test project
directly:

```txt
$ dotnet test
Running tests from …\Shop.Tests\bin\Debug\net10.0\Shop.Tests.dll (net10.0|x64)
…\Shop.Tests\bin\Debug\net10.0\Shop.Tests.dll (net10.0|x64) passed (2s 468ms)

Test run summary: Passed!
  total: 4
  failed: 0
  succeeded: 4
  skipped: 0
  duration: 3s 177ms
```

| Package | Version | Licence | Maintainers | Targets |
|---|---|---|---|---|
| `xunit.v3` | 4.0.2 | Apache-2.0 | Brad Wilson, James Newkirk | .NET 8+, .NET Framework 4.7.2+ |

**Alternatives.** NUnit and MSTest (Microsoft's own)
are both mature and fully supported; the choice between the three is mostly
taste. I prefer xUnit's instance-per-test model and its smaller API.

## Test data: Bogus

Bogus is "a simple fake data generator for C#, F#, and VB.NET. Based on and
ported from the famed faker.js."[^bogus] It fills objects with believable
names, emails, addresses, amounts and dates, from dozens of data sets in many
locales.

**Why I use it.** Tests full of `"test"`, `"a@b.c"` and `1` are hard to read,
and they hide bugs that only show with real-looking data: long names, unusual
emails, amounts with cents. A `Faker<T>` describes how to build a valid
object once, and every test gets fresh ones from it. Seeding makes it
deterministic: `Faker<T>.UseSeed(int)` gives that generator its own seed, and
the README recommends this for unit tests, because changes elsewhere then
have less effect on its output.[^bogus]

The examples in this section and the next two share one small domain: an
`Order`, a validator for it and an `OrderService` with three dependencies.

```csharp
public record Order(string Customer, string Email, decimal Total, int Items);

public interface IPaymentGateway { Task<bool> ChargeAsync(string email, decimal amount); }
public interface IOrderRepository { Task SaveAsync(Order order); }
public interface INotifier { Task SendReceiptAsync(string email); }

public class OrderService(IPaymentGateway payments, IOrderRepository orders, INotifier notifier)
{
    public async Task<bool> PlaceAsync(Order order)
    {
        if (!await payments.ChargeAsync(order.Email, order.Total))
            return false;

        await orders.SaveAsync(order);
        await notifier.SendReceiptAsync(order.Email);
        return true;
    }
}
```

The test class builds its orders with Bogus:

```csharp
public class OrderTests(ITestOutputHelper output)
{
    private static readonly Faker<Order> Orders = new Faker<Order>()
        .UseSeed(42)
        .CustomInstantiator(f => new Order(
            f.Name.FullName(),
            f.Internet.Email(),
            f.Finance.Amount(5, 500),
            f.Random.Int(1, 10)));

    [Fact]
    public void Bogus_generates_believable_orders()
    {
        foreach (var order in Orders.Generate(3))
            output.WriteLine(order.ToString());
    }
}
```

`CustomInstantiator` is how Bogus builds a type with a constructor, such as a
positional record; for classes with settable properties, `RuleFor` sets one
property at a time. Running the test project directly with
`-showLiveOutput` prints what the test wrote:

```txt
$ ./bin/Debug/net10.0/Shop.Tests.exe -showLiveOutput
…
    OrderTests.Bogus_generates_believable_orders [OUTPUT] Order { Customer = Noemy Feest, Email = Joaquin.Hammes@gmail.com, Total = 261.14, Items = 1 }
    OrderTests.Bogus_generates_believable_orders [OUTPUT] Order { Customer = Rashad Mayert, Email = Camylle_Borer53@yahoo.com, Total = 26.85, Items = 8 }
    OrderTests.Bogus_generates_believable_orders [OUTPUT] Order { Customer = Caleb Ullrich, Email = Jorge30@hotmail.com, Total = 293.66, Items = 9 }
```

With the seed fixed, every run produces these same three orders.

| Package | Version | Licence | Maintainer | Targets |
|---|---|---|---|---|
| `Bogus` | 35.6.5 | MIT | Brian Chavez | .NET Standard 1.3+, .NET Framework 4.0+ |

**Alternatives.** AutoFixture (MIT) fills objects with anonymous values
rather than realistic ones, and can create whole object graphs with no setup.
I prefer Bogus's readable output; AutoFixture is better when you do not care
what the values are.

## Mocking: Moq

Moq calls itself "the most popular and friendly mocking framework for
.NET".[^moq] A mock stands in for a dependency, so a test can decide what it
returns and check how it was called, without a real payment gateway or
database.

**Why I use it.** Setups and checks are written as lambdas against the real
interface, so they are type-checked and survive renames. The example tests
the unhappy path: when the payment is declined, nothing is saved.

```csharp
[Fact]
public async Task Declined_payment_saves_nothing()
{
    var payments = new Mock<IPaymentGateway>();
    payments.Setup(p => p.ChargeAsync(It.IsAny<string>(), It.IsAny<decimal>()))
            .ReturnsAsync(false);
    var orders = new Mock<IOrderRepository>();
    var service = new OrderService(payments.Object, orders.Object, Mock.Of<INotifier>());

    var placed = await service.PlaceAsync(Orders.Generate());

    Assert.False(placed);
    orders.Verify(r => r.SaveAsync(It.IsAny<Order>()), Times.Never);
}
```

`Setup` decides what the mock returns, `Mock.Of<T>()` creates one that does
nothing, and `Verify` fails the test if the call did or did not happen as
stated.

**The SponsorLink episode, which you should know about.** In August 2023,
Moq 4.20.0 shipped with SponsorLink, a closed-source component by Moq's
author. Issue #1372, "Privacy issues with SponsorLink,
starting from version 4.20", opened on 8 August 2023, reported that a .NET
analyzer "runs during the build" and sends "the hashed email of the current
developer to a cloud service", with "no option to disable this".[^moq1372]
Release 4.20.69, published on 11 August 2023, lists "Removed SponsorLink"
first under its changes.[^moq42069] On nuget.org, versions 4.20.0 to 4.20.2
are now unlisted, and the current version is 4.21.0.[^nugetmoq] I still use
Moq: the problem was fixed within days, and the
library itself is mature and well known. But it is a fair reason to prefer
an alternative, and if your organisation pins dependency versions, check that
nothing still references 4.20.0 to 4.20.2.

| Package | Version | Licence | Maintainer | Targets |
|---|---|---|---|---|
| `Moq` | 4.21.0 | BSD-3-Clause | Daniel Cazzulino (kzu) | .NET Standard 2.0+, .NET Framework 4.6.2+ |

**Alternatives.** NSubstitute is the main one. Its
syntax treats the substitute as if it were the real object, with no `.Object`
and no `Setup`, which some people find easier to read.

## Mocking without the wiring: Moq.AutoMocker

Moq.AutoMocker is "an auto-mocking IoC container for Moq".[^automocker]
`CreateInstance<T>()` builds the class under test and fills every
constructor parameter with a mock; `GetMock<T>()` gives you the mock for one
dependency so you can set it up or verify it.

**Why I use it.** Without it, every test creates a mock for every
constructor parameter, including the ones it does not care about, and adding
a parameter to the constructor breaks every test that builds the class. The
README puts the case plainly: use it if you want "to decouple your unit tests
from changes to their constructor arguments".[^automocker] The happy path,
with no hand-built mocks at all:

```csharp
[Fact]
public async Task Accepted_payment_saves_and_sends_a_receipt()
{
    var mocker = new AutoMocker();
    mocker.GetMock<IPaymentGateway>()
          .Setup(p => p.ChargeAsync(It.IsAny<string>(), It.IsAny<decimal>()))
          .ReturnsAsync(true);
    var service = mocker.CreateInstance<OrderService>();
    var order = Orders.Generate();

    Assert.True(await service.PlaceAsync(order));

    mocker.Verify<IOrderRepository>(r => r.SaveAsync(order), Times.Once());
    mocker.Verify<INotifier>(n => n.SendReceiptAsync(order.Email), Times.Once());
}
```

The NuGet package is called `Moq.AutoMock`, not `Moq.AutoMocker` like the
repository and the class, which trips up a first `dotnet add package`.

| Package | Version | Licence | Maintainers | Targets |
|---|---|---|---|---|
| `Moq.AutoMock` | 4.0.3 | MIT | Tim Kellogg, Adam Hewitt, Kevin Bost | .NET Standard 2.0 |

**When not to use it.** If a class needs so many dependencies that wiring
mocks by hand is painful, that is worth hearing too: the class may be doing
too much. AutoMocker removes the pain; it should not remove the signal. For
NSubstitute users, AutoFixture's `AutoNSubstitute` package plays the same
role.

## Excel files: ClosedXML

"ClosedXML is a .NET library for reading, manipulating and writing Excel
2007+ (.xlsx, .xlsm) files." It sits on top of Microsoft's Open XML SDK and
"aims to provide an intuitive and user-friendly interface to dealing with the
underlying OpenXML API".[^closedxml]

**Why I use it.** Sooner or later every business application exports a
report to Excel or imports a spreadsheet someone filled in. The Open XML SDK
can do it, but at the level of XML parts and shared-string tables. ClosedXML
works in cells, ranges, styles and formulas, needs no Excel installed, and is
MIT-licensed. This program writes a small report with formulas and
formatting, then reads it back:

```csharp
using ClosedXML.Excel;

using (var workbook = new XLWorkbook())
{
    var sheet = workbook.Worksheets.Add("Sales");
    sheet.Cell("A1").Value = "Product";
    sheet.Cell("B1").Value = "Units";
    sheet.Cell("C1").Value = "Price";
    sheet.Cell("D1").Value = "Revenue";

    var rows = new (string Product, int Units, double Price)[]
    {
        ("Keyboard", 12, 49.90),
        ("Mouse", 30, 19.50),
        ("Monitor", 4, 219.00),
    };
    for (var i = 0; i < rows.Length; i++)
    {
        var r = i + 2;
        sheet.Cell(r, 1).Value = rows[i].Product;
        sheet.Cell(r, 2).Value = rows[i].Units;
        sheet.Cell(r, 3).Value = rows[i].Price;
        sheet.Cell(r, 4).FormulaA1 = $"B{r}*C{r}";
    }
    sheet.Cell("D5").FormulaA1 = "SUM(D2:D4)";

    sheet.Row(1).Style.Font.Bold = true;
    sheet.Range("C2:D5").Style.NumberFormat.Format = "#,##0.00";
    sheet.Columns().AdjustToContents();
    workbook.SaveAs("sales.xlsx");
}

using (var workbook = new XLWorkbook("sales.xlsx"))
{
    var sheet = workbook.Worksheet("Sales");
    foreach (var row in sheet.Range("A2:D4").Rows())
        Console.WriteLine($"{row.Cell(1).GetString(),-10} {row.Cell(4).GetDouble(),8:F2}");
    Console.WriteLine($"Total revenue: {sheet.Cell("D5").GetDouble():F2}");
}
```

```txt
$ dotnet run
Keyboard     598.80
Mouse        585.00
Monitor      876.00
Total revenue: 2059.80
```

The revenue column and the total are formulas, not values the program
wrote: ClosedXML evaluated them when reading the file back.

**What to watch out for.** The README is candid: "ClosedXML is not
thread-safe", and "the public API is still not stable", so read the release
notes before upgrading. Memory grows with file size; its own benchmark loads
a 1,000,000-row text-only workbook in about 49 seconds using about
801 MiB.[^closedxml] For very large exports, write CSV or stream with the Open
XML SDK instead.

| Package | Version | Licence | Maintainers | Targets |
|---|---|---|---|---|
| `ClosedXML` | 0.105.1 | MIT | Jan Havlíček and others | .NET Standard 2.0 |

**Alternatives.** EPPlus is the best-known one, with features ClosedXML
lacks, but since version 5 it is published under the Polyform Noncommercial
licence, and "usage of EPPlus in a commercial environment requires a
commercial license".[^epplus] The Open XML SDK itself is free and fast, but
low-level.

## Validation: FluentValidation

"FluentValidation is a .NET library for building strongly-typed validation
rules."[^fluentvalidation] Rules for a type live in one class that derives
from `AbstractValidator<T>`, written as readable chains:

```csharp
public class OrderValidator : AbstractValidator<Order>
{
    public OrderValidator()
    {
        RuleFor(o => o.Customer).NotEmpty();
        RuleFor(o => o.Email).NotEmpty().EmailAddress();
        RuleFor(o => o.Items).GreaterThan(0);
        RuleFor(o => o.Total).GreaterThan(0).WithMessage("An order must cost something");
    }
}
```

**Why I use it.** Data annotations (`[Required]`, `[Range]`) put validation on
the model and run out of road quickly: rules that depend on other properties,
on a database lookup or on the current user end up somewhere else. A
validator keeps every rule for a type in one class, can take dependencies
through its constructor, and is easy to test. The library even ships a test
helper:

```csharp
[Fact]
public void Validator_rejects_an_empty_order()
{
    var result = new OrderValidator().TestValidate(new Order("", "not-an-email", 0, 0));

    result.ShouldHaveValidationErrorFor(o => o.Email);
    result.ShouldHaveValidationErrorFor(o => o.Total)
          .WithErrorMessage("An order must cost something");
    foreach (var error in result.Errors)
        output.WriteLine($"{error.PropertyName}: {error.ErrorMessage}");
}
```

```txt
$ ./bin/Debug/net10.0/Shop.Tests.exe -showLiveOutput
…
    OrderTests.Validator_rejects_an_empty_order [OUTPUT] Customer: 'Customer' must not be empty.
    OrderTests.Validator_rejects_an_empty_order [OUTPUT] Email: 'Email' is not a valid email address.
    OrderTests.Validator_rejects_an_empty_order [OUTPUT] Items: 'Items' must be greater than '0'.
    OrderTests.Validator_rejects_an_empty_order [OUTPUT] Total: An order must cost something
```

**Two things to know.** First, version 12 "supports .NET 8 and newer
(including .NET 10)"; projects on older runtimes stay on version
11.[^fluentvalidation] Second, the old ASP.NET Core integration that
validated models automatically is on its way out: "We no longer recommend
using this approach for new projects but it is still available for legacy
implementations." The recommended way is to inject `IValidator<T>` and call
it yourself, which the documentation calls "the most straightforward
approach".[^fluentvalidationaspnet]

| Package | Version | Licence | Maintainer | Targets |
|---|---|---|---|---|
| `FluentValidation` | 12.2.0 | Apache-2.0 | Jeremy Skinner | .NET 8+ |

**When not to use it.** For a small API whose models need only "required"
and "max length", data annotations are built in and enough.

## Resilience: Polly

"Polly is a powerful library for .NET that helps you handle transient faults
and improve the resilience of your applications."[^polly] It packages six
strategies: retry, circuit breaker, timeout, rate limiter, fallback and
hedging. You combine them into a *resilience pipeline* and run your calls
through it.

**Why I use it.** Networks fail, services restart, databases time out. Retry
loops with `Thread.Sleep` written by hand get the details wrong: no backoff,
retrying errors that will never succeed, retrying forever. Polly gets them
right, and the options read like a policy document. This program runs a call
that fails twice before succeeding through a retry pipeline, then shows a
circuit breaker opening:

```csharp
using System.Diagnostics;
using Polly;
using Polly.CircuitBreaker;
using Polly.Retry;

var clock = Stopwatch.StartNew();
void Log(string message) => Console.WriteLine($"[{clock.ElapsedMilliseconds,5} ms] {message}");

// A dependency that fails twice, then recovers.
var calls = 0;
async ValueTask<string> FlakyCall(CancellationToken token)
{
    calls++;
    await Task.Delay(10, token);
    if (calls <= 2) throw new HttpRequestException($"503 on call {calls}");
    return $"200 OK on call {calls}";
}

// Retry: three attempts with exponential backoff, only for HTTP failures.
var retry = new ResiliencePipelineBuilder()
    .AddRetry(new RetryStrategyOptions
    {
        ShouldHandle = new PredicateBuilder().Handle<HttpRequestException>(),
        MaxRetryAttempts = 3,
        BackoffType = DelayBackoffType.Exponential,
        Delay = TimeSpan.FromMilliseconds(200),
        OnRetry = args =>
        {
            Log($"retry {args.AttemptNumber + 1} in {args.RetryDelay.TotalMilliseconds} ms after: {args.Outcome.Exception!.Message}");
            return default;
        }
    })
    .AddTimeout(TimeSpan.FromSeconds(2))
    .Build();

Log(await retry.ExecuteAsync(FlakyCall));

// Circuit breaker: after enough failures, stop calling for a while.
var breaker = new ResiliencePipelineBuilder()
    .AddCircuitBreaker(new CircuitBreakerStrategyOptions
    {
        FailureRatio = 0.5,
        MinimumThroughput = 3,
        SamplingDuration = TimeSpan.FromSeconds(10),
        BreakDuration = TimeSpan.FromSeconds(5),
        OnOpened = args => { Log($"circuit opened for {args.BreakDuration.TotalSeconds} s"); return default; }
    })
    .Build();

for (var i = 1; i <= 5; i++)
{
    try
    {
        breaker.Execute(() => throw new HttpRequestException("503"));
    }
    catch (BrokenCircuitException)
    {
        Log($"call {i}: rejected without calling the service");
    }
    catch (HttpRequestException)
    {
        Log($"call {i}: failed");
    }
}
```

```txt
$ dotnet run
[   47 ms] retry 1 in 200 ms after: 503 on call 1
[  275 ms] retry 2 in 400 ms after: 503 on call 2
[  694 ms] 200 OK on call 3
[  701 ms] call 1: failed
[  701 ms] call 2: failed
[  702 ms] circuit opened for 5 s
[  702 ms] call 3: failed
[  702 ms] call 4: rejected without calling the service
[  702 ms] call 5: rejected without calling the service
```

The retry waited 200 ms, then 400 ms, and the third call succeeded. The
breaker let three calls fail, saw a failure ratio above 50 %, opened, and
then rejected calls 4 and 5 immediately, without touching the failing
service. That is the point of a circuit breaker: a dependency that is down
gets time to recover instead of a flood of retries.

**Use the v8 API.** Polly 8 replaced v7's *policies* with resilience
*strategies*, combined in a pipeline that "combines one or more resilience
strategies". The v7 API "is still available and fully supported even when
using the v8 version by referencing the Polly package", but the migration
guide calls it legacy; new code should use the `Polly.Core` package and the
`ResiliencePipelineBuilder` shown above.[^pollymigration] Many older examples
use v7's `Policy.Handle<T>().WaitAndRetryAsync(...)`; that is a
sign of their age, not of the current API.

| Package | Version | Licence | Maintainer | Targets |
|---|---|---|---|---|
| `Polly.Core` | 8.8.0 | BSD-3-Clause | App vNext | .NET Standard 2.0+, .NET Framework 4.6.2+ |

**For `HttpClient`, start one level up.** Microsoft's
`Microsoft.Extensions.Http.Resilience` package "relies on the
`Microsoft.Extensions.Resilience` library and *Polly*". Its
`AddStandardResilienceHandler()` adds a ready-made pipeline to an
`HttpClient`: rate limiter, total timeout, retry, circuit breaker and
per-attempt timeout, with sensible defaults such as three retries with
exponential backoff and jitter.[^httpresilience] For HTTP calls I start
there, and use Polly directly for everything else: database calls, message
brokers, file shares.

## Scheduling: TickerQ

TickerQ describes itself as "a fast, reflection-free background task
scheduler for .NET built with source generators, EF Core integration, cron +
time-based execution, and a real-time dashboard".[^tickerqrepo] It "runs
inside your ASP.NET Core application or .NET worker service, using your
existing dependency injection".[^tickerq]

**Why I use it.** Jobs are ordinary methods marked `[TickerFunction]`, either
with a cron expression for recurring work or scheduled for a point in time
through `ITimeTickerManager`. Because a source generator finds them at
compile time, there is no reflection scanning at start-up. Storage is
pluggable: in-memory for development, which "does not retain jobs across
process restarts", or EF Core with SQL Server, PostgreSQL or SQLite, among
others.[^tickerq] This app needs no database at all:

```csharp
using TickerQ.DependencyInjection;
using TickerQ.Utilities.Base;
using TickerQ.Utilities.Entities;
using TickerQ.Utilities.Interfaces.Managers;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders().AddSimpleConsole(o => o.SingleLine = true);
builder.Services.AddTickerQ(); // in-memory storage: nothing to install for a demo
builder.Services.AddScoped<ReportJobs>();

var app = builder.Build();
app.UseTickerQ();

// Schedule a one-off job ("time ticker") a few seconds from now.
app.MapPost("/reports", async (ITimeTickerManager<TimeTickerEntity> tickers) =>
{
    var result = await tickers.AddAsync(new TimeTickerEntity
    {
        Function = "SendDailyReport",
        ExecutionTime = DateTime.UtcNow.AddSeconds(3),
    });
    return Results.Accepted(value: new { result.IsSucceeded });
});

app.Run();

public class ReportJobs(ILogger<ReportJobs> logger)
{
    // A one-off job, run when a time ticker for it comes due.
    [TickerFunction("SendDailyReport")]
    public Task SendDailyReport(TickerFunctionContext context, CancellationToken token)
    {
        logger.LogInformation("Sending report, scheduled for {Time:HH:mm:ss}", context.ScheduledFor);
        return Task.CompletedTask;
    }

    // A recurring job: the cron expression lives on the attribute.
    [TickerFunction("CleanUp", "*/1 * * * *")]
    public Task CleanUp(TickerFunctionContext context, CancellationToken token)
    {
        logger.LogInformation("Cleaning up, occurrence at {Time:HH:mm:ss}", context.ScheduledFor);
        return Task.CompletedTask;
    }
}
```

Started, then sent `POST /reports` at 13:25:51 UTC:

```txt
$ curl -X POST http://localhost:5099/reports
{"isSucceeded":true}
```

```txt
info: TickerQ.Utilities.Instrumentation.LoggerInstrumentation[0] TickerQ Job enqueued: timeticker - SendDailyReport (03f4c5cf-ebe5-4f25-b581-e464f2091714) from ExecutionTaskHandler
info: ReportJobs[0] Sending report, scheduled for 13:25:55
info: TickerQ.Utilities.Instrumentation.LoggerInstrumentation[0] TickerQ Job completed: SendDailyReport (03f4c5cf-ebe5-4f25-b581-e464f2091714) in 6ms - Success: True
info: TickerQ.Utilities.Instrumentation.LoggerInstrumentation[0] TickerQ Job enqueued: crontickeroccurrence - CleanUp (1121807d-42fd-47e7-9f3c-5e3d1041e81a) from ExecutionTaskHandler
info: ReportJobs[0] Cleaning up, occurrence at 13:26:00
info: TickerQ.Utilities.Instrumentation.LoggerInstrumentation[0] TickerQ Job completed: CleanUp (1121807d-42fd-47e7-9f3c-5e3d1041e81a) in 2ms - Success: True
```

The one-off job ran a few seconds after it was scheduled, and the cron job ran
at the next minute boundary.

{{< callout type="warning" title="Licence change" >}}
TickerQ is changing licence. The 5.x line, package versions 10.5.0, 9.5.0
and 8.5.0 onwards, is published under the commercial, source-available
TickerQ Software License Agreement, with a free Community tier for eligible
users, a 30-day evaluation and a paid subscription. Without a valid licence
certificate, jobs do not run. Earlier releases keep the MIT or Apache-2.0
licence they were published under. On 21 October 2026 the latest stable
version on nuget.org, 10.4.0, is still `MIT OR Apache-2.0`; that is the
version used here.
{{< /callout >}}

The details are in the project's own documents. The licensing page says that
"Commercial 5.x packages are distributed under the TickerQ Software License
Agreement", that "previously distributed MIT and/or Apache 2.0 artifacts
retain the terms included with those artifacts", and that "a public
repository or package download does not itself grant permission to operate
the software".[^tickerqlicensing] The repository's LICENSING.md names the
boundary: functional line 5.x, from 10.5.0 (.NET 10), 9.5.0 (.NET 9) and
8.5.0 (.NET 8), under an agreement dated 13 October 2026.[^tickerqlicensingmd]
The 5.x quick start also has you load a `tickerq.tqlicense` certificate with
`options.UseLicense(...)`.[^tickerqquickstart]

So my recommendation comes with a condition. TickerQ is the scheduler I
reach for first, but it is young, its first GitHub release, v2.0.0, is dated
20 April 2025,[^tickerqreleases] and from 10.5.0 it no longer meets my
"licence lets me use it anywhere" rule. I would pin 10.4.x for existing
projects, or check whether the Community tier covers your use before
upgrading.

| Package | Version | Licence | Maintainer | Targets |
|---|---|---|---|---|
| `TickerQ` | 10.4.0 | MIT OR Apache-2.0 (10.5.0+: commercial) | Albert Kunushevci (Arcenox) | .NET 10 (8.x and 9.x lines for older) |

**Alternatives.** Quartz.NET, an "open-source job scheduling system for
.NET", is Apache-2.0 and has been around for years.[^quartz] Hangfire
describes itself as "an easy way to perform background processing in .NET
and .NET Core applications"; it "is licensed under LGPLv3" and "completely
free for commercial use", with some features in paid Pro packages.[^hangfire]
For a single recurring task, a plain `BackgroundService` with a
`PeriodicTimer` needs no library at all.

## At a glance

| Need | Library | Package | Version | Licence |
|---|---|---|---|---|
| Unit tests | xUnit.net v3 | `xunit.v3` | 4.0.2 | Apache-2.0 |
| Test data | Bogus | `Bogus` | 35.6.5 | MIT |
| Mocks | Moq | `Moq` | 4.21.0 | BSD-3-Clause |
| Automatic mocks | Moq.AutoMocker | `Moq.AutoMock` | 4.0.3 | MIT |
| Excel files | ClosedXML | `ClosedXML` | 0.105.1 | MIT |
| Validation | FluentValidation | `FluentValidation` | 12.2.0 | Apache-2.0 |
| Resilience | Polly v8 | `Polly.Core` | 8.8.0 | BSD-3-Clause |
| Background jobs | TickerQ | `TickerQ` | 10.4.0 | MIT OR Apache-2.0; commercial from 10.5.0 |

## How I add them to a new project

The application project gets the four runtime libraries it needs; the test
project gets the four testing ones. Versions are the ones current on
21 October 2026.

```bash
# application
dotnet add package FluentValidation --version 12.2.0
dotnet add package Polly.Core --version 8.8.0
dotnet add package ClosedXML --version 0.105.1
dotnet add package TickerQ --version 10.4.0

# tests (from the xunit3 template, which already references xUnit.net)
dotnet add package Bogus --version 35.6.5
dotnet add package Moq --version 4.21.0
dotnet add package Moq.AutoMock --version 4.0.3
```

I pin versions on purpose. The two stories on this page, a mocking library
that briefly shipped a telemetry component and a scheduler that changed
licence, both reached people through an ordinary upgrade. A pinned version
and a quick read of the release notes before bumping it are cheap
insurance.

## References

[^xunit]: xUnit.net. (n.d.). *xUnit.net*. Retrieved October 21, 2026. <https://xunit.net/>

[^xunitcontext]: xUnit.net. (n.d.). *Sharing context between tests*. <https://xunit.net/docs/shared-context>

[^xunitmigration]: xUnit.net. (n.d.). *Migrating unit tests from v2 to v3*. <https://xunit.net/docs/getting-started/v3/migration>

[^nugetxunit]: NuGet Gallery. (2026). *xunit.v3* 4.0.2 (published October 9, 2026) and *xunit* 2.9.3 (published January 8, 2025). Retrieved October 21, 2026. <https://www.nuget.org/packages/xunit.v3>

[^bogus]: Chavez, B. (n.d.). *Bogus* [Repository]. GitHub. README. <https://github.com/bchavez/Bogus>

[^moq]: Cazzulino, D. (n.d.). *Moq* [Repository]. GitHub. README. <https://github.com/devlooped/moq>

[^moq1372]: Dangl, G. (2023, August 8). *Privacy issues with SponsorLink, starting from version 4.20* (Issue #1372). devlooped/moq, GitHub. <https://github.com/moq/moq/issues/1372>

[^moq42069]: Cazzulino, D. (2023, August 11). *v4.20.69* [Release notes]. devlooped/moq, GitHub. <https://github.com/moq/moq/releases/tag/v4.20.69>

[^nugetmoq]: NuGet Gallery. (2026). *Moq*: version history, with 4.20.0 to 4.20.2 unlisted and 4.21.0 published September 24, 2026. Retrieved October 21, 2026. <https://www.nuget.org/packages/Moq>

[^automocker]: Moq contributors. (n.d.). *Moq.AutoMocker* [Repository]. GitHub. README. <https://github.com/moq/Moq.AutoMocker>

[^closedxml]: ClosedXML contributors. (n.d.). *ClosedXML* [Repository]. GitHub. README. <https://github.com/ClosedXML/ClosedXML>

[^epplus]: EPPlus Software AB. (n.d.). *License overview*. <https://www.epplussoftware.com/en/LicenseOverview>

[^fluentvalidation]: Skinner, J. (n.d.). *FluentValidation documentation*. <https://docs.fluentvalidation.net/en/latest/>

[^fluentvalidationaspnet]: Skinner, J. (n.d.). *ASP.NET Core*. FluentValidation documentation. <https://docs.fluentvalidation.net/en/latest/aspnet.html>

[^polly]: App vNext. (n.d.). *Polly documentation*. <https://www.pollydocs.org/>

[^pollymigration]: App vNext. (n.d.). *Migration guide from v7 to v8*. Polly documentation. <https://www.pollydocs.org/migration-v8.html>

[^httpresilience]: Microsoft. (2026, February 24). *Build resilient HTTP apps: Key development patterns*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience>

[^tickerqrepo]: Arcenox. (n.d.). *TickerQ* [Repository]. GitHub. <https://github.com/Arcenox-co/TickerQ>

[^tickerq]: Arcenox. (n.d.). *TickerQ: Background jobs & workflows for .NET*. <https://tickerq.net/>

[^tickerqlicensing]: Arcenox. (n.d.). *Licensing*. TickerQ documentation, 5.x. <https://tickerq.net/docs/5.x/getting-started/licensing>

[^tickerqlicensingmd]: Arcenox. (2026). *LICENSING.md*. TickerQ repository, GitHub. <https://github.com/Arcenox-co/TickerQ/blob/main/LICENSING.md>

[^tickerqquickstart]: Arcenox. (n.d.). *Quick start*. TickerQ documentation, 5.x. <https://tickerq.net/docs/5.x/getting-started/quick-start>

[^tickerqreleases]: Arcenox. (2025, April 20). *v2.0.0* [Release]. TickerQ repository, GitHub. <https://github.com/Arcenox-co/TickerQ/releases/tag/v2.0.0>

[^quartz]: Quartz.NET. (n.d.). *Quartz.NET*. <https://www.quartz-scheduler.net/>

[^hangfire]: Hangfire. (n.d.). *Hangfire: Background jobs and workers for .NET and .NET Core*. <https://www.hangfire.io/>
