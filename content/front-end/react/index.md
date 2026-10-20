---
title: "What Is React? Components, Rendering and the Library Behind Modern Interfaces"
description: "React is the most widely used library for building user interfaces on the web. Here is the whole story: where it came from at Facebook, how JSX, elements, the Fiber reconciler, Hooks, effects and Server Components actually work, how to build and test an app with it, and what it is good and bad at."
date: 2026-10-20T18:00:00Z
categories: ["Front-end"]
tags: ["React", "JavaScript", "Web", "Front-end", "UI"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

React is a JavaScript library for building user interfaces out of
**components**: small functions that describe what a piece of the screen
should look like for a given state. You never tell React *how* to change the
page; you describe what it should be now, and React works out the smallest set
of changes that gets the screen there. The idea met a cool reception when
Facebook released React in 2013; today React is the most used library of its
kind. In Stack Overflow's 2026 Developer Survey, 42 percent of respondents said
they had used it, second among web frameworks and technologies only to
Node.js.[^so2026]

This article covers where React came from, how it works underneath, how to build
with it, and where it fits and does not. It builds on [How Does a Web Browser
Work?]({{< ref "/fundamentals/how-browsers-work" >}}), since everything React
does in a browser ends up as DOM operations, events and the event loop described
there. The examples were run with React 19.3.1, the latest release at the time
of writing,[^releases] on Node.js 24 (in the jsdom DOM implementation where a
browser is needed), and their output is shown as printed.

## What React is

React's own description of itself is **"the library for web and native user
interfaces"**.[^repo] Both words matter.

- **A library, not a framework.** React itself covers one concern: turning
  state into UI and keeping the two in sync. It does not include a router, a
  data-fetching layer, a build system or a server. When React was released,
  its authors were explicit that "React isn't an MVC framework"; it is a
  library for building composable user interfaces.[^why]
- **Web and native.** The core of React does not know about the browser. A
  separate **renderer** applies its decisions to a platform: `react-dom` to the
  DOM, React Native to iOS and Android views.[^fiberarch]

The narrow scope is deliberate, but an application needs the rest, and the
official documentation now says so plainly: "If you want to build a new app or
website with React, we recommend starting with a framework," such as Next.js or
React Router, with Expo for native apps. Using React with only a build tool such
as Vite is still supported, at the cost of making "choices on which tools to use
for routing, data fetching, and other common usage patterns."[^creating]

Three ideas run through everything else in this article:

1. **Declarative UI.** A component returns a description of the UI for the
   current data. When the data changes, React calls the component again and
   compares the new description with the old one, so "reactive updates are
   dead simple".[^why]
2. **Components as pure functions.** "React assumes that every component you
   write is a pure function": given the same inputs (props, state and
   context), it returns the same output and changes nothing outside
   itself.[^pure]
3. **One-way data flow.** Data is passed down the tree, from parent to child,
   as **props**; a child changes something above it only by calling a function
   its parent gave it.[^thinking]

## A history of React

### Origins inside Facebook

Facebook's ads organisation built its interfaces with **Bolt**, an internal
client-side MVC framework. **Jordan Walke**, a Facebook engineer, began a side
project called **FaxJS** to solve Bolt's problems in a different way, and most
of React's fundamentals were born there: props and state, re-evaluating the
whole tree and diffing the result, server-side rendering, and a basic notion of
components.[^stars]

Walke concluded that functional APIs, which discourage mutation, were a better
and more scalable way to build interfaces. In March 2012 he brought his library
into Facebook's codebase as **FBolt** ("functional Bolt"); he and Tom Occhino
later renamed it **React**.[^stars]

React's markup syntax was inspired by Facebook's PHP code. Since around 2010
Facebook had used **XHP**, a PHP extension that let XML-like UI fragments be
written directly in code, introduced partly to prevent cross-site scripting
holes. An XHP-like prototype for JavaScript led the team to fork
`js-xml-literal`, a project by XHP's creator Marcel Laverdet, which became
**JSX**.[^stars]

Facebook bought Instagram in 2012. Pete Hunt, on Instagram's new web team,
wanted to build the whole site in React, where Facebook had been adopting it
piece by piece. Because Instagram used none of Facebook's infrastructure, React
had to be untangled from it, which the team later called "a forcing function"
for open-sourcing it. Hunt also implemented `renderToString`, React's
server-side rendering.[^stars]

### Open source, and a cool reception

React was released as open source on **29 May 2013**, with version
0.3.0,[^versions] and presented by Facebook at JSConf US that month.[^pragmatic]
The first reaction was poor. Looking back a year later, the team wrote that
React "received mostly disapproving first-impressions" and that "JSX, in
particular, filtered out a huge chunk of potential early adopters".[^oneyear]
Putting markup inside JavaScript broke with the habit of keeping markup in
templates, separate from logic.

The team answered with arguments rather than features. The first post on the
React blog, Pete Hunt's "Why did we build React?" of 5 June 2013,[^versions]
argued that templates were a weaker version of a real programming language and
that re-rendering and diffing made data binding unnecessary.[^why] Early outside
adopters followed: Sophie Alpert, then at Khan Academy, described herself as
"the first non-FB/IG production user of React".[^roundup] A year after release
the project had nearly 7,000 GitHub stars, with production users including Khan
Academy, The New York Times and Airbnb.[^oneyear]

### React Native, and the licence controversy

At React.js Conf in January 2015 Facebook announced **React Native**, which uses
React to drive real native views rather than a web page. It was released as open
source on 26 March 2015, for iOS first.[^rn][^rnandroid] Its slogan, "learn
once, write anywhere", was a deliberate contrast with "write once, run
anywhere": each platform still gets its own app, but the same skills and model
carry over.[^rn] The Android version followed on 14 September 2015, along with
Facebook's Ads Manager, the company's first cross-platform React Native app,
which reused about 85 percent of its code between platforms.[^rnandroid]

React's version numbering then jumped from 0.14 (October 2015) to 15.0 (April
2016). The move to major version numbers, the team explained, "simply helps
indicate our commitment to stability", since many businesses, Facebook's
included, already depended on React.[^versioning][^versions]

React was originally licensed under BSD plus a **PATENTS** file with Facebook's
own patent terms. The Apache Software Foundation lists this "Facebook
BSD+Patents license" among the licences Apache projects may not depend on,
because the PATENTS file passes risk to downstream users "imbalanced in favor of
the licensor".[^asf] In 2017, after weeks of uncertainty in the community,
Facebook announced on 22 September 2017 that React, Jest, Flow and Immutable.js
would move to the **MIT licence**, admitting it had "failed to decisively
convince this community".[^relicense] React 16 shipped under MIT, as did a
15.6.2 release for those who could not upgrade straight away.[^v16]

