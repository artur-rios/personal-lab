---
title: "What Are Data Structures? From Arrays to Hash Tables, and How to Choose One"
description: "A data structure is a way of arranging data in memory so that the operations a program needs are fast. Here is what that means, where the classic structures came from, how each one works, what it costs, and how to choose between them."
date: 2026-10-20T16:30:00Z
categories: ["Fundamentals"]
tags: ["Data Structures", "Algorithms", "Complexity", "Computer Science", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Niklaus Wirth titled a 1976 book *Algorithms + Data Structures =
Programs*,[^wirth] and [What Is Programming?]({{< ref "what-is-programming" >}})
quoted it: choosing how to represent information is as much a part of
programming as choosing the steps that work on it. This article is about the
second half of that equation. It explains what a data structure is, where the
classic ones came from, how each works and what it costs, and how to choose
between them. The examples were run with Python 3.10 on an Intel Core
i9-13900K, and their output is shown exactly as printed.

## What a data structure is

**A data structure is a way of organising data in memory so that the operations
a program needs to perform on it are efficient.**

The same data can be stored in many ways, and each way makes some operations
cheap and others expensive. A list of a million names kept in sorted order
makes it quick to find a name, but slow to add one in the middle. The same
names in a hash table make finding *and* adding fast, but give up the order.
There is no best data structure, only the best one for a particular mix of
operations.

### Abstract data types and their implementations

It helps to separate *what* a structure offers from *how* it does it.

- An **abstract data type (ADT)** is defined only by its operations and their
  behaviour: a *stack* lets you push an item and pop the most recent one; a
  *map* associates keys with values and lets you look a key up. Barbara Liskov
  and Stephen Zilles described programming with abstract data types in
  1974, as a way to hide a representation behind the operations on
  it.[^liskov]
- A **data structure** is a concrete representation that implements an ADT.
  A map can be implemented with a hash table, a balanced tree or a sorted
  array; all three offer the same operations at very different costs.

| Abstract data type | Operations | Common implementations |
|---|---|---|
| **List / sequence** | Get or set the *i*-th item, append, insert, remove | Dynamic array, linked list |
| **Stack** | Push, pop the most recent | Dynamic array, linked list |
| **Queue / deque** | Add at one end, remove at the other (or both) | Ring buffer, linked list |
| **Map (dictionary)** | Put, get and delete by key | Hash table, balanced search tree |
| **Set** | Add, remove, test membership | Hash table, balanced search tree, bitset |
| **Priority queue** | Insert, remove the smallest (or largest) | Binary heap |
| **Graph** | Vertices, edges, neighbours of a vertex | Adjacency lists, adjacency matrix |

### Measuring cost

Data structures are compared by how their costs grow with the amount of data,
*n*, using **big-O notation**: O(*f*(*n*)) means "grows no faster than *f*(*n*),
up to a constant factor". In a 1976 note Donald Knuth proposed the Ω and Θ
notation that, together with O, computer science now uses for upper, lower and
tight bounds.[^knuthbigo]

| Cost | Name | Steps for *n* = 1,000,000 | Example |
|---|---|---|---|
| O(1) | Constant | 1 | Reading `array[i]`; a hash table lookup on average |
| O(log *n*) | Logarithmic | about 20 | Searching a balanced tree or a sorted array |
| O(*n*) | Linear | 1,000,000 | Scanning a list for a value |
| O(*n* log *n*) | Linearithmic | about 20,000,000 | Sorting, or building a balanced tree |
| O(*n*²) | Quadratic | 1,000,000,000,000 | Comparing every pair |

Two refinements matter in practice:

- **Amortised cost** is the average cost per operation over a long sequence,
  even if individual operations are occasionally expensive. Robert Tarjan's
  1985 survey formalised and popularised the idea;[^tarjanamortized] a dynamic
  array's append is the classic example, below.[^clrs]
- **Constant factors and memory layout** are hidden by big-O but often decide
  real performance. A processor reads memory in cache lines of, typically, 64
  bytes, so data stored contiguously is far faster to walk than data scattered
  through memory ([What Is a Processor?]({{< ref "processors" >}}) explains
  why).[^clrs]

## A history of data structures

### The 1950s: arrays, lists and stacks

The **array**, a block of consecutive memory cells addressed by index, is as old
as the stored-program computer. FORTRAN (1957) brought it into a high-level
language as the "subscripted variable", declared with `DIMENSION`.[^backus57]

The **linked list** came from artificial-intelligence research. Allen Newell,
Cliff Shaw and Herbert Simon built list processing into their IPL languages
for the Logic Theory Machine from 1956, so that a program could build
structures whose size and shape were not known in advance.[^newell][^taocp1]
John McCarthy made the list the central structure of **LISP** in
1960.[^mccarthy]

The **stack** became a fundamental structure through compiling. Friedrich Bauer
and Klaus Samelson developed their stack method of evaluating expressions, the
*Keller* (cellar) principle, in 1955,[^bauerpioneer] and published it as
"sequential formula translation" in 1959–60.[^samelson]

### Hash tables

Hashing, computing a storage location directly from a key, appeared in the
1950s. Knuth traces it to an internal IBM memorandum by Hans Peter Luhn in 1953,
which used chaining. **Open addressing**, in which colliding keys are placed
elsewhere in the same table, was first used by Gene Amdahl's team at IBM, and
W. Wesley Peterson's 1957 paper defined and analysed it in
general.[^taocp3][^peterson] The word "hashing" did not appear in print until
1967; Robert Morris's influential 1968 survey of scatter storage techniques then
set off a wave of research.[^taocp3][^morris]

### The 1960s and 1970s: trees

Sorted data led to **trees**. Binary search trees were developed independently
by several people around 1960.[^taocp3] In 1962 Georgy Adelson-Velsky and Evgenii Landis published
the **AVL tree**, the first search tree that rebalances itself to stay
O(log *n*) deep however keys arrive.[^avl][^taocp3] René de la Briandais
(1959) and Edward Fredkin (1960), who coined the name from re*trie*val,
described the **trie**, a tree that branches on the characters of a
key.[^briandais][^fredkin]

J. W. J. Williams's **heapsort** (1964) introduced the binary heap, an array
that behaves like a tree and is still the standard priority queue.[^williams]
Rudolf Bayer and Edward McCreight's **B-tree** (a 1970 report, published 1972) adapted
balanced trees to disks, with wide nodes that each fill a disk
page;[^bayer72] by 1979 Douglas Comer could call it "ubiquitous".[^comer]
Leonidas Guibas and Robert Sedgewick's **red-black trees** (1978) gave a simpler
way to keep a binary tree balanced, building on Bayer's symmetric binary
B-trees.[^redblack][^bayersbb]

The same period produced structures for specific problems: Burton Bloom's
probabilistic **Bloom filter** (1970)[^bloom] and Tarjan's analysis of the
**union-find** (disjoint-set) structure (1975).[^unionfind]

### The 1980s to today: analysis, persistence and the memory hierarchy

The 1980s brought new kinds of analysis and structure: amortised analysis and
**splay trees** (1985), which reorganise themselves around recently used
keys;[^tarjanamortized][^splay] **Fibonacci heaps** (1987);[^fibheap] and
**persistent** data structures (1989), which keep every old version available
after an update.[^persistent] Chris Okasaki's *Purely Functional Data Structures*
(1998) showed how to make such structures efficient in functional
languages.[^okasaki] William Pugh's **skip list** (1990) offered a simpler,
randomised alternative to balanced trees.[^skiplist]

Since the 1990s, much of the work has been driven by the memory hierarchy and by
scale. The **log-structured merge tree** (1996) turned random writes into
sequential ones and now underlies many databases.[^lsm] **Cuckoo hashing**
(2001, journal version 2004) guaranteed constant-time lookups even in the worst
case,[^cuckoo] and Google's **Swiss tables** (2017) were built around cache
lines and SIMD instructions.[^swiss][^swissblog] Hash tables also became a
security concern. **Hash-flooding** attacks, which feed a table keys chosen to
collide, were described in 2003;[^crosby] in 2011 researchers showed that many
programming languages and web platforms were still vulnerable, which led
languages such as Python and Rust to adopt keyed hash functions like
**SipHash**.[^ocert][^hashdos][^siphash][^pep456][^rusthashmap]

## A timeline at a glance

| Year | Milestone |
|---|---|
| 1953 | Luhn's memorandum on hashing with chaining |
| 1955 | Bauer and Samelson's stack (*Keller*) principle |
| 1956–59 | Linked lists in Newell, Shaw and Simon's IPL |
| 1957 | Peterson analyses open addressing; FORTRAN's subscripted variables |
| 1959–60 | Sequential formula translation published; tries |
| 1960 | LISP |
| 1962 | AVL trees |
| 1964 | Binary heaps (heapsort) |
| 1967–68 | "Hashing" first in print; Morris's influential survey |
| 1970–72 | B-trees; Bloom filters |
| 1975 | Union-find analysed |
| 1978 | Red-black trees |
| 1985 | Amortised analysis; splay trees |
| 1987 | Fibonacci heaps |
| 1989 | Persistent data structures |
| 1990 | Skip lists |
| 1996 | Log-structured merge trees |
| 2001–04 | Cuckoo hashing |
| 2003 | Hash-flooding attacks described |
| 2011–12 | Hash flooding shown practical against many platforms; SipHash |
| 2017 | Swiss tables |

## The core structures

### Arrays and dynamic arrays

An **array** stores its elements side by side in one block of memory. Because
every element has the same size, the address of element *i* is simply the
start address plus *i* times that size, so any element can be read or written
in O(1) time. Arrays are also the most cache-friendly structure: walking one
reads memory in order, which is exactly what processors and their prefetchers
are built for.

{{< diagram src="array-vs-list.svg" caption="The same kind of data as an array and as a linked list. The array's position is arithmetic; the list's is a chain of pointers." >}}

A plain array has a fixed size. A **dynamic array** (Python's `list`, Java's
`ArrayList`, C++'s `std::vector`, Rust's `Vec`) keeps a larger hidden
**capacity** and, when it runs out, allocates a bigger block and copies the
elements across. Copying is O(*n*), but because the capacity grows in
proportion to the size, it happens rarely enough that appending costs O(1)
**amortised**.[^clrs] You can watch CPython do it:

```python
import sys

items = []
last = sys.getsizeof(items)
print(f"len   0: {last} bytes")
for i in range(64):
    items.append(i)
    size = sys.getsizeof(items)
    if size != last:          # the list just grew its hidden capacity
        print(f"len {len(items):3}: {size} bytes")
        last = size
```

```txt
len   0: 56 bytes
len   1: 88 bytes
len   5: 120 bytes
len   9: 184 bytes
len  17: 248 bytes
len  25: 312 bytes
len  33: 376 bytes
len  41: 472 bytes
len  53: 568 bytes
```

Each pointer takes 8 bytes, so the capacity goes 4, 8, 16, 24, 32, 40, 52, 64:
CPython over-allocates by about an eighth of the new size plus a small
constant.[^cpythonlist] Java's `ArrayList` grows by half its current
capacity.[^arraylist] The exact factor is a trade-off between wasted space and
how often to copy.

| Operation | Array / dynamic array |
|---|---|
| Read or write element *i* | O(1) |
| Append at the end | O(1) amortised |
| Insert or delete in the middle | O(*n*): everything after it shifts |
| Search for a value | O(*n*), or O(log *n*) by binary search if sorted |

### Linked lists

A **linked list** stores each element in its own **node**, together with a
pointer to the next node (a *doubly* linked list also points back to the
previous one). Nodes can be anywhere in memory.

The advantage is cheap structural change: given a pointer to a node, inserting
or removing next to it is O(1), with no shifting. The disadvantages are severe
on modern hardware: reaching the *k*-th element means following *k* pointers,
each node carries the overhead of its pointers, and every hop is likely a cache
miss. In practice a dynamic array is usually the faster default, often even
for workloads with many middle insertions, because finding the insertion point
means walking the list, and cache misses dominate.[^stroustrup] Linked lists
earn their place inside other
structures, such as the hash-map-plus-list of an LRU cache shown later, or in
systems code where nodes cannot be moved.

### Stacks, queues and deques

These three abstract types restrict *where* items can be added and removed:

- A **stack** is last in, first out (LIFO): push and pop at the same end. It is
  how programs track function calls (the *call stack*), how parsers handle
  nested brackets, and how undo works.
- A **queue** is first in, first out (FIFO): add at the back, remove from the
  front. It is the shape of every buffer, job queue and breadth-first search.
- A **deque** (double-ended queue) allows both at both ends.

A stack is naturally a dynamic array used at one end. A queue is usually a
**ring buffer**: an array with head and tail indexes that wrap around, so
neither end ever has to shift. Python's `collections.deque` provides
approximately O(1) appends and pops at either end, using a linked list of
fixed-size blocks rather than a single ring buffer.[^pydeque]

### Hash tables

A **hash table** implements a map or set with O(1) average-time insert, lookup
and delete. A **hash function** turns each key into a number, and that number,
reduced modulo the table's size, picks a **bucket**. A good hash function
spreads keys evenly, so each bucket holds few keys.

Two different keys can land in the same bucket, a **collision**, and there are
two main ways to handle it:[^taocp3][^clrs]

{{< diagram src="hash-table.svg" caption="The two main collision strategies, with illustrative bucket numbers. Chaining keeps a list per bucket; open addressing keeps every key in the array and probes for a free slot." >}}

- **Separate chaining** keeps a small list in each bucket. Java's `HashMap`
  works this way, and since Java 8 turns a bucket that grows too long into a
  small balanced tree.[^jep180]
- **Open addressing** stores every key in the array itself; on a collision it
  probes other slots in a fixed sequence until it finds a free one. Python's
  `dict` uses open addressing,[^dictobject] as do Swiss tables, which inspect
  a group of slots at once with SIMD instructions.[^swiss]

The **load factor** is the number of keys divided by the number of buckets. As
it rises, collisions multiply, so tables **resize**, typically doubling and
re-inserting every key, when it passes a threshold. Like a dynamic array's
growth, this keeps the amortised cost O(1). Here is a complete hash map with
chaining and resizing:

```python
class HashTable:
    """A hash map with separate chaining that doubles when it gets crowded."""

    def __init__(self, capacity=8):
        self.buckets = [[] for _ in range(capacity)]
        self.size = 0

    def _bucket(self, key):
        return self.buckets[hash(key) % len(self.buckets)]

    def put(self, key, value):
        bucket = self._bucket(key)
        for i, (k, _) in enumerate(bucket):
            if k == key:                      # key already present: replace it
                bucket[i] = (key, value)
                return
        bucket.append((key, value))
        self.size += 1
        if self.size > 0.75 * len(self.buckets):   # load factor above 3/4
            self._resize(2 * len(self.buckets))

    def get(self, key):
        for k, v in self._bucket(key):
            if k == key:
                return v
        raise KeyError(key)

    def _resize(self, capacity):
        old = self.buckets
        self.buckets = [[] for _ in range(capacity)]
        for bucket in old:                    # every key moves to a new bucket
            for k, v in bucket:
                self._bucket(k).append((k, v))


table = HashTable()
for word in "the quick brown fox jumps over the lazy dog".split():
    table.put(word, len(word))
print(table.get("quick"), table.size, len(table.buckets))   # 5 8 16
```

The sentence has nine words but eight distinct ones; the seventh distinct word
pushed the load factor past three-quarters and doubled the table from 8 to 16
buckets.

The difference from a linear scan is dramatic. Testing whether the last of a
million integers is present:

```python
import timeit

n = 1_000_000
as_list = list(range(n))
as_set = set(as_list)

for name, data in (("list", as_list), ("set", as_set)):
    seconds = timeit.timeit(lambda: n - 1 in data, number=100) / 100
    print(f"{name:4}: {seconds * 1e6:10.3f} microseconds per lookup")
```

```txt
list:   3198.926 microseconds per lookup
set :      0.055 microseconds per lookup
```

In this run on this machine the set, a hash table, answered about 58,000 times
faster; a second run gave about 70,000. The exact figure varies, but the gap
is always tens of thousands of times.

Hash tables have two weaknesses. They keep no order, so "the next key after
*x*" or "all keys between *a* and *b*" requires a tree instead. And their O(1) is
an *average*: if many keys collide, operations degrade to O(*n*). Attackers can
cause this on purpose, as Scott Crosby and Dan Wallach showed in 2003;[^crosby]
in 2011 Alexander Klink and Julian Wälde showed it still worked against many
platforms,
by sending web servers request parameters crafted to collide, so that a single
HTTP request could keep a server's CPU busy for minutes or even hours.[^ocert][^hashdos] The fix was keyed hash functions such as
SipHash, whose output an attacker cannot predict; Python adopted it in version
3.4.[^siphash][^pep456]

### Trees

A **binary search tree (BST)** keeps keys in order: everything in a node's left
subtree is smaller than the node's key, and everything in its right subtree is
larger. Searching compares the target with the node and moves left or right,
discarding half of what remains at each step if the tree is balanced.

{{< diagram src="bst.svg" caption="A balanced binary search tree. Searching for 6 follows one path from the root, comparing at each node." >}}

The catch is the word *balanced*. Insert keys in sorted order into a plain BST
and it degenerates into a linked list, with O(*n*) searches. **Self-balancing**
trees restore their shape after every insertion and deletion with small local
rearrangements called **rotations**:

- **AVL trees** keep the heights of every node's two subtrees within one of each
  other.[^avl]
- **Red-black trees** colour each node red or black and keep rules on the colours
  that bound the height at about twice the minimum. They need fewer rotations
  than AVL trees in the worst case, and are what Java's `TreeMap`
  uses.[^redblack][^treemap]

Balanced trees give O(log *n*) insert, delete and lookup *and* keep the keys
sorted, so they also answer range queries and "next larger key" efficiently,
which hash tables cannot.

**B-trees** generalise the idea for storage devices. Reading from disk, or even
from main memory, costs far more than comparing keys, so each B-tree node holds
many keys and has many children, sized to fill a disk page. The tree is
therefore very wide and very shallow, and finding any key among millions
takes only a handful of page reads.[^bayer72][^comer]

{{< diagram src="btree.svg" caption="A small B-tree. Each node holds several sorted keys; the keys in a node separate the ranges covered by its children." >}}

B-trees and their variants are the standard index structure of relational
databases and many file systems. SQLite, for example, keeps a separate B-tree
for each table and each index; table B-trees hold all the row data in their
leaves.[^sqlitearch][^sqlite]

A **trie** (prefix tree) branches on the characters of its keys instead of
comparing whole keys, so looking up a word of length *k* takes O(*k*) steps
regardless of how many words are stored, and all words with a given prefix sit
in one subtree. Tries power autocompletion and the longest-prefix matching that
routers use to forward packets; Linux's routing table, for example, is a
compressed trie.[^fredkin][^fibtrie]

### Heaps and priority queues

A **priority queue** always hands back its smallest (or largest) item. The
standard implementation is the **binary heap**: a complete binary tree in which
every parent is no larger than its children. Because the tree is complete, it
needs no pointers at all; it is stored level by level in an array, and the
children of the item at index *i* sit at 2*i* + 1 and 2*i* + 2.[^williams][^clrs]

{{< diagram src="heap.svg" caption="A min-heap as a tree and as the array that stores it. The smallest item is always at index 0." >}}

Inserting adds the item at the end and swaps it upward while it is smaller than
its parent; removing the minimum moves the last item to the root and swaps it
downward. Both take O(log *n*), and reading the minimum is O(1). Python's
`heapq` module works directly on a list:[^heapq]

```python
import heapq

tasks = []
heapq.heappush(tasks, (3, "write tests"))
heapq.heappush(tasks, (1, "fix the outage"))
heapq.heappush(tasks, (2, "review the PR"))
print(tasks)                      # the heap, stored as a plain list
while tasks:
    print(heapq.heappop(tasks))   # always the smallest priority first
```

```txt
[(1, 'fix the outage'), (3, 'write tests'), (2, 'review the PR')]
(1, 'fix the outage')
(2, 'review the PR')
(3, 'write tests')
```

The list itself is not sorted, only heap-ordered, but the pops come out in
priority order. Priority queues drive schedulers, event simulations and
shortest-path algorithms.

### Graphs

A **graph** is a set of **vertices** joined by **edges**: road networks, social
networks, the dependencies between software packages, the links between web
pages. The two standard representations trade space for speed:[^clrs]

{{< diagram src="graph.svg" caption="The same graph as adjacency lists and as an adjacency matrix." >}}

| | Adjacency lists | Adjacency matrix |
|---|---|---|
| **Space** | O(*V* + *E*) | O(*V*²) |
| **Is there an edge from *u* to *v*?** | O(degree of *u*) | O(1) |
| **List the neighbours of *u*** | O(degree of *u*) | O(*V*) |
| **Best for** | Sparse graphs: most real ones | Dense graphs, or very fast edge tests |

Most graph algorithms are built from the structures above: breadth-first search
uses a queue, depth-first search a stack, and modern implementations of Edsger
Dijkstra's 1959 shortest-path algorithm a priority queue.[^dijkstra][^fibheap]

### Specialised structures

A few more structures solve particular problems so well that they appear
everywhere:

- A **Bloom filter** answers "is this item in the set?" using a small bit array
  and several hash functions. It can return false positives, but never false
  negatives, and uses far less memory than storing the items.[^bloom]
  Databases built on LSM trees use Bloom filters to skip files that cannot
  contain a key.[^rocksdbbloom]
- A **skip list** is a sorted linked list with extra "express lane" pointers
  chosen at random, giving O(log *n*) expected search with simple code.[^skiplist]
- **Union-find** tracks which elements belong to the same group, merging groups
  and answering "same group?" in nearly constant amortised time.[^unionfind]
- An **LSM tree** buffers writes in memory and flushes them to disk as sorted
  runs that are merged in the background, trading some read cost for very fast
  writes.[^lsm]
- **Persistent** structures never change in place: an update returns a new
  version that shares most of its structure with the old one, so every past
  version stays valid. They are the default in functional languages.[^persistent][^okasaki]

## A cost summary

Typical costs of the main operations, for *n* items:[^clrs]

| Structure | Access by index | Search | Insert | Delete | Ordered? |
|---|---|---|---|---|---|
| Dynamic array | O(1) | O(*n*) | O(1) amortised at end; O(*n*) elsewhere | O(1) at end; O(*n*) elsewhere | Insertion order |
| Sorted array | O(1) | O(log *n*) | O(*n*) | O(*n*) | Sorted |
| Linked list | O(*n*) | O(*n*) | O(1) at a known node | O(1) given the node (doubly linked) or its predecessor | Insertion order |
| Hash table | — | O(1) average, O(*n*) worst | O(1) average | O(1) average | No |
| Balanced search tree | — | O(log *n*) | O(log *n*) | O(log *n*) | Sorted |
| Binary heap | — | O(*n*); minimum in O(1) | O(log *n*) | Minimum in O(log *n*) | Partially |

## Choosing a data structure

Start from the operations the program performs most often, not from the data:

- **Mostly appending and iterating, or reading by position?** A dynamic array.
  It is the right default far more often than its O(*n*) middle insertions
  suggest.
- **Looking things up by key?** A hash table, unless you also need order.
- **Need keys in sorted order, ranges, or "the nearest key"?** A balanced search
  tree, or a B-tree for data on disk.
- **Always need the smallest or largest item next?** A heap.
- **Adding and removing at both ends?** A deque.
- **Relationships between things?** A graph, usually as adjacency lists.

Then measure. The constant factors and cache behaviour that big-O hides can
reverse a theoretical ranking, especially for small *n*.

Every mainstream language already provides the common structures, carefully
tuned. Each cell below names the standard type for that structure:

| | Python | Java | C++ | Go | Rust |
|---|---|---|---|---|---|
| **Dynamic array** | `list` | `ArrayList` | `std::vector` | slice | `Vec` |
| **Hash map** | `dict` | `HashMap` | `std::unordered_map` | `map` | `HashMap` |
| **Sorted map** | (none built in) | `TreeMap` | `std::map` | (none built in) | `BTreeMap` |
| **Deque** | `collections.deque` | `ArrayDeque` | `std::deque` | `container/list` | `VecDeque` |
| **Priority queue** | `heapq` | `PriorityQueue` | `std::priority_queue` | `container/heap` | `BinaryHeap` |

Their documentation describes the guarantees each one gives.[^pydatastructures][^javacollections][^rustcollections][^gocontainer][^golist][^cppcontainers]

## Putting it together: an LRU cache

Real programs combine structures to get the operations they need. A
**least-recently-used (LRU) cache** keeps a fixed number of items and, when
full, evicts the one used longest ago. It needs O(1) lookup by key, which a
hash map provides, *and* O(1) "move to most recent" and "remove oldest",
which a doubly linked list provides. Python's `OrderedDict` is exactly that
combination, a dict whose entries are also linked in order:[^ordereddict]

```python
from collections import OrderedDict


class LRUCache:
    """Keeps the `capacity` most recently used items: a hash map whose
    entries are also linked in order of use."""

    def __init__(self, capacity):
        self.capacity = capacity
        self.items = OrderedDict()

    def get(self, key):
        if key not in self.items:
            return None
        self.items.move_to_end(key)           # now the most recently used
        return self.items[key]

    def put(self, key, value):
        self.items[key] = value
        self.items.move_to_end(key)
        if len(self.items) > self.capacity:
            self.items.popitem(last=False)    # evict the least recently used


cache = LRUCache(2)
cache.put("a", 1)
cache.put("b", 2)
cache.get("a")          # touch "a", so "b" is now the oldest
cache.put("c", 3)       # over capacity: evicts "b"
print(list(cache.items))  # ['a', 'c']
```

The same pairing appears in Java as `LinkedHashMap`, and in operating systems
and databases deciding which pages to keep in memory.

## Why it matters

The choice of data structure usually matters more to a program's speed than any
amount of tuning of the code around it: the difference between a list and a
set above is four orders of magnitude, and no micro-optimisation recovers that.
It also shapes the code itself, because once the data is organised to make
the common operations easy, the algorithm often becomes obvious. That is the
point of Wirth's equation: the data structure and the algorithm are two halves
of the same design, and a program is only as good as the fit between them.

## References

[^wirth]: Wirth, N. (1976). *Algorithms + Data Structures = Programs*. Prentice-Hall.

[^liskov]: Liskov, B., & Zilles, S. (1974). Programming with abstract data types. *ACM SIGPLAN Notices*, 9(4), 50–59. <https://doi.org/10.1145/942572.807045>

[^knuthbigo]: Knuth, D. E. (1976). Big Omicron and big Omega and big Theta. *ACM SIGACT News*, 8(2), 18–24. <https://doi.org/10.1145/1008328.1008329>

[^tarjanamortized]: Tarjan, R. E. (1985). Amortized computational complexity. *SIAM Journal on Algebraic Discrete Methods*, 6(2), 306–318. <https://doi.org/10.1137/0606031>

[^clrs]: Cormen, T. H., Leiserson, C. E., Rivest, R. L., & Stein, C. (2022). *Introduction to Algorithms* (4th ed.). MIT Press.

[^backus57]: Backus, J. W., Beeber, R. J., Best, S., Goldberg, R., Haibt, L. M., Herrick, H. L., Nelson, R. A., Sayre, D., Sheridan, P. B., Stern, H. J., Ziller, I., Hughes, R. A., & Nutt, R. (1957). The FORTRAN automatic coding system. *Papers Presented at the Western Joint Computer Conference*, 188–198. <https://doi.org/10.1145/1455567.1455599>

[^newell]: Newell, A., & Shaw, J. C. (1957). Programming the logic theory machine. *Papers Presented at the Western Joint Computer Conference*, 230–240. <https://doi.org/10.1145/1455567.1455606>

[^taocp1]: Knuth, D. E. (1997). *The Art of Computer Programming, Vol. 1: Fundamental Algorithms* (3rd ed.). Addison-Wesley. Section 2.6, History and bibliography.

[^mccarthy]: McCarthy, J. (1960). Recursive functions of symbolic expressions and their computation by machine, Part I. *Communications of the ACM*, 3(4), 184–195. <https://doi.org/10.1145/367177.367199>

[^samelson]: Samelson, K., & Bauer, F. L. (1960). Sequential formula translation. *Communications of the ACM*, 3(2), 76–83. <https://doi.org/10.1145/366959.366968>

[^taocp3]: Knuth, D. E. (1998). *The Art of Computer Programming, Vol. 3: Sorting and Searching* (2nd ed.). Addison-Wesley. Sections 6.2 and 6.4.

[^peterson]: Peterson, W. W. (1957). Addressing for random-access storage. *IBM Journal of Research and Development*, 1(2), 130–146. <https://doi.org/10.1147/rd.12.0130>

[^morris]: Morris, R. (1968). Scatter storage techniques. *Communications of the ACM*, 11(1), 38–44. <https://doi.org/10.1145/362851.362882>

[^avl]: Adelson-Velsky, G. M., & Landis, E. M. (1962). An algorithm for the organization of information (M. J. Ricci, Trans.). *Soviet Mathematics Doklady*, 3, 1259–1263. (Original work published in *Doklady Akademii Nauk SSSR*, 146, 263–266.)

[^briandais]: de la Briandais, R. (1959). File searching using variable length keys. *Papers Presented at the March 3–5, 1959, Western Joint Computer Conference*, 295–298. <https://doi.org/10.1145/1457838.1457895>

[^fredkin]: Fredkin, E. (1960). Trie memory. *Communications of the ACM*, 3(9), 490–499. <https://doi.org/10.1145/367390.367400>

[^williams]: Williams, J. W. J. (1964). Algorithm 232: Heapsort. *Communications of the ACM*, 7(6), 347–348. <https://doi.org/10.1145/512274.3734138>

[^bayer72]: Bayer, R., & McCreight, E. (1972). Organization and maintenance of large ordered indexes. *Acta Informatica*, 1(3), 173–189. <https://doi.org/10.1007/BF00288683>

[^comer]: Comer, D. (1979). The ubiquitous B-tree. *ACM Computing Surveys*, 11(2), 121–137. <https://doi.org/10.1145/356770.356776>

[^redblack]: Guibas, L. J., & Sedgewick, R. (1978). A dichromatic framework for balanced trees. *19th Annual Symposium on Foundations of Computer Science*, 8–21. <https://doi.org/10.1109/SFCS.1978.3>

[^bayersbb]: Bayer, R. (1972). Symmetric binary B-trees: Data structure and maintenance algorithms. *Acta Informatica*, 1(4), 290–306. <https://doi.org/10.1007/BF00289509>

[^bloom]: Bloom, B. H. (1970). Space/time trade-offs in hash coding with allowable errors. *Communications of the ACM*, 13(7), 422–426. <https://doi.org/10.1145/362686.362692>

[^unionfind]: Tarjan, R. E. (1975). Efficiency of a good but not linear set union algorithm. *Journal of the ACM*, 22(2), 215–225. <https://doi.org/10.1145/321879.321884>

[^splay]: Sleator, D. D., & Tarjan, R. E. (1985). Self-adjusting binary search trees. *Journal of the ACM*, 32(3), 652–686. <https://doi.org/10.1145/3828.3835>

[^fibheap]: Fredman, M. L., & Tarjan, R. E. (1987). Fibonacci heaps and their uses in improved network optimization algorithms. *Journal of the ACM*, 34(3), 596–615. <https://doi.org/10.1145/28869.28874>

[^persistent]: Driscoll, J. R., Sarnak, N., Sleator, D. D., & Tarjan, R. E. (1989). Making data structures persistent. *Journal of Computer and System Sciences*, 38(1), 86–124. <https://doi.org/10.1016/0022-0000(89)90034-2>

[^okasaki]: Okasaki, C. (1998). *Purely Functional Data Structures*. Cambridge University Press.

[^skiplist]: Pugh, W. (1990). Skip lists: A probabilistic alternative to balanced trees. *Communications of the ACM*, 33(6), 668–676. <https://doi.org/10.1145/78973.78977>

[^lsm]: O'Neil, P., Cheng, E., Gawlick, D., & O'Neil, E. (1996). The log-structured merge-tree (LSM-tree). *Acta Informatica*, 33(4), 351–385. <https://doi.org/10.1007/s002360050048>

[^cuckoo]: Pagh, R., & Rodler, F. F. (2004). Cuckoo hashing. *Journal of Algorithms*, 51(2), 122–144. <https://doi.org/10.1016/j.jalgor.2003.12.002>

[^swiss]: Abseil. (n.d.). Swiss tables design notes. <https://abseil.io/about/design/swisstables>

[^ocert]: oCERT. (2011). oCERT-2011-003: Multiple implementations denial-of-service via hash algorithm collision. <https://ocert.org/advisories/ocert-2011-003.html>

[^siphash]: Aumasson, J.-P., & Bernstein, D. J. (2012). SipHash: A fast short-input PRF. In *Progress in Cryptology – INDOCRYPT 2012* (Lecture Notes in Computer Science, Vol. 7668, pp. 489–508). Springer. <https://doi.org/10.1007/978-3-642-34931-7_28>

[^pep456]: Heimes, C. (2013). *PEP 456: Secure and interchangeable hash algorithm*. Python Software Foundation. <https://peps.python.org/pep-0456/>

[^cpythonlist]: Python Software Foundation. (n.d.). list_resize. In *CPython source code*, Objects/listobject.c (3.10 branch). <https://github.com/python/cpython/blob/3.10/Objects/listobject.c>

[^arraylist]: Oracle and OpenJDK contributors. (n.d.). ArrayList.java. In *OpenJDK source code*. <https://github.com/openjdk/jdk/blob/master/src/java.base/share/classes/java/util/ArrayList.java>

[^pydeque]: Python Software Foundation. (n.d.). collections: deque objects. In *Python 3 Documentation*. <https://docs.python.org/3/library/collections.html#deque-objects>

[^jep180]: Duigou, M. (2013). *JEP 180: Handle frequent HashMap collisions with balanced trees*. OpenJDK. <https://openjdk.org/jeps/180>

[^dictobject]: Python Software Foundation. (n.d.). dictobject.c. In *CPython source code*, Objects/dictobject.c (3.10 branch). <https://github.com/python/cpython/blob/3.10/Objects/dictobject.c>

[^treemap]: Oracle. (n.d.). Class TreeMap. In *Java SE 21 API Specification*. <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/TreeMap.html>

[^sqlite]: SQLite. (n.d.). Database file format. <https://www.sqlite.org/fileformat.html>

[^heapq]: Python Software Foundation. (n.d.). heapq: Heap queue algorithm. In *Python 3 Documentation*. <https://docs.python.org/3/library/heapq.html>

[^dijkstra]: Dijkstra, E. W. (1959). A note on two problems in connexion with graphs. *Numerische Mathematik*, 1(1), 269–271. <https://doi.org/10.1007/BF01386390>

[^rocksdbbloom]: RocksDB. (n.d.). RocksDB Bloom filter. *RocksDB Wiki*. <https://github.com/facebook/rocksdb/wiki/RocksDB-Bloom-Filter>

[^pydatastructures]: Python Software Foundation. (n.d.). Data structures. In *The Python Tutorial*. <https://docs.python.org/3/tutorial/datastructures.html>

[^javacollections]: Oracle. (n.d.). Collections framework overview. In *Java SE 21 Documentation*. <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/doc-files/coll-overview.html>

[^rustcollections]: The Rust Project. (n.d.). Module std::collections. In *The Rust Standard Library*. <https://doc.rust-lang.org/std/collections/index.html>

[^gocontainer]: The Go Authors. (n.d.). Package container/heap. <https://pkg.go.dev/container/heap>

[^cppcontainers]: cppreference.com. (n.d.). Containers library. <https://en.cppreference.com/cpp/container>

[^ordereddict]: Python Software Foundation. (n.d.). collections: OrderedDict objects. In *Python 3 Documentation*. <https://docs.python.org/3/library/collections.html#ordereddict-objects>

[^stroustrup]: Stroustrup, B. (n.d.). Are lists evil? In *Bjarne Stroustrup's FAQ*. <https://www.stroustrup.com/bs_faq.html#list>

[^hashdos]: Klink, A., & Wälde, J. (2011). *Efficient denial of service attacks on web application platforms* [Conference talk]. 28th Chaos Communication Congress. <https://fahrplan.events.ccc.de/congress/2011/Fahrplan/events/4680.en.html>

[^sqlitearch]: SQLite. (n.d.). Architecture of SQLite. <https://www.sqlite.org/arch.html>

[^fibtrie]: The Linux Kernel documentation. (n.d.). LC-trie implementation notes. <https://docs.kernel.org/networking/fib_trie.html>

[^golist]: The Go Authors. (n.d.). Package container/list. <https://pkg.go.dev/container/list>

[^bauerpioneer]: IEEE Computer Society. (n.d.). Friedrich L. Bauer. *Computer Pioneers*. <https://history.computer.org/pioneers/bauer.html>

[^swissblog]: Abseil. (2018, September 27). Swiss tables and absl::Hash. *Abseil Blog*. <https://abseil.io/blog/20180927-swisstables>

[^crosby]: Crosby, S. A., & Wallach, D. S. (2003). Denial of service via algorithmic complexity attacks. *Proceedings of the 12th USENIX Security Symposium*. <https://www.usenix.org/legacy/events/sec03/tech/crosby.html>

[^rusthashmap]: The Rust Project. (n.d.). Struct HashMap. In *The Rust Standard Library*. <https://doc.rust-lang.org/std/collections/struct.HashMap.html>
