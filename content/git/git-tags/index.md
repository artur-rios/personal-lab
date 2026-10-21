---
title: "Git Tags: Naming the Commits That Matter"
description: "A tag gives a commit a permanent, human name such as v1.6.0. Here is the difference between lightweight and annotated tags and how each is stored, how to create, list, describe, share, delete and check out tags, why moving a published tag is a bad idea, how tags fit with semantic versioning and release pipelines, and what this site's own release tags reveal."
date: 2026-10-21T12:00:00Z
categories: ["Git"]
tags: ["Git", "Tags", "Releases", "Versioning", "Version Control"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

Branches move: every commit on `main` moves `main` forward. Sometimes you need
a name that stays where it is put, such as "the commit that went out as
version 1.6.0". That is a **tag**. Tags mark releases, the build a bug report
refers to, or the last commit before a large refactor, and almost every
release tool, from GitHub Releases to package registries, reads them.

Tags look simple, and mostly are. The parts that cause trouble are the two
kinds of tag, which behave differently in some commands, and the fact that
tags are not pushed, fetched or overwritten the way branches are. This article
covers both. The commands shown were run with Git 2.56 on 21 October 2026, in
a scratch repository and in this site's own repository. Long temporary paths
in the output are left out.

## What a tag is

**A tag is a reference under `refs/tags/` that names one object, nearly
always a commit, and is not meant to move. A lightweight tag is only that
reference. An annotated tag points to a tag object, which stores the tagger,
a date and a message, and which points to the commit.**

*Pro Git* puts the lightweight kind in one line: "That is all a lightweight
tag is — a reference that never moves." For an annotated tag, "Git creates a
tag object and then writes a reference to point to it rather than directly to
the commit".[^progitrefs] The Git manual says what each kind is for:
"Annotated tags are meant for release while lightweight tags are meant for
private or temporary object labels."[^gittag]

{{< diagram src="tag-objects.svg" caption="Both tags name the same commit. The lightweight one points straight at it; the annotated one points at a tag object that records who tagged it, when and why." >}}

Creating one of each on the same commit shows the difference:

```txt
$ git tag v1.0.0-lw
$ git tag -a v1.0.0 -m "Release 1.0.0"
$ git cat-file -t v1.0.0-lw
commit
$ git cat-file -t v1.0.0
tag
$ git cat-file -p v1.0.0
object f9d0f72027d468d3c869ee9a50b1de4930590b90
type commit
tag v1.0.0
tagger Artur Rios <arturdev@duck.com> 1792576800 +0000

Release 1.0.0
```

The lightweight tag resolves to the commit itself. The annotated one resolves
to a tag object with a hash of its own, `f09f2bf`, whose `object` line is the
commit. Both are just entries under `refs/tags`:

```txt
$ git show-ref --tags
f09f2bf36bddbba603b64701bde2935545d2709e refs/tags/v1.0.0
f9d0f72027d468d3c869ee9a50b1de4930590b90 refs/tags/v1.0.0-lw
$ git rev-parse "v1.0.0^{}"
f9d0f72027d468d3c869ee9a50b1de4930590b90
```

The `^{}` suffix *peels* a tag: it follows tag objects until it reaches
something that is not a tag. Anywhere Git expects a commit, such as
`git checkout v1.0.0` or `git log v1.0.0`, it peels the tag for you.

A tag object does not have to point at a commit: "you can tag any Git
object". The Git project's own repository has a tag, `junio-gpg-pub`, that
points at a blob holding the maintainer's public key.[^progitrefs]

### Lightweight or annotated?

| | Lightweight | Annotated |
|---|---|---|
| Stored as | A ref to the commit | A ref to a tag object |
| Records | Nothing beyond the commit | Tagger, date, message, optional signature |
| Created with | `git tag <name>` | `git tag -a <name> -m "…"` |
| Seen by `git describe` | Only with `--tags` | Yes, by default |
| Pushed by `--follow-tags` | No | Yes |
| Meant for | Private or temporary labels | Releases |

*Pro Git* "generally recommends" annotated tags and keeps lightweight ones for
temporary use.[^progittag] The table shows why the choice matters beyond
taste: two of the commands most used around releases ignore lightweight tags
unless told otherwise.

## Creating tags

```bash
git tag v1.0.0                            # lightweight, on HEAD
git tag -a v1.0.0 -m "Release 1.0.0"      # annotated, on HEAD
git tag -a v1.1.0 -m "Release 1.1.0" 9fceb02   # annotated, on an older commit
git tag -s v1.0.0 -m "Release 1.0.0"      # annotated and signed
```

`-a` makes "an unsigned, annotated tag object"; without `-m`, Git opens an
editor for the message. `-s` makes a signed one, "using the default signing
key", and `-u <key-id>` picks a key.[^gittag] `git tag -v <name>` checks the
signature. Signing proves who made the tag, which matters when others build or
install from it.

To tag a commit after the fact, give its hash or any other name for it, as in
the third line above.[^progittag] An annotated tag records the date it was
*created*, not the commit's date; for imported history, the manual shows how
to backdate it with the `GIT_COMMITTER_DATE` environment variable.[^gittag]

## Listing and finding tags

`git tag` alone lists every tag, alphabetically. A pattern needs `-l` (or
`--list`):[^progittag]

```txt
$ git tag -l 'v1.1*'
v1.1.0
v1.10.0
```

Alphabetical order is the wrong order for versions. In a repository tagged
`v1.0.0` to `v1.10.0`:

```txt
$ git tag | head -4
v1.0.0
v1.1.0
v1.10.0
v1.2.0
$ git tag --sort=-v:refname | head -3
v1.10.0
v1.9.0
v1.8.0
```

`--sort=v:refname` treats the names as versions, and the leading `-` reverses
the order, newest first.[^gittag] `git config --global tag.sort -v:refname`
makes that the default.[^config] Three more filters are useful:

- **`-n`** prints the first line of each tag's message; for a lightweight tag
  that is the commit's subject.
- **`--contains <commit>`** lists the tags that include a commit, which answers
  "which releases have this fix?".
- **`--points-at <object>`** lists the tags on exactly that commit.[^gittag]

```txt
$ git tag -n1
v1.0.0          Release 1.0.0
v1.0.0-lw       First feature
v1.1.0          Release 1.1.0
$ git tag --contains HEAD~1
v1.1.0
```

## Describing a commit by its nearest tag

`git describe` names any commit relative to the most recent tag before it,
which makes a version string for builds between releases:

```txt
$ git log --oneline
729f95f Fix a bug
62a7e12 Second feature
f9d0f72 First feature
$ git describe
v1.0.0-2-g729f95f
$ git describe --dirty
v1.0.0-2-g729f95f-dirty
```

Read it as three parts: the nearest tag, `v1.0.0`; the number of commits since
it, `2`; and `g` followed by the abbreviated hash of the commit, `729f95f`. The
`g` "stands for 'git'".[^gitdescribe] `--dirty` appends `-dirty` when the
working tree has uncommitted changes, `--abbrev=0` prints only the tag, and
`--always` falls back to a bare hash when no tag is found.

By default `git describe` "only shows annotated tags"; `--tags` lets it use
lightweight ones too.[^gitdescribe] That default matters in the last section
of this article.

## Sharing tags

Tags do not travel with a normal push: "By default, the `git push` command
doesn't transfer tags to remote servers."[^progittag] After pushing `main`,
the remote has no tags at all:

```txt
$ git push origin main
 * [new branch]      main -> main
$ git ls-remote --tags origin
$
```

There are three ways to send them:

```bash
git push origin v1.0.0          # one tag
git push --follow-tags          # annotated tags reachable from what you push
git push origin --tags          # every tag, of both kinds
```

`--follow-tags` pushes "annotated tags in `refs/tags` that are missing from
the remote but are pointing at commit-ish that are reachable from the refs
being pushed".[^gitpush] It is the safest default, because it sends release
tags with the commits they belong to and leaves private lightweight tags
behind:

```txt
$ git push --follow-tags origin main
 * [new tag]         v1.0.0 -> v1.0.0
 * [new tag]         v1.1.0 -> v1.1.0
$ git ls-remote --tags origin
f09f2bf36bddbba603b64701bde2935545d2709e	refs/tags/v1.0.0
f9d0f72027d468d3c869ee9a50b1de4930590b90	refs/tags/v1.0.0^{}
f56919b95c288480164add4dc91ccfb4426dc503	refs/tags/v1.1.0
62a7e127d7df881789e46d52a20dbf245fff5b24	refs/tags/v1.1.0^{}
```

`v1.0.0-lw` stayed local. The `^{}` lines are the remote showing each
annotated tag peeled to its commit. `git config --global push.followTags true`
makes every push behave like this.[^gitpush] `--tags`, by contrast, pushes
everything under `refs/tags`, including tags you meant to keep to yourself.

On the other side, `git fetch` and `git pull` bring in tags that point at
commits they download, and `git fetch --tags` brings every tag.

## Deleting tags

Locally:

```bash
git tag -d v1.0.0
```

"This does not remove the tag from any remote servers."[^progittag] On a
remote:

```bash
git push origin --delete v1.0.0
git push origin :refs/tags/v1.0.0     # the older form: push "nothing" to the tag
```

```txt
$ git push origin --delete v1.0.0-lw
 - [deleted]         v1.0.0-lw
```

To delete *every* tag, remote ones first, because the local list is what
drives the loop. In PowerShell:

```powershell
git tag -l | ForEach-Object { git push origin --delete $_ }
git tag -l | ForEach-Object { git tag -d $_ }
```

And in a POSIX shell, where the remote deletions fit in one push:

```bash
git push origin --delete $(git tag -l)
git tag -l | xargs git tag -d
```

Deleting a remote tag does not delete it from anyone else's clone, and a later
`git push --tags` from such a clone puts it back. Releases built from the
tag, and any GitHub release attached to it, are not affected either.

## Moving a tag, and why not to

A tag is meant to stay put, and Git defends that. Creating a tag that already
exists fails; `-f` will "replace an existing tag with the given name (instead
of failing)":[^gittag]

