---
title: "Thoth: An IDE That Grows With You"
description: "An idea for an IDE that starts as a lightweight editor and grows through built-in modules instead of extensions, with a VS Code-like window and a LunarVim-like terminal mode, and a suggested technology stack to build it for Linux and Windows."
date: 2026-10-21T12:00:00Z
categories: ["Brainstorms"]
tags: ["Thoth", "IDE", "Code Editor", "Rust", "Language Server Protocol", "Technology Stack"]
---

An IDE that adapts to your exact needs, nothing more, nothing less.

## Features

- Starts like a simple and lightweight code editor and the user can activate modules to add functionalities to fill their needs. For example a .NET module, an Angular module etc
- Experience must be similar to Visual Studio Code on Linux and Windows and similar to LunarVim on terminal
- Do not support extensions, the idea is to use the modules to extend the application on-demand

## Platforms

- Linux
- Windows

## First release modules

- .NET
- Angular
- React
- Flutter
- Python
- Rust
- HTML/CSS
- JavaScript/TypeScript
- Java

## Technology stack

The feature that shapes the stack most is the second one: the same IDE in a
window and in a terminal. If the window and the terminal are two programs, every
feature is built twice. So the design starts from one **core** that owns
everything an editor does, such as buffers, cursors, syntax trees, language
servers, commands, keymaps and modules, and two thin **front ends** that only
draw what the core describes and send it the user's input. The core and the
front ends talk only through typed messages: input events go in, view updates
come out. Neither side calls into the other, so a front end can be replaced,
and the core could later run in a separate process, for example on a remote
machine over SSH.

```txt
              modules: .NET, Angular, ...
                       │
                ┌──────┴───────┐
                │  thoth-core  │
                └──────┬───────┘
          input ▲      │      ▼ view
          ┌────────────┴────────────┐
   ┌──────┴──────┐           ┌──────┴──────┐
   │  thoth-gui  │           │ thoth-term  │
   │ VS Code-like│           │LunarVim-like│
   └─────────────┘           └─────────────┘
```

The two experiences then differ where they should, in drawing and in keymaps:
the window uses VS Code's shortcuts, mouse and panels, and the terminal uses
modal, Vim-style editing with a leader key, as LunarVim does on top of Neovim.
Both are keymap profiles in the core, so a user could also pick Vim keys in the
window.

### The suggestion at a glance

| Concern | Choice | Why |
| --- | --- | --- |
| Language | Rust | Fast start-up and low memory with no runtime, and the language the editors closest to this idea are written in: Helix, Zed and Lapce. |
| Async runtime | Tokio | Language servers, debug adapters, builds and searches all run in the background, and the core waits on all of them at once. |
| Core and front ends | Typed messages over channels | Input events in, view updates out, so both front ends share one core and neither depends on the other's libraries. |
| Text buffer | Ropey | A rope keeps edits fast in large files and makes undo history cheap. |
| Syntax | Tree-sitter | Incremental parsing for highlighting, folding, indentation and selecting by syntax node, from one grammar per language. |
| Language features | Language Server Protocol | Completion, diagnostics, go to definition and refactoring come from each language's own server, so a module wraps a server instead of reimplementing a language. |
| Debugging | Debug Adapter Protocol | The same idea for debuggers: one client in the core, one adapter per language. |
| Terminal front end | ratatui with crossterm | The standard Rust terminal UI library, and crossterm drives both Linux terminals and the Windows console. |
| Window front end | GPUI | The GPU UI framework Zed is built on, made for a code editor, with fast text rendering; it runs on Windows and Linux. |
| Modules | Rust crates with declarative manifests | A manifest says what a module handles before any of its code runs, so modules activate on demand. |
| Search and files | `ignore`, `grep-searcher`, nucleo | The crates behind ripgrep for walking and searching the workspace, and Helix's fuzzy matcher for the file and command pickers. |
| File watching | notify | Cross-platform file system events, so files changed outside Thoth, by Git or a build, are reloaded. |
| Git | gitoxide (`gix`) | A Git implementation in Rust, without a C library to build and ship. |
| Built-in terminal panel | `alacritty_terminal` with `portable-pty` | The terminal emulator Zed embeds, and a pseudo-terminal that works on Windows too. |
| Configuration | TOML | One file for settings, keymaps and which modules are active. |
| Testing | `cargo test` with insta | Snapshot tests of what the core renders, using ratatui's test backend for the terminal. |
| Packaging | cargo-dist | MSI and a winget manifest for Windows; archives, `.deb` and AppImage for Linux. |

