---
title: "EF Core or Dapper? Two Ways to Talk to a Database from .NET"
description: "EF Core maps a model of your classes to the database and writes the SQL for you; Dapper runs the SQL you write and maps the rows to objects. Here is how each one works inside, what an ORM is for, the change tracker and entity states, the performance traps of N+1 queries, tracking and cartesian explosion shown with real SQL, bulk updates, raw SQL, parameters and SQL injection, a short history of both, and how to choose between them or use them together."
date: 2026-10-21T13:00:00Z
categories: [".NET"]
tags: [".NET", "C#", "EF Core", "Dapper", "ORM", "SQL", "Databases", "Performance"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Almost every .NET application that stores data ends up choosing how its C#
code will talk to a relational database. Two names come up more than any
other. **Entity Framework Core** is Microsoft's object-relational mapper: you
describe your classes, and it writes the SQL, tracks what you change and
evolves the schema. **Dapper** is a small library from Stack Overflow: you
write the SQL, and it turns the rows that come back into objects.

The usual framing is "productivity versus performance", and that is not wrong,
but it hides most of what matters. The real differences are who writes the
SQL, who remembers what changed, and how much you can see of what reaches the
database. This article looks at both from the inside, shows the SQL each one
actually sends, and ends with when to use which, and why many projects use
both.

Every SQL statement and every line of output below comes from a real run on 21
October 2026: a console app on the .NET 10 SDK (10.0.400) with
`Microsoft.EntityFrameworkCore.Sqlite` 10.0.13, `Dapper` 2.1.89 and
`Microsoft.Data.Sqlite` 10.0.13, against a SQLite file. EF Core's logging was
filtered to print only the text of each command, so parameter values and
timings are not shown, and repeated blank lines are trimmed.

## What an ORM is

**An object-relational mapper (ORM) is a library that moves data between
objects in a program and rows in a relational database, so that code can work
with classes and references while the database works with tables, keys and
joins. A full ORM also tracks changes to the objects and writes the
corresponding `INSERT`, `UPDATE` and `DELETE` statements; a micro-ORM only
maps query results to objects.**

The two sides do not line up neatly. Objects have identity, references and
inheritance; tables have keys, foreign keys and set-based operations. Martin
Fowler sums up the cost of bridging them: "The object/relational mapping
problem is hard", because it means "synchronizing between two quite different
representations of data".[^fowler] That gap is often called the
object-relational impedance mismatch. EF Core and Dapper choose very different
amounts of it to hide.

EF Core's documentation describes what it does as an O/RM: it "enables .NET
developers to work with a database using .NET objects" and "eliminates the
need for most of the data-access code that typically needs to be
written".[^efoverview] Dapper's README describes itself in one line, "a simple
object mapper for .Net", that enhances ADO.NET connections "via extension
methods on your `DbConnection` instance".[^dapper]

{{< diagram src="pipelines.svg" caption="EF Core translates a LINQ expression tree into SQL and passes the results through a materialiser and the change tracker. Dapper runs the SQL you wrote and maps the rows with a mapper it generates and caches per query." >}}

## The model used in this article

Three entity types: a blog has posts and contributors. The same classes serve
both libraries.

```csharp
public class Blog
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public bool IsActive { get; set; }
    public virtual List<Post> Posts { get; set; } = [];
    public virtual List<Contributor> Contributors { get; set; } = [];
}

public class Post
{
    public int Id { get; set; }
    public string Title { get; set; } = "";
    public int BlogId { get; set; }
    public virtual Blog Blog { get; set; } = null!;
}

public class Contributor
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public int BlogId { get; set; }
}

public class BlogContext : DbContext
{
    public DbSet<Blog> Blogs => Set<Blog>();
    public DbSet<Post> Posts => Set<Post>();

    protected override void OnConfiguring(DbContextOptionsBuilder options)
        => options.UseSqlite("Data Source=blogs.db");
}
```

The database holds three blogs, `Blog 1` to `Blog 3`, each with two posts and
three contributors; `Blog 3` is inactive. The navigations are `virtual` only so
that the lazy loading example further down can work.

## EF Core: how it works

### The model and its conventions

EF Core builds a *model* from your classes the first time a context is used:
which classes are entities, which property is the key, which are
relationships. Most of it comes from conventions. A property called `Id` is
the key, `BlogId` next to a `Blog` navigation is a foreign key, and a
`List<Post>` is a one-to-many relationship. Attributes or the fluent API in
`OnModelCreating` override any of it. Asking EF Core for the schema it would
create shows the result:

```txt
$ dotnet run -- schema
CREATE TABLE "Blogs" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_Blogs" PRIMARY KEY AUTOINCREMENT,
    "Name" TEXT NOT NULL,
    "IsActive" INTEGER NOT NULL
);

CREATE TABLE "Contributor" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_Contributor" PRIMARY KEY AUTOINCREMENT,
    "Name" TEXT NOT NULL,
    "BlogId" INTEGER NOT NULL,
    CONSTRAINT "FK_Contributor_Blogs_BlogId" FOREIGN KEY ("BlogId") REFERENCES "Blogs" ("Id") ON DELETE CASCADE
);

CREATE TABLE "Posts" (
    "Id" INTEGER NOT NULL CONSTRAINT "PK_Posts" PRIMARY KEY AUTOINCREMENT,
    "Title" TEXT NOT NULL,
    "BlogId" INTEGER NOT NULL,
    CONSTRAINT "FK_Posts_Blogs_BlogId" FOREIGN KEY ("BlogId") REFERENCES "Blogs" ("Id") ON DELETE CASCADE
);

CREATE INDEX "IX_Contributor_BlogId" ON "Contributor" ("BlogId");

CREATE INDEX "IX_Posts_BlogId" ON "Posts" ("BlogId");
```

Conventions explain every detail. Tables with a `DbSet` take its name
(`Blogs`, `Posts`), while `Contributor`, reachable only through a navigation,
takes the class name. Non-nullable reference types become `NOT NULL`, required
relationships cascade on delete, and every foreign key gets an index. None of
that was written by hand, which is the productivity argument for EF Core in
one listing, and also the reason to read what it generates.

### LINQ in, SQL out

Queries are written in LINQ against `DbSet<T>`, which is an `IQueryable<T>`.
The lambdas are not compiled into delegates but into *expression trees*, data
structures describing the code, which the database provider translates into
SQL. `ToQueryString` shows the translation without running it:

```csharp
var query = db.Blogs
    .Where(b => b.IsActive)
    .OrderBy(b => b.Name)
    .Select(b => new { b.Id, b.Name });
Console.WriteLine(query.ToQueryString());
```

```txt
$ dotnet run -- query
SELECT "b"."Id", "b"."Name"
FROM "Blogs" AS "b"
WHERE "b"."IsActive"
ORDER BY "b"."Name"
```

The projection reached the database: only `Id` and `Name` are selected. EF
Core caches each translation by the *shape* of the expression tree, so running
the same query again with different parameter values skips the translation
work.[^efperfadv] `ToQueryString` and the `LogTo` method used throughout this
article both arrived in EF Core 5.0.[^ef5]

### The `DbContext` as a unit of work

A `DbContext` is a session with the database. Each instance "tracks changes
made to entities", and those tracked entities "drive the changes to the
database when `SaveChanges` is called". The documentation is explicit about
lifetime: a `DbContext` "is designed to represent a short-lived
unit-of-work". Create it, load and change some entities, save, and dispose
it.[^efchange] In ASP.NET Core that usually means one context per request.

### The change tracker and entity states

Every entity a context knows about has a state:[^efchange]

| State | Tracked | Exists in database | On `SaveChanges` |
|---|---|---|---|
| `Detached` | No | – | Nothing |
| `Added` | Yes | No | `INSERT` |
| `Unchanged` | Yes | Yes | Nothing |
| `Modified` | Yes | Yes | `UPDATE` of the changed columns |
| `Deleted` | Yes | Yes | `DELETE` |

{{< diagram src="entity-states.svg" caption="A tracking query or `Add` brings an entity under tracking; editing or removing it changes its state; `SaveChanges` writes the change and moves it on." >}}

Watching the states change in one unit of work:

```csharp
var blog = db.Blogs.Include(b => b.Posts).First(b => b.Name == "Blog 1");
Console.WriteLine($"after query:     {db.Entry(blog).State}");

blog.Name = "Blog One";                                   // edit
var post = new Post { Title = "Post 1.3" };
blog.Posts.Add(post);                                     // insert
var old = blog.Posts.First(p => p.Title == "Post 1.1");
db.Posts.Remove(old);                                     // delete
// … the state of each entity is printed after each step …

Console.WriteLine(db.ChangeTracker.DebugView.ShortView);
db.SaveChanges();
Console.WriteLine($"after save:      {db.Entry(blog).State}, {db.Entry(post).State}, {db.Entry(old).State}");
```

```txt
$ dotnet run -- tracking
after query:     Unchanged
after edit:      Modified
new post:        Added
removed post:    Deleted

Blog {Id: 1} Modified
Post {Id: -2147482641} Added FK {BlogId: 1}
Post {Id: 1} Deleted FK {BlogId: 1}
Post {Id: 2} Unchanged FK {BlogId: 1}

UPDATE "Blogs" SET "Name" = @p0
WHERE "Id" = @p1
RETURNING 1;

DELETE FROM "Posts"
WHERE "Id" = @p0
RETURNING 1;

INSERT INTO "Posts" ("BlogId", "Title")
VALUES (@p0, @p1)
RETURNING "Id";

after save:      Unchanged, Unchanged, Detached
AsNoTracking:    Detached
```

A few details are worth reading closely. The new post has a temporary negative
key until the database assigns a real one, which `RETURNING "Id"` brings back.
The `UPDATE` sets only `Name`, because EF Core "tracks changes at the property
level".[^efchange] After saving, the deleted post is no longer tracked at all.
The new post was found without calling `Add`: adding it to a tracked blog's
collection was enough, because entities "detected as new entities connected to
existing tracked entities" become tracked too.[^efchange]

### Migrations

A model changes as an application grows, and the database must follow.
Migrations "incrementally update the database schema to keep it in sync with
the application's data model while preserving existing data". `dotnet ef
migrations add <Name>` compares the model with a snapshot of the previous one
and generates a migration file; `dotnet ef database update` applies it, and EF
Core "records all applied migrations in a special history table". The
documentation recommends the tools for local development, and a migration
bundle or a reviewed SQL script for deployments.[^efmigrations] This demo
uses `EnsureCreated` instead, which creates the schema directly and is meant
only for quick experiments.

## EF Core: the performance traps

None of these are bugs in EF Core. Each comes from a convenience that hides a
round trip or a row count, and each is visible the moment you look at the SQL.

### N+1 queries

The classic: load a list, then run one more query for each item in it.

```csharp
foreach (var blog in db.Blogs.AsNoTracking().ToList())
{
    var count = db.Posts.Count(p => p.BlogId == blog.Id);
}
```

```txt
$ dotnet run -- nplus1
// one query per blog
SELECT "b"."Id", "b"."IsActive", "b"."Name"
FROM "Blogs" AS "b"

SELECT COUNT(*)
FROM "Posts" AS "p"
WHERE "p"."BlogId" = @blog_Id

SELECT COUNT(*)
FROM "Posts" AS "p"
WHERE "p"."BlogId" = @blog_Id

SELECT COUNT(*)
FROM "Posts" AS "p"
WHERE "p"."BlogId" = @blog_Id

// one query with a projection
SELECT "b"."Name", (
    SELECT COUNT(*)
    FROM "Posts" AS "p"
    WHERE "b"."Id" = "p"."BlogId") AS "Posts"
FROM "Blogs" AS "b"

Blog 1: 2
Blog 2: 2
Blog 3: 2
```

Three blogs cost four round trips; three thousand would cost three thousand
and one. The fix asks for the counts in the same query, with
`db.Blogs.Select(b => new { b.Name, Posts = b.Posts.Count })`, and EF Core
turns it into a correlated subquery.

**Lazy loading** produces the same pattern without any visible query. With the
`Microsoft.EntityFrameworkCore.Proxies` package and `UseLazyLoadingProxies()`,
EF Core loads a `virtual` navigation the first time it is touched:[^eflazy]

```txt
$ dotnet run -- lazy
SELECT "b"."Id", "b"."IsActive", "b"."Name"
FROM "Blogs" AS "b"

SELECT "p"."Id", "p"."BlogId", "p"."Title"
FROM "Posts" AS "p"
WHERE "p"."BlogId" = @p

Blog 1: 2 posts
SELECT "p"."Id", "p"."BlogId", "p"."Title"
FROM "Posts" AS "p"
WHERE "p"."BlogId" = @p

Blog 2: 2 posts
SELECT "p"."Id", "p"."BlogId", "p"."Title"
FROM "Posts" AS "p"
WHERE "p"."BlogId" = @p

Blog 3: 2 posts
commands: 4
```

The loop body only reads `blog.Posts.Count`, yet each iteration runs a query.
The EF Core documentation warns that lazy loading "can cause unneeded extra
database roundtrips to occur (the so-called N+1 problem)" and, because it makes
that so easy to trigger, recommends avoiding it in favour of eager or
explicit loading.[^eflazy][^efquerying] In EF Core it is off unless you
install the package and opt in.

**Eager loading** with `Include` fetches the posts in the same query:

```txt
$ dotnet run -- include
SELECT "b"."Id", "b"."IsActive", "b"."Name", "p"."Id", "p"."BlogId", "p"."Title"
FROM "Blogs" AS "b"
LEFT JOIN "Posts" AS "p" ON "b"."Id" = "p"."BlogId"
ORDER BY "b"."Id"

Blog 1: 2 posts
Blog 2: 2 posts
Blog 3: 2 posts
commands: 1
```

### Tracking what you only read

By default, queries that return entities are tracking queries: EF Core keeps a
snapshot of each entity and checks the change tracker for an existing
instance with the same key, which is called *identity resolution*. For data
that will only be displayed, that is wasted work. No-tracking queries "are
generally quicker to execute because there's no need to set up the change
tracking information", and `AsNoTracking()` turns tracking off for one
query.[^eftracking] In the last line of the tracking run above, the blog
loaded with `AsNoTracking` was `Detached`. EF Core's own benchmark, loading 10
blogs with 20 posts each, measured the no-tracking query at 0.71 of the
tracking query's time and about 61% of its memory.[^efquerying] The opposite
default is available too: `UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking)`
makes every query no-tracking unless it says `AsTracking()`.[^eftracking]

### Cartesian explosion

Including two collections at the same level joins both into one result set.
The database then returns every combination of the two:

```txt
$ dotnet run -- split
// single query
SELECT "b"."Id", "b"."IsActive", "b"."Name", "p"."Id", "p"."BlogId", "p"."Title", "c"."Id", "c"."BlogId", "c"."Name"
FROM "Blogs" AS "b"
LEFT JOIN "Posts" AS "p" ON "b"."Id" = "p"."BlogId"
LEFT JOIN "Contributor" AS "c" ON "b"."Id" = "c"."BlogId"
ORDER BY "b"."Id", "p"."Id"

