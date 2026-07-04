# Human-readable constants for the Arista cEOS MPLS example.
#
# Everything the topology and the device configs need is named here once and
# only once. topology.nix and configs.nix interpolate these names, so there are
# no bare addresses / SIDs / ASNs anywhere in the generated artifacts.
#
#   CE1 --eBGP-- PE1 ==(2 links)== P ==(2 links)== PE2 --eBGP-- CE2
#
# IPv6-only core (IS-IS L2 + SR-MPLS); dual-stack customer edge (IPv4 carried
# over the v6 core via RFC 5549). See ./README.md.
rec {
  labName = "arista-mpls";
  kind = "arista_ceos";
  image = "ceos:4.32.0F"; # imported manually into Docker (see README)

  # Out-of-band management network. Kept off the common 172.17-172.20 ranges to
  # avoid clashing with other local Docker networks; distinct from the Nokia
  # example so both labs can run at once.
  mgmt = {
    network = "clab-arista-mgmt";
    v4 = "172.22.20.0/24";
    v6 = "3fff:172:22:22::/64";
  };

  asn = {
    core = 65000; # iBGP AS shared by PE1/PE2
    ce1 = 65001;
    ce2 = 65002;
  };

  # /128 loopbacks (IS-IS router-id source, iBGP endpoints, SR prefix-SID owner)
  loopback = {
    pe1 = "2001:db8::1";
    p = "2001:db8::2";
    pe2 = "2001:db8::3";
  };

  # ISO NETs for IS-IS, derived by hand from the loopback host part.
  isoNet = {
    pe1 = "49.0000.0000.0001.00";
    p = "49.0000.0000.0002.00";
    pe2 = "49.0000.0000.0003.00";
  };

  # SR-MPLS prefix-SID index per node loopback (SRGB default base).
  prefixSid = {
    pe1 = 1;
    p = 2;
    pe2 = 3;
  };

  # Core /127 point-to-point links. `a` is the ::0 side, `b` the ::1 side.
  # Two parallel PE1<->P links and two parallel P<->PE2 links.
  core = {
    pe1_p_a = {
      net = "2001:db8:0:1::/127";
      pe1If = "Ethernet1";
      pe1Ip = "2001:db8:0:1::/127";
      pIf = "Ethernet1";
      pIp = "2001:db8:0:1::1/127";
    };
    pe1_p_b = {
      net = "2001:db8:0:2::/127";
      pe1If = "Ethernet2";
      pe1Ip = "2001:db8:0:2::/127";
      pIf = "Ethernet2";
      pIp = "2001:db8:0:2::1/127";
    };
    p_pe2_a = {
      net = "2001:db8:0:3::/127";
      pIf = "Ethernet3";
      pIp = "2001:db8:0:3::/127";
      pe2If = "Ethernet1";
      pe2Ip = "2001:db8:0:3::1/127";
    };
    p_pe2_b = {
      net = "2001:db8:0:4::/127";
      pIf = "Ethernet4";
      pIp = "2001:db8:0:4::/127";
      pe2If = "Ethernet2";
      pe2Ip = "2001:db8:0:4::1/127";
    };
  };

  # Dual-stack customer links (CE <-> PE).
  edge = {
    ce1_pe1 = {
      ce1If = "Ethernet1";
      ce1V4 = "192.168.11.1/30";
      ce1V6 = "2001:db8:c1::1/64";
      pe1If = "Ethernet3";
      pe1V4 = "192.168.11.2/30";
      pe1V6 = "2001:db8:c1::2/64";
    };
    ce2_pe2 = {
      ce2If = "Ethernet1";
      ce2V4 = "192.168.22.1/30";
      ce2V6 = "2001:db8:c2::1/64";
      pe2If = "Ethernet3";
      pe2V4 = "192.168.22.2/30";
      pe2V6 = "2001:db8:c2::2/64";
    };
  };

  # One IPv4 + one IPv6 prefix originated by each customer router.
  route = {
    ce1V4 = "100.64.1.0/24";
    ce1V6 = "2001:db8:aaaa::/48";
    ce2V4 = "100.64.2.0/24";
    ce2V6 = "2001:db8:bbbb::/48";
  };
}
