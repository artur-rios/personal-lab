---
title: "Angular, React or Flutter? How They Compare and How to Choose"
description: "Angular, React and Flutter are named together all the time, but they are three different kinds of thing: a web framework, a UI library and a cross-platform toolkit that draws its own pixels. Here is how they compare on architecture, rendering, measured size and speed, developer experience, ecosystem, stability, accessibility and search, mobile and hiring, with the same small app built in all three, and a guide to choosing between them, or none of them."
date: 2026-10-20T18:00:00Z
categories: ["Front-end"]
tags: ["Angular", "React", "Flutter", "Front-end", "Frameworks", "Comparison"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

"Angular or React?" is one of the most common questions in front-end
development, and "or Flutter?" is now often added to it. The question sounds
like a choice between three brands of the same product. It is not. Angular is
a complete framework for web applications; React is a library for turning state
into UI, which needs a framework around it to make an application; Flutter is a
toolkit for mobile, desktop, web and embedded apps that does not use the
browser's HTML at all, but draws every pixel itself. Each has been described in
detail in this section: [What Is Angular?]({{< ref "/front-end/angular" >}}),
[What Is React?]({{< ref "/front-end/react" >}}) and
[What Is Flutter?]({{< ref "/front-end/flutter" >}}). This article puts them
side by side and ends with a guide to choosing.

Comparisons of frameworks are usually long on opinion and short on
measurement, so this one measures what it can. The same small app was built in
all three, with Angular 22.2.3, React 19.3.1 with Vite 8.3.4, and Flutter 3.47.7
with Dart 3.13.5, the current stable releases in October 2026, and loaded in
Chrome 155; the outputs and sizes below are shown as printed. Benchmark and
survey figures come from their published sources, with notes on how far each
can be trusted.

## Three different kinds of thing

The three projects describe themselves in different terms, and the difference
is the most important fact in this article:

- **Angular is a framework.** Its documentation calls it "a web framework that
  empowers developers to build fast, reliable applications", and it ships, from
  one team and in one version, the router, forms, HTTP client, dependency
  injection, server rendering, the build and the test set-up.[^ngoverview]
- **React is a library.** Its repository calls it "the library for web and
  native user interfaces".[^rrepo] It covers components, state and rendering;
  for everything else, its documentation says, "we recommend starting with a
  framework," such as Next.js or React Router.[^rcreating]
- **Flutter is a UI toolkit.** It is for "building natively compiled
  applications for mobile, web, desktop and embedded devices from a single code
  base", and it "doesn't rely on web browser views or system-provided platform
  widgets": its own engine renders the interface.[^flfaq][^flarch]

{{< diagram src="categories.svg" caption="What each one is, what you write, what comes in the box, and who finally draws the interface." >}}

Two consequences follow. First, **Angular and React compete directly**: both
are web technologies, both produce ordinary HTML elements in the browser's
DOM, and the browser does the styling, layout and painting, exactly as
described in [How Does a Web Browser Work?]({{< ref "/fundamentals/how-browsers-work" >}}).
Second, **Flutter competes with them only partly.** Its natural rival on
phones is React Native, React's sibling for native apps, and native toolkits
such as SwiftUI and Jetpack Compose. On the web it can run, but its own
documentation says it is aimed at app-like experiences rather than documents,
which changes what it competes with there.[^flwebfaq]

A useful rule of thumb is to compare like with like:

| Question | The real contenders |
|---|---|
| A web application in the browser | Angular, or React with a framework (and Vue, Svelte and others not covered here) |
| A mobile app for iOS and Android from one code base | Flutter, React Native, or native code for each platform |
| A desktop app | Flutter, React Native for Windows and macOS, or web technology in a desktop shell |
| A content website | Mostly static or server-rendered HTML; any of the web options with server rendering |

## At a glance

| | Angular | React | Flutter |
|---|---|---|---|
| **Kind** | Web framework | UI library | Cross-platform UI toolkit |
| **First release** | AngularJS 0.9 in 2010; Angular 2.0 in 2016[^ngjschangelog][^ngv2] | 0.3.0, open-sourced in May 2013[^rversions] | 1.0 in December 2018[^flflutter1] |
| **Steward** | Google[^ngoverview] | The React Foundation, under the Linux Foundation, since 2026[^rfoundation] | Google, "with contributions from a global community"[^flfaq] |
| **Licence** | MIT[^nglicense] | MIT[^rlicense] | BSD 3-Clause[^flrepo] |
| **Language** | TypeScript | JavaScript or TypeScript, with JSX | Dart |
| **You write** | Classes with decorators, and HTML templates | Functions that return JSX | Classes whose `build` methods return widgets |
| **Rendering** | DOM, through compiled template instructions[^ngaot] | DOM through `react-dom`; native views through React Native[^rrepo] | Its own engine (Impeller, or Skia on the web) draws to a surface or canvas[^flarch][^flimpeller] |
| **Reacting to change** | Signals mark the views that read them; zoneless and `OnPush` by default since v22[^ngzoneless][^ngv22] | A state change re-renders the component and its children, then React diffs and commits[^rrendercommit] | `setState` marks an element dirty; its subtree rebuilds, then layout and paint[^flarch] |
| **Platforms** | Web | Web; iOS and Android with React Native[^rrnhome] | Android, iOS, web, Windows, macOS, Linux, embedded[^flfaq] |
| **Included** | Router, forms, HTTP, DI, SSR, CLI, testing | Components, state, Hooks, Actions; the rest from a framework or libraries | Widgets, layout, navigation, forms, Material and Cupertino, CLI, testing |
| **Server rendering** | Built in, with hydration[^ngssr] | Through a framework such as Next.js[^rcreating] | None: no HTML to send |
| **Releases** | A major version a year since v22, each supported for about 24 months[^ngreleases] | Semantic versioning, few majors, no fixed schedule[^rversioning] | A stable release about every three months[^fldecouple] |
| **Used extensively** (Stack Overflow) | 16.0% (2026)[^so2026] | 41.5% (2026)[^so2026] | 9.4% (2024), against 8.4% for React Native[^so2024] |

The rest of the article goes through those rows in more depth.

## Architecture and mental model

All three are **declarative** and **component-based**: you describe what the
interface should look like for the current state, compose it from reusable
pieces, and let the framework work out what to change. They differ in what a
component is and in how they find out that something changed.

**Angular** components are TypeScript classes decorated with `@Component`,
paired with an HTML template. The template is compiled ahead of time into
JavaScript instructions that create the DOM and update it, so a mistake in a
template is a build error.[^ngaot] Services are provided through **dependency
injection**, which gives every component the instances it asks for from a
hierarchy of injectors.[^ngdi] State that the template reads is held in
**signals**, which record who reads them, so that setting one marks exactly
those views for refreshing.[^ngsignals] Angular is opinionated: there is one
router, one HTTP client and one way to build, chosen by the Angular team.

**React** components are functions. They take **props**, may hold **state**
through Hooks such as `useState`, and return elements, plain objects that
describe the UI, usually written in JSX. React assumes components are pure
functions of their inputs, and passes data down the tree in one direction
only.[^rpure][^rthinking] When state changes, React calls the component again,
compares the new elements with the previous ones and commits the
difference.[^rrendercommit] React itself has no opinion on routing, data
fetching or builds; the framework or libraries you choose do.

**Flutter** is built from **widgets**, immutable descriptions of part of the
interface, all the way down: padding, alignment and gestures are widgets too.
The framework keeps three trees, of widgets, elements and **render objects**,
and lays out the render tree in a single pass in which "constraints go down,
sizes go up, parent sets position".[^flarch][^flconstraints] State lives in a
`State` object that survives rebuilds; calling `setState` asks the framework to
run `build` again.[^flrnguide]

Concepts map across the three roughly as follows:

| Concept | Angular | React | Flutter |
|---|---|---|---|
| Unit of UI | Component class and template | Function component | Widget |
| Describing the UI | HTML template with `@if`, `@for` | JSX expressions | `build()` returning widgets |
| Local state | `signal()` | `useState` | Fields of a `State`, changed in `setState` |
| Derived values | `computed()`, cached | Plain expressions during render; the React Compiler memoises | Plain expressions in `build()` |
| Sharing data down the tree | Services through dependency injection | Context | `InheritedWidget`, often through the provider package |
| Navigation | `@angular/router` | React Router, or a framework's router | `Navigator`, and the go_router package |
| Forms | Signal Forms, reactive or template-driven forms | Actions, `useActionState`, and libraries | `Form` and `TextFormField` |
| Talking to servers | `HttpClient` | `fetch`, with libraries such as TanStack Query | The `http` package |
| Tests | Vitest through the CLI | A runner such as Vitest, with Testing Library | `flutter_test` widget tests |

The table follows each project's documentation.[^ngcontrolflow][^ngsignals][^ngrouting][^ngforms][^nghttp][^ngtesting][^rv19][^rcompilerintro][^rcontext][^rscratch][^rrtl][^flstatemgmt][^flnav][^flgorouter][^flforms][^flhttp][^fltesting]
For someone who knows one, the others are less foreign than they first look:
Flutter's own guide for React Native developers notes that "like React Native,
Flutter uses reactive-style views", with `setState` causing `build` to run
again.[^flrnguide]

## The same app in all three

The clearest way to see the differences is one small program written three
times. Each version shows a count and its double, and a button that adds one;
the derived value is there to show how each tool handles computed state.

In **Angular**, the count is a signal, the double is a `computed` signal, and
the template reads both:

```ts
import { Component, computed, signal } from '@angular/core';

@Component({
  selector: 'app-root',
  template: `
    <p>Count: {{ count() }}, doubled: {{ doubled() }}</p>
    <button (click)="increment()">Add one</button>
  `,
})
export class App {
  protected readonly count = signal(0);
  protected readonly doubled = computed(() => this.count() * 2);

  protected increment() {
    this.count.update((n) => n + 1);
  }
}
```

In **React**, the component is a function that runs again on every update, so
the double is an ordinary variable:

```tsx
import { useState } from 'react';

export default function App() {
  const [count, setCount] = useState(0);
  const doubled = count * 2;

  return (
    <>
      <p>Count: {count}, doubled: {doubled}</p>
      <button onClick={() => setCount((n) => n + 1)}>Add one</button>
    </>
  );
}
```

In **Flutter**, the widget is immutable, so the count lives in its `State`
object, and the button and text are widgets from the Material library:

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Counter()))));
}

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    final doubled = _count * 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Count: $_count, doubled: $doubled'),
        FilledButton(
          onPressed: () => setState(() => _count++),
          child: const Text('Add one'),
        ),
      ],
    );
  }
}
```

Each was built for production and clicked twice. The two web apps were driven
in headless Chrome, reading the paragraph's text; the Flutter app was driven
by a widget test, since its text is painted rather than stored in the DOM:

```txt
Angular 22.2.3 after two clicks: Count: 2, doubled: 4
React 19.3.1 + Vite 8.3 after two clicks: Count: 2, doubled: 4
Flutter after two taps: Count: 2, doubled: 4
```

The results are the same, but the three got there differently:

{{< diagram src="update-models.svg" caption="One change of state, three paths to the screen. The DOM-based frameworks finish by handing the browser a few DOM changes; Flutter computes and draws the whole frame itself." >}}

- **Angular** knows precisely what depends on `count`, because the template and
  `doubled` read it through the signal. Setting it marks those views dirty,
  and only they are re-checked.[^ngsignals][^ngzoneless]
- **React** knows only that this component's state changed, so it calls the
  whole function again and compares the result. By default the component's
  children re-render too, which the React Compiler and memoisation
  reduce.[^rrendercommit][^rcompilerintro]
- **Flutter** rebuilds the widgets below the dirty element, updates the
  matching elements and render objects, then runs its own layout, paint and
  rasterisation, the work a browser would do for the other two.[^flarch]

The React version is the shortest and the Flutter version the longest:
Dart has no equivalent of JSX or templates, so layout is written as nested
constructor calls, and state lives in a separate class from the widget that
uses it.

## Rendering and performance

### Where the pixels come from

Angular and React both end at the browser's DOM. Each has its own way of
deciding which DOM nodes to touch: Angular's compiled templates check each
binding against its last value and write only those that changed; React
builds new element trees and diffs them against the old.[^ngaot][^rreconciliation]
After that the browser's own engine styles, lays out and paints the page, so
both inherit its text rendering, accessibility tree, form controls, text
selection and search indexing.

Flutter replaces that whole pipeline. On mobile and desktop its engine draws
with **Impeller**, which precompiles its shaders so that frames do not stall
on shader compilation the first time an effect appears.[^flimpeller] On the
web it draws into a canvas, with **CanvasKit** (Skia compiled to WebAssembly)
for a JavaScript build or **skwasm** for a WebAssembly build.[^flarch][^flwebinit][^flwasm]
That brings the same pixels on every platform, and full control over every
pixel, at the price of shipping an engine with every app.

### Speed: the js-framework-benchmark

The most widely cited speed comparison for DOM libraries is Stefan Krause's
**js-framework-benchmark**, which times operations on a table of rows (create
1,000 rows, replace them, update every tenth, swap two, remove one, and so on)
in Chrome, measuring each from Chrome's own timeline.[^jsfbrepo] Its official
results for Chrome 154, for the "keyed" implementations, which keep a stable
DOM element for each data item, include the following:[^jsfb]

| Implementation | Weighted geometric mean of durations (1 = fastest) | Memory after load | Brotli size | First paint |
|---|---|---|---|---|
| Vanilla JavaScript | 1.05 | 0.48 MB | 2.5 kB | 53.8 ms |
| Solid 1.9 | 1.13 | 0.60 MB | 4.5 kB | 51.6 ms |
| Svelte 5.42 | 1.18 | 0.67 MB | 9.7 kB | 71.4 ms |
| Vue 3.5 | 1.31 | 0.78 MB | 23.3 kB | 102.3 ms |
| Angular 22.2, signals and zoneless | 1.58 | 1.10 MB | 34.5 kB | 143.2 ms |
| Angular 22.2, default | 1.59 | 1.57 MB | 45.5 kB | 158.2 ms |
| React 19.2, Hooks | 1.59 | 1.19 MB | 51.4 kB | 226.6 ms |
| React 19, Hooks with the React Compiler | 1.65 | 1.11 MB | 50.0 kB | 219.8 ms |

On these operations Angular and React are effectively tied, at about 1.5
times the duration of hand-written DOM code, while Solid and Svelte come much
closer to it. Flutter is absent because it does not render DOM rows at all.
The benchmark's own caveats matter: its development snapshot "may not have the
same quality" as the official releases, and the choice between keyed and
non-keyed modes "can be a performance gain or can cause severe
problems".[^jsfbrepo] A table of a thousand rows is one workload among many,
and a difference of a few milliseconds per operation is rarely what decides
how fast an application feels.

### Size: what the browser downloads

The counter apps above were built for production with each tool's default
command (`ng build`, `vite build`, and `flutter build web --release`, once for
JavaScript and once with `--wasm`; both Flutter builds used
`--no-web-resources-cdn` so that the engine was served from the same origin).
Each build was served without compression and loaded in headless Chrome 155;
every file the first load requested was recorded, and each was then compressed
with gzip at level 9 and brotli at quality 11. Favicons and Flutter's
installable-app icon were excluded.

{{< diagram src="sizes.svg" caption="Brotli-compressed bytes for the first load of the same counter app, on one linear scale." >}}

| Build | Files | Raw | gzip | brotli |
|---|---|---|---|---|
| Angular 22.2.3 | 3 | 99.2 kB | 33.3 kB | 30.0 kB |
| React 19.3.1, Vite 8.3.4 | 2 | 220.2 kB | 68.1 kB | 58.6 kB |
| Flutter 3.47.7 web, JavaScript and CanvasKit | 9 | 7,509.5 kB | 2,741.2 kB | 2,064.0 kB |
| Flutter 3.47.7 web, WebAssembly and skwasm | 10 | 5,320.7 kB | 2,215.9 kB | 1,738.7 kB |

The Angular build is a single 98.8 kB script, and the React build a single
219.8 kB script. Angular's compiled templates call
only the runtime instructions they use, which lets the bundler drop the
rest.[^ngaot] Flutter's largest files were its engine (`canvaskit.wasm` at
1,540.5 kB brotli, or `skwasm.wasm` at 1,209.8 kB), the compiled app and
framework (`main.dart.js` at 415.8 kB, or `main.dart.wasm` at 424.4 kB), and a
Roboto font at 74.8 kB, because a canvas cannot borrow the system's fonts.
The WebAssembly build needs a browser with WasmGC, which Chromium-based
browsers have had since version 119, and falls back to the JavaScript build
elsewhere.[^flwasm]

On Android the same app built with `flutter build apk --release
--split-per-abi` produced a 64-bit ARM APK of 15.1 MB (15,108,964 bytes),
which Flutter's tool reports as 14.4MB. Almost all of it was two native
libraries stored uncompressed: the engine, `libflutter.so` (11.7 MB), and the
compiled Dart code, `libapp.so` (3.0 MB). Compressed with deflate they would
be about 5.4 and 1.2 MB. Flutter's documentation warns that release APKs are
"not representative of your end-users' download size", because the stores
reprocess them per device, and its FAQ puts the engine and framework at "a few
megabytes compressed".[^flappsize][^flfaq]

### Why a toy app is not a verdict

Those numbers are real, but they measure the **fixed cost** of each tool, the
part every app pays before writing a line of its own. They say little about
real applications:

- **Fixed and growing costs differ.** In a real app, application code,
  libraries, images and fonts soon dominate. The median mobile web page
  already loaded 558 kB of JavaScript in the HTTP Archive's 2024 survey of the
  web, of which a framework is only one part.[^almanac]
- **Real apps load in pieces.** Angular's lazy routes and `@defer` blocks,
  and the code splitting of React frameworks, keep the first download small as
  an app grows.[^ngdefer][^rscratch]
- **Server rendering changes the first paint.** Angular's built-in server
  rendering and React frameworks such as Next.js send HTML that appears before
  any script runs; a Flutter web app shows nothing of its own until the engine
  has loaded.[^ngssr][^rnextrsc][^flwebinit]
- **Caching changes the second visit.** An engine downloaded once is cached
  for later visits, which matters more for a tool used daily than for a page
  visited once.

What the numbers do show is the **shape** of each choice. The DOM frameworks
start small and use what the browser already has. Flutter on the web starts at
about 1.7 to 2 MB compressed because it brings its own renderer, which is
acceptable for an application someone opens on purpose and uses for a long
time, and a poor fit for a page that must appear instantly from a search
result.

## Developer experience

### Getting started

Each project has a single command to begin, though React's documentation
points first to a framework:[^ngcli][^rcreating][^rscratch][^flcli]

```sh
npx @angular/cli new my-app                 # Angular
npx create-next-app@latest my-app           # React with Next.js
npm create vite@latest my-app -- --template react-ts   # React, client only
flutter create my_app                       # Flutter
```

### The edit-and-look loop

**Flutter** has the strongest story here: **stateful hot reload** injects
changed code into the running app in debug mode and keeps its state, so a
counter showing 2 would still show 2 after the button's colour was
changed.[^flhotreload] For
**React**, Vite's development server offers what it calls "extremely fast Hot
Module Replacement (HMR)".[^vite] **Angular**'s `ng serve` hot-replaces global
and component stylesheets, and reloads the page for other changes: its
documentation says that, for hot module replacement, "currently, only global
and component stylesheets are supported".[^ngserve]

### Language

Angular is written in TypeScript and expects applications to be too, with
templates type-checked at build time.[^ngaot] React works with plain
JavaScript, but the Vite template its documentation suggests is the TypeScript
one, and JSX type-checks like any other expression.[^rscratch] Flutter uses
Dart, a language with sound null safety, pattern matching and records, which
compiles just-in-time for development and ahead of time to machine code for
release.[^fldart3][^flbuildmodes] For a team that already knows TypeScript,
Angular and React need no new language; Flutter does.

### Tooling and testing

Angular's CLI creates, generates, serves, builds, tests and updates a project,
and new projects run unit tests with Vitest.[^ngcli][^ngtesting] React's
tooling is whatever the chosen framework or build tool provides, and tests
typically pair a runner such as Vitest with Testing Library.[^rscratch][^rrtl]
Flutter's CLI does the same jobs as Angular's, and its **widget tests** run the
real framework without a device or browser, as in the test that tapped the
counter above. DevTools adds a widget inspector, profilers and an app size
analyser.[^fltesting][^fldevtools]

## Ecosystem: what comes in the box

The table shows where each everyday need is met: in the core project, in a
package from the same team or organisation, or in the wider community.

| Need | Angular | React | Flutter |
|---|---|---|---|
| Components and rendering | Core | Core (`react`, `react-dom`) | Core |
| Routing | Core (`@angular/router`) | Community or framework (React Router, Next.js) | Core (`Navigator`); go_router recommended |
| Forms and validation | Core (`@angular/forms`) | Core Actions; validation from libraries | Core (`Form`, `TextFormField`) |
| HTTP | Core (`HttpClient`) | The browser's `fetch`; libraries such as TanStack Query | The `http` package, published by the Dart team |
| Shared state | Signals and services | Context; Redux and other libraries | provider, Riverpod, Bloc and others |
| Server rendering | Core (`@angular/ssr`) | Frameworks (Next.js, React Router) | Not applicable |
| Component library | Angular Aria and the CDK from the Angular team | Community libraries | Material and Cupertino |
| Build and CLI | Core | Vite or a framework | Core |
| Native mobile | Community: Ionic, NativeScript | React Native | Core |

The table follows each project's documentation.[^ngoverview][^nga11y][^ngssr][^rscratch][^rredux][^rcreating][^flnav][^flgorouter][^flforms][^flhttp][^flhttppub][^flstatemgmt][^ionic][^nativescript]

Angular's integrated approach means fewer choices and fewer compatibility
problems: the pieces are designed and released together. React's approach
means more choice and the largest pool of third-party libraries of the three,
at the cost of assembling them and of more churn; Create React App, once the
official starter, is now deprecated.[^rcra] Flutter sits in between: the core
covers far more than React's does, and its packages are published on pub.dev,
where the documentation's architecture guide recommends but does not require
particular packages.[^flstatemgmt][^flarchrec]

## Stability and upgrades

How often a tool breaks its users matters more for an application that will
live for ten years than for one that will live for one.

- **Angular** has the most explicit policy. Since version 22 a new major
  version comes every twelve months, with four to six minor releases in
  between; each major is supported for about 24 months, 12 of them in
  long-term support; and a deprecated API stays for at least one major
  version. `ng update` applies migrations that the team writes for its own
  breaking changes.[^ngreleases][^ngupdate] Its history also includes a famous
  break, the rewrite from AngularJS, whose long-term support ended at the end
  of 2021.[^ngangularjseol]
- **React** follows semantic versioning for stable releases and tries "to
  minimize the number of major releases", adding warnings first so that "if
  your app has no warnings on the latest release, it will be compatible with
  the next major release".
  There is no long-term support window, but the team releases "a backported
  fix for all major versions that are affected" by a security
  vulnerability.[^rversioning] The churn is in the ecosystem instead, and in
  newer, lower-level areas: the APIs for building Server Component frameworks
  are not covered by semantic versioning.[^rv19]
- **Flutter** ships a stable release about every three months.[^fldecouple]
  Its compatibility policy is based on a registry of tests contributed by
  developers, which no change may break without the team working with their
  owners, and substantive breaking changes are designed in public first;
  `dart fix` applies automated migrations for deprecated APIs.[^flcompat][^flfix]
  Its documentation describes no support window for older releases. In 2026
  the Material and Cupertino libraries began moving out of the framework into separately
  released packages.[^fldecouple]

## Accessibility and search on the web

Because Angular and React produce real HTML, they start with the browser's
built-in accessibility: a `<button>` is a button to a screen reader, and
headings, links and form controls carry their native meaning. Angular's
guidance is to reuse native elements "rather than re-implementing
well-supported behaviors", bind ARIA attributes in templates, and use its CDK
and Angular Aria for complex widgets.[^nga11y] React "fully supports building
accessible websites, often by using standard HTML techniques", with all
`aria-*` attributes supported in JSX.[^ra11y] Either can of course still
produce inaccessible pages; they simply do not stand in the way.

Flutter on the web paints a canvas, so it builds a parallel tree of DOM
elements for assistive technology to read. For performance reasons that tree
is off until a screen reader user activates a hidden button, or the app turns
it on itself.[^fla11yweb]

**Search** is where the difference is largest. Google renders JavaScript with
a headless Chromium before indexing, but recommends that "server-side or
pre-rendering is still a great idea because it makes your website faster for
users and crawlers", and notes that "not all bots can run
JavaScript".[^gsearch] Angular renders on the server out of the box, and React
does so through frameworks such as Next.js.[^ngssr][^rnextrsc] Flutter's own
documentation says it "is not suitable for static websites with text-rich
flow-based content" and that its output does not align with what search
engines need; it suggests keeping landing pages in ordinary HTML. The Flutter
team followed that advice for its own websites, which it rebuilt in 2026 with
Jaspr, a DOM-based Dart framework.[^flwebfaq][^fljaspr]

## Mobile and desktop

On devices, the comparison changes sides: Flutter is the native option, and
the web frameworks need help.

- **Flutter** produces Android and iOS apps, desktop apps for Windows, macOS
  and Linux, and embedded apps, all from one code base and with the same
  rendering on each.[^flfaq][^flarch] Its interface is not made of the
  platform's own widgets: Material and Cupertino are reimplementations, so a
  new platform design, such as Apple's Liquid Glass, has to be reimplemented
  too.[^fldecouple]
- **React** reaches phones through **React Native**, which renders to the
  platform's own views: "React primitives render to native platform UI".[^rrnhome]
  Its New Architecture, the default since version 0.76, replaced the old
  asynchronous bridge with direct calls through the JavaScript
  Interface.[^rrnnewarch] Versions for Windows and macOS are developed by
  partners in Microsoft's GitHub organisation, and React's documentation
  recommends Expo as the framework for native apps.[^rrnoot][^rcreating] A React web app and a React Native app can share
  logic and skills, but not their UI components, which target different
  primitives.
- **Angular** has no mobile runtime of its own. **Ionic** builds mobile apps
  from web technology, deploying them with Capacitor or Cordova or as
  progressive web apps, and integrates with Angular, React and Vue;
  **NativeScript** gives JavaScript direct access to platform APIs and has an
  Angular flavour.[^ionic][^nativescript]

Flutter's guide for React Native developers says that Flutter "controls each
pixel on the screen, which avoids performance problems caused by the need for
a JavaScript bridge".[^flrnguide] That argument was aimed at React Native's
old architecture; the New Architecture's direct calls were designed to remove
exactly that bottleneck, so it is weaker than it was.[^rrnnewarch]

## Teams, hiring and longevity

A framework is also a labour market. In Stack Overflow's 2026 survey, 41.5
percent of respondents had done extensive work with React in the past year,
16.0 percent with Angular, and 20.6 percent with Next.js; 46.7 percent of
React's users and 42.1 percent of Angular's wanted to keep using it. Among
languages, JavaScript was used by 62.0 percent and TypeScript by 43.8 percent,
against 4.9 percent for Dart.[^so2026] The 2026 survey did not ask about
mobile frameworks; the 2024 survey did, and found Flutter used by 9.4 percent
and React Native by 8.4 percent.[^so2024]

Those figures support some cautious conclusions. React developers are the
easiest to find, and so are React libraries and answers. Angular's community
is smaller, though still one developer in six in that survey. Flutter
developers need Dart, which few developers use, while both web frameworks use
the JavaScript and TypeScript that most front-end developers already know.

Longevity is about stewards as well as users. Angular and Flutter are both
Google projects. Angular is used for Google products such as Gemini and Google
Analytics, and Google plans to merge it gradually with Wiz, its internal
framework for performance-critical apps.[^ngwiz] Google's
2024 layoffs in the Flutter and Dart teams, and the community fork Flock
that followed, show that some developers worry about depending on one
company's priorities.[^fltechcrunch][^flflock] React moved from Meta to the
React Foundation in 2026, hosted by the Linux Foundation and backed by several
companies.[^rfoundation]

## How to choose

### Questions to ask first

1. **Is it a document or an application?** Pages that people read and find
   through search, such as documentation, blogs, marketing and product pages,
   want HTML first. Applications that people log into and use for a long time
   can afford more JavaScript, or an engine.
2. **Where must it run?** Browser only, or also on phones and desktops? If on
   devices, does it need the platform's own look, or a design of its own?
3. **Who will build and maintain it, and for how long?** A large team over
   many years benefits from conventions and a single upgrade path; a small team
   moving fast may prefer to pick its own pieces.
4. **What does the team already know?** Existing skills and existing code
   usually outweigh every technical difference in this article.
5. **What is the budget for the first load?** A shop page opened from a
   search result and an internal tool opened every morning have very different
   limits.

### A decision chart

{{< diagram src="decision.svg" caption="A first pass at the choice. Each outcome is a place to start looking, not a final answer." >}}

### Scenarios

| Situation | A good starting point | Why |
|---|---|---|
| Content-heavy public site: docs, blog, marketing | Static or server-rendered HTML, with little JavaScript; a React or Angular framework with server rendering if parts are interactive | Fast first paint and indexing matter most; Flutter's own documentation advises against it here[^webdevrendering][^gsearch][^flwebfaq] |
| Large enterprise or internal web app, many developers, long life | Angular | Everything included, strong conventions, a published support policy and automated migrations[^ngreleases][^ngupdate] |
| Web product that wants a broad ecosystem, or a team of React developers | React with Next.js or React Router | The largest community and library ecosystem, and server rendering through the framework[^so2026][^rcreating] |
| Startup MVP, web only | Whatever the team knows best; otherwise React with a framework | Speed of the first release outweighs framework differences |
| Mobile-first consumer app for iOS and Android, custom design | Flutter | One code base, identical rendering, hot reload, design freedom[^flfaq][^flhotreload] |
| Mobile app that should look and feel native, from a web team that knows React | React Native, with Expo | Native platform views and shared React skills[^rrnhome][^rcreating] |
| The same branded UI on mobile, desktop and web | Flutter | Its own renderer on every platform; accept the web's size and search trade-offs[^flarch][^flwebfaq] |
| An app for one platform that must follow its latest design closely | SwiftUI on Apple platforms, Jetpack Compose on Android | The platforms' own recommended toolkits[^swiftui][^compose] |
| An existing app | Usually keep its framework, and modernise within it | Angular's migrations, React's warnings-first policy and Flutter's `dart fix` exist for this[^ngupdate][^rversioning][^flfix] |

### When the answer is none of them

Sometimes none of the three is right. For pages whose job is to be read, the
authors of web.dev's guide to rendering "encourage developers to consider
server-side rendering or static rendering over a full rehydration approach",
and add that it is fine to "mostly ship HTML with minimal JavaScript".[^webdevrendering]
A small widget on an otherwise static page is often better written without a
framework at all. And for an app that targets one platform and must feel
entirely at home there, the platforms' own toolkits are the default: Apple
describes SwiftUI as building apps "across all Apple platforms", and Google
calls Jetpack Compose "Android's recommended modern toolkit for building native
UI".[^swiftui][^compose]

## Where comparisons mislead

Comparisons of frameworks, including this one, are easy to over-read. Three
kinds of evidence are especially slippery.

- **Benchmarks measure what they measure.** The js-framework-benchmark times
  table operations in one browser on one machine; it does not measure network
  loading on a slow phone, a real application's data, developer productivity or
  code quality, and Flutter cannot even enter it. Its author warns against
  reading the development snapshot as an official result.[^jsfbrepo]
- **Surveys measure who answers.** Developer surveys are self-selected, and
  their questions change. Stack Overflow's 2026 survey had 10,281 respondents,
  against 35,100 answers to the 2024 question on other frameworks, and it did
  not ask about mobile frameworks, so Flutter appears in it only as a
  write-in among *web* frameworks, at 0.2 percent.[^so2026][^so2024] A reader
  who compared the two years naively would conclude that Flutter had
  collapsed. State of JavaScript's 2025 survey noted that React "tops the list
  of things front-end developers are struggling with", but added that this is
  what "being the dominant framework also means".[^stateofjs]
- **Popularity among developers is not popularity on the web.** The HTTP
  Archive, which measures real pages across the web, found React on 10 percent
  of them in 2024, and jQuery on 75 percent of desktop pages.[^almanac] The
  most popular of the three among developers runs on one page in ten.
- **Toy apps measure fixed costs.** As shown above, a counter tells you each
  tool's starting weight, not how a real application will perform.

## Why it matters

Angular, React and Flutter are three answers to the same problem: keeping a
complicated interface in step with changing data without writing every update
by hand. Angular answers with a complete, opinionated framework and precise
dependency tracking; React with a small, stable core idea and an enormous
ecosystem around it; Flutter by owning the entire rendering stack, so that one
program looks the same everywhere. Knowing which kind of thing each one is
explains most of what they are good at and most of what they cost, and turns
"which is best?" into the more useful question of which fits this product,
this team and this platform.

## References

[^ngoverview]: Angular. (n.d.). What is Angular? *angular.dev*. <https://angular.dev/overview>

[^ngjschangelog]: AngularJS. (2022). *CHANGELOG.md* [Source code repository, archived]. GitHub. <https://github.com/angular/angular.js/blob/master/CHANGELOG.md>

[^ngv2]: Kremer, J. (2016, September 22). Angular, version 2: proprioception-reinforcement. *Google Open Source Blog*. <https://opensource.googleblog.com/2016/09/angular-version-2-proprioception.html>

[^nglicense]: Angular. (2026). *LICENSE* [MIT License; Copyright (c) 2010–2026 Google LLC]. GitHub. <https://github.com/angular/angular/blob/main/LICENSE>

[^ngaot]: Angular. (n.d.). Ahead-of-time (AOT) compilation. *angular.dev*. <https://angular.dev/tools/cli/aot-compiler>

[^ngzoneless]: Angular. (n.d.). Angular without ZoneJS (Zoneless). *angular.dev*. <https://angular.dev/guide/zoneless>

[^ngv22]: Angular. (2026, June 3). Announcing Angular v22. *Angular Blog*. <https://blog.angular.dev/announcing-angular-v22-c52bb83a4664>

[^ngssr]: Angular. (n.d.). Server and hybrid rendering. *angular.dev*. <https://angular.dev/guide/ssr>

[^ngreleases]: Angular. (n.d.). Versioning and releases. *angular.dev*. <https://angular.dev/reference/releases>

[^ngdi]: Angular. (n.d.). Dependency injection in Angular. *angular.dev*. <https://angular.dev/guide/di>

[^ngsignals]: Angular. (n.d.). Signals. *angular.dev*. <https://angular.dev/guide/signals>

[^ngcontrolflow]: Angular. (n.d.). Control flow. *angular.dev*. <https://angular.dev/guide/templates/control-flow>

[^ngrouting]: Angular. (n.d.). Routing in Angular. *angular.dev*. <https://angular.dev/guide/routing>

[^ngforms]: Angular. (n.d.). Forms in Angular. *angular.dev*. <https://angular.dev/guide/forms>

[^nghttp]: Angular. (n.d.). Making HTTP requests. *angular.dev*. <https://angular.dev/guide/http/making-requests>

[^ngtesting]: Angular. (n.d.). Testing. *angular.dev*. <https://angular.dev/guide/testing>

[^ngdefer]: Angular. (n.d.). Deferred loading with @defer. *angular.dev*. <https://angular.dev/guide/templates/defer>

[^ngcli]: Angular. (n.d.). CLI reference. *angular.dev*. <https://angular.dev/cli>

[^ngserve]: Angular. (n.d.). ng serve. In *CLI reference*. *angular.dev*. <https://angular.dev/cli/serve>

[^ngupdate]: Angular. (n.d.). ng update. *angular.dev*. <https://angular.dev/cli/update>

[^nga11y]: Angular. (n.d.). Accessibility in Angular. *angular.dev*. <https://angular.dev/best-practices/a11y>

[^ngangularjseol]: Thompson, M. (2022, January 11). Discontinued long term support for AngularJS. *Angular Blog*. <https://blog.angular.dev/discontinued-long-term-support-for-angularjs-cc066b82e65a>

[^ngwiz]: Ramanathan, J., & Gechev, M. (2024, March 29). Angular and Wiz are better together. *Angular Blog*. <https://blog.angular.dev/angular-and-wiz-are-better-together-91e633d8cd5a>

[^rrepo]: React. (n.d.). *react/react: The library for web and native user interfaces* [Source code repository]. GitHub. <https://github.com/react/react>

[^rlicense]: React. (n.d.). *LICENSE* [MIT License; Copyright (c) Meta Platforms, Inc. and affiliates]. GitHub. <https://github.com/react/react/blob/main/LICENSE>

[^rcreating]: React. (n.d.). Creating a React app. In *React documentation*. <https://react.dev/learn/creating-a-react-app>

[^rscratch]: React. (n.d.). Build a React app from scratch. In *React documentation*. <https://react.dev/learn/build-a-react-app-from-scratch>

[^rversions]: React. (n.d.). React versions. In *React documentation*. <https://react.dev/versions>

[^rfoundation]: Carroll, M. (2026, February 24). The React Foundation: A new home for React hosted by the Linux Foundation. *React Blog*. <https://react.dev/blog/2026/02/24/the-react-foundation>

[^rrendercommit]: React. (n.d.). Render and commit. In *React documentation*. <https://react.dev/learn/render-and-commit>

[^rpure]: React. (n.d.). Keeping components pure. In *React documentation*. <https://react.dev/learn/keeping-components-pure>

[^rthinking]: React. (n.d.). Thinking in React. In *React documentation*. <https://react.dev/learn/thinking-in-react>

[^rreconciliation]: React. (n.d.). Reconciliation. In *React documentation* (legacy). <https://legacy.reactjs.org/docs/reconciliation.html>

[^rv19]: The React Team. (2024, December 5). React v19. *React Blog*. <https://react.dev/blog/2024/12/05/react-19>

[^rcompilerintro]: React. (n.d.). Introduction. In *React Compiler documentation*. <https://react.dev/learn/react-compiler/introduction>

[^rcontext]: React. (n.d.). Passing data deeply with context. In *React documentation*. <https://react.dev/learn/passing-data-deeply-with-context>

[^rrtl]: Testing Library. (n.d.). Guiding principles. <https://testing-library.com/docs/guiding-principles>

[^rredux]: Redux. (n.d.). Getting started with Redux. In *Redux documentation*. <https://redux.js.org/introduction/getting-started>

[^rcra]: Carroll, M., & Hanlon, R. (2025, February 14). Sunsetting Create React App. *React Blog*. <https://react.dev/blog/2025/02/14/sunsetting-create-react-app>

[^rnextrsc]: Vercel. (n.d.). Server and Client Components. In *Next.js documentation*. <https://nextjs.org/docs/app/getting-started/server-and-client-components>

[^rversioning]: React. (n.d.). Versioning policy. In *React documentation*. <https://react.dev/community/versioning-policy>

[^ra11y]: React. (n.d.). Accessibility. In *React documentation* (legacy). <https://legacy.reactjs.org/docs/accessibility.html>

[^rrnhome]: React Native. (n.d.). *React Native: Learn once, write anywhere*. <https://reactnative.dev/>

[^rrnnewarch]: The React Team. (2024, October 23). New Architecture is here. *React Native Blog*. <https://reactnative.dev/blog/2024/10/23/the-new-architecture-is-here>

[^rrnoot]: React Native. (n.d.). Out-of-tree platforms. In *React Native documentation*. <https://reactnative.dev/docs/out-of-tree-platforms>

[^flfaq]: Flutter. (n.d.). FAQ. *Flutter documentation*. <https://docs.flutter.dev/resources/faq>

[^flarch]: Flutter. (n.d.). Flutter architectural overview. *Flutter documentation*. <https://docs.flutter.dev/resources/architectural-overview>

[^flrepo]: Flutter. (n.d.). *flutter/flutter* [Source code repository; BSD 3-Clause licence]. GitHub. <https://github.com/flutter/flutter>

[^flflutter1]: Sneath, T. (2018, December 4). Flutter 1.0: Google's portable UI toolkit. *Google Developers Blog*. <https://developers.googleblog.com/en/flutter-10-googles-portable-ui-toolkit/>

[^flimpeller]: Flutter. (n.d.). Impeller rendering engine. *Flutter documentation*. <https://docs.flutter.dev/perf/impeller>

[^flconstraints]: Flutter. (n.d.). Understanding constraints. *Flutter documentation*. <https://docs.flutter.dev/ui/layout/constraints>

[^flrnguide]: Flutter. (n.d.). Flutter for React Native developers. *Flutter documentation*. <https://docs.flutter.dev/get-started/flutter-for/react-native-devs>

[^flstatemgmt]: Flutter. (n.d.). List of state management approaches. *Flutter documentation*. <https://docs.flutter.dev/data-and-backend/state-mgmt/options>

[^flnav]: Flutter. (n.d.). Navigation and routing. *Flutter documentation*. <https://docs.flutter.dev/ui/navigation>

[^flgorouter]: Flutter. (n.d.). *go_router* [Dart package]. pub.dev. <https://pub.dev/packages/go_router>

[^flforms]: Flutter. (n.d.). Build a form with validation. In *Flutter cookbook*. <https://docs.flutter.dev/cookbook/forms/validation>

[^flhttp]: Flutter. (n.d.). Fetch data from the internet. In *Flutter cookbook*. <https://docs.flutter.dev/cookbook/networking/fetch-data>

[^flhttppub]: Dart. (n.d.). *http* [Dart package; verified publisher dart.dev]. pub.dev. <https://pub.dev/packages/http>

[^fltesting]: Flutter. (n.d.). Testing Flutter apps. *Flutter documentation*. <https://docs.flutter.dev/testing/overview>

[^flarchrec]: Flutter. (n.d.). Architecture recommendations and resources. *Flutter documentation*. <https://docs.flutter.dev/app-architecture/recommendations>

[^flwebinit]: Flutter. (n.d.). Flutter web app initialization. *Flutter documentation*. <https://docs.flutter.dev/platform-integration/web/initialization>

[^flwasm]: Flutter. (n.d.). Support for WebAssembly (Wasm). *Flutter documentation*. <https://docs.flutter.dev/platform-integration/web/wasm>

[^flwebfaq]: Flutter. (n.d.). Web FAQ. *Flutter documentation*. <https://docs.flutter.dev/platform-integration/web/faq>

[^fla11yweb]: Steiner, T. (2024, April 16). Accessibility in Flutter on the web. *Flutter Blog*. <https://flutter.dev/blog/accessibility-in-flutter-on-the-web>

[^fljaspr]: Lougheed, P. (2026, April 15). We rebuilt Flutter's websites with Dart and Jaspr. *Flutter Blog*. <https://flutter.dev/blog/we-rebuilt-flutters-websites-with-dart-and-jaspr>

[^flappsize]: Flutter. (n.d.). Measuring your app's size. *Flutter documentation*. <https://docs.flutter.dev/perf/app-size>

[^flhotreload]: Flutter. (n.d.). Hot reload. *Flutter documentation*. <https://docs.flutter.dev/tools/hot-reload>

[^fldart3]: Thomsen, M. (2023, May 10). Announcing Dart 3. *Dart Blog*. <https://dart.dev/blog/announcing-dart-3>

[^flbuildmodes]: Flutter. (n.d.). Flutter's build modes. *Flutter documentation*. <https://docs.flutter.dev/testing/build-modes>

[^flcli]: Flutter. (n.d.). The Flutter command-line tool. *Flutter documentation*. <https://docs.flutter.dev/reference/flutter-cli>

[^fldevtools]: Flutter. (n.d.). Flutter and Dart DevTools. *Flutter documentation*. <https://docs.flutter.dev/tools/devtools>

[^flcompat]: Flutter. (n.d.). Flutter compatibility policy. *Flutter documentation*. <https://docs.flutter.dev/release/compatibility-policy>

[^flfix]: Flutter. (n.d.). Flutter fix. *Flutter documentation*. <https://docs.flutter.dev/tools/flutter-fix>

[^fldecouple]: Labenz, C. (2026, September 9). Decoupling Material and Cupertino. *Flutter Blog*. <https://flutter.dev/blog/decoupling-material-cupertino>

[^fltechcrunch]: Perez, S. (2024, April 29; updated May 1). Google lays off staff from Flutter, Dart and Python weeks before its developer conference. *TechCrunch*. <https://techcrunch.com/2024/04/29/google-lays-off-staff-from-flutter-dart-python-weeks-before-its-developer-conference>

[^flflock]: Anderson, T. (2024, October 30). Flutter forked as Flock, developer cites "company-wide issues at Google". *DevClass*. <https://devclass.com/2024/10/30/flutter-forked-as-flock-developer-cites-company-wide-issues-at-google>

[^ionic]: Ionic. (n.d.). Ionic Framework documentation. <https://ionicframework.com/docs>

[^nativescript]: NativeScript. (n.d.). NativeScript documentation. <https://docs.nativescript.org/>

[^swiftui]: Apple. (n.d.). SwiftUI. *Apple Developer*. <https://developer.apple.com/swiftui/>

[^compose]: Google. (n.d.). Jetpack Compose. *Android Developers*. <https://developer.android.com/compose>

[^vite]: Vite. (n.d.). Getting started. In *Vite guide*. <https://vite.dev/guide/>

[^gsearch]: Google. (n.d.). Understand the JavaScript SEO basics. *Google Search Central*. <https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics>

[^webdevrendering]: Miller, J., & Osmani, A. (2019, February 6; updated 2026, January 5). Rendering on the web. *web.dev*. <https://web.dev/articles/rendering-on-the-web>

[^jsfb]: Krause, S. (2026). *js-framework-benchmark: Official results for Chrome 154* [Benchmark results, keyed implementations]. <https://krausest.github.io/js-framework-benchmark/2026/chrome154.html>

[^jsfbrepo]: Krause, S. (n.d.). *js-framework-benchmark* [Source code repository and README]. GitHub. <https://github.com/krausest/js-framework-benchmark>

[^almanac]: Amjad, A. H., & Goel, N. (2025, March 3; updated 2026, January 16). JavaScript. In *The 2024 Web Almanac*. HTTP Archive. <https://almanac.httparchive.org/en/2024/javascript>

[^so2026]: Stack Overflow. (2026). Technology. In *2026 Developer Survey* [Full data]. <https://survey.stackoverflow.co/2026/technology/data>

[^so2024]: Stack Overflow. (2024). Other frameworks and libraries. In *2024 Developer Survey: Technology*. <https://survey.stackoverflow.co/2024/technology#most-popular-technologies-misc-tech>

[^stateofjs]: Devographics. (2026). Front-end frameworks. In *State of JavaScript 2025*. <https://2025.stateofjs.com/en-US/libraries/front-end-frameworks/>