### Fiber, Hooks and concurrency

**React 16** (26 September 2017) was "the first version of React built on top
of a new core architecture, codenamed 'Fiber'", a rewrite of the reconciler.
The release added fragments, error boundaries, portals and a rewritten server
renderer that supports streaming.[^v16] Fiber, described in detail below, was
designed to let rendering be interrupted, which React put to use in later
versions.

**Hooks** were introduced at React Conf 2018 by Sophie Alpert and Dan Abramov
and shipped in **React 16.8** on 6 February 2019.[^hooksintro][^v168] "Hooks
let you use state and other React features without writing a class."[^v168]
They answered three complaints: stateful logic was hard to reuse between
components, complex class components were hard to understand, and classes
"confuse both people and machines". They were opt-in and fully backward
compatible.[^hooksintro] Function components with Hooks have since become the
normal way to write React; the current documentation teaches them from the
first page.[^reactdev]

**React 17** (20 October 2020) had "no new features"; it made gradual upgrades
possible and stopped attaching event handlers to `document`, attaching them to
the root container instead.[^v17] A month earlier the team had introduced a new
**JSX transform** that no longer needs `React` in scope.[^jsxtransform]

**React 18** (29 March 2022) brought **concurrent rendering**: "rendering is
interruptible", so React can prepare an update in the background, pause it or
throw it away. It added automatic batching of state updates, **transitions** for
marking updates as non-urgent, Suspense on the server, and the `createRoot`
API.[^v18]

### Server Components, the compiler and a foundation

On 16 March 2023 the documentation moved to **react.dev**, teaching function
components and Hooks from the start; the old site was archived at
legacy.reactjs.org.[^reactdev] On 14 February 2025 the team deprecated
**Create React App**, its official starter since 2016, recommending frameworks
or build tools such as Vite instead.[^cra]

**React 19** (5 December 2024) added **Actions**, async functions that run in
transitions and handle pending states, errors, forms and optimistic updates;
the `use` API for reading promises and context during render; `ref` as an
ordinary prop; and native support for document metadata. It also made **React
Server Components** stable for applications, though "the underlying APIs used
to implement a React Server Components bundler or framework do not follow
semver".[^v19] React 19.2 (1 October 2025) added `<Activity>` and
`useEffectEvent`, among other things.[^v192]

**React Compiler 1.0** was released on 7 October 2025: a build-time tool that
memoises components and Hooks automatically.[^compiler1] The same day the
team announced plans for an independent foundation,[^foundationintro] and on
24 February 2026 the **React Foundation**, hosted by the Linux Foundation,
launched. React, React Native and supporting projects such as JSX are no longer
owned by Meta. The foundation is led by executive director Seth Webster, with
Amazon, Callstack, Expo, Huawei, Meta, Microsoft, Software Mansion and Vercel as
founding members, while technical direction remains with the people who
maintain React.[^foundation][^lf] The main repository now lives at
`github.com/react/react`.[^repo]

**React 19.3** (9 September 2026) made View Transitions and Fragment Refs
stable and added a `browser()` API for opting a component out of server
rendering.[^v193]

## A timeline at a glance

| Year | Milestone |
|---|---|
| 2012 | Jordan Walke's library, grown out of his FaxJS prototype, enters Facebook's codebase as FBolt in March and is renamed React; Facebook buys Instagram, whose React website forces React to stand alone |
| 2013 | Open-sourced on 29 May (v0.3.0); presented at JSConf US |
| 2015 | React Native for iOS (March) and Android (September); React 0.14 |
| 2016 | React 15; Create React App |
| 2017 | MIT licence; React 16 with the Fiber architecture |
| 2019 | React 16.8 introduces Hooks |
| 2020 | React 17; the new JSX transform; lanes in the reconciler |
| 2022 | React 18: concurrent rendering, transitions, automatic batching |
| 2023 | react.dev replaces the old documentation |
| 2024 | React 19: Actions, `use`, stable Server Components |
| 2025 | Create React App deprecated; React 19.2; React Compiler 1.0; React Foundation announced |
| 2026 | React Foundation launches under the Linux Foundation; React 19.3 |

## How React works

### The pieces

React is split into layers. JSX exists only in source code: a compiler turns
it into plain function calls before the program runs. At run time, the `react`
package provides the component model and Hooks; the **reconciler** decides what
has changed; and a **renderer** applies those changes to a particular
platform. Reconciliation and rendering are separate phases precisely so that
React DOM and React Native can share one reconciler and supply their own
renderers.[^fiberarch]

{{< diagram src="architecture.svg" caption="The layers of a React application. JSX disappears at build time; at run time one reconciler can drive several renderers." >}}

### JSX is just function calls

JSX looks like HTML inside JavaScript, but it is only syntax for calling a
function. Here is a component and what Babel 8 compiles it to, first with the
original **classic** runtime and then with the **automatic** runtime
introduced with React 17:[^jsxtransform]

```jsx
function Greeting({ name }) {
  return <h1 className="title">Hello, {name}!</h1>;
}
```

```js
// runtime: classic
function Greeting({
  name
}) {
  return /*#__PURE__*/React.createElement("h1", {
    className: "title"
  }, "Hello, ", name, "!");
}

// runtime: automatic
import { jsxs as _jsxs } from "react/jsx-runtime";
function Greeting({
  name
}) {
  return /*#__PURE__*/_jsxs("h1", {
    className: "title",
    children: ["Hello, ", name, "!"]
  });
}
```

The tag name becomes the first argument, the attributes become an object of
**props**, and the content becomes `children`. Because the result is ordinary
JavaScript, anything a language can do, from variables and conditionals to `map`
over an array, can produce UI; this was exactly the argument Pete Hunt made for
JSX over templates in 2013.[^why] The compiler is the same kind of
source-to-source translator described in [What Is a Compiler?]({{< ref
"/fundamentals/compilers" >}}). Because attributes become object keys, JSX uses
`className` rather than the reserved word `class`, named after the corresponding
DOM property, and camelCase names such as `strokeWidth` for dashed
ones.[^jsxmarkup]

### Elements are plain objects

Calling `jsx()` does not create anything on the screen. It returns a **React
element**: a small, plain object that describes what should be there.

```jsx
const element = <h1 className="title" key="greeting">Hello, world!</h1>;
console.log(element);
```

