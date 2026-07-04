# constants -> { "<node>.cfg" = "<SR Linux flat `set` config>"; ... }
#
# All addresses / SIDs / ASNs are interpolated from constants.nix. SR Linux does
# not support classic RSVP-TE, so traffic engineering uses Segment Routing
# (SR-TE) policies instead. SR Linux SR-MPLS / SR policy / RFC 5549 syntax is
# version-sensitive and is the primary tuning surface (see ../README.md): the
# structure is correct and the values consistent, but validate against your
# image.
c:
let
  stripMask = a: builtins.head (builtins.split "/" a);

  routerId = {
    pe1 = "1.1.1.1";
    p = "2.2.2.2";
    pe2 = "3.3.3.3";
  };

  # System (loopback) interface + IS-IS/SR enablement shared by all core nodes.
  coreSystem = self: ''
    set / interface system0 admin-state enable
    set / interface system0 subinterface 0 admin-state enable
    set / interface system0 subinterface 0 ipv6 address ${c.loopback.${self}}/128
    set / network-instance default type default
    set / network-instance default admin-state enable
    set / network-instance default interface system0.0
    set / network-instance default protocols isis instance CORE admin-state enable
    set / network-instance default protocols isis instance CORE level-capability L2
    set / network-instance default protocols isis instance CORE net [ ${c.isoNet.${self}} ]
    set / network-instance default protocols isis instance CORE ipv6-unicast admin-state enable
    set / network-instance default protocols isis instance CORE segment-routing mpls admin-state enable
    set / network-instance default protocols isis instance CORE interface system0.0 passive true
    set / network-instance default protocols isis instance CORE interface system0.0 ipv6-unicast prefix-sid-index ${toString c.prefixSid.${self}}'';

  # One IS-IS-enabled /127 core interface.
  coreLink = srlIf: ip: ''
    set / interface ${srlIf} admin-state enable
    set / interface ${srlIf} subinterface 0 admin-state enable
    set / interface ${srlIf} subinterface 0 ipv6 address ${ip}
    set / network-instance default interface ${srlIf}.0
    set / network-instance default protocols isis instance CORE interface ${srlIf}.0 admin-state enable
    set / network-instance default protocols isis instance CORE interface ${srlIf}.0 circuit-type point-to-point
    set / network-instance default protocols isis instance CORE interface ${srlIf}.0 ipv6-unicast admin-state enable'';

  # A PE: core + dual-stack CE interface + iBGP (v4 via RFC 5549 + v6) + eBGP.
  peConfig =
    {
      self,
      far,
      coreA,
      coreB,
      ceIf,
      ceV4,
      ceV6,
      ceNbrV4,
      ceNbrV6,
      ceAsn,
    }:
    ''
      ${coreSystem self}
      ${coreLink coreA.srlIf coreA.ip}
      ${coreLink coreB.srlIf coreB.ip}
      set / interface ${ceIf} admin-state enable
      set / interface ${ceIf} subinterface 0 admin-state enable
      set / interface ${ceIf} subinterface 0 ipv4 admin-state enable
      set / interface ${ceIf} subinterface 0 ipv4 address ${ceV4}
      set / interface ${ceIf} subinterface 0 ipv6 address ${ceV6}
      set / network-instance default interface ${ceIf}.0
      set / network-instance default protocols bgp admin-state enable
      set / network-instance default protocols bgp autonomous-system ${toString c.asn.core}
      set / network-instance default protocols bgp router-id ${routerId.${self}}
      set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
      set / network-instance default protocols bgp afi-safi ipv6-unicast admin-state enable
      set / network-instance default protocols bgp group ibgp peer-as ${toString c.asn.core}
      set / network-instance default protocols bgp group ibgp local-as as-number ${toString c.asn.core}
      set / network-instance default protocols bgp group ibgp transport local-address ${c.loopback.${self}}
      set / network-instance default protocols bgp group ibgp afi-safi ipv4-unicast admin-state enable
      set / network-instance default protocols bgp group ibgp afi-safi ipv6-unicast admin-state enable
      set / network-instance default protocols bgp group ibgp next-hop-self true
      set / network-instance default protocols bgp neighbor ${c.loopback.${far}} peer-group ibgp
      set / network-instance default protocols bgp group ce peer-as ${toString ceAsn}
      set / network-instance default protocols bgp group ce afi-safi ipv4-unicast admin-state enable
      set / network-instance default protocols bgp group ce afi-safi ipv6-unicast admin-state enable
      set / network-instance default protocols bgp neighbor ${ceNbrV4} peer-group ce peer-as ${toString ceAsn}
      set / network-instance default protocols bgp neighbor ${ceNbrV6} peer-group ce peer-as ${toString ceAsn}
      # --- SR-TE: two policies to ${far}, one per parallel link pair. Fill the
      # --- adjacency-SID segment lists from `show network-instance default
      # --- protocols isis adjacency-sid` on a running lab.
      set / network-instance default segment-routing te policy to-${far}-a color 1 endpoint ${c.loopback.${far}}
      set / network-instance default segment-routing te policy to-${far}-b color 2 endpoint ${c.loopback.${far}}'';

  # A CE: dual-stack interface, blackhole the originated prefixes, export to eBGP.
  ceConfig =
    {
      self,
      edgeIf,
      v4,
      v6,
      peV4,
      peV6,
      route4,
      route6,
      asn,
    }:
    ''
      set / interface ${edgeIf} admin-state enable
      set / interface ${edgeIf} subinterface 0 admin-state enable
      set / interface ${edgeIf} subinterface 0 ipv4 admin-state enable
      set / interface ${edgeIf} subinterface 0 ipv4 address ${v4}
      set / interface ${edgeIf} subinterface 0 ipv6 address ${v6}
      set / network-instance default type default
      set / network-instance default admin-state enable
      set / network-instance default interface ${edgeIf}.0
      set / network-instance default static-routes route ${route4} blackhole
      set / network-instance default static-routes route ${route6} blackhole
      set / routing-policy policy export-customer statement 10 match protocol static
      set / routing-policy policy export-customer statement 10 action policy-result accept
      set / network-instance default protocols bgp admin-state enable
      set / network-instance default protocols bgp autonomous-system ${toString asn}
      set / network-instance default protocols bgp router-id ${
        if self == "ce1" then "10.1.1.1" else "10.2.2.2"
      }
      set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
      set / network-instance default protocols bgp afi-safi ipv6-unicast admin-state enable
      set / network-instance default protocols bgp group pe peer-as ${toString c.asn.core}
      set / network-instance default protocols bgp group pe export-policy export-customer
      set / network-instance default protocols bgp group pe afi-safi ipv4-unicast admin-state enable
      set / network-instance default protocols bgp group pe afi-safi ipv6-unicast admin-state enable
      set / network-instance default protocols bgp neighbor ${stripMask peV4} peer-group pe
      set / network-instance default protocols bgp neighbor ${stripMask peV6} peer-group pe'';