```txt
$ git tag -a v1.1.0 -m "Release 1.1.0"
fatal: tag 'v1.1.0' already exists
$ git tag -f -a v1.1.0 -m "Release 1.1.0, take two"
Updated tag 'v1.1.0' (was f56919b)
```

The remote refuses the moved tag, and forcing it through changes only the
remote:

```txt
$ git push origin v1.1.0
 ! [rejected]        v1.1.0 -> v1.1.0 (already exists)
hint: Updates were rejected because the tag already exists in the remote.
$ git push --force origin v1.1.0
 + f56919b...544e5b9 v1.1.0 -> v1.1.0 (forced update)
```

A teammate who already had `v1.1.0` keeps the old one. A plain fetch is silent,
and an explicit tag fetch refuses to overwrite it:

```txt
$ git rev-parse --short "v1.1.0^{}"
62a7e12
$ git fetch
$ git fetch --tags
 ! [rejected] v1.1.0     -> v1.1.0  (would clobber existing tag)
$ git rev-parse --short "v1.1.0^{}"
62a7e12
$ git fetch --tags --force
 t [tag update]      v1.1.0     -> v1.1.0
$ git rev-parse --short "v1.1.0^{}"
729f95f
```

Now the same name means two different commits, depending on who you ask.
That is deliberate: "Git does **not** (and it should not) change tags behind
users back."[^gittag] The manual's "On Re-tagging" section names the two
options. "The sane thing" is to "admit you screwed up, and use a different
name", say `v1.1.1`. "The insane thing" is to force the old name and ask
everyone who fetched it to delete their copy.[^gittag] Once a tag has been
pushed, release a new version instead of moving the tag.

