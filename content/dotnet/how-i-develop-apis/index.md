---
title: "How I Develop APIs"
description: "The shape every ASP.NET Core API of mine takes, with Heimdall as the example: the folder structure, the design patterns (layers, CQRS behind a mediator, results instead of exceptions, message maps, an auditing decorator), the test patterns (Given/When/Then unit tests with fakes, functional tests over HTTP against a real PostgreSQL) and the coding style that holds it together."
date: 2026-10-21T19:30:00Z
categories: [".NET"]
tags: [".NET", "C#", "ASP.NET Core", "Web API", "CQRS", "Architecture", "Testing", "xUnit", "Testcontainers", "Code Style"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Every backend I build is an ASP.NET Core API, and they all look alike on
purpose. When the structure is the same everywhere, I never have to remember
where a thing lives, a new feature is a list of files to add rather than a
design decision, and a test that fails points at one small piece of code.

This page describes that shape, using
[Heimdall](https://docs.artur-rios.tech/heimdall-api/) as the example
throughout. Heimdall is my identity management API: people, applications,
logins, two-factor authentication and permissions, for several client systems
at once, each in its own scope. It is the largest API I have, so every pattern
here has been tested against a real use case rather than a toy one. All code
on this page is taken from it, trimmed only where noted.

Two other pages cover what comes before and after the code.
[How I Start a Project From Scratch]({{< ref "/engineering/starting-a-project-from-scratch" >}})
explains the documents and use cases a project starts with; this page picks up
when the first use case is implemented.
[Web APIs]({{< ref "/infrastructure/infrastructure-web-apis" >}}) in the
infrastructure series explains how the finished API is packaged and deployed.

| Concern | Choice |
| --- | --- |
| Framework | ASP.NET Core on .NET 10, controllers rather than minimal APIs |
| Structure | Four layers in six projects: Domain, Application (Command, Query, Shared), Infrastructure, Presentation |
| Reads and writes | CQRS: commands and queries, each dispatched by its own mediator to one handler |
| Errors | Returned in a `DataOutput<T>` result, never thrown; a message map turns each message into a status code |
| Validation | FluentValidation, one validator per command or query |
| Data | EF Core on PostgreSQL, behind repository interfaces, with migrations applied explicitly |
| Cross-cutting | Auditing as a decorator around every write handler |
| Tests | xUnit v3; unit tests with fakes and Moq, functional tests over HTTP against PostgreSQL in Testcontainers |
| Style | One `.editorconfig`, Allman braces, `var`, primary constructors, and documentation comments that cite the specification |

## Folder structure

### The repository

The repository holds more than the code. Everything needed to understand,
call, test and release the API sits next to it:

```txt
heimdall-api/
  api-client/                 ready-to-send requests for every endpoint
    http/                     JetBrains HTTP Client files, one per area
    bruno/                    the same requests as a Bruno collection
  docs/                       the Hugo (Docsy) documentation site
    requirements/             vision, requirements, use cases, testing, workflow
    openapi/                  the generated OpenAPI document, committed
  scripts/                    Python helpers: migrations, coverage, OpenAPI, flake hunting
  tools/                      small console programs outside the solution
  src/                        the API, one folder per layer
  tests/                      one test project per production project, same folders
  docker/                     an env file template per environment
  Directory.Packages.props    every package version, in one place
  .editorconfig               the coding style
  Dockerfile                  the multi-stage image
  docker-compose.yml          the API and its database, for local runs
  CHANGELOG.md                what changed, for API clients and operators
  CONTRIBUTING.md             build, test, migrate, branch and release
  README.md                   what it is, links to the docs, the use case tracker
```

A few of these are worth explaining:

- **`api-client/`** means nobody has to write a request by hand to try an
  endpoint. Each area of the API (scopes, persons, authentication…) has its own
  `.http` file, and the same requests exist as a Bruno collection for people
  who prefer a GUI.
- **`docs/requirements/`** holds the specification as plain Markdown. The
  documentation site renders the same files rather than a copy, so there is
  only ever one version of a requirement.
- **`scripts/`** holds every task longer than one command, written in Python
  so it runs the same on Windows, Linux and in CI: creating and applying
  migrations, building the coverage report, regenerating the OpenAPI document,
  repeating the test suite until a flaky test shows itself.
- **`Directory.Packages.props`** turns on
  [central package management](https://learn.microsoft.com/en-us/nuget/consume-packages/central-package-management).
  Project files list packages without versions, and this one file sets them,
  so two projects can never drift onto different versions of the same library.

### The solution

Inside `src/`, there is one folder per layer, and one project per
responsibility. Projects are named `ArturRios.<Product>.<Part>`:

```txt
src/
  Domain/
    ArturRios.Heimdall.Domain/            entities, enums, persistence interfaces
  Application/
    ArturRios.Heimdall.Command/           the write side
    ArturRios.Heimdall.Query/             the read side
    ArturRios.Heimdall.Shared/            messages and contracts both sides use
  Infrastructure/
    ArturRios.Heimdall.Data/              DbContext, entity maps, migrations, seeding
  Presentation/
    ArturRios.Heimdall.WebApi/            controllers, security, adapters, start-up
  ArturRios.Heimdall.sln
```

The project references enforce the direction of every dependency, so the
compiler rejects a shortcut before a code review has to:

{{< diagram src="layers.svg" caption="Each arrow is a project reference. Domain references nothing. Command and Query never reference Data: they depend on repository interfaces, and Data provides the implementations. Only the Web API project, where start-up wires everything together, sees every layer." >}}

### Inside each project

Every project is split into folders by the role a file plays, and the same
roles appear in the same folders everywhere:

| Project | Folders |
| --- | --- |
| Domain | `Entities/`, `Enums/`, `Persistence/` (interfaces for writes that need special care) |
| Command | `Input/` (commands), `Input/Validation/` (validators), `Output/`, `Handlers/`, `Services/`, `Auditing/` |
| Query | `Input/` (queries), `Input/Validation/`, `Output/`, `Handlers/`, `HealthChecks/` |
| Shared | `Messages/` (messages and their status maps), `Security/`, `Services/` |
| Data | `Configuration/` (the `DbContext`), `EntityMaps/`, `Migrations/`, `Persistence/`, `Seeding/` |
| WebApi | `Controllers/`, `Security/`, `Email/`, `Settings/`, `Metrics/`, plus `Program.cs` and `Startup.cs` |

The result is that a use case always produces the same set of files. Here is
everything UC-01, *Create Scope*, added:

| File | Project | Role |
| --- | --- | --- |
| `Input/CreateScopeCommand.cs` | Command | What the caller asks for |
| `Input/Validation/CreateScopeCommandValidator.cs` | Command | Whether the request is well formed |
| `Output/CreateScopeCommandOutput.cs` | Command | What the caller gets back |
| `Handlers/CreateScopeCommandHandler.cs` | Command | The use case itself |
| `Messages/ScopeMessages.cs` | Shared | Every message the use case can produce |
| `Messages/ScopeMessageMap.cs` | Shared | The status code for each message |
| `Controllers/ScopeController.cs` | WebApi | The endpoint, `POST /api/scopes` |
| `CreateScopeCommandHandlerTests.cs` | Command.Tests | Unit tests for the handler |
| `CreateScopeCommandValidatorTests.cs` | Command.Tests | Unit tests for the validator |
| `ScopeControllerCreateTests.cs` | WebApi.Tests | Functional tests for the endpoint |

Plus two lines in `Startup.cs` to register the validator and the handler, and
the request in `api-client/`. Adding a feature is mostly filling in this
table.

## Design patterns

### Layers, and the dependency rule

The four layers follow one rule: dependencies point inwards, towards the
domain, and never out. The Domain project describes what the system is about,
and references no other project. The Application projects hold the use cases,
and reach the database only through interfaces such as
`IAsyncRepository<T, long>`. The Data project implements those interfaces with
EF Core. The Web API project is the
[composition root]({{< ref "/concepts/inversion-of-control" >}}): it is the
only place that knows every concrete class, and it wires them together at
start-up.

The same rule applies to anything outside the process. When a use case needs
to send an email, verify a Google token or issue a JWT, the Command project
declares an interface (`IEmailVerificationSender`, `IGoogleIdTokenVerifier`,
`IAuthTokenIssuer`) and the Web API project provides the adapter. Choosing
Mailgun or a sender that only logs, or the real Google verifier or a local one
for the tests, becomes a decision made once at start-up, and no use case
changes. This is the
[dependency inversion principle]({{< ref "/concepts/dependency-inversion-principle" >}})
applied at the level of projects.

The entities themselves are plain data: properties, defaults and navigation
collections. How they are stored lives elsewhere, in one *entity map* per
entity in the Data project, so tables, keys and indexes never leak into the
domain:

```csharp
internal static class ScopeDbMap
{
    public static void Configure(this EntityTypeBuilder<Scope> scope)
    {
        scope.ToTable("scope");

        scope.HasKey(x => x.Id);

        scope.Property(x => x.PublicId).IsRequired();
        scope.HasIndex(x => x.PublicId).IsUnique();

        scope.Property(x => x.Name).IsRequired();

        // Scope name is unique (FR-SC-01, AF-01a / AF-03b).
        scope.HasIndex(x => x.Name).IsUnique();

        scope.Property(x => x.IsDeleted).HasDefaultValue(false);
        scope.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
        // ... the remaining columns
    }
}
```

Every entity has two identifiers. `Id` is a `long`, the primary key, used for
joins and never shown to anyone. `PublicId` is a `Guid` generated on creation,
and it is the only identifier that appears in a URL, a response body or a token
claim. Callers cannot guess other records' identifiers by counting, and the
internal keys can change without breaking a client.

### CQRS behind a mediator

The Application layer is split into a write side and a read side, an idea
known as Command Query Responsibility Segregation. A **command** asks the
system to change something (`CreateScopeCommand`), a **query** asks it for
data (`GetScopeByIdQuery`), and each has exactly one handler. Reads and writes
use different objects, different handlers and different mediators, so a read
never changes state by accident, and a change to how scopes are listed never
touches how they are created.

Controllers do not call handlers directly. They hand the command or query to a
mediator (`CommandMediator` or `QueryMediator`, from my
[ArturRios.Mediator](https://github.com/artur-rios/dotnet-mediator) library),
which resolves the handler registered for that type. A handler implements one
interface:

```csharp
public class CreateScopeCommandHandler(
    IValidator<CreateScopeCommand> validator,
    IAsyncReadOnlyRepository<Scope, long> scopeReader,
    IAsyncReadOnlyRepository<Person, long> personReader,
    IAsyncRepository<Scope, long> scopeWriter)
    : ICommandHandlerAsync<CreateScopeCommand, CreateScopeCommandOutput>
```

Each handler receives only what it uses, which keeps its constructor an honest
list of its dependencies, and its tests short. Read handlers take
`IAsyncReadOnlyRepository<T, long>`, whose `Query()` returns an `IQueryable`,
so the filtering, projection and paging happen in SQL rather than in memory.

### Thin controllers

A controller action does three things: bind the request, dispatch it, and turn
the result into a response. No business rule ever lives there:

```csharp
[Route("api/scopes")]
public class ScopeController(CommandMediator commandMediator, QueryMediator queryMediator) : Controller
{
    /// <summary>
    ///     Creates a new scope with one or more initial owners (UC-01). Restricted to System Admins.
    /// </summary>
    [HttpPost]
    [RoleRequirement((int)Roles.SystemAdmin)]
    public async Task<ActionResult<DataOutput<CreateScopeCommandOutput?>>> Create([FromBody] CreateScopeCommand command)
    {
        var result = await commandMediator
            .ExecuteCommandAsync<CreateScopeCommand, CreateScopeCommandOutput>(command);

        return result.ToActionResult(statusMap: ScopeMessageMap.StatusCodes);
    }
}
```

Two small helpers keep even the less simple actions this short. Route values
are copied onto the command (`command.Id = id;`) so the handler gets one
object. And when a rule depends on *who* is asking, `HttpContext.ApplyActor`
copies the caller's public identifier and role from the token onto the command
or query, so the handler can decide without knowing anything about HTTP:

```csharp
[HttpGet("{id:guid}")]
public async Task<ActionResult<DataOutput<ScopeOutput?>>> GetById(Guid id, [FromQuery] bool includeDeleted = false)
{
    var query = new GetScopeByIdQuery { Id = id, IncludeDeleted = includeDeleted };
    HttpContext.ApplyActor(query);

    var result = await queryMediator.ExecuteQueryAsync<GetScopeByIdQuery, ScopeOutput>(query);

    return result.ToActionResult(statusMap: ScopeMessageMap.StatusCodes);
}
```

Authorisation is split the same way. A role check that the token alone can
answer is an attribute on the action, `[RoleRequirement]`. A check that needs
data, such as "does this Scope Admin own *this* scope?", cannot be an
attribute, so it is the handler's.

### Results instead of exceptions

A handler never throws to report a business outcome. "That name is taken" or
"that scope does not exist" are expected answers, not failures of the program,
so the handler returns them inside a `DataOutput<T>`, a result object from my
[ArturRios.Output](https://github.com/artur-rios/dotnet-output) library that
carries the data, the messages and the errors. Exceptions are kept for what is
genuinely unexpected, and a middleware turns those into a 500.

The handler for UC-01 shows the shape every handler follows: start an empty
output, check the input, check the rules, collect every error, return early if
there are any, write, and return the data with a success message:

```csharp
public async Task<DataOutput<CreateScopeCommandOutput?>> HandleAsync(CreateScopeCommand command, CancellationToken cancellationToken = default)
{
    var output = DataOutput<CreateScopeCommandOutput?>.New;

    // Step 2 (AF-01b): validate input fields.
    var validation = await validator.ValidateAsync(command);

    if (!validation.IsValid)
    {
        return output.WithErrors(validation.Errors.Select(failure => failure.ErrorMessage));
    }

    var ownerIds = command.OwnerIds.Distinct().ToList();

    // Step 3 (AF-01a): the scope name must be unique, compared case-insensitively (LOWER() in SQL).
    var nameAlreadyExists = await scopeReader.Query()
        .AnyAsync(x => x.Name.ToLower() == command.Name.ToLower());

    if (nameAlreadyExists)
    {
        output.AddError(ScopeMessages.NameAlreadyExists);
    }

    // Step 4 (AF-01d): every owner must be an existing, non-logically-deleted administrator.
    var owners = await personReader.Query()
        .Where(x => ownerIds.Contains(x.PublicId) && !x.IsDeleted &&
                    (x.RoleId == (long)Roles.ScopeAdmin || x.RoleId == (long)Roles.SystemAdmin))
        .ToListAsync();

    if (owners.Count != ownerIds.Count)
    {
        output.AddError(ScopeMessages.OwnerNotValidScopeAdmin);
    }

    if (!output.Success)
    {
        return output;
    }

    // Step 5: create the scope with a SCOPE_OWNER row for each owner (inserted atomically).
    var scope = new Scope
    {
        Name = command.Name,
        Description = command.Description,
        Owners = [.. owners.Select(owner => new ScopeOwner { PersonId = owner.Id })]
    };

    var creation = await scopeWriter.CreateAsync(scope);

    if (!creation.Success)
    {
        return output.WithErrors(creation.Errors);
    }

    // Step 6: return the created scope.
    return output
        .WithData(new CreateScopeCommandOutput { Id = scope.PublicId, Name = scope.Name /* ... */ })
        .WithMessage(ScopeMessages.ScopeCreatedSuccessfully);
}
```

The step numbers and the `AF-01a` labels are the steps and alternative flows
of UC-01 in the use case specification. Anyone reading the handler can follow
it side by side with the document it implements.

### Message maps: one table decides the status code

If handlers return messages rather than throwing, something has to decide
which message is a 404 and which is a 409. That decision lives in one place
per area. Every message a caller can see is a constant in a static class:

```csharp
public static class ScopeMessages
{
    /// <summary>UC-01 success: the scope was created.</summary>
    public const string ScopeCreatedSuccessfully = "Scope created successfully.";

    /// <summary>AF-02a: the requested scope does not exist (or is logically deleted and not requested).</summary>
    public const string ScopeNotFound = "Scope not found.";

    /// <summary>AF-01a: a scope with the requested name already exists.</summary>
    public const string NameAlreadyExists = "A scope with this name already exists.";

    // ...
}
```

and a *message map* next to it gives each one its status:

```csharp
public static class ScopeMessageMap
{
    public static readonly IReadOnlyDictionary<string, int> StatusCodes =
        DataAccessMessageMap.CombinedWith(new Dictionary<string, int>
        {
            // UC-01 main flow — scope created.
            [ScopeMessages.ScopeCreatedSuccessfully] = HttpStatusCodes.Created,
            // AF-02a — scope not found.
            [ScopeMessages.ScopeNotFound] = HttpStatusCodes.NotFound,
            // AF-01a — scope name already exists.
            [ScopeMessages.NameAlreadyExists] = HttpStatusCodes.Conflict,
            // ...
        });
}
```

`ToActionResult`, from my
[ArturRios.Util.WebApi](https://github.com/artur-rios/dotnet-webapi-util)
library, looks up the first error (or, on success, the first message) in the
map and answers with that status, falling back to 200 on success and 400 on
failure. The whole HTTP contract of an area can be read in one file, and the
tests can assert on the same constants the handler returns, so a reworded
message never breaks a test.

`DataAccessMessageMap.CombinedWith` folds in the failures the persistence
layer can report: a unique violation or a concurrency conflict becomes a 409,
and an unreachable database a 503, which tells the client the problem is
temporary and worth a retry. The use case's own entries always win if a
message appears in both.

{{< diagram src="request-flow.svg" caption="The path of a write through the API. Everything a use case can answer travels back as a message in the `DataOutput`, and the area's message map picks the status code." >}}

### Validation in two places

Each command or query with input has one FluentValidation validator, in
`Input/Validation/`. A validator checks only the *shape* of the request: that a
field is present, not longer than its column, a well-formed URL. Anything that
needs the database, such as whether a name is already taken, is the handler's.
The split keeps validators fast and trivially testable, and keeps every rule
that reads data inside the use case, where its alternative flow is documented.

```csharp
public class CreateScopeCommandValidator : AbstractValidator<CreateScopeCommand>
{
    public CreateScopeCommandValidator()
    {
        RuleFor(command => command.Name)
            .NotEmpty()
            .WithMessage(ScopeMessages.NameRequired)
            .MaximumLength(200)
            .WithMessage(ScopeMessages.NameTooLong);

        // FluentValidation's MaximumLength rule skips a null argument, so only a non-null overlong
        // description is rejected.
        RuleFor(command => command.Description)
            .MaximumLength(500)
            .WithMessage(ScopeMessages.DescriptionTooLong);

        RuleFor(command => command.OwnerIds)
            .NotEmpty()
            .WithMessage(ScopeMessages.AtLeastOneOwnerRequired);
    }
}
```

The handler calls its validator itself, as the first step of the use case, so
the check runs whatever dispatches the command. A command without a validator is a decision,
not an omission, and the registration says why:

```csharp
// UC-50 (FR-SR-12): no validator — both identifiers are route values already constrained to
// GUIDs. Audited like every write, with the registration as target.
Builder.Services.AddAuditedCommandHandler<DiscardPendingRegistrationCommand, DiscardPendingRegistrationCommandOutput, DiscardPendingRegistrationCommandHandler>();
```

### Auditing as a decorator

Every successful write must leave an audit record: who did what, to which
record, and when. Writing that into every handler would mean dozens of copies
of the same code, and one forgotten copy would be a gap in the trail. Instead
it is a [decorator](https://refactoring.guru/design-patterns/decorator): a
handler that wraps the real one, calls it, and writes the audit row if it
succeeded. Registration does the wrapping:

```csharp
public static IServiceCollection AddAuditedCommandHandler<TCommand, TOutput, THandler>(
    this IServiceCollection services)
    where TCommand : BaseCommand
    where TOutput : CommandOutput
    where THandler : class, ICommandHandlerAsync<TCommand, TOutput>
{
    services.AddScoped<THandler>();
    services.AddScoped<ICommandHandlerAsync<TCommand, TOutput>>(provider =>
        new AuditingCommandHandler<TCommand, TOutput>(
            provider.GetRequiredService<THandler>(),
            provider.GetRequiredService<IAuditLogWriter>(),
            provider.GetRequiredService<
                Microsoft.Extensions.Logging.ILogger<AuditingCommandHandler<TCommand, TOutput>>>()));

    return services;
}
```

The mediator asks for `ICommandHandlerAsync<TCommand, TOutput>` and gets the
decorator, so no handler knows auditing exists, and no new write can forget
it. A failure to write the audit row is logged as a warning and never fails a
request the caller already succeeded at.

### Writes that race

The repositories write whole rows: read, change in memory, save. That is fine
for most writes, and wrong for the few that concurrent requests compete for. If
two requests read the same single-use recovery code before either saves, both
see it unused, and both spend it.

Those writes go through a dedicated interface instead, declared in the
Domain's `Persistence/` folder and implemented in Data. Each method is one
conditional `UPDATE … WHERE`: the check moves into the `WHERE` clause, the
database applies check and write together, and the number of affected rows
says who won. Budgets, such as login attempts, are charged *before* the
expensive comparison they guard, so a burst of parallel guesses cannot all pass
the "under the limit" check before any is counted. Rules that span rows, such
as "a scope always keeps one owner", take a row lock and check again once they
hold it.

These are the exception, and the interface names each one. Everything else
stays on the plain repositories.

### Start-up as a base class

`Program.cs` is two lines. `Startup` derives from `WebApiStartup`, a base class
in ArturRios.Util.WebApi that runs the sequence every one of my APIs shares:
load the configuration, add the controllers, the error envelope for invalid
requests and Swagger, then the standard middleware in a fixed order (tracing,
exception handling, Swagger, CORS, authentication). A new API inherits all of
that. Its own `Startup` overrides one method, `ConfigureServices`, to add what
is specific to it: its dependencies, logging, metrics, security, rate
limiting.

```csharp
public class Program
{
    public static void Main(string[] args)
    {
        var app = new Startup(args).CreateApplication();

        app.Run();
    }
}
```

Registrations in `Startup` are written one per line, grouped by area, each
validator right above its handler. It is long, and that is deliberate: the
file reads as the list of everything the API can do.

## Test patterns

### Two kinds of test, at two layers

Every test is either a **unit** test or a **functional** test, and the layer
of the code decides which:

| What the use case produced | Test kind | Test project |
| --- | --- | --- |
| A command handler | Unit | `*.Command.Tests` |
| A query handler | Unit | `*.Query.Tests` |
| A validator | Unit | next to its handler's tests |
| A domain class with real behaviour | Unit | `*.Domain.Tests` |
| An endpoint | Functional | `*.WebApi.Tests` |

Unit tests check the logic of one class with every collaborator replaced. A
functional test checks the whole thing a client would use: routing, binding,
authorisation, validation, the mediator, EF Core and the real schema. Both are
required for every use case, because they catch different mistakes. Entities
that only hold data get no unit tests of their own; their behaviour shows up
through the handlers.

The `tests/` folder mirrors `src/` exactly: one test project per production
project, named `<Project>.Tests`, and one test class per production class,
named `<Class>Tests`. Endpoints are the exception, with one functional class
per action, such as `ScopeControllerCreateTests`, because one endpoint already
has a dozen cases.

Tests are marked with `[UnitFact]`, `[UnitTheory]`, `[FunctionalFact]` or
`[FunctionalTheory]` instead of xUnit's `[Fact]` and `[Theory]`. The attributes
come from my [ArturRios.Util.Test](https://github.com/artur-rios/dotnet-test-util)
library and stamp a `Category` trait on each test, so each kind runs on its
own:

```bash
dotnet test src/ArturRios.Heimdall.sln --filter "Category=Unit"
```

CI runs the two categories as separate steps. Because a test with neither
category would silently run in neither step, CI first lists any such test and
fails the build if it finds one.

### Given, When, Then

Every test, of either kind, is named and laid out the same way. The name says
the situation, the action and the expected outcome:

```txt
GivenSomeCondition_WhenSomeAction_ThenSomeOutput
GivenNameAlreadyExists_WhenHandlingCreateScope_ThenReturnsNameAlreadyExistsError
GivenDuplicateName_WhenPostScope_ThenConflict
```

and the body has three commented sections in that order. A test checks one
behaviour. The same behaviour over several inputs becomes a theory, not a copy.
A failing test's name is therefore already a bug report, and the
[unit tests]({{< ref "/fundamentals/unit-tests" >}}) page explains the idea in
general terms.

Each test class starts with a comment naming the use case and which of its
flows it covers, and which it leaves to the other layer:

```csharp
// Unit tests for CreateScopeCommandHandler (UC-01).
// Cover the main flow plus alternative flows AF-01a (name exists), AF-01b (invalid input / no owner),
// and AF-01d (owner is not a valid ScopeAdmin). AF-01c (not System Admin) is a functional concern.
public class CreateScopeCommandHandlerTests
```

### One test per flow

The use case specification is the test plan. For each handler, there is a test
for the main flow and one for every alternative flow (`AF-xx`) the use case
defines. Flows that the framework enforces, such as a 403 from
`[RoleRequirement]`, are left to the functional tests, since a unit test of the
handler cannot reach them. For each endpoint, the functional tests cover the
main flow and every alternative flow, authorisation included.

### Unit tests: construct, drive, assert on the result

A unit test builds the handler directly with `new`, passing test doubles for
every dependency. There is no web host, no database, no network and no real
clock. Two kinds of double are used:

- **Repositories** become `AsyncFakeRepository<T, long>` from ArturRios.Util.Test,
  an in-memory store seeded in the *Given* step with exactly the state the
  scenario assumes.
- **Every other collaborator** (a validator, a token issuer, an email sender, a
  clock) is a [Moq](https://github.com/devlooped/moq) mock set up to return
  what the scenario needs. Moq is the only mocking library; a second one never
  enters a project.

Because handlers return a `DataOutput<T>`, tests assert on `Success`,
`Errors`, `Messages` and `Data`, not on exceptions:

```csharp
private static Mock<IValidator<CreateScopeCommand>> ValidValidator()
{
    var validator = new Mock<IValidator<CreateScopeCommand>>();
    validator
        .Setup(v => v.ValidateAsync(It.IsAny<CreateScopeCommand>(), It.IsAny<CancellationToken>()))
        .ReturnsAsync(new ValidationResult());
    return validator;
}

[UnitFact]
public async Task GivenNameAlreadyExists_WhenHandlingCreateScope_ThenReturnsNameAlreadyExistsError()
{
    // Given a store that already contains a scope named "Acme"
    var (persons, ownerId) = await PersonsWithScopeAdminOwner();
    var scopes = new AsyncFakeRepository<Scope, long>();
    await scopes.CreateAsync(new Scope { Name = "Acme" });
    var handler = new CreateScopeCommandHandler(ValidValidator().Object, scopes, persons, scopes);
    var command = new CreateScopeCommand { Name = "Acme", OwnerIds = [ownerId] };

    // When
    var output = await handler.HandleAsync(command);

    // Then
    Assert.False(output.Success);
    Assert.Contains(ScopeMessages.NameAlreadyExists, output.Errors);
}
```

Small private helpers such as `ValidValidator()` and
`PersonsWithScopeAdminOwner()` build the common *Given* state, so each test
shows only what makes it different. Test data sets only the fields the
behaviour depends on.

Validators are tested on their own with FluentValidation's `TestHelper`, and a
length rule is tested on both sides of its boundary: 201 characters is
refused, 200 is accepted.

```csharp
[UnitFact]
public void GivenNameOf201Characters_WhenValidating_ThenNameTooLongIsReported()
{
    // Given a name one character past the column that stores it
    var result = _validator.TestValidate(Command(name: new string('a', 201)));

    result.ShouldHaveValidationErrorFor(command => command.Name)
        .WithErrorMessage(ScopeMessages.NameTooLong);
}
```

### Functional tests: real HTTP, real PostgreSQL

A functional test calls the API the way a client would, over HTTP, and the API
talks to a real PostgreSQL database. Never an in-memory provider, and never a
developer's own database. The test class derives from `WebApiTest<Program>`,
from ArturRios.Util.Test, which hosts the API in memory with
`WebApplicationFactory` and exposes a `Gateway` for requests.

The database comes from [Testcontainers](https://dotnet.testcontainers.org/).
A `PostgresFixture` starts one `postgres:18-alpine` container for the whole
functional suite, the same major version production runs, applies the real EF
Core migrations to it and points the API's connection string at it before the
host starts. Using the migrations rather than `EnsureCreated` means the tests
run against exactly the schema a deployment gets. An xUnit collection shares
the fixture, so the container starts once, not once per class:

```csharp
[Collection(nameof(FunctionalCollection))]
public class ScopeControllerCreateTests(PostgresFixture db) : WebApiTest<Program>(EnvironmentType.Local)
{
    private static string UniqueName() => $"scope-{Guid.NewGuid():N}";

    [FunctionalFact]
    public async Task GivenSystemAdminAndValidOwner_WhenPostScope_ThenScopeIsCreated()
    {
        // Given
        var owner = await SeedPersonAsync(Roles.ScopeAdmin);
        Authorize(TestTokens.ForRole((int)Roles.SystemAdmin));
        var name = UniqueName();

        // When
        var response = await Gateway.PostAsync<DataOutput<CreateScopeCommandOutput?>>(
            "/api/scopes",
            new CreateScopeCommand { Name = name, Description = "New", OwnerIds = [owner.PublicId] });

        // Then — response
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal(name, response.Body?.Data?.Name);

        // Then — database state: the scope and one SCOPE_OWNER row for the owner
        await using var context = db.CreateContext();
        var persisted = await context.Scopes.Include(x => x.Owners).AsNoTracking()
            .FirstAsync(x => x.Name == name);
        Assert.Equal(owner.Id, Assert.Single(persisted.Owners).PersonId);
    }
}
```

Three habits make this work:

- **Assert the response *and* the database.** The status code says what the
  API claimed to do; the rows say what it did. A test that checks only one of
  them passes against an endpoint that lies.
- **Unique data instead of a clean database.** Nothing is truncated between
  tests and nothing runs in a rolled-back transaction. Each test creates its
  own rows under identifiers no other test can produce (`scope-{Guid:N}`,
  `user-{Guid:N}@test.local`) and asserts only about those. Tests stay
  independent, run in parallel, and never assert on a global count, because
  another class may have added rows of its own. A rule about *every* row of a
  table, such as "one System Admin always remains", gets an `IsolatedDatabase`
  of its own in the same container.
- **Real tokens.** `TestTokens` mints JWTs with the production claims mapper
  and the same secret, issuer and audience the host validates, so a change to
  the claims can never leave the tests passing against an outdated token
  format.

### Patterns for the harder cases

Some behaviours are easy to test badly. A few rules from Heimdall's testing
specification, each added after a test passed that should not have:

- **Every refusal checks that nothing changed.** A 403 is not enough: the test
  reads the row back and asserts it is still there, unchanged. An endpoint that
  answered 403 and deleted the row anyway would otherwise pass.
- **A toggle is tested in both directions.** Enabling and disabling are two
  tests, because a handler that ignored the requested value would pass the
  enable-only half.
- **A flag is tested where it is read, not only where it is written.** A
  "deleted" flag that nothing honours is not a deletion, so one test deletes a
  record and then confirms the read endpoint stops returning it.
- **When two answers look the same, assert the side effect.** Password
  recovery answers the same way whether or not the address exists, so that
  attackers cannot use it to find accounts. The tests check whether a reset
  token row was created, and one test compares the two responses to prove they
  match.
- **Races run for real.** For rules that rely on a lock, a `LockRace` helper
  holds the first request's write until the second is seen waiting on the lock,
  then asserts that it waited and that exactly the right outcome survived.
- **Absence is a decision.** When a rule deliberately does not exist, such as
  unique permission names, a test states it (`GivenDuplicateName_…ThenBothAreCreated`).
  If the rule is ever wanted, this is the test that fails first.

### Coverage, flakiness and the non-functional requirements

Merged line coverage must stay at or above 90%, and `scripts/coverage.py`
fails the build below it, in CI and locally alike. The floor sits well under
the real figure on purpose: a threshold just below today's number fails on the
next honest refactor and teaches everyone to lower it, while one well below it
still catches a whole subsystem arriving without tests. Branch coverage is
reported but not gated. The
[test coverage]({{< ref "/dotnet/test-coverage" >}}) page explains how the
numbers are produced.

Every run writes a `.trx` result file, so a test that fails once is recorded
by name instead of only as a count on the console. To catch a test that fails
only sometimes, `scripts/flake_hunt.py --runs 25` repeats the whole suite and
collects the names of every test that failed.

Non-functional requirements get the same treatment as use cases: each one
states how it is verified, by a **test** that fails the build, by
**inspection** of the code or configuration, or by a **measurement** whose
figure is published. A requirement with no method is not a requirement yet.

## Coding style

### One `.editorconfig`

Formatting is not discussed in reviews, because the `.editorconfig` at the
repository root settles it and the IDE applies it. The settings that shape how
the code looks:

| Setting | Effect |
| --- | --- |
| `indent_size = 4`, spaces | Four spaces, never tabs; two for XML and YAML |
| `csharp_new_line_before_open_brace = all` | Allman style: every opening brace on its own line |
| `csharp_style_var_* = true` | `var` everywhere a local is declared |
| `dotnet_style_predefined_type_* = true` | `string` and `int`, not `String` and `Int32` |
| `dotnet_style_qualification_* = false` | No `this.` |
| `csharp_using_directive_placement = outside_namespace` | `using` directives at the top, `System` first |
| `csharp_style_prefer_switch_expression = true` | Switch expressions over switch statements |
| Private fields `_camelCase`, constants `PascalCase` | Naming rules, as suggestions |
| `insert_final_newline`, `trim_trailing_whitespace` | No noise in diffs |

### The language features I lean on

- **File-scoped namespaces** (`namespace ArturRios.Heimdall.Command.Handlers;`),
  matching the folder.
- **Primary constructors for dependency injection.** Handlers, controllers and
  test classes take their dependencies in the class declaration and use them
  directly, with no private fields to assign.
- **Collection expressions**: `OwnerIds = [owner.PublicId]`,
  `Owners = [.. owners.Select(...)]`.
- **Switch expressions** for rules with one answer per case:

  ```csharp
  private static bool MayView(GetScopeByIdQuery query, ScopeProjection scope) => query.ActingRole switch
  {
      (int)Roles.SystemAdmin => true,
      (int)Roles.ScopeAdmin => scope.Output.OwnerIds.Contains(query.ActingPersonId),
      (int)Roles.User => scope.ActorBelongsToScope,
      _ => false
  };
  ```

  The `_ => false` is part of the rule: a role added later is denied by
  default rather than inheriting access.
- **Nullable reference types** on in every project, so `string?` means "may be
  missing" and the compiler checks it. Non-nullable strings start as
  `string.Empty` and collections as empty lists, never `null`.
- **Guard clauses and early returns**, always with braces, and a blank line
  after each block, so the main flow reads down the left margin.

### Names that say the role

A class's name tells you its job and where it lives:

| Kind | Pattern | Example |
| --- | --- | --- |
| Command | `<Verb><Noun>Command` | `CreateScopeCommand` |
| Its handler, validator and output | `…CommandHandler`, `…CommandValidator`, `…CommandOutput` | `CreateScopeCommandHandler` |
| Query | `Get<Noun>ByIdQuery`, `List<Nouns>Query` | `GetScopeByIdQuery`, `ListScopesQuery` |
| Messages and their map | `<Area>Messages`, `<Area>MessageMap` | `ScopeMessages`, `ScopeMessageMap` |
| Entity map | `<Entity>DbMap` | `ScopeDbMap` |
| Controller | `<Resource>Controller`, route `api/<resources>` | `ScopeController`, `api/scopes` |
| Tables | singular snake case, in the product's schema | `scope`, `scope_owner` |

Parameters and locals are full words (`command`, `owner`, `validation`), and
lambdas name their parameter after what it is (`failure => failure.ErrorMessage`,
`owner => owner.PublicId`), except the shortest query predicates, which use
`x`.

### Comments that cite the specification

Every public type and member has an XML documentation comment, and the
comments do two jobs that the code cannot do on its own.

The first is **traceability**. Comments name the use case, flow or
requirement a piece of code implements (`UC-01`, `AF-01a`, `FR-SC-08`,
`NFR-10`), so every line can be followed back to the reason it exists, and a
search for an identifier finds the code that implements it:

```csharp
/// <summary>
///     Handles <see cref="CreateScopeCommand" /> (UC-01): validates the request, verifies the scope
///     name is unique and every owner is an existing, non-logically-deleted administrator — a
///     <c>ScopeAdmin</c> or a <c>SystemAdmin</c> (FR-SC-08) — then
///     persists the scope together with a <c>SCOPE_OWNER</c> row for each owner. All failures are
///     returned as errors on the <see cref="DataOutput{T}" /> rather than thrown, using the canonical
///     <see cref="ScopeMessages" /> so the response resolver can pick the matching status code.
/// </summary>
```

The second is **why, not what**. A comment never repeats what the line below
says. It explains a decision that the code alone cannot: why a package is
referenced although another one already brings it, why a field is `bool?`
instead of `bool` (so that an omitted value is refused rather than read as
`false`), why one persistence error is deliberately left unmapped. When
something is missing on purpose, such as a validator, a comment says so, so
the next reader does not "fix" it.

### Commits, changelog and versions

Commit messages follow
[Conventional Commits](https://www.conventionalcommits.org/) with a lowercase
subject: `feat: let a data subject export their own data`,
`fix: block the last system admin's erasure`. Every change an API client or an
operator would notice gets an entry under `## [Unreleased]` in
`CHANGELOG.md`, in the same pull request that makes it.

Versions follow [Semantic Versioning](https://semver.org/), with the public
surface spelled out: the HTTP contract (routes, bodies, status codes,
messages, token claims, the roles allowed on each endpoint), the configuration
a deployment provides, and the database it keeps. Removing a field or
renaming an environment variable is a major version, and its changelog entry
says how to upgrade. The version is never stored in the source; it is the name
of the release branch.

## Around the code

A few habits sit outside the solution but are part of how every API is built:

- **Migrations are applied explicitly.** The API never migrates itself on
  start-up, and refuses to start if a migration is pending. Locally,
  `scripts/migrations.py` lists, creates and applies them; in deployment, the
  container's entry point runs a migrations bundle before the API starts.
- **The OpenAPI document is generated and committed.** A small tool writes
  `docs/openapi/heimdall.json` from the same Swagger configuration the API
  uses, and a CI check fails if the committed file is out of date, so the
  published reference can never describe an older API.
- **CI checks more than the tests.** It scans dependencies for known
  vulnerabilities, builds in Release, runs each test category, enforces the
  coverage floor, and builds the Docker image, so a change that breaks the
  image is caught before it reaches a deploy.
- **Every use case ships alone.** One use case, one issue, one `feature/`
  branch, one pull request into `develop`, merged only when every test, old and
  new, passes.

## Why it works

None of these patterns is unusual on its own. What makes them work is that
they are applied everywhere, without exceptions. Each one removes a decision
from the moment of writing code: where the file goes, how an error reaches the
client, what a test is called, which flows it must cover. With those settled,
the work that is left on each use case is the part that is actually new, its
rules, and every one of them can be traced from the specification to the
handler that implements it and the test that proves it.