// rows returned by the join: 18
// split query
SELECT "b"."Id", "b"."IsActive", "b"."Name"
FROM "Blogs" AS "b"
ORDER BY "b"."Id"

SELECT "p"."Id", "p"."BlogId", "p"."Title", "b"."Id"
FROM "Blogs" AS "b"
INNER JOIN "Posts" AS "p" ON "b"."Id" = "p"."BlogId"
ORDER BY "b"."Id"

SELECT "c"."Id", "c"."BlogId", "c"."Name", "b"."Id"
FROM "Blogs" AS "b"
INNER JOIN "Contributor" AS "c" ON "b"."Id" = "c"."BlogId"
ORDER BY "b"."Id"
```

Each blog has 2 posts and 3 contributors, and the single query returns
2 × 3 = 6 rows per blog, 18 in all, each repeating the blog's columns. The
documentation's example makes the growth plain: a blog with 10 posts and 10
contributors returns 100 rows. This is "sometimes called *cartesian
explosion*".[^efsplit] With numbers that small the split query returns as many
rows in total (3 + 6 + 9), but it grows as a sum instead of a product: 1 + 10
+ 10 rows for that larger blog.

`AsSplitQuery()`, added in EF Core 5.0, loads each collection in its own
query.[^ef5] It is not free. The documentation lists the costs: no
consistency guarantee between the queries if data changes in between, an
extra round trip per query, and buffering of earlier results on most
databases. EF Core still uses single queries by default, and logs a warning
when a query loads several collections without saying which mode it
wants.[^efsplit]

### Client evaluation

Not every C# expression can become SQL. Before version 3.0, EF Core quietly
ran untranslatable parts of a query in memory, which could mean downloading a
whole table to filter it. Since 3.0, it only does so in the *top-level
projection*, the final `Select`; anywhere else, "it throws a runtime
exception".[^efclienteval] A helper method shows both cases:

```csharp
public static class Text
{
    public static string Shout(string s) => s.ToUpperInvariant() + "!";
}

