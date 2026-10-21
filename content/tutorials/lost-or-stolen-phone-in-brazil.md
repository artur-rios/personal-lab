---
title: "What to Do If Your Phone Is Lost or Stolen in Brazil"
description: "A checklist for the hours after a phone is lost or stolen, written for Brazil: lock and erase it with Samsung Find or Google's Find Hub while it is still online, block the line and the IMEI through the operator or the Celular Seguro programme, protect bank and e-mail accounts, and file a police report. Plus what to set up now so that every step works when you need it."
date: 2026-10-21T23:30:00Z
categories: ["Tutorials"]
tags: ["Smartphone", "Security", "Brazil", "Anatel", "Celular Seguro", "IMEI", "Samsung", "Android", "Tutorial"]
---

I live in Brazil, where phone theft is common enough that it pays to know
the steps before you need them. This tutorial is the checklist I keep for
that moment. It covers the tools every Android phone has, Samsung's in
particular because that is what I use, and the Brazilian side: the mobile
operator, Anatel's national blocklist of stolen phones, the federal
*Celular Seguro* programme and the police report (*boletim de ocorrência*).

Every step below was checked against the official pages of Samsung, Google,
Anatel and the Ministry of Justice (*Ministério da Justiça e Segurança
Pública*, MJSP) on 21 October 2026. Menus and names change often; when
something does not match, the linked page is the authority.

## The order matters

Two things pull in opposite directions:

- **Erasing the phone needs it online.** Google's Find Hub can only lock or
  erase a phone that is switched on and connected to mobile data or
  Wi-Fi,[^google] and Samsung Find's commands reach the phone the same way.
  A phone that is off or disconnected only shows its last known
  location.
- **Blocking the line takes it offline.** Once the operator blocks the
  chip, the phone has no mobile data, and a blocked IMEI cannot connect to
  any Brazilian mobile network.[^anatel]

So deal with the phone itself first, while it may still be connected, and
block the line and the device straight after. If the phone was stolen
rather than lost, do it all in the same hour: the sooner the line is
blocked, the less time anyone has to use it.

## Step 1: Lock and erase the phone

Use another phone or a computer. There are two services, and a Samsung phone
signed in to a Google account appears in both, so if one fails, try the
other.

### Samsung Find

