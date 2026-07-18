# arista-mpls

Arista **cEOS-lab** implementation of the shared MPLS lab: an IPv6-only
SR-MPLS core with a dual-stack customer edge.

```
             2001:db8:0:1::/127                 2001:db8:0:3::/127
             2001:db8:0:2::/127                 2001:db8:0:4::/127
  CE1 --eBGP-- PE1 ============== P ============== PE2 --eBGP-- CE2
      dual-stack   (IS-IS L2 / SR-MPLS, IPv6-only core)   dual-stack
```

## What it demonstrates

- **IPv6-only core**: PE1–P–PE2 links and loopbacks are IPv6 only. IS-IS
  (level-2, IPv6 AF) + Segment Routing MPLS provide loopback reachability and
  the label transport. `P` is BGP-free.
- **Dual-stack customer routes**: CE1 originates `100.64.1.0/24` +
  `2001:db8:aaaa::/48`, CE2 originates `100.64.2.0/24` + `2001:db8:bbbb::/48`.
  IPv4 prefixes ride the IPv6-only core via **RFC 5549** (IPv4 NLRI with an IPv6
  next-hop) on the PE1↔PE2 iBGP session.
- **Traffic engineering**: two SR-TE policies from PE1 to PE2, each pinned to
  one of the parallel link pairs via that link's IS-IS adjacency-SID.

## Addressing

| Element                   | Value                                         |
| ------------------------- | --------------------------------------------- |
| PE1 / P / PE2 loopback    | `2001:db8::1` / `::2` / `::3` (SID 1 / 2 / 3) |
| PE1↔P links               | `2001:db8:0:1::/127`, `2001:db8:0:2::/127`    |
| P↔PE2 links               | `2001:db8:0:3::/127`, `2001:db8:0:4::/127`    |
| CE1↔PE1                   | `192.168.11.0/30` + `2001:db8:c1::/64`        |
| CE2↔PE2                   | `192.168.22.0/30` + `2001:db8:c2::/64`        |
| Core AS / CE1 AS / CE2 AS | 65000 / 65001 / 65002                         |

All of the above live in [`constants.nix`](./constants.nix) and are interpolated
by [`topology.nix`](./topology.nix) and [`configs.nix`](./configs.nix).

## Getting the image

cEOS is **not** auto-pulled. Register at arista.com, download the cEOS-lab image,
and import it, then set the matching tag in `constants.nix` (`image`):

```bash
docker import cEOS-lab-4.36.1F.tar.xz ceos:4.36.1F
```

## Run it

From the repo root:

```bash
nix run .#arista-mpls-up        # deploy
nix run .#arista-mpls-inspect   # list nodes
nix run .#arista-mpls-gen       # render lab dir to ./arista-mpls-lab for inspection
nix run .#arista-mpls-down      # tear down
```

## Verify

```bash
docker exec -it clab-arista-mpls-pe1 Cli
show isis neighbors                      # adjacencies up on BOTH links to P
show isis segment-routing prefix-segments
show bgp ipv6 unicast                    # CE2's 2001:db8:bbbb::/48 learned
show bgp ipv4 unicast                    # CE2's 100.64.2.0/24 (RFC 5549 next-hop)
show traffic-engineering segment-routing policy
```

End-to-end (from CE1):

```bash
ping 100.64.2.1 source 100.64.1.1
ping 2001:db8:bbbb::1 source 2001:db8:aaaa::1
```

## Status

Verified end-to-end on **cEOS `4.36.1F`**: IS-IS L2 adjacencies up on both
PE↔P link pairs, SR-MPLS prefix-segments programmed, PE1↔PE2 iBGP up, and
CE↔CE ping passes for **both** address families (0% loss) — IPv4 over RFC 5549
and native IPv6.

## Gotchas found while bringing this up

| #   | Symptom                                    | Root cause                                                                                     | Fix                                                                                                             |
| --- | ------------------------------------------ | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 1   | Data ports never bound; ~5-min boots       | clab endpoints named `EthernetN`; cEOS expects kernel `ethN`                                   | `topology.nix`: derive `ethN` from the config's `EthernetN`                                                     |
| 2   | CE eBGP never came up                      | BGP neighbor addresses carried a `/30`,`/64` suffix                                            | `configs.nix`: strip the prefix to a bare IP                                                                    |
| 3   | IPv4 wouldn't forward                      | no `ip routing` (only `ipv6 unicast-routing`)                                                  | `configs.nix`: add `ip routing`                                                                                 |
| 4   | No pingable endpoints                      | customer prefixes were only null-routed                                                        | CE `Loopback1` host addresses inside each prefix                                                                |
| 5   | IPv4 (RFC 5549) dropped in core; IPv6 fine | PHP pops the label → a bare IPv4 packet lands on an IPv6-only core link with no IPv4 adjacency | `explicit-null` on the prefix-SIDs so the penultimate hop swaps to label 2 and the egress PE does the IP lookup |

\#5 is the interesting one — a genuine RFC-5549-over-an-IPv6-only-SR-core
interaction, not a typo. IPv6 traffic is unaffected by PHP because the core link
_does_ have an IPv6 adjacency; only the label-less IPv4 packet has nowhere to go.

The SR-TE policies still need each link's dynamic adjacency-SID filled in (see
the comments in `configs.nix`).
