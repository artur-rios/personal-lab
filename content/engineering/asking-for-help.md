---
title: "Asking for Help in Chat: No Hello, Don't Ask to Ask, and the XY Problem"
description: "Three short websites name three habits that slow down every request for help in chat: a greeting sent on its own, a question about whether anyone can answer a question, and a question about a guessed solution instead of the real problem. What each one says, why it matters more in chat than in person, and how to use them without being rude, from both sides of the conversation."
date: 2026-10-21T23:00:00Z
categories: ["Engineering"]
tags: ["Communication", "Asking Questions", "Chat", "Remote Work", "No Hello", "XY Problem", "Teamwork"]
---

Most of the time I spend helping someone, or being helped, goes to the
question rather than the answer. The answer is often a sentence. Getting to
the point where that sentence can be written takes a greeting, a wait, a
follow-up, a "what are you actually trying to do?", and another wait. In
chat, each of those round trips can cost minutes or hours, because the other
person is not watching the window.

Three small websites each name one of these round trips and explain how to
skip it:

- [nohello.net](https://nohello.net/en/): don't send a greeting on its own
  and wait for a reply before asking.
- [dontasktoask.com](https://dontasktoask.com/): don't ask whether anyone
  can help; ask the question.
- [xyproblem.info](https://xyproblem.info/): ask about the problem you have,
  not about the solution you guessed.

None of them is new. All three are refinements of advice in Eric S. Raymond
and Rick Moen's *How To Ask Questions The Smart Way*, first published in
2001.[^smart] What the websites add is a name and a link: something short
enough to put in a profile, a channel topic or a team handbook, so that the
advice is there before the question is asked. This page explains what each
one says, why it works, and how I use them.

## Why chat makes it worse

In person or on a call, a greeting costs nothing. The other person is
already listening, the reply comes back in a second, and the question
follows straight away. Chat looks like a conversation, but it does not work
like one:

- **It is asynchronous.** The person you are writing to is in a meeting, in
  another time zone, or focused on something else. They see your message
  when they next look, not when you send it.
- **Typing is slow.** Each message takes longer to write than to say, so a
  conversation that would take a minute aloud takes several in text.[^nohello]
- **Every message interrupts.** A notification pulls attention away from
  whatever the reader was doing, and a message with nothing to act on
  interrupts for no gain.

So the cost of a chat conversation is counted in **round trips**: each time
one person has to wait for the other to reply before they can go on. All
three habits below add round trips that carry no information.

## No hello

**The habit.** Sending "hi", "hello" or "got a minute?" as a message on its
own, and waiting for a reply before writing the question.

**What nohello.net says.** It compares this to phoning someone, saying hello
and putting them on hold.[^nohello] The person who receives the greeting
cannot do anything with it. They reply, then wait while the question is
typed, and only then can they start thinking about the answer. If they go
offline in the meantime, they come back to a "hello" with no context and
nothing to answer, and the asker has to wait for them to return. If the whole
question had been in the first message, they could have answered it
whenever they next looked.

The site is clear that the habit comes from good intentions: people do it to
be polite, as they would face to face. The fix keeps the politeness and
drops the wait. Greet, then ask, in the same message:

> **Instead of:**
> Hi Ana
> *(waits ten minutes for "hi?")*
> Do you know why the staging deploy is failing?
>
> **Send:**
> Hi Ana! Do you know why the staging deploy is failing since this morning?
> The build passes, but the health check times out after the release step.

The second version gets an answer in one round trip, and Ana can answer it
from her phone between meetings.

## Don't ask to ask

**The habit.** Posting "Any Java experts here?" or "Can someone help me with
Docker?" in a channel, and waiting for a volunteer before saying what the
question is.

**What dontasktoask.com says.** That question is really asking for much
more than it seems to: it asks someone to commit to helping before they know
what with.[^dontask] Nobody can tell whether they are able to answer a
question they have not seen, so the people best placed to help often stay
quiet. It also narrows the audience to self-declared "experts", when plenty
of people who have never called themselves Java experts could answer a
specific Java question. Meanwhile, people who only glance at the channel
now and then have nothing to respond to, while a concrete question might
have caught their interest.

The fix is to ask the question itself, with enough detail to answer it:

> **Instead of:**
> Anyone here know Docker?
>
> **Send:**
> My container exits straight away with code 137 when I run
> `docker compose up`. The same image runs fine on my colleague's machine.
> Is that the memory limit, and where do I raise it on Docker Desktop?

Asking the question directly is not pushy. Someone who knows the answer can
reply, and someone who does not can scroll past without being asked to say
so. That is easier on everyone than a call for volunteers.

## The XY problem

**The habit.** You want to achieve X. You decide that Y is the way to do it,
get stuck on Y, and ask for help with Y without mentioning X.

**What xyproblem.info says.** The helpers try to solve Y, find it a strange
thing to want, and only after a lot of back-and-forth learn about X, often
to discover that Y was never a good route to it.[^xy] Its first example is
someone asking how to get the last three characters of a file name. After
some questions, it turns out they want the file extension, and taking the
last three characters is the wrong way to get it: extensions are not always
three characters long, and some files have none.

The name grew up in IRC help channels. Greg's Wiki, which is closely tied
to the #bash channel and quotes its logs, describes the same pattern and
adds why it happens: Y is often the longest or most complicated route to
X, and the asker has grown attached to it.[^wooledge] Raymond and Moen give
the same advice under the heading "Describe the goal, not the
step".[^smart]

**What to do as the asker.** Say what you are trying to achieve, then what
you tried:

> **Instead of:**
> How do I make the API return dates as strings in this format?
>
> **Send:**
> The mobile app shows the wrong day for orders placed late in the evening.
> I think the API's dates are the problem, so I tried returning them as
> formatted strings, but I can't get the format right. Is that the right fix?

The second version lets a reader spot the real cause, perhaps a time zone
being dropped, instead of helping with a string format that would not have
fixed it. If you have ruled something out, say that too, and say why: it
tells helpers about constraints they would otherwise have to guess.

**What to do as the helper.** When a question seems oddly specific or
oddly hard, ask "what are you trying to do?" before answering it. It is not
a refusal to help. It is often the quickest way to an answer.

## Using the links without being rude

All three sites exist to be linked, and that is where they can go wrong.
Answering someone's "hi" with nothing but a link to nohello.net reads as a
rebuke, however reasonable the site's content. The nohello.net page itself
says it is only half serious, and asks readers not to be upset with whoever
sent it to them.[^nohello] The aim is to make the next conversation
shorter, not to win this one.

What works for me:

- **Put the link where it is read before the question is asked.** A line in
  a chat profile or status ("No need to say hello first, just ask:
  nohello.net"), the topic of a help channel, or the contributing guide of a
  project. Then nobody is being corrected; they are reading the house rules.
- **Answer first, link second.** When someone does send a bare "hi", reply
  "Hi! What's up?" and help them. If the habit keeps coming back, mention
  the link afterwards, privately, as a tip.
- **Apply them to myself first.** Most of my own slow conversations are ones
  where I sent the greeting, asked to ask, or asked about Y. The links are
  more convincing when the people around me have seen me follow them.

## A message that avoids all three

Put together, a request for help that skips every round trip above looks
like this:

1. **A greeting**, if you like, in the same message.
2. **The goal:** what you are trying to achieve (X).
3. **What you tried** and what happened instead (Y, and its symptoms).
4. **What you have ruled out**, and why.
5. **The question**, stated directly.

That message can be answered by anyone who reads it, whenever they read it,
in one reply. That is the whole point of all three sites.

## References

[^smart]: Raymond, E. S., & Moen, R. (2014). *How to ask questions the smart way* (Revision 3.10). <http://www.catb.org/~esr/faqs/smart-questions.html>

[^nohello]: No Hello. (n.d.). *no hello*. <https://nohello.net/en/>

[^dontask]: Don't ask to ask, just ask. (n.d.). *Don't ask to ask, just ask*. <https://dontasktoask.com/>

[^xy]: The XY Problem. (n.d.). *The XY problem*. <https://xyproblem.info/>

[^wooledge]: Greg's Wiki. (2020, May 3). XyProblem. <https://mywiki.wooledge.org/XyProblem>
