---
title: "Test Coverage in .NET: What It Measures and How to Collect It"
description: "Test coverage measures how much of your code the tests ran: lines, branches, methods and, in safety-critical work, conditions. Here is what each kind of coverage means, how .NET tools collect it by instrumenting your assemblies, the Coverlet integrations and Microsoft's own collector, thresholds that fail the build, excluding code, turning results into reports with ReportGenerator, running it all in CI, and why a suite at 100% can still miss the bug, with mutation testing as the check that coverage cannot do."
date: 2026-10-21T13:10:00Z
categories: [".NET"]
tags: [".NET", "C#", "Testing", "Code Coverage", "Coverlet", "ReportGenerator", "Mutation Testing"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

A pull request comes back with a comment: "coverage dropped from 84% to 81%".
What does the number mean? Which 3% went missing, and does it matter? Coverage
is one of the few test metrics that every .NET tool can produce for free, and
one of the easiest to misread. It is very good at answering *which code did no
test run?* and close to useless at answering *are the tests any good?*

This article explains what the different kinds of coverage measure, how .NET
tools collect them, and how to use Coverlet, Microsoft's code coverage
extension and ReportGenerator in practice, including thresholds and CI. It
ends with what coverage cannot tell you and the technique that can, mutation
testing. The general ideas behind unit tests, test doubles and the first look
at coverage are in [What Is a Unit Test?](../../fundamentals/unit-tests/);
this article is the .NET half.

Every command shown was run on 21 October 2026 with the .NET 10 SDK 10.0.400,
coverlet 10.1.0, ReportGenerator 5.5.11, Microsoft.Testing.Extensions.CodeCoverage
18.12.0 and Stryker.NET 5.0.0, on a Windows machine with a Brazilian locale,
which is why some numbers print with a decimal comma. Long paths are shortened
to `…`.

## What test coverage is

**Test coverage, or code coverage, is the share of a program's code that a
test run executed, measured in some unit: lines, branches, methods or
conditions. It is computed by instrumenting the code so that each unit records
when it runs, running the tests, and dividing what ran by what could have
run.**

Microsoft's guide puts it in one sentence: "Code coverage is a measurement of
the amount of code that is run by unit tests - either lines, branches, or
methods."[^mscoverage] The unit matters, because the same test run gives very
different numbers depending on what is counted:

| Kind | What counts as covered | Reported by .NET tools |
|---|---|---|
| **Line** (statement) | Each line, or sequence point, that ran at least once | Yes |
| **Branch** (decision) | Each outcome of each decision: both sides of an `if`, every `case`, both results of `?:`, `&&` and `??` | Yes |
| **Method** (function) | Each method entered at least once | Yes |
| **Condition** | Each boolean sub-expression of a decision evaluated both true and false | Not directly |
| **MC/DC** | Each condition shown to change the decision's outcome on its own, with the others held fixed | Specialist tools |
| **Path** | Each distinct route through a method, so every combination of branches | No: the count grows exponentially |

The first three are what Coverlet, Microsoft's collector and ReportGenerator
report. Modified condition/decision coverage, MC/DC, belongs to safety-critical
software: a NASA tutorial on it was written for "aviation software products
that must comply with regulatory guidance for DO-178B level A
software".[^mcdc] It is worth knowing the name, because it shows how far
"100% coverage" is from "every case tested". A decision such as
`a && (b || c)` is fully covered at the decision level by two tests, one true
and one false. MC/DC needs, for each of the three conditions, a pair of tests
in which only that condition changes and the outcome flips, which takes four
tests here.

## How .NET collects coverage

A compiled .NET assembly does not know which lines of source it came from. The
compiler records that in the PDB, the symbol file, as *sequence points*: IL
offsets that each correspond to a span of source code. Coverage tools use them
to map executed IL back to lines.

Coverlet, the open source collector most .NET projects use, works by
**instrumentation**. Its documentation describes two phases. Before the tests
run, it finds the test assembly's references that have PDBs and "instruments
the selected assemblies by inserting code to record sequence point hits to a
temporary file". After the tests, it restores the original, non-instrumented
assemblies, reads the hits and writes the result.[^coverlet] That is why
coverage needs a PDB, and why it is collected from a normal Debug build: an
assembly without symbols is skipped.

{{< diagram src="pipeline.svg" caption="Coverlet rewrites the assembly's IL so that each sequence point records a hit, runs the tests against it, restores the original and writes a coverage file. ReportGenerator turns the file into something people read." >}}

Microsoft's own collector takes a different route to the same result. It
supports "both static and dynamic instrumentation", for managed and, if
enabled, native code, and ships "with Microsoft .NET library closed-source free
to use licensing model".[^mtpcoverage] Coverlet is "part of the .NET
Foundation" and open source.[^mscoverage] Both produce the same kind of
numbers, and both can write Cobertura, so the rest of the tool chain does not
care which one collected them.

### The tools at a glance

| Tool | Package or command | Runs on | Output |
|---|---|---|---|
| Coverlet, VSTest collector | `coverlet.collector`, `dotnet test --collect:"XPlat Code Coverage"` | VSTest | Cobertura by default, in `TestResults/<guid>/` |
| Coverlet, MSBuild | `coverlet.msbuild`, `dotnet test /p:CollectCoverage=true` | VSTest | JSON by default, in the test project folder, plus a console table |
| Coverlet, console tool | `coverlet.console` | Any test command | Any Coverlet format |
| Coverlet, MTP | `coverlet.MTP`, `--coverlet` | Microsoft.Testing.Platform | JSON and Cobertura |
| Microsoft code coverage | `Microsoft.Testing.Extensions.CodeCoverage`, `--coverage`; or `--collect:"Code Coverage"` on VSTest | Either | `.coverage`, XML or Cobertura |
| ReportGenerator | `dotnet-reportgenerator-globaltool` | A .NET tool | HTML, text, Markdown, badges |

Two rules from Coverlet's documentation save time. Do not reference
`coverlet.msbuild` and `coverlet.collector` in the same test
project.[^coverlet] And neither of them works on Microsoft.Testing.Platform:
"coverlet.collector is not compatible with the Microsoft Testing Platform (MTP
v2)", so MTP projects use `coverlet.MTP` or Microsoft's
extension.[^coverletvstest]

