---
title: "What Is Angular? Google's Web Framework, From AngularJS to Signals"
description: "Angular is the web framework Google builds its large interactive applications with. Here is its whole story and how it works: the AngularJS years and the rewrite, components and the template compiler, dependency injection, change detection from Zone.js to signals, routing, forms, server rendering, the tooling, and an honest account of its strengths and weaknesses."
date: 2026-10-20T18:00:00Z
categories: ["Front-end"]
tags: ["Angular", "TypeScript", "Web", "Front-end", "Frameworks"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Most web pages are documents. Some are applications: a mail client, an
analytics dashboard, a banking back office, a cloud console. Those have
hundreds of screens, thousands of components and teams of dozens of people
working on them for years, and building them directly on the browser's
[DOM and event loop]({{< ref "/fundamentals/how-browsers-work" >}}) quickly becomes
unmanageable. **Angular** is Google's answer to that problem: a complete,
opinionated framework that decides how such an application is structured,
compiled, tested and shipped.

This article covers where Angular came from, how it works inside, what working
with it looks like, and where it is and is not a good choice. The examples
were run with Angular 22.2.3 (TypeScript 6.0, Vitest 5.0, Node.js 24) in a
project created by the Angular CLI, and their output is shown as printed.

## What Angular is

**Angular is a web framework for building single-page applications in
TypeScript, maintained by Google.** Its own documentation describes it as "a
web framework that empowers developers to build fast, reliable applications",
and stresses that it provides the tools, APIs and libraries for applications
that grow with their team and codebase.[^overview]

The word *framework* matters. A library such as a templating or rendering
library handles one concern and leaves the rest to you; Angular ships an
answer, written and versioned by one team, for almost every concern a large
front end has:

| Package or tool | What it does |
|---|---|
| `@angular/core` | Components, templates, dependency injection, change detection, signals |
| `@angular/common` | Common directives and pipes, and `HttpClient` for talking to servers |
| `@angular/router` | Maps URLs to components, with lazy loading and guards |
| `@angular/forms` | Signal forms, reactive forms and template-driven forms |
| `@angular/ssr` | Server-side rendering, prerendering and hydration |
| `@angular/cli` and `@angular/build` | Project creation, code generation, the dev server, builds, tests and automated updates |
| Angular DevTools | A browser extension for debugging, including the component and injector trees[^v17][^v20] |

Inside Google, Angular is the framework for "highly interactive apps,
prioritizing developer experience and quick delivery of complex UIs", such as
Gemini and Google Analytics.[^wiz] Outside it, 16 percent of the developers in
Stack Overflow's 2026 survey reported extensive work with Angular in the past
year, against 41.5 percent for React and 17.2 percent for Vue.js.[^so2026]

## A history of Angular

Angular has had two lives. The first framework, now called **AngularJS**, was
written in JavaScript and released in 2010. The second, called simply
**Angular**, is a ground-up rewrite in TypeScript that shares the name, the
team and many ideas, but little code.

### AngularJS: teaching HTML new tricks (2009–2016)

Angular began in 2009 as a side project of Miško Hevery, a Google engineer,
and his friend Adam Abrons. Their original aim, Hevery later said, was to
"make it easier for web designers", who would enrich their HTML forms with a
little extra markup; the name came from Abrons, from the angle brackets of
HTML tags.[^infoworld]

It got its break inside Google. Brad Green, Hevery's manager, recalled that
the Google Feedback project had grown to about 17,000 lines of front-end code
after six months of frustrating progress, when Hevery claimed he could rewrite
the whole thing in two weeks with the open source library he had made as a
hobby. It took three weeks, and the new version had 1,500 lines. Green and
Hevery built a team around the idea.[^oreilly] Version 0.9.0 of the
framework was released in October 2010, and 1.0 in June 2012.[^ngjschangelog]

AngularJS's central promise was **two-way data binding**: "the automatic
synchronization of data between the model and view components", so that the
view was "an instant projection of your model".[^ngjsdatabinding] A developer
wrote ordinary HTML with extra attributes such as `ng-model` and `ng-repeat`,
put data on a `$scope` object, and the page kept itself up to date. Behind the
scenes this was done by **dirty checking**: after any event the framework ran
a `$digest` loop that evaluated every watched expression and compared it with
its previous value, repeating until nothing changed.[^ngjsscope] And, in the
words of its README, it taught "the browser how to do dependency injection and
inversion of control", techniques until then more at home in server-side
code.[^ngjsreadme]

Dirty checking was what made the programming model so pleasant: developers
changed plain objects, and the page followed. It was also its weak point. Every
watched expression was evaluated on every digest, so the guide warned that the
dirty-checking function "must be efficient" and must not touch the
DOM,[^ngjsscope] and the work grew with the number of bindings on the page.

### The rewrite (2014–2016)

In October 2014, at the ng-europe conference in Paris, Igor Minar and Tobias
Bosch presented the plans for "AngularJS 2.0". It would drop controllers,
`$scope`, the directive definition object, `angular.module` and jqLite, support
only evergreen browsers, and be written in **AtScript**, a superset of
TypeScript with annotations. The team said there was no migration path from
1.x, although it did not rule one out for later.[^infoq2014]

AtScript did not last. In March 2015 Microsoft announced that Angular 2 would
be built with TypeScript itself after "a months-long partnership with the
Angular team", and that TypeScript 1.5 would gain decorators, a way to
annotate classes with metadata, which was the main thing AtScript had
added.[^tsblog] The final release of Angular 2 came in September 2016,
announced as "the full-platform successor to Angular 1"; from 2.0.0 on,
Angular followed **semantic versioning**.[^ng2final][^npm]

A naming problem followed at once. The router package was already at version
3, so in December 2016 the team announced that the next major version would be
4, that all packages would share one version number, that the framework would
be called "Angular" while "AngularJS" meant only the 1.x line, and that a new
major version would come roughly every six months.[^juri] Angular 4.0.0 shipped
in March 2017.[^npm]

### Ivy (2020)

Angular's first compiler and runtime generated a sizeable factory of code for
every component. Their replacement, **Ivy**, designed to generate less code per
component and to let bundlers remove the parts of Angular an application does
not use, became the default compiler and runtime in Angular 9 in February
2020, "one of the biggest updates to Angular we've made in the past 3 years".
It produced
smaller bundles (around 30 percent smaller for small applications, 25 to 40
percent for large ones, by the team's measurements), faster tests, better
debugging, and made ahead-of-time compilation the default.[^v9][^aot] Ivy is
still the engine today, and is described in detail below.

### The end of AngularJS

In January 2018 the team announced the final releases of AngularJS before
long-term support. That support, extended because of the pandemic, ended on
31 December 2021: the repository was archived, the npm packages were marked
deprecated, and teams were urged to move to Angular.[^angularjseol] The last
release, 1.8.3, was tagged in April 2022 with the code name
*ultimate-farewell*.[^ngjschangelog] AngularJS is
still in use: six percent of respondents to Stack Overflow's 2026 survey
reported extensive work with it in the past year.[^so2026]

### The renaissance: standalone, signals and a new syntax (2022–2024)

From 2022 Angular changed more than at any time since the rewrite, in a
sequence the team itself called "Angular's renaissance":[^v17]

- **Standalone components.** Angular 2 had organised code into `NgModule`
  classes that declared which components belonged together. Angular 14 (June
  2022) introduced standalone components, which list their own dependencies
  and make Angular "easier to learn and get started with"; they left developer
  preview in version 15, and version 19 made them the
  default.[^standalone][^v16]
- **Signals.** Angular 16 (May 2023) previewed a new reactivity model based
  on *signals*, designed to make change detection precise and to make Zone.js
  optional; the same release previewed full-application hydration and an
  esbuild-based build system.[^v16]
- **A new template syntax and a new home.** Angular 17 (November 2023)
  introduced built-in control flow (`@if`, `@for`, `@switch`) and *deferrable
  views* (`@defer`), made the esbuild and Vite tooling the default for new
  projects, generated standalone code by default, and launched a new logo and
  a new documentation site, **angular.dev**.[^v17]
- **Wiz.** In March 2024 Google announced that Angular and Wiz, the internal
  framework behind Google Search and Photos, would gradually merge over the
  coming years. Wiz had adopted Angular's signals, and Angular's deferrable
  views and its work on partial hydration were "highly inspired by Wiz's fine
  grained code loading and an event delegation library".[^wiz]

### Zoneless and the present (2024–2026)

Since Angular 2, a library called **Zone.js** had told the framework when to
update the page. The team spent the next releases removing it. Zoneless change
detection was introduced experimentally in version 18 (2024), reached
developer preview in version 20 and was declared stable in 20.2; Angular 21
(November 2025) stopped including Zone.js in new applications, made Vitest the
default test runner and introduced experimental **Signal Forms**.[^v21][^v20]
Version 20 had finished stabilising the core signal APIs and deprecated the old
`*ngIf`, `*ngFor` and `*ngSwitch` directives in favour of the built-in control
flow.[^v20]

Angular 22, released on 3 June 2026, declared Signal Forms, the Angular Aria
accessibility primitives and the asynchronous `resource` APIs stable; made
`OnPush` the default change detection strategy for components; made the Fetch
API the default backend of `HttpClient`; added a `@Service` decorator and
asynchronous dependency injection; and deprecated the remaining webpack-based
build tooling.[^v22][^changelog] It also changed the release rhythm: from v22
on, a new major version comes every twelve months instead of six, with four to
six minor releases in between.[^releases] At the time of writing the current
release is 22.2, published in September 2026, and the next major version is
planned for around June 2027.[^releases][^changelog]

## A timeline at a glance

| Year | Milestone |
|---|---|
| 2009 | Hevery and Abrons start the project; the Google Feedback rewrite |
| 2010 | AngularJS 0.9.0, the first public release |
| 2012 | AngularJS 1.0 |
| 2014 | Angular 2 announced at ng-europe |
| 2015 | Angular 2 to be built in TypeScript |
| 2016 | Angular 2.0 final; semantic versioning; version 3 skipped |
| 2017 | Angular 4 |
| 2020 | Angular 9: Ivy by default |
| 2021 | AngularJS long-term support ends (31 December) |
| 2022 | Angular 14: standalone components (preview) |
| 2023 | Angular 16: signals (preview); Angular 17: `@if`/`@for`/`@defer`, angular.dev |
| 2024 | Angular and Wiz to merge; Angular 18: zoneless (experimental); Angular 19: standalone by default |
| 2025 | Angular 20: signals stable; Angular 21: zoneless by default, Vitest |
| 2026 | Angular 22: Signal Forms stable, `OnPush` by default, yearly major releases |

## How Angular works

### Components and templates

An Angular application is a **tree of components**. A component is a
TypeScript class with a `@Component` decorator that gives it three things: a
*selector*, the custom HTML tag that places it in other templates; a
*template*, the HTML it renders; and optionally *styles*, which by default
apply only to that component's own template.[^components] A component that
uses another lists it in its `imports`.

{{< diagram src="component-anatomy.svg" caption="A component's parts, what the compiler makes of them, and what exists at run time for each use of it." >}}

Templates are HTML extended with a small binding language: `{{ }}`
interpolates text, `[property]` binds an element property (and `[class.x]`,
`[style.x]` and `[attr.x]` the corresponding classes, styles and attributes),
`(event)` listens for an event, and blocks such as `@if`, `@for` and `@switch`
control which parts of the template exist.[^binding][^controlflow] Here is a
small to-do list:

```ts
import { Component, computed, signal } from '@angular/core';

@Component({
  selector: 'app-todo-list',
  template: `
    <h2>{{ remaining() }} of {{ todos().length }} left</h2>
    <ul>
      @for (todo of todos(); track todo.id) {
        <li [class.done]="todo.done">{{ todo.title }}</li>
      } @empty {
        <li>Nothing to do</li>
      }
    </ul>
    @if (remaining() === 0) {
      <p>All done!</p>
    }
    <button (click)="completeFirst()">Complete next</button>
  `,
})
export class TodoList {
  readonly todos = signal([
    { id: 1, title: 'Write the article', done: false },
    { id: 2, title: 'Run the examples', done: false },
  ]);
  readonly remaining = computed(() => this.todos().filter(t => !t.done).length);

  completeFirst() {
    this.todos.update(list => {
      const i = list.findIndex(t => !t.done);
      return list.map((t, j) => (j === i ? { ...t, done: true } : t));
    });
  }
}
```

A test created the component, printed its heading, list items and message,
clicked the button twice and printed them again:

```ts
show();
el.querySelector('button')!.click();
el.querySelector('button')!.click();
await fixture.whenStable();
show();
```

```txt
2 of 2 left | Write the article | Run the examples
0 of 2 left | Write the article (done) | Run the examples (done) | All done!
```

The state lives in `todos`, a *signal*, and `remaining` is derived from it;
the template only describes what the page should look like for any state.
Clicking the button replaced the list with a new one, and Angular updated the
heading, added the `done` class to both items and created the paragraph that
`@if` had left out. The `track todo.id` expression in `@for` tells Angular
which DOM node belongs to which item, so that when the list changes it can
keep, move or remove existing nodes instead of rebuilding them.[^controlflow]

### The compiler: from templates to instructions

Browsers do not understand `@for` or `(click)`, so templates have to be
compiled. Since Angular 9 this happens **ahead of time (AOT)**, during the
build: the compiler analyses the TypeScript and the templates, type-checks
every binding expression in the templates against the component classes, and
generates JavaScript. The documentation lists the benefits: the browser does
not need to compile anything before rendering, templates and styles are
inlined so there are fewer requests, the compiler itself (roughly half of
Angular) is not downloaded, binding errors are reported at build time rather
than by users, and there are fewer opportunities for injection attacks.[^aot]
This is the same division of labour as any compiler, described in
[What Is a Compiler?]({{< ref "/fundamentals/compilers" >}}): the expensive analysis
happens once, at build time.

It is instructive to look at the output. This component:

```ts
@Component({
  selector: 'app-greeting',
  template: `<h1 class="title">Hello, {{ name() }}!</h1>
             <button (click)="name.set('Ada')">Rename</button>`,
})
export class Greeting {
  readonly name = signal('world');
}
```

compiled with the Angular compiler (`ngc`) became, in part:

```js
static ɵcmp = /*@__PURE__*/ i0.ɵɵdefineComponent({ type: Greeting, selectors: [["app-greeting"]], decls: 4, vars: 1, consts: [[1, "title"], [3, "click"]], template: function Greeting_Template(rf, ctx) { if (rf & 1) {
        i0.ɵɵdomElementStart(0, "h1", 0);
        i0.ɵɵtext(1);
        i0.ɵɵdomElementEnd();
        i0.ɵɵdomElementStart(2, "button", 1);
        i0.ɵɵdomListener("click", function Greeting_Template_button_click_2_listener() { return ctx.name.set("Ada"); });
        i0.ɵɵtext(3, "Rename");
        i0.ɵɵdomElementEnd();
    } if (rf & 2) {
        i0.ɵɵadvance();
        i0.ɵɵtextInterpolate1("Hello, ", ctx.name(), "!");
    } }, encapsulation: 2 });
```

The template has become a **function of instructions**, run in one of two
modes selected by the `rf` (render flags) argument. In *creation* mode
(`rf & 1`), run once, the instructions create the `h1`, its text node and the
button, and attach the click listener. In *update* mode (`rf & 2`), run each
time the view is refreshed, there is a single instruction: move to node 1 and
set its text to `"Hello, " + name() + "!"` if that differs from last time.
Nothing in the static parts of the template is ever looked at again.

This is the **incremental DOM** approach. Ivy's runtime expresses DOM changes
as a series of instructions; Angular does not use Google's separate Incremental
DOM library but implements its own version of the idea.[^koretskyi] That
library's description gives the contrast with the better-known **virtual DOM**:
"no intermediate tree is created (the existing tree is mutated in-place)",
which "significantly reduces memory allocation and GC thrashing" during
updates.[^incdom]

{{< diagram src="update-strategies.svg" caption="Two strategies for updating the page. A virtual DOM builds and diffs a new tree of objects; Ivy's compiled instructions compare bindings and write to the DOM directly." >}}

The instructions are also ordinary functions imported from `@angular/core`,
so a bundler can drop every instruction an application never uses. A template
without, say, pipes never imports the pipe instructions, which is how Ivy made
small applications smaller.[^koretskyi][^v9]

### Dependency injection

Components should not construct their own collaborators: a component that
creates its own HTTP client cannot be tested without a network, and two
components that each create a shopping cart do not share one. Angular solves
this with **dependency injection (DI)**, "a design pattern you use to organize
and share code across your application".[^di] A class declares what it needs
by calling `inject()`; an **injector** decides which instance it receives.

The simplest service is marked with `@Service()`, Angular 22's shorthand for
`@Injectable({providedIn: 'root'})`, which registers a single instance for the
whole application.[^di][^v22] Components can also *provide* a class
themselves, so that each instance of the component, and everything inside it,
gets its own copy:

```ts
import { Component, inject, Injectable, Service } from '@angular/core';

@Service()
export class Cart {
  private readonly items: string[] = [];
  add(item: string) { this.items.push(item); }
  count() { return this.items.length; }
}

let nextId = 1;

@Injectable()
export class PanelState {
  readonly id = nextId++;
}

@Component({
  selector: 'app-panel',
  template: `panel {{ state.id }}`,
  providers: [PanelState],      // one PanelState per <app-panel>
})
export class Panel {
  readonly cart = inject(Cart);
  readonly state = inject(PanelState);
}

@Component({
  selector: 'app-shop',
  imports: [Panel],
  template: `<app-panel /> <app-panel />`,
})
export class Shop {}
```

A test rendered a `Shop`, took its two `Panel` instances `a` and `b`, and
compared what they had been given:

```ts
a.cart.add('book');
console.log('same Cart?', a.cart === b.cart, '- items:', b.cart.count());
console.log('same PanelState?', a.state === b.state, '- ids:', a.state.id, b.state.id);
console.log('root Cart is that Cart?', TestBed.inject(Cart) === a.cart);
console.log(fixture.nativeElement.textContent.trim());
```

```txt
same Cart? true - items: 1
same PanelState? false - ids: 1 2
root Cart is that Cart? true
panel 1panel 2
```

Injectors form two hierarchies. **Environment injectors** hold
application-wide services: the root environment injector is configured by the
application's config and by `@Service()` classes; its parent is the platform
injector, shared by every Angular application on the page; and at the top sits
the `NullInjector`, which throws if a lookup reaches it. **Element injectors**
are created along the tree of components and directives. When a class asks
for a dependency, Angular first searches the element injectors from the
requesting component upwards, then the environment injectors, and uses the
first provider it finds.[^hdi]

{{< diagram src="injectors.svg" caption="How a Panel's request for Cart is resolved, and why each Panel gets its own PanelState." >}}

The lookup can be narrowed with options: `optional` returns `null` instead of
throwing, `self` looks only at the current element, `skipSelf` starts at the
parent, and `host` stops at the host component.[^hdi] Tests use the same
mechanism to replace a real service with a fake one, which is why DI is as
much a testing tool as an architectural one.

### Change detection: from Zone.js to signals

A framework has to know *when* to re-run those update instructions. Angular
originally answered with **Zone.js**, a library that implements "an execution
context that persists across async tasks" by patching most standard web APIs,
such as DOM events, timers and `XMLHttpRequest`.[^zonejs] Because every
callback ran inside Angular's zone, the framework learned whenever any code
had run, and then **checked the component tree**, comparing each binding with
its previous value, much as AngularJS had. A component could opt into the
`OnPush` strategy, which skips its subtree unless one of its inputs changes,
an event is handled inside it, or `markForCheck()` is called.[^skipping]

That design is simple to use, because developers never tell Angular anything,
but it has costs the team lists plainly: Zone.js "does not have any insight
into whether application state actually changed", so checks run more often
than needed; it adds payload and startup time; it makes stack traces harder to
read; and patching browser APIs is a long-term compatibility risk.[^zoneless]
The Zone.js package is no longer accepting new features.[^zonejs]

In **zoneless** mode, the default since Angular 21, Angular relies instead on
explicit notifications: a signal read by a template changing,
`markForCheck()` (which the `async` pipe calls), `ComponentRef.setInput`, a
listener bound in a template or host firing, or a dirty view being
attached.[^zoneless][^v21] Since Angular 22, components also default to
`OnPush`; the old behaviour is still available as
`ChangeDetectionStrategy.Eager`.[^v22]

{{< diagram src="change-detection.svg" caption="With Zone.js, any asynchronous callback triggers a check of the tree. Without it, only views that Angular has been notified about are refreshed." >}}

The difference is easy to see. This component shows a plain field and a
signal:

```ts
@Component({
  selector: 'app-counters',
  template: `plain: {{ plain }}, signal: {{ counter() }}`,
})
export class Counters {
  plain = 0;
  readonly counter = signal(0);
}
```

A test changed each in turn, waiting for Angular to settle after each change:

```ts
show();
c.plain = 5;               // a plain field: nobody is notified
await fixture.whenStable();
show();
c.counter.set(5);          // a signal read by the template: Angular is notified
await fixture.whenStable();
show();
```

```txt
plain: 0, signal: 0
plain: 0, signal: 0
plain: 5, signal: 5
```

Assigning to `plain` changed the object but notified no one, so the page was
not touched. Setting the signal marked the view dirty; when Angular refreshed
it, the update instructions re-read every binding in that view, which is why
the stale `plain` value appeared too. Modern Angular code keeps state that the
template reads in signals so that this never happens by accident.

### Signals

A **signal** is "a wrapper around a value that notifies interested consumers
when that value changes".[^signals] There are three basic kinds:

- **Writable signals**, created with `signal(initial)` and changed with
  `.set(value)` or `.update(fn)`.
- **Computed signals**, created with `computed(fn)`, which derive a value from
  other signals. They are "both lazily evaluated and memoized", and their
  dependencies are dynamic: only the signals actually read during the last
  computation are tracked.
- **Effects**, which run side effects when the signals they read change.

Reading a signal is calling it, `price()`, and that call is how Angular learns
who depends on what. Reading a signal in a template makes Angular mark that
view for checking when the signal changes.[^signals]

{{< diagram src="signal-graph.svg" caption="Signals form a dependency graph. Setting a signal notifies its dependents; computed values are recalculated only when they are read." >}}

Laziness and memoisation are visible from a few lines run outside any
component:

```ts
const price = signal(10);
const quantity = signal(3);
const total = computed(() => {
  console.log('computing total');
  return price() * quantity();
});

console.log('before first read');
console.log(total());   // runs the derivation
console.log(total());   // cached: nothing has changed
quantity.set(4);
console.log('after set');
console.log(total());   // a dependency changed, so it recomputes
```

```txt
before first read
computing total
30
30
after set
computing total
40
```

Creating `total` computed nothing. The first read ran the function, the second
returned the cached value, and setting `quantity` only invalidated the cache:
the function ran again when `total` was next read.

Around the core sit more specialised primitives: `linkedSignal`, a writable
signal that resets when a source changes; `resource` and `httpResource`, which
load asynchronous data and expose it as signals (stable since Angular 22); and
`toSignal`/`toObservable`, which convert between signals and RxJS
observables.[^v20][^v22][^rxjsinterop] The idea has spread beyond Angular:
TC39, the committee that standardises JavaScript, is investigating adding
signals to the language, with a reference implementation based on Angular's,
and Google's YouTube reported a 35 percent improvement in input latency on its
living-room app after adopting Angular Signals through Wiz.[^v20]

### RxJS and talking to servers

Before signals, Angular's reactive tool was **RxJS**, a library of
*observables*: streams of values over time that can be transformed with
operators such as `map`, `filter` and `switchMap`. RxJS remains part of the
framework's API, most visibly in `HttpClient`, whose methods return
"cold" observables: "no actual request happens until the Observable is
subscribed", and each subscription sends its own request.[^http]

```ts
@Service()
export class WeatherApi {
  private readonly http = inject(HttpClient);

  temperature(city: string) {
    return this.http
      .get<Forecast>(`/api/forecast/${city}`)
      .pipe(map(f => `${f.city}: ${f.celsius} °C`));
  }
}
```

A test used Angular's HTTP testing backend, which records requests instead of
sending them:

```ts
const lisbon$ = api.temperature('Lisbon');
console.log('requests before subscribe:', backend.match(() => true).length);

lisbon$.subscribe(text => console.log('received', text));
const req = backend.expectOne('/api/forecast/Lisbon');
console.log('request sent:', req.request.method, req.request.url);
req.flush({ city: 'Lisbon', celsius: 21 });
```

```txt
requests before subscribe: 0
request sent: GET /api/forecast/Lisbon
received Lisbon: 21 °C
```

Calling `temperature()` only described the request; subscribing sent it.
Laziness like this makes observables composable (they can be retried,
debounced or cancelled before anything happens), but it is also a classic
source of bugs, such as a request that never fires because nothing subscribed,
or fires twice because two things did. Signals and `httpResource` are partly
the team's answer to that complexity.[^v22]

### The router

An Angular application is usually a **single-page application**: the browser
loads one HTML page, and the router changes the content "in place without
triggering a full-page reload" as the URL changes.[^routing] Routes are plain
objects that map a path, which can contain parameters such as `:id`, to a
component. A route can also redirect, match anything with `**`, or load its
component only when it is first visited:[^routes][^lazy]

```ts
@Component({ selector: 'app-home', template: `Home` })
export class Home {}

@Component({ selector: 'app-product', template: `Product {{ id() }}` })
export class ProductPage {
  readonly id = input.required<string>();   // filled from the :id parameter
}

export const routes: Routes = [
  { path: '', component: Home },
  { path: 'products/:id', component: ProductPage },
  { path: 'admin', loadComponent: () => import('./admin').then(m => m.Admin) },
  { path: '**', redirectTo: '' },
];
```

A test navigated to four URLs and printed what was rendered:

```ts
for (const url of ['/', '/products/42', '/admin', '/nowhere']) {
  await harness.navigateByUrl(url);
  console.log(url.padEnd(14), '→', harness.routeNativeElement!.textContent);
}
```

```txt
/              → Home
/products/42   → Product 42
/admin         → Admin (loaded on demand)
/nowhere       → Home
```

The `import()` in the `admin` route is a dynamic import, so the build puts the
admin component in a separate file that is downloaded only when someone visits
`/admin`; lazy loading like this "can significantly improve the load speed" of
a large application.[^lazy] Routes can also be protected by guards and can
fetch data before they activate.[^routing]

### Forms

Forms are where front-end code gets complicated: values, validation, touched
and dirty states, errors, disabled controls and submission. Angular offers
three approaches. **Template-driven forms** put the logic in the template with
directives and suit simple forms; **reactive forms** build an explicit object
model in TypeScript and are more scalable, reusable and testable.[^forms] The
newest, **Signal Forms**, stable since Angular 22, combine "the best parts of
Reactive forms, the value of strongly typed forms, as well as the things
developers love about template driven forms and reactivity of
signals".[^v22] A Signal Form wraps a signal holding the model and attaches
validation rules to its fields:

```ts
import { Component, signal } from '@angular/core';
import { email, form, FormField, minLength, required } from '@angular/forms/signals';

@Component({
  selector: 'app-signup',
  imports: [FormField],
  template: `
    <input type="email" [formField]="signup.email" />
    <input type="password" [formField]="signup.password" />
    <button [disabled]="signup().invalid()">Sign up</button>
  `,
})
export class Signup {
  readonly model = signal({ email: '', password: '' });
  readonly signup = form(this.model, s => {
    required(s.email, { message: 'Email is required' });
    email(s.email, { message: 'Not an email address' });
    minLength(s.password, 8, { message: 'At least 8 characters' });
  });
}
```

A test typed into the inputs and reported the model, the errors and the
button's state after each step:

```txt
{"email":"","password":""} | errors: [ 'Email is required' ] | button disabled: true
{"email":"ada@example.com","password":"secret"} | errors: [ 'At least 8 characters' ] | button disabled: true
{"email":"ada@example.com","password":"lovelace1815"} | errors: [] | button disabled: false
```

Typing updated the model signal directly, validation re-ran as a computation
over it, and the button's `disabled` binding followed. Note that the empty
password produced no error at first: the length rule does not apply to an
empty value, which is what `required` is for.

### Server-side rendering and hydration

A single-page application has a weakness: until its JavaScript has downloaded
and run, the page is empty. Angular can instead render on the server. Each
route can be rendered per request on the server (`RenderMode.Server`), once at
build time (`RenderMode.Prerender`), or in the browser as usual
(`RenderMode.Client`); server rendering offers faster page loads and better
search-engine optimisation.[^ssr]

The server's HTML still has to become a working application. **Hydration**
"restores the server-side rendered application on the client": instead of
throwing the server's DOM away and rendering again, which causes flicker and
layout shifts, Angular walks the existing nodes, reuses them and attaches
listeners. This requires the server and client to produce exactly the same DOM
structure. **Event replay** captures clicks that happen before hydration and
replays them afterwards.[^hydration]

{{< diagram src="hydration.svg" caption="Server rendering and hydration. The page is visible as soon as the HTML arrives; hydration makes it interactive without re-creating it." >}}

**Incremental hydration**, enabled by default with hydration since Angular 22,
goes further: a `@defer` block with a `hydrate` trigger, such as
`@defer (hydrate on viewport)`, stays as dehydrated server HTML until its
trigger fires, and only then is its code loaded.[^incremental][^changelog]
`@defer` also works without a server, splitting any part of a template into
its own JavaScript file, loaded on idle (the default), when it enters the
viewport, on interaction, on hover, after a timer, or when a condition becomes
true.[^defer] Both features descend from the fine-grained code loading and
event delegation of Wiz.[^wiz]

### The build: esbuild, Vite and the CLI

The Angular CLI drives everything. Since Angular 17 its `application`
builder bundles with **esbuild** and the
development server is built on **Vite**; the older webpack-based builders were
deprecated in Angular 22.[^v17][^buildsystem][^v22] A production build of the
project generated by `ng new`, whose start page is a welcome screen with a
router outlet, printed:

```txt
Initial chunk files | Names         |  Raw size | Estimated transfer size
main-TK6HYCXX.js    | main          | 216.87 kB |                59.58 kB
styles-5INURTSO.css | styles        |   0 bytes |                 0 bytes

                    | Initial total | 216.87 kB |                59.58 kB
```

That baseline, about 60 kB compressed including the router, is the price of
the framework before an application adds its own code. The production
configuration also sets *budgets*: the generated project warns if the initial
bundle exceeds 500 kB and fails the build at 1 MB.

## Working with Angular

### Creating a project

A project starts with the CLI:

```sh
npx @angular/cli@latest new demo
cd demo
npx ng serve
```

`ng new` asks a few questions (stylesheet format, server-side rendering) and
creates a workspace. The project used for this article contained:

```txt
demo/
  angular.json            workspace and build configuration
  package.json            dependencies: @angular/*, rxjs, typescript, vitest
  tsconfig.json           TypeScript and Angular compiler options
  public/                 static files copied as they are
  src/
    index.html            the single HTML page
    main.ts               bootstrapApplication(App, appConfig)
    styles.css            global styles
    app/
      app.ts              the root component
      app.html, app.css   its template and styles
      app.config.ts       application-wide providers
      app.routes.ts       the route table
      app.spec.ts         a first test
```

The entry point is short. `main.ts` boots the root component with a
configuration, and the configuration lists the application-wide providers,
here the router:

```ts
// main.ts
bootstrapApplication(App, appConfig)
  .catch((err) => console.error(err));

// app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes)
  ]
};
```

### The CLI's main commands

| Command | What it does |
|---|---|
| `ng new` | Creates a new Angular workspace |
| `ng serve` | Builds and serves the application, rebuilding on file changes |
| `ng generate` | Generates or modifies files from a schematic, such as `ng generate component todo-list` |
| `ng build` | Compiles the application into `dist/` |
| `ng test` | Runs the unit tests |
| `ng add` | Adds support for a library, such as `ng add @angular/ssr` |
| `ng update` | Updates the workspace and its dependencies, running migrations |

The descriptions follow the CLI reference.[^cli][^update] Generated code
follows the project's conventions, which is one reason Angular code bases
tend to look alike: a developer moving between Angular projects finds the same
structure, the same DI, the same router and the same test setup.

### Testing

New projects use **Vitest**, running tests in Node.js with jsdom emulating the
DOM, or in a real browser; Karma and Jasmine are still supported.[^testing]
Angular's `TestBed` creates components with real dependency injection, and
every example in this article was run that way, with `ng test`. The test for
the to-do list in full:

```ts
import { TestBed } from '@angular/core/testing';
import { TodoList } from './todo-list';

describe('TodoList', () => {
  it('updates the view when its signals change', async () => {
    const fixture = TestBed.createComponent(TodoList);
    await fixture.whenStable();
    const el: HTMLElement = fixture.nativeElement;
    const show = () => console.log(
      [...el.querySelectorAll('h2, li, p')]
        .map(n => n.className ? `${n.textContent} (${n.className})` : n.textContent)
        .join(' | '));

    show();
    el.querySelector('button')!.click();
    el.querySelector('button')!.click();
    await fixture.whenStable();
    show();

    expect(el.querySelector('p')?.textContent).toBe('All done!');
  });
});
```

`fixture.whenStable()` waits until Angular has finished any pending work,
including change detection, so the test sees what a user would see.

### Staying up to date

Angular's release policy is unusually explicit. Every major version is
supported for about 24 months: 12 months of active development, then 12 of
long-term support with only critical and security fixes. A deprecated API stays
available for at least one major version, about a year, and is removed only in
a major release. APIs marked *developer preview* or *experimental* are exempt
and can change in any release.[^releases]

`ng update` moves a project to a new version and applies code transformations
("migrations") that the team writes for its own breaking changes; the online
Update Guide gives step-by-step instructions, one major version at a
time.[^releases][^update] The big changes of recent years came with such
migrations, for example from `*ngFor` to `@for`, to standalone components, and
from the old default change detection to an explicit `Eager` strategy when
upgrading to v22.[^v17][^standalone][^changelog]

| Version | Released | Status in October 2026 |
|---|---|---|
| 22 | June 2026 | Active, until June 2027; long-term support until June 2028 |
| 21 | November 2025 | Long-term support until June 2027 |
| 20 | May 2025 | Long-term support until November 2026 |
| 2 to 19 | 2016–2024 | No longer supported |

The dates are those of Angular's release page.[^releases]

## Strengths

- **Everything in one box.** Routing, forms, HTTP, DI, testing, SSR, i18n and
  the build are designed, versioned and released together by one team. There
  is no assembling and upgrading of a dozen independent libraries, and no
  argument within a team about which ones to choose.
- **Built for large code bases and large teams.** TypeScript throughout,
  compile-time type checking of templates, dependency injection and strong
  conventions make big applications easier to navigate, refactor and test.
  Inside Google, Angular is used by thousands of engineers and
  applications.[^aot][^wiz]
- **Predictable evolution.** Semantic versioning, a published release
  schedule, two years of support per major version, a deprecation policy and
  automated `ng update` migrations make long-lived applications cheaper to keep
  current.[^releases]
- **A modern reactive core.** Signals, zoneless change detection and `OnPush`
  by default mean Angular now updates only what changed, without the overhead
  and surprises of Zone.js.[^zoneless][^v22]
- **Performance features built in.** AOT compilation, tree-shakable
  instructions, `@defer`, lazy routes, server rendering, hydration,
  incremental hydration and event replay are part of the framework rather than
  third-party add-ons.[^aot][^defer][^hydration]
- **Backed by Google.** Angular is maintained by a full-time team at Google and
  used in Google's own products, which gives some assurance of continued
  investment.[^overview][^wiz]

## Weaknesses

- **A lot to learn.** Components, templates, DI, providers, injectors, signals,
  RxJS, the router, three form systems, SSR modes and the CLI are a large
  surface before a first feature ships. Smaller libraries let a beginner start
  with less.
- **Several generations at once.** Because Angular migrates gradually,
  real code bases and online material mix `NgModule`s and standalone
  components, `*ngIf` and `@if`, Zone.js and zoneless, decorators and signal
  inputs, reactive forms and Signal Forms. Knowing which era a tutorial comes
  from is part of the job.[^v20][^standalone]
- **The AngularJS break.** The move from AngularJS to Angular was a rewrite
  with, at first, no migration path, and many organisations spent years on it.
  The memory of that break still shapes how some teams judge the
  framework.[^infoq2014][^angularjseol]
- **Opinions you cannot easily opt out of.** Angular's way of doing routing,
  DI or builds is the way; integrating a different router or bundler is
  possible but swims against the current, and the project chooses the tools,
  as with the deprecation of webpack in v22.[^v22]
- **Weight for small things.** About 60 kB of compressed JavaScript for the
  starter project is reasonable for an application, but heavy for a mostly
  static page or a small widget, where server-rendered HTML or a lighter
  library would do.
- **A smaller community than React's.** In the 2026 Stack Overflow survey,
  16.0 percent of respondents had worked extensively with Angular against
  41.5 percent with React, and 42.1 percent of Angular users wanted to keep
  using it, against 46.7 percent for React.[^so2026] Fewer users means fewer
  third-party libraries, answers and candidates to hire.

## When to choose Angular

Angular is a strong fit for large, long-lived, highly interactive applications
built by teams: internal tools, dashboards, back offices, enterprise and
government software, where consistency between developers and between years
matters more than starting fast. Its integrated tooling and conventions pay off
most when an application has many screens and many hands.

It is a weaker fit for content-heavy sites, landing pages and blogs, where
static or server-rendered HTML with little JavaScript is usually better; for
small embedded widgets, where its baseline size dominates; and for teams who
prefer to choose each library themselves.

## Why it matters

Angular's history is a compressed history of front-end development. AngularJS
showed that declarative templates and data binding could make browser
applications productive, and its dirty checking showed the cost of not knowing
what changed. The rewrite brought TypeScript, components and compilation;
Ivy turned templates into tree-shakable instructions; and the move from Zone.js
to signals replaced "check everything after anything happens" with a precise
graph of what depends on what. Understanding those mechanisms explains most of
what makes an Angular application fast or slow, and why its code looks the way
it does.

## References

[^overview]: Angular. (n.d.). What is Angular? *angular.dev*. <https://angular.dev/overview>

[^wiz]: Ramanathan, J., & Gechev, M. (2024, March 29). Angular and Wiz are better together. *Angular Blog*. <https://blog.angular.dev/angular-and-wiz-are-better-together-91e633d8cd5a>

[^so2026]: Stack Overflow. (2026). Technology: Web frameworks and technologies. In *2026 Developer Survey*. <https://survey.stackoverflow.co/2026/technology/data>

[^infoworld]: Krill, P. (2013, October 29). What's so special about Google's AngularJS. *InfoWorld*. <https://www.infoworld.com/article/2205974/whats-so-special-about-googles-angularjs.html>

[^oreilly]: Seshadri, S., & Green, B. (2013). Preface. In *AngularJS*. O'Reilly Media. <https://www.oreilly.com/library/view/angularjs/9781449355852/pr01.html>

[^ngjschangelog]: AngularJS. (2022). *CHANGELOG.md* [Source code repository, archived]. GitHub. <https://github.com/angular/angular.js/blob/master/CHANGELOG.md>

[^ngjsdatabinding]: AngularJS. (n.d.). Data binding. In *AngularJS Developer Guide* [Documentation source, archived]. GitHub. <https://github.com/angular/angular.js/blob/master/docs/content/guide/databinding.ngdoc>

[^ngjsscope]: AngularJS. (n.d.). Scopes. In *AngularJS Developer Guide* [Documentation source, archived]. GitHub. <https://github.com/angular/angular.js/blob/master/docs/content/guide/scope.ngdoc>

[^ngjsreadme]: AngularJS. (n.d.). *README.md* [Source code repository, archived]. GitHub. <https://github.com/angular/angular.js>

[^infoq2014]: Iffland, D. (2014, October 27). AngularJS 2.0 details emerge. *InfoQ*. <https://www.infoq.com/news/2014/10/angular-2-atscript>

[^tsblog]: Hoban, L. (2015, March 5). Angular 2: Built on TypeScript. *TypeScript Blog*, Microsoft. <https://devblogs.microsoft.com/typescript/angular-2-built-on-typescript/>

[^ng2final]: Kremer, J. (2016, September 22). Angular, version 2: proprioception-reinforcement. *Google Open Source Blog*. <https://opensource.googleblog.com/2016/09/angular-version-2-proprioception.html>

[^npm]: npm. (n.d.). *@angular/core* [Package version history]. <https://www.npmjs.com/package/@angular/core?activeTab=versions>

[^juri]: Strumpflohner, J. (2016, December). Ok... let me explain: it's going to be Angular 4.0, or just Angular. *juri.dev* (cross-posted to the Angular blog). <https://juri.dev/blog/2016/12/let-me-explain-angular-release-cycles>

[^v9]: Fluin, S. (2020, February 6). Version 9 of Angular now available — Project Ivy has arrived! *Angular Blog*. <https://blog.angular.dev/version-9-of-angular-now-available-project-ivy-has-arrived-23c97b63cfa3>

[^aot]: Angular. (n.d.). Ahead-of-time (AOT) compilation. *angular.dev*. <https://angular.dev/tools/cli/aot-compiler>

[^angularjseol]: Thompson, M. (2022, January 11). Discontinued long term support for AngularJS. *Angular Blog*. <https://blog.angular.dev/discontinued-long-term-support-for-angularjs-cc066b82e65a>

[^v17]: Gechev, M. (2023, November 8). Introducing Angular v17. *Angular Blog*. <https://blog.angular.dev/introducing-angular-v17-4d7033312e4b>

[^standalone]: Rickabaugh, A. (2024, September 3). The future is standalone! *Angular Blog*. <https://blog.angular.dev/the-future-is-standalone-475d7edbc706>

[^v16]: Gechev, M. (2023, May 3). Angular v16 is here! *Angular Blog*. <https://blog.angular.dev/angular-v16-is-here-4d7a28ec680d>

[^v21]: Kuehlers, J., & Thompson, M. (2025, November 19). Announcing Angular v21. *Angular Blog*. <https://blog.angular.dev/announcing-angular-v21-57946c34f14b>

[^v20]: Gechev, M. (2025, May 28). Announcing Angular v20. *Angular Blog*. <https://blog.angular.dev/announcing-angular-v20-b5c9c06cf301>

[^v22]: Angular. (2026, June 3). Announcing Angular v22. *Angular Blog*. <https://blog.angular.dev/announcing-angular-v22-c52bb83a4664>

[^changelog]: Angular. (2026). *CHANGELOG.md* [Source code repository]. GitHub. <https://github.com/angular/angular/blob/main/CHANGELOG.md>

[^releases]: Angular. (n.d.). Versioning and releases. *angular.dev*. <https://angular.dev/reference/releases>

[^components]: Angular. (n.d.). Anatomy of a component. *angular.dev*. <https://angular.dev/guide/components>

[^binding]: Angular. (n.d.). Binding dynamic text, properties and attributes. *angular.dev*. <https://angular.dev/guide/templates/binding>

[^controlflow]: Angular. (n.d.). Control flow. *angular.dev*. <https://angular.dev/guide/templates/control-flow>

[^koretskyi]: Koretskyi, M. (2018, May 15). Ivy engine in Angular: First in-depth look at compilation, runtime and change detection. *Angular In Depth*. <https://angularindepth.com/article/ivy-engine-in-angular-first-in-depth-look-at-compilation-runtime-and-c/>

[^incdom]: Google. (n.d.). *Incremental DOM* [Source code repository]. GitHub. <https://github.com/google/incremental-dom>

[^di]: Angular. (n.d.). Dependency injection in Angular. *angular.dev*. <https://angular.dev/guide/di>

[^hdi]: Angular. (n.d.). Hierarchical injectors. *angular.dev*. <https://angular.dev/guide/di/hierarchical-dependency-injection>

[^zonejs]: Angular. (n.d.). *Zone.js README* [Source code repository]. GitHub. <https://github.com/angular/angular/blob/main/packages/zone.js/README.md>

[^skipping]: Angular. (n.d.). Skipping component subtrees. *angular.dev*. <https://angular.dev/best-practices/skipping-subtrees>

[^zoneless]: Angular. (n.d.). Angular without ZoneJS (Zoneless). *angular.dev*. <https://angular.dev/guide/zoneless>

[^signals]: Angular. (n.d.). Signals. *angular.dev*. <https://angular.dev/guide/signals>

[^rxjsinterop]: Angular. (n.d.). RxJS interop with Angular signals. *angular.dev*. <https://angular.dev/ecosystem/rxjs-interop>

[^http]: Angular. (n.d.). Making HTTP requests. *angular.dev*. <https://angular.dev/guide/http/making-requests>

[^routing]: Angular. (n.d.). Routing in Angular. *angular.dev*. <https://angular.dev/guide/routing>

[^routes]: Angular. (n.d.). Define routes. *angular.dev*. <https://angular.dev/guide/routing/define-routes>

[^lazy]: Angular. (n.d.). Route loading strategies. *angular.dev*. <https://angular.dev/guide/routing/loading-strategies>

[^forms]: Angular. (n.d.). Forms in Angular. *angular.dev*. <https://angular.dev/guide/forms>

[^ssr]: Angular. (n.d.). Server and hybrid rendering. *angular.dev*. <https://angular.dev/guide/ssr>

[^hydration]: Angular. (n.d.). Hydration. *angular.dev*. <https://angular.dev/guide/hydration>

[^incremental]: Angular. (n.d.). Incremental hydration. *angular.dev*. <https://angular.dev/guide/incremental-hydration>

[^defer]: Angular. (n.d.). Deferred loading with @defer. *angular.dev*. <https://angular.dev/guide/templates/defer>

[^buildsystem]: Angular. (n.d.). Angular application build system. *angular.dev*. <https://angular.dev/tools/cli/build-system-migration>

[^testing]: Angular. (n.d.). Testing. *angular.dev*. <https://angular.dev/guide/testing>

[^cli]: Angular. (n.d.). CLI reference. *angular.dev*. <https://angular.dev/cli>

[^update]: Angular. (n.d.). ng update. *angular.dev*. <https://angular.dev/cli/update>
