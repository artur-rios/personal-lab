---
title: "How Does a Web Browser Work? From a URL to Pixels on the Screen"
description: "A web browser turns a URL into a working application in a fraction of a second. Here is how it does it: the history, the multi-process architecture, networking, HTML parsing and the DOM, CSS and the rendering pipeline, the JavaScript event loop, and the security model that holds it together."
date: 2026-10-20T17:30:00Z
categories: ["Fundamentals"]
tags: ["Browsers", "DOM", "Web", "Computer Science", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

A web browser is probably the most complex program most people use every day.
In a few hundred milliseconds it turns a line of text in an address bar into
a network connection, a stream of bytes, a tree of objects, a set of styled and
measured boxes, and finally pixels, then keeps all of that live while scripts
change it and the user scrolls, types and clicks. It is also a small operating
system in its own right ([What Is an Operating System?]({{< ref "operating-systems" >}})),
running untrusted code from every site you visit and keeping those sites apart.

This article follows that journey from URL to pixels. The DOM, CSS and
JavaScript examples were run in Chromium 152, and their output is shown as
printed.

## What a browser is

**A web browser is a program that retrieves documents and applications from
the web by their URLs, and renders them for a person to read and use.** The
HTML standard calls it a *user agent*: software that acts on the user's behalf.

Every browser has the same main components:[^garsiel]

| Component | What it does | Examples |
|---|---|---|
| **User interface** | The address bar, tabs, back button, bookmarks: everything outside the page | |
| **Browser engine** | Coordinates the UI and the rendering engine | |
| **Rendering engine** | Parses HTML and CSS, builds the page and draws it | Blink (Chrome, Edge, Opera), WebKit (Safari), Gecko (Firefox) |
| **JavaScript engine** | Runs the page's scripts | V8, JavaScriptCore, SpiderMonkey |
| **Networking** | DNS, TLS, HTTP, caching | |
| **Storage** | Cookies, local storage, IndexedDB, the HTTP cache | |

### Many processes, not one

Early browsers ran everything in one process, so one misbehaving page could
freeze or crash them all. In 2008 Google's Chrome split the browser into
several operating system processes, a design its engineers described in
research on isolating web programs,[^chrome2008][^multiprocess][^reisgribble]
and every major browser now works this way, Firefox since 2016 and Safari
through its WebKit2 architecture:[^insidebrowser1][^electrolysis][^webkit2]

{{< diagram src="architecture.svg" caption="A modern browser's process architecture, as in Chrome. Pages run in sandboxed renderer processes, separate from the privileged browser process." >}}

- The **browser process** owns the window, the address bar and the tabs, and
  coordinates everything else.
- **Renderer processes** run web content: the HTML parser, the DOM, style and
  layout, painting, and the JavaScript engine. They run in a **sandbox** that
  denies them direct access to files, the network or the screen.
- A **GPU process** draws everyone's output to the screen, and a **network
  service** performs all fetching.

Since **Site Isolation** shipped in 2018, Chrome on desktop puts each *site* in
its own renderer process, so a page from one site cannot share memory with a
page from another, even inside the same tab.[^siteisolation][^spectreblog] That matters for
security, as the Spectre attacks showed that code can read memory belonging to
its own process.

## A history of browsers

### The first browsers

Tim Berners-Lee wrote the first web browser, called **WorldWideWeb**, on a NeXT
computer at CERN in 1990. It was also an editor: the web was meant to be
written as well as read.[^tblwww] A simpler line-mode browser, written by
Nicola Pellow and released in 1991, could run on almost any
platform.[^w3history]

**NCSA Mosaic** (1993), from the National Center for Supercomputing
Applications at the University of Illinois, showed images inline with text and
ran on ordinary PCs and Macs, and it made the web popular.[^mosaic] Several of
its developers went on to found Netscape, whose **Navigator**, released in
December 1994, quickly displaced Mosaic.[^w3history][^netscape][^js]

### The browser wars and the scriptable page

In 1995 Netscape added a scripting language, created by Brendan Eich in about
ten days, that was renamed **JavaScript** before its final release. Microsoft's
Internet Explorer, launched the same year, answered in 1996 with JScript, a
compatible version, in Internet Explorer 3.[^js] Pages could
now change themselves while open. The two companies competed by adding
incompatible features, and the period is remembered as the first **browser
war**.

Standards emerged to tame it. Håkon Wium Lie proposed **Cascading Style
Sheets** in 1994, and CSS level 1 became a W3C Recommendation in December
1996.[^lie94][^css1] The **Document Object Model (DOM)** Level 1, published by
the W3C in 1998, standardised how scripts see and change a document.[^dom1]

### Engines, standards and the modern browser

Microsoft's Internet Explorer won the first browser war: by 2002 it had well
over 90 percent of users, and development slowed.[^mozillahistory] Mozilla's
**Firefox** (2004), built on the Gecko engine begun at Netscape and
open-sourced through the Mozilla project, revived competition.[^firefox1]
Apple built Safari (2003) on **WebKit**, its engine based on the KDE project's
KHTML.[^safari][^webkit] Google's **Chrome** (2008) used WebKit
with its own V8 JavaScript engine and multi-process design,[^chrome2008] and in
2013 forked WebKit as **Blink**.[^blink] Microsoft's Edge moved to Blink in
2020,[^edge] which leaves three major engines: Blink, WebKit and Gecko.

The standards changed too. In 2004 engineers from Apple, Mozilla and Opera
founded the **WHATWG** to evolve HTML in step with what browsers actually do,
leading to HTML5.[^whatwgfaq][^htmlintro] Since 2019 the WHATWG's **living
standards** for HTML and the DOM are the authoritative versions, by agreement
with the W3C,[^mou] and the WHATWG also maintains living standards for URLs,
Fetch and more. They describe precisely what browsers must do,
including how to handle broken markup, which is why modern browsers agree far
more often than their predecessors did.

## A timeline at a glance

| Year | Milestone |
|---|---|
| 1990 | Berners-Lee's WorldWideWeb browser and editor |
| 1993 | NCSA Mosaic |
| 1994 | Netscape Navigator; CSS proposed |
| 1995 | JavaScript (Navigator 2.0 beta); Internet Explorer |
| 1996 | CSS level 1; JScript in Internet Explorer 3 |
| 1998 | DOM Level 1 |
| 2003 | Safari and WebKit |
| 2004 | Firefox; the WHATWG is founded |
| 2008 | Chrome: multi-process browser with V8 |
| 2013 | Blink forked from WebKit |
| 2018 | Site Isolation in Chrome |
| 2019 | WHATWG living standards become the reference for HTML and the DOM |
| 2020 | Edge moves to Blink |

## From URL to response

Typing an address and pressing Enter starts a sequence that every page load
follows:

{{< diagram src="navigation.svg" caption="The main steps of a navigation. Steps 1 to 4 run in the browser process and network service; from step 5 the page belongs to a renderer process." >}}

### 1. Parsing the URL

The browser first decides whether the text is a URL or a search, then parses
it according to the **URL Standard** into its parts: scheme (`https`), host
(`example.com`), port, path, query and fragment.[^urlstd] If the host is on the
**HSTS** list, a site that has told the browser to use only HTTPS, `http` is
upgraded to `https` before anything is sent.[^hsts]

### 2. Finding the server

The host name is turned into an IP address by the **Domain Name System
(DNS)**: the browser checks its own cache and the operating system's, then asks
a resolver, which may query the DNS hierarchy on its behalf.[^dns]

### 3. Connecting securely

Next the browser opens a connection. Over **TCP**, it then performs a **TLS**
handshake to agree on keys and to check the server's certificate; TLS 1.3 needs
one round trip for this.[^tls13] **HTTP/3** runs over **QUIC**, which combines the
transport and TLS handshakes and avoids some of TCP's delays on lossy
networks.[^quic][^http3]

### 4. Request and response

The browser sends an **HTTP** request, `GET /` with headers describing what it
accepts, its cookies and so on, and the server replies with a status code
(`200 OK`), headers and a body.[^http] The `Content-Type` header tells the
browser what it received, such as `text/html; charset=utf-8`, though browsers
also apply a standard sniffing algorithm when it is missing or too
generic.[^mimesniff] Responses can be stored in the **HTTP cache** and reused,
subject to `Cache-Control` and related headers.[^httpcache]

### 5. Committing the navigation

When the response is an HTML document, the browser process picks a renderer
process for the site and hands it the response; the address bar updates and
the old page is unloaded. From here on, the work happens in the
renderer.[^insidebrowser2]

## From HTML to the DOM

### Parsing HTML

The renderer parses the bytes into a document in stages: it decodes the bytes
into characters using the document's encoding, a **tokenizer** turns the
characters into tokens (start tags, end tags, text, comments), and a **tree
construction** stage turns the tokens into nodes.[^htmlparsing]

HTML parsing is unusual because it never fails. The HTML Standard specifies
exactly how to recover from every kind of mistake, so all browsers build the
same tree from the same broken markup. Here a paragraph and a table are left
unclosed:

```js
const html = "<!DOCTYPE html><p>One<p>Two<table><tr><td>Cell</table>";
const doc = new DOMParser().parseFromString(html, "text/html");
console.log(doc.body.innerHTML);
```

```txt
<p>One</p><p>Two</p><table><tbody><tr><td>Cell</td></tr></tbody></table>
```

The parser closed each paragraph when the next block started, and inserted the
`<tbody>` element it requires around table rows, even though the source never
mentioned it. (Without the `<!DOCTYPE html>` the document would be in *quirks
mode*, and there the table would have ended up inside the second paragraph.)

Parsing interacts with scripts. A plain classic `<script>` element stops the parser
until the script has been fetched and run, because the script might change
the document being parsed. Scripts marked `defer` run after parsing finishes,
and `async` scripts run as soon as they arrive. To avoid waiting, browsers run
a **preload scanner** ahead of the parser that spots stylesheets, scripts and
images and starts fetching them early.[^htmlparsing][^insidebrowser3]

### The DOM

The result of parsing is the **Document Object Model (DOM)**: a tree of
**nodes** that represents the document, and the programming interface scripts
use to read and change it.[^domstd]

{{< diagram src="dom-tree.svg" caption="A small document and its DOM tree. Whitespace-only text nodes and the doctype node are omitted for clarity." >}}

The DOM Standard defines several kinds of node. The most important are the
**Document**, the root; **elements**, one per tag, with attributes and
children; and **text nodes**, holding the text between tags. Every node knows
its parent, its children and its siblings, so a script can walk and reshape the
tree:[^domstd]

```js
document.body.innerHTML = "<ul id='list'><li>Milk</li></ul>";

const item = document.createElement("li");   // a new element node
item.textContent = "Eggs";                    // with a text node inside
document.getElementById("list").append(item);

console.log(document.getElementById("list").outerHTML);
console.log(item.parentNode.nodeName, item.firstChild.nodeType);
```

```txt
<ul id="list"><li>Milk</li><li>Eggs</li></ul>
UL 3
```

The new element's parent is the `UL`, and its first child has `nodeType` 3, the
DOM's code for a text node. The DOM is live: changing it changes what the
browser renders, which is how every interactive page works. The source HTML
is only the starting point; what you see in a browser's developer tools
"Elements" panel is the current DOM, not the file the server sent.

## From CSS to boxes

### Styles and the cascade

Stylesheets are parsed into the **CSS Object Model (CSSOM)**. Then, for every
element, the browser works out the value of every CSS property, a step called
**style resolution**. When several rules set the same property on the same
element, the **cascade** decides which one wins: first by origin and
importance (author styles beat the browser's defaults, and for `!important`
declarations the order is reversed); then declarations in a `style` attribute
beat those from selectors; then cascade layers; then **specificity**; then
order of appearance.[^cascade] Specificity counts IDs, then classes, attributes
and pseudo-classes, then element names and pseudo-elements, so `#warning` beats
`.note`, which beats `p`.[^selectors] A `style` attribute's declarations are
attached directly to the element, so they beat any selector of the same
importance, whatever its specificity:

```js
document.head.insertAdjacentHTML("beforeend", `<style>
  p        { color: gray; }
  .note    { color: green; }
  #warning { color: red; }
</style>`);
document.body.innerHTML = `
  <p id="warning" class="note" style="color: blue">First</p>
  <p id="warning2" class="note">Second</p>
  <p>Third</p>`;

for (const p of document.querySelectorAll("p")) {
  console.log(p.textContent, getComputedStyle(p).color);
}
```

```txt
First rgb(0, 0, 255)
Second rgb(0, 128, 0)
Third rgb(128, 128, 128)
```

The first paragraph matches all three rules, but its inline style wins: blue.
The second matches `.note` and `p`, and the class is more specific: green. The
third matches only `p`: gray. Properties that are not set at all are either
**inherited** from the parent (like `color` and `font-family`) or take their
initial value (like `border`).[^cascade]

### The rendering pipeline

With the DOM and the computed styles ready, the browser turns them into pixels
in a series of stages:[^renderingng][^insidebrowser3]

{{< diagram src="pipeline.svg" caption="The rendering pipeline, and how much of it different kinds of change make the browser redo." >}}

- **Layout** computes the geometry of every box: where it goes and how big it
  is. CSS describes every element as a rectangular box with content, padding,
  border and margin, and layout places those boxes according to the display
  type, the available width and the text inside them.[^boxmodel] Elements with
  `display: none` produce no boxes at all.
- **Paint** records the drawing operations needed for each box, such as
  backgrounds, borders, text and images, in the right stacking order.
- **Compositing** splits the page into layers, rasterises them into bitmaps
  and combines them into the final frame. A separate compositor thread
  coordinates this, with rasterisation done in tiles, usually on the GPU, which
  is why a page can often scroll smoothly even while JavaScript is busy on the
  main thread.[^renderingng][^renderingngarch]

The pipeline also explains what makes pages slow. Changing an element's size
or position invalidates layout for it and possibly much of the page; changing
only its colour skips layout but must repaint; changing `transform` or
`opacity` on an element with its own layer can be handled by the compositor
alone. Code that alternately writes styles and reads layout values, such as
`offsetHeight`, forces the browser to recompute layout again and again, a
problem known as **layout thrashing**.

## JavaScript and the event loop

### The JavaScript engine

Scripts are run by the **JavaScript engine**. Modern engines compile JavaScript
in tiers, much like the just-in-time compilers described in
[What Is a Compiler?]({{< ref "compilers" >}}): V8, for example, first
compiles source to bytecode for its Ignition interpreter; code that runs often
is compiled to machine code by Sparkplug, then optimised by Maglev and, for the
hottest code, TurboFan, using the types it has observed.[^v8][^maglev] Memory is reclaimed automatically by a garbage collector.

### One thread, one loop

A page's JavaScript, its style and layout work, and most of its event handling
all run on one **main thread**, coordinated by the **event loop** defined in the
HTML Standard:[^eventloop]

{{< diagram src="event-loop.svg" caption="One turn of the event loop. A long task blocks everything behind it, including rendering." >}}

1. Take one **task** from a task queue, such as a timer callback, a click event
   or a network response, and run it to completion.
2. Run every **microtask**, such as promise callbacks, until the microtask
   queue is empty.
3. When a rendering opportunity arises, typically once per display refresh,
   the browser queues a task to **update the rendering**: run
   `requestAnimationFrame` callbacks, then style, layout and paint.

The order is visible from a short script:[^archibald]

```js
console.log("script start");
setTimeout(() => console.log("timeout"), 0);
Promise.resolve().then(() => console.log("promise"));
queueMicrotask(() => console.log("microtask"));
console.log("script end");
```

```txt
script start
script end
promise
microtask
timeout
```

The script itself is a task, so it runs to the end first. Its promise callback
and `queueMicrotask` callback are microtasks, which run as soon as that task
finishes. The `setTimeout` callback, even with a delay of 0, is a new task and
has to wait for the next turn of the loop.

Two consequences matter for anyone writing a web page. Because tasks run to
completion, a long-running script **blocks** everything else on the main
thread, including rendering and input handling: a 200-millisecond loop is a
200-millisecond freeze. And because a frame is due roughly every 16.7
milliseconds on a 60 Hz display, smooth animation means keeping each task
well within that budget. Work that does not need the DOM can move to a
**Web Worker**, which runs on its own thread.[^eventloop]

### Events

User input and many other happenings reach the page as **events**. When you
click a button, the browser process works out where the click landed and sends
it to the renderer, which hit-tests it to find the target element and
dispatches a `click` event.[^insidebrowser4] The event then travels
through the DOM in three phases:[^domstd]

{{< diagram src="event-flow.svg" caption="The path of a click event: down the tree, at the target, and back up." >}}

```js
document.body.innerHTML = "<div id='outer'><button id='inner'>Go</button></div>";
const order = [];

for (const id of ["outer", "inner"]) {
  const el = document.getElementById(id);
  el.addEventListener("click", () => order.push(`${id} (capture)`), { capture: true });
  el.addEventListener("click", () => order.push(`${id} (bubble)`));
}

document.getElementById("inner").click();
console.log(order.join(" → "));
```

```txt
outer (capture) → inner (capture) → inner (bubble) → outer (bubble)
```

**Capture** listeners run on the way down, then the target's listeners, then
ordinary listeners on the way back up as the event **bubbles**. Bubbling is what
makes **event delegation** possible: one listener on a list can handle clicks
on all of its items, including ones added later.

## Security: keeping sites apart

A browser runs code from every site you visit, often several at once, so
isolating them is its most important job.

- **The same-origin policy.** An **origin** is the combination of scheme, host
  and port, such as `https://example.com:8080`.[^origin] Scripts can freely read
  data only from their own origin; a page from one site cannot read your
  messages on another, even though both are open in the same browser.
- **CORS.** A server can explicitly allow other origins to read its responses
  with Cross-Origin Resource Sharing headers, which the Fetch Standard
  defines.[^fetch]
- **Cookies** carry state between requests and are scoped to the site that set
  them, with attributes such as `Secure` and `HttpOnly`, and in current
  browsers `SameSite`, limiting where they are sent.[^cookies][^cookiesbis]
- **Content Security Policy** lets a site tell the browser which sources of
  scripts and other resources to trust, limiting the damage of injected
  code.[^csp]
- **Process isolation and sandboxing**, described earlier, are the last line of
  defence: even if an attacker exploits a bug in the renderer, the sandbox and
  Site Isolation keep them away from other sites' data and the rest of the
  system.[^siteisolation]

## Putting it together: loading a page

Following one page load, the whole system appears in sequence:

1. You type `example.com` and press Enter. The address bar turns it into the
   URL `https://example.com/`, and the network service resolves the name,
   connects with TLS and sends `GET /`.
2. The response arrives as `text/html`; the browser process commits it to a
   renderer process for `example.com`.
3. The renderer streams the HTML through the tokenizer and tree builder,
   building the DOM. The preload scanner has already requested the stylesheet
   and a script.
4. The stylesheet arrives and is parsed into the CSSOM; a `defer` script will
   run after parsing.
5. Style, layout and paint run, the compositor has the layers rasterised, and
   the first pixels may appear.
6. When parsing finishes, the deferred script runs, adds event listeners and
   changes part of the DOM. The next frame recomputes style and layout for just the changed
   part.
7. You click a button. The browser process forwards the input, the renderer
   hit-tests it, dispatches a `click` through the DOM, the handler runs, and the
   event loop's next frame shows the result.

## Why it matters

Understanding the browser explains most of what makes web pages fast or slow,
correct or broken. Pages are slow when scripts block the main thread, when
render-blocking resources delay the first paint, or when code makes the browser
recompute layout over and over. Pages behave unexpectedly when the DOM no longer
matches the HTML that was sent, when a promise callback runs before a timer, or
when a security boundary quietly blocks a request. Each of those has its root in
one of the stages above, and the standards that define them are open for
anyone to read.

## References

[^garsiel]: Irish, P., & Garsiel, T. (2011). How browsers work: Behind the scenes of modern web browsers. *web.dev*. <https://web.dev/articles/howbrowserswork>

[^reisgribble]: Reis, C., & Gribble, S. D. (2009). Isolating web programs in modern browser architectures. *Proceedings of the 4th ACM European Conference on Computer Systems*, 219–232. <https://doi.org/10.1145/1519065.1519090>

[^chrome2008]: Pichai, S., & Upson, L. (2008, September 1). A fresh take on the browser. *Official Google Blog*. <https://googleblog.blogspot.com/2008/09/fresh-take-on-browser.html>

[^insidebrowser1]: Kosaka, M. (2018). Inside look at modern web browser (part 1). *Chrome for Developers*. <https://developer.chrome.com/blog/inside-browser-part1>

[^multiprocess]: The Chromium Projects. (n.d.). Multi-process architecture. <https://www.chromium.org/developers/design-documents/multi-process-architecture/>

[^siteisolation]: Reis, C., Moshchuk, A., & Oskov, N. (2019). Site Isolation: Process separation for web sites within the browser. *Proceedings of the 28th USENIX Security Symposium*, 1661–1678. <https://www.usenix.org/conference/usenixsecurity19/presentation/reis>

[^tblwww]: Berners-Lee, T. (n.d.). WorldWideWeb, the first Web client. *W3C*. <https://www.w3.org/People/Berners-Lee/WorldWideWeb.html>

[^mosaic]: National Center for Supercomputing Applications. (n.d.). NCSA Mosaic. <https://www.ncsa.illinois.edu/research/project-highlights/ncsa-mosaic/>

[^js]: Wirfs-Brock, A., & Eich, B. (2020). JavaScript: The first 20 years. *Proceedings of the ACM on Programming Languages*, 4(HOPL), 1–189. <https://doi.org/10.1145/3386327>

[^lie94]: Lie, H. W. (1994, October 10). *Cascading HTML style sheets: A proposal*. <https://www.w3.org/People/howcome/p/cascade.html>

[^css1]: Lie, H. W., & Bos, B. (1996). *Cascading Style Sheets, level 1* (W3C Recommendation). <https://www.w3.org/TR/REC-CSS1-961217>

[^dom1]: Apparao, V., et al. (1998). *Document Object Model (DOM) Level 1 Specification* (W3C Recommendation). <https://www.w3.org/TR/REC-DOM-Level-1/>

[^webkit]: WebKit. (n.d.). The WebKit open source project. <https://webkit.org/project/>

[^blink]: Barth, A. (2013, April 3). Blink: A rendering engine for the Chromium project. *Chromium Blog*. <https://blog.chromium.org/2013/04/blink-rendering-engine-for-chromium.html>

[^whatwgfaq]: WHATWG. (n.d.). FAQ. <https://whatwg.org/faq>

[^mou]: W3C & WHATWG. (2019, May 28). *Memorandum of understanding between W3C and WHATWG*. <https://www.w3.org/2019/04/WHATWG-W3C-MOU.html>

[^urlstd]: WHATWG. (n.d.). *URL Standard* (Living Standard). <https://url.spec.whatwg.org/>

[^hsts]: Hodges, J., Jackson, C., & Barth, A. (2012). *HTTP Strict Transport Security (HSTS)* (RFC 6797). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6797>

[^dns]: Mockapetris, P. (1987). *Domain names: Concepts and facilities* (RFC 1034). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1034>

[^tls13]: Rescorla, E. (2026). *The Transport Layer Security (TLS) Protocol Version 1.3* (RFC 9846, obsoleting RFC 8446 of 2018). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9846>

[^quic]: Iyengar, J., & Thomson, M. (Eds.). (2021). *QUIC: A UDP-based multiplexed and secure transport* (RFC 9000). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9000>

[^http3]: Bishop, M. (Ed.). (2022). *HTTP/3* (RFC 9114). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9114>

[^http]: Fielding, R., Nottingham, M., & Reschke, J. (Eds.). (2022). *HTTP Semantics* (RFC 9110). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9110>

[^mimesniff]: WHATWG. (n.d.). *MIME Sniffing Standard* (Living Standard). <https://mimesniff.spec.whatwg.org/>

[^httpcache]: Fielding, R., Nottingham, M., & Reschke, J. (Eds.). (2022). *HTTP Caching* (RFC 9111). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9111>

[^insidebrowser2]: Kosaka, M. (2018). Inside look at modern web browser (part 2). *Chrome for Developers*. <https://developer.chrome.com/blog/inside-browser-part2>

[^htmlparsing]: WHATWG. (n.d.). Parsing HTML documents. In *HTML Standard* (Living Standard). <https://html.spec.whatwg.org/multipage/parsing.html>

[^insidebrowser3]: Kosaka, M. (2018). Inside look at modern web browser (part 3). *Chrome for Developers*. <https://developer.chrome.com/blog/inside-browser-part3>

[^domstd]: WHATWG. (n.d.). *DOM Standard* (Living Standard). <https://dom.spec.whatwg.org/>

[^cascade]: Etemad, E. J., Suzanne, M. E., & Atkins, T., Jr. (Eds.). (2022). *CSS Cascading and Inheritance Level 5* (W3C Candidate Recommendation Snapshot). W3C. <https://www.w3.org/TR/css-cascade-5/>

[^selectors]: Etemad, E. J., & Atkins, T., Jr. (Eds.). (2026). *Selectors Level 4* (W3C Working Draft). W3C. <https://www.w3.org/TR/selectors-4/>

[^renderingng]: Harrelson, C. (2021). RenderingNG. *Chrome for Developers*. <https://developer.chrome.com/docs/chromium/renderingng>

[^boxmodel]: Bos, B., Çelik, T., Hickson, I., & Lie, H. W. (Eds.). (2011). Box model. In *Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification* (W3C Recommendation). <https://www.w3.org/TR/CSS2/box.html>

[^v8]: V8 Team. (2017, May 15). Launching Ignition and TurboFan. *V8 Blog*. <https://v8.dev/blog/launching-ignition-and-turbofan>

[^eventloop]: WHATWG. (n.d.). Event loops. In *HTML Standard* (Living Standard). <https://html.spec.whatwg.org/multipage/webappapis.html#event-loops>

[^archibald]: Archibald, J. (2015, August 17). Tasks, microtasks, queues and schedules. <https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/>

[^insidebrowser4]: Kosaka, M. (2018). Inside look at modern web browser (part 4). *Chrome for Developers*. <https://developer.chrome.com/blog/inside-browser-part4>

[^origin]: Barth, A. (2011). *The Web Origin Concept* (RFC 6454). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6454>

[^fetch]: WHATWG. (n.d.). *Fetch Standard* (Living Standard). <https://fetch.spec.whatwg.org/>

[^cookies]: Barth, A. (2011). *HTTP State Management Mechanism* (RFC 6265). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6265>

[^csp]: West, M., & Sartori, A. (Eds.). (2026). *Content Security Policy Level 3* (W3C Working Draft). W3C. <https://www.w3.org/TR/CSP3/>

[^electrolysis]: Mozilla. (n.d.). Electrolysis. *MozillaWiki*. <https://wiki.mozilla.org/Electrolysis>

[^webkit2]: WebKit. (n.d.). WebKit2. *WebKit Wiki*. <https://trac.webkit.org/wiki/WebKit2>

[^spectreblog]: Reis, C. (2018, July 11). Mitigating Spectre with Site Isolation in Chrome. *Google Online Security Blog*. <https://security.googleblog.com/2018/07/mitigating-spectre-with-site-isolation.html>

[^w3history]: W3C. (n.d.). A little history of the World Wide Web. <https://www.w3.org/History.html>

[^netscape]: Netscape Communications. (1994, December 15). Netscape Communications ships 1.0 products [Press release, reposted to www-talk]. <https://ksi.cpsc.ucalgary.ca/archives/WWW-TALK/www-talk-1994q4/1135.html>

[^mozillahistory]: Mozilla. (n.d.). History of the Mozilla project. <https://www.mozilla.org/en-US/about/history/details/>

[^firefox1]: Mozilla. (2004, November 9). Mozilla Foundation releases the highly anticipated Mozilla Firefox 1.0 web browser [Press release]. <https://blog.mozilla.org/press/2004/11/mozilla-foundation-releases-the-highly-anticipated-mozilla-firefox-1-0-web-browser/>

[^safari]: Apple. (2003, January 7). Apple unveils Safari [Press release]. <https://www.apple.com/newsroom/2003/01/07Apple-Unveils-Safari/>

[^edge]: Microsoft. (2020, January 15). New year, new browser: The new Microsoft Edge is out of preview and now available for download. *Windows Experience Blog*. <https://blogs.windows.com/windowsexperience/2020/01/15/new-year-new-browser-the-new-microsoft-edge-is-out-of-preview-and-now-available-for-download/>

[^htmlintro]: WHATWG. (n.d.). History. In *HTML Standard* (Living Standard), section 1.6. <https://html.spec.whatwg.org/multipage/introduction.html#history-2>

[^renderingngarch]: Harrelson, C. (2021). RenderingNG architecture. *Chrome for Developers*. <https://developer.chrome.com/docs/chromium/renderingng-architecture>

[^maglev]: V8 Team. (2023, December 5). Maglev: V8's fastest optimizing JIT. *V8 Blog*. <https://v8.dev/blog/maglev>

[^cookiesbis]: Bingler, S., West, M., & Wilander, J. (Eds.). (2025). *Cookies: HTTP State Management Mechanism* (Internet-Draft draft-ietf-httpbis-rfc6265bis-22). Internet Engineering Task Force. <https://datatracker.ietf.org/doc/draft-ietf-httpbis-rfc6265bis/>