## Collecting coverage with the VSTest collector

The example is a small pricing rule in a class library, `Shop`:

```csharp
namespace Shop;

public static class Pricing
{
    // Members get 10% off. Orders of 100.00 or more after the discount
    // ship free; smaller ones pay 7.50.
    public static decimal Total(decimal subtotal, bool isMember)
    {
        if (subtotal < 0)
            throw new ArgumentOutOfRangeException(nameof(subtotal));

        var discounted = isMember ? subtotal * 0.9m : subtotal;
        var shipping = subtotal >= 100m ? 0m : 7.50m;
        return discounted + shipping;
    }
}
```

A second class, `Receipt`, formats a total for printing. Look closely at the
shipping line: the comment says the threshold applies *after* the discount,
and the code tests `subtotal`. That bug comes back later.

`dotnet new xunit` still adds the VSTest collector for you. On this SDK the
template's test project is:

```xml
<ItemGroup>
  <PackageReference Include="coverlet.collector" Version="6.0.4" />
  <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
  <PackageReference Include="xunit" Version="2.9.3" />
  <PackageReference Include="xunit.runner.visualstudio" Version="3.1.4" />
</ItemGroup>
```

The template pins versions from when the SDK was built. NuGet had
coverlet.collector 10.1.0 on the day of the run, so the first step was
`dotnet add package coverlet.collector` to update it. With one test, a member
buying 200.00 worth:

```csharp
[Fact]
public void Member_with_a_large_order_gets_the_discount_and_free_shipping()
{
    Assert.Equal(180m, Pricing.Total(200m, isMember: true));
}
```

```txt
$ dotnet test --collect:"XPlat Code Coverage"
Passed!  - Failed:     0, Passed:     1, Skipped:     0, Total:     1, Duration: 35 ms - Shop.Tests.dll (net10.0)

Attachments:
  …\tests\Shop.Tests\TestResults\aaf3f9fe-3913-4539-83d8-e2cc0c0772d9\coverage.cobertura.xml
```

