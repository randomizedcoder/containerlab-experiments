# constants -> containerlab topology attrset (rendered to nokia-mpls.clab.yml).
# Endpoints use the containerlab short interface form (e1-N).
c: {
  name = c.labName;

  mgmt = {
    network = c.mgmt.network;
    ipv4-subnet = c.mgmt.v4;
    ipv6-subnet = c.mgmt.v6;
  };

  topology = {
    defaults = {
      inherit (c) kind;
    };

    kinds.${c.kind} = {
      image = c.image;
      type = c.type;
    };

    # `.partial` tells containerlab these are partial CLI configs to merge into
    # SR Linux's factory config, not full replacements (which would revert).
    nodes = {
      ce1.startup-config = "configs/ce1.partial.cfg";
      pe1.startup-config = "configs/pe1.partial.cfg";
      p.startup-config = "configs/p.partial.cfg";
      pe2.startup-config = "configs/pe2.partial.cfg";
      ce2.startup-config = "configs/ce2.partial.cfg";
    };

    links = [
      {
        endpoints = [
          "ce1:${c.edge.ce1_pe1.ce1Clab}"
          "pe1:${c.edge.ce1_pe1.pe1Clab}"
        ];
      }
      {
        endpoints = [
          "pe1:${c.core.pe1_p_a.pe1Clab}"
          "p:${c.core.pe1_p_a.pClab}"
        ];
      }
      {
        endpoints = [
          "pe1:${c.core.pe1_p_b.pe1Clab}"
          "p:${c.core.pe1_p_b.pClab}"
        ];
      }
      {
        endpoints = [
          "p:${c.core.p_pe2_a.pClab}"
          "pe2:${c.core.p_pe2_a.pe2Clab}"
        ];
      }
      {
        endpoints = [
          "p:${c.core.p_pe2_b.pClab}"
          "pe2:${c.core.p_pe2_b.pe2Clab}"
        ];
      }
      {
        endpoints = [
          "ce2:${c.edge.ce2_pe2.ce2Clab}"
          "pe2:${c.edge.ce2_pe2.pe2Clab}"
        ];
      }
    ];
  };
}
