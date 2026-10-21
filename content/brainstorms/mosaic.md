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
| Android | Tauri file system plugin, in app storage | Tauri SQL plugin |
| Web | Origin Private File System, with export and import of the vault | SQLite compiled to WebAssembly, persisted in the Origin Private File System |

### Pomodoro on mobile

A timer counting down in JavaScript stops when Android suspends the app. The
Pomodoro feature should store when the session ends rather than how long is
left, compute the remaining time from the clock whenever the screen is shown,
and hand the end of the session to a system notification, so the alarm fires
even if the app is in the background.

### Sync, later

The first version can be local only and still useful, because a vault folder
can be synced with tools the user already has, such as Syncthing or Git. When
sync becomes a feature of its own, there are two routes:

- **Sync the files**, with a small server that stores the vault and resolves
  conflicts per file. An ASP.NET Core API is a natural fit for this.
- **Sync the edits**, with a CRDT library such as Yjs or Automerge, which merges
  concurrent edits to the same note without conflicts, at the cost of storing
  each document's history.

## Open questions

- Should the Android app open a vault folder in shared storage, so other apps
  can read the notes, or keep the vault in app storage and offer export?
- Do tasks belong in the notes, as checklist items Mosaic reads, or in the
  database with links to notes, or both?
- Is the web build a full app with its own vault, or a companion to the
  desktop and mobile apps once sync exists?
- Are plugins in scope, as they are for Obsidian? If so, the extension points
  should be designed early, because they shape every feature.
