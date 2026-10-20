---
title: "How Do Computer Networks Work? TCP/IP, the OSI Model and the Protocols Every Programmer Uses"
description: "Almost every program talks to another one over a network. Here is how that works: packet switching and its history, the OSI and TCP/IP models, Ethernet, IP addresses and routing, NAT and IPv6, UDP, TCP and QUIC, DNS, HTTP and TLS, the sockets API, latency and bandwidth, security, and the tools for finding out what is going on."
date: 2026-10-20T18:00:00Z
categories: ["Fundamentals"]
tags: ["Networking", "TCP/IP", "OSI Model", "Protocols", "Computer Science", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Very few programs work alone. A web page fetches data from an API, the API
queries a database on another machine, the database replicates to a third, and
all of them ask a time server what time it is and a name server where everyone
else lives. Every one of those conversations crosses a network, and every one
of them can be slow, fail halfway or arrive in pieces. A programmer who
understands what happens between `connect()` and the reply can tell a DNS
problem from a TLS problem from a congested link, and can write code that
copes with all three.

This article builds that understanding from the bottom up: what a network is
and where the Internet came from, the layered models used to describe it, and
then each layer in turn, from frames on a cable to HTTP requests, ending with
the programming interface, performance, security and tools. It complements
[How Does a Web Browser Work?]({{< ref "how-browsers-work" >}}), which follows
one page load through the browser, and
[What Is an Operating System?]({{< ref "operating-systems" >}}), which
describes the kernel where most of the networking stack lives. The Python
examples were run with Python 3.14 on Windows 11, and the packet capture with
tcpdump 4.99 and Python 3.10 on Ubuntu 22.04 under WSL 2; their output is shown
as printed.

## What a network is

**A computer network is a set of computers connected by links so that they can
exchange data, and a protocol is the agreed set of rules for that exchange:
the format of the messages, their order, and what each side does on receiving
one.**[^parch] The machines at the edges, the laptops, phones and servers
that run applications, are called **hosts**. The devices in between forward
data on behalf of others: **switches** within one local network, and
**routers** between networks.[^preq]

### Packet switching

The telephone network was built on **circuit switching**: placing a call
reserved a path through the exchanges for its whole length, used or not.
Computer networks instead use **packet switching**. Data is cut into small,
self-contained **packets**, each carrying its destination address, and every
router forwards each packet independently, sharing links with everyone
else's.[^preq]

Packet switching was proposed in the early 1960s by Paul Baran at RAND, who was
looking for a communications network that could survive the loss of many of its
nodes,[^baran] and independently by Donald Davies at the UK's National Physical
Laboratory, who designed his system in 1965 and gave the packet its
name.[^davies][^ethwpacket] It wastes no capacity on idle conversations, and a
network of many paths can route around a failure. The price is that nothing is
guaranteed: packets can be delayed when links are busy, dropped when a router's
queue overflows, duplicated or delivered out of order. Much of networking, as
the rest of this article shows, is about building reliable conversations on top
of that unreliable delivery.

### A network of networks

The **Internet** is not one network but a great many independently run
networks, belonging to broadband providers, universities, companies and
clouds, that carry one another's packets using one common protocol, IP. Any
set of networks joined this way is an *internet*; the capitalised Internet is
the global one.[^preq] The idea of connecting networks that may each work
differently, through "black boxes" that would later be called gateways and
routers, was introduced by Bob Kahn in 1972 and worked out with Vint Cerf in
1974.[^leiner][^cerfkahn]

## A short history

### From ARPANET to TCP/IP

The US Advanced Research Projects Agency's **ARPANET** connected its first
nodes in 1969; the first message was sent from UCLA to the Stanford Research
Institute on 29 October that year.[^leiner][^lo] Its host protocol, NCP,
relied on the ARPANET itself for reliability and could not address machines
beyond it.[^leiner] As packet radio and satellite networks appeared alongside
it, Kahn and Cerf designed a protocol for
connecting different networks, published in May 1974 as *A Protocol for
Packet Network Intercommunication*.[^cerfkahn] Their single Transmission
Control Program was later split in two: **IP**, which only moves packets
between networks, and **TCP**, which adds reliability on top, with **UDP**
added for applications that did not want TCP's guarantees.[^leiner] IPv4 and
TCP were specified in RFC 791 and RFC 793 in September 1981.[^ipv4][^rfc793]

On **1 January 1983** the ARPANET switched from NCP to TCP/IP in a single
planned cut-over.[^ncptcp][^leiner] The same year, 4.2BSD Unix shipped with
TCP/IP and the **sockets** interprocess communication interface, whose
descendants almost every operating system still offers,[^bsd][^ipc] and the
Domain Name System was first specified.[^rfc882][^leiner] The National Science
Foundation's NSFNET program, from 1985, made TCP/IP mandatory for the
university networks it funded, and its backbone carried American research
traffic until it was defunded in April 1995, when the regional networks
turned to private long-haul networks instead.[^leiner]

### Growing pains

Growth exposed weaknesses. In October 1986 the network between Lawrence
Berkeley Laboratory and UC Berkeley, 400 yards apart, slowed from 32 kbit/s to
40 bit/s, the first of a series of **congestion collapses**.[^jacobson] The
congestion control algorithms that Van Jacobson devised in response are still
the basis of TCP's standard congestion control.[^jacobson][^congestion]

The Internet's address space ran short too. **CIDR** (1993) replaced the fixed
class A, B and C network sizes with prefixes of any length,[^rfc1519]
**NAT** (1994) let many machines share one public address,[^rfc1631] and
**IPv6**, first specified in 1995, gave addresses 128 bits instead of
32.[^rfc1883][^ipv6] Even so, IANA handed out the last of its free IPv4
address blocks to the regional registries in February 2011.[^exhaustion]

### The OSI alternative

While TCP/IP grew out of research, the international standards bodies
designed their own suite, **Open Systems Interconnection (OSI)**. Its seven
layer **reference model** was published as an international standard in 1984,
and OSI had the backing of the large computer companies, the European
Economic Community and governments in Europe, North America and Asia; from
1988 the US government required OSI-compliant products in its own
purchases.[^zimmermann][^russell] TCP/IP won anyway: by the mid-1990s the
Internet was the de facto standard for computer networking.[^russell] The
OSI protocols are almost forgotten, but the OSI model survived as the
vocabulary everyone uses to talk about networks.

### The modern stack

The **World Wide Web**, proposed by Tim Berners-Lee at CERN in March 1989, gave
the Internet its most popular application.[^cernweb] Since then the lower
layers have changed slowly and the upper ones quickly: HTTP/2 (2015)
multiplexed requests over one connection,[^rfc7540] TLS 1.3 (2018) cut a full
secure handshake from two round trips to one,[^rfc8446][^tls12] and **QUIC**
(2021) moved transport into a new protocol over UDP, on which **HTTP/3** (2022)
runs.[^quic][^http3] TLS 1.3 was republished in 2026 as RFC 9846, with
corrections and clarifications.[^tls13]

### A timeline at a glance

| Year | Milestone |
|---|---|
| 1964 | Baran's *On Distributed Communications* |
| 1969 | ARPANET's first nodes; the first message, UCLA to SRI |
| 1974 | Cerf and Kahn's internetworking paper |
| 1976 | Ethernet described by Metcalfe and Boggs |
| 1981 | IPv4 (RFC 791) and TCP (RFC 793) |
| 1983 | ARPANET switches to TCP/IP; 4.2BSD sockets; DNS |
| 1984 | The OSI reference model is published |
| 1985 | The NSFNET program begins |
| 1986 | The first congestion collapse |
| 1989 | The World Wide Web is proposed at CERN |
| 1993 | CIDR |
| 1994 | NAT |
| 1995 | IPv6 first specified (RFC 1883; RFC 8200 today) |
| 2011 | IANA's free pool of IPv4 addresses runs out |
| 2015 | HTTP/2 |
| 2018 | TLS 1.3 |
| 2021 | QUIC |
| 2022 | HTTP/3; TCP's specification consolidated as RFC 9293 |
| 2026 | TLS 1.3 republished as RFC 9846 |

## Layers: the OSI and TCP/IP models

Networking software is built in **layers**. Each layer offers a service to the
one above and uses the service of the one below: the layer that moves packets
between networks need not know whether they travel over fibre or radio, and
the application that sends an HTTP request need not know how packets are
routed. At each layer, the two machines follow a **protocol** with each other,
while actually handing their data down to the layer beneath.[^zimmermann][^parch]

### The OSI reference model

The OSI model, standardised as ISO/IEC 7498-1 and identically as ITU-T
Recommendation X.200, divides communication into seven layers:[^x200]

| # | Layer | What it does | Examples today |
|---|---|---|---|
| 7 | **Application** | The service the user's program wants: fetch a page, send mail | HTTP, DNS, SMTP |
| 6 | **Presentation** | How data is represented: encodings, compression, encryption | character encodings, TLS (partly) |
| 5 | **Session** | Managing a dialogue between two applications | rarely a separate layer today |
| 4 | **Transport** | End-to-end delivery between programs: reliability, ordering, flow control | TCP, UDP, QUIC |
| 3 | **Network** | Addressing and routing packets across many networks | IP, ICMP |
| 2 | **Data link** | Delivering frames between machines on the same link | Ethernet, Wi-Fi |
| 1 | **Physical** | Sending bits as signals: voltages, light, radio | cables, fibre, radio |

### The TCP/IP model

The Internet's own architecture, described in the host requirements RFCs of
1989, has four layers: **link**, **internet** (IP), **transport** and
**application**.[^rfc1122][^rfc1123] It was written to describe protocols that
already existed, where OSI's model came first and its protocols afterwards.

{{< diagram src="models.svg" caption="The OSI and TCP/IP models side by side. The names of the data units, frame, packet and segment, come from the layer that creates them." >}}

The two models disagree most at the top. The Internet has no separate session
or presentation layer: applications do that work themselves. Some protocols do
not fit either model neatly. TLS encrypts on top of TCP but beneath the
application; QUIC is a transport protocol carried inside UDP, another
transport. In practice, engineers use the OSI *numbers* as shorthand, a
"layer 2 switch" or a "layer 7 load balancer", while the protocols follow the
TCP/IP model. The IETF itself has warned against taking layering too
literally, in a section titled *Layering Considered Harmful*.[^rfc3439]

### Encapsulation

When a program sends data, each layer on the way down wraps what it received
from above in its own **header**, a process called **encapsulation**:

{{< diagram src="encapsulation.svg" caption="Encapsulating an HTTP request. Each layer adds its own header and treats everything inside as payload." >}}

An HTTP request becomes the payload of a TCP **segment**; the segment becomes
the payload of an IP **packet**; the packet becomes the payload of an Ethernet
**frame**, which carries it to the next machine. On the receiving side each
layer strips its header and passes the rest up. A router on the way unwraps
only as far as the IP header, which is all it needs to forward the packet, and
wraps the packet in a new frame for its next link.[^parch][^rfc1180]

## The link layer: getting to the next machine

The link layer moves frames between machines that share a link: a cable, a
fibre, or the same Wi-Fi network.

### Ethernet and Wi-Fi

**Ethernet**, invented at Xerox PARC and described by Robert Metcalfe and
David Boggs in 1976, was a shared cable on which every station listened for
other traffic before and while transmitting.[^metcalfe][^pethernet]
Standardised by the IEEE as **802.3**,[^ieee8023] it is now typically wired
point to point, each machine to a port on a switch, and runs at 1 or 10
Gbit/s instead of the original 10 Mbit/s.[^pethernet] **Wi-Fi**, standardised
as IEEE **802.11**, carries frames by radio.[^ieee80211]

Each network interface has a 48-bit **MAC address**, written as six bytes in
hexadecimal such as `3c:22:fb:12:34:56`.[^arp] An Ethernet frame carries the
destination and source MAC addresses and a type field that says what is
inside, `0x0800` for IPv4, followed by the payload and a 32-bit CRC that lets
the receiver discard corrupted frames.[^rfc894][^pethernet] A **switch**
learns which addresses are reachable through which of its ports by watching
the source addresses of the frames it receives, and forwards each frame only
to the port where its destination lives.[^pswitched]

The largest payload a link can carry in one frame is its **maximum
transmission unit (MTU)**. For standard Ethernet it is 1,500
bytes,[^rfc894] and that number shows up again and again at the higher layers.

### ARP: from IP address to MAC address

Programs address machines by IP address, but an Ethernet frame needs a MAC
address. The **Address Resolution Protocol (ARP)** bridges the two: to send to
`192.168.1.20` on the local network, a host broadcasts "who has
192.168.1.20?", the owner replies with its MAC address, and the answer is
cached.[^arp] IPv6 does the same job with **Neighbor Discovery**, which uses
ICMPv6 messages instead of a separate protocol.[^rfc4861]

## The internet layer: IP

The **Internet Protocol (IP)** delivers packets from any host to any other,
across as many networks as lie between them. It is deliberately simple.
Every packet is a self-contained **datagram**; there are no connections, and
delivery is **best effort**: IP makes no promise that a packet arrives, arrives
once or arrives in order.[^ipv4] David Clark, explaining the design in 1988,
described the datagram as the basic building block out of which different
kinds of service could be built, and one that let the network survive the
loss of its gateways, since they keep no state about connections.[^clark88]
Guarantees, when an application needs them, are added at the ends of the
conversation and not in the network, the **end-to-end argument**.[^e2e]

### The IPv4 header and addresses

An IPv4 header is at least 20 bytes long. Among its fields are the source and
destination addresses, the protocol carried inside (such as TCP or UDP), the
total length, fields for fragmenting packets that are too big for a link, and a
**time to live (TTL)** that every router decrements, so that a packet caught in
a routing loop is eventually discarded.[^ipv4]

An IPv4 address is 32 bits, written as four decimal bytes such as
`192.168.1.77`. Addresses are allocated in blocks written in **CIDR
notation**: `192.168.1.0/24` means the addresses whose first 24 bits match
`192.168.1.0`, which leaves 8 bits, or 256 addresses, for hosts.[^cidr]
Python's `ipaddress` module does the arithmetic:[^pyipaddress]

```python
import ipaddress

net = ipaddress.ip_network("192.168.1.0/24")
print(net.network_address, net.broadcast_address, net.netmask, net.num_addresses)
print(ipaddress.ip_address("192.168.1.77") in net)
print(ipaddress.ip_address("10.20.30.40").is_private,
      ipaddress.ip_address("8.8.8.8").is_private)

v6 = ipaddress.ip_address("2001:0db8:0000:0000:0000:ff00:0042:8329")
print(v6.compressed)
print(v6.exploded)
```

```txt
192.168.1.0 192.168.1.255 255.255.255.0 256
True
True False
2001:db8::ff00:42:8329
2001:0db8:0000:0000:0000:ff00:0042:8329
```

Some ranges are set aside for special purposes, and a programmer meets them
constantly:[^rfc1918][^ianav4][^rfc5737]

| Range | Purpose |
|---|---|
| `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` | **Private** addresses, for use inside an organisation, never routed on the Internet |
| `127.0.0.0/8` | **Loopback**: the machine itself, usually as `127.0.0.1` |
| `169.254.0.0/16` | **Link-local**: self-assigned when no configuration is available |
| `100.64.0.0/10` | Shared address space for providers' carrier-grade NAT |
| `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` | Reserved for documentation and examples, like those in this article |

Machines usually get their address, network prefix, default router and DNS
servers automatically from a **DHCP** server, in a four-message exchange:
the client broadcasts a DISCOVER, servers reply with an OFFER, the client
sends a REQUEST for one offer, and the server confirms with an
ACK.[^dhcp]

### Routing and forwarding

A router's job has two halves. **Forwarding** is what it does with each
packet: look up the destination address in its **forwarding table** and send
the packet out of the matching interface. **Routing** is how that table gets
built.

Each table entry is a prefix and a next hop, and more than one prefix can
match a destination. The rule is **longest prefix match**: the most specific
matching route wins, and the default route `0.0.0.0/0`, which matches
everything, is used only when nothing else does:[^rfc1812]

```python
import ipaddress

# A router's forwarding table: destination prefix -> next hop.
table = {
    "0.0.0.0/0":      "ISP uplink",       # the default route
    "10.0.0.0/8":     "core router",
    "10.1.0.0/16":    "building A",
    "10.1.2.0/24":    "lab switch",
}
routes = [(ipaddress.ip_network(p), hop) for p, hop in table.items()]

def next_hop(destination):
    address = ipaddress.ip_address(destination)
    matches = [(net, hop) for net, hop in routes if address in net]
    net, hop = max(matches, key=lambda m: m[0].prefixlen)  # longest prefix wins
    return f"{destination:<13} -> {str(net):<12} {hop}"

for d in ["10.1.2.9", "10.1.7.7", "10.9.9.9", "203.0.113.5"]:
    print(next_hop(d))
```

```txt
10.1.2.9      -> 10.1.2.0/24  lab switch
10.1.7.7      -> 10.1.0.0/16  building A
10.9.9.9      -> 10.0.0.0/8   core router
203.0.113.5   -> 0.0.0.0/0    ISP uplink
```

The tables are filled by **routing protocols**. Inside one organisation's
network, an **interior** protocol such as **OSPF** has every router flood a
description of its links to the others, so that each can compute the shortest
paths itself.[^ospf] Between the networks that make
up the Internet, called **autonomous systems**, the **Border Gateway Protocol
(BGP)** exchanges reachability: each network announces the prefixes it can
reach and the path of autonomous systems to them, and applies its own
policies about which routes to accept and pass on. BGP runs over TCP, on port
179.[^bgp]

### ICMP: errors, ping and traceroute

When IP cannot deliver a packet, the **Internet Control Message Protocol
(ICMP)** reports why: destination unreachable, or time exceeded when a
packet's TTL reaches zero.[^icmp] Two familiar tools are built on it. `ping`
sends ICMP echo requests and times the replies. `traceroute` (`tracert` on
Windows) sends packets with a TTL of 1, then 2, then 3, and so on; each router
that drops one for running out of TTL reveals itself with a time exceeded
message, so the replies map out the path.[^icmp][^tracert]

ICMP also makes **path MTU discovery** work. A sender sets the "don't
fragment" flag on its packets; a router that cannot forward one without
fragmenting it drops it and sends back an ICMP message giving the smaller
MTU.[^pmtud] Firewalls that block all ICMP break this mechanism, and
connections then hang as soon as they send a full-sized packet, a classic
problem known as a PMTUD **black hole**.[^rfc2923] It is one good reason not to
filter ICMP blindly.

### NAT: sharing one address

Most homes and many companies have far more devices than public IPv4
addresses. **Network address and port translation (NAT)** lets them share one:
the router rewrites the source address and port of every outgoing packet to
its own public address and a port of its choosing, records the mapping, and
reverses the rewrite on the replies:[^nat]

{{< diagram src="nat.svg" caption="Two devices share one public address. The router tells their connections apart by the ports it assigns. The addresses are from the ranges reserved for documentation." >}}

NAT works so well that most people never notice it, but programmers do.
Connections can only be started from the inside, because an unsolicited
packet arriving at the public address matches no mapping, so peer-to-peer
applications need techniques such as STUN and ICE to get through.[^stun][^ice]
Mappings also expire when idle. For UDP the requirement is no less than two
minutes, with five or more recommended, but real devices vary, so long-lived
idle connections need periodic keep-alive traffic.[^rfc4787]

### IPv6

**IPv6** gives every address 128 bits, written as eight groups of four
hexadecimal digits with the longest run of zero groups shortened to `::`, as
the Python example above showed.[^ipv6addr] Its header has a fixed 40 bytes,
a **hop limit** in place of TTL and a **flow label**; routers never fragment
IPv6 packets, only senders do; and every link must carry packets of at least
1,280 bytes.[^ipv6] Hosts can configure their own addresses from the prefix
their router announces, without DHCP, and can add temporary randomised
addresses for privacy.[^slaac][^rfc8981]

Every IPv6 interface has a **link-local** address in `fe80::/10`, the loopback
address is `::1`, and `fc00::/7` holds *unique local* addresses for private
networks.[^ipv6addr][^ianav6] Adoption is gradual: Google measures the share of
its users that reach it over IPv6, and on 18 October 2026 it was 48.9
percent.[^googlev6] Most hosts are therefore **dual-stack**, and clients use
**Happy Eyeballs**: they try IPv6 first, and if it has not connected within
about 250 milliseconds, they race an IPv4 attempt alongside it, so a broken
IPv6 path costs a fraction of a second instead of a long timeout.[^happyeyeballs]

## The transport layer: ports, UDP and TCP

IP delivers packets to a *machine*. The transport layer delivers data to a
*program* on that machine, identified by a 16-bit **port number**. A
connection is identified by five values: the protocol, and the source and
destination address and port.

The IANA keeps the registry of port numbers. Ports 0 to 1023 are the **system**
or well-known ports (80 for HTTP, 443 for HTTPS, 22 for SSH), 1024 to 49151 are
**user** or registered ports, and 49152 to 65535 are **dynamic** ports, never
assigned.[^rfc6335][^ianaports] When a client connects, the operating system
picks a temporary **ephemeral port** for its end. The ranges differ: Windows
uses 49152 to 65535, Linux 32768 to 60999 by default, and the IETF recommends
using the whole range from 1024 upwards and choosing ports at random, which
makes attacks that guess them harder.[^windowsports][^ipsysctl][^rfc6056]

### UDP: datagrams and nothing more

The **User Datagram Protocol (UDP)** adds almost nothing to IP: an 8-byte
header with the two ports, a length and a checksum.[^udp] There is no
connection, no acknowledgement, no retransmission and no ordering. What UDP
does keep is **message boundaries**: each send becomes one datagram, which
arrives whole or not at all. It suits applications that prefer speed to
completeness, or that want to build their own reliability: DNS queries, voice
and video calls, games, and QUIC. An application that sends a lot over UDP
must also do its own congestion control, so as not to swamp the
network.[^rfc8085]

### TCP: a reliable byte stream

The **Transmission Control Protocol (TCP)** turns IP's unreliable datagrams
into a reliable, ordered, two-way **stream of bytes** between two programs.
Its specification, first published in 1981 and consolidated with four decades
of updates into RFC 9293 in 2022, is one of the Internet's core
standards.[^tcp]

**The handshake.** Before any data flows, the two sides exchange three
segments: the client sends a **SYN** carrying its initial sequence number, the
server answers with a **SYN-ACK** carrying its own and acknowledging the
client's, and the client acknowledges the server's.[^tcp] The initial numbers
are chosen to be hard to predict, which protects connections from attackers
who would otherwise inject forged segments.[^tcp] Here is a real connection,
captured with tcpdump on Linux's loopback interface, as a client sends `hello`
to a server that replies with `HELLO` and closes:

```sh
tcpdump -i lo -n -t -S 'tcp port 9999'
```

```txt
IP 127.0.0.1.41134 > 127.0.0.1.9999: Flags [S], seq 3283327688, win 65495, options [mss 65495,sackOK,TS val 4246365075 ecr 0,nop,wscale 10], length 0
IP 127.0.0.1.9999 > 127.0.0.1.41134: Flags [S.], seq 4167151407, ack 3283327689, win 65483, options [mss 65495,sackOK,TS val 1470277348 ecr 4246365075,nop,wscale 10], length 0
IP 127.0.0.1.41134 > 127.0.0.1.9999: Flags [.], ack 4167151408, win 64, options [nop,nop,TS val 4246365075 ecr 1470277348], length 0
IP 127.0.0.1.41134 > 127.0.0.1.9999: Flags [P.], seq 3283327689:3283327694, ack 4167151408, win 64, options [nop,nop,TS val 4246365075 ecr 1470277348], length 5
IP 127.0.0.1.9999 > 127.0.0.1.41134: Flags [.], ack 3283327694, win 64, options [nop,nop,TS val 1470277348 ecr 4246365075], length 0
IP 127.0.0.1.9999 > 127.0.0.1.41134: Flags [P.], seq 4167151408:4167151413, ack 3283327694, win 64, options [nop,nop,TS val 1470277348 ecr 4246365075], length 5
IP 127.0.0.1.41134 > 127.0.0.1.9999: Flags [.], ack 4167151413, win 64, options [nop,nop,TS val 4246365075 ecr 1470277348], length 0
IP 127.0.0.1.9999 > 127.0.0.1.41134: Flags [F.], seq 4167151413, ack 3283327694, win 64, options [nop,nop,TS val 1470277348 ecr 4246365075], length 0
IP 127.0.0.1.41134 > 127.0.0.1.9999: Flags [F.], seq 3283327694, ack 4167151414, win 64, options [nop,nop,TS val 4246365075 ecr 1470277348], length 0
IP 127.0.0.1.9999 > 127.0.0.1.41134: Flags [.], ack 3283327695, win 64, options [nop,nop,TS val 1470277348 ecr 4246365075], length 0
```

{{< diagram src="handshake.svg" caption="The captured connection as a sequence diagram, with x and y for the two initial sequence numbers." >}}

Reading the trace: the client, on ephemeral port 41134, sends `[S]` (SYN) with
sequence number 3283327688. The server answers `[S.]` (SYN and ACK) with its own
number, acknowledging 3283327689, one more than the client's, because a SYN
counts as one byte of sequence space. After the client's `[.]` (ACK), the
connection is established, one round trip after it started. The client's 5
bytes travel as `seq 3283327689:3283327694` and are acknowledged with
`ack 3283327694`, the next byte the server expects. The options in the SYNs
negotiate the **maximum segment size**, selective acknowledgements, timestamps
and window scaling.[^tcp][^tcp7]

**Reliability.** Every byte has a sequence number, and the receiver
acknowledges the next byte it expects, which confirms everything before
it.[^tcp] A sender
that gets no acknowledgement in time retransmits; the **retransmission
timeout** is computed from measured round-trip times, and doubles after each
failed attempt.[^rto] The receiver uses the sequence numbers to put segments
back in order and to discard duplicates, so the application sees each byte
exactly once, in order.

**Flow control.** Each acknowledgement also carries a **receive window**, the
amount of buffer space the receiver has left (`win` in the trace, scaled by
the negotiated factor). The sender never has more unacknowledged data
outstanding than that, so a fast sender cannot overrun a slow
receiver.[^tcp]

**Congestion control.** The receive window protects the receiver; nothing in
it protects the network in between. Since Jacobson's work, TCP senders also
keep a **congestion window** and probe for how much the path can
take:[^congestion][^jacobson]

{{< diagram src="congestion.svg" caption="The congestion window of a classic TCP sender. CUBIC, the default in Linux, Windows and Apple's systems, grows along a cubic curve instead of a straight line, and on a loss cuts its window to 0.7 of its size instead of half." >}}

- **Slow start**: a new connection may send an *initial window*, up to 10
  segments under current guidance,[^iw10] and the window grows by one segment
  for every acknowledgement, which doubles it every round trip.
- **Congestion avoidance**: once the window passes the *slow-start threshold*,
  it grows by about one segment per round trip.
- **Fast retransmit**: three duplicate acknowledgements, sent by a receiver
  that keeps getting segments after a gap, mean one segment was lost while
  later ones arrived; the sender retransmits it at once and halves its
  window.
- **Timeout**: if the retransmission timer expires, something is badly
  wrong; the window falls to one segment and slow start begins again.

Modern stacks refine the details. **CUBIC** is the default congestion control
in Linux, Windows and Apple's systems,[^cubic] and Google's **BBR** instead
estimates the path's bandwidth and round-trip time directly rather than
waiting for losses.[^bbr] The consequence for programmers is the same: a new
connection starts slowly, and short transfers on fresh connections never reach
the link's full speed.

**Closing.** Each side closes its direction of the stream with a **FIN**. The
side that closes first then waits in the **TIME-WAIT** state for twice the
**maximum segment lifetime (MSL)**, taken in the specification to be two
minutes, so that delayed segments from the old connection cannot be mistaken
for a new one using the same ports.[^tcp] Linux uses a fixed 60 seconds,
as `ss` shows for the server that closed first in the capture above:[^tcph]

```txt
Recv-Q Send-Q Local Address:Port Peer Address:Port Process
0      0          127.0.0.1:9999    127.0.0.1:41134 timer:(timewait,58sec,0)
```

A busy server that closes its own connections accumulates these sockets, and
a server restarted while its old sockets are in TIME-WAIT may be refused its
port unless it sets the `SO_REUSEADDR` option, which Python's
`create_server` does on Unix-like systems for exactly that
reason.[^pysocket][^socket7] TCP has eleven states in all, from LISTEN and
SYN-SENT through ESTABLISHED to TIME-WAIT and CLOSED.[^tcp]

### A stream, not messages

A very common networking bug in application code comes from forgetting that
TCP delivers a stream of bytes, not a sequence of messages. Two `send` calls
can arrive as one `recv`, and one `send` can arrive split across several:

```python
import socket, time

# TCP: a byte stream. Two sends can arrive as one read.
listener = socket.create_server(("127.0.0.1", 0))
client = socket.create_connection(listener.getsockname())
conn, _ = listener.accept()
client.sendall(b"first message")
client.sendall(b"second message")
time.sleep(0.1)                      # let both arrive before reading
print("TCP read:", conn.recv(1024))

# UDP: datagrams. Each send arrives whole, as its own message, or not at all.
receiver = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
receiver.bind(("127.0.0.1", 0))
sender = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sender.sendto(b"first message", receiver.getsockname())
sender.sendto(b"second message", receiver.getsockname())
time.sleep(0.1)
print("UDP read:", receiver.recv(1024))
print("UDP read:", receiver.recv(1024))
```

```txt
TCP read: b'first messagesecond message'
UDP read: b'first message'
UDP read: b'second message'
```

Every protocol on top of TCP therefore defines its own **framing**: HTTP/1.1
uses a blank line to end the headers and a `Content-Length` header or chunked
encoding for the body;[^http11] binary protocols commonly put a length in
front of each message. Reading a message then means reading exactly that many
bytes, however many `recv` calls it takes:

```python
import socket, struct

def send_message(sock, payload):
    # A 4-byte length in network byte order (big-endian), then the payload.
    sock.sendall(struct.pack("!I", len(payload)) + payload)

def recv_exactly(sock, n):
    data = b""
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk:
            raise ConnectionError("peer closed the connection")
        data += chunk
    return data

def recv_message(sock):
    (length,) = struct.unpack("!I", recv_exactly(sock, 4))
    return recv_exactly(sock, length)

listener = socket.create_server(("127.0.0.1", 0))
client = socket.create_connection(listener.getsockname())
conn, _ = listener.accept()
send_message(client, b"first message")
send_message(client, b"second message")
print(recv_message(conn))
print(recv_message(conn))
print(struct.pack("!I", 13).hex(" "), "is 13 as a big-endian 32-bit integer")
```

```txt
b'first message'
b'second message'
00 00 00 0d is 13 as a big-endian 32-bit integer
```

The `!` in the `struct` format means **network byte order**: Internet protocols
send multi-byte numbers most significant byte first, whatever the byte order
of the processor.[^ipv4][^pystruct]

A related surprise is **Nagle's algorithm**, which holds back small segments
while earlier data is unacknowledged so that many tiny writes do not each
become a packet.[^nagle] Combined with the receiver's habit of delaying
acknowledgements, by up to half a second,[^rfc1122] it can add noticeable
delays to request-response protocols that write a message in several small
pieces. Setting the `TCP_NODELAY` socket option turns it off; writing each
message in one call is often the better fix.[^tcp7]

### Head-of-line blocking and QUIC

Because TCP delivers bytes strictly in order, one lost segment holds up
everything behind it until the retransmission arrives, even data that belongs
to unrelated requests multiplexed on the same connection. This is
**head-of-line blocking**, and HTTP/2, which multiplexes many requests over
one TCP connection, suffers from it at the transport layer.[^http2]

**QUIC** was designed to fix that and more. It runs over UDP "to better
facilitate deployment in existing systems and networks", and it
provides:[^quic][^quictls]

- **Independent streams** within one connection, so a loss delays only the
  stream it belongs to.
- **Built-in TLS 1.3**: the transport and cryptographic handshakes are
  combined, every packet is authenticated, and as much of each packet as is
  practical, including parts of its header, is encrypted.
- **Connection IDs** that identify a connection independently of addresses,
  so it can **migrate** when an address changes, for example when a NAT
  rebinds or a phone moves from Wi-Fi to mobile data.
- Its own loss detection and congestion control.[^quicrecovery]

## The application layer: DNS, HTTP, TLS and friends

### DNS: names to addresses

People and programs use names such as `example.com`; IP needs addresses. The
**Domain Name System (DNS)** is the distributed database that maps one to the
other, and much more besides.[^dns][^dnsimpl] Names form a tree, read from
right to left: the root, then **top-level domains** such as `com`, then
`example.com` and its subdomains. Each part of the tree, a **zone**, is served
by its own **authoritative** name servers. At the top are 13 named root server
authorities, `a.root-servers.net` to `m.root-servers.net`, run by 12
organisations; in October 2026 they answered from 2,047 server instances
around the world.[^ianaroot][^rootservers]

A program rarely talks to that hierarchy itself. Its operating system's
**stub resolver** asks a **recursive resolver**, which does the walk and
caches what it learns:[^dns]

{{< diagram src="dns.svg" caption="Resolving a name with an empty cache. With a warm cache, the recursive resolver answers step 1 immediately." >}}

Every answer comes with a **time to live (TTL)**, the number of seconds it may
be cached. Caching is what makes DNS fast, and also why a changed record can
take a while to be seen everywhere. The most common record types
are:[^dnsimpl][^ipv6dns]

| Type | Holds |
|---|---|
| `A` | An IPv4 address |
| `AAAA` | An IPv6 address |
| `CNAME` | An alias: the canonical name to look up instead |
| `MX` | The mail servers for the domain |
| `NS` | The authoritative name servers for a zone |
| `TXT` | Descriptive text, whose meaning depends on the domain |

DNS messages are small and binary, and usually travel over UDP on port 53, so
a query fits in a few dozen bytes of Python. This example builds a query by
hand following RFC 1035, sends it to a public resolver and decodes the
answers:[^dnsimpl]

```python
import socket, struct

def build_query(name, qtype):
    # Header: ID, flags (only "recursion desired" set), 1 question, 0 other records.
    header = struct.pack("!HHHHHH", 0x1234, 0x0100, 1, 0, 0, 0)
    labels = b"".join(bytes([len(p)]) + p.encode() for p in name.split("."))
    return header + labels + b"\x00" + struct.pack("!HH", qtype, 1)  # class IN

def skip_name(msg, i):
    while msg[i] != 0:
        if msg[i] & 0xC0 == 0xC0:          # a compression pointer ends the name
            return i + 2
        i += msg[i] + 1
    return i + 1

def lookup(name, qtype, resolver=("1.1.1.1", 53)):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.settimeout(2)
        s.sendto(build_query(name, qtype), resolver)
        msg, _ = s.recvfrom(512)
    id_, flags, qd, an, _, _ = struct.unpack("!HHHHHH", msg[:12])
    print(f"id={id_:#06x} rcode={flags & 0xF} answers={an} bytes={len(msg)}")
    i = skip_name(msg, 12) + 4                       # skip the echoed question
    for _ in range(an):
        i = skip_name(msg, i)
        rtype, _, ttl, length = struct.unpack("!HHIH", msg[i:i + 10])
        data = msg[i + 10:i + 10 + length]
        family = socket.AF_INET if rtype == 1 else socket.AF_INET6
        print(f"  type={rtype:<3} ttl={ttl:<5} {socket.inet_ntop(family, data)}")
        i += 10 + length

lookup("example.com", 1)    # A: IPv4 addresses
lookup("example.com", 28)   # AAAA: IPv6 addresses
```

```txt
id=0x1234 rcode=0 answers=2 bytes=61
  type=1   ttl=295   172.66.147.243
  type=1   ttl=295   104.20.23.154
id=0x1234 rcode=0 answers=2 bytes=85
  type=28  ttl=228   2606:4700:10::ac42:93f3
  type=28  ttl=228   2606:4700:10::6814:179a
```

The response echoes the query's ID, which is how the client matches answers
to questions; `rcode=0` means no error; the TTLs show how long the resolver
had left to cache each answer. Plain DNS was limited to 512-byte UDP messages,
with longer answers retried over TCP;[^dnsimpl] the EDNS(0) extension lets the
two sides agree on larger ones.[^edns] It is also unencrypted, so anyone on
the path can see and alter queries. **DNSSEC** lets resolvers verify that
answers are authentic,[^dnssec] and DNS over TLS (port 853) and DNS over
HTTPS encrypt the conversation between a client and its
resolver.[^dot][^doh]

In application code, name resolution normally goes through the operating
system's `getaddrinfo`, which applies the system's configuration, caches and
hosts file, and returns every address to try in order.[^posixgai]

### HTTP

The **Hypertext Transfer Protocol (HTTP)** is the application protocol of the
web and of most APIs. Its *semantics*, the same in every version, are defined
in RFC 9110: a client sends a **request** with a **method** (`GET`, `POST`,
`PUT`, `DELETE` and others), a target and headers, and the server returns a
**response** with a three-digit **status code** and its own headers and
body.[^http] The first digit of the status gives its class: `1xx`
informational, `2xx` success, `3xx` redirection, `4xx` a client error, `5xx`
a server error.[^http] Methods such as `GET` and `PUT` are defined to be
*idempotent*, so a client may safely retry them after a network failure, while
retrying a `POST` might, for example, place an order twice.[^http]

What changed between versions is how messages travel:

| Version | Year | Transport | How messages travel |
|---|---|---|---|
| HTTP/1.1 | 1997; current text 2022 | TCP | Text; responses return in order, so clients open several connections for concurrency[^rfc2068][^http11][^http2] |
| HTTP/2 | 2015; current text 2022 | TCP | Binary frames; many concurrent streams on one connection; compressed headers[^http2][^hpack] |
| HTTP/3 | 2022 | QUIC | HTTP/2's model mapped onto QUIC streams, without TCP's head-of-line blocking[^http3] |

HTTP/1.1 is simple enough to speak by hand. This example opens a TCP
connection, wraps it in TLS and sends a request:

```python
import socket, ssl

context = ssl.create_default_context()   # checks the certificate chain and name
with socket.create_connection(("example.com", 443)) as raw:
    with context.wrap_socket(raw, server_hostname="example.com") as tls:
        print(tls.version(), tls.cipher()[0])
        cert = tls.getpeercert()
        print("issued to:", dict(x[0] for x in cert["subject"])["commonName"])
        print("issued by:", dict(x[0] for x in cert["issuer"])["organizationName"])

        tls.sendall(b"GET / HTTP/1.1\r\n"
                    b"Host: example.com\r\n"
                    b"Connection: close\r\n"
                    b"\r\n")
        response = b""
        while chunk := tls.recv(4096):
            response += chunk

head = response.split(b"\r\n\r\n")[0].decode()
print(head.splitlines()[0])
for line in head.splitlines()[1:]:
    if line.split(":")[0].lower() in ("content-type", "transfer-encoding", "alt-svc"):
        print(line)
```

```txt
TLSv1.3 TLS_AES_256_GCM_SHA384
issued to: example.com
issued by: SSL Corporation
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Transfer-Encoding: chunked
alt-svc: h3=":443"; ma=86400
```

The response uses chunked encoding, the framing HTTP/1.1 uses when the length
is not known in advance.[^http11] The `alt-svc` header advertises that the same
service is available over HTTP/3 on UDP port 443 for the next 86,400 seconds.
It is one way clients discover HTTP/3: they learn it from a response over TCP
and can use QUIC for later connections.[^altsvc][^http3]

### TLS

**Transport Layer Security (TLS)** gives a connection three properties:
**confidentiality** (eavesdroppers see only ciphertext), **integrity**
(tampering is detected) and **authentication** of the server, and optionally
of the client.[^tls13] In a TLS 1.3 handshake the client's first message
already carries its key share, and the server's reply completes the key
exchange, so the client can send encrypted application data after one round
trip.[^tls13] A resumed connection can even send data in its first flight,
called **0-RTT**, at the cost of allowing that data to be replayed by an
attacker, so it must only be used for requests that are safe to repeat.[^tls13]

The server proves its identity with an **X.509 certificate**: a document
binding its name to a public key, signed by a **certificate authority** whose
own certificate is signed by another, up to a **root** that the client already
trusts.[^x509] The client checks the signatures, the validity dates and that
the name matches the host it meant to reach; the `server_hostname` argument in
the example both tells the server which site is wanted, the **Server Name
Indication** extension, and tells the client which name to check.[^sni][^pyssl]
Turning those checks off to make an error go away is one of the most common
security mistakes in networked code.

### Other protocols worth knowing

| Protocol | Transport | What it does |
|---|---|---|
| **DHCP** | UDP | Configures a host's address, router and DNS servers[^dhcp] |
| **NTP** | UDP | Synchronises clocks[^ntp] |
| **SMTP** | TCP | Transfers email between servers[^smtp] |
| **SSH** | TCP | Encrypted remote login, commands and file transfer[^ssh] |
| **WebSocket** | TCP | A two-way message channel that starts as an HTTP request[^websocket] |
| **mDNS** | UDP | Name lookups on a local network without a DNS server, such as `printer.local`[^mdns] |

## Sockets: the programmer's interface

Applications reach the network through **sockets**, the interface introduced
by 4.2BSD in 1983 and standardised by POSIX.[^bsd][^posixsocket] A socket is a
file-like handle for one end of a conversation. A TCP server creates one,
`bind`s it to an address and port, `listen`s, and `accept`s connections, each
of which gets its own new socket; a client creates one and `connect`s. Both
then `send` and `recv`. Python's `socket` module is a thin layer over the same
calls:[^pysocket]

```python
import socket, threading

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)    # TCP over IPv4
server.bind(("127.0.0.1", 0))      # port 0: let the OS pick a free port
server.listen()
host, port = server.getsockname()

def serve_one():
    conn, peer = server.accept()           # blocks until a client connects
    with conn:
        print("server: connection from", peer)
        while data := conn.recv(1024):     # b"" means the peer closed
            conn.sendall(data.upper())

threading.Thread(target=serve_one).start()

with socket.create_connection((host, port)) as client:
    print("client: connected to", client.getpeername(),
          "from", client.getsockname())
    client.sendall(b"hello, network")
    print("client: got", client.recv(1024))
```

```txt
client: connected to ('127.0.0.1', 58594) from ('127.0.0.1', 58595)
server: connection from ('127.0.0.1', 58595)
client: got b'HELLO, NETWORK'
```

Both ports came from Windows' dynamic range, the listening one because the
program asked for port 0 and the client's because the operating system picks
one on `connect`. Binding to `127.0.0.1` makes the server reachable only from
the same machine; binding to `0.0.0.0` (or `::` for IPv6) accepts connections
on every interface, which is what a public server wants and a development
database usually does not.[^ip7]

A few habits make socket code robust:

- **Always set timeouts.** Unless told otherwise, Python sockets have no
  timeout, so `connect` and `recv` can wait indefinitely for a peer that has
  vanished; a network failure often looks like silence, not an
  error.[^pysocket]
- **Treat `recv` returning nothing as the end of the stream**, and treat a
  reset connection as normal, because peers crash and connections drop.
- **Resolve names with `getaddrinfo` and try every address**, IPv6 and IPv4,
  instead of hard-coding one family; `socket.create_connection` does exactly
  that.[^posixgai][^pysocket]
- **Do not block one thread per connection** if a server must handle many
  clients: event loops built on `select`, `epoll` or `kqueue`, and libraries
  such as `asyncio`, handle thousands of sockets on a few threads, as
  [Processes and Threads]({{< ref "processes-and-threads" >}}) describes.

## Performance: latency, bandwidth and round trips

Two numbers describe a network path. **Bandwidth** is how many bits per second
it can carry; **latency** is how long one bit takes to get from end to end.
Latency is the sum of **propagation** delay (distance divided by signal
speed), **transmission** delay (packet size divided by bandwidth),
**queuing** delay in busy routers, and **processing**.[^pperf]

Propagation cannot be engineered away. Light travels at 2.0 × 10⁸ m/s in
optical fibre, two-thirds of its speed in a vacuum: 200,000 km per second, or
5 microseconds per kilometre.[^pperf] A path of 6,000 km therefore costs at
least 30 milliseconds each way and 60 milliseconds per round trip, whatever
the bandwidth.

Their product, the **bandwidth-delay product**, is how much data is "in
flight" on a full path: at 100 Mbit/s and a 100 ms round trip it is 10 Mbit,
1.25 megabytes.[^pperf] TCP can only fill such a path if its windows are at
least that large, which is why window scaling exists.[^tcp]

For most applications, the number that matters is **round trips**. curl can
break a single HTTPS request down:

```sh
curl -s -o /dev/null -w 'dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} first_byte=%{time_starttransfer} total=%{time_total}\n' https://example.com/
```

```txt
dns=0.018498 tcp=0.029511 tls=0.052294 first_byte=0.070137 total=0.070179
```

The times are cumulative, in seconds: 18 ms to resolve the name, another 11
ms for the TCP handshake, 23 ms for TLS, and 18 ms more for the request and
the first byte of the response.[^curl] Before a single byte of the page arrived,
most of the time went on setting up the connection. That is why the main
techniques for making networked programs fast are all ways of saving round
trips:

- **Reuse connections.** HTTP keep-alive and connection pools pay the TCP and
  TLS handshakes once for many requests.
- **Multiplex.** HTTP/2 and HTTP/3 send many requests at once on one
  connection, instead of waiting for each response.
- **Shorten the handshakes.** TLS 1.3 needs one round trip instead of TLS
  1.2's two, and QUIC combines it with the transport
  handshake.[^tls13][^tls12][^quic]
- **Move closer.** Content delivery networks put servers near users,
  shortening every round trip.
- **Batch.** One request that fetches fifty items beats fifty requests.

Bandwidth matters for large transfers, latency for everything else, and a
fast link does not fix a chatty protocol.

## Security on the network

Every network between two hosts should be assumed hostile: packets can be
read, altered, dropped, replayed or forged by anyone on the path, and IP's
source address proves nothing. A few principles follow:

- **Encrypt and authenticate everything with TLS** (or QUIC, or SSH), and keep
  certificate verification on.[^tls13] Do not invent your own cryptographic
  protocol.
- **Expose as little as possible.** Bind services to the interfaces that need
  them, and let firewalls allow only the ports that must be reachable.
- **Do not trust names or addresses alone.** DNS answers can be spoofed
  without DNSSEC, and addresses can be forged or shared behind NAT;
  authentication belongs at the application layer.[^dnssec]
- **Expect abuse at the transport layer.** A **SYN flood** fills a server's
  table of half-open connections with forged SYNs; operating systems defend
  against it with techniques such as SYN cookies.[^synflood]
- **Validate what you receive.** The old robustness principle, "be liberal
  in what you accept", has been reconsidered by the Internet Architecture
  Board, which warns that some ways of tolerating faulty input harm
  interoperability over time, and that actively maintained protocols can fix
  such problems instead of accommodating them.[^robustness]

## Tools of the trade

| Tool | What it answers |
|---|---|
| `ping` | Is the host reachable, and what is the round-trip time? |
| `traceroute` / `tracert` | Which routers are on the path, and where does it break? |
| `nslookup` / `dig` | What does DNS say for this name, and which server said it? |
| `curl -v` | What exactly was sent and received over HTTP and TLS? |
| `ss` / `netstat` | Which sockets are open, listening or in TIME-WAIT? |
| `openssl s_client` | What certificate does the server present? |
| `tcpdump` / Wireshark | What packets actually crossed the wire?[^tcpdump][^wireshark] |

When something fails, working up the layers usually finds it quickly: is the
link up, is there an address and a route (`ping`), does the name resolve
(`nslookup`), does the port accept connections, does TLS succeed, and what
does the application say (`curl -v`)?

## The fallacies of distributed computing

In the 1990s Peter Deutsch, then at Sun Microsystems, listed seven false
assumptions that programmers new to distributed systems tend to make, and
James Gosling later added an eighth. The network is reliable; latency is
zero; bandwidth is infinite; the network is secure; topology does not change;
there is one administrator; transport cost is zero; the network is
homogeneous.[^fallacies] Every section above is a reason why each one is
false: packets are lost, round trips cost tens of
milliseconds, paths are shared, links are hostile, routes and addresses
change, every network has its own operator and policies, and connections carry
IPv4 and IPv6, Wi-Fi and fibre, old middleboxes and new protocols. Code that
plans for each of them, with timeouts, retries of idempotent operations,
connection reuse, encryption and tolerance of change, is code that works on
real networks.

## Putting it together: one request

Running the HTTPS example above, the whole stack appears in sequence:

1. `create_connection` calls `getaddrinfo`, and the resolver, using a cached
   answer or walking from the root, returns the addresses of `example.com`.
2. The kernel picks an ephemeral port and sends a TCP SYN to port 443. To
   reach the router, it uses ARP to find the router's MAC address and puts the
   packet in an Ethernet or Wi-Fi frame.
3. The home router rewrites the source address and port (NAT) and forwards the
   packet towards its ISP; routers along the way pick the next hop by longest
   prefix match, along paths learned through BGP.
4. The SYN-ACK comes back the same way, the client acknowledges it, and the
   connection is established after one round trip.
5. `wrap_socket` performs the TLS 1.3 handshake, checking the certificate
   chain and the name: one more round trip.
6. The HTTP request travels encrypted inside TCP segments, inside IP packets,
   inside frames; the response arrives in chunks that the application
   reassembles.
7. Because the request asked for `Connection: close`, the server closes the
   connection after the response with a FIN, and as the side that closed
   first, it holds TIME-WAIT for a while.

## Why it matters

Networks explain a large share of the bugs and slowness that programmers deal
with. A request that hangs forever lacks a timeout; a message that arrives
corrupted was read without framing; a service that is fast on a laptop and
slow in production makes too many round trips; a connection that dies after
a few idle minutes has probably lost its NAT mapping; a certificate error is
either a real attack or a misconfiguration that turning off verification
would only hide. Each of
those has its root in one of the layers above, and the standards that define
them are, almost without exception, free to read.

## References

[^parch]: Peterson, L. L., & Davie, B. S. (n.d.). Architecture. In *Computer networks: A systems approach* (6th ed.). <https://book.systemsapproach.org/foundation/architecture.html>

[^preq]: Peterson, L. L., & Davie, B. S. (n.d.). Requirements. In *Computer networks: A systems approach* (6th ed.). <https://book.systemsapproach.org/foundation/requirements.html>

[^baran]: Baran, P. (1964). *On distributed communications: I. Introduction to distributed communications networks* (RM-3420-PR). RAND Corporation. <https://doi.org/10.7249/RM3420>

[^davies]: Internet Hall of Fame. (n.d.). Donald Davies (2012 inductee). <https://www.internethalloffame.org/inductee/donald-davies/>

[^ethwpacket]: Engineering and Technology History Wiki. (n.d.). Packet switching. <https://ethw.org/Packet_Switching>

[^leiner]: Leiner, B. M., Cerf, V. G., Clark, D. D., Kahn, R. E., Kleinrock, L., Lynch, D. C., Postel, J., Roberts, L. G., & Wolff, S. (1997). A brief history of the Internet. *Internet Society*. <https://www.internetsociety.org/internet/history-internet/brief-history-internet/>

[^cerfkahn]: Cerf, V. G., & Kahn, R. E. (1974). A protocol for packet network intercommunication. *IEEE Transactions on Communications*, 22(5), 637–648. <https://doi.org/10.1109/TCOM.1974.1092259>

[^lo]: Kleinrock, L. (n.d.). The day the infant Internet uttered its first words. *UCLA*. <https://www.lk.cs.ucla.edu/internet_first_words.html>

[^ipv4]: Postel, J. (1981). *Internet Protocol* (RFC 791). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0791>

[^rfc793]: Postel, J. (1981). *Transmission Control Protocol* (RFC 793, obsoleted by RFC 9293). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0793>

[^ncptcp]: Postel, J. (1981). *NCP/TCP transition plan* (RFC 801). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0801>

[^bsd]: McKusick, M. K. (1999). Twenty years of Berkeley Unix: From AT&T-owned to freely redistributable. In C. DiBona, S. Ockman, & M. Stone (Eds.), *Open sources: Voices from the open source revolution*. O'Reilly. <https://www.oreilly.com/openbook/opensources/book/kirkmck.html>

[^ipc]: Leffler, S. J., Fabry, R. S., Joy, W. N., Lapsley, P., Miller, S., & Torek, C. (n.d.). *An advanced 4.4BSD interprocess communication tutorial*. University of California, Berkeley. <https://docs-archive.freebsd.org/44doc/psd/21.ipc/paper.html>

[^rfc882]: Mockapetris, P. (1983). *Domain names: Concepts and facilities* (RFC 882, obsoleted by RFC 1034). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0882>

[^jacobson]: Jacobson, V. (1988). Congestion avoidance and control. *Proceedings of the ACM SIGCOMM '88 Symposium on Communications Architectures and Protocols*, 314–329. <https://doi.org/10.1145/52324.52356>

[^congestion]: Allman, M., Paxson, V., & Blanton, E. (2009). *TCP congestion control* (RFC 5681). Internet Engineering Task Force. <https://doi.org/10.17487/RFC5681>

[^rfc1519]: Fuller, V., Li, T., Yu, J., & Varadhan, K. (1993). *Classless Inter-Domain Routing (CIDR): An address assignment and aggregation strategy* (RFC 1519, obsoleted by RFC 4632). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1519>

[^rfc1631]: Egevang, K., & Francis, P. (1994). *The IP Network Address Translator (NAT)* (RFC 1631, obsoleted by RFC 3022). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1631>

[^rfc1883]: Deering, S., & Hinden, R. (1995). *Internet Protocol, Version 6 (IPv6) specification* (RFC 1883, obsoleted by RFC 2460 and then RFC 8200). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1883>

[^ipv6]: Deering, S., & Hinden, R. (2017). *Internet Protocol, Version 6 (IPv6) specification* (RFC 8200). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8200>

[^exhaustion]: Number Resource Organization. (2011, February 3). Free pool of IPv4 address space depleted. <https://www.nro.net/ipv4-free-pool-depleted/>

[^zimmermann]: Zimmermann, H. (1980). OSI reference model: The ISO model of architecture for open systems interconnection. *IEEE Transactions on Communications*, 28(4), 425–432. <https://doi.org/10.1109/TCOM.1980.1094702>

[^russell]: Russell, A. L. (2013). The internet that wasn't [Online as "OSI: The Internet that wasn't"]. *IEEE Spectrum*, 50(8), 39–43. <https://doi.org/10.1109/MSPEC.2013.6565559>

[^cernweb]: CERN. (n.d.). A short history of the Web. <https://home.cern/science/computing/the-birth-of-the-web/short-history-web>

[^rfc7540]: Belshe, M., Peon, R., & Thomson, M. (Ed.). (2015). *Hypertext Transfer Protocol Version 2 (HTTP/2)* (RFC 7540, obsoleted by RFC 9113). Internet Engineering Task Force. <https://doi.org/10.17487/RFC7540>

[^rfc8446]: Rescorla, E. (2018). *The Transport Layer Security (TLS) Protocol Version 1.3* (RFC 8446, obsoleted by RFC 9846). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8446>

[^quic]: Iyengar, J., & Thomson, M. (Eds.). (2021). *QUIC: A UDP-based multiplexed and secure transport* (RFC 9000). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9000>

[^http3]: Bishop, M. (Ed.). (2022). *HTTP/3* (RFC 9114). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9114>

[^tls13]: Rescorla, E. (2026). *The Transport Layer Security (TLS) Protocol Version 1.3* (RFC 9846). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9846>

[^x200]: ITU-T. (1994). *Information technology – Open Systems Interconnection – Basic Reference Model: The basic model* (ITU-T Recommendation X.200; identical to ISO/IEC 7498-1:1994). International Telecommunication Union. <https://www.itu.int/rec/T-REC-X.200-199407-I/en>

[^rfc1122]: Braden, R. (Ed.). (1989). *Requirements for Internet hosts: Communication layers* (RFC 1122). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1122>

[^rfc1123]: Braden, R. (Ed.). (1989). *Requirements for Internet hosts: Application and support* (RFC 1123). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1123>

[^rfc3439]: Bush, R., & Meyer, D. (2002). *Some Internet architectural guidelines and philosophy* (RFC 3439). Internet Engineering Task Force. <https://doi.org/10.17487/RFC3439>

[^rfc1180]: Socolofsky, T., & Kale, C. (1991). *TCP/IP tutorial* (RFC 1180). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1180>

[^metcalfe]: Metcalfe, R. M., & Boggs, D. R. (1976). Ethernet: Distributed packet switching for local computer networks. *Communications of the ACM*, 19(7), 395–404. <https://doi.org/10.1145/360248.360253>

[^pethernet]: Peterson, L. L., & Davie, B. S. (n.d.). Multi-access networks. In *Computer networks: A systems approach* (6th ed.). <https://book.systemsapproach.org/direct/ethernet.html>

[^ieee8023]: IEEE. (2022). *IEEE standard for Ethernet* (IEEE Std 802.3-2022). <https://doi.org/10.1109/IEEESTD.2022.9844436>

[^ieee80211]: IEEE. (2025). *IEEE standard for information technology—Telecommunications and information exchange between systems—Local and metropolitan area networks—Specific requirements—Part 11: Wireless LAN medium access control (MAC) and physical layer (PHY) specifications* (IEEE Std 802.11-2024). <https://doi.org/10.1109/IEEESTD.2025.10979691>

[^arp]: Plummer, D. (1982). *An Ethernet Address Resolution Protocol: Or converting network protocol addresses to 48.bit Ethernet address for transmission on Ethernet hardware* (RFC 826). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0826>

[^rfc894]: Hornig, C. (1984). *A standard for the transmission of IP datagrams over Ethernet networks* (RFC 894). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0894>

[^pswitched]: Peterson, L. L., & Davie, B. S. (n.d.). Switched Ethernet. In *Computer networks: A systems approach* (6th ed.). <https://book.systemsapproach.org/internetworking/ethernet.html>

[^rfc4861]: Narten, T., Nordmark, E., Simpson, W., & Soliman, H. (2007). *Neighbor Discovery for IP version 6 (IPv6)* (RFC 4861). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4861>

[^clark88]: Clark, D. D. (1988). The design philosophy of the DARPA Internet protocols. *Proceedings of the ACM SIGCOMM '88 Symposium on Communications Architectures and Protocols*, 106–114. <https://doi.org/10.1145/52324.52336>

[^e2e]: Saltzer, J. H., Reed, D. P., & Clark, D. D. (1984). End-to-end arguments in system design. *ACM Transactions on Computer Systems*, 2(4), 277–288. <https://doi.org/10.1145/357401.357402>

[^cidr]: Fuller, V., & Li, T. (2006). *Classless Inter-domain Routing (CIDR): The Internet address assignment and aggregation plan* (RFC 4632). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4632>

[^pyipaddress]: Python Software Foundation. (n.d.). ipaddress: IPv4/IPv6 manipulation library. In *Python 3.14 documentation*. <https://docs.python.org/3.14/library/ipaddress.html>

[^rfc1918]: Rekhter, Y., Moskowitz, B., Karrenberg, D., de Groot, G. J., & Lear, E. (1996). *Address allocation for private internets* (RFC 1918). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1918>

[^ianav4]: IANA. (2025). *IANA IPv4 special-purpose address registry*. <https://www.iana.org/assignments/iana-ipv4-special-registry/>

[^rfc5737]: Arkko, J., Cotton, M., & Vegoda, L. (2010). *IPv4 address blocks reserved for documentation* (RFC 5737). Internet Engineering Task Force. <https://doi.org/10.17487/RFC5737>

[^dhcp]: Droms, R. (1997). *Dynamic Host Configuration Protocol* (RFC 2131). Internet Engineering Task Force. <https://doi.org/10.17487/RFC2131>

[^rfc1812]: Baker, F. (Ed.). (1995). *Requirements for IP version 4 routers* (RFC 1812). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1812>

[^ospf]: Moy, J. (1998). *OSPF version 2* (RFC 2328). Internet Engineering Task Force. <https://doi.org/10.17487/RFC2328>

[^bgp]: Rekhter, Y. (Ed.), Li, T. (Ed.), & Hares, S. (Ed.). (2006). *A Border Gateway Protocol 4 (BGP-4)* (RFC 4271). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4271>

[^icmp]: Postel, J. (1981). *Internet Control Message Protocol* (RFC 792). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0792>

[^pmtud]: Mogul, J., & Deering, S. (1990). *Path MTU discovery* (RFC 1191). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1191>

[^tracert]: Microsoft. (n.d.). tracert. In *Windows commands*. Microsoft Learn. <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/tracert>

[^rfc2923]: Lahey, K. (2000). *TCP problems with path MTU discovery* (RFC 2923). Internet Engineering Task Force. <https://doi.org/10.17487/RFC2923>

[^nat]: Srisuresh, P., & Egevang, K. (2001). *Traditional IP Network Address Translator (Traditional NAT)* (RFC 3022). Internet Engineering Task Force. <https://doi.org/10.17487/RFC3022>

[^stun]: Petit-Huguenin, M., Salgueiro, G., Rosenberg, J., Wing, D., Mahy, R., & Matthews, P. (2020). *Session Traversal Utilities for NAT (STUN)* (RFC 8489). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8489>

[^ice]: Keranen, A., Holmberg, C., & Rosenberg, J. (2018). *Interactive Connectivity Establishment (ICE): A protocol for Network Address Translator (NAT) traversal* (RFC 8445). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8445>

[^rfc4787]: Audet, F. (Ed.), & Jennings, C. (2007). *Network Address Translation (NAT) behavioral requirements for unicast UDP* (RFC 4787). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4787>

[^ipv6addr]: Hinden, R., & Deering, S. (2006). *IP version 6 addressing architecture* (RFC 4291). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4291>

[^slaac]: Thomson, S., Narten, T., & Jinmei, T. (2007). *IPv6 stateless address autoconfiguration* (RFC 4862). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4862>

[^rfc8981]: Gont, F., Krishnan, S., Narten, T., & Draves, R. (2021). *Temporary address extensions for stateless address autoconfiguration in IPv6* (RFC 8981). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8981>

[^ianav6]: IANA. (2025). *IANA IPv6 special-purpose address registry*. <https://www.iana.org/assignments/iana-ipv6-special-registry/>

[^googlev6]: Google. (n.d.). IPv6 adoption statistics. Retrieved October 20, 2026, from <https://www.google.com/intl/en/ipv6/statistics.html>

[^happyeyeballs]: Schinazi, D., & Pauly, T. (2017). *Happy Eyeballs version 2: Better connectivity using concurrency* (RFC 8305). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8305>

[^rfc6335]: Cotton, M., Eggert, L., Touch, J., Westerlund, M., & Cheshire, S. (2011). *Internet Assigned Numbers Authority (IANA) procedures for the management of the Service Name and Transport Protocol Port Number registry* (RFC 6335). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6335>

[^ianaports]: IANA. (2026). *Service name and transport protocol port number registry*. <https://www.iana.org/assignments/service-names-port-numbers/>

[^windowsports]: Microsoft. (2026). The default dynamic port range for TCP/IP has changed in Windows Vista and in Windows Server 2008. *Microsoft Learn*. <https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/default-dynamic-port-range-tcpip-chang>

[^ipsysctl]: The Linux kernel documentation. (n.d.). IP sysctl. <https://docs.kernel.org/networking/ip-sysctl.html>

[^rfc6056]: Larsen, M., & Gont, F. (2011). *Recommendations for transport-protocol port randomization* (RFC 6056). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6056>

[^udp]: Postel, J. (1980). *User Datagram Protocol* (RFC 768). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0768>

[^rfc8085]: Eggert, L., Fairhurst, G., & Shepherd, G. (2017). *UDP usage guidelines* (RFC 8085). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8085>

[^tcp]: Eddy, W. (Ed.). (2022). *Transmission Control Protocol (TCP)* (RFC 9293). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9293>

[^tcp7]: Linux man-pages project. (2026). *tcp(7)* (man-pages 6.19). <https://man7.org/linux/man-pages/man7/tcp.7.html>

[^rto]: Paxson, V., Allman, M., Chu, J., & Sargent, M. (2011). *Computing TCP's retransmission timer* (RFC 6298). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6298>

[^iw10]: Chu, J., Dukkipati, N., Cheng, Y., & Mathis, M. (2013). *Increasing TCP's initial window* (RFC 6928). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6928>

[^cubic]: Xu, L., Ha, S., Rhee, I., Goel, V., & Eggert, L. (Ed.). (2023). *CUBIC for fast and long-distance networks* (RFC 9438). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9438>

[^bbr]: Cardwell, N., Cheng, Y., Gunn, C. S., Yeganeh, S. H., & Jacobson, V. (2016). BBR: Congestion-based congestion control. *ACM Queue*, 14(5), 20–53. <https://doi.org/10.1145/3012426.3022184>

[^tcph]: The Linux kernel. (n.d.). include/net/tcp.h: TCP_TIMEWAIT_LEN. <https://github.com/torvalds/linux/blob/master/include/net/tcp.h>

[^pysocket]: Python Software Foundation. (n.d.). socket: Low-level networking interface. In *Python 3.14 documentation*. <https://docs.python.org/3.14/library/socket.html>

[^socket7]: Linux man-pages project. (2026). *socket(7)* (man-pages 6.19). <https://man7.org/linux/man-pages/man7/socket.7.html>

[^http11]: Fielding, R. (Ed.), Nottingham, M. (Ed.), & Reschke, J. (Ed.). (2022). *HTTP/1.1* (RFC 9112). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9112>

[^pystruct]: Python Software Foundation. (n.d.). struct: Interpret bytes as packed binary data. In *Python 3.14 documentation*. <https://docs.python.org/3.14/library/struct.html>

[^nagle]: Nagle, J. (1984). *Congestion control in IP/TCP internetworks* (RFC 896). Internet Engineering Task Force. <https://doi.org/10.17487/RFC0896>

[^http2]: Thomson, M. (Ed.), & Benfield, C. (Ed.). (2022). *HTTP/2* (RFC 9113). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9113>

[^quictls]: Thomson, M. (Ed.), & Turner, S. (Ed.). (2021). *Using TLS to secure QUIC* (RFC 9001). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9001>

[^quicrecovery]: Iyengar, J. (Ed.), & Swett, I. (Ed.). (2021). *QUIC loss detection and congestion control* (RFC 9002). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9002>

[^dns]: Mockapetris, P. (1987). *Domain names: Concepts and facilities* (RFC 1034). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1034>

[^dnsimpl]: Mockapetris, P. (1987). *Domain names: Implementation and specification* (RFC 1035). Internet Engineering Task Force. <https://doi.org/10.17487/RFC1035>

[^ianaroot]: IANA. (n.d.). Root servers. <https://www.iana.org/domains/root/servers>

[^rootservers]: Root Server Operators. (n.d.). Root server technical operations. Retrieved October 20, 2026, from <https://root-servers.org/>

[^ipv6dns]: Thomson, S., Huitema, C., Ksinant, V., & Souissi, M. (2003). *DNS extensions to support IP version 6* (RFC 3596). Internet Engineering Task Force. <https://doi.org/10.17487/RFC3596>

[^edns]: Damas, J., Graff, M., & Vixie, P. (2013). *Extension mechanisms for DNS (EDNS(0))* (RFC 6891). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6891>

[^dnssec]: Arends, R., Austein, R., Larson, M., Massey, D., & Rose, S. (2005). *DNS security introduction and requirements* (RFC 4033). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4033>

[^dot]: Hu, Z., Zhu, L., Heidemann, J., Mankin, A., Wessels, D., & Hoffman, P. (2016). *Specification for DNS over Transport Layer Security (TLS)* (RFC 7858). Internet Engineering Task Force. <https://doi.org/10.17487/RFC7858>

[^doh]: Hoffman, P., & McManus, P. (2018). *DNS queries over HTTPS (DoH)* (RFC 8484). Internet Engineering Task Force. <https://doi.org/10.17487/RFC8484>

[^posixgai]: The IEEE and The Open Group. (2024). freeaddrinfo, getaddrinfo. In *The Open Group Base Specifications Issue 8* (IEEE Std 1003.1-2024). <https://pubs.opengroup.org/onlinepubs/9799919799/functions/getaddrinfo.html>

[^http]: Fielding, R. (Ed.), Nottingham, M. (Ed.), & Reschke, J. (Ed.). (2022). *HTTP semantics* (RFC 9110). Internet Engineering Task Force. <https://doi.org/10.17487/RFC9110>

[^hpack]: Peon, R., & Ruellan, H. (2015). *HPACK: Header compression for HTTP/2* (RFC 7541). Internet Engineering Task Force. <https://doi.org/10.17487/RFC7541>

[^altsvc]: Nottingham, M., McManus, P., & Reschke, J. (2016). *HTTP alternative services* (RFC 7838). Internet Engineering Task Force. <https://doi.org/10.17487/RFC7838>

[^x509]: Cooper, D., Santesson, S., Farrell, S., Boeyen, S., Housley, R., & Polk, W. (2008). *Internet X.509 public key infrastructure certificate and certificate revocation list (CRL) profile* (RFC 5280). Internet Engineering Task Force. <https://doi.org/10.17487/RFC5280>

[^sni]: Eastlake 3rd, D. (2011). *Transport Layer Security (TLS) extensions: Extension definitions* (RFC 6066). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6066>

[^pyssl]: Python Software Foundation. (n.d.). ssl: TLS/SSL wrapper for socket objects. In *Python 3.14 documentation*. <https://docs.python.org/3.14/library/ssl.html>

[^ntp]: Mills, D., Martin, J. (Ed.), Burbank, J., & Kasch, W. (2010). *Network Time Protocol version 4: Protocol and algorithms specification* (RFC 5905). Internet Engineering Task Force. <https://doi.org/10.17487/RFC5905>

[^smtp]: Klensin, J. (2008). *Simple Mail Transfer Protocol* (RFC 5321). Internet Engineering Task Force. <https://doi.org/10.17487/RFC5321>

[^ssh]: Ylonen, T., & Lonvick, C. (Ed.). (2006). *The Secure Shell (SSH) transport layer protocol* (RFC 4253). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4253>

[^websocket]: Fette, I., & Melnikov, A. (2011). *The WebSocket protocol* (RFC 6455). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6455>

[^mdns]: Cheshire, S., & Krochmal, M. (2013). *Multicast DNS* (RFC 6762). Internet Engineering Task Force. <https://doi.org/10.17487/RFC6762>

[^posixsocket]: The IEEE and The Open Group. (2024). socket. In *The Open Group Base Specifications Issue 8* (IEEE Std 1003.1-2024). <https://pubs.opengroup.org/onlinepubs/9799919799/functions/socket.html>

[^pperf]: Peterson, L. L., & Davie, B. S. (n.d.). Performance. In *Computer networks: A systems approach* (6th ed.). <https://book.systemsapproach.org/foundation/performance.html>

[^curl]: curl project. (n.d.). curl man page: --write-out. <https://curl.se/docs/manpage.html#-w>

[^synflood]: Eddy, W. (2007). *TCP SYN flooding attacks and common mitigations* (RFC 4987). Internet Engineering Task Force. <https://doi.org/10.17487/RFC4987>

[^robustness]: Thomson, M., & Schinazi, D. (2023). *Maintaining robust protocols* (RFC 9413). Internet Architecture Board. <https://doi.org/10.17487/RFC9413>

[^tcpdump]: The Tcpdump Group. (2026). *tcpdump(1) manual page*. <https://www.tcpdump.org/manpages/tcpdump.1.html>

[^wireshark]: Sharpe, R., Warnicke, E., & Lamping, U. (n.d.). *Wireshark user's guide*. <https://www.wireshark.org/docs/wsug_html_chunked/>

[^fallacies]: Rotem-Gal-Oz, A. (2006). *Fallacies of distributed computing explained* [Archived]. <http://web.archive.org/web/20070929150539/http://www.rgoarchitects.com/Files/fallacies.pdf>

[^rfc2068]: Fielding, R., Gettys, J., Mogul, J., Frystyk, H., & Berners-Lee, T. (1997). *Hypertext Transfer Protocol -- HTTP/1.1* (RFC 2068, obsoleted by RFC 2616). Internet Engineering Task Force. <https://doi.org/10.17487/RFC2068>

[^ip7]: Linux man-pages project. (2026). *ip(7)* (man-pages 6.19). <https://man7.org/linux/man-pages/man7/ip.7.html>

[^tls12]: Dierks, T., & Rescorla, E. (2008). *The Transport Layer Security (TLS) Protocol Version 1.2* (RFC 5246, obsoleted by RFC 8446 and RFC 9846). Internet Engineering Task Force. <https://doi.org/10.17487/RFC5246>
