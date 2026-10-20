---
title: "What Is Text Encoding? From Telegraph Codes to Unicode and UTF-8"
description: "Computers store only numbers, so every piece of text is a sequence of numbers under some agreed code. Here is what a text encoding is, how we got from telegraph codes and ASCII to Unicode, how UTF-8 and UTF-16 work byte by byte, and why text still goes wrong."
date: 2026-10-20T17:00:00Z
categories: ["Fundamentals"]
tags: ["Text Encoding", "Unicode", "UTF-8", "Computer Science", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

A computer stores nothing but numbers. Every letter you read on a screen, every
name in a database and every line of source code is held as a sequence of
numbers, and something has to agree on which number means which character.
That agreement is a **text encoding**. When it works, nobody notices. When two
programs disagree, "café" turns into "cafÃ©", a customer's name is rejected as
invalid, or an emoji crashes a database insert. This article explains what a
text encoding is, how the world got from telegraph codes to Unicode, how the
modern encodings work bit by bit, and where text still goes wrong. The examples
were run with Python 3.10 and Node.js 12, and their output is shown as printed.

## What a text encoding is

**A text encoding is a rule for turning characters into bytes and back.** It
has two halves: a list of the characters it can represent, each with a number,
and a method for storing those numbers as bytes.

The Unicode Standard separates those halves more carefully, into layers that
are worth keeping apart even when they are casually called by one
name:[^tr17]

{{< diagram src="layers.svg" caption="From character to bytes to picture, using the euro sign. Most text bugs come from confusing two of these layers." >}}

| Layer | What it is | Example for € |
|---|---|---|
| **Abstract character** | A unit of meaning in writing: a letter, digit, punctuation mark or symbol | EURO SIGN |
| **Coded character set** | A mapping from characters to numbers, called **code points** | U+20AC |
| **Character encoding form** | A way to represent each code point as one or more **code units** of a fixed size | UTF-8: E2 82 AC; UTF-16: 20AC |
| **Character encoding scheme** | The exact byte sequence, including byte order | UTF-16BE: 20 AC; UTF-16LE: AC 20 |
| **Glyph** | The visual shape a font draws; not part of the encoding at all | € in a particular typeface |

Two consequences follow. First, *a character is not a byte*: in most encodings
in use today, one character can take several bytes. Second, *a character is not
a glyph*: the same code point looks different in every font, and some glyphs
on screen are built from several code points.

## A history of text encoding

### Telegraph codes and punched cards

Text was encoded as signals long before computers. Morse code used variable
lengths of dots and dashes, but machines needed fixed-length codes. In the 1870s
Émile Baudot designed a five-unit telegraph code, and a modified version by
Donald Murray became the International Telegraph Alphabet No. 2 (1931), the
standard for teleprinters. With five bits there are only 32 combinations, so
the code used two "shift" characters to switch between letters and
figures.[^fischer] Herman Hollerith's
punched cards used their own codes for digits and letters, and each computer
maker devised character codes for its own machines.

### ASCII

By the early 1960s, incompatible codes were a serious obstacle to exchanging
data. The American Standards Association published the **American Standard Code
for Information Interchange (ASCII)** in 1963; a 1967 revision, issued after the
association had been renamed the USA Standards Institute, added the lowercase
letters.[^fischer][^mackenzie] ASCII is a 7-bit code with 128
positions: 33 control codes (such as line feed and carriage return) and 95
printable characters, the space included.[^rfc20] In 1969 RFC 20 proposed it as
the format for text exchanged between ARPANET computers.[^rfc20]

ASCII covered English and nothing else. IBM's **EBCDIC**, introduced with the
System/360 in 1964, was an incompatible 8-bit code that survives on IBM
mainframes.[^mackenzie][^ibmebcdic]

### Code pages: one byte, many meanings

Computers stored characters in 8-bit bytes, so ASCII left 128 values free, and
every country and vendor filled them differently. The ISO/IEC 8859 series
defined one standard per region; **ISO 8859-1 (Latin-1)**, first published in
1987, covered Western European languages.[^iso8859] Microsoft's
**Windows-1252** put 27 more characters, including €, in the range Latin-1
leaves for control codes (0x80 to 0x9F),[^cp1252] and DOS and Windows had
dozens of other **code pages**.[^whatwgencoding] Chinese, Japanese and Korean needed thousands
of characters, so they used multi-byte encodings such as Shift_JIS, GB 2312 and
Big5.

The same byte sequence therefore meant different things on different machines,
and a file carried no record of which code page it used. Text that crossed a
border came out garbled, a result common enough that it is widely known by a
Japanese name, **mojibake** (文字化け): text garbled by the wrong
encoding.[^kotobank]

### Unicode

In late 1987 Joe Becker and Lee Collins of Xerox and Mark Davis of Apple began
working on a single character set for all the world's writing systems. Becker
coined the name, and his 1988 paper *Unicode 88* set out its
principles.[^unicodehistory][^earlyyears][^unicode88] The **Unicode Consortium**
was incorporated in January 1991, and Unicode 1.0 appeared in two volumes in
1991–92. Unicode 1.1 (1993) was synchronised with the parallel international
standard ISO/IEC 10646-1, and the two have assigned the same characters to the
same code points ever since.[^unicodehistory][^unicode11]

The original design assumed that 16 bits, 65,536 characters, would be enough.
It was not. Unicode 2.0 (1996) extended its code space to more than a million
code points, U+0000 to U+10FFFF, and introduced **surrogate pairs** so that
16-bit systems could still represent all of them; that became **UTF-16**.
(ISO/IEC 10646 had defined a larger 31-bit space; both standards now stop at
U+10FFFF.)[^unicodefaq][^rfc2781][^unicodecore] Unicode 18.0, released in 2026, defines
172,808 characters.[^unicode18]

### UTF-8

Unicode needed an encoding that would not break the enormous amount of software
built around ASCII bytes. In September 1992 Ken Thompson, working with Rob Pike
at Bell Labs, designed **UTF-8** over dinner in a New Jersey diner, sketching it
on a placemat, and within days their Plan 9 operating system was running
it.[^pikehistory][^rfc3629] They presented it at the Winter 1993 USENIX
conference in San Diego.[^pikethompson] UTF-8 was standardised by the IETF as RFC 2279 (1998), and
RFC 3629 (2003) restricted it to the Unicode range, so that no character takes
more than four bytes.[^rfc3629]

UTF-8 won. In 2008 Google reported that since December 2007 Unicode, in
practice UTF-8, had been the most common encoding on the web pages it
indexed,[^google2008] and today W3Techs finds UTF-8 on 99.1 percent of the
websites whose encoding it can determine.[^w3techs] The WHATWG Encoding Standard, which governs web browsers,
requires new formats and protocols to use UTF-8 exclusively.[^whatwgencoding]

## A timeline at a glance

| Year | Milestone |
|---|---|
| 1870s | Baudot's five-unit telegraph code |
| 1963 | ASCII published; revised with lowercase in 1967 |
| 1964 | EBCDIC with the IBM System/360 |
| 1969 | ASCII proposed for ARPANET text (RFC 20) |
| 1987 | ISO 8859-1 (Latin-1); Unicode work begins |
| 1988 | Becker's *Unicode 88* proposal |
| 1991 | Unicode Consortium incorporated; Unicode 1.0 |
| 1992 | UTF-8 designed by Thompson, with Pike |
| 1993 | Unicode 1.1 synchronised with ISO/IEC 10646; UTF-8 presented at USENIX |
| 1996 | Unicode 2.0: code space to U+10FFFF, surrogates, UTF-16 |
| 1998 | UTF-8 as an Internet standard (RFC 2279) |
| 2003 | RFC 3629 limits UTF-8 to U+10FFFF (four bytes) |
| 2008 | Google: Unicode (UTF-8) now the web's most common encoding |
| 2026 | Unicode 18.0: 172,808 characters |

## How Unicode works

### Code points and planes

Unicode assigns every character a **code point**, written U+ followed by at
least four hexadecimal digits: `A` is U+0041, `é` is U+00E9, `€` is U+20AC and
`😀` is U+1F600. The code space runs from U+0000 to U+10FFFF, 1,114,112 code
points, divided into 17 **planes** of 65,536 each.[^unicodecore]

{{< diagram src="codespace.svg" caption="The Unicode code space. Almost every character in everyday use is in plane 0; most emoji are in plane 1." >}}

**Plane 0**, the **Basic Multilingual Plane (BMP)**, contains the characters of
almost all modern writing systems. Its range U+D800 to U+DFFF is permanently
reserved for UTF-16 surrogates and never assigned to characters. Most emoji and
historic scripts live in plane 1, additional CJK ideographs in planes 2 and 3,
and planes 15 and 16 are for private use.[^unicodecore]

### UTF-32 and UTF-16

The simplest encoding form, **UTF-32**, stores every code point as one 32-bit
number. It is easy to index but wastes space: plain English text becomes four
times larger than in ASCII.

**UTF-16** stores each BMP code point as one 16-bit code unit. Code points above
U+FFFF are split across a **surrogate pair**: subtract 0x10000, leaving a 20-bit
number, then put its high 10 bits into a *high surrogate* (U+D800 to U+DBFF) and
its low 10 bits into a *low surrogate* (U+DC00 to U+DFFF).[^rfc2781] For
U+1F600, 0x1F600 − 0x10000 = 0xF600, whose high ten bits are 0x3D and low ten bits
0x200, giving the pair D83D DE00.

UTF-16 is the native string format of Windows, Java and JavaScript, all
designed when Unicode still fitted in 16 bits.[^winunicode][^javachar][^ecma262] It is why a
JavaScript string's `length` counts UTF-16 code units, not characters:

```js
const smile = "\u{1F600}";
console.log(smile.length);          // UTF-16 code units
console.log([...smile].length);     // code points
console.log(smile.charCodeAt(0).toString(16), smile.charCodeAt(1).toString(16));
```

```txt
2
1
d83d de00
```

Because a 16-bit unit can be stored with either byte first, UTF-16 has two
byte orders, big-endian (UTF-16BE) and little-endian (UTF-16LE). A file may
start with a **byte order mark (BOM)**, U+FEFF, to say which: the bytes FE FF
mean big-endian, FF FE little-endian.[^rfc2781]

### UTF-8

**UTF-8** encodes each code point as one to four bytes. The number of leading 1
bits in the first byte says how many bytes the character takes, and every
following byte starts with the bits `10`:[^rfc3629]

{{< diagram src="utf8-layout.svg" caption="The four UTF-8 byte patterns. Accented bits are fixed markers; the x positions carry the code point's bits." >}}

Encoding the euro sign shows the method. U+20AC needs 16 bits, so it takes the
three-byte form; its bits are split 4 + 6 + 6 and dropped into the x positions:

{{< diagram src="utf8-euro.svg" caption="Encoding U+20AC in UTF-8, step by step." >}}

Python can show the same characters in all three encoding forms:

```python
for ch in ["A", "é", "€", "😀"]:
    print(f"{ch}  U+{ord(ch):04X}  "
          f"UTF-8: {ch.encode('utf-8').hex(' ').upper():12}  "
          f"UTF-16BE: {ch.encode('utf-16-be').hex(' ').upper():12}  "
          f"UTF-32BE: {ch.encode('utf-32-be').hex(' ').upper()}")
```

```txt
A  U+0041  UTF-8: 41            UTF-16BE: 00 41         UTF-32BE: 00 00 00 41
é  U+00E9  UTF-8: C3 A9         UTF-16BE: 00 E9         UTF-32BE: 00 00 00 E9
€  U+20AC  UTF-8: E2 82 AC      UTF-16BE: 20 AC         UTF-32BE: 00 00 20 AC
😀  U+1F600  UTF-8: F0 9F 98 80   UTF-16BE: D8 3D DE 00   UTF-32BE: 00 01 F6 00
```

The design has properties that explain why it took over:[^pikethompson][^rfc3629]

- **ASCII compatibility.** Every ASCII file is already valid UTF-8, byte for
  byte, and ASCII characters never appear inside a multi-byte sequence. Software
  that only looks for ASCII characters such as `/`, `<` or newline works
  unchanged.
- **No zero bytes** except for U+0000 itself, so C strings, which end at a zero
  byte, keep working.
- **Self-synchronisation.** Lead bytes and continuation bytes look different, so
  a program can start reading anywhere and find the next character boundary
  within three bytes.
- **Sorting is preserved.** Sorting UTF-8 strings byte by byte gives the same
  order as sorting them by code point.
- **No byte order.** UTF-8 is a sequence of bytes, so it needs no BOM, though
  some Windows tools still write the bytes EF BB BF at the start of a file.

The cost is variable length: finding the 1,000th character means scanning from
the start, and non-Latin scripts take two to four bytes per character.

## Characters, code points and what users see

### Grapheme clusters

What a reader thinks of as one character can be several code points. Unicode
calls the user-perceived character a **grapheme cluster**, and defines the rules
for finding their boundaries.[^tr29]

{{< diagram src="graphemes.svg" caption="Two cases where one visible character is several code points." >}}

- **Combining marks.** `é` can be stored as one precomposed code point, U+00E9,
  or as `e` followed by the combining acute accent, U+0301. Both display the
  same.
- **Emoji sequences.** Many emoji are built from several code points joined by
  the ZERO WIDTH JOINER, U+200D, or combined with skin-tone modifiers. A flag is
  a pair of *regional indicator* letters: 🇧🇷 is the indicators for B and R.[^tr51]

So "how long is this string?" has several correct answers:

```python
import unicodedata

for label, text in [
    ("composed é", "\u00e9"),
    ("decomposed é", "e\u0301"),
    ("family emoji", "\U0001F468\u200D\U0001F469\u200D\U0001F467"),
    ("flag of Brazil", "\U0001F1E7\U0001F1F7"),
]:
    print(f"{label:15} code points: {len(text)}  "
          f"UTF-16 units: {len(text.encode('utf-16-le')) // 2}  "
          f"UTF-8 bytes: {len(text.encode('utf-8'))}")

composed, decomposed = "\u00e9", "e\u0301"
print(composed == decomposed)                                  # False
print(unicodedata.normalize("NFC", decomposed) == composed)    # True
print([unicodedata.name(c) for c in decomposed])
```

```txt
composed é      code points: 1  UTF-16 units: 1  UTF-8 bytes: 2
decomposed é    code points: 2  UTF-16 units: 2  UTF-8 bytes: 3
family emoji    code points: 5  UTF-16 units: 8  UTF-8 bytes: 18
flag of Brazil  code points: 2  UTF-16 units: 4  UTF-8 bytes: 8
False
True
['LATIN SMALL LETTER E', 'COMBINING ACUTE ACCENT']
```

Each of these is one grapheme cluster on screen. Python's `len` counts code
points, JavaScript's counts UTF-16 units, and a database column limit may count
bytes; none of them counts what the user sees.

### Normalisation

Because the same text can be encoded in different ways, comparing strings
code point by code point can give the wrong answer, as the `False` above shows.
**Normalisation** converts text into a standard form first. Unicode defines four
normalisation forms:[^tr15]

| Form | What it does | Typical use |
|---|---|---|
| **NFC** | Composes characters where possible (e + U+0301 → é) | Storing and exchanging text; the form W3C recommends for web content[^charmodnorm] |
| **NFD** | Decomposes characters into base plus combining marks | Text processing; Apple's HFS+ file system stores names fully decomposed[^tn1150] |
| **NFKC** | Like NFC, and also replaces *compatibility* characters (ﬁ → fi, ² → 2) | Identifiers, search |
| **NFKD** | Like NFD, with the same compatibility replacements | Search, sorting keys |

Normalise text before comparing it, hashing it or using it as a key, or two
visually identical usernames can be different accounts.

### Case and sorting

Changing case and sorting are also language-dependent, and do not map one
character to one character:[^specialcasing][^tr10]

```python
print("straße".upper())              # one character becomes two
print("İ".lower(), len("İ".lower())) # Turkish capital dotted I
print("ﬁ".upper())                   # a ligature splits in two
```

```txt
STRASSE
i̇ 2
FI
```

German `ß` uppercases to `SS`; the Turkish capital dotted `İ` lowercases (in the
default, language-neutral rules) to `i` plus a combining dot; and the `ﬁ`
ligature becomes two letters. Alphabetical order differs between languages too:
Swedish sorts `ä` after `z`, German sorts it with `a`. The **Unicode Collation
Algorithm** defines a default order that each locale can tailor.[^tr10]

## When text goes wrong

### Mojibake

**Mojibake** happens when bytes are decoded with a different encoding from the
one that wrote them. Since a single-byte code page such as Windows-1252 maps
almost every byte to a character (and browsers, following the WHATWG Encoding
Standard, map all 256), the decoder usually raises no error; it simply produces
the wrong characters:[^whatwgencoding]

{{< diagram src="mojibake.svg" caption="UTF-8 bytes decoded as Windows-1252. Each byte of the two-byte é becomes a character of its own." >}}

```python
data = "café".encode("utf-8")
print(data)                          # the bytes on disk
print(data.decode("utf-8"))          # read correctly
print(data.decode("cp1252"))         # read as Windows-1252: mojibake
```

```txt
b'caf\xc3\xa9'
café
cafÃ©
```

The pattern `Ã` followed by another character is the classic sign of UTF-8
read as Latin-1 or Windows-1252. The cure is never to guess: record the encoding
with the data, as HTTP does in `Content-Type: text/html; charset=utf-8` and HTML
in `<meta charset="utf-8">`,[^whatwghtml] or simply use UTF-8 everywhere.

### Limits that were never meant for every character

Systems designed before supplementary planes were common sometimes cannot store
them. MySQL's original `utf8` character set, now called `utf8mb3`, allows at most three bytes per
character, so it cannot hold emoji or other characters beyond the BMP; the
character set that holds all of Unicode is `utf8mb4`.[^mysql] Code that slices
UTF-16 strings by index can cut a surrogate pair in half, and code that slices
UTF-8 bytes can cut a character in half, leaving invalid data.

### Security

Text encoding is also an attack surface:

- **Overlong and invalid sequences.** Early decoders accepted non-shortest
  encodings, such as the two bytes C0 AF for `/`, which let attackers sneak
  characters past filters that looked only for the one-byte form.[^bugtraq]
  RFC 3629 makes such sequences invalid and requires decoders to protect
  against decoding them.[^rfc3629]
- **Look-alike characters.** Latin `a` (U+0061) and Cyrillic `а` (U+0430) look
  identical, so a domain name can impersonate another. Unicode's security
  mechanisms define how to detect such **confusables**.[^tr39]
- **Bidirectional controls.** Invisible characters that change the display
  direction of text can make source code look different to a reviewer than it
  does to the compiler, an attack published as **Trojan Source** in
  2021.[^trojansourcearxiv][^trojansource]

### In programming languages

Languages represent strings in different ways, which explains much of the
confusion:

| Language | What a string is | `len` / `length` counts |
|---|---|---|
| **Python 3** | A sequence of code points, stored internally in 1, 2 or 4 bytes each depending on the widest character[^pep393] | Code points |
| **JavaScript, Java, C#** | A sequence of UTF-16 code units[^ecma262][^javachar] | UTF-16 code units |
| **Go** | Bytes, conventionally UTF-8; source code is UTF-8[^gospec] | Bytes |
| **Rust** | `str` is guaranteed to be valid UTF-8[^ruststr] | Bytes |
| **C** | Bytes, in whatever encoding the program assumes | Bytes up to the first zero |

The practical rule is the same in all of them: decode bytes into text as soon
as they enter the program, work with text inside, and encode back to bytes,
almost always UTF-8, only at the boundary.

## Putting it together: typing é on a web page

Following one character from keyboard to screen touches every layer:

1. **Input.** The keyboard layout and input method turn your key presses into
   the code point U+00E9; on some layouts you type `e` and an accent key, and
   the system composes them.
2. **In the program.** The browser holds the text field's contents as a
   JavaScript string, in UTF-16: the single code unit 00E9.
3. **On the wire.** When the form is submitted, the browser encodes the text as
   UTF-8, the bytes C3 A9 (sent percent-encoded as `%C3%A9`), because forms are
   submitted in the page's own encoding and the page declared
   `charset=utf-8`.[^formencoding]
4. **On the server.** The server decodes the bytes as UTF-8 and stores the
   string; the database stores the same two bytes in a `utf8mb4` column.
5. **Back to the screen.** On the next page load the bytes C3 A9 are decoded to
   U+00E9 again, and the browser asks a font for a glyph for that code point and
   draws é.

If any step uses the wrong encoding, the reader sees `Ã©` instead.

## Why it matters

Text is the most common kind of data, and most of it now crosses languages,
systems and countries. The encoding problem looks solved, since almost
everything is UTF-8, but the remaining bugs are subtle precisely because the
common case works: names that are truncated in the middle of a character,
lengths counted in the wrong unit, two identical-looking strings that do not
compare equal, emoji that a database silently rejects. Knowing the difference
between a character, a code point, a code unit, a byte and a glyph is what turns
those bugs from mysteries into routine fixes.

## References

[^tr17]: Whistler, K., & Freytag, A. (2022). *Unicode Technical Report #17: Unicode Character Encoding Model* (Revision 9). Unicode Consortium. <https://www.unicode.org/reports/tr17/>

[^fischer]: Fischer, E. (2000). *The Evolution of Character Codes, 1874–1968* [Unpublished manuscript]. <https://web.archive.org/web/20081217135753/http://www.transbay.net/~enf/ascii/ascii.pdf>

[^mackenzie]: Mackenzie, C. E. (1980). *Coded Character Sets: History and Development*. Addison-Wesley.

[^rfc20]: Cerf, V. (1969). *ASCII format for network interchange* (RFC 20, STD 80). Network Working Group. <https://www.rfc-editor.org/rfc/rfc20>

[^iso8859]: International Organization for Standardization. (1998). *ISO/IEC 8859-1:1998 Information technology — 8-bit single-byte coded graphic character sets — Part 1: Latin alphabet No. 1*. <https://www.iso.org/standard/28245.html>

[^whatwgencoding]: WHATWG. (n.d.). *Encoding Standard* (Living Standard). <https://encoding.spec.whatwg.org/>

[^unicodehistory]: Unicode Consortium. (n.d.). Summary narrative. *History of Unicode*. <https://www.unicode.org/history/summary.html>

[^unicode88]: Becker, J. D. (1988, August 29). *Unicode 88* [Reprinted 1998]. <https://www.unicode.org/history/unicode88.pdf>

[^rfc2781]: Hoffman, P., & Yergeau, F. (2000). *UTF-16, an encoding of ISO 10646* (RFC 2781). Internet Engineering Task Force. <https://doi.org/10.17487/RFC2781>

[^unicodecore]: Unicode Consortium. (2026). *The Unicode Standard, Version 18.0.0: Core Specification*. Chapters 2 and 3. <https://www.unicode.org/versions/Unicode18.0.0/core-spec/>

[^unicode18]: Unicode Consortium. (2026). *Unicode 18.0.0*. <https://www.unicode.org/versions/Unicode18.0.0/>

[^pikehistory]: Pike, R. (2003, April 30). UTF-8 history [Email]. Archived by M. Kuhn. <https://www.cl.cam.ac.uk/~mgk25/ucs/utf-8-history.txt>

[^pikethompson]: Pike, R., & Thompson, K. (1993). Hello world or Καλημέρα κόσμε or こんにちは 世界. *Proceedings of the Winter 1993 USENIX Conference*, 43–50. <https://plan9.io/sys/doc/utf.html>

[^rfc3629]: Yergeau, F. (2003). *UTF-8, a transformation format of ISO 10646* (RFC 3629). Internet Engineering Task Force. <https://doi.org/10.17487/RFC3629>

[^google2008]: Davis, M. (2008, May 5). Moving to Unicode 5.1. *Official Google Blog*. <https://googleblog.blogspot.com/2008/05/moving-to-unicode-51.html>

[^w3techs]: W3Techs. (2026, October). Usage statistics of character encodings for websites. <https://w3techs.com/technologies/overview/character_encoding>

[^ecma262]: Ecma International. (2026). *ECMAScript 2026 Language Specification* (ECMA-262, 17th ed.), Section 6.1.4, The String Type. <https://262.ecma-international.org/17.0/#sec-ecmascript-language-types-string-type>

[^javachar]: Oracle. (n.d.). Class Character: Unicode character representations. In *Java SE 21 API Specification*. <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Character.html#unicode>

[^tr29]: Hadley, J. (2026). *Unicode Standard Annex #29: Unicode Text Segmentation* (Revision 49). Unicode Consortium. <https://www.unicode.org/reports/tr29/>

[^tr51]: Davis, M., & Holbrook, N. (2026). *Unicode Technical Standard #51: Unicode Emoji* (Revision 31). Unicode Consortium. <https://www.unicode.org/reports/tr51/>

[^tr15]: Whistler, K. (2026). *Unicode Standard Annex #15: Unicode Normalization Forms* (Revision 58). Unicode Consortium. <https://www.unicode.org/reports/tr15/>

[^specialcasing]: Unicode Consortium. (n.d.). SpecialCasing.txt. *Unicode Character Database*. <https://www.unicode.org/Public/UCD/latest/ucd/SpecialCasing.txt>

[^tr10]: Whistler, K., & Scherer, M. (2026). *Unicode Technical Standard #10: Unicode Collation Algorithm* (Revision 55). Unicode Consortium. <https://www.unicode.org/reports/tr10/>

[^whatwghtml]: WHATWG. (n.d.). Specifying the document's character encoding. In *HTML Standard* (Living Standard). <https://html.spec.whatwg.org/multipage/semantics.html#charset>

[^mysql]: Oracle. (n.d.). The utf8mb4 character set (4-byte UTF-8 Unicode encoding). In *MySQL 8.4 Reference Manual*. <https://dev.mysql.com/doc/refman/8.4/en/charset-unicode-utf8mb4.html>

[^tr39]: Hadley, J., & Pournader, R. (2026). *Unicode Technical Standard #39: Unicode Security Mechanisms* (Revision 34). Unicode Consortium. <https://www.unicode.org/reports/tr39/>

[^trojansource]: Boucher, N., & Anderson, R. (2023). Trojan Source: Invisible vulnerabilities. *Proceedings of the 32nd USENIX Security Symposium*, 6507–6524. <https://www.usenix.org/conference/usenixsecurity23/presentation/boucher>

[^pep393]: von Löwis, M. (2010). *PEP 393: Flexible string representation*. Python Software Foundation. <https://peps.python.org/pep-0393/>

[^gospec]: The Go Authors. (n.d.). The Go programming language specification: Source code representation and String types. <https://go.dev/ref/spec>

[^ruststr]: The Rust Project. (n.d.). Primitive type str. In *The Rust Standard Library*. <https://doc.rust-lang.org/std/primitive.str.html>

[^charmodnorm]: W3C. (2026). *Character Model for the World Wide Web: String Matching* (W3C First Public Working Draft). <https://www.w3.org/TR/charmod-norm/>

[^tn1150]: Apple. (2004). *Technical Note TN1150: HFS Plus Volume Format*. <https://developer.apple.com/library/archive/technotes/tn/tn1150.html>

[^bugtraq]: Bugtraq. (2000). IIS Unicode directory traversal (Web server folder traversal) [Mailing list archive]. <https://diswww.mit.edu/menelaus/bt/17324>

[^trojansourcearxiv]: Boucher, N., & Anderson, R. (2021). *Trojan Source: Invisible vulnerabilities* (arXiv:2111.00169). arXiv. <https://arxiv.org/abs/2111.00169>

[^formencoding]: WHATWG. (n.d.). Selecting a form submission encoding. In *HTML Standard* (Living Standard). <https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#selecting-a-form-submission-encoding>

[^ibmebcdic]: IBM. (n.d.). The EBCDIC character set. In *z/OS Basic Skills*. <https://www.ibm.com/docs/en/zos-basic-skills?topic=mainframe-ebcdic-character-set>

[^cp1252]: Unicode Consortium. (n.d.). CP1252.TXT: cp1252 to Unicode table [Mapping file, Microsoft vendor mappings]. <https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1252.TXT>

[^kotobank]: Kotobank. (n.d.). 文字化け (mojibake). <https://kotobank.jp/word/%E6%96%87%E5%AD%97%E5%8C%96%E3%81%91>

[^earlyyears]: Unicode Consortium. (n.d.). Early years of Unicode. *History of Unicode*. <https://www.unicode.org/history/earlyyears.html>

[^unicode11]: Unicode Consortium. (1993). *Unicode 1.1.0*. <https://www.unicode.org/versions/Unicode1.1.0/>

[^unicodefaq]: Unicode Consortium. (n.d.). UTF-8, UTF-16, UTF-32 & BOM. *Unicode FAQ*. <https://www.unicode.org/faq/utf_bom.html>

[^winunicode]: Microsoft. (n.d.). Unicode. *Microsoft Learn*. <https://learn.microsoft.com/en-us/windows/win32/intl/unicode>
