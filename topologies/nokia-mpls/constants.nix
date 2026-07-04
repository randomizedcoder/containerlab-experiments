# Human-readable constants for the Nokia SR Linux MPLS example.
#
# Same logical topology and addressing as the Arista example, but SR Linux names
# interfaces `ethernet-1/N` (containerlab short form `e1-N`), so each link
# carries both forms: `clabIf` for topology.nix endpoints and `srlIf` for the
# device config.
#
#   CE1 --eBGP-- PE1 ==(2 links)== P ==(2 links)== PE2 --eBGP-- CE2
#
# IPv6-only core (IS-IS L2 + SR-MPLS); dual-stack customer edge (IPv4 over the
# v6 core via RFC 5549). See ./README.md.
rec {
  labName = "nokia-mpls";
  kind = "nokia_srlinux";
  image = "ghcr.io/nokia/srlinux:latest"; # free, auto-pulled from ghcr

  # NOTE: the free SR Linux container does NOT expose SR-MPLS / IGP segment
  # routing config on any platform type (verified on ixr-d2l and ixr6e; ixr6e
  # also crash-loops). This example is therefore BLOCKED and slated to move to
  # Nokia SR OS (vr-sros) - see ../../README.md "Status". Kept on the stable
  # default DC type so the nodes at least boot.
  type = "ixr-d2l";

  # Out-of-band management network. Kept off the common 172.17-172.20 ranges to
  # avoid clashing with other local Docker networks; distinct from the Arista
  # example so both labs can run at once.
  mgmt = {
    network = "clab-nokia-mgmt";
    v4 = "172.21.20.0/24";
    v6 = "3fff:172:21:21::/64";
  };

  asn = {
    core = 65000;
    ce1 = 65001;
    ce2 = 65002;
  };

  loopback = {
    pe1 = "2001:db8::1";
    p = "2001:db8::2";
    pe2 = "2001:db8::3";
  };

  isoNet = {
    pe1 = "49.0000.0000.0001.00";
    p = "49.0000.0000.0002.00";
    pe2 = "49.0000.0000.0003.00";
  };

  prefixSid = {
    pe1 = 1;
    p = 2;
    pe2 = 3;
  };

  # Core /127 links. `a` = ::0 side, `b` = ::1 side.
  core = {
    pe1_p_a = {
      net = "2001:db8:0:1::/127";
      pe1If = "ethernet-1/1";
      pe1Clab = "e1-1";
      pe1Ip = "2001:db8:0:1::/127";
      pIf = "ethernet-1/1";
      pClab = "e1-1";
      pIp = "2001:db8:0:1::1/127";
    };
    pe1_p_b = {
      net = "2001:db8:0:2::/127";
      pe1If = "ethernet-1/2";
      pe1Clab = "e1-2";
      pe1Ip = "2001:db8:0:2::/127";
      pIf = "ethernet-1/2";
      pClab = "e1-2";
      pIp = "2001:db8:0:2::1/127";
    };
    p_pe2_a = {
      net = "2001:db8:0:3::/127";
      pIf = "ethernet-1/3";
      pClab = "e1-3";
      pIp = "2001:db8:0:3::/127";
      pe2If = "ethernet-1/1";
      pe2Clab = "e1-1";
      pe2Ip = "2001:db8:0:3::1/127";
    };
    p_pe2_b = {
      net = "2001:db8:0:4::/127";
      pIf = "ethernet-1/4";
      pClab = "e1-4";
      pIp = "2001:db8:0:4::/127";
      pe2If = "ethernet-1/2";
      pe2Clab = "e1-2";
      pe2Ip = "2001:db8:0:4::1/127";
    };
  };

  # Dual-stack customer links.
  edge = {
    ce1_pe1 = {
      ce1If = "ethernet-1/1";
      ce1Clab = "e1-1";
      ce1V4 = "192.168.11.1/30";
      ce1V6 = "2001:db8:c1::1/64";
      pe1If = "ethernet-1/3";
      pe1Clab = "e1-3";
      pe1V4 = "192.168.11.2/30";
      pe1V6 = "2001:db8:c1::2/64";
    };
    ce2_pe2 = {
      ce2If = "ethernet-1/1";
      ce2Clab = "e1-1";
      ce2V4 = "192.168.22.1/30";
      ce2V6 = "2001:db8:c2::1/64";
      pe2If = "ethernet-1/3";
      pe2Clab = "e1-3";
      pe2V4 = "192.168.22.2/30";
      pe2V6 = "2001:db8:c2::2/64";
    };
  };

  route = {
    ce1V4 = "100.64.1.0/24";
    ce1V6 = "2001:db8:aaaa::/48";
    ce2V4 = "100.64.2.0/24";
    ce2V6 = "2001:db8:bbbb::/48";
  };
}
