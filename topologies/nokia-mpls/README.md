# nokia-mpls

> **Status (2026-07-03): BLOCKED — migrating to Nokia SR OS.**
> This example was prototyped on the free **SR Linux** container, but that build
> **cannot configure SR-MPLS**: its IS-IS instance and network-instance schemas
> have no `segment-routing` / `mpls` / `sid` config nodes on any platform type
> (verified on `ixr-d2l` and `ixr6e`; `ixr6e` also crash-loops). SR Linux does
> support IPv6 IS-IS, iBGP, and RFC 5549, but not the MPLS transport this lab
> needs. It is therefore being reworked onto **Nokia SR OS (`vr-sros`)**, which
> fully supports SR-MPLS, pending a licensed image. The files below are the
> SR Linux prototype, kept for reference until the SR OS version lands.

Nokia implementation of the shared MPLS lab: an IPv6-only SR-MPLS core with a
dual-stack customer edge.

```
             2001:db8:0:1::/127                 2001:db8:0:3::/127
             2001:db8:0:2::/127                 2001:db8:0:4::/127
  CE1 --eBGP-- PE1 ============== P ============== PE2 --eBGP-- CE2
      dual-stack   (IS-IS L2 / SR-MPLS, IPv6-only core)   dual-stack
```

## What it demonstrates

- **IPv6-only core**: IS-IS (level-2, IPv6 AF) + Segment Routing MPLS on the
  PE1–P–PE2 links. `P` is BGP-free.
- **Dual-stack customer routes**: CE1 originates `100.64.1.0/24` +
  `2001:db8:aaaa::/48`, CE2 originates `100.64.2.0/24` + `2001:db8:bbbb::/48`;
  IPv4 rides the IPv6-only core via **RFC 5549** on the PE↔PE iBGP session.
- **Traffic engineering with SR-TE**: SR Linux does **not** support classic
  RSVP-TE, so two **SR-TE policies** (one per parallel link pair, via
  adjacency-SIDs) provide the two-path traffic engineering — the equivalent of
  the RSVP-TE LSPs you would use on a full router OS. This is the one intentional
  difference from the Arista example.

## Addressing

Identical plan to the Arista example (see the table in
[`../arista-mpls/README.md`](../arista-mpls/README.md)); SR Linux just names the
interfaces `ethernet-1/1..4`. All values live in [`constants.nix`](./constants.nix)
and feed [`topology.nix`](./topology.nix) + [`configs.nix`](./configs.nix).

## Getting the image

SR Linux is free and **auto-pulls** from `ghcr.io/nokia/srlinux:latest` on first
deploy — no registration or manual import. Pin a specific tag in `constants.nix`
(`image`) if you want reproducibility.

## Run it

From the repo root:

```bash
nix run .#nokia-mpls-up        # deploy
nix run .#nokia-mpls-inspect   # list nodes
nix run .#nokia-mpls-gen       # render lab dir to ./nokia-mpls-lab for inspection
nix run .#nokia-mpls-down      # tear down
```

## Verify

```bash
docker exec -it clab-nokia-mpls-pe1 sr_cli
show network-instance default protocols isis adjacency
show network-instance default protocols isis segment-routing
show network-instance default protocols bgp neighbor
show network-instance default segment-routing te policy
```

End-to-end (from CE1):

```bash
docker exec -it clab-nokia-mpls-ce1 ip netns exec srbase-default \
  ping -I 100.64.1.1 100.64.2.1
```

## Notes

SR Linux SR-MPLS, SR-TE policy, and RFC 5549 syntax vary by release.
`configs.nix` has the correct structure and consistent values but should be
validated against your image; the SR-TE policies need each link's dynamic
adjacency-SID filled in (see the comments in `configs.nix`).
