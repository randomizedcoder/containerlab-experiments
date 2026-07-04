# constants -> containerlab topology attrset (rendered to arista-mpls.clab.yml).
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

    kinds.${c.kind}.image = c.image;

    nodes = {
      ce1.startup-config = "configs/ce1.cfg";
      pe1.startup-config = "configs/pe1.cfg";
      p.startup-config = "configs/p.cfg";
      pe2.startup-config = "configs/pe2.cfg";
      ce2.startup-config = "configs/ce2.cfg";
    };

    # Endpoints reference the same interface names used in configs.nix.
    links = [
      {
        endpoints = [
          "ce1:${c.edge.ce1_pe1.ce1If}"
          "pe1:${c.edge.ce1_pe1.pe1If}"
        ];
      }
      {
        endpoints = [
          "pe1:${c.core.pe1_p_a.pe1If}"
          "p:${c.core.pe1_p_a.pIf}"
        ];
      }
      {
        endpoints = [
          "pe1:${c.core.pe1_p_b.pe1If}"
          "p:${c.core.pe1_p_b.pIf}"
        ];
      }
      {
        endpoints = [
          "p:${c.core.p_pe2_a.pIf}"
          "pe2:${c.core.p_pe2_a.pe2If}"
        ];
      }
      {
        endpoints = [
          "p:${c.core.p_pe2_b.pIf}"
          "pe2:${c.core.p_pe2_b.pe2If}"
        ];
      }
      {
        endpoints = [
          "ce2:${c.edge.ce2_pe2.ce2If}"
          "pe2:${c.edge.ce2_pe2.pe2If}"
        ];
      }
    ];
  };
}
