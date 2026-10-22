---
title: "Merlin: A Reading Tracker"
description: "An idea for an app to keep your readings: search books from a public database, track what you are reading now and what you have read, and write reviews, with a suggested technology stack around Flutter for Android and the web."
date: 2026-10-22T12:00:00Z
categories: ["Brainstorms"]
tags: ["Merlin", "Books", "Reading", "Flutter", "Open Library", "Technology Stack"]
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

The second question decides most of the stack. Android and the web are two
places to open the same library, so a book marked as finished on the phone
should be finished in the browser too. That needs an account and a server that
holds each user's library. The suggestion below includes one, and also routes
book searches through it, for reasons covered under
[the public database](#the-public-database).

### The suggestion at a glance

| Concern | Choice | Why |
| --- | --- | --- |
| App | Flutter, in Dart | Already chosen; one code base for Android and the web. |
| Architecture | MVVM, as in Flutter's architecture guide | Views, view models, repositories and services, with `provider` for dependency injection, so there is no state management library to choose. |
| Navigation | go_router | Maintained by the Flutter team, with real URLs and a working back button on the web. |
| Models and JSON | freezed and json_serializable | Immutable models and generated JSON code, since Flutter has no runtime reflection. |
| Book data | Open Library | Open data, no API key, and a covers API; see below. |
| Local storage | drift | SQLite for Dart, on Android and in the browser through WebAssembly, as an offline cache of the library. |
| Images | cached_network_image | Covers are downloaded once and kept on the device. |
| Server | ASP.NET Core with PostgreSQL | Holds each user's library, searches the book database on the app's behalf, and ships as one Docker image. |
| Accounts | ASP.NET Core Identity | Sign-in and tokens from the framework, through its Identity API endpoints. |
| Testing | flutter_test, integration_test and xUnit | Unit and widget tests for the app, end-to-end tests on a device and in the browser, and tests for the server. |

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

### The data model

| Record | Holds |
| --- | --- |
| Book | One work: title, authors, Open Library work ID, cover ID |
| Edition | One edition of a book: ISBN, publisher, page count, Open Library edition ID |
| Reading | One time a user reads a book: the edition, status, start and finish dates, current page |
| Review | A rating and text, written about one reading |

Keeping **readings** separate from **books** is what lets the library answer
both "what am I reading now" and "what did I read in the past" from one table,
and it allows re-reading: a book read twice has two readings, with two sets of
dates. Attaching each review to a reading keeps a second opinion of the same
book from overwriting the first, and the book's page can still show all of a
user's reviews of it together.

### Offline on Android

The library should open on a phone with no connection. drift keeps a copy of
the user's library on the device, and the app reads from it first:

- **Reads** come from the local database, refreshed from the server when the
  app opens and on pull to refresh.
- **Writes**, such as a new page number or a finished book, are saved locally
  and queued, then sent when the connection returns.
- **Conflicts** are rare, since a library belongs to one person. When two
  devices change the same reading, the later change to each field wins.

Searching for new books still needs a connection, since it goes through the
server.

### Flutter on the web

Flutter draws the web app into a canvas rather than with HTML, so search
engines see little of it. That is not a problem for a library behind a
sign-in, but it would be for public pages, such as a review shared with a link.
If reviews become public, those pages should be ordinary HTML rendered by the
server, and the Flutter app kept for the signed-in library.

## Open questions

- Is an account required from the first release, or does Merlin start as an
  Android app with a local library, and add the web app and the server later?
- Are reviews private, or can they be shared or made public?
- Beyond reading now and read, does Merlin keep a list of books to read later,
  and books the reader gave up on?
- Is progress tracked in pages, in percent, or both? E-books and audiobooks
  have no fixed page count.
- Should a library be importable from Goodreads, which exports a reader's
  shelves as a CSV file?
- Should books be added by scanning the ISBN barcode on the cover with the
  phone's camera?