## Checking out a tag

```txt
$ git checkout v1.0.0
Note: switching to 'v1.0.0'.

You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you make in this
state without impacting any branches by switching back to a branch.
…
HEAD is now at f9d0f72 First feature
```

A tag is not a branch, so checking one out detaches `HEAD`. Commits made there
"won't belong to any branch and will be unreachable, except by the exact
commit hash".[^progittag] To fix an old release, start a branch at the tag:

```txt
$ git switch -c fix-1.0 v1.0.0
Switched to a new branch 'fix-1.0'
```

## Naming tags: semantic versions and the `v`

Most projects name release tags after a version number, and most version
numbers follow Semantic Versioning: MAJOR.MINOR.PATCH, where you increment the
major version for incompatible changes, the minor version for compatible new
functionality and the patch version for compatible bug fixes.[^semver]

The leading `v` is a convention, not part of the version. The SemVer FAQ says
"v1.2.3" is not a semantic version, but that prefixing one with a "v" is "a
common way (in English) to indicate it is a version number", and that in
`git tag v1.2.3` the tag name is "v1.2.3" while the semantic version is
"1.2.3".[^semver] Pick one style and keep it, because tools that read tags,
from `--sort=v:refname` to release automation, work best with consistent
names.

## Tags in a release pipeline: this site as an example

