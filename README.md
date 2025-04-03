# verifycopy.zsh

A clean, reliable shell script to verify whether files and folders were completely and correctly copied from a source to a destination directory — including subdirectories and hidden files.

Designed for **post-copy sanity checking**: useful after backups, manual drag-and-drop transfers, SD card dumps, or Android file transfers.

---

## What This Script Does

- Recursively compares all files (including hidden ones) between source and destination
- Compares:
  - Relative file paths
  - File sizes (in bytes)
  - (Optionally) file modification timestamps
- Detects:
  - Files missing in the destination
  - Extra files in the destination
  - Files with same path but different size or timestamp (marked as changed)
- Skips macOS AppleDouble files (`._*`) that contain metadata but not actual file content
- Outputs:
  - A **color-coded summary** in terminal
  - A detailed **diff-style log** saved as `verifycopy_diff_output.txt` in the script directory

---

## Why AppleDouble Files (`._*`) Are Excluded

When copying to non-macOS file systems (e.g. FAT32, exFAT, NTFS, SMB), macOS generates `._*` files — known as **AppleDouble files** — to store extended metadata like:

- Finder tags and labels
- Custom icons
- Resource forks

These files are not user content, are invisible on macOS, and often confuse verification.  
This script **excludes them by default**, ensuring they don't pollute the results.  
Normal dotfiles (like `.bashrc`, `.config`) are **not affected** and are fully included.

---

## Why Timestamp Checking Matters

Timestamps detect changes that file size cannot — for example:

- File was edited but size didn't change
- File was re-encoded or touched
- File was modified during sync

**Timestamp comparison is optional** because some copy methods don’t preserve timestamps.

### When to Enable Timestamp Checks

> Enable when:
>
> - You used reliable methods that preserve timestamps
> - You want to ensure copied files weren’t modified after transfer

### When to Disable Timestamp Checks

> Disable when:
>
> - You copied via MTP, browser, or plain `cp`
> - You want to avoid false positives due to timestamp differences

**Recommendation:** Enable timestamp checks unless you know your copy tool strips them

---

## Reference: Copy Methods and Timestamps

### Copy Methods That Preserve Timestamps

| Method                     | Preserves Timestamps |
|----------------------------|----------------------|
| `rsync -a`, `rsync -av`    | ✅ Yes               |
| `cp -p`, `cp -a`           | ✅ Yes               |
| macOS Finder (drag & drop) | ✅ Yes               |

### Copy Methods That Strip Timestamps

| Method / Tool                 | Preserves Timestamps |
|-------------------------------|----------------------|
| `cp` (without `-p`)           | ❌ No                |
| Web/browser downloads         | ❌ No                |
| Android MTP transfer          | ❌ No                |
| Some network (SMB/NFS) shares | ❌ No                |

---

## What This Script Does Not Do

While `verifycopy.zsh` is ideal for most real-world usage, it does **not** perform full content-level validation. Specifically:

- ❌ It does **not** compare actual file contents (no hashing or checksums)
- ❌ It does **not** verify file permissions, symlinks, or extended attributes
- ❌ It does **not** detect bit-level corruption when size and timestamp are identical

If you need full integrity verification, use `rsync` with checksums (see next section).

---

## Why Not Just Use rsync?

While `rsync` is a powerful tool that can detect missing or changed files — and even verify content with checksums — this script exists because:

| Feature / Need                            | `verifycopy.zsh` ✅ | `rsync` (with `--dry-run`) |
|-------------------------------------------|----------------------|-----------------------------|
| Designed purely for **post-copy verification** | ✅ Yes              | ❌ No (sync-focused)        |
| Fully **read-only**, always safe          | ✅ Yes              | ⚠️ Only with `--dry-run`    |
| Clear, **human-readable summary**         | ✅ Yes              | ❌ No (cryptic output)      |
| Detects **extras in destination**         | ✅ Yes              | ❌ No (requires complex setup) |
| Color-coded terminal output               | ✅ Yes              | ❌ No                       |
| Logs to diff-style file                   | ✅ Yes              | ❌ No                       |
| Skips macOS `._*` clutter automatically   | ✅ Yes              | ⚠️ Only with `--exclude='._*'` |
| Supports **timestamp optionality**        | ✅ Yes              | ✅ Yes (`--size-only`)      |
| Supports **checksum-based comparison**    | ❌ No               | ✅ Yes (`-c`)               |

If you need full bit-level verification (e.g. for archives or production systems), use:

```bash
rsync -avc --dry-run --exclude='._*' /source/ /destination/
```

But for day-to-day safety checks after copying files, `verifycopy.zsh` is faster, simpler, and safer to use.

---

## Installation

### Clone the Script

```bash
git clone https://github.com/agarwalvishal/verifycopy.git ~/Tools/verifycopy
cd ~/Tools/verifycopy
chmod +x verifycopy.zsh
```

### Create a Symlink to Run It Anywhere

```bash
ln -s ~/Tools/verifycopy/verifycopy.zsh /usr/local/bin/verifycopy
```

You can now run:

```bash
verifycopy
```

---

## Usage

Run the script:

```bash
verifycopy
```

Then:

- Enter the source folder path
- Enter the destination folder path
- Choose whether to compare timestamps

After scanning and comparing, a diff log is saved as:

```bash
~/Tools/verifycopy/verifycopy_diff_output.txt
```

---

## Uninstalling

To remove the command:

```bash
rm /usr/local/bin/verifycopy
```

To delete the script and diff output:

```bash
rm -rf ~/Tools/verifycopy
```

---

## Summary

`verifycopy.zsh` is a focused tool that answers a simple but critical question:

> "Did all my files copy correctly?"

- It verifies the success of manual file copies and provides peace of mind before deleting original files and helps catch skips, overwrites, or modifications.
- It’s designed to give you fast, trustworthy feedback — without needing to understand `rsync`, parse obscure flags, or risk overwriting data.
- Use it confidently for backups, file migrations, or post-transfer validation when bit-level hashing is overkill.