```txt
{
  '$$typeof': Symbol(react.transitional.element),
  type: 'h1',
  key: 'greeting',
  ref: null,
  props: { className: 'title', children: 'Hello, world!' }
}
```

That is the whole element: a type, a key, a ref and the props. The `$$typeof`
field holds a `Symbol`, and React refuses to process an element without a
valid one. Symbols cannot be written in JSON, so even if a buggy server returned
user-supplied JSON where text was expected, it could not be passed off as an
element and used to inject markup.[^typeof] (In development builds React also
freezes elements and their props, so code that tries to mutate them fails
early.)

A tree of these objects is what React's legacy documentation called the
**virtual DOM**: "an ideal, or 'virtual', representation of a UI … kept in
memory and synced with the 'real' DOM", a process called
**reconciliation**.[^internals] The name is loose, since React also renders to
targets that have no DOM at all, such as native views.

### Components and composition

When the `type` of an element is a function rather than a string, it is a
**component**. React calls it with the element's props and uses whatever it
returns. Components are composed by nesting, and anything nested between a
component's tags arrives as its `children` prop:

```jsx
import { renderToString } from "react-dom/server";

function Badge({ label, tone = "info" }) {
  return <span className={`badge badge-${tone}`}>{label}</span>;
}

function Card({ title, children }) {
  return (
    <section className="card">
      <h2>{title}</h2>
      {children}
      <Badge label="new" />
    </section>
  );
}

console.log(renderToString(
  <Card title="Ada Lovelace">
    <p>Wrote the first published program.</p>
  </Card>
));
```

```txt
<section class="card"><h2>Ada Lovelace</h2><p>Wrote the first published program.</p><span class="badge badge-info">new</span></section>
```

`renderToString` walked the tree, calling `Card` and then `Badge`, until only
host elements such as `section` and `span` remained, and serialised those as
HTML. This is server-side rendering in its simplest form. In the browser,
`react-dom` turns the same tree into DOM nodes instead.

### Render and commit

Every update goes through the same three steps: something **triggers** a
render, React **renders**, and React **commits**.[^rendercommit]

{{< diagram src="render-commit.svg" caption="The life of an update. Rendering only computes; nothing reaches the screen until the commit." >}}

- **Trigger.** A render happens for one of two reasons: it is the component's
  initial render, or the state of the component or one of its ancestors has
  been updated.[^rendercommit]
- **Render.** "'Rendering' is React calling your components."[^rendercommit]
  On an update, React calls the component whose state changed and, by default,
  every component nested inside it, and compares the new elements with the
  previous ones.
  This phase must be pure; React may call a component more than once, and with
  concurrent rendering it may pause a render or discard it
  altogether.[^v18][^pure]
- **Commit.** React applies the difference to the DOM. "React only changes the
  DOM nodes if there's a difference between renders."[^rendercommit] It waits
  to do so until the whole new tree has been evaluated, so the user never sees
  a half-finished update.[^v18]

After the commit the browser paints, as in any other page, and then React runs
the component's **effects** (described below).[^effects]

### Reconciliation: comparing trees

Comparing two arbitrary trees optimally takes time on the order of O(n³) in the
number of elements, far too slow for a UI. React instead uses a heuristic O(n)
algorithm based on two assumptions:[^reconciliation]

1. Two elements of different types produce different trees. If a `<div>`
   becomes a `<section>`, or `<Counter>` becomes `<p>`, React tears down the old
   subtree, state included, and builds a new one.
2. The developer can mark which children are stable across renders with a
   **`key`** prop.

When the types match, React keeps the same DOM node, or the same component
instance and its state, and updates only what changed.[^reconciliation] The
documentation puts the consequence for state in one sentence: "React preserves
a component's state for as long as it's being rendered at its position in the UI
tree."[^preserving]

Keys decide what counts as "the same position" in a list. "Keys tell React
which array item each component corresponds to, so that it can match them up
later."[^lists] Without them, or with the array index as the key, React matches
children by position. Here each row keeps a piece of state, and a new row is
inserted at the top:

```jsx
function Row({ name }) {
  const [note, setNote] = useState(`note for ${name}`); // state inside each row
  return <li>{name}: {note}</li>;
}

function List({ items, useIndex }) {
  return (
    <ul>
      {items.map((name, i) => <Row key={useIndex ? i : name} name={name} />)}
    </ul>
  );
}

// render ["Ana", "Bo"], then ["Cy", "Ana", "Bo"], once with each kind of key
```

```txt
key={index} Cy: note for Ana | Ana: note for Bo | Bo: note for Bo
key={name}  Cy: note for Cy | Ana: note for Ana | Bo: note for Bo
```

{{< diagram src="keys.svg" caption="The same insertion with index keys and with stable keys. With index keys, the state stays in the slot while the items move." >}}

With index keys, the row now showing Cy inherited Ana's state, and Ana
inherited Bo's. With the names as keys, React saw that Ana and Bo had moved and
that Cy was new. This is why the documentation warns that using the index as a
key "often leads to subtle and confusing bugs", and that a key generated during
render, such as `Math.random()`, recreates every row on every
render.[^lists] The same mechanism can be used on purpose: giving a component a
different `key` resets its state.[^preserving]

### Fiber: rendering as units of work

Before React 16, React walked the tree recursively and "calls render functions
of the whole updated tree during a single tick". Work driven by the call stack
"will keep doing work until the stack is empty", and too much work at once
makes animations drop frames.[^fiberarch] **Fiber** reimplemented the
reconciler so that rendering could be split into chunks and spread across
frames, and so that React could pause, abort or reuse work and give different
kinds of update different priorities.[^fiberarch][^v16]

A **fiber** is "a unit of work": an object for each component or element in the
tree, which can be thought of as a virtual stack frame that React keeps in
memory and processes whenever it chooses.[^fiberarch] Instead of nesting through
recursion, fibers are linked to their first **child**, their next **sibling**
and, through a **return** pointer, their parent, so React can stop after any
fiber and resume later from exactly that point.[^fiberarch]

{{< diagram src="fiber.svg" caption="A fiber tree and its two versions. The links let React stop after any fiber and pick up where it left off." >}}

Each fiber also records the component `type`, its `key`, the props it started
with (`pendingProps`) and the props it finished with (`memoizedProps`); when the
two are equal, the fiber's previous output can be reused. And there are at most
two versions of each fiber, linked by an `alternate` pointer: the **current**
fiber, which has been flushed to the screen, and the **work-in-progress** fiber
being built for the next render.[^fiberarch] Rendering works on the
work-in-progress tree, so an unfinished render never touches what the user
sees.

### Scheduling, lanes and concurrent rendering