`"XPlat Code Coverage"` is the friendly name of Coverlet's data collector;
`"Code Coverage"` would select Microsoft's built-in one instead.[^mscoverage]
The result lands in a folder with a random GUID name, "by design" of the VSTest
platform.[^coverletvstest] The top of the Cobertura file already has the
totals:

```xml
<coverage line-rate="0.75" branch-rate="0.5" version="1.9" timestamp="1792588726"
          lines-covered="6" lines-valid="8" branches-covered="3" branches-valid="6">
```

and further down, the line-by-line detail for `Total`:

```xml
<line number="9" hits="1" branch="True" condition-coverage="50% (1/2)">
<line number="10" hits="0" branch="False" />
<line number="12" hits="1" branch="True" condition-coverage="50% (1/2)">
<line number="13" hits="1" branch="True" condition-coverage="50% (1/2)">
<line number="14" hits="1" branch="False" />
```

Every line of `Total` except the `throw` ran, yet only half of the branches
were taken. Line coverage cannot see that lines 12 and 13 each hide two
paths.

{{< diagram src="line-vs-branch.svg" caption="One test runs six of the seven lines of `Total`, but takes only three of its six branches. Branch coverage is the stricter measure." >}}

The whole assembly scores 75% of lines, not 85.7%, because `Receipt.Format`
never ran: its one line counts against the total. That is method coverage at
work too, at 1 of 2 methods.

### Choosing output formats

Coverlet writes Cobertura by default through the collector, and can also write
`json`, `lcov`, `opencover` and `teamcity`:[^coverletvstest]

```bash
dotnet test --collect:"XPlat Code Coverage;Format=json,lcov,cobertura"
```

Cobertura is the format most report tools and CI services read; lcov suits
editor extensions that paint covered lines in the gutter; OpenCover carries the
most detail for .NET-specific tools. The same settings can live in a
`.runsettings` file under the `XPlat code coverage` data collector, which is
the better home once there are filters and exclusions to share.

## Thresholds with the MSBuild integration

The collector records coverage but cannot enforce it: the VSTest integration
does not support "show result on console, report merging and threshold
validation".[^coverletvstest] For that, Coverlet's MSBuild package runs
coverage as part of `dotnet test` and can fail the build. It replaces the
collector rather than sitting beside it:

```bash
dotnet remove package coverlet.collector
dotnet add package coverlet.msbuild
```

`/p:Threshold` sets the minimum and `/p:ThresholdType` picks `line`, `branch`,
`method` or several of them.[^coverletmsbuild] With the one-test suite and a
line threshold of 80%:

```txt
$ dotnet test /p:CollectCoverage=true /p:Threshold=80 /p:ThresholdType=line
  [coverlet] _mapping file name: 'CoverletSourceRootsMapping_Shop.Tests'

Passed!  - Failed:     0, Passed:     1, Skipped:     0, Total:     1, Duration: 51 ms - Shop.Tests.dll (net10.0)
  [coverlet]
  Calculating coverage result...
   Generating report '…\tests\Shop.Tests\coverage.json'

+--------+------+--------+--------+
| Module | Line | Branch | Method |
+--------+------+--------+--------+
| Shop   | 75%  | 50%    | 50%    |
+--------+------+--------+--------+

+---------+------+--------+--------+
|         | Line | Branch | Method |
+---------+------+--------+--------+
| Total   | 75%  | 50%    | 50%    |
+---------+------+--------+--------+
| Average | 75%  | 50%    | 50%    |
+---------+------+--------+--------+

…\coverlet.msbuild.targets(73,5): error : The minimum line coverage is below the specified 80 […\Shop.Tests.csproj]
…
```

The tests passed and the command still exited with code 1, which is what a CI
step needs. By default every module must meet the threshold on its own;
`/p:ThresholdStat=total` or `average` applies it to the combined result
instead.[^coverletmsbuild] The JSON report is written to the test project's
folder, not attached to the test run, and `/p:CoverletOutputFormat` changes
the format. Several formats are separated by commas, and in PowerShell or
Azure DevOps the comma has to be written as `%2c`.[^coverletmsbuild]