db.Blogs.OrderBy(b => b.Id).Select(b => Text.Shout(b.Name)).ToList();   // allowed
db.Blogs.Where(b => Text.Shout(b.Name) == "BLOG 1!").ToList();          // throws
```

```txt
$ dotnet run -- client
top-level Select: BLOG 1!, BLOG 2!, BLOG 3!
InvalidOperationException: The LINQ expression 'DbSet<Blog>()
    .Where(b => Text.Shout(b.Name) == "BLOG 1!")' could not be translated. Additional information: Translation of method 'Text.Shout' failed. If this method can be mapped to your custom function, see https://go.microsoft.com/fwlink/?linkid=2132413 for more information. Either rewrite the query in a form that can be translated, or switch to client evaluation explicitly by inserting a call to 'AsEnumerable', 'AsAsyncEnumerable', 'ToList', or 'ToListAsync'. See https://go.microsoft.com/fwlink/?linkid=2101038 for more information.
```

The exception appears when the query runs, not when it compiles: the C#
compiler only sees a valid expression tree. That is why queries need tests
against a real database provider.

## EF Core: when the defaults are not enough

### Bulk updates and deletes

`SaveChanges` updates rows one entity at a time, after loading them. EF Core
7.0 added `ExecuteUpdate` and `ExecuteDelete`, which "update or delete
entities in the database based on the results of" a LINQ query, in a single
statement.[^ef7]

```csharp
db.Blogs.Where(b => !b.IsActive)
    .ExecuteUpdate(s => s.SetProperty(b => b.Name, b => b.Name + " (archived)"));
