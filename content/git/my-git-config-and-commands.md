---
title: "My Git Config and the Commands I Keep Reaching For"
description: "The global settings I put on every new machine, the one alias I use every day, and five operations I look up often enough to keep written down: rewriting commit authors, re-applying a new .gitignore, renaming branches, drawing the branch graph and undoing pushed commits."
date: 2026-10-21T10:00:00Z
categories: ["Git"]
tags: ["Git", "Git Config", "Aliases", "Rebase", "Branches", "Reference"]
---

This page is a reference rather than an article: the global configuration I set
on every new machine, and the commands I look up often enough to keep written
down. Each one comes with what it actually does and, where it rewrites history
or throws work away, what to watch out for. Every command here was run against
Git 2.56 on 21 October 2026, and the explanations follow the official Git
reference pages linked at the end.

## Setting up a new machine

Three settings, written once to the global configuration file:

```bash
git config --global user.name "Artur Rios"
git config --global user.email artur.dev@duck.com
git config --global init.defaultBranch main
```

`--global` writes to `~/.gitconfig` (or to `$XDG_CONFIG_HOME/git/config` if
that file exists and `~/.gitconfig` does not), so the settings apply to every
repository for the current user.[^config] A setting written without `--global`
goes to the current repository's `.git/config` and wins over the global one,
which is how a work repository can use a different email.

- **`user.name` and `user.email`** are the identity Git writes into every
  commit as its author and committer. They are not an account and nothing
  checks them: hosting services match the email to an account to show an
  avatar and a profile link.
