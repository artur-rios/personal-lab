---
title: "What Is Flutter? History, Architecture and How to Build With It"
description: "Flutter is Google's toolkit for building apps for mobile, web, desktop and embedded devices from one Dart code base, by drawing every pixel itself. Here is where it came from, how it works inside (widgets, elements and render objects, constraints-based layout, the Impeller renderer, Dart's JIT and AOT compilers), how to work with it day to day, and what it is good and bad at."
date: 2026-10-20T18:00:00Z
categories: ["Front-end"]
tags: ["Flutter", "Dart", "Mobile", "Cross-platform", "UI Frameworks", "Front-end"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Most toolkits for building an app on more than one platform make a choice
early on: either they wrap each platform's own buttons, lists and text fields,
or they run the app inside a web view. Flutter does neither. It ships its own
rendering engine inside every app and draws every pixel of the interface
itself, from the text to the scroll bars, on a canvas the operating system
hands it. The same Dart code then runs on Android, iOS, the web, Windows,
macOS and Linux, and on embedded devices through a custom host.

This article covers where Flutter came from, how it turns widgets into pixels,
how to build an app with it, and what that design costs. The examples were run
with Flutter 3.47.7 and Dart 3.13.5, the current stable release when this was
written,[^releases] and their output is shown as printed.

## What Flutter is

**Flutter is an open-source UI toolkit, created by Google, for building
natively compiled applications for mobile, web, desktop and embedded devices
from a single code base.** Applications are written in **Dart**, a language
also developed at Google, and the framework itself is written in Dart too, so
an app and the toolkit beneath it are one program.[^arch][^faq]

Its defining trait is how it draws. Flutter "doesn't rely on web browser views
or system-provided platform widgets": it renders its interface with its own
engine.[^faq] A Flutter button is not an Android `Button` or an iOS
`UIButton`; it is a set of shapes and text that the framework lays out and the
engine paints. Flutter provides two complete design libraries out of the box,
**Material** (Google's design system) and **Cupertino** (in the style of
Apple's iOS), and an app can use either, both or neither.[^arch][^faq]

| Target | What Flutter produces |
|---|---|
| **Android** | An Android app (ARM32, ARM64, x86_64) that hosts Flutter in an `Activity` |
| **iOS** | An iOS app (ARM64) that hosts Flutter in a `UIViewController` |
| **Web** | A web app compiled to JavaScript or WebAssembly, drawing into a canvas |
| **Windows, macOS, Linux** | A native desktop application |
| **Embedded** | Anything with a custom *embedder*, such as a Raspberry Pi |

The table follows Flutter's own FAQ and architectural overview.[^faq][^arch]
The framework is under the BSD 3-Clause licence and its development is
"managed by Google, with contributions from a global community".[^faq][^repo]

Flutter's documentation lists three guiding principles: **control**, since the
whole framework is open Dart code an app can inspect and override;
**performance**, from compiling to machine code and rendering directly; and
**fidelity**, the same pixels on every platform.[^faq]

## A history of Flutter

### From Chrome to Sky

Flutter began inside Google's Chrome team. Eric Seidel and several colleagues
experimented with how fast they could make Chrome render pages, and found that
much of the slowness came from code kept for compatibility with a small set of
sites; stripping it out showed how fast a UI framework could be. Because the
web adopts new standards slowly, they decided to build that framework outside
the web.[^sed] Seidel later wrote that "a group of us left the Chrome team
believing there had to be something better than janky web pages, or
complicated Java apps to build for mobile".[^shorebird]

The project's source repository, `flutter/flutter`, was created on GitHub in
March 2015.[^repo] It was shown publicly the next month, at the **Dart Developer
Summit** in San Francisco, under the name **Sky**, in a talk titled "Sky: An
Experiment Writing Dart for Mobile".[^dartsummit][^skyvideo] Sky apps for
Android could be written without a line of Java, its engineers talked of
reaching 120 frames per second, more than phones of the day could display, and
the design aimed to keep the interface from freezing even when work in the
background slowed down.[^9to5]

### Why Dart

Dart itself was older. Lars Bak and Gilad Bracha announced it in October 2011
at the GOTO conference in Aarhus as a language for structured web programming:
JavaScript-like syntax, *optional* static types that only produced warnings,
compilation to JavaScript, a dedicated virtual machine, and **isolates**,
concurrent workers that share no state and communicate by
messages.[^infoq] Dart 1.0 followed in November 2013.[^dart1]

When Flutter adopted Dart, the language changed to suit it. **Dart 2**, in
2018, was described as "uniquely optimized for client-side development": it
"dramatically strengthened and streamlined the type system", and made the
`new` and `const` keywords optional so that a nested tree of widgets reads like
markup.[^dart2] Today's Dart type system is **sound**: a program "can't get
into certain invalid states", which the language enforces with a mix of
compile-time and runtime checks.[^typesys] Flutter's FAQ gives the reasons it
chose Dart: a just-in-time compiler for fast development with **hot reload**,
an ahead-of-time compiler for fast native code in production, an object model
that suits composing user interfaces without a separate markup language, and a
garbage collector tuned for allocating and discarding many short-lived
objects.[^faq]

### Beta and 1.0

Sky became Flutter. The **first beta** was announced on 27 February 2018 at
Mobile World Congress, already running in production apps such as the official
app for the musical *Hamilton*.[^beta1] **Flutter 1.0** was released on
4 December 2018 at the Flutter Live event as "the first stable release of
Google's UI toolkit", for iOS and Android.[^flutter1] It was then rendering with
Skia, the 2D graphics library used by Chrome and Android, compiled Dart ahead
of time to native ARM code, and listed users such as Alibaba, Capital One,
Groupon, Philips Hue, Tencent and the Google Ads app.[^flutter1]

### Beyond mobile

The same event previewed **Hummingbird**, an experiment that reimplemented the
engine's `dart:ui` layer on top of the browser so the rest of the framework
could run unchanged on the web, compiled to JavaScript by `dart2js`.[^hummingbird]
Web support reached beta with Flutter 1.12 in December 2019.[^webbeta] A Linux
alpha, built jointly with Canonical, followed in July 2020.[^linux]

**Flutter 2** (3 March 2021) moved web support to the stable channel and
shipped **sound null safety**, which arrived in Dart 2.12 the same day: types
are non-nullable unless declared otherwise, and the compiler proves it.
Desktop support was available as a beta, and the announcement counted more
than 150,000 Flutter apps.[^flutter2][^dart212] Windows support became stable
in Flutter 2.10, in February 2022,[^windows] and **Flutter 3** (11 May 2022)
added stable macOS and Linux, making six platforms in all. By then over 500,000
apps had been built with Flutter.[^flutter3]

### A new renderer and Dart 3

Flutter's biggest internal change since 1.0 was its renderer. Skia compiled
the GPU programs it needed, called **shaders**, while the app was running, the
first time each kind of drawing was required. That could take long enough to
drop frames, so animations stuttered on their first run, a problem the Flutter
team called **shader compilation jank**. It was worst on iOS, which unlike
Android kept no persistent cache of compiled shaders.[^shaderwarm] The workaround,
"warming up" shaders by drawing everything an app would need in advance,
took expert analysis or automated tests that exercised the app's drawing, and
by 2022 the team's stated aim was to remove "the need for shader warm-up
entirely".[^shaderwarm][^hixie]

That became **Impeller**, a new rendering runtime that "precompiles a smaller,
simpler set of shaders at engine-build time so they don't compile at
runtime".[^impeller] It was previewed on iOS in Flutter 3.7 (January 2023)[^f37]
and became the default there in Flutter 3.10 (10 May 2023),[^f310] which shipped
alongside **Dart 3**. Dart 3 made null safety mandatory ("100% sound null
safety") and added records, patterns, sealed classes with exhaustive
`switch`, and class modifiers.[^dart3] Flutter 3.16 (November 2023) made the
**Material 3** design the default.[^f316]

### 2024 to 2026

- **WebAssembly.** Flutter 3.22 (May 2024) put compilation to WebAssembly on
  the stable channel; Google reported frame rendering times about two times
  faster on average in its Wonderous sample app.[^f322] Flutter 3.29
  (February 2025) removed the older HTML renderer for the
  web.[^f329]
- **Impeller everywhere.** Impeller became the default on modern Android
  devices with Vulkan in Flutter 3.27 (December 2024),[^f327] and the only
  renderer on iOS in 3.29, when Skia support was removed there.[^f329] In 3.47
  (August 2026) it became the default on macOS, Windows and Linux;
  the web still uses Skia.[^f347][^impeller]
- **Threads.** From Flutter 3.29, on Android and iOS, Dart code runs on the
  application's main thread instead of a separate UI thread.[^f329][^arch]
- **People and pressure.** In April 2024 Google laid off staff across several
  developer teams, including Flutter and Dart.[^techcrunch] In October 2024 a
  former Flutter team member, Matt Carroll, announced **Flock**, a fork meant
  to merge fixes faster and feed them back, arguing that desktop platforms had
  been neglected.[^flock] Google's published 2026 roadmap includes letting new
  platforms be added to the engine outside the main repository, alongside
  advisory boards and other community programmes.[^roadmap2026]
- **Decoupled design libraries.** In August 2026 Material and Cupertino were
  frozen inside the framework and published as standalone packages,
  `material_ui` and `cupertino_ui` 1.0, so they can be released weekly instead
  of with each quarterly Flutter release; the built-in copies are to be
  deprecated and eventually removed.[^decouple][^f347]

Flutter now ships a stable release every three months,[^decouple] recently
3.38 in November 2025, 3.41 in February 2026, 3.44 at Google I/O in May 2026
and 3.47 in August 2026, with 3.50 scheduled for November
2026.[^whatsnewdocs][^archive]

## A timeline at a glance

| Year | Milestone |
|---|---|
| 2011 | Dart announced at GOTO Aarhus |
| 2013 | Dart 1.0 |
| 2015 | "Sky" shown at the Dart Developer Summit |
| 2018 | Flutter beta (February); Dart 2; Flutter 1.0 and the Hummingbird web preview (December) |
| 2019 | Web support in beta (Flutter 1.12) |
| 2020 | Linux alpha with Canonical |
| 2021 | Flutter 2: stable web, sound null safety (Dart 2.12) |
| 2022 | Stable Windows (2.10); Flutter 3: six stable platforms |
| 2023 | Impeller the default on iOS (3.10); Dart 3; Material 3 by default (3.16) |
| 2024 | WebAssembly on stable (3.22); Flock fork; Impeller the default on Android (3.27) |
| 2025 | HTML web renderer and iOS Skia removed; Dart on the main thread (3.29) |
| 2026 | Impeller the default on desktop; Material and Cupertino as standalone packages (3.47) |

## How Flutter works

### Three layers

Flutter is built as a stack of layers, each depending only on the one below,
and "every part of the framework level is designed to be optional and
replaceable":[^arch]

{{< diagram src="layers.svg" caption="Flutter's layers. Everything above `dart:ui` is Dart that ships with your app; the engine is C++, and the embedder is written in each platform's own language." >}}

- The **embedder** is the platform-specific host. It is written in Java and
  C++ on Android, Swift and Objective-C on iOS and macOS, and C++ on Windows
  and Linux. It provides the entry point, obtains a surface to draw on, feeds
  in input and accessibility events, and runs the event loop.[^arch]
- The **engine**, written mostly in C++, is "responsible for rasterizing
  composited scenes". It also provides text layout, file and network I/O, the
  Dart runtime and the plumbing that connects Dart to native code. The
  framework reaches it only through the `dart:ui` library, which wraps the
  engine's C++ in Dart classes.[^arch]
- The **framework**, in Dart, is what apps program against: foundation
  classes, animation, painting, gestures, a **rendering** layer that does
  layout, a **widgets** layer on top, and the Material and Cupertino
  libraries.[^arch]

Because the engine ships inside every app, an app gets the same rendering
behaviour on every version of the operating system, and rendering improvements
arrive with a Flutter upgrade rather than an OS update.[^arch]

### Everything is a widget

Flutter describes its interface as a function of state, `UI = f(state)`: an
app declares what the screen should look like for the current state, and the
framework works out what to change.[^arch] The unit of that description is the
**widget**, an immutable object that configures part of the interface. "In
Flutter, almost everything is a widget—even layout models are
widgets":[^layout] padding is a `Padding` widget, centring is a `Center`
widget, and a screen is a tree of them.

Widgets favour composition over configuration. `Padding` is a widget "rather
than a property of other widgets",[^inside] and the familiar `Container` is
not a primitive at all: it is assembled from simpler widgets such as
`ConstrainedBox`, `Align`, `Padding`, `DecoratedBox` and `Transform`, adding
only the ones its arguments need.[^arch] Every widget implements a `build`
method that returns other widgets, and `build` is meant to be fast and free of
side effects, because the framework calls it often.[^arch]

### Widgets, elements and render objects

If widgets are immutable and rebuilt constantly, something else must hold on
to what is actually on screen. Flutter keeps **three trees**:[^arch][^inside]

- The **widget tree** is the configuration: cheap, immutable objects, thrown
  away and recreated on each rebuild.
- The **element tree** has one element per widget and persists from frame to
  frame. An element remembers its place in the tree, holds the `State` of a
  stateful widget, and owns its render object if it has one. Elements come in
  two kinds: *component elements*, which only build other widgets, and
  *render object elements*, which take part in layout and painting.
- The **render tree** is made of `RenderObject`s, which do the real work of
  layout, painting and hit testing. It is a subset of the element tree, since
  many elements exist only to build others.

The trees are visible from a widget test. This one draws a `Container` with a
colour and padding around some text, then walks the elements beneath it and
prints each element's widget, its own type, and its render object if any:

```dart
testWidgets('three trees', (tester) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        key: const Key('root'),
        color: const Color(0xFF2196F3),
        padding: const EdgeInsets.all(8),
        child: const Text('Hi'),
      ),
    ),
  );

  void walk(Element element, int depth) {
    final render = element is RenderObjectElement
        ? element.renderObject.runtimeType.toString()
        : '-';
    print('${'  ' * depth}${element.widget.runtimeType}'
        '  [${element.runtimeType}]  render: $render');
    element.visitChildren((child) => walk(child, depth + 1));
  }

  walk(tester.element(find.byKey(const Key('root'))), 0);
});
```

```txt
Container  [StatelessElement]  render: -
  ColoredBox  [SingleChildRenderObjectElement]  render: _RenderColoredBox
    Padding  [SingleChildRenderObjectElement]  render: RenderPadding
      Text  [StatelessElement]  render: -
        RichText  [MultiChildRenderObjectElement]  render: RenderParagraph
```

{{< diagram src="three-trees.svg" caption="The same tree drawn out. Two widgets were written; their `build` methods produced three more, and only three of the five elements own a render object." >}}

The code mentioned two widgets, but there are five. `Container` built a
`ColoredBox` for its colour and a `Padding` for its padding, and `Text` built a
`RichText`. `Container` and `Text` are pure composition, with no render object
of their own; the three render objects, a coloured box, `RenderPadding` and
`RenderParagraph`, are what will actually be measured and drawn.

The split is what makes rebuilding cheap. When `build` returns a new widget
of the same type (and key) at the same place, the framework does not destroy
anything: the existing element is updated with the new configuration and
passes it on to its render object. Flutter does not diff whole trees; it
compares each element's list of children independently, in linear
time.[^inside] Elements also hold state across rebuilds, and keeping the
element "is important for performance because elements own two critical
pieces of data: the state for stateful widgets and the underlying render
objects".[^inside] A `GlobalKey` lets the framework move an element, with its
whole subtree and state, to a new place in the tree, which is how effects
such as hero transitions work.[^inside]

### Layout: constraints go down, sizes go up

Flutter's layout is a single pass over the render tree, governed by one rule,
which its documentation says every Flutter developer should learn early:

> **Constraints go down. Sizes go up. Parent sets position.**[^constraints]

A **constraint** is four numbers: a minimum and maximum width and a minimum and
maximum height. A parent passes constraints to each child; each child lays out
its own children and then picks a size within its constraints; the parent then
positions each child. A widget can choose its size only within the limits its
parent gives it, and it never decides, or even knows, its own position on the
screen.[^constraints]

This test puts a 100 by 50 `SizedBox` in a `Center` on a 400 by 300 surface,
and wraps each level in a `LayoutBuilder` that prints the constraints it
receives. The innermost child is a `SizedBox.shrink()`, which would like to be
zero by zero:

```dart
Widget probe(String label, Widget child) => LayoutBuilder(
      builder: (context, constraints) {
        print('$label gets $constraints');
        return child;
      },
    );

testWidgets('constraints go down, sizes go up', (tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 300));
  await tester.pumpWidget(
    probe('Center',
      Center(
        child: probe('SizedBox',
          SizedBox(
            key: const Key('box'),
            width: 100,
            height: 50,
            child: probe('inner', const SizedBox.shrink(key: Key('inner'))),
          ),
        ),
      ),
    ),
  );
  print('inner wanted 0x0, is ${tester.getSize(find.byKey(const Key('inner')))}');
  print('SizedBox placed at ${tester.getRect(find.byKey(const Key('box')))}');
});
```

```txt
Center gets BoxConstraints(w=400.0, h=300.0)
SizedBox gets BoxConstraints(0.0<=w<=400.0, 0.0<=h<=300.0)
inner gets BoxConstraints(w=100.0, h=50.0)
inner wanted 0x0, is Size(100.0, 50.0)
SizedBox placed at Rect.fromLTRB(150.0, 125.0, 250.0, 175.0)
```

{{< diagram src="constraints.svg" caption="The layout pass for the test above. Constraints flow down, sizes flow back up, and only then does each parent position its children." >}}

The screen gives `Center` **tight** constraints: exactly 400 by 300. `Center`
**loosens** them, so its child may be anything up to that size. The `SizedBox`
asks its own child to be exactly 100 by 50, so the inner box, which wanted to
be empty, has no choice: it is 100 by 50. Sizes then travel back up, and
`Center`, knowing its own size and its child's, places the child at
(150, 125), in the middle. Many of the layout puzzles new Flutter developers
meet, such as a widget that ignores the width it was given, come from a parent
handing down tight constraints.[^constraints]

The rule is also what makes layout fast. Only constraints flow down and only
sizes flow up, so each render object is visited at most twice in a layout
pass, and a child whose layout is not dirty and whose constraints have not
changed can return immediately, which makes relayout after a small change
**sublinear** in the size of the tree.[^inside]

### Rendering a frame

A Flutter frame is produced by two threads working in sequence:[^uiperf]

{{< diagram src="frame.svg" caption="The stages of a frame. The UI thread turns widgets into a layer tree; the raster thread turns the layer tree into GPU commands." >}}

1. On the **UI thread**, which runs the app's Dart code (on Android and iOS,
   since Flutter 3.29, that is the platform's main thread[^arch]), the framework
   advances animations, rebuilds the elements marked dirty since the last
   frame, runs layout and then paint. Painting does not produce pixels: it
   records drawing commands into a tree of **layers**.
2. The layer tree is handed to the engine. On the **raster thread**, the
   engine composites the layers and renders them through the GPU, using
   Impeller (or Skia, where Skia is still used).[^uiperf][^arch]

At 60 Hz each frame has a budget of about 16 milliseconds; a frame that takes
much longer is dropped, and the user sees **jank**. Flutter's performance
overlay shows the two threads as separate graphs, so a slow `build` method
shows up on the UI graph and an expensive scene, with too many clips or
`saveLayer` calls, on the raster graph.[^uiperf] Build and layout only visit
what changed: the framework keeps a list of dirty elements and "jumps directly
to them during the *build* phase".[^inside] This is the same shape of
pipeline a web browser runs for HTML and CSS (see
[How Does a Web Browser Work?]({{< ref "fundamentals/how-browsers-work" >}})), except that
Flutter's framework, not the platform, owns every stage up to the layer tree.

### Impeller

Impeller exists to make that pipeline predictable. It compiles all its shaders
and reflection data offline, when the engine is built, and builds all its GPU
pipeline state up front, so no frame has to wait for a shader compiler. It
targets modern graphics APIs, Metal on Apple platforms and Vulkan on Android,
with OpenGL as a fallback.[^impeller][^impreadme]

| Platform | Renderer (Flutter 3.47) |
|---|---|
| iOS | Impeller only; Skia removed |
| Android | Impeller on API 29+ with Vulkan; older or non-Vulkan devices fall back to the legacy OpenGL renderer |
| macOS, Windows, Linux | Impeller by default, with a temporary opt-out |
| Web | Skia, compiled to WebAssembly |

The table summarises the Impeller documentation as of Flutter 3.47.[^impeller]

### Dart: JIT in development, AOT in production

Flutter compiles the same Dart source in very different ways depending on the
build:

{{< diagram src="compilation.svg" caption="One Dart code base, four ways of running it. Debug builds favour fast edits; release builds favour fast start-up and execution." >}}

- In **debug** builds on mobile and desktop, code runs in the Dart virtual
  machine with a **just-in-time** (JIT) compiler that supports incremental
  recompilation.[^dartoverview][^arch]
- In **profile** and **release** builds, Dart is compiled **ahead of time**
  (AOT) to ARM or x64 machine code, with no interpreter or JIT at
  run time.[^arch][^dartoverview] Release builds disable assertions and
  debugging and are optimised "for fast startup, fast execution, and small
  package sizes".[^buildmodes]
- On the **web**, where there is no Dart VM, debug builds use the incremental
  `dartdevc` compiler, and release builds use `dart2js` to produce JavaScript
  or `dart2wasm` to produce WebAssembly.[^arch]

The difference between the two kinds of compiler is covered in
[What Is a Compiler?]({{< ref "fundamentals/compilers" >}}); Flutter uses both, for
different stages of an app's life.

The JIT is what makes **hot reload** possible, the feature most Flutter
developers name first. When you save a change, the tools recompile only the
changed libraries into kernel files and send them to the running Dart VM,
which reloads them; Flutter then rebuilds, lays out and repaints the existing
widget tree. The app's state survives: you can change a screen several
levels deep in navigation without logging in again.[^hotreload] Because state is
kept, code that only runs at start-up, such as `main()`, `initState()` and the
initialisers of global variables, is not run again, and some changes, such as
turning an `enum` into a class or editing native Kotlin or Swift code, need a
**hot restart** (which resets the state) or a full rebuild instead.[^hotreload]
Hot reload works only in debug mode, and it now works on the web as
well.[^hotreload]

Dart 3's sound null safety and pattern matching show up throughout Flutter
code. The analyser rejects assigning `null` to a non-nullable variable before
the program ever runs:

```dart
void main() {
  String name = 'Ada';
  name = null;
}
```

```txt
  error - bad.dart:3:10 - A value of type 'Null' can't be assigned to a variable of type 'String'. Try changing the type of the variable, or casting the right-hand type to 'String'. - invalid_assignment
```

And a `sealed` class lets a `switch` expression prove it has handled every
case, while a **record** returns two values at once:

```dart
sealed class Shape {}

class Circle extends Shape {
  Circle(this.radius);
  final double radius;
}

class Rect extends Shape {
  Rect(this.width, this.height);
  final double width, height;
}

double area(Shape shape) => switch (shape) {
      Circle(:final radius) => 3.14159 * radius * radius,
      Rect(:final width, :final height) => width * height,
    };

(double, int) stats(List<Shape> shapes) =>
    (shapes.map(area).reduce((a, b) => a + b), shapes.length);

void main() {
  String? name; // nullable: may hold null
  print(name?.length ?? 'no name yet');

  final (total, count) = stats([Circle(1), Rect(2, 3)]);
  print('$count shapes, total area ${total.toStringAsFixed(2)}');
}
```

```txt
no name yet
2 shapes, total area 9.14
```

If a third subclass of `Shape` were added, `area` would stop compiling until
the `switch` handled it.[^dart3]

### The event loop and isolates

Dart code runs in **isolates**. Each isolate has its own memory and a single
thread running an **event loop**, which takes events such as taps, I/O
completions and timers from a queue and handles them one at a time. Isolates
share no mutable state: each has its own copy of every global variable, and
they communicate only by passing messages.[^dartconc] It is the same model of
run-to-completion tasks as a browser's main thread, including a separate
queue of **microtasks** that runs before the next event:

```dart
import 'dart:async';

void main() {
  print('main start');
  Timer.run(() => print('timer (event queue)'));
  Future(() => print('future (event queue)'));
  scheduleMicrotask(() => print('microtask'));
  Future.value(42).then((v) => print('then: $v (microtask)'));
  print('main end');
}
```

```txt
main start
main end
microtask
then: 42 (microtask)
timer (event queue)
future (event queue)
```

A Flutter app's UI runs in the **main isolate**, which also produces frames.
A long computation there, such as decoding a large JSON file, blocks the next
frame, and "there is only one hard rule for when you should use isolates, and
that's when large computations are causing your Flutter application to
experience UI jank".[^isolates] `Isolate.run` runs a function in a new isolate
and returns its result:

```dart
import 'dart:isolate';

int counter = 0; // every isolate has its own copy of this global

int fib(int n) => n < 2 ? n : fib(n - 1) + fib(n - 2);

Future<void> main() async {
  final result = await Isolate.run(() {
    counter++; // changes the worker isolate's copy only
    return (fib(30), counter);
  });
  print('worker returned $result');
  print('main isolate still has counter = $counter');
}
```

```txt
worker returned (832040, 1)
main isolate still has counter = 0
```

The worker incremented its own `counter`; the main isolate's copy was never
touched. That isolation removes data races between threads (for the general
problem, see [Processes and Threads]({{< ref "fundamentals/processes-and-threads" >}})), at
the cost of copying messages. Background isolates cannot use `dart:ui` or
build widgets, and the web does not support isolates at all; Flutter's
`compute` function runs its work on the main thread there.[^isolates][^dartconc]

### Talking to the platform

Drawing its own interface does not cut Flutter off from the platform beneath.
There are three ways to reach native code:[^arch][^channels]

{{< diagram src="channels.svg" caption="Platform channels pass encoded messages between Dart and the host; `dart:ffi` calls C directly." >}}

- **Platform channels** send asynchronous messages between Dart and the host.
  A `MethodChannel` call is encoded by the `StandardMessageCodec`, which
  handles JSON-like values such as numbers, strings, lists and maps, carried
  across by the engine, and handled by Kotlin, Java, Swift or Objective-C code
  on the platform's main thread; the reply completes a Dart `Future`. Channels
  are not type-safe by themselves, so the documentation also recommends
  **Pigeon**, a code generator that produces both ends of a channel from one
  Dart interface.[^channels][^pigeon]
- **`dart:ffi`** binds directly to C functions. It "can be considerably faster
  than platform channels, because no serialization is required", and works on
  every platform except the web.[^arch]
- **Platform views** embed a real native control, such as a map or a web view,
  inside the Flutter interface. They have a cost and suit complex controls
  that would be impractical to reimplement.[^arch]

Most apps use these indirectly, through **plugins**: packages that bundle a
Dart API with the native code for each platform, such as access to the camera
or to the device's preferences.[^packages]

### Flutter on the web

The web is the platform where Flutter's approach differs most from its
neighbours. Flutter does not translate widgets into HTML elements; the engine's
drawing layer was reimplemented for the browser, and the page is drawn by Skia
compiled to WebAssembly.[^arch][^webhome] There are two renderers, both built
from Skia. A default build compiles Dart to JavaScript and draws with
**CanvasKit**, which it downloads as `canvaskit.wasm`; a build with `--wasm`
compiles Dart itself to WebAssembly with `dart2wasm` and draws with **skwasm**,
which can move rasterisation to a separate Web Worker thread when the server
sends the cross-origin isolation headers the browser requires.[^webinit][^wasm][^wasmweek]
Google's own measurements in 2026 showed the WebAssembly build up to about
twice as fast in frame time on a demanding test.[^wasmweek] The WebAssembly build needs browser support for
**WasmGC**, available in Chromium-based browsers since version 119, and falls
back to the JavaScript build where it is missing. As of Flutter 3.47 the
documentation notes bugs blocking the WebAssembly renderer in Firefox and
Safari, and every browser on iOS has to use WebKit.[^wasm]

Two consequences follow from drawing into a canvas. **Accessibility** works
through a parallel tree of DOM elements that mirrors what is painted, so screen
readers have something to read; for performance reasons it is off until a
screen reader user activates a hidden "Enable accessibility" button, or the app
turns it on itself.[^a11yweb] And **search engines** see little: the
documentation says Flutter "is not suitable for static websites with
text-rich flow-based content" such as blog articles, and that its output
"doesn't align with what search engines need to properly index".[^webfaq] It
suggests keeping landing and help pages in ordinary HTML and using Flutter for
the application itself. The Flutter team followed that advice for its own
sites, rebuilding dart.dev, flutter.dev and docs.flutter.dev in 2026 with Jaspr,
a DOM-based Dart framework that prerenders pages as static HTML.[^jaspr]

## Working with Flutter

### Creating a project

The Flutter SDK includes the full Dart SDK and the `flutter` command, which
creates, runs, tests and builds apps.[^install][^getdart][^cli] A new project
starts with one command:

```sh
flutter create my_app
cd my_app
flutter run
```

The generated project looks like this. There is one host folder for each
platform enabled in the SDK's configuration; the machine used here had iOS and
macOS turned off.

```txt
my_app/
  lib/main.dart          the app's Dart code starts here
  test/widget_test.dart  a sample widget test
  pubspec.yaml           name, version, dependencies and assets
  analysis_options.yaml  lint rules for the analyser
  android/  linux/  web/  windows/   one host project per platform
```

Each platform folder is an ordinary native project, an Android Gradle project
or a Windows CMake project for example, that hosts the Flutter engine; it is
edited only to change native settings or add native code. The `pubspec.yaml`
declares dependencies, and `flutter pub add` adds one from
**pub.dev**, Dart's package repository. Dependencies are normally written as
caret ranges, `^4.0.0` meaning anything from 4.0.0 up to but not including
5.0.0, and the exact versions resolved are recorded in `pubspec.lock`.[^packages]

### Stateless and stateful widgets

An app is a tree of widgets, and most of the widgets you write are one of two
kinds:[^arch]

- A **`StatelessWidget`** has no mutable state. Its `build` method depends
  only on its constructor arguments and on data it looks up from its
  ancestors, such as the current theme.
- A **`StatefulWidget`** is itself immutable too, but it creates a separate
  **`State`** object that the element keeps alive across rebuilds. Calling
  `setState` changes that state and marks the element dirty, so its `build`
  method runs again in the next frame.

Here is a small counter, with a `debugPrint` in `build` to show when it runs:

```dart
class Counter extends StatefulWidget {
  const Counter({super.key, required this.label});

  final String label;

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    debugPrint('build ${widget.label}: $_count');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${widget.label}: $_count'),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => setState(() => _count++),
        ),
      ],
    );
  }
}
```

And a widget test that taps the button, then replaces the whole app with a new
`Counter` that has a different label:

```dart
testWidgets('tapping + increments the count', (tester) async {
  Widget app(String label) =>
      MaterialApp(home: Scaffold(body: Counter(label: label)));

  await tester.pumpWidget(app('Taps'));
  expect(find.text('Taps: 0'), findsOneWidget);

  await tester.tap(find.byIcon(Icons.add));
  await tester.pump(); // build the next frame

  expect(find.text('Taps: 1'), findsOneWidget);

  // A new Counter widget with a new label, at the same place in the tree:
  await tester.pumpWidget(app('Clicks'));
  expect(find.text('Clicks: 1'), findsOneWidget); // the State survived
});
```

```txt
build Taps: 0
build Taps: 1
build Clicks: 1
All tests passed!
```

The three lines show the model at work. `setState` caused one rebuild. Then a
brand-new `Counter` widget arrived, but because it had the same type at the same
position, the framework kept the existing element and its `State`: the count
is still 1 under the new label. That is the element tree from earlier, seen
from an app developer's side. Had the new widget been given a different `Key`,
the framework would have created a fresh element and the count would have
started again at zero.[^inside]

### Layout widgets

Flutter has no separate layout language: layout is done with widgets. The
documentation's most common ones are:[^layout]

| Widget | What it does |
|---|---|
| `Container` | Adds padding, margins, borders, a background colour or decoration |
| `Row`, `Column` | Lay children out horizontally or vertically |
| `Expanded` | Makes a child of a `Row` or `Column` fill the remaining space |
| `Stack` | Overlaps children on top of each other |
| `Center`, `SizedBox` | Centre a child; give a child a fixed size |
| `ListView`, `GridView` | Scrollable lists and grids, built lazily |
| `Card`, `ListTile` | Material building blocks for grouped content and list rows |

To adapt to the space available, `LayoutBuilder` hands a widget the
constraints from its parent, so it can, for instance, show one column below
600 pixels of width and two above it.[^arch]

### Navigation

Flutter's `Navigator` keeps a stack of **routes**, one per screen: `push` adds
a screen with the platform's transition animation and `pop` removes it. For
apps that need deep links, web URLs and a working browser Back and Forward,
the lower-level `Router` API keeps the app's screens in step with the
address, and the documentation recommends a routing package such as
**go_router** over the older named routes, which cannot customise deep-link
handling and do not support the browser's forward button.[^nav][^gorouter] The
app architecture recommendations call go_router "the preferred way to write
90% of Flutter applications".[^archrec]

### State and architecture

For state that belongs to one widget, `setState` is enough. To share state
down the tree, Flutter has `InheritedWidget`, which is how `Theme.of(context)`
finds the current theme.[^arch] Higher-level approaches are built on these
primitives: the **provider** package, "a wrapper around InheritedWidget", and
many community packages such as **Riverpod** and **flutter_bloc**.[^statemgmt][^provider][^riverpod][^bloc]
The documentation does not crown one; the choice "often depends on the app's
complexity, your team's preferences, and the specific problems you need to
solve".[^statemgmt]

What it does recommend is a structure. Flutter's architecture guide uses
**MVVM**: a **view** (widgets with no business logic) and a **view model**
per feature form the UI layer, and **repositories**, the source of truth for
data, and **services**, thin wrappers around APIs and platform features, form
the data layer.[^archguide] Its recommendations strongly favour one-way data
flow from the data layer to the UI, immutable data models, and dependency
injection with `provider`, and suggest `ChangeNotifier` for letting views
observe view models:[^archrec]

```dart
class CounterViewModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners(); // every listening widget rebuilds
  }
}

// In a view:
ListenableBuilder(
  listenable: viewModel,
  builder: (context, _) => Text('${viewModel.count}'),
);
```

### Asynchronous code

Most work an app waits for, network calls, file reads, platform channels,
returns a **`Future`**, a value that will be available later, or a
**`Stream`**, a sequence of values over time. `async` and `await` handle
futures, and `async*` with `yield` produces a stream:[^dartconc]

```dart
Future<String> fetchGreeting() async {
  await Future.delayed(const Duration(milliseconds: 100)); // pretend I/O
  return 'Hello from the future';
}

Stream<int> countdown(int from) async* {
  for (var i = from; i > 0; i--) {
    await Future.delayed(const Duration(milliseconds: 50));
    yield i;
  }
}

Future<void> main() async {
  print(await fetchGreeting());
  await for (final n in countdown(3)) {
    print('tick $n');
  }
  print('lift-off');
}
```

```txt
Hello from the future
tick 3
tick 2
tick 1
lift-off
```

In a widget tree, `FutureBuilder` and `StreamBuilder` rebuild themselves as
each new result or value arrives. A common mistake is to create the future
inside `build`, which starts the work again on every rebuild; the
documentation warns that it must not be created during the `build` call, and
should be obtained earlier, for example in `initState`.[^futurebuilder][^streambuilder]

### Testing

Flutter has three kinds of automated test, with a familiar trade-off:[^testing]

| | Unit | Widget | Integration |
|---|---|---|---|
| **Tests** | One function, method or class | One widget, in a simulated environment | A whole app on a device or emulator |
| **Confidence** | Low | Higher | Highest |
| **Maintenance cost** | Low | Higher | Highest |
| **Execution speed** | Quick | Quick | Slow |

Widget tests, like the ones above, are Flutter's distinctive tool: they run
the real framework, layout and gestures included, without a device, fast
enough to run on every change. The documentation's advice is many unit and
widget tests plus "enough integration tests to cover all the important use
cases".[^testing]

### Tooling and build modes

**DevTools** is the suite of debugging and performance tools for Dart and
Flutter: a widget inspector, a performance view for finding janky frames, CPU
and memory profilers, a network view, a debugger, logging and an app size
analyser.[^devtools] Performance should be measured in **profile** mode on a
real device, never in debug mode, which runs extra checks and is "not
indicative of release performance".[^uiperf][^renderperf] Release builds can be
inspected with `flutter build apk --analyze-size` (or `appbundle`, `ios`,
`macos`, `windows`, `linux`), which breaks the binary down by package and
category.[^appsize]

## Strengths

- **One code base, one rendering.** The same Dart code and the same pixels on
  six platforms, without a bridge to the platform's widgets on every
  frame.[^faq][^arch]
- **Fast iteration.** Stateful hot reload shortens the edit-and-look cycle
  dramatically; at 1.0 Google reported developer surveys crediting it with a
  threefold productivity gain.[^flutter1][^hotreload]
- **Performance and predictability.** Release code is compiled ahead of time
  to machine code, layout is a single sublinear pass, and Impeller removes
  runtime shader compilation.[^arch][^inside][^impeller]
- **Control over the interface.** Because Flutter draws everything, custom,
  heavily branded designs and animations are first-class; the FAQ calls apps
  needing custom designs "well suited for Flutter".[^faq] Every framework
  widget is Dart code that can be read, copied and changed.
- **A solid language.** Dart's sound null safety, pattern matching and
  isolates prevent whole classes of bugs.[^dart3][^dartconc]
- **Testing built in.** Widget tests run the real framework without a device.[^testing]
- **Wide adoption.** Over 500,000 apps had been built by 2022,[^flutter3] and in
  the 2024 Stack Overflow Developer Survey 9.4% of respondents had done
  extensive work in Flutter in the past year, slightly more than React
  Native's 8.4%.[^so2024]

## Weaknesses

- **Size.** Every app carries the engine and framework, which add "a few
  megabytes compressed" to the download before any of the app's own code,
  assets or packages.[^faq] The documentation's own example, the default demo
  app from Flutter 1.17, was about 5.4 MB to download on an iPhone.[^appsize]
- **Not the platform's own widgets.** Material and Cupertino are
  reimplementations. When a platform's design changes, a Flutter app does not
  pick up the change automatically: Apple introduced its Liquid Glass design
  across its operating systems in June 2025,[^apple] and in September 2026
  Flutter's official Liquid Glass implementation was still "underway", one of
  the reasons given for releasing the design libraries
  separately.[^decouple]
- **A weaker fit for the web.** The canvas-based output is a poor match for
  search engines and text-heavy pages, accessibility on the web is opt-in, and
  the WebAssembly build depends on browser support that is still
  incomplete.[^webfaq][^a11yweb][^wasm]
- **Native features through a layer.** Anything the framework does not cover
  needs a plugin, a platform channel, FFI or a platform view, each with its own
  cost; hot reload does not reload native code.[^arch][^channels][^hotreload]
- **Platform restrictions.** There is no runtime reflection (`dart:mirrors` is
  disabled), so serialisation and similar tasks rely on code generation, and
  there is no built-in way to update an app's code without a store release,
  although third-party services fill that gap.[^faq]
- **A smaller talent pool.** In the 2025 Stack Overflow survey 5.9% of
  respondents used Dart, against 66% for JavaScript.[^so2025]
- **Dependence on Google.** Flutter is managed by Google, and its pace depends
  on Google's priorities; the 2024 layoffs and the Flock fork show that the
  community has worried about exactly that.[^faq][^techcrunch][^flock]

## When to choose Flutter

Flutter fits best when one team must ship the same app to several platforms,
especially iOS and Android, when the design is custom rather than strictly
native, and when smooth animation matters. It is a reasonable choice for
desktop applications and for embedded screens with a custom embedder. It is a
poor choice for content websites that need to be indexed, for apps whose value
is in looking exactly like the latest version of each platform, and for teams
whose product is mostly a thin layer over platform features that would all
need native code anyway. For an existing native app, Flutter can also be
added screen by screen, hosted inside the native app.[^arch]

## Putting it together: tapping a button

Following one tap of the counter's **+** button shows the whole system at
work:

1. The operating system delivers a touch to the app. The **embedder** passes
   it to the engine, which hands it to the framework as a pointer event.
2. The framework **hit-tests** the render tree to find what lies under the
   finger, and the gesture system recognises a tap on the `IconButton`.[^arch]
3. The button's `onPressed` callback calls `setState`, which increments
   `_count` and marks the `Counter`'s element **dirty**, scheduling a frame.
4. At the next vsync, on the UI thread, the **build** phase visits only the
   dirty element. Its `build` returns a new `Row` with a new `Text('Taps: 1')`.
5. Each new widget has the same type as the old one at the same position, so
   the existing elements are **updated**, and the `RichText` element gives its
   `RenderParagraph` the new text, marking it as needing layout.
6. **Layout** reruns only where needed, **paint** records the new text into
   the layer tree, and the layer tree goes to the **raster thread**.
7. **Impeller** turns the layers into GPU commands with shaders compiled long
   before, and the new frame reaches the screen within its frame budget.

## Why it matters

Flutter is a bet that an app is better served by owning its whole rendering
stack than by borrowing the platform's. That bet explains almost everything
about it: why the same app looks identical on six platforms, why hot reload
and widget tests work so well, why a button can be animated in any way at all,
and also why apps carry an engine, why the web version struggles with search
engines, and why a new platform design needs reimplementing. Understanding
the three trees, the constraints rule and the frame pipeline is most of what
it takes to reason about why a Flutter app is fast or slow, and why a widget
ends up the size it does.

## References

[^releases]: Flutter. (2026). *Flutter SDK releases* [Release feed; stable 3.47.7, 8 October 2026, Dart 3.13.5]. <https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json>

[^archive]: Flutter. (n.d.). Flutter SDK archive: Release schedule. *Flutter documentation*. <https://docs.flutter.dev/install/archive>

[^arch]: Flutter. (n.d.). Flutter architectural overview. *Flutter documentation*. <https://docs.flutter.dev/resources/architectural-overview>

[^faq]: Flutter. (n.d.). FAQ. *Flutter documentation*. <https://docs.flutter.dev/resources/faq>

[^repo]: Flutter. (n.d.). *flutter/flutter* [Source code repository, created 6 March 2015; BSD 3-Clause licence]. GitHub. <https://github.com/flutter/flutter>

[^inside]: Flutter. (n.d.). Inside Flutter. *Flutter documentation*. <https://docs.flutter.dev/resources/inside-flutter>

[^constraints]: Flutter. (n.d.). Understanding constraints. *Flutter documentation*. <https://docs.flutter.dev/ui/layout/constraints>

[^layout]: Flutter. (n.d.). Layouts in Flutter. *Flutter documentation*. <https://docs.flutter.dev/ui/layout>

[^sed]: Software Engineering Daily. (2018, October 8). An overview of Flutter. <https://softwareengineeringdaily.com/2018/10/08/an-overview-of-flutter>

[^shorebird]: Seidel, E. (2025, August 27). Expanding the Shorebird team. *Shorebird Blog*. <https://shorebird.dev/blog/shorebird-is-growing>

[^dartsummit]: Dart Team. (2015, May 11). Dart Developer Summit videos now available. *Dart News & Updates*. <https://news.dartlang.org/2015/05/dart-developer-summit-videos-now.html>

[^skyvideo]: Google for Developers. (2015). *Sky: An experiment writing Dart for mobile (Dart Developer Summit 2015)* [Video]. YouTube. <https://www.youtube.com/watch?v=PnIWl33YMwA>

[^9to5]: Beasley, M. (2015, May 4). Google launches experimental project to build Android apps with Dart web language. *9to5Google*. <https://9to5google.com/2015/05/04/dart-android-sky/>

[^infoq]: Schuster, W. (2011, October 10). Google's Dart language: Optional typing, isolates, no shared state threads. *InfoQ*. <https://www.infoq.com/news/2011/10/google-dart-language/>

[^dart1]: Bak, L. (2013, November 14). Dart 1.0: A stable SDK for structured web apps. *Dart News & Updates*. <https://news.dartlang.org/2013/11/dart-10-stable-sdk-for-structured-web.html>

[^dart2]: Sandholm, A. T. (2018, February 22). Announcing Dart 2: Optimized for client-side development. *Dart Blog*. <https://dart.dev/blog/announcing-dart-2-optimized-for-client-side-development>

[^typesys]: Dart. (n.d.). The Dart type system. *Dart documentation*. <https://dart.dev/language/type-system>

[^beta1]: Ladd, S. (2018, February 27). Announcing Flutter beta 1: Build beautiful native apps. *Google Developers Blog*. <https://developers.googleblog.com/2018/02/announcing-flutter-beta-1.html>

[^flutter1]: Sneath, T. (2018, December 4). Flutter 1.0: Google's portable UI toolkit. *Google Developers Blog*. <https://developers.googleblog.com/en/flutter-10-googles-portable-ui-toolkit/>

[^hummingbird]: Jbanov, Y. (2018, December 4). Hummingbird: Building Flutter for the web. *Flutter Blog*. <https://flutter.dev/blog/hummingbird-building-flutter-for-the-web>

[^webbeta]: Hasnany, M. (2019, December 11). Web support for Flutter goes beta. *Flutter Blog*. <https://flutter.dev/blog/web-support-for-flutter-goes-beta>

[^linux]: Sells, C., & VanDine, K. (2020, July 8). Announcing Flutter Linux alpha with Canonical. *Flutter Blog*. <https://flutter.dev/blog/announcing-flutter-linux-alpha-with-canonical>

[^flutter2]: Sells, C. (2021, March 3). What's new in Flutter 2. *Flutter Blog*. <https://flutter.dev/blog/whats-new-in-flutter-2-0>

[^dart212]: Thomsen, M. (2021, March 3). Announcing Dart 2.12. *Dart Blog*. <https://dart.dev/blog/announcing-dart-2-12>

[^windows]: Sneath, T. (2022, February 3). Announcing Flutter for Windows. *Flutter Blog*. <https://flutter.dev/blog/announcing-flutter-for-windows>

[^flutter3]: Sneath, T. (2022, May 11). Introducing Flutter 3. *Flutter Blog*. <https://flutter.dev/blog/introducing-flutter-3>

[^shaderwarm]: Li, Y. (2019, May 6). *Automatic/scalable shader warm-up* (Issue #32170). flutter/flutter, GitHub. <https://github.com/flutter/flutter/issues/32170>

[^hixie]: Hickson, I. (2022, January 19). Comment on *Automatic/scalable shader warm-up* (Issue #32170). flutter/flutter, GitHub. <https://github.com/flutter/flutter/issues/32170#issuecomment-1016927129>

[^impeller]: Flutter. (n.d.). Impeller rendering engine. *Flutter documentation*. <https://docs.flutter.dev/perf/impeller>

[^impreadme]: Flutter. (n.d.). *Impeller* [README]. flutter/flutter, GitHub. <https://github.com/flutter/flutter/blob/main/engine/src/flutter/impeller/README.md>

[^f37]: Chisholm, K. (2023, January 24). What's new in Flutter 3.7. *Flutter Blog*. <https://flutter.dev/blog/whats-new-in-flutter-3-7>

[^f310]: Chisholm, K. (2023, May 10). What's new in Flutter 3.10. *Flutter Blog*. <https://flutter.dev/blog/whats-new-in-flutter-3-10>

[^dart3]: Thomsen, M. (2023, May 10). Announcing Dart 3. *Dart Blog*. <https://dart.dev/blog/announcing-dart-3>

[^f316]: Chisholm, K. (2023, November 15). What's new in Flutter 3.16. *Flutter Blog*. <https://flutter.dev/blog/whats-new-in-flutter-3-16>

[^f322]: Chisholm, K. (2024, May 14). What's new in Flutter 3.22. *Flutter Blog*. <https://flutter.dev/blog/whats-new-in-flutter-3-22>

[^f327]: Chisholm, K. (2024, December 11). What's new in Flutter 3.27. *Flutter Blog*. <https://flutter.dev/blog/whats-new-in-flutter-3-27>

[^f329]: Chisholm, K. (2025, February 12). What's new in Flutter 3.29. *Flutter Blog*. <https://flutter.dev/blog/whats-new-in-flutter-3-29>

[^f347]: Twersky, E. (2026, August 12). What's new in Flutter 3.47. *Flutter Blog*. <https://flutter.dev/blog/whats-new-in-flutter-3-47>

[^techcrunch]: Perez, S. (2024, April 29; updated May 1). Google lays off staff from Flutter, Dart and Python weeks before its developer conference. *TechCrunch*. <https://techcrunch.com/2024/04/29/google-lays-off-staff-from-flutter-dart-python-weeks-before-its-developer-conference>

[^flock]: Anderson, T. (2024, October 30). Flutter forked as Flock, developer cites "company-wide issues at Google". *DevClass*. <https://devclass.com/2024/10/30/flutter-forked-as-flock-developer-cites-company-wide-issues-at-google>

[^roadmap2026]: Twersky, E. (2026, February 24). Flutter & Dart's 2026 roadmap. *Flutter Blog*. <https://flutter.dev/blog/flutter-darts-2026-roadmap>

[^decouple]: Labenz, C. (2026, September 9). Decoupling Material and Cupertino. *Flutter Blog*. <https://flutter.dev/blog/decoupling-material-cupertino>

[^whatsnewdocs]: Flutter. (n.d.). What's new in the docs. *Flutter documentation*. <https://docs.flutter.dev/release/whats-new>

[^uiperf]: Flutter. (n.d.). Flutter performance profiling. *Flutter documentation*. <https://docs.flutter.dev/perf/ui-performance>

[^renderperf]: Flutter. (n.d.). Improving rendering performance. *Flutter documentation*. <https://docs.flutter.dev/perf/rendering-performance>

[^dartoverview]: Dart. (n.d.). Dart overview. *Dart documentation*. <https://dart.dev/overview>

[^buildmodes]: Flutter. (n.d.). Flutter's build modes. *Flutter documentation*. <https://docs.flutter.dev/testing/build-modes>

[^hotreload]: Flutter. (n.d.). Hot reload. *Flutter documentation*. <https://docs.flutter.dev/tools/hot-reload>

[^dartconc]: Dart. (n.d.). Concurrency in Dart. *Dart documentation*. <https://dart.dev/language/concurrency>

[^isolates]: Flutter. (n.d.). Isolates. *Flutter documentation*. <https://docs.flutter.dev/perf/isolates>

[^channels]: Flutter. (n.d.). Writing custom platform-specific code. *Flutter documentation*. <https://docs.flutter.dev/platform-integration/platform-channels>

[^pigeon]: Flutter. (n.d.). *pigeon* [Dart package]. pub.dev. <https://pub.dev/packages/pigeon>

[^packages]: Flutter. (n.d.). Using packages. *Flutter documentation*. <https://docs.flutter.dev/packages-and-plugins/using-packages>

[^webhome]: Flutter. (n.d.). Web support for Flutter. *Flutter documentation*. <https://docs.flutter.dev/platform-integration/web>

[^webinit]: Flutter. (n.d.). Flutter web app initialization. *Flutter documentation*. <https://docs.flutter.dev/platform-integration/web/initialization>

[^wasm]: Flutter. (n.d.). Support for WebAssembly (Wasm). *Flutter documentation*. <https://docs.flutter.dev/platform-integration/web/wasm>

[^wasmweek]: Moore, K. (2026, August 17). Try Flutter web with WebAssembly week. *Flutter Blog*. <https://flutter.dev/blog/try-flutter-web-with-webassembly-week>

[^a11yweb]: Steiner, T. (2024, April 16). Accessibility in Flutter on the web. *Flutter Blog*. <https://flutter.dev/blog/accessibility-in-flutter-on-the-web>

[^webfaq]: Flutter. (n.d.). Web FAQ. *Flutter documentation*. <https://docs.flutter.dev/platform-integration/web/faq>

[^jaspr]: Lougheed, P. (2026, April 15). We rebuilt Flutter's websites with Dart and Jaspr. *Flutter Blog*. <https://flutter.dev/blog/we-rebuilt-flutters-websites-with-dart-and-jaspr>

[^install]: Flutter. (n.d.). Install Flutter. *Flutter documentation*. <https://docs.flutter.dev/get-started/install>

[^getdart]: Dart. (n.d.). Get the Dart SDK. *Dart documentation*. <https://dart.dev/get-dart>

[^cli]: Flutter. (n.d.). The Flutter command-line tool. *Flutter documentation*. <https://docs.flutter.dev/reference/flutter-cli>

[^nav]: Flutter. (n.d.). Navigation and routing. *Flutter documentation*. <https://docs.flutter.dev/ui/navigation>

[^gorouter]: Flutter. (n.d.). *go_router* [Dart package]. pub.dev. <https://pub.dev/packages/go_router>

[^archguide]: Flutter. (n.d.). Guide to app architecture. *Flutter documentation*. <https://docs.flutter.dev/app-architecture/guide>

[^archrec]: Flutter. (n.d.). Architecture recommendations and resources. *Flutter documentation*. <https://docs.flutter.dev/app-architecture/recommendations>

[^statemgmt]: Flutter. (n.d.). List of state management approaches. *Flutter documentation*. <https://docs.flutter.dev/data-and-backend/state-mgmt/options>

[^provider]: dash-overflow.net. (n.d.). *provider* [Dart package]. pub.dev. <https://pub.dev/packages/provider>

[^riverpod]: dash-overflow.net. (n.d.). *riverpod* [Dart package]. pub.dev. <https://pub.dev/packages/riverpod>

[^bloc]: bloclibrary.dev. (n.d.). *flutter_bloc* [Dart package]. pub.dev. <https://pub.dev/packages/flutter_bloc>

[^futurebuilder]: Flutter. (n.d.). FutureBuilder class. *Flutter API reference*. <https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html>

[^streambuilder]: Flutter. (n.d.). StreamBuilder class. *Flutter API reference*. <https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html>

[^testing]: Flutter. (n.d.). Testing Flutter apps. *Flutter documentation*. <https://docs.flutter.dev/testing/overview>

[^devtools]: Flutter. (n.d.). Flutter and Dart DevTools. *Flutter documentation*. <https://docs.flutter.dev/tools/devtools>

[^appsize]: Flutter. (n.d.). Measuring your app's size. *Flutter documentation*. <https://docs.flutter.dev/perf/app-size>

[^so2024]: Stack Overflow. (2024). Other frameworks and libraries. In *2024 Developer Survey: Technology*. <https://survey.stackoverflow.co/2024/technology#most-popular-technologies-misc-tech>

[^so2025]: Stack Overflow. (2025). Programming, scripting, and markup languages. In *2025 Developer Survey: Technology*. <https://survey.stackoverflow.co/2025/technology#most-popular-technologies-language>

[^apple]: Apple. (2025, June 9). Apple introduces a delightful and elegant new software design [Press release]. <https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/>