db.Posts.Where(p => p.Blog.Name.EndsWith("(archived)")).ExecuteDelete();
```

```txt
$ dotnet run -- bulk
UPDATE "Blogs" AS "b"
SET "Name" = "b"."Name" || ' (archived)'
WHERE NOT ("b"."IsActive")

rows updated: 1
DELETE FROM "Posts" AS "p"
WHERE "p"."Id" IN (
    SELECT "p0"."Id"
    FROM "Posts" AS "p0"
    INNER JOIN "Blogs" AS "b" ON "p0"."BlogId" = "b"."Id"
    WHERE "b"."Name" LIKE '%(archived)'
)

rows deleted: 2
```

Nothing was loaded and nothing was tracked. That is the point, and also the
catch: these methods "are completely unaware of EF's change tracker", so a
tracked entity keeps its old values and a later `SaveChanges` can overwrite
the bulk change. They also do not start a transaction of their own, and they
only work with relational providers.[^efbulk]

### Raw SQL

When LINQ cannot express a query, or translates it badly, `FromSql` (EF Core
7.0; `FromSqlInterpolated` before that) starts a query from SQL you
write.[^efsql] It looks like string interpolation, but it is not:

```csharp
var name = "Blog 2";
var blogs = db.Blogs
    .FromSql($"SELECT * FROM Blogs WHERE Name = {name}")
    .Include(b => b.Posts)
    .ToList();