in
{
  "ce1.cfg" = ceConfig {
    self = "ce1";
    edgeIf = c.edge.ce1_pe1.ce1If;
    v4 = c.edge.ce1_pe1.ce1V4;
    v6 = c.edge.ce1_pe1.ce1V6;
    peV4 = c.edge.ce1_pe1.pe1V4;
    peV6 = c.edge.ce1_pe1.pe1V6;
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
    route4 = c.route.ce2V4;
    route6 = c.route.ce2V6;
    asn = c.asn.ce2;
  };

  "pe1.cfg" = peConfig {
    self = "pe1";
    far = "pe2";
    coreA = {
      srlIf = c.core.pe1_p_a.pe1If;
      ip = c.core.pe1_p_a.pe1Ip;
    };
    coreB = {
      srlIf = c.core.pe1_p_b.pe1If;
      ip = c.core.pe1_p_b.pe1Ip;
    };
    ceIf = c.edge.ce1_pe1.pe1If;
    ceV4 = c.edge.ce1_pe1.pe1V4;
    ceV6 = c.edge.ce1_pe1.pe1V6;
    ceNbrV4 = stripMask c.edge.ce1_pe1.ce1V4;
    ceNbrV6 = stripMask c.edge.ce1_pe1.ce1V6;
    ceAsn = c.asn.ce1;
  };

  "pe2.cfg" = peConfig {
    self = "pe2";
    far = "pe1";
    coreA = {
      srlIf = c.core.p_pe2_a.pe2If;
      ip = c.core.p_pe2_a.pe2Ip;
    };
    coreB = {
      srlIf = c.core.p_pe2_b.pe2If;
      ip = c.core.p_pe2_b.pe2Ip;
    };
    ceIf = c.edge.ce2_pe2.pe2If;
    ceV4 = c.edge.ce2_pe2.pe2V4;
    ceV6 = c.edge.ce2_pe2.pe2V6;
    ceNbrV4 = stripMask c.edge.ce2_pe2.ce2V4;
    ceNbrV6 = stripMask c.edge.ce2_pe2.ce2V6;
    ceAsn = c.asn.ce2;
  };

  "p.cfg" = ''
    ${coreSystem "p"}
    ${coreLink c.core.pe1_p_a.pIf c.core.pe1_p_a.pIp}
    ${coreLink c.core.pe1_p_b.pIf c.core.pe1_p_b.pIp}
    ${coreLink c.core.p_pe2_a.pIf c.core.p_pe2_a.pIp}
    ${coreLink c.core.p_pe2_b.pIf c.core.p_pe2_b.pIp}'';
}
