# constants -> { "<node>.cfg" = "<Arista EOS config>"; ... }
#
# All addresses / SIDs / ASNs are interpolated from constants.nix; nothing is
# hard-coded here. cEOS EOS syntax for IPv6 SR-MPLS + SR-TE + RFC 5549 varies by
# release and is the primary tuning surface (see ../README.md) - the structure
# is correct and the values are consistent, but validate against your image.
c:
let
  # BGP requires an IPv4 router-id even on a v6-only control plane; reuse the
  # loopback host index as a stable, non-routable id.
  routerId = {
    pe1 = "1.1.1.1";
    p = "2.2.2.2";
    pe2 = "3.3.3.3";
  };

  # Common preamble for every core/edge node.
  preamble = hostname: ''
    hostname ${hostname}
    !
    service routing protocols model multi-agent
    !
    ip routing
    ipv6 unicast-routing
    !
    mpls ip
    !'';

  # A PE runs: IS-IS+SR core, iBGP to the far PE (v4 via RFC 5549 + v6),
  # eBGP dual-stack to its CE, and two SR-TE policies over the parallel links.
  peConfig =
    {
      self, # "pe1" | "pe2"
      far, # far PE key
      coreA,
      coreB, # the two core link records for this PE
      coreAIf,
      coreBIf, # this PE's interface field names on those links
      coreAIp,
      coreBIp,
      ceEdge, # this PE's edge link record
      ceIf,
      ceV4,
      ceV6,
      ceNbrV4,
      ceNbrV6,
      ceAsn,
    }:
    ''
      ${preamble self}
      interface Loopback0
         ipv6 address ${c.loopback.${self}}/128
         isis enable CORE
         ! explicit-null: advertise the prefix-SID with the E-flag so the
         ! penultimate hop swaps to the explicit-null label instead of doing
         ! PHP. Without it, PHP leaves a bare IPv4 packet (RFC 5549 traffic) on
         ! the IPv6-only core link, which has no IPv4 adjacency, so it is
         ! dropped. Keeping the label to the egress PE lets it do the IP lookup.
         node-segment ipv6 index ${toString c.prefixSid.${self}} explicit-null
      !
      interface ${coreAIf}
         no switchport
         ipv6 enable
         ipv6 address ${coreAIp}
         isis enable CORE
         isis network point-to-point
      !
      interface ${coreBIf}
         no switchport
         ipv6 enable
         ipv6 address ${coreBIp}
         isis enable CORE
         isis network point-to-point
      !
      interface ${ceIf}
         no switchport
         ip address ${ceV4}
         ipv6 address ${ceV6}
      !
      router isis CORE
         net ${c.isoNet.${self}}
         is-type level-2
         !
         address-family ipv6 unicast
         !
         segment-routing mpls
            no shutdown
      !
      router bgp ${toString c.asn.core}
         router-id ${routerId.${self}}
         no bgp default ipv4-unicast
         !
         neighbor ${c.loopback.${far}} remote-as ${toString c.asn.core}
         neighbor ${c.loopback.${far}} update-source Loopback0
         neighbor ${c.loopback.${far}} next-hop-self
         !
         neighbor ${ceNbrV6} remote-as ${toString ceAsn}
         neighbor ${ceNbrV4} remote-as ${toString ceAsn}
         !
         address-family ipv4
            neighbor ${ceNbrV4} activate
            neighbor ${c.loopback.${far}} activate
            neighbor ${c.loopback.${far}} next-hop address-family ipv6
         !
         address-family ipv6
            neighbor ${ceNbrV6} activate
            neighbor ${c.loopback.${far}} activate
      !
      ! --- Traffic engineering: two SR-TE policies to the far PE, one pinned to
      ! --- each parallel link pair via that link's IS-IS adjacency-SID.
      ! --- Adjacency SIDs are allocated dynamically; read them from
      ! ---   'show isis segment-routing adjacency-segments'
      ! --- on a running lab and fill the explicit index lists below.
      router traffic-engineering
         segment-routing
            policy endpoint ${c.loopback.${far}} color 1
               ! path over ${coreA.net}: <adj-sid link A>
               binding-sid 900${toString c.prefixSid.${self}}
            !
            policy endpoint ${c.loopback.${far}} color 2
               ! path over ${coreB.net}: <adj-sid link B>
               binding-sid 901${toString c.prefixSid.${self}}
      !
      end'';

  # A CE originates one IPv4 + one IPv6 prefix into eBGP toward its PE.
  ceConfig =
    {
      self, # "ce1" | "ce2"
      edgeIf,
      v4,
      v6,
      peV4,
      peV6,
      hostV4,
      hostV6,
      route4,
      route6,
      asn,
    }:
    let
      # BGP neighbor addresses must be bare IPs; the PE edge addresses carry a
      # prefix length (e.g. 192.168.11.2/30), so strip it as the PE config does.
      peV4Addr = builtins.head (builtins.split "/" peV4);
      peV6Addr = builtins.head (builtins.split "/" peV6);
    in
    ''
      ${preamble self}
      interface ${edgeIf}
         no switchport
         ip address ${v4}
         ipv6 address ${v6}
      !
      ! Loopback host addresses inside the advertised prefixes; real endpoints
      ! for end-to-end CE<->CE ping tests.
      interface Loopback1
         ip address ${hostV4}
         ipv6 address ${hostV6}
      !
      ip route ${route4} Null0
      ipv6 route ${route6} Null0
      !
      router bgp ${toString asn}
         router-id ${if self == "ce1" then "10.1.1.1" else "10.2.2.2"}
         no bgp default ipv4-unicast
         neighbor ${peV4Addr} remote-as ${toString c.asn.core}
         neighbor ${peV6Addr} remote-as ${toString c.asn.core}
         !
         address-family ipv4
            neighbor ${peV4Addr} activate
            network ${route4}
         !
         address-family ipv6
            neighbor ${peV6Addr} activate
            network ${route6}
      !
      end'';