Fiber makes rendering interruptible; the scheduler decides what to work on.
React takes a "pull" approach: rather than the application deciding when to
compute, React delays work until necessary and orders it by priority, since an
animation must finish sooner than, say, an update from a data
store.[^fiberarch]

Since 2020 those priorities have been expressed as **lanes**. Each kind of
update is assigned a bit in a 32-bit mask, which lets React track many distinct
groups of work in one integer and decide separately how urgent each group is
and which updates must be rendered together. The earlier "expiration time"
model had coupled those two questions.[^lanes]

Application code sees this through **transitions**. An update wrapped in
`startTransition` is marked as non-urgent: "A state update marked as a
Transition will be interrupted by other state updates." If the user types
while a large list is re-rendering for a transition, React handles the
keystroke first and then restarts the list.[^usetransition]

```jsx
const [isPending, startTransition] = useTransition();

function handleChange(e) {
  setText(e.target.value);              // urgent: the input must keep up
  startTransition(() => {
    setQuery(e.target.value);           // can wait, and be interrupted
  });
}
```

Concurrency is, in the React 18 announcement's words, not a feature as such
but "a new behind-the-scenes mechanism that enables React to prepare multiple
versions of your UI at the same time".[^v18]

### State, and why it is a snapshot

`useState` gives a component a piece of memory that survives between renders,
and a function to change it. Calling that function does not change the variable
in the running code; it asks React for a new render, in which the component
will read the new value. React also **batches** updates: it "waits until *all*
code in the event handlers has run before processing your state
updates".[^queueing] Since React 18 this batching applies everywhere, including
in timeouts and promises.[^v18] Two ways of adding three:

```jsx
function Counter() {
  const [count, setCount] = useState(0);
  return (
    <>
      <button id="plain" onClick={() => {
        setCount(count + 1);
        setCount(count + 1);
        setCount(count + 1);
      }}>plain</button>
      <button id="updater" onClick={() => {
        setCount(c => c + 1);
        setCount(c => c + 1);
        setCount(c => c + 1);
      }}>updater</button>
      <output>{count}</output>
    </>
  );
}
// click "plain", then "updater", counting renders
```

```txt
plain: count is 1 after 1 render(s)
updater: count is 4 after 1 render(s)
```

During the first click `count` was 0 throughout the handler, so all three
calls asked for `0 + 1`. The updater form passes each function the result of
the previous one, so the second click went from 1 to 4. Either way, three
updates cost one render.[^queueing]

### Hooks and the rules of Hooks

How does `useState` know which state belongs to which call, when it is given
nothing but an initial value? By order. "Hooks rely on a stable call order on
every render of the same component." Internally React keeps, for each
component, a list of Hook state and an index that starts at zero before each
render; every Hook call takes the next slot.[^statememory]

{{< diagram src="hooks.svg" caption="Hook state is matched to Hook calls by position, which is why Hooks may not be called conditionally." >}}

That is the reason for the **rules of Hooks**:[^rulesofhooks]

- **Only call Hooks at the top level**: not inside loops, conditions, nested
  functions or `try`/`catch` blocks, and before any early return.
- **Only call Hooks from React functions**: from components and from **custom
  Hooks**, functions whose names start with `use` and that call other Hooks.

If a condition skipped one call, every later call would read its neighbour's
slot. The `eslint-plugin-react-hooks` linter catches most
violations.[^statememory] Custom Hooks are the main tool for reuse: a function
such as `useOnlineStatus` can bundle state and effects and be called from any
component, and each call gets its own state.

### Effects

Rendering must be pure, but applications must talk to the outside world.
"Effects let you run some code after rendering so that you can synchronize your
component with some system outside of React", such as a network connection, a
browser API or a non-React widget. They "run at the end of a commit after the
screen updates". An effect can return a **cleanup** function, which React calls
before running the effect again and when the component is removed.[^effects]
The order is visible in a small example:

```jsx
function Clock({ room }) {
  log.push(`render ${room}`);
  useLayoutEffect(() => { log.push(`layout effect ${room}`); });
  useEffect(() => {
    log.push(`connect to ${room}`);
    return () => log.push(`disconnect from ${room}`);
  }, [room]);
  return <p>{room}</p>;
}
// render room="general", then room="random", then unmount
```

```txt
render general
layout effect general
connect to general
--- room changes
render random
layout effect random
disconnect from general
connect to random
--- unmount
disconnect from random
```

The array `[room]` lists the effect's **dependencies**: the effect re-runs only
when one of them changes, and the old connection is cleaned up first.
`useLayoutEffect` "fires before the browser repaints the screen", for cases
such as measuring a tooltip before positioning it; because it delays painting,
the documentation advises preferring `useEffect`.[^layouteffect]

In development, **Strict Mode** checks that effects are written correctly by
mounting every component, unmounting it and mounting it again:[^effects]

```jsx
function ChatRoom() {
  useEffect(() => {
    console.log("connect");
    return () => console.log("disconnect");
  }, []);
  return <p>chat</p>;
}
// rendered inside <StrictMode>
```

```txt
connect
disconnect
connect
```

An effect without the right cleanup would show up here as two open
connections. In production the effect runs once.[^effects]

Effects are also easy to overuse. The documentation calls them
"an escape hatch from the React paradigm": "If there is no external system
involved … you shouldn't need an Effect." Data that can be computed from props
or state should be computed during render, and work caused by a user action
belongs in the event handler.[^noeffect]

### Events

JSX event props such as `onClick` look like inline HTML handlers, but React does
not attach a listener to each element. Since React 17 it listens at the **root
container** the app is mounted in and dispatches events to the right components
itself, an instance of the event delegation described in [How Does a Web Browser
Work?]({{< ref "/fundamentals/how-browsers-work" >}}).[^v17] Handlers receive a
**React event object**, sometimes called a *synthetic event*, which "conforms to
the same standard as the underlying DOM events, but fixes some browser
inconsistencies"; the browser's own event is available as
`nativeEvent`.[^events]

```jsx
function App() {
  return (
    <div onClick={() => console.log("div onClick (bubbling)")}>
      <button onClick={(e) => {
        console.log("button onClick");
        console.log("  React event type:", e.type, "| currentTarget:", e.currentTarget.tagName);
        console.log("  native listener is on:",
          e.nativeEvent.currentTarget === container ? "the root container" : e.nativeEvent.currentTarget);
      }}>Go</button>
    </div>
  );
}
```

```txt
button onClick
  React event type: click | currentTarget: BUTTON
  native listener is on: the root container
div onClick (bubbling)
```

