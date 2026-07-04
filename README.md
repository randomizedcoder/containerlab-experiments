# containerlab-experiments

A Nix-driven environment for building and running example MPLS router topologies
with [containerlab](https://containerlab.dev/). Each example is a self-contained
lab under [`topologies/`](./topologies/) whose containerlab topology and device
configs are **generated from Nix** — every address, SID, and ASN is named once
in that example's `constants.nix` and interpolated everywhere else, so there are
no hard-coded values in the generated artifacts.

## Status (2026-07-03)

The **Nix machinery is complete and working**: `nix fmt`, `nix flake check`
(formatting + render-build of every lab, no Docker), the `-up/-down/-inspect/-gen`
apps, and the render pipeline all pass. Deploy mechanics are proven end-to-end on
real containers (management-subnet selection, `CLAB_LABDIR_BASE` for the
read-only store, and SR Linux `.partial` config handling were all sorted out
against a live run).

The **two MPLS examples are blocked on licensed vendor images**:

- **Arista `arista-mpls`** — needs the cEOS-lab image (free Arista account).
  Config drafted; not yet deployed/validated.
- **Nokia `nokia-mpls`** — was prototyped on the free **SR Linux** container, but
  SR Linux's free build **cannot configure SR-MPLS** (no `segment-routing` /
  `mpls` / `sid` nodes in its schema on any platform type; the `ixr6e` Jericho
  variant also crash-loops). This example is therefore being **migrated to Nokia
  SR OS (`vr-sros`)**, which fully supports SR-MPLS/LDP/RSVP-TE, pending a
  licensed SR OS image.

Both device NOSes require accounts/licenses that are being arranged. The SR Linux
files remain in-tree as a reference prototype until the SR OS migration lands.

### Next steps

1. Obtain images: Arista cEOS-lab (import to Docker as `ceos:<ver>`) and Nokia
   SR OS qcow2 (build a `vr-sros` container via
   [vrnetlab](https://containerlab.dev/manual/vrnetlab/)).
2. Deploy & validate `arista-mpls` (IS-IS/SR adjacencies over both link pairs,
   iBGP + RFC 5549, SR-TE policies, CE↔CE ping over both AFs); fill the dynamic
   adjacency-SIDs into the SR-TE policies.
3. Rework `nokia-mpls` from SR Linux to `vr-sros` (new `constants.nix`/`configs.nix`
   in SR OS syntax; the topology/render/app machinery is unchanged).
4. Add a live-deploy smoke test once images are available (kept out of
   `nix flake check` by design).

## The examples

Both examples implement the **same logical topology** and differ only by vendor:

```
             (2 Ethernet links)             (2 Ethernet links)
  CE1 --eBGP-- PE1 ================ P ================ PE2 --eBGP-- CE2
      dual-stack    IPv6-only core: IS-IS L2 + SR-MPLS      dual-stack
```

- **IPv6-only MPLS core** (PE1–P–PE2): IS-IS (level-2, IPv6) advertises loopback
  reachability + prefix-SIDs; Segment Routing MPLS carries the transport labels;
  `P` is BGP-free.
- **Dual-stack customer edge**: CE1 and CE2 each originate one IPv4 + one IPv6
  route via eBGP. IPv4 prefixes are carried across the IPv6-only core via
  **RFC 5549** (IPv4 NLRI with an IPv6 next-hop) on the PE↔PE iBGP session.
- **Traffic engineering over both link pairs**: two TE tunnels from PE1 to PE2,
  one pinned to each parallel link pair.

| Example                                                        | Platform                   | TE mechanism   | State                           |
| -------------------------------------------------------------- | -------------------------- | -------------- | ------------------------------- |
| [`topologies/arista-mpls`](./topologies/arista-mpls/README.md) | Arista cEOS-lab            | SR-TE policies | blocked on image                |
| [`topologies/nokia-mpls`](./topologies/nokia-mpls/README.md)   | Nokia SR Linux → **SR OS** | SR-TE policies | migrating to SR OS (see Status) |

> The examples use **SR-TE**, not RSVP-TE/LDP: those are unreliable-to-absent
> over IPv6 on containerized cEOS, and SR Linux has no classic RSVP-TE. SR-TE
> gives the same two-path traffic engineering over an IPv6 control plane. See
> each example's README for per-vendor details, and the **Status** section above
> for what currently works.

## Prerequisites

- Nix with flakes enabled.
- Docker (containerlab drives it; deploys typically need root/sudo).
- Node images: **SR Linux auto-pulls** from `ghcr.io/nokia/srlinux`; **cEOS must
  be imported manually** (see [`topologies/arista-mpls`](./topologies/arista-mpls/README.md)).

## Usage

```bash
# Deploy / inspect / tear down a topology (see `nix flake show` for the full list)
nix run .#arista-mpls-up
nix run .#arista-mpls-inspect
nix run .#arista-mpls-down

nix run .#nokia-mpls-up
nix run .#nokia-mpls-down

# Render a lab dir (topology YAML + configs) to ./<name>-lab without deploying
nix run .#arista-mpls-gen

# Dev shell with containerlab, docker client, yq, yamllint, formatter
nix develop
```

## Development

```bash
nix fmt           # format Nix / Markdown / JSON (treefmt: nixfmt + prettier)
nix flake check   # static checks: formatting + renders every lab (no Docker)
nix build .#arista-mpls-lab   # materialize the rendered lab in ./result to inspect
```

## Layout

```
flake.nix                     # small flake-parts entrypoint
nix/                          # one module per concern (render, apps, checks, fmt, devshell)
topologies/<name>/
  constants.nix               # human-readable named constants (single source of truth)
  topology.nix                # constants -> containerlab topology
  configs.nix                 # constants -> per-node device configs
  README.md
```

Adding an example: create a `topologies/<name>/` with those three files and add
it to the list in [`nix/topologies.nix`](./nix/topologies.nix); the apps,
packages, and checks are generated automatically.