in
{
  "ce1.cfg" = ceConfig {
    self = "ce1";
    edgeIf = c.edge.ce1_pe1.ce1If;
    v4 = c.edge.ce1_pe1.ce1V4;
    v6 = c.edge.ce1_pe1.ce1V6;
    peV4 = c.edge.ce1_pe1.pe1V4;
    peV6 = c.edge.ce1_pe1.pe1V6;
    hostV4 = c.host.ce1V4;
    hostV6 = c.host.ce1V6;
    route4 = c.route.ce1V4;
    route6 = c.route.ce1V6;
    asn = c.asn.ce1;
  };

  "ce2.cfg" = ceConfig {
    self = "ce2";
    edgeIf = c.edge.ce2_pe2.ce2If;
    v4 = c.edge.ce2_pe2.ce2V4;
    v6 = c.edge.ce2_pe2.ce2V6;
    peV4 = c.edge.ce2_pe2.pe2V4;
    peV6 = c.edge.ce2_pe2.pe2V6;
    hostV4 = c.host.ce2V4;
    hostV6 = c.host.ce2V6;
    route4 = c.route.ce2V4;
    route6 = c.route.ce2V6;
    asn = c.asn.ce2;
  };

  "pe1.cfg" = peConfig {
    self = "pe1";
    far = "pe2";
    coreA = c.core.pe1_p_a;
    coreB = c.core.pe1_p_b;
    coreAIf = c.core.pe1_p_a.pe1If;
    coreBIf = c.core.pe1_p_b.pe1If;
    coreAIp = c.core.pe1_p_a.pe1Ip;
    coreBIp = c.core.pe1_p_b.pe1Ip;
    ceEdge = c.edge.ce1_pe1;
    ceIf = c.edge.ce1_pe1.pe1If;
    ceV4 = c.edge.ce1_pe1.pe1V4;
    ceV6 = c.edge.ce1_pe1.pe1V6;
    ceNbrV4 = builtins.head (builtins.split "/" c.edge.ce1_pe1.ce1V4);
    ceNbrV6 = builtins.head (builtins.split "/" c.edge.ce1_pe1.ce1V6);
    ceAsn = c.asn.ce1;
  };

  "pe2.cfg" = peConfig {
    self = "pe2";
    far = "pe1";
    coreA = c.core.p_pe2_a;
    coreB = c.core.p_pe2_b;
    coreAIf = c.core.p_pe2_a.pe2If;
    coreBIf = c.core.p_pe2_b.pe2If;
    coreAIp = c.core.p_pe2_a.pe2Ip;
    coreBIp = c.core.p_pe2_b.pe2Ip;
    ceEdge = c.edge.ce2_pe2;
    ceIf = c.edge.ce2_pe2.pe2If;
    ceV4 = c.edge.ce2_pe2.pe2V4;
    ceV6 = c.edge.ce2_pe2.pe2V6;
    ceNbrV4 = builtins.head (builtins.split "/" c.edge.ce2_pe2.ce2V4);
    ceNbrV6 = builtins.head (builtins.split "/" c.edge.ce2_pe2.ce2V6);
    ceAsn = c.asn.ce2;
  };

  # The P router is BGP-free: IS-IS + SR-MPLS transit only, four core links.
  "p.cfg" = ''
    ${preamble "p"}
    interface Loopback0
       ipv6 address ${c.loopback.p}/128
       isis enable CORE
       ! explicit-null for consistency with the PEs (see peConfig); harmless on
       ! P, which is transit-only and never an egress for customer traffic.
       node-segment ipv6 index ${toString c.prefixSid.p} explicit-null
    !
    interface ${c.core.pe1_p_a.pIf}
       no switchport
       ipv6 enable
       ipv6 address ${c.core.pe1_p_a.pIp}
       isis enable CORE
       isis network point-to-point
    !
    interface ${c.core.pe1_p_b.pIf}
       no switchport
       ipv6 enable
       ipv6 address ${c.core.pe1_p_b.pIp}
       isis enable CORE
       isis network point-to-point
    !
    interface ${c.core.p_pe2_a.pIf}
       no switchport
       ipv6 enable
       ipv6 address ${c.core.p_pe2_a.pIp}
       isis enable CORE
       isis network point-to-point
    !
    interface ${c.core.p_pe2_b.pIf}
       no switchport
       ipv6 enable
       ipv6 address ${c.core.p_pe2_b.pIp}
       isis enable CORE
       isis network point-to-point
    !
    router isis CORE
       net ${c.isoNet.p}
       is-type level-2
       !
       address-family ipv6 unicast
       !
       segment-routing mpls
          no shutdown
    !
    end'';
}
