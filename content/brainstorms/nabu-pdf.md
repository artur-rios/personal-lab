---
title: "Nabu PDF: A PDF Toolbox That Stays on Your Device"
description: "An idea for a free, open-source PDF app for Windows, Linux and Android that views, merges, splits, rotates and reorders pages and signs documents with a drawn, uploaded or typed signature, entirely offline and with no account, with a suggested technology stack around Flutter and PDFium."
date: 2026-11-22T12:00:00Z
categories: ["Brainstorms"]
tags: ["Nabu PDF", "PDF", "Signatures", "Offline", "Flutter", "PDFium", "Technology Stack"]
---

Everyday PDF work, without uploading your documents anywhere.

## Features

- PDF viewer
- Merge, split, rotate and sort the pages of a PDF
- Add a signature to a PDF. The user can draw it, upload an image of it, or
  type their name and choose one of the fonts the app offers

## Platforms

- Windows
- Linux
- Android

## Requirements

- The same front end on every platform
- Works offline
- Open source and free to use
- No registration and no authentication

## Technology stack

Most free PDF tools on the web work by uploading the document to a server,
which is the reason Nabu exists: contracts, bank statements and IDs are exactly
the files people sign and split. Two requirements shape the stack most. **Works
offline** means every operation runs on the device, so Nabu needs a real PDF
engine compiled into the app, not a service. **The same front end on every
platform** means one UI toolkit that runs natively on Windows, Linux and
Android.

The design is one Flutter app with three layers. The **UI** draws pages,
thumbnails and the signature tools. A **document service** in Dart turns what
the user does into edits, such as "move page 4 before page 2" or "place this
signature at this spot on page 3". The **PDF engine**, PDFium, does the actual
reading, rendering and writing, called from Dart through `dart:ffi`. PDFium is
not thread-safe, so a single background isolate owns every call into it and
the UI never waits on a large file.

```txt
   ┌──────────────────────────────────────┐
   │   Flutter UI: viewer, page grid,     │
   │   merge and split, signature pad     │
   └──────────────────┬───────────────────┘
              edits ▼ │ ▲ pages, thumbnails
   ┌──────────────────┴───────────────────┐
   │   Document service (Dart)            │
   │   edit list, undo, save              │
   └──────────────────┬───────────────────┘
                      │  one worker isolate
   ┌──────────────────┴───────────────────┐
   │   PDFium through dart:ffi            │
   │   render, import, rotate, move, save │
   └──────────────────────────────────────┘
```

### The suggestion at a glance

| Concern | Choice | Why |
| --- | --- | --- |
| UI toolkit | Flutter | One Dart code base and one UI for Windows, Linux and Android, drawn by Flutter itself, so it looks the same everywhere; see [What Is Flutter?]({{< ref "/front-end/flutter" >}}) |
| PDF engine | PDFium | The engine inside Chrome: BSD-licensed, fast, and able to both render and edit, so viewing and editing share one library. |
| Viewer | pdfrx | An MIT-licensed Flutter viewer built on PDFium, with zoom, text selection, search and links, for all three platforms. |
| Editing | PDFium's own editing API through `dart:ffi` | Importing, rotating, moving and deleting pages, inserting images and saving are all part of PDFium, so no second PDF library is needed. |
| Background work | One worker isolate | Keeps every PDFium call on one thread and keeps the UI smooth on large files. |
| Signature pad | `CustomPainter` with stroke smoothing | Captures the pen, finger or mouse and draws smooth, pressure-like strokes. |
| Signature fonts | Handwriting fonts under the SIL Open Font License | Free to bundle and to use inside a signed document. |
| Saved signatures | Files in the app's data folder | Stays on the device, with no account and no database to set up. |
| File access | `file_selector` on desktop, the Storage Access Framework on Android | Opens and saves where the user chooses, including "Open with" from the file manager. |
| State | Riverpod | Small, testable state for the open document and its undo history. |
| Testing | `flutter test`, golden tests, and `qpdf --check` in CI | Golden images catch rendering changes, and qpdf checks that every file Nabu writes is a valid PDF. |
| Packaging | MSIX and winget for Windows; Flatpak, AppImage and `.deb` for Linux; F-Droid and Google Play for Android | The stores where people look for free, open-source apps on each platform. |

