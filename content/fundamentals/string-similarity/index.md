---
title: "String Similarity: Levenshtein, Jaro and Jaro–Winkler"
description: "How a program decides that two strings are almost the same: where the idea came from, the families of methods, and a close look at the three measures I reach for most, Levenshtein distance, Jaro similarity and Jaro–Winkler similarity, with worked examples, C# implementations and the pitfalls of each."
date: 2026-10-21T20:00:00Z
categories: ["Fundamentals"]
tags: ["String Similarity", "Levenshtein Distance", "Edit Distance", "Jaro", "Jaro-Winkler", "Record Linkage", "Algorithms", "Dynamic Programming", "Fundamentals"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Two strings are equal or they are not, and for a computer that is the end of
it: `"Smith"` and `"Smyth"` differ, and so do `"recieve"` and `"receive"`. For
the person who typed them, though, they are almost the same, and a lot of
software has to act on that "almost". A spell checker has to find the word
that was meant. A search box has to forgive a typo. A company merging two
customer lists has to notice that "Jon Smyth, 12 Main St" and "John Smith,
12 Main Street" are probably the same person. A **string similarity measure**
puts a number on how close two strings are, so a program can make those calls.

This article explains where the idea came from, the main families of methods,
and three measures in detail: **Levenshtein distance**, **Jaro similarity**
and **Jaro–Winkler similarity**. Every worked example was computed three ways
and the results agreed: with the C# implementations shown below on the .NET 10
SDK (10.0.400), with a separate Python 3.14 implementation, and with the
[RapidFuzz](https://rapidfuzz.github.io/RapidFuzz/) library, version
3.14.1.[^rapidfuzz]

## Distance and similarity

Measures come in two shapes:

- A **distance** is 0 for identical strings and grows as they differ.
  Levenshtein distance counts edits: `kitten` and `sitting` are 3 apart.
- A **similarity** is usually scaled from 0 to 1, where 1 means identical.
  Jaro similarity scores `MARTHA` and `MARHTA` at about 0.944.

One converts into the other. A distance becomes a similarity by dividing it
by the largest value it can take and subtracting the result from 1; for
Levenshtein that maximum is the length of the longer string, so `kitten` and
`sitting` are 1 − 3/7 ≈ 0.571 similar. A similarity becomes a distance as
1 − similarity.

A distance that behaves like a distance on a map is called a **metric**: it
is never negative, it is zero only for identical strings, it is the same in
both directions, and it obeys the **triangle inequality**, so going from A to
C directly is never longer than going through B. Levenshtein distance is a
metric. 1 − Jaro is not, as shown [further down](#jaro-similarity), and that
matters as soon as an index or a clustering algorithm relies on the triangle
inequality to skip comparisons.

## A short history

String similarity was invented several times, by people solving different
problems: sorting census cards, correcting transmission errors, catching
typing mistakes, comparing proteins and matching people across records.

| Year | Who | What |
| --- | --- | --- |
| 1918 | Robert C. Russell | Patents **Soundex**, an index that files names by how they sound, so that "Smith" and "Smyth" end up together[^russell] |
| 1950 | Richard Hamming | Defines what is now called the **Hamming distance**, the number of positions at which two equal-length codes differ, to detect and correct transmission errors[^hamming] |
| 1964 | Fred Damerau | Builds a spelling checker on the observation that most misspellings, about 80 percent, are one insertion, deletion, substitution or swap of two adjacent letters away from the right word[^damerau][^boytsov] |
| 1965 | Vladimir Levenshtein | Defines the minimum number of insertions, deletions and substitutions needed to turn one sequence into another, in a paper on error-correcting codes[^levenshtein] |
| 1969 | Ivan Fellegi and Alan Sunter | Publish the probabilistic theory of **record linkage**, deciding whether two records describe the same entity[^fellegisunter] |
| 1970 | Saul Needleman and Christian Wunsch | Align protein sequences with dynamic programming, the technique behind every edit distance algorithm since[^needlemanwunsch] |
| 1974 | Robert Wagner and Michael Fischer | Give the general dynamic programming algorithm for the string-to-string correction problem, the one still taught today[^wagnerfischer] |
| 1975 | Roy Lowrance and Robert Wagner | Extend it with transpositions of adjacent characters[^lowrancewagner] |
| 1989 | Matthew Jaro | Describes the string comparator used to match records of the 1985 test census of Tampa, Florida[^jaro] |
| 1990 | William Winkler | Modifies Jaro's comparator to raise the score of strings that agree on their first few characters[^winkler1990] |
| 1999 | Gene Myers | Computes edit distance with bit-parallel operations, many cells of the table per machine instruction[^myers] |
| 2015 | Arturs Backurs and Piotr Indyk | Show that edit distance cannot be computed in strongly subquadratic time unless a widely believed conjecture, SETH, is false[^backursindyk] |

Two threads run through the table. The first, from Hamming to Backurs and
Indyk, treats strings as sequences and asks how many operations separate
them; it gave us edit distance and the dynamic programming algorithm behind
it. The second, from Russell to Winkler, comes from census and statistics
work, where the strings are short names typed by people, and the question is
whether two records are about the same person. Jaro and Winkler's measures
come from the second thread, which is why they are tuned for names.

## Families of methods

There are many measures, but most fall into a handful of families.
Gonzalo Navarro's survey is the standard map of the edit-based
ones,[^navarro] and Cohen, Ravikumar and Fienberg compared measures from
several families on name-matching tasks.[^cohen]

| Family | Idea | Examples | Good at |
| --- | --- | --- | --- |
| **Edit-based** | Count the operations that turn one string into the other | Hamming, Levenshtein, Damerau–Levenshtein, longest common subsequence | Typos, short and medium strings, anything where order matters |
| **Alignment** | Line the strings up, scoring matches, mismatches and gaps | Needleman–Wunsch (global),[^needlemanwunsch] Smith–Waterman (local)[^smithwaterman] | Biological sequences, finding a similar region inside a longer string |
| **Character matching** | Count characters that appear in both strings near the same position | Jaro, Jaro–Winkler | Short strings such as personal names |
| **Token and set-based** | Split into words or n-grams and compare the sets | Jaccard,[^jaccard] cosine over TF-IDF, n-gram overlap | Longer text, reordered words ("Smith, John" and "John Smith") |
| **Phonetic** | Reduce each string to a code for how it sounds, then compare the codes | Soundex[^russell] | Names spelled differently but pronounced alike |

The rest of the article is about the two families most used for short
strings: edit distance, through Levenshtein, and character matching, through
Jaro and Jaro–Winkler.

## Levenshtein distance

The **Levenshtein distance** between two strings is the smallest number of
single-character edits that turns one into the other, where an edit is one
of:

- **Insertion** of a character: `cat` → `cart`
- **Deletion** of a character: `cart` → `cat`
- **Substitution** of one character for another: `cat` → `cut`

Each edit costs 1. `kitten` becomes `sitting` in three edits, and no shorter
way exists:

1. **k**itten → **s**itten (substitute k with s)
2. sitt**e**n → sitt**i**n (substitute e with i)
3. sittin → sittin**g** (insert g)

Levenshtein defined the measure in a 1965 paper on codes that can correct
deletions, insertions and reversals of binary digits, published in English
the next year.[^levenshtein] It is often called simply **edit distance**,
though that name also covers variants with other sets of operations.

### Computing it

Trying every sequence of edits is hopeless, but the problem breaks into
smaller ones that overlap, which is what dynamic programming is for. Let
*d*(*i*, *j*) be the distance between the first *i* characters of the source
and the first *j* characters of the target. Then:

- *d*(*i*, 0) = *i*, because *i* characters need *i* deletions to become
  empty, and *d*(0, *j*) = *j* for the same reason with insertions.
- Otherwise *d*(*i*, *j*) is the smallest of:
  - *d*(*i* − 1, *j*) + 1, deleting the *i*-th source character;
  - *d*(*i*, *j* − 1) + 1, inserting the *j*-th target character;
  - *d*(*i* − 1, *j* − 1) + *c*, where *c* is 0 if the two characters are
    equal and 1 if one must be substituted for the other.

Filling a table row by row with this rule gives the answer in the
bottom-right cell. This is the algorithm Wagner and Fischer published in
1974,[^wagnerfischer] and it is the same idea Needleman and Wunsch had used
four years earlier on proteins.[^needlemanwunsch]

{{< diagram src="levenshtein-matrix.svg" caption="The table for kitten and sitting. Each cell is the distance between two prefixes; the shaded cells trace one cheapest way to get from the top-left corner to the answer, 3." >}}

Each cell depends only on the row above and the cell to its left, so only
two rows need to be kept at any time:

```csharp
public static int Levenshtein(string source, string target)
{
    // Only two rows of the table are needed: the previous one and the current one.
    var previous = new int[target.Length + 1];
    var current = new int[target.Length + 1];

    for (var j = 0; j <= target.Length; j++)
    {
        previous[j] = j;
    }

    for (var i = 1; i <= source.Length; i++)
    {
        current[0] = i;

        for (var j = 1; j <= target.Length; j++)
        {
            var substitution = source[i - 1] == target[j - 1] ? 0 : 1;

            current[j] = Math.Min(
                Math.Min(previous[j] + 1, current[j - 1] + 1),
                previous[j - 1] + substitution);
        }

        (previous, current) = (current, previous);
    }

    return previous[target.Length];
}
```

```txt
Levenshtein(kitten, sitting) = 3
Levenshtein(saturday, sunday) = 3
```

### How fast it can be

For strings of lengths *m* and *n* the table has (*m* + 1)(*n* + 1) cells,
so the algorithm takes O(*mn*) time; keeping two rows brings memory down to
O(min(*m*, *n*)) if the shorter string is used for the columns. Comparing two
10-character names is about a hundred cell updates and costs nothing.
Comparing two 100,000-character documents is ten billion, which is why edit
distance is rarely used on long text.

Faster algorithms exist for common special cases. When only distances up to
some limit *k* matter, as in "find words within two typos", only a band of
the table around the diagonal can hold such values, and Ukkonen showed how
to compute only that band, so the cost grows with the distance itself
rather than with the full size of the table.[^ukkonen][^navarro] Myers' bit-vector algorithm packs a
whole column into machine words and updates it with a handful of bitwise
operations, which is how fast libraries do it today.[^myers]

For the general case, though, nobody expects much better. Backurs and Indyk
proved in 2015 that an algorithm for edit distance running in
O(*n*^(2 − ε)) time, for any constant ε > 0, would refute the Strong
Exponential Time Hypothesis, a conjecture about how hard satisfiability
problems are that most researchers believe.[^backursindyk] The textbook
quadratic algorithm is, in that sense, close to the best possible.

### Damerau–Levenshtein and transpositions

The commonest typo of all is swapping two neighbouring letters: `teh` for
`the`. Levenshtein distance charges 2 for it, a substitution each way, while
it is clearly one mistake. Damerau's 1964 spelling checker counted the swap
of two adjacent letters as a single error, alongside insertion, deletion and
substitution,[^damerau] and a distance that does the same is called
**Damerau–Levenshtein distance**.

There are two versions of it, and libraries do not always say which one they
implement:[^boytsov]

- **Optimal string alignment** (OSA), also called restricted edit distance,
  adds a fourth case to the table rule: if the last two characters are
  swapped, *d*(*i* − 2, *j* − 2) + 1. It is simple and fast, but it never
  edits a substring twice, so it is not a metric: `ca` → `abc` costs 3 under
  OSA, because swapping `ca` to `ac` and then inserting `b` between the
  swapped letters is not allowed.
- **True Damerau–Levenshtein distance** allows it, giving 2 for the same
  pair, and is a metric. Lowrance and Wagner gave the algorithm for it in
  1975.[^lowrancewagner]

| Pair | Levenshtein | OSA | Damerau–Levenshtein |
| --- | --- | --- | --- |
| `ca` → `ac` | 2 | 1 | 1 |
| `ca` → `abc` | 3 | 3 | 2 |

## Jaro similarity

Edit distance was built for sequences in general. Matthew Jaro's measure was
built for one job: matching records at the U.S. Census Bureau, where the
strings are first names and surnames typed by people, often short, often
with a letter or two out of place.[^jaro] Instead of counting edits, it
counts the characters the two strings have in common near the same
position, and how many of those are in a different order.

### Definition

For two strings *s*₁ and *s*₂:

1. **The matching window.** Two characters can match only if they are
   equal and no further apart than

   ⌊max(|*s*₁|, |*s*₂|) / 2⌋ − 1

   positions. For two 6-letter strings, that is 2.
2. **Matches.** Going through *s*₁ from left to right, each character
   matches the first equal, not-yet-matched character of *s*₂ inside its
   window. *m* is the number of matches.
3. **Transpositions.** Read the matched characters of each string in order.
   Count the positions where the two sequences disagree; half of that count
   is *t*, the number of transpositions.
4. **The score.** If *m* = 0 the similarity is 0. Otherwise the Jaro
   similarity *J* is the average of three fractions: how much of *s*₁ matched, how much of *s*₂
   matched, and how many matches are in order:

   *J* = ⅓ × (*m* / |*s*₁| + *m* / |*s*₂| + (*m* − *t*) / *m*)

The window and the halving of out-of-order matches follow Winkler's 1990
description of the comparator,[^winkler1990] and the same rules are used by
libraries such as Apache Commons Text.[^commonstext] Descriptions do not
always agree on the details: Winkler's 2006 overview, for instance, gives the
window as half the length of the shorter string.[^winkler2006] When scores
from two libraries differ slightly, the window is the first thing to check.

{{< diagram src="jaro-matching.svg" caption="MARTHA and MARHTA. Every letter matches inside the window of 2, but T and H are matched across each other: two matched letters out of order, one transposition. The shared prefix MAR is what Jaro–Winkler adds on top." >}}

For `MARTHA` and `MARHTA`, all 6 letters match. Reading the matches in order
gives `MARTHA` and `MARHTA`, which disagree at two positions, so *t* = 1:

*J* = ⅓ × (6/6 + 6/6 + 5/6) ≈ 0.944

### Implementation

```csharp
public static double Jaro(string first, string second)
{
    if (first == second)
    {
        return 1.0;
    }

    if (first.Length == 0 || second.Length == 0)
    {
        return 0.0;
    }

    var window = Math.Max(Math.Max(first.Length, second.Length) / 2 - 1, 0);
    var firstMatched = new bool[first.Length];
    var secondMatched = new bool[second.Length];
    var matches = 0;

    for (var i = 0; i < first.Length; i++)
    {
        var start = Math.Max(0, i - window);
        var end = Math.Min(i + window + 1, second.Length);

        for (var j = start; j < end; j++)
        {
            if (secondMatched[j] || first[i] != second[j])
            {
                continue;
            }

            firstMatched[i] = secondMatched[j] = true;
            matches++;
            break;
        }
    }

    if (matches == 0)
    {
        return 0.0;
    }

    // Walk both strings' matched characters in order and count the positions where they differ.
    var outOfOrder = 0;
    var k = 0;

    for (var i = 0; i < first.Length; i++)
    {
        if (!firstMatched[i])
        {
            continue;
        }

        while (!secondMatched[k])
        {
            k++;
        }

        if (first[i] != second[k])
        {
            outOfOrder++;
        }

        k++;
    }

    double m = matches;
    var transpositions = outOfOrder / 2.0;

    return (m / first.Length + m / second.Length + (m - transpositions) / m) / 3.0;
}
```

The work is O(|*s*₁| × window), which for names is tiny.

### Quirks worth knowing

- **Very short strings barely match.** For strings of length 2 or 3 the
  window is 0, so characters match only in the same position. `ab` and `ba`
  score 0, not "one swap away".
- **1 − Jaro is not a metric.** `a` and `aa` score 0.833 and `aa` and `ba`
  score 0.667, so the distances are 0.167 and 0.333. But `a` and `ba` score
  0, a distance of 1, more than the 0.5 of the detour through `aa`. The
  triangle inequality fails, so indexes that depend on it cannot be used
  with Jaro.
- **It knows nothing about words.** `John Smith` and `Smith John` score
  poorly, because the matching window keeps characters near their original
  positions. Reordered words are a job for token-based measures.

## Jaro–Winkler similarity

William Winkler, also at the Census Bureau, modified Jaro's comparator
according to whether the first few characters of the two strings agree, for
use in the matching software of the 1990 Census's Post Enumeration
Survey.[^winkler1990] **Jaro–Winkler similarity** adds a bonus for a common
prefix:

*JW* = *J* + ℓ × *p* × (1 − *J*)

where:

- **ℓ** is the length of the common prefix, counted up to a maximum of 4
  characters;
- **_p_** is a scaling factor, 0.1 in Winkler's paper.[^winkler1990] The
  bonus closes a fraction ℓ × *p* of the gap between the Jaro score and a
  perfect 1, so *p* must not exceed 0.25, or four matching letters would
  push the score above 1; RapidFuzz rejects larger values for that
  reason.[^rapidfuzzjw]

Many implementations, Apache Commons Text among them, apply the bonus only
when the Jaro score is already above 0.7, so that a shared first letter
cannot rescue two strings that are otherwise different.[^commonstext] That
**boost threshold** is a convention of the implementations rather than part
of the formula in Winkler's paper, and libraries differ on whether they apply
it, so it is worth checking before comparing numbers across libraries.

```csharp
public static double JaroWinkler(string first, string second, double scaling = 0.1, double boostThreshold = 0.7)
{
    var jaro = Jaro(first, second);

    if (jaro <= boostThreshold)
    {
        return jaro;
    }

    var prefix = 0;
    var limit = Math.Min(4, Math.Min(first.Length, second.Length));

    while (prefix < limit && first[prefix] == second[prefix])
    {
        prefix++;
    }

    return jaro + prefix * scaling * (1.0 - jaro);
}
```

For `MARTHA` and `MARHTA` the prefix `MAR` gives ℓ = 3:

*JW* ≈ 0.944 + 3 × 0.1 × (1 − 0.944) ≈ 0.961

Run through the implementations above, the first two pairs reproduce the
values in Winkler's 2006 overview,[^winkler2006] and the third is a pair of
my own where the prefix bonus does more of the work:

```txt
MARTHA / MARHTA: Jaro = 0.944, Jaro-Winkler = 0.961
DWAYNE / DUANE: Jaro = 0.822, Jaro-Winkler = 0.840
DIXON / DICKSONX: Jaro = 0.767, Jaro-Winkler = 0.813
```

The prefix bonus is also Jaro–Winkler's weakness. It assumes the start of a
string is the most reliable part, which holds for names typed by people and
fails elsewhere: product codes that share a long prefix, such as
`INV-2026-0001` and `INV-2026-0917`, are boosted for agreeing on the part
that carries no information.

## Choosing a measure

| If the strings are | Reach for | Because |
| --- | --- | --- |
| Words with typos, search terms, identifiers | Levenshtein, or Damerau–Levenshtein if swapped letters are common | It counts the mistakes people actually make, and a limit such as "within 2 edits" is easy to reason about |
| Personal names, short fields in record linkage | Jaro–Winkler | It was designed for exactly that, and rewards agreement at the start where names are most reliable |
| Long text, or text with reordered words | A token or n-gram measure, such as Jaccard or cosine over TF-IDF | Edit distance is quadratic and sensitive to word order; set measures are neither |
| Names that sound alike but are spelled differently | A phonetic code, then an exact or edit-based comparison of the codes | Neither family above knows that "ph" and "f" sound alike |

On name matching specifically, Cohen, Ravikumar and Fienberg found that among
the edit-distance-like measures, Jaro and Jaro–Winkler came close to the best
one while being much faster, and that a hybrid combining word-level TF-IDF
with Jaro–Winkler on the individual words did best overall.[^cohen]

Whatever the measure, three things decide whether it works in practice:

- **Normalise first.** Compare `josé` with `José` and the measure sees a
  difference that is only case. Lowercasing, trimming, collapsing spaces and
  Unicode normalisation (so that é is always the same code point) remove
  differences nobody cares about before the measure ever runs; see
  [What Is Text Encoding?]({{< ref "/fundamentals/text-encoding" >}}) for
  why the same letter can be stored in more than one way. Note also that the
  implementations above compare UTF-16 code units, not what a reader sees as
  characters.
- **Pick the threshold from data.** "0.9 means the same person" is a
  decision, not a property of the measure. The right cut-off comes from
  labelled examples of real matches and non-matches.
- **Do not compare everything with everything.** Comparing every record
  with every other is quadratic in the number of records, on top of the cost
  of each comparison. Record linkage systems first group records into
  **blocks** that share something cheap to check, such as a postcode or the
  first letter of a surname, and compare only within a block.[^winkler2006]

## References

[^rapidfuzz]: Bachmann, M. (2025). *RapidFuzz* (Version 3.14.1) [Computer software]. <https://pypi.org/project/rapidfuzz/3.14.1/>

[^russell]: Russell, R. C. (1918). *Index* (U.S. Patent No. 1,261,167). U.S. Patent Office. <https://patents.google.com/patent/US1261167A/en>

[^hamming]: Hamming, R. W. (1950). Error detecting and error correcting codes. *Bell System Technical Journal*, 29(2), 147–160. <https://doi.org/10.1002/j.1538-7305.1950.tb00463.x>

[^damerau]: Damerau, F. J. (1964). A technique for computer detection and correction of spelling errors. *Communications of the ACM*, 7(3), 171–176. <https://doi.org/10.1145/363958.363994>

[^levenshtein]: Levenshtein, V. I. (1966). Binary codes capable of correcting deletions, insertions, and reversals. *Soviet Physics Doklady*, 10(8), 707–710. Translated from *Doklady Akademii Nauk SSSR*, 163(4), 845–848 (1965). <https://www.mathnet.ru/eng/dan31411>

[^fellegisunter]: Fellegi, I. P., & Sunter, A. B. (1969). A theory for record linkage. *Journal of the American Statistical Association*, 64(328), 1183–1210. <https://doi.org/10.1080/01621459.1969.10501049>

[^needlemanwunsch]: Needleman, S. B., & Wunsch, C. D. (1970). A general method applicable to the search for similarities in the amino acid sequence of two proteins. *Journal of Molecular Biology*, 48(3), 443–453. <https://doi.org/10.1016/0022-2836(70)90057-4>

[^wagnerfischer]: Wagner, R. A., & Fischer, M. J. (1974). The string-to-string correction problem. *Journal of the ACM*, 21(1), 168–173. <https://doi.org/10.1145/321796.321811>

[^lowrancewagner]: Lowrance, R., & Wagner, R. A. (1975). An extension of the string-to-string correction problem. *Journal of the ACM*, 22(2), 177–183. <https://doi.org/10.1145/321879.321880>

[^jaro]: Jaro, M. A. (1989). Advances in record-linkage methodology as applied to matching the 1985 census of Tampa, Florida. *Journal of the American Statistical Association*, 84(406), 414–420. <https://doi.org/10.1080/01621459.1989.10478785>

[^winkler1990]: Winkler, W. E. (1990). String comparator metrics and enhanced decision rules in the Fellegi-Sunter model of record linkage. In *Proceedings of the Section on Survey Research Methods* (pp. 354–359). American Statistical Association. <http://www.asasrms.org/Proceedings/papers/1990_056.pdf>

[^myers]: Myers, G. (1999). A fast bit-vector algorithm for approximate string matching based on dynamic programming. *Journal of the ACM*, 46(3), 395–415. <https://doi.org/10.1145/316542.316550>

[^backursindyk]: Backurs, A., & Indyk, P. (2015). Edit distance cannot be computed in strongly subquadratic time (unless SETH is false). In *Proceedings of the 47th Annual ACM Symposium on Theory of Computing* (pp. 51–58). ACM. <https://doi.org/10.1145/2746539.2746612>

[^navarro]: Navarro, G. (2001). A guided tour to approximate string matching. *ACM Computing Surveys*, 33(1), 31–88. <https://doi.org/10.1145/375360.375365>

[^cohen]: Cohen, W. W., Ravikumar, P., & Fienberg, S. E. (2003). A comparison of string distance metrics for name-matching tasks. In *Proceedings of the IJCAI-2003 Workshop on Information Integration on the Web (IIWeb-03)*. <https://www.cs.cmu.edu/~wcohen/postscript/ijcai-ws-2003.pdf>

[^ukkonen]: Ukkonen, E. (1985). Algorithms for approximate string matching. *Information and Control*, 64(1–3), 100–118. <https://doi.org/10.1016/S0019-9958(85)80046-2>

[^boytsov]: Boytsov, L. (2011). Indexing methods for approximate dictionary searching: Comparative analysis. *ACM Journal of Experimental Algorithmics*, 16. <https://doi.org/10.1145/1963190.1963191>

[^winkler2006]: Winkler, W. E. (2006). *Overview of record linkage and current research directions* (Research Report Series, Statistics #2006-2). Statistical Research Division, U.S. Census Bureau. <https://www.census.gov/content/dam/Census/library/working-papers/2006/adrm/rrs2006-02.pdf>

[^commonstext]: The Apache Software Foundation. (n.d.). JaroWinklerSimilarity [Source code]. In *Apache Commons Text*. <https://commons.apache.org/proper/commons-text/xref/org/apache/commons/text/similarity/JaroWinklerSimilarity.html>

[^rapidfuzzjw]: Bachmann, M. (n.d.). JaroWinkler. In *RapidFuzz documentation*. <https://rapidfuzz.github.io/RapidFuzz/Usage/distance/JaroWinkler.html>

[^smithwaterman]: Smith, T. F., & Waterman, M. S. (1981). Identification of common molecular subsequences. *Journal of Molecular Biology*, 147(1), 195–197. <https://doi.org/10.1016/0022-2836(81)90087-5>

[^jaccard]: Jaccard, P. (1912). The distribution of the flora in the alpine zone. *New Phytologist*, 11(2), 37–50. <https://doi.org/10.1111/j.1469-8137.1912.tb05611.x>