To make the settings permanent, put them in the test project instead of on the
command line:

```xml
<PropertyGroup>
  <CollectCoverage>true</CollectCoverage>
  <CoverletOutputFormat>cobertura</CoverletOutputFormat>
  <Threshold>80</Threshold>
  <ThresholdType>line,branch</ThresholdType>
</PropertyGroup>
```

### Excluding code

Some code has no business in the number: generated code, `Program.cs`
bootstrapping, thin wrappers around the framework. `[ExcludeFromCodeCoverage]`
from `System.Diagnostics.CodeAnalysis` removes "a method, an entire class or
assembly from code coverage"; MSBuild properties exclude by attribute
(`ExcludeByAttribute`), by source file glob (`ExcludeByFile`) or by
`[Assembly-Filter]Type-Filter` pattern (`Exclude`), and `SkipAutoProps` drops
auto-implemented properties.[^coverletmsbuild]

Marking `Receipt` with the attribute and running the same command:

```txt
$ dotnet test /p:CollectCoverage=true /p:Threshold=80 /p:ThresholdType=line
…
Passed!  - Failed:     0, Passed:     1, Skipped:     0, Total:     1, Duration: 48 ms - Shop.Tests.dll (net10.0)
…

+--------+--------+--------+--------+
| Module | Line   | Branch | Method |
+--------+--------+--------+--------+
| Shop   | 85.71% | 50%    | 100%   |
+--------+--------+--------+--------+
…
```

The build now passes. Nothing was tested that was not tested before: one
class simply stopped counting. That is the risk with exclusions, and the
reason to review them like code. Exclude what is genuinely untestable or not
yours, never what is merely untested.

## Coverage on Microsoft.Testing.Platform

Microsoft.Testing.Platform, MTP, is the newer test runner that MSTest, NUnit
and xUnit v3 can use instead of VSTest. A test project becomes an executable,
and coverage is an extension added by package. xUnit v3 keeps its own command
line by default; `<UseMicrosoftTestingPlatformRunner>true</UseMicrosoftTestingPlatformRunner>`
switches a project to MTP.[^xunitmtp] With
`Microsoft.Testing.Extensions.CodeCoverage` referenced, the extension is
registered automatically:[^mtpcoverage]

```xml
<PropertyGroup>
  <OutputType>Exe</OutputType>
  <UseMicrosoftTestingPlatformRunner>true</UseMicrosoftTestingPlatformRunner>
</PropertyGroup>

<ItemGroup>
  <PackageReference Include="xunit.v3" Version="4.0.2" />
  <PackageReference Include="Microsoft.Testing.Extensions.CodeCoverage" Version="18.12.0" />
</ItemGroup>
```

```txt
$ dotnet run --project tests/Shop.Tests.Mtp -- --coverage --coverage-output-format cobertura

  In process file artifacts produced:
    - …\tests\Shop.Tests.Mtp\bin\Debug\net10.0\TestResults\389a5569-0b07-4bae-95da-32d31787e36e.cobertura.xml

Test run summary: Passed! - …\Shop.Tests.Mtp.dll (net10.0|x64)
  total: 1
  failed: 0
  succeeded: 1
  skipped: 0
  duration: 394ms

  Code Coverage Summary:
    Total - Line: 85.7%
    Total - Block: N/A
    Shop - Line: 85.7%
    Shop - Block: N/A
```

Microsoft's collector reaches the same 85.7% as Coverlet and honours the same
`[ExcludeFromCodeCoverage]` on `Receipt`. Its formats are `coverage`, `xml` and
`cobertura`, and unlike VSTest it leaves the test assembly out by
default.[^mtpcoverage] From MTP 2.4, collectors can also publish threshold
results to the platform, and a failed threshold makes an otherwise green run
exit with code 14.[^mtpcoverage] Coverlet users on MTP switch to `coverlet.MTP`
and its `--coverlet` options.[^mtpcoverage]

## Turning results into reports

A Cobertura file is meant for machines. ReportGenerator, Daniel Palme's Apache
2.0 tool, "converts coverage reports generated by coverlet, OpenCover,
dotCover, Visual Studio, NCover, Cobertura, JaCoCo, Clover, gcov or lcov into
human readable reports in various formats", and it "supports merging several
coverage files into a single report", which matters once a solution has
several test projects.[^reportgenerator]

