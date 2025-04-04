# Test Coverage & Design Justification for verifycopy.zsh

## Tool Philosophy

> **The tool's #1 priority is to avoid false confidence in broken copies.**  
> It's okay to **fail noisily** — it's **not okay to succeed silently when wrong**.

This means:

- Detect **any real issue** with missing or mismatched files  
- Avoid misleading users by claiming everything is fine when it isn’t  
- Don't get slowed down by unnecessary checksum comparisons unless absolutely needed

---

## Verification Logic

A file is flagged as mismatched if:

- It is **missing** in either source or destination
- It has a **different size**
- (Optionally) It has a **different timestamp**
- File **content is not compared** (checksum not used for speed)

---

## Summary of Test Cases (Simplified by Real-World Scenarios)

| #  | Scenario (Real-World Description)                                          | Name | Size | Time | Content | Result When Timestamp Check Is... |
|-----|---------------------------------------------------------------------------|------|------|------|---------|-----------------------------------|
| 1   | File copied perfectly                                                     | ✅   | ✅   | ✅   | ✅      | ✅ Pass Always                     |
| 2   | File is present in source but missing in destination                      | ❌   | —    | —    | —       | ❌ Fail (Missing in DEST)         |
| 3   | File is present in destination but missing in source                      | ❌   | —    | —    | —       | ❌ Fail (Extra in DEST)           |
| 4   | File content changed and size is different, but timestamp preserved       | ✅   | ❌   | ✅   | ❌      | ❌ Fail (Detected via size)       |
| 5   | File copied, but timestamp changed                                        | ✅   | ✅   | ❌   | ✅      | ❌ Fail if timestamp check ON<br>✅ Pass if OFF |
| 6   | File content changed, but size and timestamp are the same                | ✅   | ✅   | ✅   | ❌      | ✅ Pass (False negative allowed)  |
| 7   | Same content, different file name (e.g. file got renamed)                | ❌   | ✅   | ✅   | ✅      | ❌ Fail (Name mismatch)           |
| 8   | File modified, content and timestamp changed, but size is same           | ✅   | ✅   | ❌   | ❌      | ❌ Fail if timestamp check ON<br>✅ Pass if OFF |
| 9   | Files inside deep nested folders                                          | ✅   | ✅   | ✅   | ✅      | ✅ Pass Always                     |
| 10  | `.AppleDouble` file exists only in source (macOS metadata file)          | —    | —    | —    | —       | ✅ Pass (Intentionally Ignored)   |
| 11  | `.DS_Store` file differs in size, timestamp, and content                 | ✅   | ❌   | ❌   | ❌      | ✅ Pass (Intentionally Ignored)   |
| 12  | File modified with timestamp changed, but timestamp check is disabled    | ✅   | ✅   | ❌   | ✅      | ✅ Pass (Expected when timestamp ignored) |

---

## Philosophy-Adhering Design Choices

| Feature/Case                                    | Covered? | Why it matters                              |
|------------------------------------------------|----------|---------------------------------------------|
| Missing or extra files                         | ✅ Yes   | Core integrity check                        |
| Size differences                               | ✅ Yes   | Flags content-altering changes              |
| Timestamp mismatches                           | ✅ Yes   | Catches silent edits (if enabled)           |
| Ignoring `.DS_Store`, `._*` system files       | ✅ Yes   | Avoids clutter-caused false alarms          |
| Skipping checksum comparison                   | ✅ Yes   | Keeps tool fast and usable on large trees   |
| Deep directory recursion                       | ✅ Yes   | Ensures structure-wide validation           |
| Edge case of same size + timestamp + diff content | ❌ No (by design) | Acceptable false negative for speed      |

---

## How to Run the Test Suite

To validate correctness of `verifycopy.zsh` after any change:

```bash
chmod +x test-verifycopy.sh
./test-verifycopy.sh
```