This site tags its own releases. When a `release/x.y.z` pull request is merged
into `main`, the Deploy workflow publishes the site and then runs
`gh release create "v1.6.0" --target "$SHA"` to create the GitHub release. The
GitHub CLI documents that "if a matching git tag does not yet exist, one will
automatically get created".[^ghrelease] Looking at those tags locally shows
what kind they are:

```txt
$ git tag -l --sort=-v:refname | head -3
v1.6.0
v1.5.0
v1.4.0
$ git cat-file -t v1.6.0
commit
$ git describe origin/main
fatal: No annotated tags can describe '5b9997ee829862e9e78e70f15bd2b12e16acb77c'.
However, there were unannotated tags: try --tags.
$ git describe --tags origin/main
v1.6.0
```

The automatically created tags are **lightweight**: no tagger, no message, and
invisible to `git describe` and `--follow-tags` unless asked. For this site
that costs nothing, since nothing reads the version from Git, and the release
notes live on the GitHub release instead. A project that stamps builds with
`git describe` would want annotated tags. The CLI's own route is to "first
create one locally with git, push the tag to GitHub, then run this command",
with `--verify-tag` to stop if the tag is missing and `--notes-from-tag` to
reuse its message.[^ghrelease]

The output shows one more thing. The release tags sit on the merge commits on
`main`, and `develop` never contains those commits, so `git describe` on
`develop` finds no tag at all:

```txt
$ git describe --tags develop
fatal: No tags can describe '0ab26cbf9e1805af7afe4fa5c847c8b71aa4d0f0'.
Try --always, or create some tags.
```

Tags live on the commits they name. In a branching model where releases are
merge commits on a separate branch, version strings computed from tags only
work on that branch.

## Good practice

- **Use annotated tags for anything you publish**, and lightweight tags only
  for private bookmarks.
- **Push them on purpose.** `push.followTags` sends release tags with their
  commits and keeps private ones local.
- **Keep names consistent**, such as `v1.0.0`, `v2.1.3`, and sort them with
  `--sort=-v:refname`.
- **Never move a published tag.** Release a new version instead.
- **Sign release tags** when others install or build from them.
- **Clean up unused tags** both locally and on the remote, remote first.

## Common misunderstandings

| Misunderstanding | What is actually true |
|---|---|
| "`git push` sends my tags." | It sends none by default. Use `--follow-tags`, `--tags` or the tag's name. |
| "Lightweight and annotated tags behave the same." | `git describe` and `--follow-tags` ignore lightweight tags unless told otherwise. |
| "A tag is a kind of branch." | A branch moves with each commit; a tag stays. Checking out a tag detaches `HEAD`. |
| "Deleting a remote tag removes it everywhere." | Every clone keeps its copy, and a `git push --tags` from one restores it. |
| "Moving a tag with `-f` fixes a bad release." | Clones that already fetched it keep the old commit. Use a new version number. |
| "`v1.2.3` is a semantic version." | It is a tag name; the semantic version is `1.2.3`. |

## References

[^gittag]: Git Project. (n.d.). *git-tag*. Git reference manual. Options, "On Re-tagging" and "On Backdating Tags". <https://git-scm.com/docs/git-tag>

[^progittag]: Chacon, S., & Straub, B. (2014). Git basics: Tagging. In *Pro Git* (2nd ed., section 2.6). Apress. <https://git-scm.com/book/en/v2/Git-Basics-Tagging>

[^progitrefs]: Chacon, S., & Straub, B. (2014). Git internals: Git references. In *Pro Git* (2nd ed., section 10.3). Apress. <https://git-scm.com/book/en/v2/Git-Internals-Git-References>

[^gitdescribe]: Git Project. (n.d.). *git-describe*. Git reference manual. <https://git-scm.com/docs/git-describe>

[^gitpush]: Git Project. (n.d.). *git-push*. Git reference manual. Options `--follow-tags`, `--tags` and `--delete`. <https://git-scm.com/docs/git-push>

[^config]: Git Project. (n.d.). *git-config*. Git reference manual. Entries for `tag.sort` and `push.followTags`. <https://git-scm.com/docs/git-config>

[^semver]: Preston-Werner, T. (n.d.). *Semantic Versioning 2.0.0*. <https://semver.org/>

[^ghrelease]: GitHub. (n.d.). *gh release create*. GitHub CLI manual. <https://cli.github.com/manual/gh_release_create>