### Global, tool-path or local

ReportGenerator is a .NET tool, and .NET tools install in three ways:[^dotnettools]

- **Global** (`dotnet tool install -g`): installed for the current user and
  added to `PATH`, one version for every directory on the machine.
- **Tool-path** (`--tool-path tools`): a global tool in a folder you choose,
  which is not added to `PATH`.
- **Local**: recorded in a manifest, `dotnet-tools.json`, so that every clone
  of the repository uses the same version. Contributors run
  `dotnet tool restore` to install everything the manifest lists.

The package is called `dotnet-reportgenerator-globaltool`, but the name is
historical: it installs as a local tool like any other. For a project, local
is the right choice, because the version is pinned in source control and CI
gets it with one command:

```txt
$ dotnet new tool-manifest
The template "Dotnet local tool manifest file" was created successfully.

$ dotnet tool install dotnet-reportgenerator-globaltool
You can invoke the tool from this directory using the following commands: 'dotnet tool run reportgenerator' or 'dotnet reportgenerator'.
Tool 'dotnet-reportgenerator-globaltool' (version '5.5.11') was successfully installed. Entry is added to the manifest file …\dotnet-coverage\dotnet-tools.json.
```

```json
{
  "version": 1,
  "isRoot": true,
  "tools": {
    "dotnet-reportgenerator-globaltool": {
      "version": "5.5.11",
      "commands": [
        "reportgenerator"
      ],
      "rollForward": false
    }
  }
}
```

The documentation describes the manifest under a `.config` folder; this SDK
wrote it at the root of the directory, and both locations are found.
Microsoft's warning applies to both: .NET tools "run in full trust", and a
manifest modified by someone untrusted "could cause the CLI to run malicious
code".[^dotnettools]

### Reading the summary

With four tests, covering the guest, the member, the negative subtotal and the
receipt, and `Receipt` counted again:

```txt
$ dotnet test --collect:"XPlat Code Coverage"
Passed!  - Failed:     0, Passed:     4, Skipped:     0, Total:     4, Duration: 45 ms - Shop.Tests.dll (net10.0)
$ dotnet reportgenerator -reports:"tests/**/coverage.cobertura.xml" -targetdir:coveragereport -reporttypes:TextSummary
$ cat coveragereport/Summary.txt
Summary
  Generated on: 21/10/2026 - 10:19:31
  Coverage date: 21/10/2026 - 10:19:31
  Parser: Cobertura
  Assemblies: 1
  Classes: 2
  Files: 2
  Line coverage: 100%
  Covered lines: 8
  Uncovered lines: 0
  Coverable lines: 8
  Total lines: 25
  Branch coverage: 100% (6 of 6)
  Covered branches: 6
  Total branches: 6
  Method coverage: 100% (2 of 2)
  Full method coverage: 100% (2 of 2)
  Covered methods: 2
  Fully covered methods: 2
  Total methods: 2

Shop              100%
  Shop.Pricing    100%
  Shop.Receipt    100%
```

The glob in `-reports` picks up every `coverage.cobertura.xml` under `tests/`,
however many GUID folders there are, and merges them. `Html` produces the
browsable report with source files coloured line by line; `TextSummary`,
`MarkdownSummaryGithub` and `Badges` are the useful ones for
CI.[^reportgenerator] One detail in the run: the first attempt at the receipt
test failed, because `Receipt` formatted with the machine's culture and printed
`57,50`. The fix was `CultureInfo.InvariantCulture`. Tests find bugs by
checking results, not by executing lines, which is the theme of the rest of
this article.

## Coverage in CI

In a pipeline the pieces fit in four steps: restore the tools, run the tests
with coverage, merge and summarise, and publish. A GitHub Actions job, for
example:

```yaml
- run: dotnet tool restore
- run: dotnet test --collect:"XPlat Code Coverage" --results-directory coverage
- run: >
    dotnet reportgenerator -reports:"coverage/**/coverage.cobertura.xml"
    -targetdir:coveragereport -reporttypes:"Html;MarkdownSummaryGithub"
- run: cat coveragereport/SummaryGithub.md >> "$GITHUB_STEP_SUMMARY"
```