### Why Rust

"Lightweight" is a requirement, not a wish, so the core should start in
milliseconds and stay small with nothing open. Rust gives that without a
garbage collector or a runtime to start, and it is the only ecosystem where
every piece above already exists as a library and has been proven in a shipping
editor. Helix is the closest reference: a terminal editor in Rust with
Tree-sitter and language servers built in, and no plugin system, which is
Thoth's stance on extensions too.

| Option | Window | Terminal | Weight | Trade-off |
| --- | --- | --- | --- | --- |
| **Rust core + GPUI + ratatui** | GPUI | ratatui | Lightest | Rust has a steep start, and GPUI changes along with Zed and is documented mostly by Zed's own code. |
| .NET core + Avalonia + Terminal.Gui | Avalonia with AvaloniaEdit | Terminal.Gui | Light with Native AOT; see [How C# Runs]({{< ref "/dotnet/compilation-and-execution" >}}) | Familiar language, and the .NET module could use Roslyn directly, but Tree-sitter is only reachable through native bindings, and the two UI libraries each bring their own text model. |
| Tauri or Electron with Monaco | Monaco, VS Code's editor | A second editor | Heaviest | The window would look like VS Code quickly, but Monaco owns the text model, so the terminal mode would be another editor with every feature built twice. |
| A Neovim distribution | A Neovim GUI such as Neovide | Neovim | Light | The fastest route to the terminal half, but modules become Lua plugins, which is the extension system Thoth wants to avoid, and the window would feel like Vim, not VS Code. |

If Rust is too much to learn alongside building an IDE, the .NET row is the
honest second choice: the architecture stays the same, one core and two front
ends, only the libraries change.

### Why GPUI

Most Rust UI libraries are general purpose, so an editor built on them draws
its text area by hand on a canvas. GPUI was written for Zed, a code editor, so
fast text rendering, many panes and an editor-style layout are what it does
best, which is what a VS Code-like window needs. It comes with three costs:

- **Its API moves with Zed.** There is little documentation outside Zed's own
  code, so Thoth should pin one version and plan its upgrades.
- **Zed's editor is not GPUI.** GPUI is licensed under Apache 2.0, but most of
  Zed's other crates, its editor included, are GPL. Reading them is fine;
  copying code from them would make Thoth GPL too.
- **GPUI has its own async executors.** The core runs on Tokio and never
  depends on GPUI; the window front end receives the core's messages and
  turns them into GPUI views. This is also what keeps the terminal build free
  of GPUI.

### Modules instead of extensions

A module is first-party code compiled into Thoth, not a package downloaded from
a marketplace. Inactive modules cost nothing at run time: they register no
commands, start no processes and add no menu items. Activating one does three
things, each driven by the module's manifest:

1. **Fetches its tools**, such as a language server or a debug adapter, into
   Thoth's own data folder, pinned to a version Thoth was tested with. This is
   what mason.nvim does for LunarVim.
2. **Starts its servers** when a file it handles is opened, and stops them when
   the last one closes.
3. **Registers its commands, keymaps and panels** with the core, such as "Run
   tests" or a project tree.

Each module is a Rust crate with two parts. A declarative manifest in TOML
lists what the module handles and needs: the file types and project files that
activate it, the language servers and debug adapters with their versions, and
the commands it adds. The core reads every manifest at start-up without running
any module code, so it knows when to offer or activate a module at no cost.
The crate itself implements a `Module` trait for the behaviour a manifest
cannot describe, such as parsing a solution file, so the core stays ignorant of
every language. Because the set of modules is fixed at build time, the core can
test every combination, which a marketplace never can.

```toml
[module]
id = "dotnet"
name = ".NET"

[activation]
files = ["*.cs", "*.csproj", "*.sln", "*.slnx"]

[[language-server]]
id = "roslyn"
languages = ["csharp"]

[[debug-adapter]]
id = "netcoredbg"

[[command]]
id = "dotnet.test"
title = "Run tests"
```

A manifest can also require other modules. Angular and React are built on the
web, so their manifests require the JavaScript/TypeScript and HTML/CSS modules
instead of bringing their own copies of those servers:

```toml
[module]
id = "angular"
name = "Angular"
requires = ["javascript-typescript", "html-css"]
```

The nine modules of the first release would start as:

| Module | Language server | Debugger | Tasks |
| --- | --- | --- | --- |
| .NET | The Roslyn language server, or csharp-ls | netcoredbg | `dotnet build`, `dotnet test`, `dotnet new`, solution and project tree |
| Angular | Angular Language Service, on top of JavaScript/TypeScript and HTML/CSS | `js-debug`, from JavaScript/TypeScript | `ng serve`, `ng test`, `ng generate`; see [What Is Angular?]({{< ref "/front-end/angular" >}}) |
| React | None of its own: JSX and TSX are handled by the TypeScript server from JavaScript/TypeScript | `js-debug`, from JavaScript/TypeScript | The project's `dev`, `build` and `test` scripts, component snippets; see [What Is React?]({{< ref "/front-end/react" >}}) |
| Flutter | The Dart analysis server, run as `dart language-server` | The Dart and Flutter debug adapters, which include hot reload | `flutter run`, `flutter test`, device picker; see [What Is Flutter?]({{< ref "/front-end/flutter" >}}) |
| Python | Pyright for types, Ruff for linting and formatting | debugpy | Virtual environment picker, `pytest` |
| Rust | rust-analyzer | CodeLLDB | `cargo build`, `cargo test`, `cargo run`, Clippy |
| HTML/CSS | The HTML and CSS language servers extracted from VS Code | None, debugging runs in the browser | Emmet abbreviations, colour previews |
| JavaScript/TypeScript | A TypeScript language server, and ESLint's | `js-debug`, for Node.js, Chrome and Edge | npm, pnpm and Yarn scripts, `package.json` awareness |
| Java | Eclipse JDT Language Server | java-debug, which runs inside the JDT Language Server | Maven and Gradle tasks, test runner |

Several of these servers are programs for another runtime: the TypeScript,
Angular, HTML, CSS, ESLint and Pyright servers run on Node.js, and the JDT
Language Server runs on Java. Those modules need either the runtime the user
already has installed, or one Thoth fetches and pins for itself.

{{< callout type="warning" title="Licences of Microsoft's own tools" >}}
Microsoft's .NET debugger, vsdbg, may only be used with Microsoft's own tools,
such as Visual Studio and VS Code, so Thoth cannot ship it or download it. The
.NET module has to use netcoredbg, Samsung's open-source debugger, which speaks
the Debug Adapter Protocol. Pylance, VS Code's Python language server, has the
same restriction, which is why the Python module uses Pyright, the open-source
project Pylance is built on.
{{< /callout >}}

### Building toward the first release

Nine modules is a lot to build at once, so the order matters. The first
milestone is the core and the terminal front end with one module: open a
folder, edit with Vim keys, find files, search, and get completion and
diagnostics for C#. The terminal is the quicker front end to build and the
easier one to test, and it proves the core's design before the window is
started. The window front end comes next, then the other modules, starting with
JavaScript/TypeScript and HTML/CSS, since Angular and React are built on them.

## Open questions

- Is the window a requirement for the first release, or can Thoth ship as a
  terminal IDE first?
- Should a user be able to choose Vim keys in the window and VS Code keys in
  the terminal, or does each front end keep one keymap?
- Should Thoth fetch its own Node.js and Java runtimes for the servers that
  need them, or require the user to install them?
- Should modules ever load from outside the binary, for languages Thoth does
  not ship, or does that make them extensions after all?
