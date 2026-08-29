# Kontakt-USB — minimal Debian + XFCE live distro

A minimal, portable Linux system designed to boot from a 128GB USB drive with:

- **Debian 12 (bookworm) + XFCE** — light, stable, well documented
- **Outlook access** — both Outlook Web App (installed as an app-style window)
  and Thunderbird (real native client) configured against Office 365
- **KontaktApp** — a local case-logging tool tailored for logging cases as
  Kontaktbefalingsmand, with case numbers, contact details, categories,
  status tracking and CSV export
- **Full persistence** — everything you do (mail, cases, settings, files)
  is saved back to the USB drive across reboots

> Note on Outlook: Microsoft does not ship a native Linux Outlook client.
> There is no way around that. This build gives you the two best practical
> substitutes — an installed Outlook Web App window, and Thunderbird as a
> true offline-capable native client — both pre-installed and ready.

---

## 1. Build the ISO (from your Mac, no Linux machine needed)

`live-build` only runs on Debian/Ubuntu, so a MacBook can't run
`build-distro.sh` directly. Instead, this repo includes a GitHub Actions
workflow that builds the ISO on GitHub's free Linux servers:

1. Create a **public** GitHub repo (free builds) and push this whole
   `kontakt-usb-distro` folder to it:
   ```bash
   cd kontakt-usb-distro
   git init
   git add .
   git commit -m "Kontakt-USB build kit"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<repo-name>.git
   git push -u origin main
   ```
2. On GitHub, go to the repo's **Actions** tab → **Build KontaktUSB ISO** →
   **Run workflow** → **Run workflow** (this is `workflow_dispatch`, so it
   only runs when you click the button)
3. Wait ~20–40 minutes. When the run finishes (green check), open it and
   download the **kontaktusb-iso** artifact — it's a zip containing
   `live-image-amd64.hybrid.iso`
4. Unzip it — you now have the ISO sitting on your Mac, ready for the next
   step. Move it to the Windows laptop (AirDrop won't work laptop-to-PC, so
   use a cloud drive, a shared network folder, or just copy it via a USB
   stick/cable).

*(If you ever do get access to a Debian/Ubuntu machine or VM, `sudo
./build-distro.sh` does the same build locally — see the script for
details.)*

---

## 2. Write it to the 128GB USB drive with full persistence — on the Windows laptop

Do this step on the Windows laptop, since that's where the USB will actually
be used. **Rufus** handles both the ISO writing and the persistent partition
in one pass — no manual `dd`/`parted` needed.

1. Download **Rufus** (free): https://rufus.ie
2. Plug in the 128GB USB drive
3. Open Rufus:
   - **Device**: select your USB drive (⚠️ double-check — this erases it)
   - **Boot selection**: click **SELECT** and choose the `.iso` file
   - Rufus will detect it's a Debian Live ISO and show a
     **"Persistent partition size"** slider — drag it to use (almost) the
     full 128GB, leaving it just shy of the max
   - Leave partition scheme as **GPT** / target as **UEFI** unless the
     laptop is older BIOS-only hardware
4. Click **START** and confirm. This takes 10–20 minutes depending on the
   drive's write speed.

That's it — Rufus creates and labels the persistence partition and writes
the correct `persistence.conf` for you automatically.

---

## 3. Boot it

1. Boot the target machine from the USB drive (F12/F2/Esc at startup,
   depending on the machine, to pick the boot device)
2. At the Debian Live boot menu, either:
   - choose **"Live (with persistence)"** if it's listed, or
   - press `Tab`/`e` to edit the boot line and add `persistence` at the end,
     then boot
3. Log in — the XFCE desktop loads with:
   - **Outlook installere (kør en gang)** icon on the desktop — run this
     once to install the Outlook Web App shortcut and open Thunderbird's
     account wizard
   - **KontaktApp – Sagslog** icon — your case log, ready to use

From then on, everything persists automatically on every future boot.

---

## 4. Using KontaktApp day to day

- Click the desktop icon (or it auto-starts on login) — it opens in its own
  app window at `http://127.0.0.1:5157`
- **+ Ny sag** creates a new case with an auto-generated number
  (`KB-2026-0001`, etc.)
- Fields: emne, kontaktperson, telefon/e-mail, sted, kategori, beskrivelse,
  handling/noter, status, opfølgningsdato
- Filter/search from the case list, and use **Eksporter CSV** to get a
  spreadsheet of all cases (e.g. for reporting up the chain)
- Data is stored at `~/.local/share/kontaktapp/cases.db` (SQLite) — on the
  persistent partition, so it survives reboots. Back this file up
  periodically if the cases are important (copy it off to another drive).

If you need different/extra fields (e.g. a specific unit reference number,
a priority level, escalation contact, etc.), tell me what they should be and
I'll adjust `case-app/app.py` and the form templates — it's a quick change.

---

## 5. Customising further

- **Package list**: edit `config/package-lists/desktop.list.chroot` before
  building to add/remove software
- **Desktop wallpaper/branding**: drop files into
  `config/includes.chroot/etc/skel/...` before building
- **Re-running the build**: `sudo rm -rf build/` first if you change config,
  then re-run `build-distro.sh`
