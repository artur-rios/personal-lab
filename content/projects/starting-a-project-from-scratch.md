---
title: "How I Start a Project From Scratch"
description: "The ten steps I follow to take a project from a first idea to a working system: a brainstorm, informal documents, formal specifications reviewed until they are right, a GitHub backlog of use cases, and an implementation that finishes one use case, tests included, before starting the next."
date: 2026-10-21T17:30:00Z
categories: ["Projects"]
tags: ["Process", "Requirements", "Use Cases", "GitHub", "Testing", "Project Management"]
---

Every project on this site starts the same way. Not with code, but with a
document, because the cheapest place to find a mistake is in a sentence, before
anything has been built on top of it. This is the roadmap I follow, from the
first idea to a system that is ready to use:

1. Create a brainstorm document for the project, with ideas about its nature,
   its implementation and the technologies to use.
2. Refine the brainstorm into four initial documents: Project Overview,
   Technology Stack, Workflow and Business Rules.
3. Formalise them into a Vision Document, a System Requirements Document and a
   Use Case Specification Document.
4. Review the documents, improve them, and review them again until they match
   what the project is meant to be.
5. Create GitHub issues for the initial scaffold and infrastructure.
6. Create a GitHub issue for each use case, linked to a GitHub Project and to an
   MVP milestone.
7. Implement the initial scaffold and infrastructure.
8. Implement one use case after another, including unit and functional tests.
9. For each use case, run the tests and fix until all of them pass, and only
   then move on to the next one.
10. Run a final test of the full functionality and fix any issue found,
    repeating until the system is ready.

The ten steps fall into four phases:

| Phase | Steps | Question it answers | What it leaves behind |
| --- | --- | --- | --- |
| Think | 1 | What could this be? | A brainstorm |
| Specify | 2–4 | What exactly will it do? | Four informal and three formal documents, reviewed |
| Plan | 5–6 | In what order will it be built? | A GitHub backlog, a board and a milestone |
| Build | 7–10 | Does it work? | A tested system, one use case at a time |

## Think

### 1. Brainstorm

A brainstorm is the place to be wrong cheaply. It holds what the project is,
what it should do, who it is for, and which technologies might build it, all
written down before anything is decided. It is allowed to be rough, to
contradict itself and to end in questions.

What makes a brainstorm useful later is that it ends with the questions it
could not answer. Each answer becomes a decision, and the decisions are what
the next phase is built from. The [Brainstorms]({{< ref "/brainstorms" >}})
section of this site is where mine live; [Mosaic]({{< ref "/brainstorms/mosaic" >}}),
[Thoth]({{< ref "/brainstorms/thoth" >}}),
[Anvil OS]({{< ref "/brainstorms/anvil-os" >}}) and
[Craft]({{< ref "/brainstorms/craft" >}}) all went from a few lines of ideas to
a technology stack, open questions, and finally a list of decisions.

## Specify

### 2. Refine the brainstorm into four documents

The brainstorm is reorganised into four short, informal documents, each with
one job:

| Document | What it answers |
| --- | --- |
| **Project Overview** | What the project is, the problem it solves and for whom, what it does, what it explicitly does not do, and how success will be measured |
| **Technology Stack** | The platform and language, the kind of application, data storage and access, authentication, testing, external services and deployment |
| **Workflow** | How a piece of work goes from an issue to merged code: loading the specification, designing, branching, implementing, testing, opening the pull request, and what "done" means |
| **Business Rules** | The domain's entities and their relationships, the numbered rules with their reasons, validation constraints, permissions, lifecycles, and what must never happen |

Writing "what it does not do" in the overview matters as much as what it does.
Non-goals are what stop a project from growing in every direction at once. And
writing the workflow down before any code exists means every use case later is
built the same way, whoever builds it.

### 3. Formalise them

The informal documents become three formal ones, each built from the one
before it:

- **Vision Document.** The problem statement, the product's position, the
  stakeholders, a high-level architecture, the core features, an overview of
  the domain model, the roles, the constraints and the success criteria.
- **System Requirements Document.** The functional requirements grouped by
  area, the data model with its fields, the interface the system exposes, the
  non-functional requirements such as performance and security, an
  authorisation matrix, and a traceability table.
- **Use Case Specification Document.** The actors, and for every use case its
  preconditions, its main flow, its alternative flows, and the requirements it
  covers.

