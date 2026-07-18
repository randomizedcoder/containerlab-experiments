# vendor/ — licensed images and license keys (git-ignored)

Everything in this folder **except this README** is git-ignored (see the repo
`.gitignore`). It holds large, licensed, or secret vendor artifacts that must
**never** be committed:

```
vendor/
  images/     vendor NOS images + their checksums (cEOS .tar, vEOS .qcow2, ...)
  licenses/   license keys (e.g. srlinux-26.3.lic), mode 0600
```

## What lives here

| File                            | Purpose                                              |
| ------------------------------- | ---------------------------------------------------- |
| `images/cEOS64-lab-<ver>.tar`   | Arista cEOS-lab container image (import into Docker) |
| `images/vEOS64-lab-<ver>.qcow2` | Arista vEOS VM image (not used by the cEOS labs)     |
| `licenses/srlinux-26.3.lic`     | Nokia SR Linux license, referenced by nokia-mpls     |

## How they're used

- **cEOS image** — imported into Docker, then referenced by tag in
  `topologies/arista-mpls/constants.nix`:
  ```bash
  docker import vendor/images/cEOS64-lab-4.36.1F.tar ceos:4.36.1F
  ```
- **SR Linux license** — referenced by absolute path from the containerlab
  topology (`license:` key). Keep it mode 0600.

## ⚠️ Caveat

These files are git-ignored, which means `git clean -fdx` **will delete them**.
They are not backed up by git — keep the originals (or your arista.com /
license source) available to re-download if needed.