1. Go to [samsungfind.samsung.com](https://samsungfind.samsung.com) and sign
   in with the Samsung account used on the lost phone.[^samsung]
2. Select the phone. The map shows where it is, or its last known location
   if *Send last location* was turned on.
3. If it may be nearby, **ring** it.
4. Turn on **Lost mode**: it locks the screen, shows a message and contact
   details, and restricts access to the phone's features. Locking the phone
   this way also locks Samsung Wallet.[^wallet]
5. If you will not get it back, choose **Erase data**. This resets the phone
   to factory settings and deletes everything on it. It is only available
   on the website, not in the app.[^samsung]

**The sign-in problem.** If your Samsung account uses two-step verification
and the codes come from an authenticator app on the phone that is now
missing, you cannot receive a code. That is exactly what happened to me.
Use one of the account's **backup codes** instead: one-time codes created
when two-step verification is set up, meant for when the other methods
fail.[^samsungcodes] If you have never saved them, see
[Prepare now](#prepare-now-before-it-happens).

### Google Find Hub

Google's service, formerly Find My Device, works for any Android phone with
a Google account.[^google]

1. Go to [android.com/find](https://www.android.com/find) and sign in with
   the Google account on the lost phone.
2. Select the phone. You can **play a sound** (full volume for five
   minutes, even on silent), **mark it as lost**, which locks it with its
   PIN, pattern or password and lets you add a message and contact number,
   or **factory reset** it.
3. Next to the phone's name, open the settings to see its **IMEI**. Write it
   down: the operator may ask for it in the next step.

Erasing has a cost on both services: after a factory reset, the phone no
longer appears in Find Hub, and Samsung warns that location and remote
control may stop working.[^google][^samsung] Erase once you are ready to
give up on finding it. Whoever has the phone still cannot use it afterwards
without your Google account password.[^google]

## Step 2: Block the line and the device

There are two separate blocks, and it is worth knowing what each one
does:[^anatel]

| Block | What it does | What it does not do |
| --- | --- | --- |
| **Line** (the chip, or SIM card) | Stops your number being used in another phone and running up charges on your account. | Does not stop the phone being used with someone else's chip. |
| **Device** (the IMEI) | Adds the phone's IMEI to the CEMI (*Cadastro de Estações Móveis Impedidas*), a blocklist shared by every Brazilian operator, so the phone cannot use any mobile network in the country. | Does not block your chip, which could still work in another phone. |

You want both. There are two ways to get them.

### Through Celular Seguro

[Celular Seguro](https://celularseguro.mj.gov.br/) is a federal programme
run by the MJSP with Anatel, the operators and the banks' federation,
Febraban. A single **alert** sent through its app or website reaches every
participant at once: the operators block the line and the IMEI, and partner
banks block access to your accounts in their apps.[^anatelcs][^mjsp]

1. Sign in at [celularseguro.mj.gov.br](https://celularseguro.mj.gov.br/)
   with your gov.br account, from any phone or computer.
2. Choose **Emitir Alerta** (send alert), select the phone number and fill
   in the details of what happened.
3. Choose the kind of block:[^mjsp]
   - **Modo recuperação** (recovery mode) blocks the line and your partner
     bank accounts, but not the phone. If the phone is later used with
     another chip, the operator reports the new number, so the police have
     a chance of recovering it.
   - **Bloqueio Total** (total block) also blocks the IMEI. The phone
     becomes useless, but also harder for the police to trace.
4. Keep the **protocol number** it gives you. You will need it to undo
   anything.

Three conditions decide whether it works:[^mjsp]

- **The line must be in your CPF.** Operators block only when the name and
  CPF registered in Celular Seguro match the line's holder at the operator.
  A line in someone else's name gets no block from the operator at all.
- **Registering the phone beforehand makes it a one-tap job.** You can send
  an alert without having registered, but a registered phone and a
  registered *pessoa de confiança* (trusted person), who can send the alert
  for you, make the moment much easier.
- **Only the operators listed in the app block through it.** If yours is
  not listed, the alert only blocks the bank accounts; contact the operator
  directly for the line.

The choice cannot be changed or undone in the app afterwards.

### Through the operator

Without Celular Seguro, call your operator on any of its channels and ask
for both blocks. Anatel says to give the number of the line that was in the
phone, the date and time of the loss or theft, and details that confirm who
you are; with that, the operator finds the IMEI itself and adds it to the
CEMI.[^anatel] Have the IMEI from Find Hub at hand anyway. For a phone
with two SIM slots, every IMEI must be blocked, even for a slot that was
never used.

### Keeping your number

Blocking the line does not cancel it. Ask the operator for a new chip with
the same number. In my experience this is easiest in one of the operator's
own stores, which is also where any block placed through Celular Seguro has
to be undone.[^mjsp]

## Step 3: Protect your accounts

The phone was the key to most of your accounts: e-mail, banks, and the
authenticator app for everything else.

- **Banks.** Partner banks block their apps on a Celular Seguro alert, but
  not every bank is a partner. Call each bank whose app was on the phone.
  If the phone had cards in a digital wallet and you could not lock it,
  Samsung's advice is to call the number on the back of the physical
  card.[^wallet]
- **E-mail first, then the rest.** Change the password of your Google
  account and your Samsung account, then of every e-mail account on the
  phone. E-mail is how almost every other password is reset, so whoever
  controls it controls the rest. Google's help page for lost phones links
  to its checklist for securing the account.[^google]
- **Sign the phone out.** In your Google account's device list, and in
  apps that show where you are signed in, remove the lost phone.

## Step 4: File a police report

Register a *boletim de ocorrência* (BO) with the Polícia Civil of your
state, either at a police station or online through the state's *delegacia
virtual*. A Celular Seguro alert does **not** replace the BO; the MJSP is
explicit about that.[^mjsp] The report is the document that proves the
phone was stolen, for insurance, for disputing charges, and for the police
if the phone turns up. All 26 states and the Federal District feed a shared
national database of stolen phones, the *Banco Nacional de Celulares com
Restrição*.[^mjsp]

## If you get the phone back

- **Line and IMEI:** only the person who asked for the block can ask to
  undo it, through the police or the operator.[^anatel] A block placed
  through Celular Seguro is undone in person at one of the operator's own
  stores, not a reseller.[^mjsp]
- **Banks:** each bank unblocks its own app; Celular Seguro does not do it
  for you.[^mjsp]
- **An erased phone** asks for your Google account password before it can
  be used again.[^google]

## Prepare now, before it happens

Every step above is easier with a little preparation, and some are
impossible without it:

1. **Write down the IMEI.** Dial `*#06#` to show it; it is also on the
   box.[^mjsp] A dual-SIM phone shows two.
2. **Register in Celular Seguro.** Add the phone and line, and at least one
   *pessoa de confiança*, who can send the alert if you cannot.[^mjsp]
3. **Save your backup codes somewhere other than the phone.** Both Google
   and Samsung offer one-time backup codes for two-step
   verification.[^googlecodes][^samsungcodes] Google suggests keeping them
   with your passport or other important documents. If your authenticator
   app lives only on your phone, these codes are how you sign in to find
   it.
4. **Check that finding is turned on.** On a Samsung phone, under
   *Settings > Security and privacy > Lost device protection > Find My
   Mobile*, turn on finding, *Send last location* and *Offline finding*, so
   nearby Galaxy devices can help locate it even when it is
   offline.[^samsung]
5. **Use a screen lock.** Find Hub locks the phone with its PIN, pattern or
   password, and its network of other Android devices only helps find a
   phone that has one.[^google]

## References

[^google]: Google. (n.d.). Encontrar, proteger ou limpar um dispositivo Android perdido. In *Ajuda do Android*. <https://support.google.com/android/answer/6160491?hl=pt-BR>

[^samsung]: Samsung Brasil. (2026, September 30). Como usar o Samsung Find para localizar um celular, dispositivo ou item perdido. <https://www.samsung.com/br/support/mobile-devices/use-the-samsung-find-app-to-locate-a-lost-device/>

[^wallet]: Samsung US. (n.d.). Manage Samsung Pay if your phone or watch is missing. <https://www.samsung.com/us/support/answer/ANS10002615/>

[^samsungcodes]: Samsung Gulf. (n.d.). How to find backup codes for your Samsung account. <https://www.samsung.com/ae/support/apps-services/accessing-backup-codes-for-your-samsung-account/>

[^googlecodes]: Google. (n.d.). Sign in with backup codes. In *Google Account Help*. <https://support.google.com/accounts/answer/1187538>

[^anatel]: Agência Nacional de Telecomunicações. (2025, December 22). Celular roubado. <https://www.gov.br/anatel/pt-br/assuntos/celular-legal/celular-roubado>

[^anatelcs]: Agência Nacional de Telecomunicações. (2025, December 22). Celular Seguro. <https://www.gov.br/anatel/pt-br/assuntos/celular-legal/celular-seguro>

[^mjsp]: Ministério da Justiça e Segurança Pública. (2026, June 25). Celular Seguro: dúvidas frequentes. <https://www.gov.br/mj/pt-br/acesso-a-informacao/acoes-e-programas/celular-seguro/duvidas-frequentes>