### Why Flutter

Flutter is the most mature toolkit that ships one UI to Windows, Linux and
Android from the same code, with all three as stable targets. It draws its own
widgets instead of wrapping each platform's, so the page grid, the signature
pad and the drag-and-drop work identically everywhere, and only file access
differs per platform.

| Option | Platforms | PDF engine | Trade-off |
| --- | --- | --- | --- |
| **Flutter + PDFium** | Windows, Linux, Android | PDFium | Dart is a smaller ecosystem, and the PDFium editing calls need a thin FFI layer of Nabu's own. |
| Flutter + MuPDF | Windows, Linux, Android | MuPDF | The best rendering and editing quality, but MuPDF is AGPL, which binds Nabu's licence to the AGPL unless a commercial licence is bought. |
| Tauri + PDF.js + pdf-lib | Windows, Linux, Android | PDF.js in the web view, pdf-lib for edits | A familiar web stack, but rendering in a web view is slower on large files, pdf-lib has not had a release in years, and Linux web views differ by distribution. |
| Compose Multiplatform | Windows, Linux, Android | PDFBox on desktop, Android's own renderer on Android | Good on Android, but no single PDF library covers both halves, so editing would be written twice. |
| .NET MAUI | Windows, Android | — | Rules itself out: MAUI does not support Linux. |

### Why PDFium

A PDF tool needs an engine that renders correctly and edits without damaging
the file. PDFium does both, has been hardened by years inside Chrome, and its
BSD licence leaves Nabu free to choose its own licence. pdfrx already bundles
it for the viewer, so the editing layer reuses the same binary instead of
adding another one.

Every editing feature maps to a PDFium function that changes the document's
structure, not its pixels, so pages are never rasterised: text stays
selectable, links keep working, and quality never drops.

| Feature | How it works | PDFium |
| --- | --- | --- |
| Merge | Open the files in the order the user chose, and import every page into a new document | `FPDF_ImportPages` |
| Split | By ranges such as `1-3, 5, 8-`, every N pages, or the selected pages; each part is imported into its own new document | `FPDF_ImportPages` |
| Rotate | Turn one page, the selected pages or all of them by 90° steps, by changing each page's `/Rotate` value | `FPDFPage_SetRotation` |
| Sort | Drag thumbnails in a reorderable grid, or delete pages | `FPDF_MovePages`, `FPDFPage_Delete` |
| Sign | Insert the signature image as an image object on the page | `FPDFImageObj_SetBitmap`, `FPDFPage_InsertObject` |
| Save | Write the result to a new file, or incrementally to the same one | `FPDF_SaveAsCopy` |

The document service keeps edits as a list and applies them only on save, so
undo is removing the last edit, and nothing touches the original file until
the user saves.

### Signatures

All three ways of making a signature end in the same thing: a transparent PNG,
stored in the app's data folder and placed on the page as an image. One format
keeps placing, resizing and saving the same code for all three.

- **Drawn.** The pad records each stroke as points and smooths them into
  curves, using an algorithm like perfect-freehand's, which has a Dart port, so
  a mouse signature looks as natural as a finger or pen one. The strokes are
  rendered to a PNG at a high resolution, so it stays sharp when printed.
- **Uploaded.** The user picks a photo or scan of a signature on paper. Nabu
  crops it, and turns the near-white background transparent with an
  adjustable threshold, so the signature sits on the page instead of in a white
  box.
- **Typed.** The user types their name and picks one of the bundled
  handwriting fonts, such as Dancing Script, Great Vibes, Caveat, Sacramento or
  Allura. All of them are under the SIL Open Font License, which allows
  bundling them in the app and using them in documents. The name is rendered to
  a PNG in the chosen font, so the PDF does not need the font embedded.