- **`init.defaultBranch`** names the first branch that `git init` creates.
  The setting arrived in Git 2.28, which made "the default name used for the
  first branch in newly created repositories" configurable.[^rel228] Without
  it Git still uses `master`, with a hint on every `git init`. It only affects
  new repositories; an existing branch is renamed as shown
  [further down](#renaming-a-branch).

The result in `~/.gitconfig`:

```ini
[user]
	name = Artur Rios
	email = artur.dev@duck.com
[init]
	defaultBranch = main
[alias]
	undo = reset --soft HEAD^
```

`git config --global --list` prints it back, and
`git config --show-origin user.email` shows which file a value came from when a
repository overrides it. Recent versions of Git also accept the subcommand
form, `git config set --global user.name "Artur Rios"`; the form above still
works.[^config]

## The `undo` alias

```bash
git config --global alias.undo "reset --soft HEAD^"
```

An alias makes `git undo` run `git reset --soft HEAD^`.[^config] `HEAD^` is the
parent of the current commit, so the branch moves back by one commit.
`--soft` leaves "your working tree files and the index unchanged":[^reset] the
commit disappears from the branch, but every change it made is still there and
still staged. It is the quickest way to fix a commit you have just made, by
adding a forgotten file or rewording the message, and committing again:

```txt
$ git log --oneline
68fc720 three
5973151 two
9079698 one
$ git undo
$ git status --short
M  f
$ git log --oneline
5973151 two
9079698 one
```

{{< callout type="warning" >}}
Use it only on commits you have not pushed. Once a commit is on a shared
branch, removing it rewrites history that others may have built on; see
[undoing pushed commits](#undoing-pushed-commits).
{{< /callout >}}

For the same job on the last commit only, `git commit --amend` does it in one
step: the Git manual describes it as a rough equivalent of
`git reset --soft HEAD^` followed by a new commit.[^commit] The alias is still
handy when you want to split the commit or rethink it before committing again.
`HEAD~1` means the same as `HEAD^`, and is easier to type in shells where `^`
is special, such as `cmd.exe`.

## Rewriting the author of every commit on a branch

When a branch was committed with the wrong identity, say the work email on a
personal project, fix the configuration first and then replay the branch:

```bash
git rebase main --exec 'git commit --amend --no-edit --reset-author'
```

`git rebase main` replays the commits of the current branch that are not on
`main`, one at a time. `--exec` appends a command after each commit it
recreates, and stops the rebase if the command fails.[^rebase] The command
amends that commit without opening an editor (`--no-edit`), and
`--reset-author` declares "that the authorship of the resulting commit now
belongs to the committer", meaning the identity now in your configuration. It
"also renews the author timestamp".[^commit]

```txt
$ git log --format='%h %an <%ae> %s' main..feature
da828f5 Artur Rios <artur.dev@duck.com> three
6b758ea Artur Rios <artur.dev@duck.com> two
```

Only the commits after `main` change; `main` itself keeps its old author. Every
rewritten commit gets a new hash, so a branch that was already pushed needs a
force push afterwards, with the same caveats as below. The original author
dates are lost too.

## Re-applying a new `.gitignore`

Adding a path to `.gitignore` does not stop Git tracking files that were
already committed: the ignore rules only apply to untracked files. To make the
repository match the new rules, take everything out of the index and add it
back:

```bash
git rm -r --cached .
git add .
git commit -am "Remove ignored files"
```

`git rm --cached` removes paths "only from the index", and "working tree files,
whether modified or not, will be left alone"; `-r` lets it recurse into
directories.[^rm] `git add .` then stages everything again, and this time the
ignored files are skipped. The commit records them as deleted from the
repository while they stay on disk:

```txt
$ git show --stat --format=%s HEAD
Remove ignored files

 .gitignore | 1 +
 build/out  | 1 -
 2 files changed, 1 insertion(+), 1 deletion(-)
```

Or all at once:

```bash
git rm -r --cached . && git add . && git commit -am "Remove ignored files"
```

Two things to know. Anyone who pulls this commit has those files *deleted*
from their working tree, because for them the commit removes tracked files.
And the files are still in the history, so this is no way to get rid of a
leaked secret: rotate the secret instead.

## Renaming a branch

Locally, `git branch -m` moves a branch "together with its config and
reflog":[^branch]

```bash
git branch -m new-name             # rename the branch you are on
git branch -m old-name new-name    # rename any other branch
```

A remote has no rename operation, so the remote branch is replaced: push the
new name and delete the old one in a single command, then point the local
branch's upstream at the new name.

```bash
git push origin :old-name new-name
git push origin -u new-name
```

The first command pushes two refspecs. `:old-name` has an empty source, and "if
`<src>` is empty, it deletes the `<dst>` ref from the remote repository";
`new-name` pushes the local branch under its own name.[^push] It is the same as
`git push origin --delete old-name` followed by `git push origin new-name`.
`-u` then sets the upstream, so `git pull` and `git status` track the new
remote branch.

```txt
$ git push origin :feature feature-renamed
 - [deleted]         feature
 * [new branch]      feature-renamed -> feature-renamed
$ git push -u origin feature-renamed
branch 'feature-renamed' set up to track 'origin/feature-renamed'.
```

An open pull request on the old branch is usually closed by the deletion, and
other clones keep the old name until they rename too. On a hosting service,
renaming through the web interface is often better for long-lived branches.

## Drawing the branch graph

The short version, known as "a dog" for its flags:

```bash
git log --all --decorate --oneline --graph
```

```txt
* 220d5b8 (HEAD -> feature-renamed) Remove ignored files
* ed43413 oops build
* da828f5 (origin/feature-renamed) three
* 6b758ea two
* 42cb1d9 (origin/main, main) one
```

`--all` shows every branch, not only the current one; `--decorate` adds the
branch and tag names; `--graph` draws the lines between commits. Two richer
versions, one line per commit:

```bash
git log --abbrev-commit --all --decorate --graph --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)'
```

and two lines per commit, the date on the first and the message on the second:

```bash
git log --abbrev-commit --all --decorate --graph --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'
```

The placeholders come from Git's pretty formats: `%h` is the abbreviated hash,
`%ar` the author date relative to now, `%aD` the same date in RFC 2822 style,
`%s` the subject, `%an` the author name, `%d` the branch and tag names and `%n`
a newline. `%C(...)` switches colour and `%C(reset)` switches it back.[^pretty]
Both are long enough to deserve an alias:

```bash
git config --global alias.graph "log --all --decorate --oneline --graph"
```

## Undoing pushed commits

To make a remote branch forget its last commits, move it back to the last good
commit, then do the same locally:

```bash
git push -f origin <last_known_good_commit_hash>:<branch_name>
git reset --hard <last_known_good_commit_hash>
```

The push uses a refspec whose source is a commit rather than a branch, so the
remote branch is set to exactly that commit. Without `-f`, Git would refuse,
because the new value is not a descendant of the old one. `git reset --hard`
then moves the local branch and overwrites the working tree to match, and
uncommitted changes are lost.[^reset]

```txt
$ git push -f origin HEAD~2:feature-renamed
 + 220d5b8...da828f5 HEAD~2 -> feature-renamed (forced update)
$ git reset --hard HEAD~2
HEAD is now at da828f5 three
```

{{< callout type="warning" >}}
A force push can make the remote lose commits. On a branch only you use, that
is the point. On a shared branch, prefer one of these:

- **`--force-with-lease`** instead of `-f`. It only overwrites the remote
  branch if it still points where your remote-tracking branch says it does, so
  a push someone made since your last fetch is not silently thrown away.
- **`git revert <commit>`**, which does not rewrite anything. It records new
  commits that undo the bad ones, and it is the only option on a protected
  branch that refuses force pushes.
{{< /callout >}}

The `git push` manual is blunt about it: `--force` "can cause the remote
repository to lose commits; use it with care", while `--force-with-lease`
proceeds only "if the current value of the remote ref is the expected
value".[^push] `git revert` exists "to record some new commits to reverse the
effect of some earlier commits".[^revert]

## References

[^config]: Git Project. (n.d.). *git-config*. Git reference manual. Entries for `--global`, `alias.*` and `init.defaultBranch`. <https://git-scm.com/docs/git-config>

[^rel228]: Git Project. (2020, July 27). *Git v2.28 release notes*. <https://github.com/git/git/blob/master/Documentation/RelNotes/2.28.0.adoc>

[^reset]: Git Project. (n.d.). *git-reset*. Git reference manual. Modes `--soft`, `--mixed` and `--hard`. <https://git-scm.com/docs/git-reset>

[^commit]: Git Project. (n.d.). *git-commit*. Git reference manual. Options `--amend`, `--no-edit` and `--reset-author`. <https://git-scm.com/docs/git-commit>

[^rebase]: Git Project. (n.d.). *git-rebase*. Git reference manual. Option `--exec`. <https://git-scm.com/docs/git-rebase>

[^rm]: Git Project. (n.d.). *git-rm*. Git reference manual. Options `--cached` and `-r`. <https://git-scm.com/docs/git-rm>

[^branch]: Git Project. (n.d.). *git-branch*. Git reference manual. Options `-m` and `-M`. <https://git-scm.com/docs/git-branch>

[^push]: Git Project. (n.d.). *git-push*. Git reference manual. Refspecs, `--delete`, `--force` and `--force-with-lease`. <https://git-scm.com/docs/git-push>

[^pretty]: Git Project. (n.d.). *Pretty formats*. Git reference manual. <https://git-scm.com/docs/pretty-formats>

[^revert]: Git Project. (n.d.). *git-revert*. Git reference manual. <https://git-scm.com/docs/git-revert>