From the component's point of view the event came from the button and bubbled
to the `div`, as it would in the DOM. Underneath, the browser delivered it to a
listener React had registered on the root container, and React replayed the
bubbling through its own tree.

### Server Components

Everything so far runs wherever React runs. **React Server Components** add a
second kind of component that runs only ahead of time: "a new type of Component
that renders ahead of time, before bundling, in an environment separate from
your client app or SSR server", either once at build time or on each
request.[^rsc] Server Components can be `async` and `await` data directly, and
because they are never sent to the browser, neither is their code or the
libraries they use. They cannot use state or effects. To add interactivity, a
file marked with the `'use client'` directive becomes a **Client Component**,
and that directive marks a boundary in the *module* graph: the file and
everything it imports are sent to the client. Props crossing the boundary must
be serialisable, so plain data, JSX and promises can cross but ordinary
functions cannot.[^rsc][^useclient]

What a Server Component produces is not HTML but the **RSC payload**, "a
compact, serialized representation of the rendered React Server Components
tree", with placeholders where Client Components go and references to their
JavaScript files.[^nextrsc] Here is the payload that `react-server-dom-webpack`
produced for a small page, an async Server Component that renders a Client
Component (with `getPost` stubbed out, and `LikeButton` registered as a client
reference the way a bundler would register a `'use client'` module):

```jsx
async function Page({ id }) {           // a Server Component: async, runs only here
  const post = await getPost(id);
  return (
    <main>
      <h1>{post.title}</h1>
      <LikeButton likes={post.likes} />
    </main>
  );
}
```

```txt
1:"./app/like-button.js"
2:I["$1",[],"default"]
0:["$","main",null,{"children":[["$","h1",null,{"children":"Hello, RSC"}],["$","$L2",null,{"likes":3}]]}]
```

Row 0 is the rendered tree: `main` and `h1` are already resolved, and the post's
title is baked in, while `getPost` and `Page` themselves are gone. In place of
`LikeButton` there is a reference, `$L2`, to row 2, an import (`I`) of the
module named in row 1 that the browser will load. Only the `likes` prop travels
with it.

{{< diagram src="rsc.svg" caption="Server Components on first load, as described by the Next.js documentation." >}}

In a framework such as Next.js, the first visit to a page returns HTML for a
fast, non-interactive preview; the RSC payload then reconciles the server and
client trees, and the Client Components' JavaScript **hydrates** them, attaching
event handlers to the existing HTML. Later navigations fetch only the RSC
payload.[^nextrsc] **Server Functions**, marked with `'use server'`, go the
other way, letting client code call a function that runs on the
server.[^v19]

Server Components move work and code off the user's device, but they also
put a protocol between client and server. On 3 December 2025 the React team
disclosed CVE-2025-55182, rated CVSS 10.0: a flaw in how React decoded payloads
sent to Server Function endpoints allowed unauthenticated remote code
execution, affecting React 19.0 to 19.2.0 and fixed in 19.0.1, 19.1.2 and
19.2.1.[^cve]

### The React Compiler

Because a component's update re-renders everything nested inside it by
default,[^rendercommit] large apps have traditionally added manual memoisation
with `memo`, `useMemo` and `useCallback`, work the documentation calls "tedious,
easy to get wrong".[^compilerintro] The **React Compiler** is a Babel plugin
that does it automatically at build time, relying on components following the
rules of React.[^compilerintro] Given a plain component:

```jsx
function TodoList({ todos, filter }) {
  const visible = todos.filter(t => t.status === filter);
  return (
    <ul>
      {visible.map(t => <li key={t.id}>{t.text}</li>)}
    </ul>
  );
}
```

`babel-plugin-react-compiler` 1.0 produces:

```js
import { c as _c } from "react/compiler-runtime";
import { jsx as _jsx } from "react/jsx-runtime";
function TodoList(t0) {
  const $ = _c(7);
  const {
    todos,
    filter
  } = t0;
  let t1;
  if ($[0] !== filter || $[1] !== todos) {
    let t2;
    if ($[3] !== filter) {
      t2 = t => t.status === filter;
      $[3] = filter;
      $[4] = t2;
    } else {
      t2 = $[4];
    }
    const visible = todos.filter(t2);
    t1 = visible.map(_temp);
    $[0] = filter;
    $[1] = todos;
    $[2] = t1;
  } else {
    t1 = $[2];
  }
  let t2;
  if ($[5] !== t1) {
    t2 = /*#__PURE__*/_jsx("ul", {
      children: t1
    });
    $[5] = t1;
    $[6] = t2;
  } else {
    t2 = $[6];
  }
  return t2;
}
function _temp(t_0) {
  return /*#__PURE__*/_jsx("li", {
    children: t_0.text
  }, t_0.id);
}
```

`_c(7)` gives the component a cache of seven slots that persists across
renders. Each computed value is stored with the inputs it depended on and
reused while they are unchanged: if neither `todos` nor `filter` changed, the
filtering and the list items are skipped and the same `<ul>` element is
returned, which in turn lets React skip re-rendering below it. The callback
that does not depend on anything (`_temp`) is hoisted out of the component
entirely. At Meta, the compiler improved initial loads and cross-page
navigations in the Quest Store by up to 12 percent and made some interactions
more than 2.5 times faster, with neutral memory use. It works with React 17 and
later.[^compiler1]

## Working with React

### Starting a project

The documentation's recommended starting points are frameworks, each with its
own generator:[^creating]

```sh
npx create-next-app@latest        # Next.js
npx create-react-router@latest    # React Router in framework mode
npx create-expo-app@latest        # Expo, for native apps
```

For a client-only single-page app, or to learn the pieces one by one, a build
tool works too:[^scratch]

```sh
npm create vite@latest my-app -- --template react-ts
```

That template provides a development server and a production build, but
nothing for routing, data fetching, server rendering or code splitting; the
documentation suggests libraries for each.[^scratch] Its suggested template is
the TypeScript one: JSX type-checks like any other expression, so a misspelt
prop is a compile-time error.

### Thinking in components

The documentation's "Thinking in React" turns a design into code in five
steps: break the UI into a component hierarchy; build a static version that
only renders props; find the minimal but complete representation of the
state; decide which component should own each piece of state; and add
"inverse data flow", passing callbacks down so children can request
changes.[^thinking] The guiding rule is to keep each piece of state in exactly
one place, the closest common parent of everything that needs it, and to derive
everything else during render.

### Sharing data with context

Passing props through many layers that do not use them ("prop drilling")
becomes tedious. **Context** "lets the parent component make some information
available to any component in the tree below it—no matter how deep—without
passing it explicitly through props":[^context]