To place a signature, the user drags it onto the page and resizes it. The UI
works in screen pixels, but a PDF page works in points, 1/72 of an inch, with
its origin at the bottom-left corner, and a page may be rotated or have an
offset crop box. The document service converts between the two, so the
signature lands exactly where the user put it, whatever the page's rotation.

Saved signatures appear in a list, so a user signs a second document in two
taps. Because there is no account, they never leave the device, and deleting
the app deletes them.

{{< callout type="note" title="A signature image is not a digital signature" >}}
What these three features add is an electronic signature: a picture of the
user's signature on the page, which is what most everyday forms and contracts
ask for. A digital signature in the PDF sense is different: it uses a
certificate to prove who signed and that the file has not changed since. Nabu
could add that later, still offline, with a certificate the user already has
in a `.p12` or `.pfx` file. PDFium can verify those signatures but cannot
create them, so that would need another library.
{{< /callout >}}

A file that already carries a digital signature needs care: any change saved
by rewriting the whole file breaks it. When Nabu opens such a file, it says so,
and saves changes incrementally, appending them after the signed part, so the
existing signature stays valid for the content it covered.

### Offline, free and without an account

These three requirements reinforce each other, and the stack can enforce them
rather than only promise them:

- **No network permission on Android.** Nabu's release manifest does not
  request the `INTERNET` permission, so Android itself stops the app from
  connecting to anything. Anyone can check this on the app's store page.
  Flutter adds the permission only to debug builds, for hot reload.
- **No telemetry, no crash reporting service and no update check.** Updates
  come from the store or package manager the app was installed from.
- **No account to make.** Everything the app remembers, such as saved
  signatures, recent files and settings, is a file in the app's data folder.
- **The original is never overwritten by default.** Saving writes a new file
  next to the original, and overwriting is an explicit choice.
- **Password-protected PDFs open locally.** PDFium decrypts the file with the
  password the user types, which never leaves the device.

### Each platform

The UI is the same everywhere, but opening and saving files is not:

- **Windows.** Native open and save dialogs through `file_selector`, a file
  association so Nabu appears under "Open with", and an MSIX package listed on
  winget.
- **Linux.** The GTK file chooser, which goes through the desktop's portal
  inside a Flatpak, and a
  Flatpak on Flathub, whose sandbox can be set with no network access, as well
  as an AppImage and a `.deb`.
- **Android.** The Storage Access Framework for opening and saving, an intent
  filter for PDFs so Nabu appears when a PDF is opened from the file manager,
  an email or a browser download, and touch-friendly sizes for the page grid
  and the signature pad.

F-Droid builds every app from source, and pdfrx downloads prebuilt PDFium
binaries, so publishing there means building PDFium in the F-Droid recipe
too. Google Play is simpler and can come first.

### Building toward the first release

1. **The viewer**, on all three platforms: open a PDF, scroll, zoom, search
   and see thumbnails. This proves pdfrx, the file access on each platform and
   the packaging before any editing exists.
2. **Page tools:** rotate, sort and delete within one file, then merge and
   split. These are the PDFium FFI layer and the edit list with undo.
3. **Signatures:** the drawn signature first, then typed with the bundled
   fonts, then uploaded images with background removal.

## Decisions

- **One Flutter front end on Windows, Linux and Android.** Only file access
  and packaging differ per platform.
- **Everything runs on the device.** No server, no network access, no
  telemetry.
- **Free and open source, with no account.** There is nothing to register for
  and nothing stored anywhere but the device.
- **PDFium is the only PDF engine.** It renders and edits, and its BSD licence
  leaves Nabu free to pick its own.
- **Signatures are images.** Drawn, uploaded and typed signatures all become
  transparent PNGs placed on the page.

## Open questions

- **Which licence?** PDFium and pdfrx allow anything from MIT to GPL. A
  permissive licence lets others reuse the code; the GPL keeps every fork open
  too.
- **Digital signatures with a certificate?** Worth adding after the first
  release if users ask for them, and it needs a library to choose.
- **More tools later?** Compressing, adding page numbers or watermarks, and
  filling forms are natural next features, and PDFium supports most of them.
