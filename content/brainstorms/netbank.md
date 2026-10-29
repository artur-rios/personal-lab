---
title: "Netbank: A Banking System to Learn From"
description: "An idea for a complete banking system built for learning, with a .NET back end, a Flutter front end for Android, Linux, Windows and the browser, Heimdall for authentication and authorization, and PostgreSQL, with a suggested design around a double-entry ledger, a simulated central bank and a clock that can be moved forward."
date: 2026-10-22T12:30:00Z
categories: ["Brainstorms"]
tags: ["Netbank", "Banking", "Ledger", ".NET", "Flutter", "PostgreSQL", "Heimdall", "Technology Stack"]
---

A complete banking system, built for learning purposes.

## Technology

- .NET on the back end
- Flutter on the front end
- Heimdall for authentication and authorization
- PostgreSQL database

## Platforms

- Android
- Linux
- Windows
- Web

## What a complete bank covers

"Complete" is the part of the idea that needs a boundary. A real bank is
hundreds of systems, so this is a suggestion of what Netbank should cover, chosen
because each part teaches something a CRUD app does not. It moves no real money
and connects to no real bank: every institution outside Netbank is simulated.

| Area | What it does | What it teaches |
| --- | --- | --- |
| Onboarding | Sign-up, personal details, document checks, approval by the back office | Workflows with states, and data that must be kept and later erased |
| Accounts | Checking and savings accounts, each with a balance and a statement | The ledger: where money is, and how it can never appear or vanish |
| Transfers | Between Netbank accounts, at once | Concurrency, idempotency and limits |
| Pix | Instant payments by key or QR code to other, simulated banks | Talking to an outside system, with settlement that can fail |
| Boletos | Issuing and paying bank slips | Payments that are created now and settled later |
| Cards | Debit and credit cards, purchases, a monthly bill | Authorisation and capture, credit limits, billing cycles |
| Loans | Personal loans with SAC or Price amortisation | Interest, schedules, late fees and early repayment |
| Savings | Daily interest on savings balances | Jobs that run every day, and rounding |
| Back office | Staff who approve customers, look up accounts and reverse transactions | Staff permissions, auditing, and corrections without deleting history |

The Brazilian products, Pix and boletos, follow from where the author banks; an
international bank would have IBAN transfers and SEPA instead. The ledger, the
concurrency rules and the simulated outside world are the same either way.

## Technology stack

The four choices that came with the idea, .NET, Flutter, Heimdall and
PostgreSQL, settle the outline. The back end is an ASP.NET Core API shaped like
Heimdall and Fortuna, as described in
[How I Develop APIs]({{< ref "/dotnet/how-i-develop-apis" >}}), and it runs next
to them on the self-hosted server, as
[How I Host My Projects]({{< ref "/infrastructure/infrastructure-overview" >}})
describes. The front end is one Flutter code base, which builds all four
platforms; how Flutter does that is in
[What Is Flutter?]({{< ref "/front-end/flutter" >}}).

What is left to decide is the inside: how money is stored, how two requests
that spend the same balance are kept apart, how the outside banks are faked,
and how time passes in a bank where interest accrues daily and bills come due
monthly.

### The suggestion at a glance

| Concern | Choice | Why |
| --- | --- | --- |
| API | ASP.NET Core on .NET 10 | Layers, CQRS behind a mediator and results instead of exceptions, the same shape as Heimdall and Fortuna. |
| Data access | EF Core with Npgsql, and raw SQL for the ledger's hot paths | EF Core for the many ordinary tables; a few hand-written statements where a lock or a conditional update matters; see [EF Core or Dapper?]({{< ref "/dotnet/ef-core-and-dapper" >}}). |
| Database | PostgreSQL | Transactions, row locks, `numeric` for money and constraints that check the ledger. |
| Accounts | Heimdall | Customers and staff sign in there, in two scopes; see below. |
| Outside banks | A second ASP.NET Core service, the simulated central bank | Pix, boleto clearing and settlement happen across a real network boundary. |
| Messaging | An outbox table in PostgreSQL | Events are written in the same transaction as the change that caused them, and sent after it commits. |
| Scheduled jobs | Quartz.NET, with its PostgreSQL job store | Interest, bills, loan instalments and statements run on a schedule that survives restarts. |
| Time | .NET's `TimeProvider` | Every rule reads the time from one clock, which a learning environment can move forward. |
| Front end | Flutter, with MVVM as in its architecture guide | One code base for Android, Linux, Windows and the web. |
| Front-end packages | go_router, freezed, json_serializable, qr_flutter, mobile_scanner, fl_chart | Navigation with URLs, immutable models, Pix QR codes to show and to scan, and spending charts. |
| Token storage | flutter_secure_storage on Android, Linux and Windows; a cookie on the web | The operating system's key store where there is one, and no token in the browser's JavaScript; see below. |
| Testing | xUnit with Testcontainers, FsCheck, flutter_test and integration_test | Functional tests against a real PostgreSQL, property tests that the ledger always balances, and app tests on every platform. |