```jsx
const ThemeContext = createContext("light");   // the default value

function Button({ children }) {
  const theme = useContext(ThemeContext);       // read the nearest provider
  return <button className={`btn-${theme}`}>{children}</button>;
}

function Toolbar() {                            // passes nothing down
  return <nav><Button>Save</Button></nav>;
}

console.log(renderToString(<Toolbar />));
console.log(renderToString(
  <ThemeContext value="dark">
    <Toolbar />
  </ThemeContext>
));
```

```txt
<nav><button class="btn-light">Save</button></nav>
<nav><button class="btn-dark">Save</button></nav>
```

Since React 19 the context object itself is the provider, so
`<ThemeContext value="dark">` replaces the older
`<ThemeContext.Provider>`.[^v19] The documentation warns against reaching for
context too early: passing props, or passing JSX as `children`, often keeps the
data flow clearer.[^context]

### Fetching data

Where data comes from is the biggest choice a React app makes, and React
itself deliberately leaves it open. Frameworks fetch on the server, in route
loaders or in Server Components; in a client-only app, libraries such as
TanStack Query, SWR or RTK Query handle caching, loading and error
states.[^scratch][^noeffect] Fetching in an effect is possible, but the
documentation spells out what it takes to do correctly: "there is no guarantee
about which order the responses will arrive in", so each effect must ignore
responses that arrive after it has been cleaned up.[^noeffect] Here a search
box changes from `he` to `hello`, and the server happens to answer the older
request last:

```jsx
function Naive({ query }) {
  const [results, setResults] = useState("");
  useEffect(() => {
    fetchResults(query).then(setResults);
  }, [query]);
  return <p>{results}</p>;
}

function WithCleanup({ query }) {
  const [results, setResults] = useState("");
  useEffect(() => {
    let ignore = false;
    fetchResults(query).then(json => { if (!ignore) setResults(json); });
    return () => { ignore = true; };
  }, [query]);
  return <p>{results}</p>;
}
```

```txt
Naive       shows results for "he" for query "hello"
WithCleanup shows results for "hello" for query "hello"
```

That is a **race condition**, and the cleanup fixes it. Caching, avoiding
request waterfalls and rendering data on the server remain, which is why the
documentation says frameworks "provide more efficient built-in data fetching
mechanisms than fetching data in Effects".[^noeffect]

### Forms and Actions

React 19's **Actions** make the common pattern of submitting data, showing a
pending state and displaying the result part of React itself. A function can be
passed as a form's `action`, and `useActionState` wraps it with the latest
result and a pending flag:[^v19]

```jsx
function NameForm() {
  const [state, formAction, isPending] = useActionState(
    async (previous, formData) => {
      const name = formData.get("name");
      try {
        await saveName(name);           // e.g. a request to the server
        return { message: `Saved ${name}` };
      } catch (err) {
        return { message: err.message };
      }
    },
    { message: "" }
  );
  console.log(`render: pending=${isPending} message="${state.message}"`);
  return (
    <form action={formAction}>
      <input name="name" defaultValue="" />
      <button disabled={isPending}>Save</button>
    </form>
  );
}
// submit the form empty, then with "Ada"
```

```txt
render: pending=false message=""
--- submit ""
render: pending=true message=""
render: pending=false message="Name is required"
--- submit "Ada"
render: pending=true message="Name is required"
render: pending=false message="Saved Ada"
```

Each submission rendered once with `isPending` true, while the request was in
flight, and once with the result. There is no `onSubmit` handler, no
`preventDefault` and no separate loading state. With a framework, `saveName`
can be a Server Function running on the server. `useOptimistic` shows the
expected result immediately and reverts it if the action fails.[^v19]

### Testing

React components are usually tested by rendering them into a simulated DOM and
interacting with them the way a user would, most often with **Testing
Library**, whose guiding principle is that "the more your tests resemble the
way your software is used, the more confidence they can give you".[^rtl] With
Vitest as the test runner:

```jsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { test, expect } from "vitest";
import { Counter } from "./Counter";

test("counts clicks", async () => {
  render(<Counter initial={2} />);
  expect(screen.getByText("You clicked 2 times")).toBeTruthy();

  await userEvent.click(screen.getByRole("button", { name: "Click me" }));

  expect(screen.getByText("You clicked 3 times")).toBeTruthy();
});
```

```txt
 ✓ tst/Counter.test.jsx > counts clicks 74ms
 Test Files  1 passed (1)
      Tests  1 passed (1)
```

The test finds the button by its role and accessible name, as a user or a
screen reader would, rather than by a CSS class or a component's internals, so
it survives refactoring and fails if the button stops being accessible.

## The ecosystem

React's narrow scope means much of a React application comes from elsewhere.
The main pieces:

| Need | Common choices |
|---|---|
| **Framework** | **Next.js**, maintained by Vercel; **React Router** v7, maintained by Shopify, which brought the Remix framework's features into React Router in 2024; **Expo** for native apps; TanStack Start and RedwoodSDK as newer options[^creating][^rrv7] |
| **Routing in an SPA** | React Router, TanStack Router[^scratch] |
| **Server data** | TanStack Query, SWR, RTK Query; Apollo or Relay for GraphQL[^scratch] |
| **Client state** | Built-in state and context first; Redux, whose Redux Toolkit is its official recommended approach, and lighter stores for larger apps[^redux] |
| **Native apps** | React Native, whose "New Architecture" became the default in 0.76 (October 2024), replacing the asynchronous bridge with direct calls through the JavaScript Interface (JSI) and supporting concurrent features[^rnnewarch] |

Because so much is left open, two React applications can look very different,
and the ecosystem churns: Create React App, once the standard starter, is
deprecated,[^cra] and Remix, a framework in its own right, folded back into
React Router.[^rrv7]

## Strengths

- **A small, stable core idea.** UI as a function of state, components as
  functions and one-way data flow have stayed constant since 2013, and Hooks
  were added without breaking existing code.[^why][^hooksintro]
- **It is just JavaScript.** JSX compiles to function calls, so conditions,
  loops, functions and the type checker all work on UI with no template
  language to learn.[^why]
- **Composition and reuse.** Components and custom Hooks are ordinary functions
  that can be combined, shared and published as packages.
- **A very large community.** React is the most used front-end library in
  Stack Overflow's survey, well ahead of Vue.js and Angular,[^so2026] so
  libraries, answers and experienced developers are easy to find.
