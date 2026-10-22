---
title: "Merlin: A Reading Tracker"
description: "An idea for an app to keep your readings: search books from a public database or scan their barcodes, track what you want to read, are reading, have read or gave up on, write private or public reviews, and import a Goodreads library, with a suggested technology stack around Flutter for Android and the web and accounts through Heimdall."
date: 2026-10-22T12:00:00Z
categories: ["Brainstorms"]
tags: ["Merlin", "Books", "Reading", "Flutter", "Open Library", "Heimdall", "Technology Stack"]
---

Merlin is an app to keep your readings.

## Features

- Search books from a public database
- Track the books you are reading now, and read on the past
- Write reviews on books

## Platforms

- Android
- Web

## Technology stack

One choice is already made: the app is built with Flutter, which builds the
Android app and the web app from one Dart code base. How Flutter works, and
what it is good and bad at, is covered in
[What Is Flutter?]({{< ref "/front-end/flutter" >}}). What is left to decide is
everything around it: where the books come from, where the readings and
reviews are stored, and how the two platforms see the same library.

The last question decides most of the stack. Android and the web are two
places to open the same library, so a book marked as finished on the phone
should be finished in the browser too. That needs an account, which
[Heimdall](https://artur-rios.github.io/heimdall-api/) provides, and a server
that holds each user's library. The server also searches the book database on
the app's behalf, for reasons covered under
[the public database](#the-public-database).

### The suggestion at a glance

| Concern | Choice | Why |
| --- | --- | --- |
| App | Flutter, in Dart | Already chosen; one code base for Android and the web. |
| Architecture | MVVM, as in Flutter's architecture guide | Views, view models, repositories and services, with `provider` for dependency injection, so there is no state management library to choose. |
| Navigation | go_router | Maintained by the Flutter team, with real URLs and a working back button on the web. |
| Models and JSON | freezed and json_serializable | Immutable models and generated JSON code, since Flutter has no runtime reflection. |
| Book data | Open Library | Open data, no API key, a lookup by ISBN and a covers API; see below. |
| Barcode scanning | mobile_scanner | Reads the EAN-13 barcode on a book's cover with the camera, on Android and in the browser. |
| Local storage | drift | SQLite for Dart, on Android and in the browser through WebAssembly, as an offline cache of the library. |
| Images | cached_network_image | Covers are downloaded once and kept on the device. |
| Server | ASP.NET Core with PostgreSQL | Holds each user's library, searches the book database, imports Goodreads exports and renders public reviews; shaped like Heimdall and Fortuna, as described in [How I Develop APIs]({{< ref "/dotnet/how-i-develop-apis" >}}). |
| Accounts | Heimdall | Sign-up, sign-in, Google Sign-In and two-factor authentication already exist there; see below. |
| Goodreads import | CsvHelper, in a background job on the server | Reads the export and matches each book against Open Library at a gentle pace. |
| Public reviews | Razor Pages on the server | Plain HTML pages that search engines and link previews can read. |
| Testing | flutter_test, integration_test and xUnit | Unit and widget tests for the app, end-to-end tests on a device and in the browser, and tests for the server. |

### Accounts with Heimdall

Merlin owns no passwords. Every account lives in Heimdall, the identity API that
Fortuna already uses, and Merlin follows the same pattern:

- **Merlin is a scope in Heimdall.** Its users belong to that scope and to no
  other system. The scope has **self-registration** enabled, so anyone can sign
  up with an email address and a password, and **Google Sign-In** enabled, so
  an Android user can sign in with the account already on the phone.
- **The app signs in through Merlin's server.** Merlin's API exposes the same
  `/api/auth/` endpoints Fortuna does, for sign-in, sign-up, Google, two-factor
  and password recovery, and forwards each one to Heimdall. The app talks to
  one host, and the web app calls its own origin, so the browser needs no CORS.
- **Tokens are checked without calling Heimdall.** Merlin validates each
  Heimdall token locally, by its signature, issuer, audience and expiry, so a
  request never waits on Heimdall. Heimdall signs its tokens with a shared
  secret today; Fortuna is already prepared for its planned move to public keys
  published as a key set, and Merlin should be too, so that in the end it holds
  no key that could issue tokens.
- **Merlin's records point at the Heimdall identity.** Readings and reviews
  store the user's Heimdall ID and nothing else about the person. A public
  review shows the reviewer's name, taken from the token, never the email
  address.

Two-factor authentication, password recovery and email verification come with
Heimdall, at no cost to Merlin. What Merlin still owns is its own data: when a
user asks for their data or for its erasure, Heimdall answers for the identity,
and Merlin has to export or erase that user's readings and reviews.

### The public database

Two public databases cover most books:

| Option | Strengths | Trade-off |
| --- | --- | --- |
| **Open Library** | Run by the Internet Archive, open data, no API key; separates a work from its editions; free covers | Uneven data for recent or non-English books, and it asks clients to keep request rates low |
| Google Books | Wide coverage of commercial titles, with descriptions and page counts | Needs an API key with a daily quota, and Google's terms limit how its data can be stored |

Open Library is the better default for an app that wants to keep what it
finds. Its model also fits Merlin well: a **work** is the book as written, such
as *The Hobbit*, and an **edition** is one printing of it, with its own ISBN,
publisher, page count and cover. A review is about the work; progress in pages
is about the edition in the reader's hands.

The app does not call Open Library directly. It calls Merlin's server, which
calls Open Library:

- **Open Library asks clients to identify themselves** with a `User-Agent`
  header naming the app and a contact, and a browser does not let a web app set
  that header.
- **Covers looked up by ISBN are rate limited**, to 100 requests per IP address
  every five minutes. Looked up by cover ID, they are not, so the server
  resolves each book's cover ID once and the app only ever asks for covers by
  ID.
- **Results are cached.** Popular searches and books are answered from
  PostgreSQL, which is faster for users and gentler on Open Library.
- **The source can change in one place.** The server talks to the book database
  through an interface, so Google Books could later fill gaps in Open Library's
  data without a new release of the app; this is the
  [dependency inversion principle]({{< ref "/concepts/dependency-inversion-principle" >}})
  applied to the data source.

When a user adds a book, the server copies its title, authors, cover ID and
edition details into the user's library. The library never depends on the
public database staying the same, and it opens without calling it.

### Adding a book

A book can be found in three ways, and all of them end on the same page, where
the user picks the edition and a shelf:

- **Search** by title or author, which returns works; the user then picks the
  edition they own, or the most common one.
- **Scan** the barcode on the back cover. A book's barcode is an EAN-13 that
  holds its ISBN-13, so the number the camera reads is the ISBN.
- **Type or paste** an ISBN. Merlin accepts ISBN-10 and ISBN-13, with or without
  hyphens and spaces, and finds the first ISBN in pasted text, such as a
  bookshop link or a line copied from a page. It checks the check digit before
  any lookup, so a typo is reported at once, and converts an ISBN-10 to its
  ISBN-13 form, so each edition has one key.

Scanning and typing both look the ISBN up with Open Library's edition lookup,
which returns the exact edition, and through it the work. An ISBN that Open
Library does not know can still be added by hand, with a title, authors and a
page count, and linked to an Open Library edition later.

### The data model

| Record | Holds |
| --- | --- |
| Book | One work: title, authors, Open Library work ID, cover ID |
| Edition | One edition of a book: ISBN, publisher, format, page count, Open Library edition ID |
| Reading | One time a user reads, or means to read, a book: the edition, shelf, dates and progress |
| Review | A rating from one to five stars, text, and whether it is private or public, written about one reading |

Every reading sits on one of four **shelves**:

| Shelf | Meaning | Dates |
| --- | --- | --- |
| To read | Books the user wants to read later | Added |
| Reading | Books the user is reading now | Added, started |
| Read | Books the user finished | Added, started, finished |
| Abandoned | Books the user gave up on | Added, started, abandoned, and the progress reached |

Keeping **readings** separate from **books** is what lets one table answer
"what am I reading now", "what did I read in the past" and "what is next", and
it allows re-reading: a book read twice has two readings, with two sets of
dates. Attaching each review to a reading keeps a second opinion of the same
book from overwriting the first, and the book's page can still show all of a
user's reviews of it together. A book given up on can be picked up again, which
starts a new reading.

**Progress is kept in pages and in percent.** The user updates whichever they
prefer, and Merlin shows both:

- For an edition with a page count, the two convert into each other, so moving
  to page 150 of 300 also shows 50%.
- For an e-book or an audiobook, which has no fixed page count, progress is in
  percent only, as the reading app or the audiobook player shows it.
- When the reader's copy has a different number of pages than the edition
  Merlin knows, the user can correct the page count on their reading, and the
  percentages follow.

### Importing from Goodreads

Goodreads exports a reader's library as a CSV file, with one row per book, and
Merlin's server imports it:

| Goodreads column | Becomes |
| --- | --- |
| `ISBN13`, `ISBN`, `Title`, `Author` | The edition, matched against Open Library |
| `Exclusive Shelf` | The shelf: `to-read`, `currently-reading` and `read` map to To read, Reading and Read |
| `Bookshelves` | Abandoned, for the custom shelf the user names as their "did not finish" shelf |
| `Date Added`, `Date Read` | The reading's dates |
| `My Rating`, `My Review` | A review, where `0` means no rating |
| `Number of Pages` | The page count, when Open Library has none |

A few details shape the importer:

- **The ISBN columns are written as spreadsheet formulas**, such as
  `="0140328726"`, so the importer strips them before reading the number, and
  many rows have no ISBN at all.
- **Rows without a usable ISBN are matched by title and author**, and the ones
  Merlin cannot match with confidence are listed for the user to resolve,
  rather than guessed.
- **Imported reviews are private.** The user publishes the ones they want to
  share, since a review written on Goodreads was not written for Merlin's
  public pages.
- **It runs in the background.** Matching hundreds of books at a pace that is
  gentle on Open Library takes minutes, so the server takes the file, answers
  at once, and reports progress until the import is done. Importing the same
  file again skips the books already imported.

Goodreads keeps one finish date per book, even for a book read more than once,
so a re-read imports as one reading with the latest date.

### Private and public reviews

Each review is **private** by default, seen only by its author, and the user can
make it **public**, or private again, at any time. A public review appears on
the book's page in Merlin for other users, with the reviewer's name and rating,
and has a link of its own that can be shared.

That link should not open the Flutter app. Flutter draws its web app into a
canvas rather than with HTML, so search engines and link previews see little of
it. A public review is a small page of text, so the server renders it as HTML
with Razor Pages, with the title, cover and preview tags a shared link needs,
and a button to open the book in Merlin. Making a review private again takes
its page down. The Flutter web app stays the signed-in library.

### Offline on Android

The library should open on a phone with no connection. drift keeps a copy of
the user's library on the device, and the app reads from it first:

- **Reads** come from the local database, refreshed from the server when the
  app opens and on pull to refresh.
- **Writes**, such as a new page number or a finished book, are saved locally
  and queued, then sent when the connection returns.
- **Conflicts** are rare, since a library belongs to one person. When two
  devices change the same reading, the later change to each field wins.

Searching for new books, looking up a scanned ISBN and publishing a review
still need a connection, since they go through the server.

## Decisions

The questions this brainstorm raised, and how they were settled:

- **An account is required from the first release**, and accounts live in
  Heimdall, which handles authentication and authorization.
- **Reviews are private or public, as the user chooses**, review by review.
- **There are four shelves**: to read, reading, read and abandoned.
- **Progress is tracked in both pages and percent.**
- **A Goodreads library can be imported** from its CSV export.
- **Books can be added by scanning the ISBN barcode**, and by typing or pasting
  the ISBN.
