---
title: "Git Submodules: One Repository Pinned Inside Another"
description: "A submodule is a Git repository inside another one, pinned to an exact commit. Here is what the superproject actually stores, how to add, clone, update, change and remove a submodule, the difference between the recorded commit and the latest one, the settings that make submodules less painful, the security changes that affect them, and when to use something else."
date: 2026-10-21T11:00:00Z
categories: ["Git"]
tags: ["Git", "Submodules", "Dependencies", "Version Control"]
# The diagrams are inlined by the diagram shortcode, so the SVG files
# themselves need not be published.
build:
  publishResources: false
---

This site is built with a Hugo theme I also maintain,
[nuno](https://github.com/artur-rios/hugo-theme-nuno), and the theme lives in
its own repository. The site needs an exact version of it, and I want to change
the theme without copying files back and forth. Git's answer is a
**submodule**: a repository placed inside another repository, the
*superproject*, which records exactly which commit of it to use. The site's
`themes/nuno` folder is one, and it is the example throughout this article.

Submodules have a reputation for being confusing, and most of the confusion
comes from one fact that is easy to miss: the superproject does not store the
submodule's files, or even a branch name. It stores **one commit hash**.
Everything else, from the empty folder after a plain clone to the detached
`HEAD` inside the submodule, follows from that.

The commands shown were run with Git 2.56 on 21 October 2026, against the real
theme repository on GitHub. Long temporary paths in the output are shortened
to `…`.

## What a submodule is

**A submodule is a Git repository embedded in another one, the superproject.
The superproject's commits record the submodule as a single entry, a
*gitlink*, holding the hash of the submodule commit it expects, plus a line in
a tracked `.gitmodules` file that says where to clone the submodule from.**

The Git manual lists three parts: the gitlink, which "contains the object name
of the commit that the superproject expects the submodule's working directory
to be at"; the `.gitmodules` entry; and a separate Git directory for the
submodule, kept "under the `$GIT_DIR/modules/` directory of its
superproject".[^gitsubmodules] The two histories stay apart: the superproject
does not contain the submodule's commits, and the submodule knows nothing
about the superproject.

{{< diagram src="anatomy.svg" caption="The superproject's tree records a gitlink, mode `160000`, holding one commit hash. `.gitmodules` says where to clone from. The commit itself lives in the submodule's own repository under `.git/modules`." >}}

The gitlink shows up in the superproject's tree with a mode no ordinary file or
directory has:

```txt
$ git ls-tree HEAD themes/
160000 commit 4b2c2b503e221ab1dfc77e67524ba82ebb6788db	themes/nuno
```

*Pro Git* calls `160000` "a special mode in Git that basically means you're
recording a commit as a directory entry rather than a subdirectory or a
file".[^progit] A normal subdirectory would appear as `040000 tree`. The commit
it names is not in the superproject's object database at all; asking the
superproject about it fails:

```txt
$ git cat-file -t 4b2c2b503e221ab1dfc77e67524ba82ebb6788db
fatal: git cat-file: could not get object info
```

That is why a clone of the superproject alone cannot fill the folder: the
files are in a different repository, which has to be cloned separately.

## Adding a submodule

`git submodule add` clones the repository into the given path and stages both
parts of the record:[^gitsubmodule]

```txt
$ git submodule add https://github.com/artur-rios/hugo-theme-nuno.git themes/nuno
Cloning into '…/site/themes/nuno'...
$ git status --short
A  .gitmodules
A  themes/nuno
$ cat .gitmodules
[submodule "themes/nuno"]
	path = themes/nuno
	url = https://github.com/artur-rios/hugo-theme-nuno.git
$ git diff --cached themes/nuno
diff --git a/themes/nuno b/themes/nuno
new file mode 160000
index 0000000..4b2c2b5
--- /dev/null
+++ b/themes/nuno
@@ -0,0 +1 @@
+Subproject commit 4b2c2b503e221ab1dfc77e67524ba82ebb6788db
```

The diff of a submodule is a single line, `Subproject commit` and a hash. The
submodule's own Git directory went to `.git/modules/themes/nuno`, and the
folder in the working tree got a one-line `.git` *file* pointing there:

```txt
$ cat themes/nuno/.git
gitdir: ../../.git/modules/themes/nuno
```

Keeping the repository inside the superproject's `.git` means the submodule's
folder can be deleted, or disappear on a branch switch, without losing its
history. Older versions of Git put a full `.git` directory inside the
submodule's folder; `git rm` only removes the folder for submodules "cloned
with a Git version 1.7.8 or newer", and `git submodule absorbgitdirs` moves an
old-style one into place.[^gitrm][^gitsubmodule]

A commit then records the pin. From now on, every commit of the superproject
says which commit of the theme it was built with.

### What `.gitmodules` can say

`path` and `url` are required. The `url` can be relative, starting with `./`
or `../`, in which case it is resolved against the superproject's own remote,
which helps when both repositories move hosts together. The optional keys
are:[^gitmodules]

| Key | What it does |
|---|---|
| `branch` | The remote branch `git submodule update --remote` follows. Defaults to the remote `HEAD`; `.` means "the same name as the superproject's current branch". |
| `update` | The default way `git submodule update` applies the recorded commit: `checkout`, `rebase`, `merge` or `none`. A custom `!command` is refused here "for security reasons". |
| `fetchRecurseSubmodules` | Whether fetching the superproject also fetches this submodule. |
| `ignore` | When `git status` and `git diff` report the submodule as modified: `none` (the default), `untracked`, `dirty` or `all`. |
| `shallow` | Clone the submodule with a history depth of 1. |

`.gitmodules` is a template. `git submodule init` copies the URL into the
superproject's `.git/config`, and from then on the local value wins, which is
why changing a URL takes `git submodule sync` as well as an edit.

## Cloning a project that has submodules

A plain clone brings the gitlink and `.gitmodules`, but not the submodule:

```txt
$ git clone site clone-plain
$ ls -A clone-plain/themes/nuno | wc -l
0
$ cd clone-plain
$ git submodule status
-4b2c2b503e221ab1dfc77e67524ba82ebb6788db themes/nuno
```

The leading `-` means the submodule "is not initialized".[^gitsubmodule] For
this site that means an empty `themes/nuno` folder, and Hugo builds an empty
site, which is why the README says to clone with `--recurse-submodules`.
Either fix works:

```txt
$ git submodule update --init
Submodule 'themes/nuno' (https://github.com/artur-rios/hugo-theme-nuno.git) registered for path 'themes/nuno'
Cloning into '…/clone-plain/themes/nuno'...
Submodule path 'themes/nuno': checked out '4b2c2b503e221ab1dfc77e67524ba82ebb6788db'
$ git submodule status
 4b2c2b503e221ab1dfc77e67524ba82ebb6788db themes/nuno (heads/main)
```

`--init` registers every submodule not yet initialised and then updates it; add
`--recursive` for submodules that contain submodules of their own. Passing
`--recurse-submodules` to `git clone` does all of this in one
step.[^progit][^gitsubmodule]

```bash
git clone --recurse-submodules https://github.com/artur-rios/personal-lab.git
# or, after a plain clone
git submodule update --init --recursive
```

## The pinned commit and the detached `HEAD`

Look inside a freshly updated submodule and it is not on a branch:

```txt
$ cd themes/nuno
$ git status
HEAD detached at 4b2c2b5
nothing to commit, working tree clean
```

That is the default update procedure, `checkout`: "the commit recorded in the
superproject will be checked out in the submodule on a detached
`HEAD`".[^gitsubmodule] It is not an error. The superproject asked for a
commit, not a branch, so Git checks out exactly that commit. It does become a
trap the moment you start editing inside the submodule; see
[working inside a submodule](#working-inside-a-submodule).

The superproject notices when the submodule's checkout and the recorded commit
disagree. Moving the theme back three commits:

```txt
$ git -C themes/nuno checkout -q HEAD~3
$ git submodule status
+443ed26c2c0ae6bb73d08534fad411272652003c themes/nuno (443ed26)
$ git status --short
 M themes/nuno
$ git diff --submodule=log
Submodule themes/nuno 4b2c2b5..443ed26 (rewind):
  < Navigate a series from the aside, with the table of contents as a tab (#17)
  < Show postsOnHome posts on mobile, and raise the keyboard when search opens (#16)
  < Cut 0.2.2 (#15)
```

The `+` in `git submodule status` means the checked-out commit "does not match
the SHA-1 found in the index of the containing repository"; a `U` would mean
merge conflicts.[^gitsubmodule] To the superproject, a different commit in
the submodule is just a modified path. `git add themes/nuno` and a commit make
it the new pin; `git submodule update` throws the change away and goes back to
the recorded commit.

## Updating: the recorded commit or the latest one

There are two different things "update the submodule" can mean, and the
commands for them look alike.

{{< diagram src="update-modes.svg" caption="`git submodule update` and `git pull --recurse-submodules` go to the commit the superproject recorded. `git submodule update --remote` goes to the tip of the tracked branch, and the new pointer still has to be committed." >}}

**Following the superproject.** When someone else bumps the pin and you pull,
the submodule should move to the commit they recorded.
`git pull --recurse-submodules` does that: it fetches "new commits of
populated submodules" and updates the working trees of active submodules as
well.[^gitpull] In this run a teammate had moved the theme from `714a917` to
`22bc5dc`. The theme's `main` was already at `4b2c2b5`, and the pull stopped at
the recorded commit:

```txt
$ git submodule status
 714a917f4e0c952f3ecee761bc58058f01db6706 themes/nuno (714a917)
$ git pull --recurse-submodules
Fetching submodule themes/nuno
Submodule path 'themes/nuno': checked out '22bc5dcdac245fc8bcc77ef262b07dfa55ab321b'
```

Without the flag, a plain `git pull` updates the gitlink but leaves the
submodule's files where they were, and `git submodule update` has to follow.
That is the default unless `submodule.recurse` is set.

**Following the submodule's upstream.** To move to the newest commit of the
theme, which nobody has recorded yet, use `--remote`. Instead of the recorded
hash it uses "the status of the submodule's remote-tracking branch", by default
the remote `HEAD`, unless `submodule.<name>.branch` names a
branch:[^gitsubmodule]

```txt
$ git submodule update --remote
Submodule path 'themes/nuno': checked out '4b2c2b503e221ab1dfc77e67524ba82ebb6788db'
$ git submodule status
+4b2c2b503e221ab1dfc77e67524ba82ebb6788db themes/nuno (heads/main)
$ git status --short
 M themes/nuno
```

The `+` is back: the submodule is ahead of the pin. Nobody else gets the new
version until the superproject commits it:

```bash
git add themes/nuno
git commit -m "Update the nuno theme"
```

To follow a branch other than the default, record it in `.gitmodules` with
`git submodule set-branch --branch stable themes/nuno`, or edit the file;
`--remote` then fetches and checks out that branch's tip.[^gitsubmodule]
`git submodule update --remote --merge` or `--rebase` merges or rebases the
upstream changes into a local branch instead of detaching.

## Working inside a submodule

The submodule is a full repository, so you can commit in it. The trap is the
detached `HEAD`: *Pro Git* warns that, with no working branch, "even if you
commit changes to the submodule, those changes will quite possibly be lost the
next time you run `git submodule update`".[^progit] Before editing, put the
submodule on a branch:

```bash
cd themes/nuno
git switch main
# edit, commit
git push
cd ../..
git add themes/nuno
git commit -m "Use the new theme commit"
git push
```

**Order matters.** The submodule's commit must be pushed before the
superproject's commit that points to it. Otherwise the superproject records a
commit nobody else can fetch, and their `git submodule update` fails. `git push
--recurse-submodules=check` makes the push of the superproject fail if a
referenced submodule commit is on no remote; `on-demand` pushes the submodules
first.[^gitpush]

`git submodule foreach` runs a command in every checked-out submodule, which
helps once there are several:

```txt
$ git submodule foreach 'git log --oneline -1'
Entering 'themes/nuno'
4b2c2b5 Navigate a series from the aside, with the table of contents as a tab (#17)
Entering 'vendor/lib'
e1cc8be lib
```

When two branches of the superproject move the same submodule to different
commits, Git fast-forwards if one commit descends from the other and reports a
conflict otherwise, "suggesting as a resolution a submodule commit that is
descendant of the conflicting ones, if one exists".[^gitpull] The fix is made
inside the submodule, by merging the two commits, and then recorded in the
superproject.[^progit]

## Removing a submodule

Two commands, for two different intentions. `git submodule deinit` only
removes the local checkout, and the submodule stays part of the project:

```txt
$ git submodule deinit vendor/lib
Cleared directory 'vendor/lib'
Submodule 'vendor/lib' (../lib) unregistered for path 'vendor/lib'
$ git submodule status
 4b2c2b503e221ab1dfc77e67524ba82ebb6788db themes/nuno (heads/main)
-e1cc8bed42b1da497fc08f398a1dc5e95d9b0a72 vendor/lib
```

It "only modifies the superproject's `$GIT_DIR/config` file", and
`git submodule init` undoes it.[^gitsubmodules] To take the submodule out of
the project, use `git rm`, which removes the gitlink and the folder and also
deletes the section from `.gitmodules` and stages it:[^gitrm]

```txt
$ git rm vendor/lib
rm 'vendor/lib'
$ git status --short
M  .gitmodules
D  vendor/lib
$ ls .git/modules/vendor
lib
```

The submodule's repository is still in `.git/modules`, so checking out an old
commit can restore it. To remove every trace, the manual says to "manually
delete `$GIT_DIR/modules/<name>/`" as well.[^gitsubmodules]

## Settings that make submodules easier

| Setting | Effect |
|---|---|
| `git config --global submodule.recurse true` | Commands that support `--recurse-submodules`, such as `checkout`, `switch`, `pull` and `grep`, recurse by default. `clone` still needs its own flag.[^gitsubmodules][^config] |
| `git config --global diff.submodule log` | `git diff` lists the commits between the two pins instead of two bare hashes.[^config] |
| `git config --global status.submoduleSummary true` | `git status` adds a summary of commits for modified submodules.[^config] |
| `git config --global push.recurseSubmodules check` | Refuse to push a superproject commit whose submodule commits are on no remote.[^config] |

`git submodule summary` gives the same commit list on demand:

```txt
$ git submodule summary HEAD~1
* themes/nuno 4b2c2b5...443ed26 (3):
  < Navigate a series from the aside, with the table of contents as a tab (#17)
  < Show postsOnHome posts on mobile, and raise the keyboard when search opens (#16)
  < Cut 0.2.2 (#15)
```

## Submodules and security

A recursive clone makes Git fetch repositories that the repository you asked
for chose, and check out files they contain. Git has tightened that path more
than once.

- **Local submodules are refused by default.** Since Git 2.30.6 and 2.38.1,
  released in October 2022 with the fix for CVE-2022-39253,
  `protocol.file.allow` defaults to `user`.[^rel2306] The `file` protocol then
  works only when the user runs the command directly, not for "commands which
  execute clone/fetch/push commands without user input, e.g. recursive
  submodule initialization".[^config] That is why adding a submodule from a
  local path fails:

  ```txt
  $ git submodule add ../lib vendor/lib
  Cloning into '…/site/vendor/lib'...
  fatal: transport 'file' not allowed
  fatal: clone of '…/lib' into submodule path '…/site/vendor/lib' failed
  ```

  For a one-off test with a repository you trust,
  `git -c protocol.file.allow=always submodule add ../lib vendor/lib` allows it
  for that command only.
- **Recursive clones have been an attack path.** CVE-2024-32002, fixed in
  May 2024 in Git 2.39.4, 2.45.1 and other maintenance releases, let a
  crafted repository with submodules run code during
  `git clone --recurse-submodules` on case-insensitive filesystems that
  support symbolic links, as Windows and macOS usually do.[^rel2394]
- **`.gitmodules` cannot run commands.** The `update = !command` form is
  accepted only in your own configuration, never from a cloned
  `.gitmodules`.[^gitmodules]

The practical rules: keep Git up to date, and only clone untrusted
repositories recursively after looking at their `.gitmodules`.

## A short history

- **Git 1.5.2 (2007)** added the plumbing: "you can include a subdirectory that
  has an independent git repository in your index and tree objects", with
  recursive behaviour explicitly left out.[^rel152]
- **Git 1.5.3 (2007)** added the `git submodule` command, with release notes
  warning that support was "minimal" and that commands at the superproject
  level did not recurse into submodules.[^rel153]
- **Git 1.7.8 (2011)** began keeping a submodule's repository inside the
  superproject's `.git` directory, behind a `.git` file.[^gitrm]
- **Git 2.13 and 2.14 (2017)** made `checkout --recurse-submodules` put
  submodules in the right state on a branch switch, and added
  `submodule.recurse` to make that the default.[^progit]
- **October 2022 and May 2024** brought the security changes above.

## When to use a submodule, and when not

The manual gives two main uses: using another project "while keeping the
history of both projects separate", and splitting one large project into
several repositories, for repository size, transfer size or access
control.[^gitsubmodules] A submodule fits when you need **an exact, reviewable
version** of another repository and may want to change it in place, as with
this site and its theme.

It fits less well when every contributor would have to learn the workflow for
little gain. Two alternatives:

- **A package manager**, when the dependency is published as a package and you
  never edit it in place: npm, NuGet or Go modules pin versions just as
  exactly, with tooling everyone already knows.
- **`git subtree`**, which copies the other project's files into a
  subdirectory and its history into yours. Its documentation stresses that
  subtrees "do not need any special constructions (like '.gitmodules' files or
  gitlinks)" and "do not force end-users of your repository to do anything
  special".[^subtree] The price is a larger repository and a more awkward way
  to send changes back upstream.

## Common misunderstandings

| Misunderstanding | What is actually true |
|---|---|
| "The superproject contains the submodule's files." | It contains one commit hash, the gitlink. The files come from the submodule's own repository. |
| "A submodule tracks a branch." | It is pinned to a commit. A `branch` in `.gitmodules` only tells `update --remote` where to look for a newer one. |
| "`git pull --recurse-submodules` gets the latest submodule commit." | It moves the submodule to the commit the superproject recorded. `git submodule update --remote` gets the latest. |
| "The detached `HEAD` in a submodule is a problem." | It is the default and correct for reading. Switch to a branch before committing in it. |
| "Committing in the submodule updates the project." | The superproject keeps the old pin until you commit the gitlink change, and the submodule commit must be pushed first. |
| "`git submodule deinit` removes a submodule." | It removes only the local checkout. `git rm` removes it from the project. |

## References

[^gitsubmodules]: Git Project. (n.d.). *gitsubmodules: Mounting one repository inside another*. Git reference manual. <https://git-scm.com/docs/gitsubmodules>

[^gitsubmodule]: Git Project. (n.d.). *git-submodule*. Git reference manual. Subcommands, update procedures, `--remote` and `status`. <https://git-scm.com/docs/git-submodule>

[^gitmodules]: Git Project. (n.d.). *gitmodules: Defining submodule properties*. Git reference manual. <https://git-scm.com/docs/gitmodules>

[^progit]: Chacon, S., & Straub, B. (2014). Git tools: Submodules. In *Pro Git* (2nd ed., section 7.11). Apress. <https://git-scm.com/book/en/v2/Git-Tools-Submodules>

[^gitpull]: Git Project. (n.d.). *git-pull*. Git reference manual. Option `--recurse-submodules` and the `ort` merge strategy. <https://git-scm.com/docs/git-pull>

[^gitpush]: Git Project. (n.d.). *git-push*. Git reference manual. Option `--recurse-submodules`. <https://git-scm.com/docs/git-push>

[^gitrm]: Git Project. (n.d.). *git-rm*. Git reference manual. Section "Submodules". <https://git-scm.com/docs/git-rm>

[^config]: Git Project. (n.d.). *git-config*. Git reference manual. Entries for `submodule.recurse`, `diff.submodule`, `status.submoduleSummary`, `push.recurseSubmodules` and `protocol.allow`. <https://git-scm.com/docs/git-config>

[^rel2306]: Git Project. (2022, October 18). *Git v2.30.6 release notes*. CVE-2022-39253 and the `protocol.file.allow` default. <https://github.com/git/git/blob/master/Documentation/RelNotes/2.30.6.adoc>

[^rel2394]: Git Project. (2024, May 14). *Git v2.39.4 release notes*. CVE-2024-32002. <https://github.com/git/git/blob/master/Documentation/RelNotes/2.39.4.adoc>

[^rel152]: Git Project. (2007). *Git v1.5.2 release notes*. <https://github.com/git/git/blob/master/Documentation/RelNotes/1.5.2.adoc>

[^rel153]: Git Project. (2007). *Git v1.5.3 release notes*. <https://github.com/git/git/blob/master/Documentation/RelNotes/1.5.3.adoc>

[^subtree]: Git Project. (n.d.). *git-subtree*. Git source, `contrib/subtree`. <https://github.com/git/git/blob/master/contrib/subtree/git-subtree.adoc>