- **Many targets.** The reconciler and renderer split lets the same model drive
  the DOM, native mobile apps through React Native, and server-rendered HTML
  and streams.[^fiberarch][^rnandroid][^v16]
- **Serious engineering on rendering.** Fiber, concurrent rendering,
  transitions, Suspense, Server Components and the compiler tackle
  responsiveness and loading performance directly.[^v18][^compiler1]
- **Independent governance.** Since 2026 React belongs to a foundation with
  several corporate members rather than to a single company.[^foundation]

## Weaknesses

- **It is not a whole solution.** Routing, data fetching, forms validation,
  styling and builds must come from a framework or from libraries. The
  documentation itself warns that going without a framework "does require that
  you make choices", and the recommended choices change: Create React App went
  from official starter to deprecated.[^creating][^cra]
- **Effects are hard to get right.** Missing dependencies, missing cleanup,
  race conditions and effects that should not exist are common bugs; the
  documentation devotes a whole page to removing unnecessary effects.[^noeffect]
  In the State of JavaScript 2025 survey, React "tops the list of things
  front-end developers are struggling with", partly because it is so widely
  used.[^stateofjs]
- **Re-rendering by default.** A parent's update re-renders its children unless
  memoised. The compiler now automates that memoisation, but only for code
  that follows the rules of React.[^compilerintro]
- **Rules that the language does not enforce.** Purity during render and the
  rules of Hooks are conventions checked by linters and Strict Mode, not by
  JavaScript.[^pure][^rulesofhooks][^statememory]
- **Growing conceptual surface.** Server and Client Components, Server
  Functions, transitions, Suspense and Actions are powerful but add new
  boundaries to reason about, and the low-level APIs for building Server
  Component frameworks are not covered by semantic versioning.[^v19] The 2025
  remote code execution flaw showed that the server protocol is also a new
  attack surface.[^cve]
- **Client-side JavaScript cost.** A client-rendered React app must download
  and run React and the app before it is interactive, which is the problem
  server rendering, streaming and Server Components exist to reduce.[^nextrsc]

## When to choose React

React fits best when the interface is large, long-lived and highly interactive:
dashboards, editors, social and commerce applications, design systems shared
across many teams, and products that want web and native mobile apps written by
the same people. Its ecosystem is hard to match, and with a
framework such as Next.js or React Router it covers server rendering and data
loading as well.

It is a weaker fit for mostly static content, such as documentation sites and
blogs, where shipping a component runtime to the browser buys little, or for
teams that want one opinionated, batteries-included framework, where Angular,
described in [What Is Angular?]({{< ref "/front-end/angular" >}}), makes
more of the decisions for you. For apps that must look the same on every
platform from a single codebase, Flutter, described in
[What Is Flutter?]({{< ref "/front-end/flutter" >}}), builds, lays out and
paints its interface itself instead of using native views as React Native
does.[^flutterarch]

## Why it matters

React made a once-unpopular idea mainstream: instead of updating the page step
by step, describe what it should be and let a library reconcile the
difference. Knowing how React works underneath, why keys matter, why Hooks
must be called in order, when effects run and what crosses the wire with Server
Components, explains most of the bugs and performance problems React developers
meet.

## References

[^so2026]: Stack Overflow. (2026). Technology: Web frameworks and technologies. In *2026 Developer Survey*. <https://survey.stackoverflow.co/2026/technology>

[^releases]: React. (2026, October 14). *v19.3.1* [Software release]. GitHub. <https://github.com/react/react/releases/tag/v19.3.1>

[^repo]: React. (n.d.). *react/react: The library for web and native user interfaces* [Source code repository]. GitHub. <https://github.com/react/react>

[^why]: Hunt, P. (2013, June 5). Why did we build React? *React Blog*. <https://legacy.reactjs.org/blog/2013/06/05/why-react.html>

[^fiberarch]: Clark, A. (n.d.). *React Fiber architecture* [Unofficial design notes]. GitHub. <https://github.com/acdlite/react-fiber-architecture>

[^creating]: React. (n.d.). Creating a React app. In *React documentation*. <https://react.dev/learn/creating-a-react-app>

[^pure]: React. (n.d.). Keeping components pure. In *React documentation*. <https://react.dev/learn/keeping-components-pure>

[^thinking]: React. (n.d.). Thinking in React. In *React documentation*. <https://react.dev/learn/thinking-in-react>

[^stars]: Vjeux [Chedeau, C.]. (2016, September 28). Our first 50,000 stars. *React Blog*. <https://legacy.reactjs.org/blog/2016/09/28/our-first-50000-stars.html>

[^versions]: React. (n.d.). React versions. In *React documentation*. <https://react.dev/versions>

[^pragmatic]: Orosz, G. (2023, February 16). Behind the scenes with React.js: The documentary. *The Pragmatic Engineer*. <https://newsletter.pragmaticengineer.com/p/react-documentary>

[^oneyear]: Lou, C. (2014, May 29). One year of open-source React. *React Blog*. <https://legacy.reactjs.org/blog/2014/05/29/one-year-of-open-source-react.html>

[^roundup]: Vjeux [Chedeau, C.]. (2013, June 12). Community round-up #1. *React Blog*. <https://legacy.reactjs.org/blog/2013/06/12/community-roundup.html>

[^rn]: Alpert, S. (2015, March 26). Introducing React Native. *React Blog*. <https://legacy.reactjs.org/blog/2015/03/26/introducing-react-native.html>

[^rnandroid]: Witte, D., & von Weitershausen, P. (2015, September 14). React Native for Android: How we built the first cross-platform React Native app. *Engineering at Meta*. <https://engineering.fb.com/2015/09/14/developer-tools/react-native-for-android-how-we-built-the-first-cross-platform-react-native-app/>

[^versioning]: Markbåge, S. (2016, February 19). New versioning scheme. *React Blog*. <https://legacy.reactjs.org/blog/2016/02/19/new-versioning-scheme.html>

[^asf]: Apache Software Foundation. (n.d.). *ASF 3rd party license policy*. <https://www.apache.org/legal/resolved.html>

[^relicense]: Wolff, A. (2017, September 22). Relicensing React, Jest, Flow, and Immutable.js. *Engineering at Meta*. <https://engineering.fb.com/2017/09/22/web/relicensing-react-jest-flow-and-immutable-js/>

[^v16]: Clark, A. (2017, September 26). React v16.0. *React Blog*. <https://legacy.reactjs.org/blog/2017/09/26/react-v16.0.html>

[^hooksintro]: React. (n.d.). Introducing Hooks. In *React documentation* (legacy). <https://legacy.reactjs.org/docs/hooks-intro.html>

