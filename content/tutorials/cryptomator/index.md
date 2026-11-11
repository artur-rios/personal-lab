---
title: "How to Use Cryptomator to Encrypt Your Cloud Files, and How to Take a Folder Out"
description: "Cryptomator encrypts files on your own computer before Dropbox, OneDrive, Google Drive or iCloud ever see them. Here is what it is for, why to use it, how it works, how to set up and use a vault on Windows and macOS, and, step by step, how to take a folder out of a vault safely or retire a vault altogether."
date: 2026-11-11T04:00:00Z
categories: ["Tutorials"]
tags: ["Cryptomator", "Encryption", "Cloud Storage", "Privacy", "Security", "Windows", "macOS", "Tutorial"]
# The diagram is inlined by the diagram shortcode, so the SVG file itself
# need not be published.
build:
  publishResources: false
---

Cryptomator is a free, open-source app that encrypts your files on your own
device before they reach a cloud service such as Dropbox, Google Drive,
OneDrive or iCloud.[^website] Your provider only ever stores scrambled data,
and only you hold the key.

This tutorial covers what Cryptomator is for, why it is worth using, how it
works, and how to use it on Windows and macOS. Its last part is a careful,
step-by-step guide to [taking a folder out of a vault](#how-to-take-a-folder-out-of-cryptomator)
again. The steps follow Cryptomator's own documentation as of November 2026.

## What Cryptomator is for

Cryptomator works with **vaults**. A vault is an ordinary folder, usually
inside your cloud-synced folder, that holds your files in encrypted form.
When you unlock it with your password, Cryptomator shows its contents as a
virtual drive (for example `V:` on Windows). You use that drive like any other
disk. Everything you save there is encrypted on the fly and written into the
vault folder, and your sync app uploads it.

Typical uses:

- Keeping personal documents (IDs, tax papers, contracts, health records) in
  the cloud without the provider being able to read them.
- Protecting work files on a laptop or USB stick that could be lost or stolen.
- Sharing a protected folder between your own devices: desktop, laptop and
  phone.
- Teams sharing encrypted folders through Cryptomator Hub, which adds central
  access management.[^website]

## Why use it

Use Cryptomator when you want the convenience of cloud sync without trusting
the cloud company with what is inside your files.

- **The provider can't read your data.** Encryption happens on your device,
  and the key never leaves it. A breach, a rogue employee or a data request at
  the provider exposes only ciphertext.[^website]
- **File names are hidden too.** Not just contents: names and folder
  structure are encrypted, so nobody can tell a folder called `Taxes 2025`
  exists.[^vault]
- **It works with almost any cloud.** It doesn't sync anything itself; it just
  writes encrypted files into a folder your existing sync app already
  watches.[^adding] You can switch providers without changing how you work.
- **Open source and audited.** The source code is public and the project has
  had independent security audits, so its claims can be checked.[^website]
- **Free on the desktop.** The Windows, macOS and Linux apps are free; an
  optional supporter certificate unlocks extras such as dark mode. The Android
  and iOS apps read vaults for free, and a one-time purchase unlocks
  editing.[^downloads]
- **Per-file encryption syncs efficiently.** Each file is encrypted
  separately, so changing one document re-uploads one file, not a giant
  container.[^vault]

The trade-off: **if you forget the password and have no recovery key, the
data is gone.** Cryptomator cannot reset it for you.[^password]

## How it works

Cryptomator sits between your apps and your cloud folder, encrypting and
decrypting each file as it passes through. Readable files exist only in the
virtual drive, held in memory; on disk and in the cloud there is only
ciphertext.[^accessing]

{{< diagram src="how-it-works.svg" caption="You always work through the virtual drive. Taking a folder out (the dashed path) means copying it from the virtual drive to a normal folder, never from the vault folder." >}}

File contents are encrypted with AES-GCM and file names with AES-SIV, both
using 256-bit keys.[^vault] Inside the vault folder you will see:

| Item | What it is |
| --- | --- |
| `masterkey.cryptomator` | Your encrypted master key, unlocked by your password |
| `vault.cryptomator` | The vault's settings and format version |
| `d` folder | All your files and folders, encrypted and stored in random-looking subfolders |
| `.c9r` / `.c9s` entries | Individual encrypted files and folders; `.c9s` is used when an encrypted name is too long |

Don't rename, move or edit anything in here by hand. A single missing or
damaged entry can make part of the vault unreadable.

## How to use it

The routine is the same on Windows and macOS: create a vault once, then unlock
it, work in the virtual drive, and lock it. Only the installer and the file
manager differ.

### Step 1: Install

Download the app from the official downloads page.[^downloads] Your cloud
provider's sync app (OneDrive, Dropbox, Google Drive, iCloud) must also be
installed, because Cryptomator doesn't upload anything itself.[^adding]

- **Windows:** run the `.exe` installer. It also installs **WinFsp**, the
  driver that makes the vault show up as a drive letter. The `.msi` installer
  leaves WinFsp out, so use the `.exe` unless you already have
  WinFsp.[^downloads]
- **macOS:** open the `.dmg` and drag **Cryptomator** into **Applications**.
  To show vaults as a drive, Cryptomator uses **FUSE-T** or **macFUSE**, which
  you install separately. Without them it can still use WebDAV, which needs
  nothing extra.[^volumes]

### Step 2: Create a vault

These steps are identical on both systems.[^adding]

1. Click **+ Add** at the bottom left of the window, then **Create New
   Vault**.
2. **Name** the vault, for example `Personal`.
3. **Pick a storage location.** Cryptomator detects common cloud folders.
   Pick one, or choose a custom folder.
4. **Set a password** of at least 8 characters. A long passphrase is best.
5. **Create a recovery key** when offered. Print it or store it somewhere safe
   and offline. It is the only way back in if you forget the password.
6. Click **Done**.

### Step 3: Unlock and work

1. Select the vault in the list and click **Unlock**.
2. Enter the password and click **Unlock**. Tick **Remember password** only on
   a device you trust. It stores the password in your system's keychain
   (Windows Credential Manager or the macOS Keychain).[^accessing]
3. Click **Reveal Drive**.
    - **Windows:** File Explorer opens the vault as a drive letter, for
      example `V:`. You'll also find it under **This PC**.
    - **macOS:** Finder opens the vault as a drive named after it. You'll also
      find it under **Locations** in the Finder sidebar.
4. Copy, create, edit and delete files there as on any other drive. Files are
   encrypted as they are written, and readable copies are kept only in
   memory.[^accessing]

> Always work through the **virtual drive**, never inside the encrypted vault
> folder itself.

### Step 4: Lock

Click **Lock** in Cryptomator when you are done. The drive disappears from
File Explorer or Finder, and only the encrypted files remain.[^accessing] You
can also set auto-lock after a period of inactivity under **Vault Options →
General**.[^management]

### Use it on another device

On a second computer, install Cryptomator and wait for the cloud folder to
finish syncing. Then choose **+ Add → Open Existing Vault** and select the
`masterkey.cryptomator` file inside the vault folder.[^adding] On a phone, the
Cryptomator mobile app connects to your cloud account and opens the same
vault.

### Password and recovery key later

In **Vault Options → Password** you can **Change Password** (needs the current
password or the recovery key) or **Display Recovery Key** (needs the
password).[^password] If you skipped the recovery key at creation, generate
and store one there now.

## How to take a folder out of Cryptomator

To get a folder out, you **copy it from the unlocked virtual drive to a normal
location, check the copy, and only then delete it from the vault.** Never copy
from the encrypted vault folder: the files there end in `.c9r` and are
unreadable without Cryptomator.[^vault]

Each step below gives the Windows and macOS actions where they differ.

### Before you start

- [ ] You know the vault password (or have the recovery key).
- [ ] Your cloud sync app shows everything up to date. **Windows:** the
  OneDrive, Dropbox or Google Drive icon in the taskbar's notification area
  shows no pending uploads. **macOS:** the same app's icon in the menu bar
  shows it is up to date. A half-synced vault can be missing files.
- [ ] You have chosen a **destination** outside the vault with enough free
  space, for example a new folder in **Documents**. If you put it inside your
  cloud folder, it will sync to the cloud **unencrypted**.

### Part A: Move one folder out of a vault

1. **Unlock the vault.** Open Cryptomator, select the vault, click **Unlock**
   and enter the password.
2. **Click Reveal Drive.**
    - **Windows:** File Explorer opens the vault as a drive, for example `V:`.
    - **macOS:** Finder opens the vault as a drive named after it.
3. **Open a second window at your destination.**
    - **Windows:** press `Win+E` for a new File Explorer window and go to the
      destination. Put the windows side by side with `Win+←` and `Win+→`.
    - **macOS:** in Finder press `Cmd+N` for a new window and go to the
      destination. Drag the windows side by side.
4. **Select the folder** you want to take out in the vault window.
5. **Copy it, don't cut it.** Copying keeps the original safe in the vault
   until you have checked the result.
    - **Windows:** press `Ctrl+C`, click inside the destination window, press
      `Ctrl+V`. Don't use `Ctrl+X`, which moves.
    - **macOS:** press `Cmd+C`, click inside the destination window, press
      `Cmd+V`. Don't use `Cmd+Option+V`, which moves.
6. **Wait for the copy to finish.** Large folders can take a while, because
   every file is decrypted as it is read.
7. **Check the copy.** Do this for the original in the vault and for the copy,
   and compare.
    - **Windows:** right-click the folder and choose **Properties**. Compare
      **Size** and **Contains** (number of files and folders).
    - **macOS:** select the folder and press `Cmd+I` (**Get Info**). Compare
      **Size** and the number of items. Give it a moment to finish counting.
    - On both, open a few files from the destination to be sure they work.
8. **Delete the folder from the vault.** Only after step 7 checks out.
    - **Windows:** in the vault drive window, select the original folder,
      press `Delete` and confirm. Windows may warn that it will be deleted
      permanently; that is expected, because the vault drive has no Recycle
      Bin.
    - **macOS:** in the vault drive window, select the original folder and
      press `Cmd+Delete`. Finder may warn that it will be deleted
      immediately; that is expected, because the vault drive has no Trash.
9. **Let your cloud app finish syncing.** It removes the matching encrypted
   files from the cloud.
10. **Lock the vault** in Cryptomator.

Done: the folder now lives unencrypted at the destination, and the vault no
longer contains it.

> **If the copy asks to replace files, stop.** On Windows choose to decide for
> each file; on macOS choose **Keep Both** or **Stop**. Cryptomator drives are
> case-sensitive,[^accessing] but Windows and macOS usually are not, so
> `Report.pdf` and `report.pdf` can both exist in the vault but collide
> outside it. Rename one in the vault, then copy again.

### Part B: Take everything out and retire the vault

Use this when you want to stop using a vault altogether.

1. **Unlock** the vault and click **Reveal Drive**.
2. **Select everything** in the vault drive (`Ctrl+A` on Windows, `Cmd+A` on
   macOS) and **copy** it to your destination, as in Part A.
3. **Check the copy** the same way: size, number of items, and a few files
   opened.
4. Click **Lock** in Cryptomator.
5. **Remove the vault from the list:** right-click it (on macOS,
   Control-click also works) and choose **Remove**. This only works while the
   vault is locked, and it does **not** delete any files.[^management]
6. **Delete the vault folder**, the one containing `vault.cryptomator`,
   `masterkey.cryptomator` and the `d` folder. Your cloud app then deletes it
   from the cloud too.[^management]
    - **Windows:** in File Explorer, go to your cloud folder, select the vault
      folder and press `Delete`. It goes to the Recycle Bin until you empty
      it.
    - **macOS:** in Finder, go to your cloud folder, select the vault folder
      and press `Cmd+Delete`. It goes to the Trash until you empty it.

Tip: if you have the space, wait a few days before step 6. Keeping the
encrypted vault around is a free backup until you are sure the unencrypted
copy is complete.

## Common mistakes and fixes

| Problem | Cause | Fix |
| --- | --- | --- |
| Copied files have names like `aB3x….c9r` and won't open | You copied from the encrypted vault folder, not the virtual drive | Delete that copy, unlock the vault, and copy from the drive opened by **Reveal Drive** |
| Some files are missing after the copy | The vault wasn't fully synced on this device | Wait for your cloud app to finish, then compare and copy again |
| Windows offers to replace files | Two names differ only by upper/lower case | Rename one inside the vault, then copy again |
| Copy fails with "path too long" on Windows | Deeply nested folders exceed Windows' path limit | Copy to a short destination such as `C:\Out`, or copy subfolders one at a time |
| **Remove** is greyed out | The vault is still unlocked | Click **Lock** first |
| Forgot the password | — | Reset it with your recovery key. Without the key, the data cannot be recovered.[^password] |
| Sync conflict files appear in the vault | The vault was edited on two devices at once | Open both versions in the virtual drive, keep the right one, and avoid editing the same file on two devices at once |

## Quick reference

- **Put files in:** Unlock → Reveal Drive → copy into the drive → Lock.
- **Take a folder out:** Unlock → Reveal Drive → **copy** the folder to a
  normal location → check count and size → delete from the drive → let sync
  finish → Lock.
- **Retire a vault:** copy everything out → check → Lock → Remove from list →
  delete the vault folder.
- **Never** touch the encrypted vault folder directly while you still use the
  vault.
- **Always** keep the recovery key somewhere safe and offline.

## References

[^website]: Skymatic. (n.d.). *Cryptomator*. Retrieved November 11, 2026, from <https://cryptomator.org/>

[^vault]: Skymatic. (n.d.). Vault encryption scheme. In *Cryptomator documentation*. <https://docs.cryptomator.org/en/latest/security/vault/>

[^adding]: Skymatic. (n.d.). Adding vaults. In *Cryptomator documentation*. <https://docs.cryptomator.org/en/latest/desktop/adding-vaults/>

[^downloads]: Skymatic. (n.d.). Downloads. In *Cryptomator*. Retrieved November 11, 2026, from <https://cryptomator.org/downloads/>

[^password]: Skymatic. (n.d.). Password and recovery key. In *Cryptomator documentation*. <https://docs.cryptomator.org/en/latest/desktop/password-and-recovery-key/>

[^accessing]: Skymatic. (n.d.). Accessing vaults. In *Cryptomator documentation*. <https://docs.cryptomator.org/en/latest/desktop/accessing-vaults/>

[^volumes]: Skymatic. (n.d.). Volume types. In *Cryptomator documentation*. <https://docs.cryptomator.org/en/latest/desktop/volume-type/>

[^management]: Skymatic. (n.d.). Vault management. In *Cryptomator documentation*. <https://docs.cryptomator.org/en/latest/desktop/vault-management/>
