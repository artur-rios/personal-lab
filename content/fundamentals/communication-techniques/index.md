---
title: "How Do Programs Talk to Each Other? JSON, XML, Protobuf, RPC, REST, gRPC, GraphQL and Messaging"
description: "Every pair of programs that exchange data makes two choices: how to encode the data and how to shape the conversation. Here is the history of both, from remote procedure calls in the 1970s through XML, SOAP, REST and JSON to Protocol Buffers, gRPC, GraphQL, WebSocket and message brokers; how each one works on the wire, with runnable examples; their strengths and weaknesses; a side-by-side comparison; and a guide to choosing."
date: 2026-10-20T20:00:00Z
categories: ["Fundamentals"]
tags: ["APIs", "JSON", "RPC", "REST", "gRPC", "GraphQL", "Messaging", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

A mobile app asks a server for a user's orders. The server asks a payment
service whether an order was paid, tells a warehouse system to ship it, and
announces to anyone interested that it has shipped. A code editor asks a
language server where a function is defined; an AI agent asks a tool to read a
file. All of these are programs talking to other programs, and every one of
those conversations rests on two decisions: **how the data is encoded** into
bytes, and **how the conversation is shaped**, as a function call, a request
for a resource, a query, a stream or a message dropped in a queue.

The names for these decisions are a crowded field: JSON, XML, Protocol
Buffers, RPC, SOAP, REST, JSON-RPC, gRPC, GraphQL, WebSocket, server-sent
events, webhooks, AMQP, MQTT, Kafka. This article sorts them out. It starts with
the two questions every design answers, follows the history from the first
remote procedure calls to today, explains each data format and each
interaction style in technical detail with its pros and cons, compares them
side by side, and ends with a guide to choosing. It builds on
[How Do Computer Networks Work?]({{< ref "computer-networks" >}}), which
covers the TCP, TLS and HTTP underneath everything here, and
[Text Encoding]({{< ref "text-encoding" >}}), which explains the UTF-8 that
JSON and XML are written in. The Python examples were run with Python 3.14.6
and the JavaScript example with Node.js 24.17 on Windows 11; their output is
shown as printed. The GraphQL, gRPC, SOAP and OpenAPI snippets need libraries
or servers beyond the standard library and are illustrations, not captured
runs.

## Two separate choices

### Encoding: what the bytes mean

Inside a program, data lives as objects, structs, lists and pointers in
memory. None of that can cross a network: a pointer means nothing in another
process, and two machines may not even agree on the size or byte order of an
integer. Before data is sent it must be turned into a sequence of bytes, and
the receiver must turn the bytes back into its own in-memory structures. The
first step is called **encoding**, **serialization** or **marshalling**, and
the second **decoding**, **deserialization** or **unmarshalling**.[^ddia] A
**data format** such as JSON, XML or Protocol Buffers is the agreement about
how that is done.

Formats differ in two ways that matter more than any other. They are either
**text**, readable by people, or **binary**, readable only by programs; and
they either carry the names of their fields with the data, so a reader can make
sense of a message on its own, or rely on a **schema**, a separate description
of the data that both sides must have.

### Interaction: how the conversation goes

The second choice is the shape of the conversation. A client can **call a
procedure** on a server as if it were a local function (RPC); it can
**manipulate resources** named by URLs using a small set of standard methods
(REST); it can **send a query** describing exactly the data it wants
(GraphQL); a server can **push** data down a connection that stays open; or a
program can **send a message** to a broker, without knowing who will read it
or when (messaging).

The two choices are largely independent, and both sit on top of a transport,
usually HTTP, which itself runs on TCP or QUIC:

{{< diagram src="layers.svg" caption="The choices stack: an interaction style, carried in a data format, over a transport. The layers combine freely: REST can carry XML, RPC can carry JSON, a queue can carry Protobuf." >}}

### Three questions that separate the styles

Three properties explain most of the differences between the techniques
described below:

- **Is there a contract?** A **schema** or **interface definition language
  (IDL)** describes the operations and data types exactly, and tools can
  generate code and check messages from it. Without one, the contract lives in
  documentation and in the code on both sides.
- **Must both sides be running at the same time?** In **synchronous**
  request-response, the caller waits for an answer, so the callee must be up
  and reachable right now. In **asynchronous** messaging, a broker stores the
  message until a consumer is ready, and sender and receiver are decoupled in
  time.
- **Who starts the conversation?** In most styles only the client can ask.
  Push techniques let the server speak first.

Every one of them also has to answer how the two sides can change without
breaking each other. Kleppmann's terms are the useful ones: a change is
**backward compatible** if newer code can read data written by older code, and
**forward compatible** if older code can read data written by newer
code.[^ddia] Clients and servers are almost never upgraded at the same moment,
so a format or API that cannot evolve in both directions forces every party to
upgrade in lockstep.

## A short history

### Remote procedure calls

The idea of making a request to another computer look like a procedure call
is older than the Internet's TCP/IP. James White's RFC 707, at the end of
1975, proposed a procedure-call model for sharing resources across the
ARPANET, so that a program would invoke a remote service much as it called a
local routine, and already warned that "Local procedure calls are cheap;
remote procedure calls are not."[^rfc707] The idea was made practical at
Xerox PARC by Andrew Birrell and Bruce Nelson, whose 1984 paper *Implementing
Remote Procedure Calls* stated its purpose plainly, "to make distributed
computation easy", and described the design still recognisable today: the
caller makes an ordinary call into a generated **stub**, which packs the
arguments into a message, and a runtime sends it to the server, where another
stub unpacks it and calls the real procedure.[^birrell]

Sun Microsystems published its RPC protocol, together with the **External Data
Representation (XDR)** used to encode arguments, as RFCs in 1987 and
1988.[^rfc1014][^rfc1057] It became the foundation of the Network File System,
NFS,[^rfc1094] and is still specified today as Open Network Computing (ONC)
RPC version 2.[^rfc5531] The 1990s generalised the idea from procedures to
**distributed objects**. The Object Management Group's **CORBA**, first
released in 1991, let objects written in different languages call one another
through an object request broker, and CORBA 2.0 in 1996 added IIOP so that
brokers from different vendors could interoperate.[^omgcorba] Microsoft
shipped **DCOM** with Windows NT 4.0 in 1996,[^dcom] and Java added **Remote
Method Invocation (RMI)** in JDK 1.1.[^rmi] In 1994, a group at Sun
Microsystems Laboratories published *A Note on Distributed Computing*,
arguing that the attempt to make remote objects look just like local ones was
mistaken, because latency, memory access, partial failure and concurrency make
them different.[^waldo] CORBA's decline followed; one of its own experts later
blamed the complexity of its APIs and a standards process that encouraged
design by committee, while XML and SOAP drew the industry
elsewhere.[^henning]

### XML and web services

**XML 1.0** became a W3C Recommendation in February 1998,[^xml] and within
months it was carrying procedure calls. Dave Winer's **XML-RPC**, from
UserLand Software in 1998, encoded a method name and its parameters as a small XML
document sent in an HTTP POST.[^xmlrpc] Its successor, **SOAP**, added an
envelope with headers, a standard way to report faults, and extensibility;
SOAP 1.1 was published as a W3C Note in May 2000 and SOAP 1.2 became a W3C
Recommendation in June 2003.[^soap11][^soap12] Services were described in the
**Web Services Description Language (WSDL)**,[^wsdl11] from which tools
generated client code, and a growing family of WS-\* specifications added
security, reliability and transactions on top. Through the 2000s, SOAP was the
standard way for enterprise systems to expose services over HTTP.

### REST and JSON

In 2000, Roy Fielding, one of the authors of the HTTP/1.1 specification,
described in his doctoral dissertation the architectural style he had used to
guide the design of HTTP and URIs, and named it **Representational State
Transfer (REST)**.[^fielding] REST was not a protocol but a set of
constraints, and it took most of the decade for "RESTful" APIs, which used
HTTP's own methods, URLs and status codes instead of tunnelling calls through
POST, to become the norm for public web APIs.

They were increasingly written in a new format. Douglas Crockford, who says he
"discovered" rather than invented it, recalls first using **JavaScript Object
Notation (JSON)** in April 2001 at State Software, and put up a page describing
it at json.org in 2002.[^fatfree][^saga] JSON was a subset of JavaScript's own
syntax for literals, so a browser could read it with almost no code, which
suited the new style of web applications that fetched data in the background.
The `application/json` media type was registered in RFC 4627 in
2006.[^rfc4627] **JSON-RPC** took the RPC idea to JSON: version 1.0 appeared in
2005 and version 2.0 in 2010.[^jsonrpc1][^jsonrpc] The **Swagger**
specification, created at Wordnik in 2010 for describing REST APIs in a
machine-readable way, was donated in 2015 to the new OpenAPI Initiative under
the Linux Foundation, and renamed the **OpenAPI Specification**.[^oaspress][^oas]

### Schemas and binary formats return

The largest web companies, meanwhile, found text formats too slow and too
loose for the traffic between their own services, and each built a compact
binary format with a schema and generated code. Facebook described
**Thrift** in 2007,[^thrift] Google open-sourced **Protocol Buffers**, used
internally for years, in July 2008,[^pbblog] and **Apache Avro** reached
version 1.0 in 2009.[^avroreleases] Google's internal RPC system, Stubby, had
used Protocol Buffers for over a decade when Google set out to rework it as an
open project:[^grpcprinciples] **gRPC** was released in February 2015 and
reached 1.0 in August 2016,[^grpcannounce][^grpc10] and joined the Cloud
Native Computing Foundation in 2017.[^grpccncf]

Facebook, rebuilding its mobile apps in 2012, needed a way for many different
screens to fetch exactly the data they showed in one round trip. Its answer,
**GraphQL**, was released publicly in 2015,[^graphqlblog] and moved to the
vendor-neutral GraphQL Foundation, announced by the Linux Foundation in
November 2018.[^graphqlfoundation] The current edition of its specification is
dated September 2025.[^graphqlspec]

### Real time and events

HTTP was designed for the client to ask and the server to answer. Web
applications that needed the server to speak first worked around it with
**long polling**, documented with its pitfalls in RFC 6202,[^rfc6202] until
**WebSocket** (RFC 6455, 2011) gave the browser a true two-way
connection,[^websocket] and **server-sent events** gave it a standard one-way
stream.[^sse] Between servers, the simplest form of push got a name in 2007,
when Jeff Lindsay described **web hooks**, "user defined callbacks made with
HTTP POST".[^lindsay]

Between back-end systems, asynchronous messaging had a longer history in
enterprise software. **MQTT** was invented in 1999 by Andy Stanford-Clark of
IBM and Arlen Nipper of Arcom,[^mqttfaq] and became a common protocol for
devices and the Internet of Things;[^mqtt5] **AMQP**, an open wire protocol
for business messaging, became an OASIS standard in 2012;[^amqp] and
LinkedIn's **Kafka**, described in 2011, turned the message queue into a
durable, replayable log.[^kafkapaper]

### Today

Postman's 2025 survey of over 5,700 developers, architects and executives
gives a picture of current use. REST was used by 93 percent of respondents,
webhooks by 50, WebSockets by 35, GraphQL by 33, SOAP by 25, gRPC by 14,
server-sent events by 12, MQTT by 8 and AMQP by 5.[^postman] The styles are
not exclusive, so the numbers add up to far more than 100: most organisations
use several. JSON-RPC, absent from the survey, has had a revival as the message
format of developer tools: the Language Server Protocol used by code
editors,[^lsp] the Ethereum client API[^ethereum] and the Model Context
Protocol that connects AI applications to tools and data[^mcp] are all built
on it.

### A timeline at a glance

| Year | Milestone |
|---|---|
| 1975 | RFC 707 proposes a procedure-call model for network services |
| 1984 | Birrell and Nelson, *Implementing Remote Procedure Calls* |
| 1987–88 | Sun's XDR and RPC published as RFCs |
| 1991 | CORBA 1.0 |
| 1994 | *A Note on Distributed Computing* |
| 1996 | CORBA 2.0 with IIOP; DCOM |
| 1998 | XML 1.0; XML-RPC |
| 1999 | MQTT |
| 2000 | SOAP 1.1; Fielding's dissertation defines REST |
| 2001 | Crockford's first use of JSON |
| 2003 | SOAP 1.2 Recommendation |
| 2005 | JSON-RPC 1.0 |
| 2006 | RFC 4627 registers `application/json` |
| 2007 | Thrift; Lindsay's "web hooks" |
| 2008 | Protocol Buffers open-sourced |
| 2010 | JSON-RPC 2.0; Swagger created |
| 2011 | WebSocket (RFC 6455); Kafka |
| 2012 | AMQP 1.0 becomes an OASIS standard |
| 2015 | gRPC and GraphQL released; OpenAPI Initiative formed |
| 2016 | gRPC 1.0 |
| 2017 | JSON's current standards, RFC 8259 and ECMA-404 2nd edition; OpenAPI 3.0 |
| 2019 | MQTT 5.0 |
| 2023 | Problem Details for HTTP APIs (RFC 9457) |
| 2025 | GraphQL specification, September 2025 edition; OpenAPI 3.2 |
| 2026 | AsyncAPI 3.1; OpenAPI 3.2.1; MCP revision 2026-07-28 |

## Data formats

### JSON

**JSON** is a text format with four primitive types, **strings**, **numbers**,
**booleans** and **null**, and two structured ones, **objects** (unordered
sets of name-value pairs) and **arrays** (ordered lists).[^json] That is the
whole data model. Its grammar fits on a page, and it is defined identically by
the IETF's RFC 8259 and Ecma's ECMA-404.[^json][^ecma404] Between systems that
are not part of a closed ecosystem, JSON must be encoded in UTF-8.[^json]

The simplicity is the point, and also the source of most surprises. JSON has
no dates, no binary data, no distinction between integers and floating-point
numbers and no comments, and every language maps its own types onto it in its
own way. A round trip through Python's `json` module shows how much is lost:

```python
import json
from datetime import date

order = {"id": 42, "paid": True, "total": 19.9, "items": ("book", "pen"),
         "notes": None, 7: "lucky"}
text = json.dumps(order)
print(text)
back = json.loads(text)
print(back == order, back["items"], list(back)[-1].__class__.__name__)

try:
    json.dumps({"due": date(2026, 10, 20)})
except TypeError as error:
    print("TypeError:", error)

print(json.loads('{"a": 1, "a": 2}'))
print(json.loads("9007199254740993"), json.loads("0.1") + json.loads("0.2"))
```

```txt
{"id": 42, "paid": true, "total": 19.9, "items": ["book", "pen"], "notes": null, "7": "lucky"}
False ['book', 'pen'] str
TypeError: Object of type date is not JSON serializable
{'a': 2}
9007199254740993 0.30000000000000004
```

The tuple came back as a list and the integer key `7` as the string `"7"`, so
the decoded object is not equal to the original. A date cannot be encoded at
all until the program picks a convention, usually an ISO 8601 string. An object
with a repeated name was accepted, and the last value won; RFC 8259 only says
that names *should* be unique, and that what software does with duplicates is
unpredictable.[^json]

Numbers are the subtlest problem. JSON puts no limit on their size or
precision, but RFC 8259 warns that software commonly uses IEEE 754 double
precision, in which only integers between −(2^53 − 1) and 2^53 − 1 are exact,
and calls only that range interoperable.[^json] Python read
9007199254740993, which is 2^53 + 1, exactly. JavaScript, whose numbers are
doubles, cannot:

```js
const text = '{"id": 9007199254740993}';
console.log(JSON.parse(text).id);
console.log(Number.MAX_SAFE_INTEGER);
console.log(JSON.stringify({ id: 9007199254740993n.toString() }));
```

```txt
9007199254740992
9007199254740991
{"id":"9007199254740993"}
```

The browser silently reads a different number. Large identifiers, such as
64-bit database keys, therefore travel as strings, which is what the
**I-JSON** profile in RFC 7493 recommends, along with UTF-8 only, no duplicate
names, ISO 8601 for dates and base64url for binary data.[^ijson]

JSON carries no schema of its own. **JSON Schema**, whose current version is
2020-12, describes the expected structure of JSON documents so that they can be
validated and documented,[^jsonschema] and OpenAPI uses it to describe API
payloads.[^oas]

**Pros**

- Readable and writable by people; easy to debug with any text tool.
- Supported by the standard library or a common package in practically every
  language, and native to browsers.
- Self-describing: field names travel with the data, so a reader can use a
  message without a schema, and can ignore fields it does not know.
- A tiny, stable specification.

**Cons**

- Verbose: every field name is repeated in every object, and numbers are
  written as decimal text.
- Weak types: no integers, dates or binary data, and numbers beyond 2^53 are
  unsafe in many languages.
- No schema in the format; agreement must be enforced by separate tools.
- Parsing text is slower than decoding a compact binary format.

### XML

**XML**, the Extensible Markup Language, is a text format of nested
**elements**, each of which may carry named **attributes**, and of text.[^xml]
It descends from SGML, a format for documents, and it shows: XML handles
**mixed content**, text with markup inside it, which JSON cannot represent
naturally. The XML-RPC request in the RPC section below is an example.
**Namespaces** qualify element and attribute names with URIs, so that
vocabularies from different sources can be mixed in one document without
collisions,[^xmlns] and **XML Schema (XSD)** describes and validates the
structure of documents with a rich system of types.[^xsd]

XML's flexibility has a security cost. Its document type definitions can
declare **entities**, macros that the parser expands, and they can be abused:
the "billion laughs" attack nests entities so that a few hundred bytes expand
into gigabytes,[^pyxml] and **XML external entity (XXE)** injection makes a
parser that resolves external entities read local files or contact other
machines. OWASP's advice is to disable document type definitions whenever
possible.[^owaspxxe]

**Pros**

- Mature standards for schemas, namespaces, querying (XPath) and transforming
  documents, with decades of tools.
- Handles documents with mixed text and markup, not only data records.
- Namespaces allow independent vocabularies to be combined safely.

**Cons**

- More verbose than JSON, with closing tags repeating every element name.
- Two ways to say the same thing, an attribute or a child element, and no
  natural mapping to the objects and lists of programming languages.
- Complex parsers with a history of entity-expansion and XXE vulnerabilities.

### Protocol Buffers

**Protocol Buffers** (Protobuf) is a binary format with a schema. The schema
is written in a `.proto` file, which a compiler, `protoc`, turns into classes
in the target languages:

```proto
syntax = "proto3";

message Book {
  int32 id = 1;
  string title = 2;
  repeated string tags = 3;
  bool in_stock = 4;
}
```

The number after each field is its **field number**, and it, not the name, is
what goes on the wire. Each field is encoded as a **key**, the field number
shifted left three bits combined with a three-bit **wire type**, followed by
its value. The wire types say only how long the value is: `0` is a **varint**,
`1` a fixed 64-bit value, `2` a **length-delimited** value preceded by its
length, and `5` a fixed 32-bit value (`3` and `4` are deprecated).[^pbencoding]
A varint stores an integer in groups of 7 bits, least significant first, with
the top bit of each byte set when more bytes follow, so small numbers take a
single byte.[^pbencoding] This example encodes a `Book` by hand, following the
specification, and compares its size with the same data as compact JSON:

```python
import json, struct

def varint(n):
    out = bytearray()
    while True:
        low7, n = n & 0x7F, n >> 7
        out.append(low7 | (0x80 if n else 0))   # high bit: "more bytes follow"
        if not n:
            return bytes(out)

def field(number, wire_type, payload):
    return varint(number << 3 | wire_type) + payload

def length_delimited(number, data):
    return field(number, 2, varint(len(data)) + data)

book = (field(1, 0, varint(150))
        + length_delimited(2, "Dune".encode())
        + length_delimited(3, b"sf")
        + length_delimited(3, b"classic")
        + field(4, 0, varint(1)))
as_json = json.dumps({"id": 150, "title": "Dune", "tags": ["sf", "classic"],
                      "inStock": True}, separators=(",", ":")).encode()

print("protobuf:", book.hex(" "))
print(f"{len(book)} bytes as protobuf, {len(as_json)} bytes as compact JSON")
```

```txt
protobuf: 08 96 01 12 04 44 75 6e 65 1a 02 73 66 1a 07 63 6c 61 73 73 69 63 20 01
24 bytes as protobuf, 64 bytes as compact JSON
```

{{< diagram src="protobuf-bytes.svg" caption="The 24 bytes, one field per row. 150 is 1001 0110 in binary: its low seven bits, with the continuation bit set, give 0x96, and the remaining bit gives 0x01." >}}

The first three bytes, `08 96 01`, are exactly the example in the Protocol
Buffers documentation.[^pbencoding] The message is under 40 percent of the size
of the JSON, mostly because no field names are sent. That is also its
weakness: a reader without the `.proto` file sees only numbers. A generic
decoder that knows the wire format but not the schema, run on the same bytes,
prints this:

```txt
  field 1 (wire type 0): 150
  field 2 (wire type 2): b'Dune'
  field 3 (wire type 2): b'sf'
  field 3 (wire type 2): b'classic'
  field 4 (wire type 0): 1
```

The documentation says as much: a message cannot be fully interpreted without
its `.proto` file.[^pboverview]

Protobuf is designed for **schema evolution**. A new field gets a new number;
old readers skip fields they do not know, because the wire type tells them
how many bytes to skip, and new readers give missing fields their default
values. The one unbreakable rule is never to reuse a number for a different
field: "Never re-use a tag number."[^pbdonts] Since 2023 the old `proto2` and
`proto3` syntaxes have been unified as **editions**, released about once a
year; the latest is Edition 2024.[^pbeditions]

**Pros**

- Compact and fast to encode and decode.
- A schema that doubles as documentation, with generated, typed code in many
  languages.
- Clear rules for evolving the schema in both directions.

**Cons**

- Not readable without tools and the schema.
- A code-generation step in every build that uses it.
- Designed for messages that fit in memory; the documentation suggests other
  approaches for data over a few megabytes.[^pboverview]
- Browsers have no native support; JavaScript needs a library.

### Other formats

| Format | Kind | Schema | Notes |
|---|---|---|---|
| **MessagePack** | Binary | None | JSON's data model in a compact binary form[^msgpack] |
| **CBOR** | Binary | None (optional CDDL) | An IETF standard (RFC 8949) for small messages, also JSON-like[^cbor] |
| **Avro** | Binary | Required | Writes no field names or tags; the reader needs the writer's schema, and resolves it against its own[^avro] |
| **Thrift** | Binary | Required | Facebook's IDL, encoding and RPC framework in one[^thrift] |

Avro takes the opposite approach to Protobuf's numbered fields: binary Avro
data contains no type information or field names at all, and every file or
system that stores it must also keep the schema it was written with.[^avro] It
is common in data pipelines, where a **schema registry** stores the schemas
next to the data.

### Formats compared

| | JSON | XML | Protocol Buffers | MessagePack / CBOR | Avro |
|---|---|---|---|---|---|
| Representation | Text | Text | Binary | Binary | Binary |
| Readable by people | Yes | Yes | No | No | No |
| Field names on the wire | Yes | Yes | No (numbers) | Yes | No |
| Schema | Optional (JSON Schema) | Optional (XSD) | Required | Optional | Required |
| Native in browsers | Yes | Yes | No | No | No |
| Typical size | Medium | Large | Small | Small to medium | Smallest |
| Typical use | Web APIs, configuration | Documents, enterprise and legacy services | Service-to-service RPC | Compact JSON-like messages, devices | Data pipelines, event logs |

## Remote procedure calls

### The idea and its stubs

A **remote procedure call** lets a program call a function that runs in
another process, usually on another machine, with the same syntax as a local
call. Birrell and Nelson's design has five parts: the caller, a **client
stub**, the RPC runtime on each machine, a **server stub** and the procedure
itself.[^birrell]

{{< diagram src="rpc.svg" caption="The structure of an RPC system, after Birrell and Nelson. The stubs are generated, so the programmer writes only the caller and the procedure." >}}

The stubs are generated from an **interface definition**: a description of
the procedures, their parameters and their results, written in an IDL such as
Sun's RPC language, CORBA's IDL or a `.proto` file. That is RPC's great
strength: the compiler checks calls against the interface, and the
marshalling code is never written by hand.

### Why a remote call is not a local one

The stubs make a remote call *look* local, and that is also RPC's great
danger. *A Note on Distributed Computing* lists the differences no stub can
hide:[^waldo]

- **Latency.** A local call takes nanoseconds; a remote one takes from a
  fraction of a millisecond to hundreds of milliseconds. An interface designed
  as if calls were free, such as one that fetches the fields of an object one
  by one, becomes unusably slow across a network.
- **Memory.** A pointer or reference has no meaning in another address space,
  so arguments must be copied, and a change made by the callee is not seen by
  the caller.
- **Partial failure.** A local call either happens or the whole program
  crashes. A remote call can time out with no way of knowing whether the
  server never received the request, executed it and crashed, or executed it
  and lost the reply. Birrell and Nelson's system promised that a call that
  returned had run exactly once, but a call that raised an exception might
  have run once or not at all, and "the user is not told which".[^birrell]
  Retrying is then safe only if the operation is **idempotent**, meaning that
  doing it twice has the same effect as doing it once.
- **Concurrency.** The remote side serves many callers at once, in its own
  order.

These are close relatives of the *fallacies of distributed computing*, the
assumptions, such as "the network is reliable" and "latency is zero", that
newcomers to distributed systems tend to make; Peter Deutsch drafted seven of
them at Sun in 1994, and James Gosling added an eighth in 1997.[^fallacies] Every modern RPC
system acknowledges them in its interface: gRPC, for example, makes
**deadlines** and **status codes** for failures part of every call.

### XML-RPC: a procedure call in a document

XML-RPC is the simplest RPC protocol still in use, and Python's standard
library speaks it. The server registers a function; the client calls it
through a proxy object as if it were local:

```python
import threading
import xmlrpc.client
from xmlrpc.server import SimpleXMLRPCServer

server = SimpleXMLRPCServer(("127.0.0.1", 0), logRequests=False)
server.register_function(lambda a, b: a + b, "add")
threading.Thread(target=server.serve_forever, daemon=True).start()

host, port = server.server_address
proxy = xmlrpc.client.ServerProxy(f"http://{host}:{port}/")
print("add(2, 3) =", proxy.add(2, 3))

try:
    proxy.divide(1, 0)
except xmlrpc.client.Fault as fault:
    print("Fault", fault.faultCode, fault.faultString)

# The body the proxy sent for the first call:
print(xmlrpc.client.dumps((2, 3), "add"))
server.shutdown()
```

```txt
add(2, 3) = 5
Fault 1 <class 'Exception'>:method "divide" is not supported
<?xml version='1.0'?>
<methodCall>
<methodName>add</methodName>
<params>
<param>
<value><int>2</int></value>
</param>
<param>
<value><int>3</int></value>
</param>
</params>
</methodCall>
```

The call `proxy.add(2, 3)` became an HTTP POST whose body names the method and
types each parameter, and a failure on the server came back as a **fault**
that the proxy raised as an exception. XML-RPC's types are few: integers,
booleans, strings, doubles, date-times, base64 binary data, structs and
arrays.[^xmlrpc] Python's documentation warns that `xmlrpc.client` is not
secure against maliciously constructed data.[^pyxmlrpc]

### SOAP and WSDL

SOAP wrapped the same idea in a more general **envelope**: an optional
**header** for metadata such as security tokens and routing, a **body** with
the payload, and a standard **fault** element for errors.[^soap12] A SOAP 1.2
request looks like this:

```xml
<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
  <env:Header>
    <t:transaction xmlns:t="http://example.com/transactions">5</t:transaction>
  </env:Header>
  <env:Body>
    <lib:GetBook xmlns:lib="http://example.com/library">
      <lib:id>1</lib:id>
    </lib:GetBook>
  </env:Body>
</env:Envelope>
```

A WSDL document describes a service's operations, the XML Schema types of
their messages and the address and protocol to reach them, and tools generate
client classes from it.[^wsdl11] SOAP is independent of HTTP in principle, can
be signed and encrypted at the message level, and still carries much of the
traffic of banking, government, healthcare and telecommunications systems
built in its heyday. Its costs are verbosity, a deep and complex stack of
specifications, and poor fit with browsers and lightweight clients, which is
why new public APIs rarely choose it.

**Pros of classic RPC**

- Familiar: calling a remote operation looks like calling a function.
- Strongly typed contracts, with generated client and server code.
- Operations are named for what they do, which fits actions such as
  `transferFunds` or `recalculateRoute` better than resources do.

**Cons of classic RPC**

- Hides the network, inviting chatty interfaces and code that ignores partial
  failure.
- Couples client and server tightly: both need the same interface, often the
  same generated code, and changes must be coordinated.
- Older systems (Sun RPC, CORBA, DCOM, RMI) are tied to particular platforms or
  languages and work poorly across firewalls and the public Internet.

## JSON-RPC

**JSON-RPC 2.0** is RPC reduced to its essentials. A request is a JSON object
with four members: `jsonrpc`, always `"2.0"`; `method`, the name of the
procedure; `params`, an array of positional arguments or an object of named
ones; and `id`, which the client chooses and the response echoes, so that
responses can be matched to requests. A response contains either `result` or
`error`, never both.[^jsonrpc] Three more features make it practical:

- A request without an `id` is a **notification**: the server must not reply,
  so it suits fire-and-forget messages such as log entries or progress
  reports.
- An array of requests is a **batch**, answered by an array of responses.
- Errors have numeric codes, with a reserved set for protocol errors: `-32700`
  parse error, `-32600` invalid request, `-32601` method not found, `-32602`
  invalid params, `-32603` internal error, and `-32000` to `-32099` for
  server errors.[^jsonrpc]

The specification deliberately says nothing about transport: the same messages
can be passed within a process, over sockets, over HTTP or over any messaging
system.[^jsonrpc] This sketch of a server implements the whole protocol in a
few lines, and leaves the transport out on purpose:

```python
import json

METHODS = {"add": lambda a, b: a + b,
           "log": lambda message: print("   (server logged:", message + ")")}

def handle(request):
    if not isinstance(request, dict) or request.get("jsonrpc") != "2.0" \
            or not isinstance(request.get("method"), str):
        return {"jsonrpc": "2.0", "id": None,
                "error": {"code": -32600, "message": "Invalid Request"}}
    method = METHODS.get(request["method"])
    if method is None:
        response = {"error": {"code": -32601, "message": "Method not found"}}
    else:
        params = request.get("params", [])
        try:
            result = method(**params) if isinstance(params, dict) else method(*params)
            response = {"result": result}
        except TypeError:
            response = {"error": {"code": -32602, "message": "Invalid params"}}
    if "id" not in request:                 # a notification: never answered
        return None
    return {"jsonrpc": "2.0", **response, "id": request["id"]}

def serve(text):
    try:
        message = json.loads(text)
    except json.JSONDecodeError:
        return json.dumps({"jsonrpc": "2.0", "id": None,
                           "error": {"code": -32700, "message": "Parse error"}})
    if isinstance(message, list):           # a batch
        replies = [r for r in map(handle, message) if r is not None]
        return json.dumps(replies) if replies else None
    reply = handle(message)
    return json.dumps(reply) if reply else None

for text in [
    '{"jsonrpc": "2.0", "method": "add", "params": [2, 3], "id": 1}',
    '{"jsonrpc": "2.0", "method": "add", "params": {"a": 2, "b": 3}, "id": "x"}',
    '{"jsonrpc": "2.0", "method": "divide", "params": [1, 0], "id": 2}',
    '{"jsonrpc": "2.0", "method": "log", "params": ["hello"]}',
    '[{"jsonrpc": "2.0", "method": "add", "params": [1, 1], "id": 3},'
    ' {"jsonrpc": "2.0", "method": "add", "params": [1], "id": 4}]',
    '{"jsonrpc": "2.0", "method": "add", "params": [2, 3',
]:
    print("-->", text)
    print("<--", serve(text) or "(no response)")
```

```txt
--> {"jsonrpc": "2.0", "method": "add", "params": [2, 3], "id": 1}
<-- {"jsonrpc": "2.0", "result": 5, "id": 1}
--> {"jsonrpc": "2.0", "method": "add", "params": {"a": 2, "b": 3}, "id": "x"}
<-- {"jsonrpc": "2.0", "result": 5, "id": "x"}
--> {"jsonrpc": "2.0", "method": "divide", "params": [1, 0], "id": 2}
<-- {"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": 2}
--> {"jsonrpc": "2.0", "method": "log", "params": ["hello"]}
   (server logged: hello)
<-- (no response)
--> [{"jsonrpc": "2.0", "method": "add", "params": [1, 1], "id": 3}, {"jsonrpc": "2.0", "method": "add", "params": [1], "id": 4}]
<-- [{"jsonrpc": "2.0", "result": 2, "id": 3}, {"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 4}]
--> {"jsonrpc": "2.0", "method": "add", "params": [2, 3
<-- {"jsonrpc": "2.0", "id": null, "error": {"code": -32700, "message": "Parse error"}}
```

Because the messages are symmetric and transport-free, either side can send
requests to the other over one connection. That is exactly what tool
protocols need. In the Language Server Protocol, an editor and a language
server exchange JSON-RPC 2.0 messages over standard input and output, each
preceded by a `Content-Length` header, and the server can send requests and
notifications to the editor as well as answer it.[^lsp] The Model Context
Protocol uses JSON-RPC 2.0 messages between AI applications and the servers
that give them tools and data,[^mcp] and Ethereum clients expose their API the
same way.[^ethereum]

**Pros**

- Tiny and easy to implement in any language with a JSON library.
- Transport-independent and symmetric: it works over HTTP, WebSocket, pipes or
  standard input and output, in both directions.
- Notifications and batches are built in.

**Cons**

- No schema or IDL in the standard; tools and types must come from elsewhere,
  such as the LSP's and MCP's own schemas.
- When carried over HTTP, it ignores HTTP's semantics: every call is a POST,
  so HTTP caching and status codes do not help.
- Inherits JSON's weaknesses with numbers, dates and binary data.

## REST

### The constraints

REST is an **architectural style**, a set of constraints that a system can
satisfy, not a protocol or a format. Fielding derived it by starting from a
system with no constraints and adding them one at a time:[^fielding]

| Constraint | What it requires | What it buys |
|---|---|---|
| **Client-server** | Separate the user interface from data storage | Each side can evolve independently |
| **Stateless** | Each request contains everything needed to understand it; no session state on the server | Visibility, reliability, scalability: any server can handle any request |
| **Cache** | Responses label themselves cacheable or not | Some requests never reach the server |
| **Uniform interface** | One generic interface for all resources | Simplicity and independent evolution, at some cost in efficiency |
| **Layered system** | Each component sees only the next layer | Proxies, gateways and load balancers can be inserted freely |
| **Code on demand** (optional) | Servers may send code for clients to run | Clients can be extended after deployment |

The uniform interface is the heart of it, and is itself four constraints:
**identification of resources**, **manipulation of resources through
representations**, **self-descriptive messages**, and **hypermedia as the
engine of application state**.[^fielding] On the web these become concrete:
resources are identified by URLs; a client reads and changes them by
exchanging representations, usually JSON documents; messages are described by
standard methods, status codes and headers; and responses contain links that
tell the client what it can do next.

### REST over HTTP in practice

A REST API models its domain as **resources**, `/books`, `/books/1`,
`/books/1/reviews`, and uses HTTP's methods for what they mean:[^http]

| Method | Meaning | Safe | Idempotent |
|---|---|---|---|
| `GET` | Read a representation of the resource | Yes | Yes |
| `POST` | Process the enclosed data, often creating a new resource | No | No |
| `PUT` | Replace the resource with the enclosed representation | No | Yes |
| `PATCH` | Apply a partial modification | No | No |
| `DELETE` | Remove the resource | No | Yes |

**Safe** methods do not change anything on the server, and **idempotent** ones
have the same effect whether sent once or many times, so a client may retry
them after a network failure.[^http][^patch] Status codes report the outcome
in a way every HTTP client, proxy and monitoring tool already understands:
`201 Created`, `304 Not Modified`, `404 Not Found`, `409 Conflict`,
`503 Service Unavailable`.[^http]

Because REST uses HTTP's own semantics, it gets HTTP's infrastructure for
free, and caching is the most valuable part. This server returns a book with
an **entity tag** (ETag), a validator that changes whenever the
representation does, and a 404 with a **problem details** object, the
standard JSON format for HTTP API errors defined in RFC 9457:[^problem]

```python
import hashlib, http.client, json, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BOOKS = {"1": {"id": 1, "title": "Dune", "author": "Frank Herbert"}}

class Books(BaseHTTPRequestHandler):
    def do_GET(self):
        parts = self.path.strip("/").split("/")          # e.g. ["books", "1"]
        book = BOOKS.get(parts[1]) if parts[0] == "books" and len(parts) == 2 else None
        if book is None:
            problem = {"type": "about:blank", "title": "Not Found", "status": 404,
                       "detail": f"No book at {self.path}"}
            return self.reply(404, "application/problem+json", problem)
        body = json.dumps(book).encode()
        etag = '"' + hashlib.sha256(body).hexdigest()[:16] + '"'
        if self.headers.get("If-None-Match") == etag:
            self.send_response(304)                       # not modified: no body
            self.send_header("ETag", etag)
            return self.end_headers()
        self.reply(200, "application/json", book, {"ETag": etag,
                   "Cache-Control": "max-age=60"})

    def reply(self, status, content_type, payload, headers={}):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for name, value in headers.items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

server = ThreadingHTTPServer(("127.0.0.1", 0), Books)
threading.Thread(target=server.serve_forever, daemon=True).start()

def get(path, headers={}):
    conn = http.client.HTTPConnection(*server.server_address)
    conn.request("GET", path, headers=headers)
    r = conn.getresponse()
    body = r.read().decode()
    print(f"GET {path} -> {r.status} {r.reason}",
          {k: v for k, v in r.getheaders() if k in ("Content-Type", "ETag", "Cache-Control")})
    if body:
        print("   ", body)
    return r

first = get("/books/1")
get("/books/1", {"If-None-Match": first.getheader("ETag")})
get("/books/99")
server.shutdown()
```

```txt
GET /books/1 -> 200 OK {'Content-Type': 'application/json', 'ETag': '"f4745a29159b4f7a"', 'Cache-Control': 'max-age=60'}
    {"id": 1, "title": "Dune", "author": "Frank Herbert"}
GET /books/1 -> 304 Not Modified {'ETag': '"f4745a29159b4f7a"'}
GET /books/99 -> 404 Not Found {'Content-Type': 'application/problem+json'}
    {"type": "about:blank", "title": "Not Found", "status": 404, "detail": "No book at /books/99"}
```

`Cache-Control: max-age=60` lets any browser or shared cache reuse the
response for a minute without asking at all.[^caching] After that, the
**conditional request** with `If-None-Match` lets the server answer
`304 Not Modified` with no body if the book is unchanged.[^http] Neither
JSON-RPC nor gRPC nor GraphQL over POST gets this from the infrastructure,
because none of them identifies what is being read by its URL.

### Hypermedia, maturity and what "REST" usually means

Fielding's last interface constraint, hypermedia, is the one most APIs leave
out. In 2008 he wrote, in frustration, that an API whose clients must be told
in advance how to build URLs is not RESTful, however it uses HTTP: a REST
client should need nothing but an initial URL and an understanding of the
media types, and follow links from there.[^fielding2008] Leonard Richardson's
**maturity model**, popularised by Martin Fowler, describes the steps in
between:[^fowler]

- **Level 0**: HTTP as a tunnel, every call a POST to one endpoint, as in
  XML-RPC, SOAP and JSON-RPC.
- **Level 1, resources**: separate URLs for separate resources.
- **Level 2, HTTP verbs**: methods and status codes used for their meaning.
- **Level 3, hypermedia controls**: responses contain links to the next
  possible actions.

Most APIs called "REST" today are level 2: resources, methods and status codes,
with JSON representations and documentation instead of hypermedia. That is
a useful design in its own right, but it is worth knowing that it is not what
the dissertation describes.

### OpenAPI

The **OpenAPI Specification** describes HTTP APIs in a YAML or JSON document:
paths, operations, parameters, request and response bodies, with payloads
described in JSON Schema, and security schemes.[^oas] Tools generate
documentation, client libraries, server stubs, mocks and tests from it, so it
gives REST the contract that RPC gets from its IDL. Its current version is
3.2.1, from September 2026.[^oas] A fragment for the book endpoint:

```yaml
openapi: 3.2.0
info:
  title: Library
  version: 1.0.0
paths:
  /books/{id}:
    get:
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: integer }
      responses:
        "200":
          description: The book
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Book" }
        "404":
          description: No such book
          content:
            application/problem+json: {}
components:
  schemas:
    Book:
      type: object
      required: [id, title]
      properties:
        id: { type: integer }
        title: { type: string }
        author: { type: string }
```

**Pros**

- Uses the web's infrastructure as designed: caches, proxies, gateways,
  browsers, `curl` and every HTTP library understand it.
- Loose coupling: resources and standard methods change less than procedure
  lists, and JSON clients tolerate added fields.
- Universally known, easy to explore and debug, with OpenAPI for contracts and
  tooling.

**Cons**

- Not every operation is naturally a resource; actions such as "approve" or
  "recalculate" end up as awkward sub-resources or POSTs.
- Fixed responses lead to **over-fetching**, getting fields the client does
  not need, and **under-fetching**, needing several round trips to assemble
  one screen.
- No built-in schema or code generation without OpenAPI, and no standard way
  to stream or push.
- Text formats and HTTP/1.1 overheads make it slower than binary RPC for
  heavy internal traffic.

## gRPC

### Services in Protocol Buffers

**gRPC** is an RPC framework built on Protocol Buffers and HTTP/2. The
service is defined in the same `.proto` file as its messages, and `protoc`
generates client stubs and server interfaces from it. A method can be one of
four kinds:[^grpcconcepts]

```proto
syntax = "proto3";
package library.v1;

service Library {
  rpc GetBook(GetBookRequest) returns (Book);                     // unary
  rpc WatchStock(WatchStockRequest) returns (stream StockEvent);  // server streaming
  rpc ImportBooks(stream Book) returns (ImportSummary);           // client streaming
  rpc Chat(stream ChatMessage) returns (stream ChatMessage);      // bidirectional
}

message GetBookRequest { int32 id = 1; }
```

**Unary** methods are classic request-response. With **server streaming** the
client sends one request and reads a stream of responses; with **client
streaming** it sends a stream and gets one response; with **bidirectional
streaming** both sides send independent streams at the same time.[^grpcconcepts]

### On the wire

Every call is an HTTP/2 request. The method is a POST to a path made of the
fully qualified service name and the method name; the content type is
`application/grpc`, optionally with a suffix naming the encoding; and every
message, in either direction, is preceded by a 5-byte prefix: one byte saying
whether the message is compressed and four bytes of length, in network byte
order.[^grpchttp2] A call to `GetBook` with `id` 150 would look like this,
in HTTP/2's notation for header fields:

```txt
:method = POST
:scheme = https
:path = /library.v1.Library/GetBook
content-type = application/grpc+proto
te = trailers
grpc-timeout = 500m

DATA  00 00 00 00 03  08 96 01
```

The `GetBookRequest` encodes to the same three bytes as the `id` field of the
`Book` earlier, and the prefix says "not compressed, 3 bytes". `grpc-timeout`
carries the caller's **deadline**, here 500 milliseconds. The response comes
back as HTTP status 200 with the messages in DATA frames, followed by
**trailers**, header fields sent after the body, carrying the real outcome in
`grpc-status` and `grpc-message`. The specification requires the status in
the trailers even when it is OK, so that a failure in the middle of a stream
can still be reported.[^grpchttp2]

Failures use gRPC's own 17 **status codes**, from `OK` (0) through
`CANCELLED`, `INVALID_ARGUMENT`, `DEADLINE_EXCEEDED`, `NOT_FOUND`,
`PERMISSION_DENIED`, `RESOURCE_EXHAUSTED`, `UNIMPLEMENTED`, `INTERNAL` and
`UNAVAILABLE` to `UNAUTHENTICATED` (16).[^grpcstatus] Deadlines propagate: a
client says how long it is willing to wait, and if the time runs out the call
ends with `DEADLINE_EXCEEDED` on both sides, so servers stop working on
answers nobody will read.[^grpcconcepts]

### Browsers and load balancers

Browsers give JavaScript no control over HTTP/2 frames and trailers, so they
cannot make gRPC calls directly. **gRPC-Web** is a variant protocol for
browsers, translated into gRPC by a proxy, by default Envoy.[^grpcweb] The
**Connect** project, created by Buf and accepted into the CNCF sandbox in
2024, serves gRPC, gRPC-Web and its own simpler protocol, which also works over
HTTP/1.1, from the same server.[^connect][^connectcncf]

Long-lived HTTP/2 connections also change load balancing. A connection-level
(layer 4) balancer sends all of a client's calls on one connection to the same
backend; the gRPC project recommends balancing individual calls, in a layer 7
proxy or in the client itself.[^grpclb]

**Pros**

- Fast and compact: binary Protobuf messages, multiplexed over one HTTP/2
  connection.
- A strict contract in `.proto` files, with generated, typed clients and
  servers in many languages.
- Streaming in both directions, deadlines, cancellation and well-defined
  status codes built in.

**Cons**

- Not directly usable from browsers; gRPC-Web or Connect and often a proxy
  are needed.
- Binary messages cannot be read or sent with everyday tools such as `curl`
  without the schema and special clients.
- HTTP caching does not apply, and per-call load balancing needs a layer 7
  proxy, a service mesh or client-side balancing.
- A code-generation step and shared `.proto` files couple the build processes
  of client and server.

## GraphQL

### One endpoint, a typed schema, queries chosen by the client

**GraphQL** is a query language for APIs and a runtime that answers those
queries. A server publishes a **schema** of types and fields, and the client
writes a query that names exactly the fields it wants, following links between
types as deep as it needs. There are three kinds of operation: **queries**
read, **mutations** write, and **subscriptions** deliver a stream of
results over time.[^graphqlspec] A schema for the library might be:

```graphql
type Book {
  id: ID!
  title: String!
  author: Author!
  reviews(first: Int = 10): [Review!]!
}

type Author {
  name: String!
  books: [Book!]!
}

type Review {
  stars: Int!
  text: String
}

type Query {
  book(id: ID!): Book
}
```

A client that shows a book with its author's name and the stars of two
reviews asks for exactly that:

```graphql
query {
  book(id: "1") {
    title
    author { name }
    reviews(first: 2) { stars }
  }
}
```

and gets back a JSON response with the same shape as the query:

```json
{
  "data": {
    "book": {
      "title": "Dune",
      "author": { "name": "Frank Herbert" },
      "reviews": [{ "stars": 5 }, { "stars": 4 }]
    }
  }
}
```

A REST client might have needed three requests, to `/books/1`,
`/authors/{id}` and `/books/1/reviews`, and would have received every field of
each. GraphQL fixes both over-fetching and under-fetching, and lets each
client, a web page, a phone app or a watch app, ask for its own shape of data
without the server adding an endpoint for each.

### How it is served

A GraphQL server usually operates on a single URL, often `/graphql`; queries
and mutations are sent with POST, and queries may also be sent with
GET.[^graphqlhttp] The **GraphQL over HTTP** specification, which pins down
these details, was still a working draft in October 2026.[^graphqlhttp]
Every schema can be queried about itself through **introspection** fields such
as `__schema` and `__type`, which is what lets editors offer autocompletion
and tools generate typed clients.[^graphqlspec]

### The costs

Letting clients write queries moves work and risk to the server:

- **The N+1 problem.** A naive server resolves each field separately, so a
  list of 50 books with their authors makes one query for the books and 50
  more for the authors. The standard remedy is a batching layer such as
  **DataLoader**, which collects the 50 lookups and makes one.[^graphqlperf][^dataloader]
- **Caching.** HTTP caches key on URLs, and GraphQL has "no URL-like primitive"
  that identifies an object globally; caching moves into the client, keyed on
  object identifiers, and into the server.[^graphqlcache]
- **Security and cost.** A single query can ask for deeply nested data and
  overwhelm a server. GraphQL's own guidance is to limit query depth and
  analyse query complexity, and to rate-limit clients.[^graphqlsecurity]

**Pros**

- Clients get exactly the data they need in one round trip.
- A strongly typed, introspectable schema with excellent tooling.
- Many clients with different needs can share one API, which evolves by adding
  fields and deprecating old ones instead of versioning endpoints.

**Cons**

- More complex servers: resolvers, batching, query cost limits.
- HTTP caching, status codes and per-URL monitoring do not apply directly.
- Arbitrary queries make performance harder to predict and to secure.
- More machinery than a simple API with one or two clients needs.

## Push: when the server speaks first

HTTP lets only the client start an exchange. Applications that must learn of
events as they happen, a chat message, a finished build, a price change, have
four ways to get them:

{{< diagram src="push.svg" caption="Four ways for a client to learn about events on a server." >}}

### Polling and long polling

**Polling** asks again every few seconds. It is trivial and works everywhere,
but trades latency against wasted requests: most answers say nothing new, and
an event is seen only at the next poll. **Long polling** has the server hold
each request open until it has something to say, or a timeout passes, and the
client sends a new request as soon as it gets an answer. RFC 6202 documents it,
and its problems: header overhead on every message, an extra round trip after
each one, and timeouts in proxies along the way.[^rfc6202]

### Server-sent events

**Server-sent events (SSE)** keep one HTTP response open and write events into
it as they happen, in a simple text format with the media type
`text/event-stream`. Each event is a few `field: value` lines, `event`,
`data`, `id` and `retry`, ended by a blank line.[^sse] Browsers read them with
the `EventSource` API, which reconnects automatically and sends the last event
ID it saw in a `Last-Event-ID` header, so the server can resume where it left
off.[^sse] This server reports a build's progress, and the client prints each
line as it arrives:

```python
import http.client, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Events(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        for n in range(1, 4):
            self.wfile.write(f'id: {n}\nevent: progress\ndata: {{"percent": {n * 25}}}\n\n'.encode())
            self.wfile.flush()
            time.sleep(0.2)

    def log_message(self, *args):
        pass

server = ThreadingHTTPServer(("127.0.0.1", 0), Events)
threading.Thread(target=server.serve_forever, daemon=True).start()
conn = http.client.HTTPConnection(*server.server_address)
conn.request("GET", "/builds/7/events", headers={"Accept": "text/event-stream"})
response = conn.getresponse()
print(response.status, response.getheader("Content-Type"))
start = time.perf_counter()
while line := response.readline():
    print(f"{time.perf_counter() - start:4.1f}s  {line.decode().rstrip()!r}")
server.shutdown()
```

```txt
200 text/event-stream
 0.0s  'id: 1'
 0.0s  'event: progress'
 0.0s  'data: {"percent": 25}'
 0.0s  ''
 0.2s  'id: 2'
 0.2s  'event: progress'
 0.2s  'data: {"percent": 50}'
 0.2s  ''
 0.4s  'id: 3'
 0.4s  'event: progress'
 0.4s  'data: {"percent": 75}'
 0.4s  ''
```

The events arrived 0.2 seconds apart, as they were written, on one response.
SSE is plain HTTP, so it passes through proxies and works with existing
authentication. It is one-way only, and its data is text. Over HTTP/1.1,
browsers allow only six connections per domain, which open event streams
use up; over HTTP/2 the streams share one connection.[^mdnsse]

### WebSocket

A **WebSocket** connection starts as an HTTP request with an `Upgrade:
websocket` header. If the server agrees, it answers `101 Switching Protocols`
and the TCP connection becomes a two-way channel of **frames**, carrying text
or binary messages in either direction at any time.[^websocket] The server
proves that it really understood the WebSocket handshake, and is not some
unrelated service, by hashing the client's random `Sec-WebSocket-Key` with a
fixed GUID and returning the result in `Sec-WebSocket-Accept`. Using the
example key from the RFC:

```python
import base64, hashlib

key = "dGhlIHNhbXBsZSBub25jZQ=="                     # the example key from RFC 6455
magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
print(base64.b64encode(hashlib.sha1((key + magic).encode()).digest()).decode())
```

```txt
s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

That is the value given in RFC 6455.[^websocket] Frames from client to server
are **masked** with a random key, which stops a malicious page from making the
browser send bytes that a confused proxy along the way could mistake for
something else.[^websocket] WebSocket can also run over HTTP/2 and
HTTP/3.[^ws2][^ws3]

What WebSocket does not give is anything above the frames: no request IDs,
no error codes, no reconnection, no message types. Applications define their
own protocol on top, and JSON-RPC is a common choice.

### Webhooks

Between servers, the usual way to push is a **webhook**: the receiver
registers a URL, and when an event happens the sender makes an HTTP POST to
it. Payment providers, source code hosts and chat platforms all notify their
customers' systems this way. Because anyone can POST to a URL, webhooks are
signed: the **Standard Webhooks** specification, for example, has the sender
put a message ID, a timestamp and an HMAC-SHA256 signature of the ID,
timestamp and body in the headers, so the receiver can verify the sender and
reject replays.[^standardwebhooks] Senders retry failed deliveries, so
receivers must expect duplicates and process each message ID once.

**Pros and cons of the push techniques**

| | Direction | Strengths | Weaknesses |
|---|---|---|---|
| Polling | Client pulls | Works everywhere; trivial | Latency or wasted requests, usually both |
| Long polling | Server responds when ready | Works over any HTTP | Overhead per message; proxy timeouts[^rfc6202] |
| SSE | Server to client | Plain HTTP; automatic reconnection and resume | One-way; text only; connection limit on HTTP/1.1[^mdnsse] |
| WebSocket | Both ways | Low overhead, true two-way, binary | No built-in semantics; stateful connections are harder to scale and balance |
| Webhooks | Server to server | Simple POSTs; no open connection | Receiver must be publicly reachable; must verify signatures and handle retries |

## Messaging

### Brokers and the shapes of delivery

In everything so far, the sender talks to the receiver directly, and both
must be up at the same moment. **Messaging** puts a **broker** in between. A
producer sends a message to the broker and moves on; the broker stores it; a
consumer receives it when it is ready. Producer and consumer need not know
each other, run at the same time or run at the same speed. *Enterprise
Integration Patterns*, the standard catalogue of the field, names the basic
shapes:[^eip]

{{< diagram src="messaging.svg" caption="Three shapes of asynchronous messaging." >}}

- A **point-to-point channel**, or **queue**, delivers each message to exactly
  one of the consumers reading it, which spreads work across competing
  workers.[^eipp2p]
- A **publish-subscribe channel**, or **topic**, delivers a copy of each
  message to every subscriber, so new consumers can be added without changing
  the producer.[^eippubsub]
- A **log**, Kafka's model, appends messages to a durable, ordered sequence and
  keeps them after they are read. Each consumer group tracks its own
  position, its **offset**, so it can read at its own pace, and replay history
  by moving back.[^kafkadocs]

### AMQP, MQTT and Kafka

The three most widely used protocols reflect three different settings:

- **AMQP** is a wire protocol for business messaging between applications.
  Version 1.0 became an OASIS standard in October 2012.[^amqp] RabbitMQ, one
  of the best-known brokers, was originally built around the earlier AMQP
  0-9-1, whose **exchanges** route messages into **queues**, and made AMQP 1.0
  a core protocol in version 4.0.[^rabbitmq]
- **MQTT** is a lightweight publish-subscribe protocol for constrained
  environments, where code must be small or bandwidth is scarce. Clients publish to and subscribe to hierarchical
  **topics** such as `plant/3/boiler/temperature` through a broker, and each
  message is sent with a **quality of service**: 0, at most once; 1, at least
  once; or 2, exactly once.[^mqtt5] The current version, MQTT 5.0, became an
  OASIS standard in 2019.[^mqtt5]
- **Kafka** is a distributed log. A **topic** is split into **partitions**
  spread across servers, and a consumer of a partition always reads its
  events in the order they were written; there is no order across
  partitions.[^kafkaintro] Within a consumer group, each partition is read by
  exactly one consumer at a time, which is how a group shares the
  work.[^kafkadocs] Events "are not deleted after consumption" but kept for a
  configured retention period,[^kafkaintro] which makes Kafka a common
  backbone for event streams, data pipelines and services that rebuild their
  state by replaying history. Since version 4.0, in 2025, Kafka runs without
  Apache ZooKeeper.[^kafka4]

### Delivery guarantees

A broker and a consumer face the same partial-failure problem as RPC. If a
consumer processes a message and crashes before **acknowledging** it, the
broker cannot tell whether the work was done. Systems choose between three
guarantees: **at most once** (messages may be lost, never repeated), **at
least once** (never lost, but possibly repeated) and **exactly once**. Kafka,
for example, provides exactly-once delivery when reading, processing and
writing data on its own topics with transactions, and notes that exactly once
with other systems "generally requires cooperation with such
systems".[^kafkadocs] In practice most systems deliver at least once, and
consumers are made **idempotent**: they recognise a message they have already
processed and skip it.[^eipidempotent] This toy broker shows why:

```python
from collections import deque

class Broker:
    """A toy queue with at-least-once delivery: a message is removed only when acked."""
    def __init__(self):
        self.ready, self.unacked = deque(), {}

    def publish(self, message_id, body):
        self.ready.append((message_id, body))

    def deliver(self):
        message_id, body = self.ready.popleft()
        self.unacked[message_id] = body
        return message_id, body

    def ack(self, message_id):
        del self.unacked[message_id]

    def consumer_died(self):            # unacknowledged messages go back on the queue
        self.ready.extendleft(reversed(self.unacked.items()))
        self.unacked.clear()

broker, charged, seen = Broker(), [], set()
broker.publish("order-1", {"customer": "ana", "amount": 30})
broker.publish("order-2", {"customer": "bo", "amount": 12})

def consume(crash_before_ack=False, idempotent=True):
    message_id, body = broker.deliver()
    if idempotent and message_id in seen:
        print(f"skip   {message_id} (already processed)")
    else:
        charged.append(body["amount"]); seen.add(message_id)
        print(f"charge {message_id}: {body['amount']}")
    if crash_before_ack:
        print("       consumer crashed before acknowledging")
        broker.consumer_died()
    else:
        broker.ack(message_id)

consume(crash_before_ack=True)   # does the work, dies before the ack
consume()                         # the broker redelivers order-1
consume()
print("total charged:", sum(charged))
```

```txt
charge order-1: 30
       consumer crashed before acknowledging
skip   order-1 (already processed)
charge order-2: 12
total charged: 42
```

Without the check, `order-1` would have been charged twice. In a real system,
the record of processed IDs must be stored durably, ideally in the same
database transaction as the work itself; an in-memory set, as here, would be
lost in the crash it is meant to survive.

Two specifications help messages travel between systems: **CloudEvents**
defines common metadata for events, an `id`, a `source`, a `type` and a
`specversion`, independent of the broker or protocol,[^cloudevents] and
**AsyncAPI** does for message-driven APIs what OpenAPI does for HTTP ones.[^asyncapi]

**Pros**

- Decouples producers and consumers in time, place and speed: either side can
  be down, slow or replaced.
- Absorbs bursts, spreads work over many workers and lets new consumers
  subscribe without changing producers.
- Logs keep history that can be replayed to rebuild state or feed new
  systems.

**Cons**

- A broker to run, secure and monitor, which becomes critical infrastructure.
- No immediate answer: request-response over messaging needs reply queues and
  correlation IDs.
- Duplicates and reordering must be handled by consumers; eventual
  consistency is harder to reason about and to debug than a call stack.

## Comparing them

### Side by side

| | REST | JSON-RPC | gRPC | GraphQL | SOAP | WebSocket / SSE | Messaging |
|---|---|---|---|---|---|---|---|
| Model | Resources and standard methods | Named procedures | Named procedures and streams | Client-written queries over a typed graph | Named operations in envelopes | Open channel | Messages through a broker |
| Typical format | JSON | JSON | Protobuf | JSON | XML | Any (often JSON) | Any (JSON, Protobuf, Avro) |
| Transport | HTTP | Any | HTTP/2 | HTTP (WebSocket for subscriptions) | HTTP, others | HTTP upgrade or stream | AMQP, MQTT, Kafka's protocol |
| Contract | Optional (OpenAPI) | None standard | Required (`.proto`) | Required (schema) | Required (WSDL) | None | Optional (AsyncAPI, schema registry) |
| Coupling in time | Synchronous | Synchronous | Synchronous | Synchronous | Synchronous | Live connection | Asynchronous |
| Server push | No | Over a two-way transport | Streaming | Subscriptions | No | Yes | Yes |
| HTTP caching | Yes | No | No | Limited | No | No | Not applicable |
| Browser support | Native | Native | Via gRPC-Web or Connect | Native | Possible, rare | Native | Via a gateway |
| Payload size and speed | Medium | Medium | Small, fast | Medium | Large | Depends on format | Depends on format |
| Debuggability | Excellent | Good | Needs tools | Good, with tools | Fair | Fair | Hard (asynchronous) |
| Best at | Public and web APIs | Tool and editor protocols | Internal service calls, streaming | Many clients with varied data needs | Legacy and enterprise integration | Live updates and two-way sessions | Background work, events, integration |

### The same request, five ways

Fetching book 1 makes the differences concrete:

```txt
REST       GET /books/1
           Accept: application/json

JSON-RPC   POST /rpc
           {"jsonrpc": "2.0", "method": "getBook", "params": {"id": 1}, "id": 7}

gRPC       POST /library.v1.Library/GetBook          (HTTP/2)
           content-type: application/grpc+proto
           00 00 00 00 02  08 01

GraphQL    POST /graphql
           {"query": "{ book(id: \"1\") { title author { name } } }"}

Messaging  publish to queue "book-requests":
           {"id": 1, "replyTo": "client-42-replies", "correlationId": "c-7"}
```

REST names the *thing* in the URL and the *action* in the method; JSON-RPC and
gRPC name the *action*, and gRPC does so in a compact, typed message; GraphQL
names the *shape of the answer*; messaging needs its own machinery,
a reply queue and a correlation ID, merely to get an answer back, which is a
sign that a lookup like this is not what messaging is for.

## How to choose

### Questions to ask first

1. **Who are the clients?** Browsers, partners and the public favour REST, or
   GraphQL; your own services in your own languages make gRPC attractive.
2. **Does the caller need an answer now?** If not, a message on a queue or a
   log decouples the systems and survives the receiver being down.
3. **Does data need to flow from server to client as it happens?** SSE for
   one-way updates, WebSocket for two-way, webhooks between organisations.
4. **How varied are the clients' needs?** Many clients with very different
   views of the same data are what GraphQL was built for; one or two clients
   rarely justify it.
5. **How much traffic, and how sensitive to latency?** Heavy internal traffic
   rewards binary formats and multiplexed connections.
6. **What do the team and the existing systems already speak?** Consistency
   across an organisation is worth more than a marginally better fit for one
   API.

### A decision chart

{{< diagram src="decision.svg" caption="A starting point, not a verdict. Most real systems combine several of these." >}}

### Scenarios

| Situation | A good default | Why |
|---|---|---|
| A public API for third-party developers | REST with JSON and OpenAPI | Universally understood; works with every tool; cacheable |
| Calls between microservices inside one company | gRPC | Typed contracts, small fast messages, deadlines, streaming |
| A web and mobile app with many screens over the same data | GraphQL, or REST with purpose-built endpoints for each client | Each screen fetches exactly its data in one round trip |
| A live dashboard, notifications or build logs in a browser | SSE | One-way push over plain HTTP, with reconnection |
| Chat, collaborative editing, multiplayer games | WebSocket | Low-latency messages in both directions |
| Notifying customers' systems of events | Webhooks, signed | Simple HTTP POSTs to the receiver's URL |
| Background jobs: emails, image processing, reports | A queue (AMQP, a cloud queue) | Work survives crashes and spreads over workers |
| Many services reacting to business events; data pipelines | A log such as Kafka | Durable, ordered, replayable events for any number of consumers |
| Sensors and devices on poor networks | MQTT | Tiny overhead, publish-subscribe, quality-of-service levels |
| An editor, IDE or AI agent talking to tools | JSON-RPC (as in LSP and MCP) | Simple, symmetric, transport-independent |
| Integrating with an existing bank, government or telecom system | Whatever it speaks, often SOAP | The other side decides |

### Combining them

Real systems mix techniques, each where it fits. A typical arrangement puts
REST or GraphQL at the edge, where browsers and partners connect; gRPC between
the internal services behind it; a log or queue for everything that can happen
later; SSE or WebSocket for live updates to the user interface; and webhooks
for telling other companies' systems what happened. The format follows from
the style more often than it is chosen on its own: JSON where people and
browsers are involved, Protobuf or Avro where machines talk to machines at
volume.

### Rules that apply whatever you choose

- **Set timeouts and deadlines** on every remote call. A call without one can
  wait forever.[^fallacies]
- **Retry only what is idempotent**, and make important operations idempotent,
  for example with a client-chosen request or message ID, so they can be
  retried safely.[^http][^eipidempotent]
- **Plan for evolution.** Add fields instead of changing them; never reuse a
  Protobuf field number; tolerate unknown fields; version only when a change
  cannot be made compatible.[^ddia][^pbdonts]
- **Use a contract**, whether OpenAPI, `.proto` files, a GraphQL schema or
  AsyncAPI, and generate from it what you can.
- **Treat every input as untrusted**: limit sizes and nesting, disable XML
  entities, verify webhook signatures, and limit the cost of GraphQL
  queries.[^owaspxxe][^standardwebhooks][^graphqlsecurity]

## Why it matters

Nearly every program of any size talks to another, and the way it does so
shapes the rest of the system: how fast it is, what fails when one part goes
down, how teams can change their services without breaking one another, and
how much of the network's unreliability leaks into the code. None of these
techniques is best. REST trades efficiency for reach, gRPC trades reach for
efficiency, GraphQL trades server simplicity for client freedom, and messaging
trades immediacy for resilience. Knowing what each one trades, and that a
remote call is never really a local one, is what lets a programmer pick the
right one, and use it well.

## References

[^ddia]: Kleppmann, M. (2017). Encoding and evolution. In *Designing data-intensive applications* (ch. 4). O'Reilly Media. <https://www.oreilly.com/library/view/designing-data-intensive-applications/9781491903063/>

[^rfc707]: White, J. E. (1975). *A high-level framework for network-based resource sharing* (RFC 707). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0707>

[^birrell]: Birrell, A. D., & Nelson, B. J. (1984). Implementing remote procedure calls. *ACM Transactions on Computer Systems*, 2(1), 39–59. <https://doi.org/10.1145/2080.357392>

[^rfc1014]: Sun Microsystems. (1987). *XDR: External Data Representation standard* (RFC 1014, obsoleted by RFC 4506). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1014>

[^rfc1057]: Sun Microsystems. (1988). *RPC: Remote Procedure Call protocol specification version 2* (RFC 1057, obsoleted by RFC 5531). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1057>

[^rfc1094]: Nowicki, B. (1989). *NFS: Network File System protocol specification* (RFC 1094). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1094>

[^rfc5531]: Thurlow, R. (2009). *RPC: Remote Procedure Call protocol specification version 2* (RFC 5531). Internet Engineering Task Force. <https://doi.org/10.17487/RFC5531>

[^henning]: Henning, M. (2006). The rise and fall of CORBA. *ACM Queue*, 4(5). <https://doi.org/10.1145/1142031.1142044>

[^waldo]: Waldo, J., Wyant, G., Wollrath, A., & Kendall, S. (1994). *A note on distributed computing* (SMLI TR-94-29). Sun Microsystems Laboratories. <https://web.archive.org/web/20090717005030/http://research.sun.com/techrep/1994/smli_tr-94-29.pdf>

[^xml]: W3C. (2008). *Extensible Markup Language (XML) 1.0* (5th ed., W3C Recommendation; first edition 10 February 1998). <https://www.w3.org/TR/xml/>

[^xmlrpc]: Winer, D. (1999). *XML-RPC specification*. UserLand Software. <http://xmlrpc.com/spec.md>

[^soap11]: W3C. (2000). *Simple Object Access Protocol (SOAP) 1.1* (W3C Note). <https://www.w3.org/TR/2000/NOTE-SOAP-20000508/>

[^soap12]: W3C. (2007). *SOAP version 1.2 part 1: Messaging framework* (2nd ed., W3C Recommendation; first edition 24 June 2003). <https://www.w3.org/TR/2007/REC-soap12-part1-20070427/>

[^wsdl11]: W3C. (2001). *Web Services Description Language (WSDL) 1.1* (W3C Note). <https://www.w3.org/TR/2001/NOTE-wsdl-20010315>

[^fielding]: Fielding, R. T. (2000). Representational state transfer (REST). In *Architectural styles and the design of network-based software architectures* (ch. 5) [Doctoral dissertation, University of California, Irvine]. <https://ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm>

[^fatfree]: Crockford, D. (n.d.). *JSON: The fat-free alternative to XML*. JSON.org. <https://www.json.org/fatfree.html>

[^saga]: Amundsen, M. (Transcriber). (n.d.). *The JSON saga* [Unofficial transcript of a 2011 talk by D. Crockford]. <https://mamund.site44.com/rwcbook/the-json-saga/index.html>

[^rfc4627]: Crockford, D. (2006). *The application/json media type for JavaScript Object Notation (JSON)* (RFC 4627, obsoleted by RFC 7159 and then RFC 8259). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4627>

[^jsonrpc1]: JSON-RPC Working Group. (2005). *JSON-RPC 1.0 specification*. <https://www.jsonrpc.org/specification_v1>

[^jsonrpc]: JSON-RPC Working Group. (2013). *JSON-RPC 2.0 specification* (originally published 2010-03-26). <https://www.jsonrpc.org/specification>

[^oaspress]: Linux Foundation. (2015, November 5). *New collaborative project to extend Swagger specification for building connected applications and services* [Press release]. <https://www.linuxfoundation.org/press/press-release/new-collaborative-project-to-extend-swagger-specification-for-building-connected-applications-and-services>

[^oas]: OpenAPI Initiative. (2026). *OpenAPI specification v3.2.1*. <https://spec.openapis.org/oas/v3.2.1.html>

[^thrift]: Slee, M., Agarwal, A., & Kwiatkowski, M. (2007). *Thrift: Scalable cross-language services implementation* [White paper]. Facebook. <https://thrift.apache.org/static/files/thrift-20070401.pdf>

[^pbblog]: Varda, K. (2008, July 7). Protocol Buffers: Google's data interchange format. *Google Open Source Blog*. <https://opensource.googleblog.com/2008/07/protocol-buffers-googles-data.html>

[^avroreleases]: Apache Software Foundation. (n.d.). *Apache Avro releases*. <https://svn.apache.org/repos/asf/avro/site/publish/releases.html>

[^grpcprinciples]: Ryan, L. (2015, September 8). gRPC motivation and design principles. *gRPC Blog*. <https://grpc.io/blog/principles/>

[^grpcannounce]: Marculescu, M. (2015, February 26). Introducing gRPC, a new open source HTTP/2 RPC framework. *Google Developers Blog*. <https://developers.googleblog.com/2015/02/introducing-grpc-new-open-source-http2.html>

[^grpc10]: Talwar, V. (2016, August 23). gRPC: A true internet-scale RPC framework is now 1.0 and ready for production deployments. *Google Cloud Blog*. <https://cloud.google.com/blog/products/gcp/grpc-a-true-internet-scale-rpc-framework-is-now-1-and-ready-for-production-deployments/>

[^grpccncf]: Woods, N. (2017, March 1). Cloud Native Computing Foundation to host gRPC from Google. *CNCF Blog*. <https://www.cncf.io/blog/2017/03/01/cloud-native-computing-foundation-host-grpc-google/>

[^graphqlblog]: Byron, L. (2015, September 14). GraphQL: A data query language. *Engineering at Meta*. <https://engineering.fb.com/2015/09/14/core-infra/graphql-a-data-query-language/>

[^graphqlfoundation]: GraphQL Foundation. (2018, November 6). The Linux Foundation announces intent to form new foundation to support GraphQL. <https://graphql.org/blog/2018-11-06-linux-foundation-graphql/>

[^graphqlspec]: GraphQL Foundation. (2025). *GraphQL specification* (September 2025 ed.). <https://spec.graphql.org/September2025/>

[^rfc6202]: Loreto, S., Saint-Andre, P., Salsano, S., & Wilkins, G. (2011). *Known issues and best practices for the use of long polling and streaming in bidirectional HTTP* (RFC 6202). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6202>

[^websocket]: Fette, I., & Melnikov, A. (2011). *The WebSocket protocol* (RFC 6455). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6455>

[^sse]: WHATWG. (n.d.). Server-sent events. In *HTML Living Standard*. <https://html.spec.whatwg.org/multipage/server-sent-events.html>

[^amqp]: Godfrey, R., Ingham, D., & Schloming, R. (Eds.). (2012). *OASIS Advanced Message Queuing Protocol (AMQP) version 1.0* (OASIS Standard). OASIS. <https://docs.oasis-open.org/amqp/core/v1.0/os/amqp-core-overview-v1.0-os.html>

[^mqttfaq]: MQTT.org. (n.d.). *Frequently asked questions*. <https://mqtt.org/faq/>

[^kafkapaper]: Kreps, J., Narkhede, N., & Rao, J. (2011). Kafka: A distributed messaging system for log processing. *Proceedings of the NetDB Workshop*. <https://people.csail.mit.edu/matei/courses/2015/6.S897/readings/kafka.pdf>

[^postman]: Postman. (2025). *2025 state of the API report*. <https://www.postman.com/state-of-api/2025/>

[^lsp]: Microsoft. (n.d.). *Language Server Protocol specification 3.18*. <https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/>

[^ethereum]: Ethereum Foundation. (n.d.). *JSON-RPC API*. ethereum.org. <https://ethereum.org/en/developers/docs/apis/json-rpc/>

[^mcp]: Model Context Protocol. (2026). *Specification* (revision 2026-07-28). <https://modelcontextprotocol.io/specification/2026-07-28>

[^json]: Bray, T. (Ed.). (2017). *The JavaScript Object Notation (JSON) data interchange format* (RFC 8259). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8259>

[^ecma404]: Ecma International. (2017). *The JSON data interchange syntax* (ECMA-404, 2nd ed.). <https://ecma-international.org/publications-and-standards/standards/ecma-404/>

[^ijson]: Bray, T. (Ed.). (2015). *The I-JSON message format* (RFC 7493). Internet Engineering Task Force. <https://doi.org/10.17487/RFC7493>

[^jsonschema]: JSON Schema. (n.d.). *Specification*. <https://json-schema.org/specification>

[^xmlns]: W3C. (2009). *Namespaces in XML 1.0* (3rd ed., W3C Recommendation). <https://www.w3.org/TR/xml-names/>

[^xsd]: Gao, S., Sperberg-McQueen, C. M., & Thompson, H. S. (Eds.). (2012). *W3C XML Schema Definition Language (XSD) 1.1 part 1: Structures* (W3C Recommendation). <https://www.w3.org/TR/xmlschema11-1/>

[^pyxml]: Python Software Foundation. (n.d.). XML processing modules: XML security. In *Python 3.14 documentation*. <https://docs.python.org/3.14/library/xml.html#xml-security>

[^owaspxxe]: OWASP Foundation. (n.d.). *XML external entity prevention cheat sheet*. OWASP Cheat Sheet Series. <https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html>

[^pbencoding]: Google. (n.d.). Encoding. In *Protocol Buffers documentation*. <https://protobuf.dev/programming-guides/encoding/>

[^pboverview]: Google. (n.d.). Overview. In *Protocol Buffers documentation*. <https://protobuf.dev/overview/>

[^pbdonts]: Google. (n.d.). Proto best practices. In *Protocol Buffers documentation*. <https://protobuf.dev/best-practices/dos-donts/>

[^pbeditions]: Google. (n.d.). Feature settings for editions. In *Protocol Buffers documentation*. <https://protobuf.dev/editions/overview/>

[^msgpack]: Furuhashi, S., et al. (n.d.). *MessagePack specification*. GitHub. <https://github.com/msgpack/msgpack/blob/master/spec.md>

[^cbor]: Bormann, C., & Hoffman, P. (2020). *Concise Binary Object Representation (CBOR)* (RFC 8949). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8949>

[^avro]: Apache Software Foundation. (n.d.). Specification. In *Apache Avro documentation* (v1.12.0). <https://avro.apache.org/docs/1.12.0/specification/>

[^fallacies]: Rotem-Gal-Oz, A. (n.d.). *Fallacies of distributed computing explained* [Archived]. <http://web.archive.org/web/20070929150539/http://www.rgoarchitects.com/Files/fallacies.pdf>

[^pyxmlrpc]: Python Software Foundation. (n.d.). xmlrpc.client: XML-RPC client access. In *Python 3.14 documentation*. <https://docs.python.org/3.14/library/xmlrpc.client.html>

[^http]: Fielding, R. (Ed.), Nottingham, M. (Ed.), & Reschke, J. (Ed.). (2022). *HTTP semantics* (RFC 9110). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9110>

[^patch]: Dusseault, L., & Snell, J. (2010). *PATCH method for HTTP* (RFC 5789). Internet Engineering Task Force. <https://doi.org/10.17487/RFC5789>

[^problem]: Nottingham, M., Wilde, E., & Dalal, S. (2023). *Problem details for HTTP APIs* (RFC 9457). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9457>

[^caching]: Fielding, R. (Ed.), Nottingham, M. (Ed.), & Reschke, J. (Ed.). (2022). *HTTP caching* (RFC 9111). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9111>

[^fielding2008]: Fielding, R. T. (2008, October 20). *REST APIs must be hypertext-driven*. Untangled. <https://roy.gbiv.com/untangled/2008/rest-apis-must-be-hypertext-driven>

[^fowler]: Fowler, M. (2010, March 18). *Richardson maturity model*. martinfowler.com. <https://martinfowler.com/articles/richardsonMaturityModel.html>

[^grpcconcepts]: gRPC Authors. (n.d.). Core concepts, architecture and lifecycle. In *gRPC documentation*. <https://grpc.io/docs/what-is-grpc/core-concepts/>

[^grpchttp2]: gRPC Authors. (n.d.). *gRPC over HTTP2*. GitHub. <https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md>

[^grpcstatus]: gRPC Authors. (n.d.). Status codes and their use in gRPC. In *gRPC documentation*. <https://grpc.io/docs/guides/status-codes/>

[^grpcweb]: gRPC Authors. (n.d.). *grpc-web* [README]. GitHub. <https://github.com/grpc/grpc-web>

[^connect]: Buf Technologies. (n.d.). Introduction. In *Connect documentation*. <https://connectrpc.com/docs/introduction/>

[^connectcncf]: Cloud Native Computing Foundation. (n.d.). *Connect RPC*. <https://www.cncf.io/projects/connect-rpc/>

[^grpclb]: gRPC Authors. (2017, June 15). gRPC load balancing. *gRPC Blog*. <https://grpc.io/blog/grpc-load-balancing/>

[^graphqlhttp]: GraphQL Foundation. (n.d.). Serving over HTTP. In *GraphQL documentation*. <https://graphql.org/learn/serving-over-http/>

[^graphqlperf]: GraphQL Foundation. (n.d.). Performance. In *GraphQL documentation*. <https://graphql.org/learn/performance/>

[^dataloader]: GraphQL Foundation. (n.d.). *DataLoader*. GitHub. <https://github.com/graphql/dataloader>

[^graphqlcache]: GraphQL Foundation. (n.d.). Caching. In *GraphQL documentation*. <https://graphql.org/learn/caching/>

[^graphqlsecurity]: GraphQL Foundation. (n.d.). Security. In *GraphQL documentation*. <https://graphql.org/learn/security/>

[^mdnsse]: MDN contributors. (n.d.). EventSource. In *MDN Web Docs*. <https://developer.mozilla.org/en-US/docs/Web/API/EventSource>

[^ws2]: McManus, P. (2018). *Bootstrapping WebSockets with HTTP/2* (RFC 8441). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8441>

[^ws3]: Hamilton, R. (2022). *Bootstrapping WebSockets with HTTP/3* (RFC 9220). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9220>

[^standardwebhooks]: Standard Webhooks. (n.d.). *Standard Webhooks specification* (version 1.0.0). GitHub. <https://github.com/standard-webhooks/standard-webhooks/blob/main/spec/standard-webhooks.md>

[^eip]: Hohpe, G., & Woolf, B. (2003). *Enterprise integration patterns: Designing, building, and deploying messaging solutions*. Addison-Wesley. <https://www.enterpriseintegrationpatterns.com/>

[^eipp2p]: Hohpe, G., & Woolf, B. (n.d.). Point-to-point channel. In *Enterprise integration patterns*. <https://www.enterpriseintegrationpatterns.com/patterns/messaging/PointToPointChannel.html>

[^eippubsub]: Hohpe, G., & Woolf, B. (n.d.). Publish-subscribe channel. In *Enterprise integration patterns*. <https://www.enterpriseintegrationpatterns.com/patterns/messaging/PublishSubscribeChannel.html>

[^eipidempotent]: Hohpe, G., & Woolf, B. (n.d.). Idempotent receiver. In *Enterprise integration patterns*. <https://www.enterpriseintegrationpatterns.com/patterns/messaging/IdempotentReceiver.html>

[^kafkadocs]: Apache Software Foundation. (n.d.). Design. In *Apache Kafka documentation* (4.3). <https://kafka.apache.org/43/design/design/>

[^kafkaintro]: Apache Software Foundation. (n.d.). Introduction. In *Apache Kafka documentation*. <https://kafka.apache.org/intro>

[^kafka4]: Jacot, D. (2025, March 18). Apache Kafka 4.0.0 release announcement. *Apache Kafka Blog*. <https://kafka.apache.org/blog/2025/03/18/apache-kafka-4.0.0-release-announcement/>

[^rabbitmq]: RabbitMQ. (n.d.). Which protocols does RabbitMQ support? In *RabbitMQ documentation*. <https://www.rabbitmq.com/docs/protocols>

[^mqtt5]: Banks, A., Briggs, E., Borgendale, K., & Gupta, R. (Eds.). (2019). *MQTT version 5.0* (OASIS Standard). OASIS. <https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html>

[^cloudevents]: CloudEvents. (n.d.). *CloudEvents specification* (v1.0.2). <https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md>

[^asyncapi]: AsyncAPI Initiative. (2026). *AsyncAPI specification* (version 3.1.0). <https://www.asyncapi.com/docs/reference/specification/v3.1.0>

[^omgcorba]: Object Management Group. (n.d.). *History of CORBA*. <https://www.omg.org/gettingstarted/history_of_corba.htm>

[^dcom]: Microsoft. (1996, September 18). *Microsoft releases beta version of DCOM for Windows 95* [Press release]. <https://news.microsoft.com/?p=9361>

[^rmi]: Oracle. (n.d.). Interface Remote. In *Java Platform, Standard Edition 8 API specification*. <https://docs.oracle.com/javase/8/docs/api/java/rmi/Remote.html>

[^lindsay]: Lindsay, J. (2007, May 3). Web hooks to revolutionize the web. *Progrium* [Archived]. <https://web.archive.org/web/20180630220036/http://progrium.com/blog/2007/05/03/web-hooks-to-revolutionize-the-web/>