Each kind of statement gets an identifier, so every line can be traced from
the reason it exists to the code that implements it:

| Identifier | Meaning | Defined in |
| --- | --- | --- |
| `BR-xx` | Business rule | Business Rules |
| `F-xx` | Feature | Vision Document |
| `FR-<AREA>-xx` | Functional requirement | System Requirements Document |
| `NFR-xx` | Non-functional requirement | System Requirements Document |
| `UC-xx` | Use case | Use Case Specification Document |
| `AF-xx` | Alternative flow of a use case | Use Case Specification Document |

A feature in the vision is realised by functional requirements, which are
covered by use cases, which become issues. When the chain is unbroken, nothing
is built without a reason, and no reason is left without something built for
it.

### 4. Review until they match

The documents are reviewed, improved and reviewed again, as many times as it
takes. A review asks:

- **Does every feature trace through?** Each `F-xx` should be realised by at
  least one requirement, and each requirement covered by at least one use case.
- **Do the documents agree?** A rule in Business Rules, a field in the data
  model and a step in a use case must not contradict each other.
- **Is every case decided?** The empty list, the duplicate name, the user
  without permission: each needs an alternative flow, not a guess made later
  in code.
- **Does it still match the intention?** Formal documents can drift from what
  the project was meant to be. Reading the brainstorm again catches that.

This is the step most tempting to skip, and the cheapest one to do. A missing
alternative flow found here costs a paragraph; found after the code is
written, it costs a redesign.

## Plan

### 5. Issues for the scaffold and infrastructure

Before any use case can be built, the project needs somewhere to live: the
repository layout, the dependencies, the configuration, the database and its
first migration, the test projects, and continuous integration. These get
GitHub issues of their own, created first, because every use case depends on
them. Their definition of done is the infrastructure requirements from the
documents, not a feature.

### 6. One issue per use case

Each `UC-xx` becomes one GitHub issue, which links back to its section of the
Use Case Specification Document. Every issue is added to:

- **A GitHub Project**, a board where each issue moves from to do, to in
  progress, to done, so the state of the whole project is visible at a glance.
- **The MVP milestone**, which groups what the first usable version must
  contain and shows how much of it is finished.

One use case is the right size for an issue: small enough to finish in one
pull request, and large enough to deliver something a user can do.

## Build

### 7. The scaffold first

The scaffold issues are implemented before any use case. When they are done,
the project builds, an empty test suite runs, and continuous integration is
green, all with no features yet. From then on, every failure in CI is caused by
the use case being worked on, never by the foundation underneath.

### 8. One use case at a time, with its tests

Use cases are implemented one after another, never side by side. Each follows
the Workflow document: load the use case and the requirements it covers,
design it, open a branch, implement the main flow and every alternative flow,
and write the tests:

- **Unit tests** check each piece in isolation, such as a validation rule or a
  calculation; see [What Is a Unit Test?]({{< ref "/fundamentals/unit-tests" >}}).
- **Functional tests** check the use case from the outside, through the
  system's own interface, such as an API endpoint or a command, the way an
  actor in the specification would use it.

The pull request links its issue with a closing keyword, such as
`Closes #12`, so merging it closes the issue and moves it to done on the board.

### 9. Green before moving on

A use case is finished only when all the tests pass, its own and every test
before it. Until then, the work is to run the tests, fix, and run them again.
Only then does the next use case start.

The rule feels slow and is the opposite. A failure found while a use case is
fresh is fixed in minutes. Failures left behind pile up, and a week later
nobody can tell which change caused which. Running every earlier test, not only
the new ones, is also what catches a new use case breaking an old one.

### 10. The final full test

When the last use case of the milestone is merged, the system is tested as a
whole: every use case, end to end, in the order a real user would go through
them, on a deployment like the real one. Anything found becomes an issue, is
fixed the same way, and the full test runs again, until a run finds nothing.
Then the system is ready, and the milestone is closed.

## Why it works

Each step turns uncertainty into something smaller and more concrete: an idea
into decisions, decisions into requirements, requirements into issues, and
issues into tested code. Most of the thinking happens in steps 1 to 4, where
changing your mind costs nothing but editing a document. By the time code is
written, the questions left are about how to build something, not what to
build, and every line of code can be traced back to the reason it exists.