`--results-directory` gives the collector a known place to write, and
`MarkdownSummaryGithub` writes `SummaryGithub.md`, a table that renders on the
run's summary page. ReportGenerator also offers ready-made steps for Azure
DevOps and GitHub Actions.[^reportgenerator] To fail the build on a drop, use
the MSBuild threshold, MTP's threshold support, or a check in the coverage
service you publish to. A useful policy is to watch coverage of *changed* lines
in a pull request rather than the total, which moves slowly and hides new
untested code inside old tested code.

## What coverage does not tell you

The four-test suite above has 100% line, branch and method coverage. It also
has the bug from the start of the article: shipping is decided on the
subtotal, not on the discounted amount. A member spending 105.00 pays 94.50
after the discount, which is below 100.00, so shipping should apply. One test
written from the requirement finds it:

```csharp
[Fact]
public void Member_whose_discount_drops_the_order_below_100_pays_shipping()
{
    Assert.Equal(102.00m, Pricing.Total(105m, isMember: true));
}
```

```txt
$ dotnet test
[xUnit.net 00:00:00.13]     PricingTests.Member_whose_discount_drops_the_order_below_100_pays_shipping [FAIL]
  Failed PricingTests.Member_whose_discount_drops_the_order_below_100_pays_shipping [1 ms]
  Error Message:
   Assert.Equal() Failure: Values differ
Expected: 102,00
Actual:   94,5
…
Failed!  - Failed:     1, Passed:     4, Skipped:     0, Total:     5, Duration: 33 ms - Shop.Tests.dll (net10.0)
```

Coverage counted every line and every branch as tested because each one *ran*.
It cannot know whether any test *checked* the right thing, or whether the
inputs that matter, here a member near the threshold, were ever tried. Martin
Fowler's summary is still the best: coverage "is a useful tool for finding
untested parts of a codebase" and "of little use as a numeric statement of how
good your tests are", because "high coverage numbers are too easy to reach
with low quality testing", at the extreme with tests that assert
nothing.[^fowler]

### Mutation testing: testing the tests

Mutation testing asks the question coverage cannot: *would the tests notice
if the code were wrong?* Stryker.NET does it for .NET. It "allows you to test
your tests by temporarily inserting bugs",[^stryker] one at a time, and runs
the suite against each *mutant*. A mutant is **killed** "when at least one
test failed while this mutant was active", and **survived** "when all tests
passed".[^strykerstates] It installs as a local tool in the same manifest and
runs from the test project's folder:[^strykerstart]

```bash
dotnet tool install dotnet-stryker
cd tests/Shop.Tests
dotnet stryker
```

Against the four-test suite with 100% coverage:

```txt
Killed:   12
Survived:  2
Timeout:   0
Errors:   0

All mutants have been tested, and your mutation score has been calculated
All files [12/15 (85,71%)]
├── Pricing.cs [10/13 (83,33%)]
│   ├── [Survived] Equality mutation on line 9
│   │   ├── [-] subtotal < 0
│   │   └── [+] subtotal <= 0
│   ├── [Survived] Equality mutation on line 13
│   │   ├── [-] subtotal >= 100m
│   │   └── [+] subtotal > 100m
…
└── Receipt.cs [2/2 (100,00%)]
…
[10:22:11 INF] The final mutation score is 85.71 %
```

The mutation score is "detected / valid * 100",[^strykerstates] here 12 of 14
tested mutants. The two survivors are exactly the boundaries no test tried: a
subtotal of zero, and an order of exactly 100.00. Changing `>=` to `>` made no
test fail, so the suite cannot tell them apart. That is information no
coverage report contains.

Neither tool found the real bug, though. Stryker mutates the code as written;
it has no idea that the comment says "after the discount". Only a test written
from the requirement does that. Coverage shows where no test looks, mutation
testing shows where tests look without checking, and neither replaces thinking
about what the code is supposed to do.

## How much coverage is enough