[^v168]: Abramov, D. (2019, February 6). React v16.8: The one with Hooks. *React Blog*. <https://legacy.reactjs.org/blog/2019/02/06/react-v16.8.0.html>

[^v17]: Abramov, D., & Nabors, R. (2020, October 20). React v17.0. *React Blog*. <https://legacy.reactjs.org/blog/2020/10/20/react-v17.html>

[^jsxtransform]: Ruan, L. (2020, September 22). Introducing the new JSX transform. *React Blog*. <https://legacy.reactjs.org/blog/2020/09/22/introducing-the-new-jsx-transform.html>

[^v18]: The React Team. (2022, March 29). React v18.0. *React Blog*. <https://react.dev/blog/2022/03/29/react-v18>

[^reactdev]: Abramov, D., & Nabors, R. (2023, March 16). Introducing react.dev. *React Blog*. <https://react.dev/blog/2023/03/16/introducing-react-dev>

[^cra]: Carroll, M., & Hanlon, R. (2025, February 14). Sunsetting Create React App. *React Blog*. <https://react.dev/blog/2025/02/14/sunsetting-create-react-app>

[^v19]: The React Team. (2024, December 5). React v19. *React Blog*. <https://react.dev/blog/2024/12/05/react-19>

[^v192]: The React Team. (2025, October 1). React 19.2. *React Blog*. <https://react.dev/blog/2025/10/01/react-19-2>

[^compiler1]: Tan, L., Savona, J., & Zhang, M. (2025, October 7). React Compiler v1.0. *React Blog*. <https://react.dev/blog/2025/10/07/react-compiler-1>

[^foundationintro]: Webster, S., Carroll, M., Savona, J., & Alpert, S. (2025, October 7). Introducing the React Foundation. *React Blog*. <https://react.dev/blog/2025/10/07/introducing-the-react-foundation>

[^foundation]: Carroll, M. (2026, February 24). The React Foundation: A new home for React hosted by the Linux Foundation. *React Blog*. <https://react.dev/blog/2026/02/24/the-react-foundation>

[^lf]: The Linux Foundation. (2026, February 24). *Linux Foundation announces the formation of the React Foundation* [Press release]. <https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-react-foundation>

[^v193]: The React Team. (2026, September 9). React 19.3. *React Blog*. <https://react.dev/blog/2026/09/09/react-19-3>

[^jsxmarkup]: React. (n.d.). Writing markup with JSX. In *React documentation*. <https://react.dev/learn/writing-markup-with-jsx>

[^typeof]: Abramov, D. (2018, December 3). Why do React elements have a $$typeof property? *Overreacted*. <https://overreacted.io/why-do-react-elements-have-typeof-property/>

[^internals]: React. (n.d.). Virtual DOM and internals. In *React documentation* (legacy). <https://legacy.reactjs.org/docs/faq-internals.html>

[^rendercommit]: React. (n.d.). Render and commit. In *React documentation*. <https://react.dev/learn/render-and-commit>

[^effects]: React. (n.d.). Synchronizing with Effects. In *React documentation*. <https://react.dev/learn/synchronizing-with-effects>

[^reconciliation]: React. (n.d.). Reconciliation. In *React documentation* (legacy). <https://legacy.reactjs.org/docs/reconciliation.html>

[^preserving]: React. (n.d.). Preserving and resetting state. In *React documentation*. <https://react.dev/learn/preserving-and-resetting-state>

[^lists]: React. (n.d.). Rendering lists. In *React documentation*. <https://react.dev/learn/rendering-lists>

[^lanes]: Clark, A. (2020, May 3). *Initial Lanes implementation* (Pull request #18796). GitHub. <https://github.com/facebook/react/pull/18796>

[^usetransition]: React. (n.d.). useTransition. In *React reference*. <https://react.dev/reference/react/useTransition>

[^queueing]: React. (n.d.). Queueing a series of state updates. In *React documentation*. <https://react.dev/learn/queueing-a-series-of-state-updates>

[^statememory]: React. (n.d.). State: A component's memory. In *React documentation*. <https://react.dev/learn/state-a-components-memory>

[^rulesofhooks]: React. (n.d.). Rules of Hooks. In *React reference*. <https://react.dev/reference/rules/rules-of-hooks>

[^layouteffect]: React. (n.d.). useLayoutEffect. In *React reference*. <https://react.dev/reference/react/useLayoutEffect>

[^noeffect]: React. (n.d.). You might not need an Effect. In *React documentation*. <https://react.dev/learn/you-might-not-need-an-effect>

[^events]: React. (n.d.). Common components (e.g. `<div>`): React event object. In *React reference*. <https://react.dev/reference/react-dom/components/common>

[^rsc]: React. (n.d.). Server Components. In *React reference*. <https://react.dev/reference/rsc/server-components>

[^useclient]: React. (n.d.). 'use client'. In *React reference*. <https://react.dev/reference/rsc/use-client>

[^nextrsc]: Vercel. (n.d.). Server and Client Components. In *Next.js documentation*. <https://nextjs.org/docs/app/getting-started/server-and-client-components>

[^cve]: The React Team. (2025, December 3). Critical security vulnerability in React Server Components. *React Blog*. <https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components>

[^compilerintro]: React. (n.d.). Introduction. In *React Compiler documentation*. <https://react.dev/learn/react-compiler/introduction>

[^scratch]: React. (n.d.). Build a React app from scratch. In *React documentation*. <https://react.dev/learn/build-a-react-app-from-scratch>

[^context]: React. (n.d.). Passing data deeply with context. In *React documentation*. <https://react.dev/learn/passing-data-deeply-with-context>

[^rtl]: Testing Library. (n.d.). Guiding principles. <https://testing-library.com/docs/guiding-principles>

[^rrv7]: Jackson, M. (2024, November 22). React Router v7. *Remix Blog*. <https://remix.run/blog/react-router-v7>

[^redux]: Redux. (n.d.). Getting started with Redux. In *Redux documentation*. <https://redux.js.org/introduction/getting-started>

[^rnnewarch]: The React Team. (2024, October 23). New Architecture is here. *React Native Blog*. <https://reactnative.dev/blog/2024/10/23/the-new-architecture-is-here>

[^flutterarch]: Flutter. (n.d.). Flutter architectural overview. In *Flutter documentation*. <https://docs.flutter.dev/resources/architectural-overview>

[^stateofjs]: Devographics. (2026). Front-end frameworks. In *State of JavaScript 2025*. <https://2025.stateofjs.com/en-US/libraries/front-end-frameworks/>
