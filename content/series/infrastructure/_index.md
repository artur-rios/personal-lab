---
title: "Infrastructure"
description: "How I host and ship every kind of project: two self-hosted servers run by yggdrasil, my own deploy manager, with Forgejo for the code, Jenkins for checks, releases and deploys, and every API, web app and site behind Cloudflare."
---

How I host and ship every kind of project. The code lives on my own Forgejo,
Jenkins checks, releases and deploys it, and everything that runs, from a .NET
API or a Flutter web app to a landing page or a documentation site, runs in
containers on my own servers, deployed by yggdrasil, my own deploy manager.
Only the packages leave: they are published on nuget.org. The series starts
with the big picture, follows the platform from the bare servers to a deploy,
and ends with what each kind of project looks like to it.
