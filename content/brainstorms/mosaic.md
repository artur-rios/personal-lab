---
title: "Mosaic: A Second Brain App"
description: "An idea for one app that brings Markdown notes, a calendar, tasks, a kanban board, Pomodoro sessions and diagrams together, with a suggested technology stack to build it for Android, Linux, the web and Windows from one codebase."
date: 2026-10-21T09:00:00Z
categories: ["Brainstorms"]
tags: ["Mosaic", "Productivity", "Local-first", "Tauri", "React", "Technology Stack"]
---

An app that wants to be your second brain.

## Features

- Create and organize notes in Markdown
- Calendar
- To do list
- Kanban board
- Pomodoro sessions
- Mermaid diagrams
- Draw diagrams

## Inspiration

This app wants to combine features from these apps:

- [Obsidian](https://obsidian.md/)
- [Super Productivity](https://super-productivity.com/)
- [Excalidraw](https://excalidraw.com/)

## Platforms

- Android
- Linux
- Web
- Windows

## Technology stack

Two of the features decide most of the stack before anything else is weighed.
Excalidraw is published as a React component, and Mermaid is a JavaScript
library. Any stack that does not run JavaScript in a web view has to embed one
to get them, so the cheapest path is to make the whole app a web app and wrap
it for each platform. The suggestion below follows that path.

Mosaic has no plugin system: every feature ships in the app. That keeps the
stack simpler than Obsidian's, since no feature has to be designed as an
extension point that outside code can hook into.

### The suggestion at a glance

| Concern | Choice | Why |
| --- | --- | --- |
| Language | TypeScript | One language for every platform, and the language Excalidraw, Mermaid and the editor libraries are written in. |
| UI | React with Vite | Excalidraw is a React component, so React avoids a wrapper; see [What Is React?]({{< ref "/front-end/react" >}}). |
| App shell | Tauri 2 | One project builds Windows, Linux and Android apps around the system web view; the web build is the same front end without the shell. |
| Markdown editor | CodeMirror 6 | The editor Obsidian is built on: live preview, Vim mode and large files are all solved problems. |
| Markdown rendering | unified (remark and rehype) | A plugin pipeline, so wiki links, tags and Mermaid code blocks are each one plugin. |
| Diagrams | Mermaid and `@excalidraw/excalidraw` | The two tools the features name, used directly. |
| Calendar | FullCalendar (`@fullcalendar/react`) | Month, week, day and list views with drag to reschedule. |
| Kanban | dnd-kit | Accessible drag and drop for columns and cards, with keyboard support. |
| State | Zustand | Small stores per feature, without a framework around them. |
| Storage | Markdown files plus SQLite | Notes stay plain files; tasks, events, boards and sessions go in a database. |
| Sync server | ASP.NET Core with PostgreSQL | Stores each user's vault and records, merges changes from every device, and serves the web companion. |
| Testing | Vitest and Playwright | Unit tests for the logic, end-to-end tests against the web build. |

### Why Tauri

The four platforms rule out most single-platform shells. Electron has no
Android target, so it would need a second shell such as Capacitor for mobile,
which is the route Obsidian takes. .NET MAUI has no Linux target. Avalonia and
Flutter cover all four platforms, but both draw their own UI, so Excalidraw and
Mermaid would live inside an embedded web view, and the app would be two apps
talking across a bridge.

Tauri 2 builds desktop and mobile apps from one project, and because it uses
the web view the operating system already has, the installers are small. The
web build needs no shell at all: it is the same Vite build served as static
files.

| Option | Android | Linux | Web | Windows | Excalidraw and Mermaid |
| --- | --- | --- | --- | --- | --- |
| **Tauri 2 + React** | Yes | Yes | Yes | Yes | Native, it is a web app |
| Electron + Capacitor + React | Through Capacitor | Yes | Yes | Yes | Native, but two shells to maintain |
| Flutter | Yes | Yes | Yes | Yes | Through a web view; see [What Is Flutter?]({{< ref "/front-end/flutter" >}}) |
| Avalonia | Yes | Yes | Through WebAssembly | Yes | Through a web view |
| .NET MAUI | Yes | No | No | Yes | Through a web view |

Tauri has two costs worth knowing up front:

- **The native side is Rust.** Most of the app never touches it, because the
  official plugins cover files, SQLite, notifications and the dialog boxes from
  TypeScript. Rust is only needed for a custom command the plugins do not
  offer.
- **The web view differs by platform.** Windows uses WebView2 and Android uses
  its system WebView, both based on Chromium, but Linux uses WebKitGTK. Linux is
  the platform to test layout and drawing performance on first.

### Storage: files first

A second brain is only worth trusting if the notes outlive the app. Following
Obsidian, the notes should be plain Markdown files in a folder the user picks,
a vault, readable by any editor and easy to back up or put under Git.

Everything that is not prose goes into SQLite:

- **Structured data** such as tasks, calendar events, kanban boards and Pomodoro
  sessions, which need queries more than they need to be readable as files.
- **An index of the vault**, with links, backlinks, tags and an FTS5 full-text
  search table. The index is rebuilt from the files, so it can always be
  deleted safely.

Drawings are saved as `.excalidraw` files next to the notes, since the format is
JSON and Excalidraw can open and save it as is. Mermaid diagrams need no storage
of their own: they are code blocks inside the notes.

The storage code should sit behind an interface, with one implementation per
platform, so the features never know where they run; this is the
[dependency inversion principle]({{< ref "/concepts/dependency-inversion-principle" >}})
applied to the shell:

| Platform | Files | Database |
| --- | --- | --- |
| Windows, Linux | Tauri file system plugin, on a folder the user picks | Tauri SQL plugin |
| Android | A folder the user picks in shared storage, through a small Kotlin plugin | Tauri SQL plugin, in app storage |
| Web | None of its own: notes come from the sync server, cached in the Origin Private File System | SQLite compiled to WebAssembly, as a cache of the server's records |

### The Android vault in shared storage

On Android the vault lives in shared storage, so other apps, such as a file
manager, a backup tool or another Markdown editor, can read and change the
notes. Android offers two ways to reach a folder there:

- **The Storage Access Framework.** The user picks the folder in the system
  picker, and Mosaic keeps a lasting permission to it. Files are reached through
  `content://` addresses rather than paths, so the Android build needs a small
  Kotlin plugin for Tauri that lists, reads and writes them; Tauri's own file
  system plugin is built around paths.
- **The "All files access" permission.** Mosaic could then use plain paths, but
  Google Play grants this permission only to apps whose main purpose needs it,
  and the user has to switch it on in the system settings.

The Storage Access Framework is the safer default. Because other apps can now
change the notes, Mosaic must notice changes it did not make: it rescans the
vault when it comes to the foreground and rebuilds the index for any file
whose modification time or hash changed. The database stays in app storage,
since it holds Mosaic's own records and an index that can be rebuilt.

### Tasks in notes and in the database

Tasks live in both places, and the to-do list, the calendar and the kanban
board show both kinds together:

- **Note tasks** are Markdown checklist items, `- [ ] Call the bank`, written
  anywhere in a note. Mosaic finds them while indexing the vault, and the note
  stays their source of truth: ticking one in the to-do list edits that line of
  the note.
- **Database tasks** are created in the to-do list or on a board, and can link
  to any number of notes. They carry what a checklist line cannot hold well,
  such as a due date, a board column or a Pomodoro estimate.

A note task can gain those fields too. The first time it does, Mosaic appends a
block ID to its line, `- [ ] Call the bank ^t7k2`, the way Obsidian marks
blocks, and stores the extra fields in the database under that ID. The ID
keeps the link when the line moves or its text is edited.

### Pomodoro on mobile

A timer counting down in JavaScript stops when Android suspends the app. The
Pomodoro feature should store when the session ends rather than how long is
left, compute the remaining time from the clock whenever the screen is shown,
and hand the end of the session to a system notification, so the alarm fires
even if the app is in the background.

### Sync in the first release

Sync ships in the first release, because the web build is a companion to the
desktop and Android apps rather than a full app with a vault of its own. There
are two ways to build it:

- **Sync the files**, with a server that stores each vault and merges changes
  per file.
- **Sync the edits**, with a CRDT library such as Yjs or Automerge, which merges
  concurrent edits to the same note without conflicts, at the cost of storing
  each document's history.

The vault decides between them. Its notes are plain files that other apps can
change, on Android and on the desktop alike, and those changes never pass
through a CRDT, so its history and the files would drift apart. Syncing the
files fits a vault that anything can edit:

- **Notes** are merged with a three-way text merge, against the version both
  sides last agreed on. When both changed the same lines, Mosaic keeps both,
  writing the other device's version next to the note as a conflict copy for
  the user to resolve.
- **Records**, such as tasks, events, boards and Pomodoro sessions, sync one
  record at a time; when two devices change the same record, the later change
  to each field wins.
- **Drawings** are synced as whole files, with a conflict copy when both sides
  changed them.

The server is an ASP.NET Core API with PostgreSQL. Each client sends what
changed since the last revision it saw and receives what the others changed.
The web companion talks to the same API directly, keeps a cache in the browser
so recent notes open quickly, and needs the server to save its changes.

## Decisions

The questions this brainstorm raised, and how they were settled:

- **The Android vault lives in shared storage**, so other apps can read and
  change the notes.
- **Tasks live in both the notes and the database.** Checklist items in notes
  and tasks created in the to-do list appear together everywhere.
- **The web build is a companion** to the desktop and Android apps, and sync
  ships in the first release to make it possible.
- **Mosaic supports no plugins.** Every feature is built into the app.

## Open questions

Shipping sync in the first release raises two questions of its own:

- Is the sync server hosted for users, self-hosted by each user, or both?
- Should notes be encrypted end to end, so the server stores only data it
  cannot read? That would rule out merging on the server, and move the merge
  to the clients.
