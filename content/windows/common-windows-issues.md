---
title: "Common Windows Issues and How I Fix Them"
description: "The Windows problems I keep running into and the fixes I keep looking up: rebuilding the icon cache when Explorer shows blank or outdated icons, and why Cryptomator closes itself every time the NVIDIA driver is updated."
date: 2026-10-21T19:00:00Z
categories: ["Windows"]
tags: ["Windows", "Windows 11", "Explorer", "Icon Cache", "Cryptomator", "NVIDIA", "Troubleshooting", "Reference"]
---

This page is a reference rather than an article: problems I have hit on
Windows more than once, with the fix written down so I do not have to search
for it again. Each entry says what the problem looks like, what is going on
underneath, and the steps that solve it. The file locations below were checked
on Windows 11 Pro on 21 October 2026.

## Blank or outdated icons: rebuilding the icon cache

**What it looks like.** Explorer, the desktop or the taskbar shows a blank
white icon, a generic one, or the old icon of an application that has since
been updated.

**What is going on.** Explorer does not read every icon from its file each
time a folder opens. It keeps the icons it has already drawn in a set of cache
files and reuses them. When an application changes its icon, or a cache file
is damaged, Explorer keeps showing what the cache holds. Deleting the cache
makes Explorer draw every icon again from its source.

The cache lives in two places under `%LOCALAPPDATA%`:

| File | What it holds |
| --- | --- |
| `IconCache.db` | The original single icon cache file, a hidden file kept from older versions of Windows |
| `Microsoft\Windows\Explorer\iconcache_*.db` | One cache per icon size (`iconcache_16.db`, `iconcache_32.db`, `iconcache_256.db` and so on) plus an index, `iconcache_idx.db` |

Deleting only `IconCache.db` is the classic fix, but on Windows 10 and 11 most
icons come from the per-size files, so both are cleared below.

### Try a refresh first

Before deleting anything, ask Windows to refresh the cache. In Windows
Terminal, with either Command Prompt or PowerShell:

```bat
ie4uinit.exe -show
```

If the icons are right after that, there is nothing else to do.

### Rebuild the cache

Explorer keeps the cache files open while it runs, so it is stopped before
they are deleted and started again afterwards. Stopping Explorer also removes
the taskbar and the desktop until it is restarted, so:

1. Save open work and close all folder windows.
2. Open **Command Prompt** (not from a folder window, since Explorer is about
   to go away) and run, one line at a time:

   ```bat
   taskkill /IM explorer.exe /F
   DEL /A /F /Q "%LOCALAPPDATA%\IconCache.db"
   DEL /A /F /Q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache*"
   start explorer.exe
   ```

What each part does:

- **`taskkill /IM explorer.exe /F`** stops every process named `explorer.exe`
  (`/IM` is the image name), and `/F` forces it.
- **`DEL /A`** deletes files whatever their attributes; without it, `DEL`
  skips hidden files, and `IconCache.db` is hidden. `/F` also deletes
  read-only files and `/Q` does not ask for confirmation of the wildcard.
- **`start explorer.exe`** brings back the taskbar and the desktop. Explorer
  creates new, empty cache files and fills them as icons are drawn, so the
  first folders opened afterwards can take a moment longer.

If the taskbar does not come back, open Task Manager with
**Ctrl+Shift+Esc**, choose **Run new task**, and
run `explorer.exe`.

### Restarting Explorer from Task Manager

When the cache files are already gone or only Explorer needs a restart, Task
Manager does it without a command line: open it with
**Ctrl+Shift+Esc**, find **Windows Explorer** in
the **Processes** tab, right-click it and choose **Restart**. If a sign-out
or a reboot is easier, either one has the same effect.

## Cryptomator closes when the NVIDIA driver updates

**What it looks like.** Every time I update the NVIDIA graphics driver,
[Cryptomator](https://cryptomator.org/) closes on its own, and every vault it
had unlocked disappears with it.

**What is going on.** Installing a display driver stops the old driver and
starts the new one, which resets the graphics device under every application
on screen. Most applications redraw and carry on. Cryptomator's interface is
built with JavaFX, which draws through Direct3D on Windows, and a JavaFX
application that loses its graphics device can stop instead of recovering.
Reports in the Cryptomator community point the same way, tying NVIDIA driver
resets and Direct3D errors to Cryptomator crashes, though none of them
documents a fix.

The part that matters is the vaults. An unlocked vault is a drive that exists
only while Cryptomator is running. When Cryptomator closes, the drive goes
with it, and any application that was writing to a file inside it loses that
file mid-write.

**The fix.** Treat a driver update as a reason to close Cryptomator first:

1. Save and close every file that is open from a vault.
2. Lock every vault, then quit Cryptomator from its tray icon.
3. Install the NVIDIA driver update and wait for it to finish, including any
   screen flicker while the driver restarts.
4. Start Cryptomator again and unlock the vaults.

If the update has already started with Cryptomator open, wait for the
installer to finish before starting Cryptomator again. Starting it while the
driver is still being replaced only gets it closed a second time.

## Sources

- Eleven Forum, [Rebuild Icon Cache in Windows 11](https://www.elevenforum.com/t/rebuild-icon-cache-in-windows-11.2049/):
  the `ie4uinit.exe -show` refresh and the files to delete.
- Cryptomator Community, [Nvidia display driver crashes when Cryptomator starts (Windows)](https://community.cryptomator.org/t/nvidia-display-driver-crashes-when-cryptomator-starts-windows/2670):
  an NVIDIA driver reset taking Cryptomator's JavaFX interface down with it.
- Cryptomator Community, [Cryptomator Desktop Crash after 1.4.15 Update](https://community.cryptomator.org/t/cryptomator-desktop-crash-after-1-4-15-update-exception-illegal-instruction-0xc000001d-d3d9-dll/4313):
  a crash in JavaFX's Direct3D rendering thread.