```

```txt
$ dotnet run -- fromsql
SELECT "b"."Id", "b"."IsActive", "b"."Name", "p"."Id", "p"."BlogId", "p"."Title"
FROM (
    SELECT * FROM Blogs WHERE Name = @p0
) AS "b"
LEFT JOIN "Posts" AS "p" ON "b"."Id" = "p"."BlogId"
ORDER BY "b"."Id"

Blog 2: 2 posts
```

`{name}` became the parameter `@p0`: "the supplied value is wrapped in a
`DbParameter`", which "makes FromSql safe from SQL injection attacks". EF Core
also wrapped the SQL in a subquery so that `Include` could compose over it. The
documentation reserves its warnings for `FromSqlRaw`, which inserts strings as
they are and is only for dynamic SQL such as a column name chosen at
runtime.[^efsql]

### Compiled queries

For very hot queries, `EF.CompileQuery` and `EF.CompileAsyncQuery` turn a
LINQ query into a delegate once, which "bypasses the cache lookup" EF Core
otherwise does on every execution:[^efperfadv]

```csharp
var byName = EF.CompileQuery((BlogContext ctx, string n) => ctx.Blogs.Single(b => b.Name == n));
Console.WriteLine(byName(db, "Blog 2").Name);
```

```txt
$ dotnet run -- compiled
SELECT "b"."Id", "b"."IsActive", "b"."Name"
FROM "Blogs" AS "b"
WHERE "b"."Name" = @n
LIMIT 2

