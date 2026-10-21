---
title: "How to Back Up Any Folder With OneDrive"
description: "OneDrive only syncs what is inside its own folder. The common fix, a symbolic link inside OneDrive pointing at the folder elsewhere, is unsupported and stops syncing changes. The reliable way is the reverse: move the folder into OneDrive and leave a directory junction at the old path, so every program that used it keeps working."
date: 2026-10-21T22:00:00Z
categories: ["Tutorials"]
tags: ["OneDrive", "Windows", "Windows 11", "Backup", "mklink", "Directory Junction", "Symbolic Link", "Tutorial"]
---

OneDrive backs up what is inside its own folder, usually
`C:\Users\<you>\OneDrive`, and nothing else. Its built-in folder backup
extends that to a fixed set of folders: Desktop, Documents, Pictures, Music
and Videos.[^folderbackup] A folder anywhere else, say `D:\Projects`, is not
backed up unless it is moved into OneDrive, and moving it breaks every
program, shortcut and script that expects it at `D:\Projects`.

The trick that gets passed around is to leave the folder where it is and put
a symbolic link to it inside OneDrive. That does not work reliably, for
reasons explained [below](#why-not-a-link-inside-onedrive). What works is
the same idea pointed the other way: move the folder into OneDrive, where it
syncs like any other folder, and leave a link at the old path, so everything
that used `D:\Projects` still finds it there.

The commands below were run on Windows 11 Pro on 21 October 2026, from a
normal, non-administrator prompt.

## Step 1: Find the two paths

You need two paths:

- **The folder to back up.** This tutorial uses `D:\Projects`.
- **Your OneDrive folder.** Windows stores it in the `OneDrive` environment
  variable. In PowerShell, `$env:OneDrive` prints it; in Command Prompt,
  `echo %OneDrive%`. On a default setup it is `C:\Users\<you>\OneDrive`.

The folder will end up at `C:\Users\<you>\OneDrive\Projects`. Make sure the
drive OneDrive lives on has room for it, because the files now physically
move there.

## Step 2: Move the folder into OneDrive

Close every program that has files open in `D:\Projects`: editors, terminals
sitting in that directory, anything that runs from it. Then move the folder.
Dragging it in Explorer with **Shift** held moves it instead of copying it;
from PowerShell:

```powershell
Move-Item "D:\Projects" "$env:OneDrive\Projects"
```

When the move finishes, `D:\Projects` must no longer exist, since the next
step creates something with that name. OneDrive starts uploading the folder
straight away.

## Step 3: Leave a junction at the old path

A directory junction is an entry in the file system that redirects one path
to another folder on the same machine. Programs that open `D:\Projects\app`
are sent to `C:\Users\<you>\OneDrive\Projects\app` without noticing.

In **Command Prompt**:

```bat
mklink /j "D:\Projects" "C:\Users\<you>\OneDrive\Projects"
```

The link comes first and the target second, which is easy to get backwards.
`mklink` answers with
`Junction created for D:\Projects <<===>> C:\Users\<you>\OneDrive\Projects`.[^mklink]

`mklink` is built into Command Prompt and does not exist in PowerShell. From
PowerShell, either call it through `cmd /c mklink /j ...` or use the
PowerShell equivalent:[^newitem]

```powershell
New-Item -ItemType Junction -Path "D:\Projects" -Target "$env:OneDrive\Projects"
```

Neither needs an administrator prompt. Check the result with:

```powershell
Get-Item "D:\Projects" | Select-Object LinkType, Target
```

which shows `Junction` and the OneDrive path. In Explorer, `D:\Projects`
now has a small arrow on its icon, and opening it shows the same files as
the OneDrive folder, because they are the same files.

### Junction or symbolic link?

`mklink /d` creates a directory symbolic link instead, and for this purpose
either works. The junction is the better default for two reasons:

- **No special permission.** Creating a symbolic link needs an elevated
  prompt, unless Developer Mode is turned on in Windows settings, which lifts
  the requirement.[^symlinks] A junction needs neither.
- **Fewer surprises.** A junction always points at an absolute path on a
  local drive, which is exactly this case. Symbolic links can also point at
  relative paths and network shares, which is flexibility this setup does
  not need.

## Step 4: Keep the files on the device

With OneDrive's Files On-Demand and Windows Storage Sense both turned on,
files that have not been opened for a while become online-only
placeholders, which are downloaded again when opened.[^ondemand] Opening one through the junction works, but a build tool
or backup script that walks thousands of files will trigger thousands of
downloads, or fail offline. For a folder that programs read from, right-click
`OneDrive\Projects` in Explorer and choose **Always keep on this device**.

## Why not a link inside OneDrive?

The approach most guides give is the reverse of the one above: leave
`D:\Projects` where it is and create a link inside OneDrive pointing at it,
with `mklink /d "C:\Users\<you>\OneDrive\Projects" "D:\Projects"`.

Microsoft's list of OneDrive restrictions says it plainly: OneDrive does not
support syncing through symbolic links or junction points.[^restrictions]
In practice the setup half works, which is what makes it misleading. When
the link is created, or when OneDrive starts, it uploads what it finds
behind the link, so the first sync looks fine. After that, new files,
edits, renames and deletions inside the linked folder are not picked up
until OneDrive is restarted.[^coretech] The likely cause is how Windows
reports changes: Microsoft documents that a program watching a folder that
contains symbolic links is told when the links change, not when the files
they point to change.[^changenotify] So the backup quietly falls behind, which is the worst
way for a backup to fail.

There is a second cost. OneDrive's folder backup refuses to protect a folder
that contains a junction or symbolic link,[^folderbackup] so a link placed
inside Documents, for example, can block backing up Documents itself.

With the link outside OneDrive and the real files inside it, OneDrive never
sees a link at all. It watches an ordinary folder, and the junction is only
something the rest of the system walks through.

## Undoing it

To put things back as they were, remove the junction, then move the folder
back. In PowerShell:

```powershell
cmd /c rmdir "D:\Projects"
Move-Item "$env:OneDrive\Projects" "D:\Projects"
```

A plain `rmdir` on a junction removes only the junction; the files behind it
are untouched. Command Prompt's own `move` cannot do the second line: it
refuses to move a folder to another drive with "Access is denied", which is
why both moves in this tutorial use PowerShell's `Move-Item` or Explorer. Do not add `/s`, and do not delete the junction's
*contents* in Explorer: that deletes the real files in OneDrive, and OneDrive
then deletes them from the cloud too.

## References

[^folderbackup]: Microsoft. (n.d.). Back up your folders with OneDrive. In *Microsoft Support*. <https://support.microsoft.com/en-us/office/back-up-your-folders-with-onedrive-d61a7930-a6fb-4b95-b28a-6552e77c3057>

[^mklink]: Microsoft. (n.d.). mklink. In *Windows commands*. Microsoft Learn. <https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/mklink>

[^newitem]: Microsoft. (n.d.). New-Item. In *PowerShell documentation*. Microsoft Learn. <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item>

[^symlinks]: Microsoft. (2016, December 2). Symlinks in Windows 10! *Windows Developer Blog*. <https://blogs.windows.com/windowsdeveloper/2016/12/02/symlinks-windows-10/>

[^ondemand]: Microsoft. (n.d.). Save disk space with OneDrive Files On-Demand for Windows. In *Microsoft Support*. <https://support.microsoft.com/en-us/office/save-disk-space-with-onedrive-files-on-demand-for-windows-0e6860d3-d9f3-4971-b321-7092438fb38e>

[^restrictions]: Microsoft. (n.d.). Restrictions and limitations in OneDrive and SharePoint. In *Microsoft Support*. <https://support.microsoft.com/en-us/office/restrictions-and-limitations-in-onedrive-and-sharepoint-64883a5d-228e-48f5-b3d2-eb39e07630fa>

[^coretech]: Core Technologies Consulting. (2023, August 9). OneDrive doesn't sync directory junctions. *The Core Technologies Blog*. <https://www.coretechnologies.com/blog/onedrive/onedrive-directory-junctions>

[^changenotify]: Microsoft. (n.d.). FindFirstChangeNotificationA function (fileapi.h). In *Win32 API documentation*. Microsoft Learn. <https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-findfirstchangenotificationa>