### Money is a ledger, not a balance column

The most important design choice in a bank is that a balance is never edited.
Netbank keeps a **double-entry ledger**, as accountants have for centuries:

- **Every movement of money is a journal entry** with two or more postings, each
  posting adding to or taking from one account. The postings of an entry always
  sum to zero, so money only moves from somewhere to somewhere.
- **Entries are never changed or deleted.** A mistake is corrected with a new
  entry that reverses it, so the history always says what happened and when.
- **A balance is the sum of an account's postings.** The account row keeps the
  current balance too, for speed, but it is updated in the same transaction as
  the postings, and a check can always recompute it.
- **The bank has accounts of its own.** A customer's deposit is not money from
  nowhere: it moves from the bank's cash account to the customer's. Interest
  paid comes from an expense account, fees go to an income account, and money
  sent by Pix waits in a settlement account until the central bank confirms it.

```txt
Ana sends R$ 50.00 by Pix to another bank

Entry 1  (when Ana sends)
  Ana's checking account      −50.00
  Pix settlement (outgoing)   +50.00
                               ─────
                                0.00

Entry 2  (when the central bank confirms)
  Pix settlement (outgoing)   −50.00
  Reserve at central bank     +50.00
                               ─────
                                0.00
```

PostgreSQL can enforce the rule itself: a constraint trigger, deferred to the
end of the transaction, refuses to commit an entry whose postings do not sum to
zero. A property test then throws thousands of random transfers at the ledger
and checks that the sum of every account in the bank is still zero.

**Amounts are exact.** PostgreSQL stores them as `numeric` and .NET as
`decimal`, never as floating point, so R$ 0.10 plus R$ 0.20 is exactly R$ 0.30.
The API sends amounts as whole cents, such as `5000` for R$ 50.00, because a
JSON number read by Dart becomes a `double`, which cannot hold every amount
exactly.

### Two requests, one balance

If Ana has R$ 100 and two transfers of R$ 80 arrive at the same moment, both
can read R$ 100 before either writes, and both pass the balance check. That is
the classic way a bank loses money, and Netbank is a good place to see it happen
and fix it:

- **The debit is a conditional update.** `UPDATE accounts SET balance = balance - 80
  WHERE id = … AND balance >= 80` checks and writes in one statement, and the
  number of rows it changed says whether the money was there. This is the
  pattern described in
  [Writes that race]({{< ref "/dotnet/how-i-develop-apis#writes-that-race" >}}).
- **Locks are taken in a fixed order.** A transfer between two Netbank accounts
  locks both rows, always the lower ID first, so two opposite transfers cannot
  wait on each other forever.
- **Every request that moves money carries an idempotency key.** A phone that
  loses its connection after sending a transfer will send it again; the server
  stores each key with its result, and answers a repeated key with the first
  result instead of moving the money twice.
- **Limits are budgets.** A daily Pix limit is charged before the transfer, in
  the same transaction, so parallel transfers cannot all fit under it.

### The outside world, simulated

Pix and boletos only teach something if there is another side that can be slow,
refuse, or fail. So Netbank comes with a second service, the **simulated central
bank**, that plays the part of Brazil's Central Bank and the other banks:

- **It keeps a reserve account for each bank**, and settles Pix payments
  between them.
- **It holds the directory of Pix keys**, as the real one does, so paying a key
  first asks which bank and account it belongs to.
- **It clears boletos**, telling the issuing bank when one is paid.
- **It can misbehave on purpose.** A setting makes it answer slowly, time out or
  refuse a share of payments, so the retries, timeouts and reversals in Netbank
  can be watched working.