Blog 2
```

The `LIMIT 2` is how `Single` works: EF Core asks for two rows so that it can
throw if there is more than one. The gain from compiling is real but small,
and the same page is clear about where time usually goes: "network latency and
database I/O will usually dominate any time spent inside EF Core
itself".[^efperfadv]

## Dapper: how it works

Dapper adds extension methods to an ADO.NET connection. You write the SQL,
pass parameters as an object, and get typed results back:

```csharp
using var connection = new SqliteConnection("Data Source=blogs.db");

var blogs = connection.Query<Blog>(
    """
    SELECT Id, Name, IsActive
    FROM Blogs
    WHERE IsActive = @isActive
    ORDER BY Name;
    """,
    new { isActive = true });
foreach (var b in blogs) Console.WriteLine($"{b.Id} {b.Name} {b.IsActive}");
```

```txt
$ dotnet run -- dapper
1 Blog 1 True
2 Blog 2 True
```

Each property of the anonymous object becomes a parameter with the same name.
The first time a query runs, Dapper generates a mapping function for that SQL
and result type and caches it, which is where its speed comes from; the README
notes that "Dapper caches information about every query it runs".[^dapper]
There is no model, no change tracker and no SQL generation. The README is
candid that "Dapper's simplicity means that many features that ORMs ship with
are stripped out".[^dapper]

Dapper "has no DB specific implementation details": it works with any ADO.NET
provider, from SQLite and PostgreSQL to SQL Server and Oracle.[^dapper] The
SQL dialect is yours to manage.

### The core methods

| Method | Use |
|---|---|
| `Query<T>` / `QueryAsync<T>` | Several rows mapped to `T` |
| `QueryFirst`, `QuerySingle` and their `OrDefault` variants | One row |
| `QueryMultiple` | Several result sets from one command |
| `Execute` / `ExecuteAsync` | Commands that return no rows; returns the affected count |
| `ExecuteScalar<T>` | A single value |

### Multi-mapping

Dapper can split one row into several objects. It assumes each object starts
at a column named `Id`, and `splitOn` names a different column when
needed:[^dapper]

```csharp
var posts = connection.Query<Post, Blog, Post>(
    """
    SELECT p.Id, p.Title, p.BlogId, b.Id, b.Name, b.IsActive
    FROM Posts p JOIN Blogs b ON b.Id = p.BlogId
    WHERE b.Id = @id;
    """,
    (post, blog) => { post.Blog = blog; return post; },
    new { id = 1 },
    splitOn: "Id");
```

```txt
// multi-mapping
Post 1.1 in Blog 1
Post 1.2 in Blog 1
```

The mapping function wires the objects together. Note that each row gets its
own `Blog` instance: there is no identity resolution unless you build it, for
example with a dictionary keyed by `Id`.

### Several results, lists and buffering

`QueryMultiple` reads "multiple result grids in a single query", which saves
round trips. Passing a collection as a parameter expands it into an `IN`
list:[^dapper]

```csharp
using var grid = connection.QueryMultiple(
    """
    SELECT COUNT(*) FROM Blogs;
    SELECT COUNT(*) FROM Posts;
    """);
Console.WriteLine($"blogs={grid.ReadSingle<int>()} posts={grid.ReadSingle<int>()}");

var rows = connection.Execute(
    "UPDATE Blogs SET IsActive = @active WHERE Id IN @ids;",
    new { active = false, ids = new[] { 1, 2 } });
```

```txt
// QueryMultiple
blogs=3 posts=6
// Execute
rows updated: 2
```

By default, "Dapper's default behavior is to execute your SQL and buffer the
entire reader on return": `Query` returns a fully loaded list and the
connection is free again. For very large results, `buffered: false` streams
rows one at a time instead.[^dapper]

## Parameters and SQL injection

The one rule that matters more than any choice of library: never build SQL by
concatenating user input. SQL injection exploits "dynamic database queries
that use string concatenation and user-supplied input", and the first defence
OWASP lists is prepared statements with parameterised queries, with which "the
database will always distinguish between code and data".[^owasp] The
difference, in the same database:

```csharp
var input = "x' OR '1'='1";
var unsafeCount = connection.ExecuteScalar<int>(
    $"SELECT COUNT(*) FROM Blogs WHERE Name = '{input}'");          // never do this
var safeCount = connection.ExecuteScalar<int>(
    "SELECT COUNT(*) FROM Blogs WHERE Name = @input", new { input });