There is no number that is right for every codebase, and the sources worth
trusting avoid giving one as a target. Fowler expects that thoughtful testing
lands "in the upper 80s or 90s", as a side effect rather than a
goal.[^fowler] A threshold is a floor that stops coverage from silently
eroding, not a definition of done; set it a little below where the project
already is, raise it as the suite improves, and pay more attention to the
uncovered lines in a pull request than to the total. When a team is told to
reach a percentage, it can always do so, if necessary with tests that execute
code without checking it, and the number stops meaning anything.

## Common misunderstandings

| Misunderstanding | What is actually true |
|---|---|
| "100% coverage means the code is tested." | It means every counted unit ran. The example above has 100% line and branch coverage and a bug. |
| "Line and branch coverage are the same thing." | One test ran six of seven lines of `Total` but only three of six branches. Branch coverage is stricter. |
| "Coverage proves the tests check anything." | Coverage records execution. A test with no assertion covers as much as one with ten. |
| "I need both coverlet packages." | Use the collector *or* the MSBuild package in a test project, never both. |
| "The collector can fail the build on a threshold." | Thresholds are a feature of the MSBuild and console integrations, and of MTP's coverage model. |
| "coverlet.collector works everywhere." | It is VSTest-only. Projects on Microsoft.Testing.Platform use `coverlet.MTP` or Microsoft's extension. |
| "A tool manifest manages global tools." | It manages *local* tools. Global tools are per user and live outside the repository. |
| "`dotnet restore` installs the tools in the manifest." | `dotnet tool restore` does. |
| "Excluding code is harmless." | An exclusion raises the number without adding a test. Review it like code. |
| "Coverage should be a team target." | As a target it is easy to game. As a map of what no test runs it is very useful. |

## References

[^mscoverage]: Microsoft. (2026). *Use code coverage for unit testing*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-code-coverage>

[^mcdc]: Hayhurst, K. J., Veerhusen, D. S., Chilenski, J. J., & Rierson, L. K. (2001). *A practical tutorial on modified condition/decision coverage* (NASA/TM-2001-210876). NASA Langley Research Center. <https://ntrs.nasa.gov/citations/20010057789>

[^coverlet]: Coverlet contributors. (n.d.). *Coverlet* [README]. GitHub. Sections "How It Works" and "Quick Start". <https://github.com/coverlet-coverage/coverlet>

[^coverletvstest]: Coverlet contributors. (n.d.). *Coverlet integration with VSTest*. GitHub. <https://github.com/coverlet-coverage/coverlet/blob/master/Documentation/VSTestIntegration.md>

[^coverletmsbuild]: Coverlet contributors. (n.d.). *Coverlet integration with MSBuild*. GitHub. Sections on output formats, thresholds and excluding from coverage. <https://github.com/coverlet-coverage/coverlet/blob/master/Documentation/MSBuildIntegration.md>

[^mtpcoverage]: Microsoft. (2026). *Microsoft.Testing.Platform (MTP) code coverage*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/testing/microsoft-testing-platform-extensions-code-coverage>

[^xunitmtp]: xUnit.net. (n.d.). *Microsoft Testing Platform support in xUnit.net v3*. <https://xunit.net/docs/getting-started/v3/microsoft-testing-platform>

[^reportgenerator]: Palme, D. (n.d.). *ReportGenerator* [README]. GitHub. <https://github.com/danielpalme/ReportGenerator>

[^dotnettools]: Microsoft. (2025). *.NET tools*. .NET documentation. <https://learn.microsoft.com/en-us/dotnet/core/tools/global-tools>

[^fowler]: Fowler, M. (2012, April 17). *TestCoverage*. martinfowler.com. <https://martinfowler.com/bliki/TestCoverage.html>

[^stryker]: Stryker Mutator. (n.d.). *Introduction*. Stryker.NET documentation. <https://stryker-mutator.io/docs/stryker-net/introduction/>

[^strykerstart]: Stryker Mutator. (n.d.). *Getting started*. Stryker.NET documentation. <https://stryker-mutator.io/docs/stryker-net/getting-started/>

[^strykerstates]: Stryker Mutator. (n.d.). *Mutant states and metrics*. Mutation testing elements. <https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/>