Netbank and the central bank talk over HTTP, and each change that the other
side must hear about is first written to an **outbox** table, in the same
transaction as the change itself, then sent by a background worker. A payment
is never lost between "saved" and "sent", and the receiving side ignores a
message it has already processed.

Two instances of Netbank, each with its own database, can be connected to the
same central bank as two different banks, so a Pix payment between them crosses
the whole system.

### A clock that can be moved forward

Much of a bank happens with time: interest accrues every night, a card bill
closes once a month, a loan instalment is late after its due date. Waiting a
month to see a bill is not a way to learn, so every rule in Netbank reads the
time from .NET's `TimeProvider`, never from the system clock directly.

In production it is the real clock. In a learning environment, the back office
can move it forward by a day, a week or a month, and the scheduled jobs that
would have run in between run in order: interest is credited, bills close, and
missed instalments become late. Tests use the same mechanism, with a fake time
provider, to check a whole loan from the first instalment to the last in
milliseconds.

### Customers and staff in Heimdall

Netbank owns no passwords. Everyone signs in through
[Heimdall](https://docs.artur-rios.tech/heimdall-api/), the identity API that
Fortuna already uses, and Netbank follows the same pattern.

In Heimdall, a scope's permissions are added to the token of every identity in
that scope, so they cannot tell a customer from a member of staff. Netbank
therefore uses **two scopes**:

| Scope | Who | Sign-up | Signs in |
| --- | --- | --- | --- |
| Netbank | Customers | Self-registration, and Google Sign-In | The app, on every platform |
| Netbank Staff | Back-office staff | Only created by the scope's owner, never by self-registration | The back office, with two-factor authentication |

The scope named in a token tells Netbank which kind of person is calling. What
each person may then do is Netbank's own authorization:

- **A customer may only touch their own accounts.** Each request checks that
  the account belongs to the caller, so a customer who changes an account
  number in a URL gets nothing.
- **Staff have roles in Netbank**, such as teller, manager and compliance, and
  the actions that matter most need two people: a reversal above a set amount
  is proposed by one and approved by another.
- **The simulated central bank is a Heimdall application**, a non-human identity
  with its own credential, which it exchanges for a short-lived application
  token when it calls Netbank. Netbank checks that token live with Heimdall, so
  revoking the credential cuts the central bank off at once.

The app signs in through Netbank's own `/api/auth/` endpoints, which forward to
Heimdall, as Fortuna's do. Netbank validates each token locally, by its
signature, issuer, audience and expiry, and should be ready for Heimdall's
planned move from a shared secret to public keys, as Fortuna is.

### One app on four platforms

Flutter builds Android, Linux, Windows and web apps from the same code, so the
differences are only where a platform truly differs:

| Concern | Android | Linux and Windows | Web |
| --- | --- | --- | --- |
| Where the token is kept | Android Keystore, through flutter_secure_storage | libsecret on Linux and the Windows Credential Manager, through the same package | An `HttpOnly` cookie set by the server; no token in JavaScript |
| Pix by QR code | Scan with the camera | Paste the Pix "copy and paste" code | Scan with the camera, or paste |
| Unlock | Fingerprint or face, through local_auth | Windows Hello on Windows; password on Linux | Password |
| Distribution | APK on GitHub releases | AppImage on Linux, MSIX on Windows | Served by nginx, as in [Web Apps]({{< ref "/infrastructure/infrastructure-web-apps" >}}) |

The web column is the one that differs most. In a browser, anything a script
can read, a script injected into the page can steal, and a bank's token is the
last thing to lose that way. So on the web the server keeps the token, and the
browser holds only an `HttpOnly`, `Secure`, `SameSite=Strict` session cookie
that scripts cannot read. This is the backend-for-frontend pattern, and since
the web app calls its own origin, the browser sends the cookie without any
CORS.

## Open questions

- Is Netbank Brazilian, with Pix, boletos and CPF numbers, or generic, with
  IBAN transfers?
- Is the back office part of the same Flutter app, shown only to staff, or a
  separate web app?
- Does onboarding check documents, with a simulated identity bureau, or does
  every sign-up become a customer at once?
- Is the clock that moves forward available only in a learning environment, or
  per customer, so each learner can move their own time without affecting
  others?
- Does Netbank handle one currency, or several, with exchange between them?
- Should the outbox be read by a message broker, such as RabbitMQ, to learn
  one, or stay as HTTP between the two services?