```

```txt
$ dotnet run -- injection
concatenated: 3 rows
parameterised: 0 rows
```

No blog is named `x' OR '1'='1`, yet the concatenated query matched all three,
because the input closed the string and added a condition that is always true.
Parameterised, it is just an odd name that matches nothing. EF Core
parameterises LINQ and `FromSql` for you, so the risk there is limited to
`FromSqlRaw` and `ExecuteSqlRaw`. With Dapper every query is hand-written, so
the discipline is entirely yours, and Dapper makes the safe form the easy one.

## Side by side

| | EF Core | Dapper |
|---|---|---|
| Abstraction | A model of entities, relationships and a change tracker | Extension methods on a connection |
| Who writes queries | You write LINQ; the provider writes SQL | You write SQL |
| Inserts and updates | `SaveChanges` works out the SQL; `ExecuteUpdate`/`ExecuteDelete` for bulk | You write each command |
| Relationships | First-class: `Include`, navigations, fix-up | Multi-mapping by hand |
| Identity resolution | Yes, in tracking queries | No |
| Schema evolution | Migrations | Not provided; use a separate tool |
| Raw SQL | `FromSql`, `SqlQuery`, `ExecuteSql` | Always |
| Database portability | The provider adapts LINQ to each database | Your SQL, your dialect |
| Overhead | Translation (cached), materialisation, tracking (optional) | Very small |
| Main risks | Hidden round trips, over-fetching, untranslatable queries | Hand-written SQL to maintain and keep injection-safe |

## Choosing, and using both

**EF Core is a sensible default** for an application with a real domain
model: many entity types, relationships, business rules that load an object,
change it and save it, and a schema that will evolve. The change tracker and
migrations remove a great deal of repetitive code, and the traps above are
avoided by habit: project what you need, use `AsNoTracking` for reads, avoid
lazy loading, and look at the SQL. The EF Core documentation adds one point
that applies to any ORM: "Intermediate-level knowledge or higher of the
underlying database server is essential" in production.[^efoverview]

**Dapper fits** where the SQL is the point: reporting queries, dashboards and
search endpoints with hand-tuned joins, stored procedures, an existing
database whose schema you do not own, or a hot path where profiling has shown
that EF Core's overhead matters. It also suits teams who think in SQL and want
to read exactly what runs.

**Many projects use both.** EF Core owns the model, the migrations and the
writes; Dapper runs a handful of read-heavy queries over the same database.
They can even share a connection: `db.Database.GetDbConnection()` returns the
ADO.NET connection EF Core is using, and Dapper's methods work on it. Before
reaching for Dapper for a single slow query, though, check whether a
projection, a split query, `FromSql` or `SqlQuery` fixes it inside EF Core.

## A short history

- **2008: Entity Framework.** The first version shipped with .NET Framework
  3.5 Service Pack 1 and Visual Studio 2008 SP1 in August 2008, with "basic
  O/RM support using the Database First workflow".[^efhistory]
- **2010–2013: EF grows up.** EF 4.0 with .NET Framework 4 in April 2010
  added POCO support and lazy loading; EF 4.1, the first release on NuGet in
  April 2011, brought `DbContext` and Code First; EF 4.3 added Code First
  Migrations in February 2012; and EF 6.0 in October 2013 became open source
  and fully independent of the .NET Framework.[^efhistory]
- **2011: Dapper.** Stack Overflow's pages were spending too much time in
  LINQ to SQL. In March 2011 Sam Saffron described a small mapper that could
  "act as a fast replacement for both compiled queries and ExecuteQuery
  methods" and that "does not do relationships and other bells and
  whistles".[^saffron] Dapper "was originally developed for and by Stack
  Overflow" and is open source under the Apache 2.0 licence.[^dapper][^dappernuget]
- **2016: EF Core.** EF Core 1.0 was released in June 2016, "based on a new
  codebase" and "designed as a more lightweight and extensible version of
  EF".[^efhistory]
- **2019–2022: the modern shape.** EF Core 3.0 restricted client evaluation
  to the top-level projection,[^efclienteval] 5.0 added split queries, simple
  logging and `ToQueryString`,[^ef5] and 7.0, released in November 2022, added
  `ExecuteUpdate`, `ExecuteDelete` and `FromSql`.[^ef7][^efsql]
- **Today.** EF Core releases follow .NET's: EF Core 10.0 targets .NET 10 and
  is supported until 10 November 2028, and EF Core 11.0 is scheduled for
  November 2026.[^efreleases] Dapper's current version is 2.1.89.[^dappernuget]

## Common misunderstandings

| Misunderstanding | What is actually true |
|---|---|
| "EF Core is slow." | Its own overhead is usually small next to network and database time. Slow EF Core code is nearly always N+1 queries, over-fetching or missing indexes, all visible in the SQL. |
| "Dapper is always faster." | It removes EF Core's overhead, not the database's. A bad query is just as slow when written by hand. |
| "Dapper is safe from SQL injection." | Only if you use parameters. It runs whatever SQL string you give it. |
| "EF Core's interpolated `FromSql` is string concatenation." | Interpolated values become `DbParameter`s. `FromSqlRaw` is the one that inserts text as it is. |
| "EF Core loads related data automatically." | Only with `Include`, a projection, explicit loading, or lazy loading, which is off unless you install the proxies package and opt in. |
| "`AsNoTracking` is always better." | It skips the change tracker, so it also skips identity resolution and saving changes. Use it for reads, not for entities you will update. |
| "`ExecuteUpdate` goes through `SaveChanges`." | It runs immediately as one SQL statement and never touches the change tracker. |
| "You have to choose one." | They work side by side on the same database, even on the same connection. |

## References

[^fowler]: Fowler, M. (2012, May 8). *OrmHate*. martinfowler.com. <https://martinfowler.com/bliki/OrmHate.html>

[^efoverview]: Microsoft. (n.d.). *Overview of Entity Framework Core*. Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/>

[^dapper]: DapperLib. (n.d.). *Dapper: A simple object mapper for .Net* [README]. GitHub. <https://github.com/DapperLib/Dapper>

[^efperfadv]: Microsoft. (n.d.). *Advanced performance topics*. EF Core documentation, Microsoft Learn. Sections "Compiled queries", "Query caching and parameterization" and "Reducing runtime overhead". <https://learn.microsoft.com/en-us/ef/core/performance/advanced-performance-topics>

[^ef5]: Microsoft. (n.d.). *What's new in EF Core 5.0*. Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-5.0/whatsnew>

[^efchange]: Microsoft. (n.d.). *Change tracking in EF Core*. Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/change-tracking/>

[^efmigrations]: Microsoft. (n.d.). *Migrations overview*. EF Core documentation, Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/>

[^eflazy]: Microsoft. (n.d.). *Lazy loading of related data*. EF Core documentation, Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/querying/related-data/lazy>

[^efquerying]: Microsoft. (n.d.). *Efficient querying*. EF Core documentation, Microsoft Learn. Sections "Beware of lazy loading" and "Tracking, no-tracking and identity resolution". <https://learn.microsoft.com/en-us/ef/core/performance/efficient-querying>

[^eftracking]: Microsoft. (n.d.). *Tracking vs. no-tracking queries*. EF Core documentation, Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/querying/tracking>

[^efsplit]: Microsoft. (n.d.). *Single vs. split queries*. EF Core documentation, Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/querying/single-split-queries>

[^efclienteval]: Microsoft. (n.d.). *Client vs. server evaluation*. EF Core documentation, Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/querying/client-eval>

[^ef7]: Microsoft. (n.d.). *What's new in EF Core 7.0*. Microsoft Learn. Section "ExecuteUpdate and ExecuteDelete (Bulk updates)". <https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-7.0/whatsnew>

[^efbulk]: Microsoft. (n.d.). *ExecuteUpdate and ExecuteDelete*. EF Core documentation, Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/saving/execute-insert-update-delete>

[^efsql]: Microsoft. (n.d.). *SQL queries*. EF Core documentation, Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/querying/sql-queries>

[^owasp]: OWASP Foundation. (n.d.). *SQL injection prevention cheat sheet*. OWASP Cheat Sheet Series. <https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html>

[^efhistory]: Microsoft. (n.d.). *Past releases of Entity Framework*. EF6 documentation, Microsoft Learn. <https://learn.microsoft.com/en-us/ef/ef6/what-is-new/past-releases>

[^saffron]: Saffron, S. (2011, March 30). *How I learned to stop worrying and write my own ORM*. <https://samsaffron.com/archive/2011/03/30/How+I+learned+to+stop+worrying+and+write+my+own+ORM>

[^dappernuget]: NuGet. (2026). *Dapper* 2.1.89 [Package]. Licence Apache-2.0. Retrieved October 21, 2026. <https://www.nuget.org/packages/Dapper/>

[^efreleases]: Microsoft. (n.d.). *EF Core releases and planning*. Microsoft Learn. <https://learn.microsoft.com/en-us/ef/core/what-is-new/>
